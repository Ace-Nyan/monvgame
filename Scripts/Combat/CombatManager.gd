## CombatManager — 战斗编排器
##
## 一场战斗的核心流程：
##   1. start(player, enemy) -> 双方 init_for_combat() + 抽手牌
##   2. begin_turn(): 双方刷新 AP，敌人 AI 选牌入队（intent 公开类型，帧数保密）
##   3. 玩家选牌 queue_card()，达到出牌完成时按 confirm_player_turn()
##   4. resolve_timeline(): 把双方 queued_cards 排到 0~99 tick 时间轴上，
##      逐 tick 推进每张卡的 phase 状态：WINDUP -> ACTIVE -> RECOVERY -> DONE
##      ACTIVE 进入瞬间触发 effect.apply()
##   5. end_turn(): 弃手、清护盾、检查死亡 -> 下一回合 / 结束
##
## 注：本 MVP 版本时间轴不做"打断"以外的复杂交互；C 模型的"recovery 期受击放大"
## 通过敌方 active 命中我方 recovery 时的 1.5x 倍率实现（见 deal_damage）。
class_name CombatManager
extends Node

const TURN_TICKS: int = 100
const RECOVERY_DAMAGE_MULTIPLIER: float = 1.5

enum State { IDLE, PLAYER_PLANNING, RESOLVING, ENDED }

var player: Combatant
var enemy: Combatant
var turn_index: int = 0
var state: int = State.IDLE

## 当前正在结算的卡指针（供 interrupt 检查使用）
var _resolving_cards: Array[CardInstance] = []

func start(p: Combatant, e: Combatant) -> void:
	player = p
	enemy = e
	turn_index = 0
	player.init_for_combat()
	enemy.init_for_combat()
	player.draw_to_hand_size()
	enemy.draw_to_hand_size()
	EventBus.combat_started.emit(player, enemy)
	begin_turn()

func begin_turn() -> void:
	turn_index += 1
	player.refresh_ap()
	enemy.refresh_ap()
	player.queued_cards.clear()
	enemy.queued_cards.clear()
	# 敌人 AI 选牌
	_enemy_select_cards()
	state = State.PLAYER_PLANNING
	EventBus.turn_started.emit(turn_index)

# === 玩家行动 ===

func can_queue(card: CardInstance) -> bool:
	if state != State.PLAYER_PLANNING:
		return false
	return player.can_play(card)

func queue_card(card: CardInstance) -> bool:
	if not can_queue(card):
		return false
	player.ap -= card.data.cost
	player.queued_cards.append(card)
	player.deck.hand.erase(card)
	EventBus.card_queued.emit(player, card)
	return true

func unqueue_card(card: CardInstance) -> bool:
	if state != State.PLAYER_PLANNING:
		return false
	if not player.queued_cards.has(card):
		return false
	player.queued_cards.erase(card)
	player.ap += card.data.cost
	player.deck.hand.append(card)
	return true

func confirm_player_turn() -> void:
	if state != State.PLAYER_PLANNING:
		return
	state = State.RESOLVING
	resolve_timeline()

# === 敌人 AI ===

func _enemy_select_cards() -> void:
	# MVP：贪心地把手牌按 cost 升序选满 AP
	var hand_copy := enemy.deck.hand.duplicate()
	hand_copy.sort_custom(func(a, b): return a.data.cost < b.data.cost)
	for c: CardInstance in hand_copy:
		if c.data.cost <= enemy.ap:
			enemy.ap -= c.data.cost
			enemy.queued_cards.append(c)
			enemy.deck.hand.erase(c)
			EventBus.card_queued.emit(enemy, c)

# === 时间轴推进 ===

func resolve_timeline() -> void:
	# 双方各自串联：自家的卡按入队顺序首尾相连
	var player_cards := _layout_cards(player, 0)
	var enemy_cards := _layout_cards(enemy, 0)
	_resolving_cards = player_cards + enemy_cards
	# 简单 tick 推进：每个 tick 检查每张卡当前应处于什么 phase
	for tick in TURN_TICKS:
		for card: CardInstance in _resolving_cards:
			_advance_card(card, tick)
		# 终止条件
		if not player.is_alive() or not enemy.is_alive():
			break
	# 收尾
	for card in _resolving_cards:
		if card.phase != CardInstance.Phase.INTERRUPTED and card.phase != CardInstance.Phase.DONE:
			card.enter_phase(CardInstance.Phase.DONE)
		EventBus.card_resolved.emit(card)
	_end_turn()

func _layout_cards(c: Combatant, base_tick: int) -> Array[CardInstance]:
	var cur := base_tick
	var out: Array[CardInstance] = []
	for card: CardInstance in c.queued_cards:
		card.timeline_start = cur
		card.phase = CardInstance.Phase.PENDING
		cur += card.data.total_frames()
		out.append(card)
	return out

func _advance_card(card: CardInstance, tick: int) -> void:
	if card.phase == CardInstance.Phase.INTERRUPTED or card.phase == CardInstance.Phase.DONE:
		return
	var local := tick - card.timeline_start
	if local < 0:
		return
	var d := card.data
	var w := d.windup_frames
	var a := d.active_frames
	if local < w:
		if card.phase != CardInstance.Phase.WINDUP:
			card.enter_phase(CardInstance.Phase.WINDUP)
	elif local < w + a:
		if card.phase != CardInstance.Phase.ACTIVE:
			card.enter_phase(CardInstance.Phase.ACTIVE)
			_apply_effects(card)
	elif local < d.total_frames():
		if card.phase != CardInstance.Phase.RECOVERY:
			card.enter_phase(CardInstance.Phase.RECOVERY)
	else:
		card.enter_phase(CardInstance.Phase.DONE)

func _apply_effects(card: CardInstance) -> void:
	var source := card.owner
	var target := _resolve_target(card)
	var ctx := {
		"source": source,
		"target": target,
		"card": card,
		"manager": self,
	}
	for e: CardEffect in card.data.effects:
		if e.phase == CardEffect.Phase.ACTIVE:
			e.apply(ctx)

func _resolve_target(card: CardInstance) -> Combatant:
	match card.data.target_kind:
		CardData.Target.SELF: return card.owner
		CardData.Target.ENEMY, CardData.Target.ALL_ENEMIES:
			return enemy if card.owner == player else player
	return null

# === 由 effects 反向调用 ===

func deal_damage(source: Combatant, target: Combatant, amount: float, element: int, _src_card: CardInstance) -> void:
	# 元素克制
	var matchup := Element.matchup_multiplier(element, _attacker_element_of(target))
	# 后摇放大
	var recovery_mult := 1.0
	if _is_in_recovery(target):
		recovery_mult = RECOVERY_DAMAGE_MULTIPLIER
	var raw := amount * matchup * recovery_mult
	var dealt := target.take_damage(raw, element)
	EventBus.damage_dealt.emit(source, target, amount, element, dealt)

func interrupt(target: Combatant, fizzle_dmg_mult: float) -> void:
	for card in _resolving_cards:
		if card.owner != target:
			continue
		if card.phase == CardInstance.Phase.WINDUP:
			card.enter_phase(CardInstance.Phase.INTERRUPTED)
			EventBus.card_interrupted.emit(card)
			# 顺带一点元素惩罚（用卡牌 element 回打）
			# 简化：固定 4 点无属性
			target.take_damage(4.0 * fizzle_dmg_mult, Element.Type.NONE)
			return

func _is_in_recovery(c: Combatant) -> bool:
	for card in _resolving_cards:
		if card.owner == c and card.phase == CardInstance.Phase.RECOVERY:
			return true
	return false

func _attacker_element_of(c: Combatant) -> int:
	# 取该角色"主导"元素：当前正在 ACTIVE 的卡的元素，否则 NONE
	for card in _resolving_cards:
		if card.owner == c and card.phase == CardInstance.Phase.ACTIVE:
			return card.data.element
	return Element.Type.NONE

# === 收尾 ===

func _end_turn() -> void:
	# 弃手 + 清护盾
	for c in [player, enemy]:
		# 已结算的 queued -> discard
		for ci: CardInstance in c.queued_cards:
			if ci.data:
				c.deck.discard_pile.append(ci.data)
		c.queued_cards.clear()
		# 未出的手牌也丢弃（杀戮尖塔风格）
		c.deck.discard_hand()
		c.block = 0
		EventBus.block_changed.emit(c, 0)
	EventBus.turn_ended.emit(turn_index)
	# 死亡判定
	if not player.is_alive():
		_finish(enemy)
		return
	if not enemy.is_alive():
		_finish(player)
		return
	# 抽下回合手牌
	player.draw_to_hand_size()
	enemy.draw_to_hand_size()
	begin_turn()

func _finish(winner: Combatant) -> void:
	state = State.ENDED
	EventBus.combat_ended.emit(winner)
