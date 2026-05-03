## Combatant — 实时动作模式下的战斗者组件
##
## 设计哲学（参考 Aalis）：
##   - 自身只负责"我是谁、能干什么、当前状态"，不持有具体战斗逻辑
##   - 通过 EventBus 广播状态变化，让 UI/AI/特效层各自响应
##   - 卡牌效果（CardEffect）由本组件在 ACTIVE 阶段反向调用
##
## 必须挂在 CharacterBody3D（或带有 Node3D 父级）下，因为施法会用到位置朝向。
class_name Combatant
extends Node

enum CastState { IDLE, WINDUP, ACTIVE, RECOVERY }
enum Faction { PLAYER, ENEMY }

# === 静态配置（@export 可在编辑器或 .tres 里改）===
@export var display_name: String = "战士"
@export var faction: Faction = Faction.ENEMY
@export var max_hp: int = 30
@export var max_ap: int = 3
@export var ap_regen_per_sec: float = 0.7        ## 每秒回复 AP
@export var hand_size: int = 4
@export var aggro_radius: float = 8.0            ## 进入此范围被警戒
@export var leash_radius: float = 16.0           ## 超出此范围脱战

@export_group("初始牌库（CardData id 列表）")
@export var starting_card_ids: Array[StringName] = []

@export_group("基础抗性")
@export var base_resistance: ResistanceProfile

# === 运行时状态 ===
var hp: int
var block: int = 0
var ap: float
var resistance: ResistanceProfile
var deck: Deck
var hand_slots: Array = []                       ## 长度 = hand_size，元素是 CardInstance 或 null

var cast_state: int = CastState.IDLE
var current_card: CardInstance = null
var phase_elapsed: float = 0.0                   ## 当前阶段已过秒数

var body3d: Node3D                               ## 父级 Node3D，提供位置朝向
var animator: Node                               ## 同一父级下的肢体动画器（LimbAnimator，可为空）
var aggro_target: Combatant = null

const FRAMES_TO_SECONDS: float = 1.0 / 12.0      ## 1 frame ≈ 0.083 秒（每秒 12 帧）

func _ready() -> void:
	hp = max_hp
	ap = float(max_ap)
	if base_resistance == null:
		base_resistance = ResistanceProfile.new()
	resistance = base_resistance.clone()
	# 解析所属 3D 节点
	body3d = get_parent()
	if body3d:
		animator = body3d.get_node_or_null("Visual/LimbAnimator")
		if animator == null:
			animator = body3d.get_node_or_null("Visual/Humanoid/LimbAnimator")
	# 构建牌库
	_build_deck()
	# 注册到 CombatantRegistry（用于互查 / AI 寻敌）
	CombatantRegistry.register(self)
	EventBus.combatant_registered.emit(self)
	EventBus.hp_changed.emit(self, hp, max_hp)
	EventBus.ap_changed.emit(self, ap, max_ap)
	EventBus.resistance_changed.emit(self)
	# 抽起手手牌
	for i in hand_size:
		_draw_to_first_empty_slot()

func _exit_tree() -> void:
	CombatantRegistry.unregister(self)
	EventBus.combatant_unregistered.emit(self)

func _build_deck() -> void:
	var cards: Array[CardData] = []
	for id in starting_card_ids:
		var c := CardRegistry.get_card(id)
		if c:
			cards.append(c)
			# 共鸣
			for k in c.resonance.keys():
				resistance.add_resistance(int(k), float(c.resonance[k]))
	deck = Deck.new(self, cards)
	hand_slots.resize(hand_size)
	for i in hand_size:
		hand_slots[i] = null

# === 帧循环 ===

func _process(delta: float) -> void:
	# AP 回复
	if cast_state == CastState.IDLE and ap < float(max_ap):
		ap = min(float(max_ap), ap + ap_regen_per_sec * delta)
		EventBus.ap_changed.emit(self, ap, max_ap)
	# 施法状态推进
	if cast_state != CastState.IDLE:
		phase_elapsed += delta
		_tick_cast()

func _tick_cast() -> void:
	if current_card == null:
		_finish_cast()
		return
	var d := current_card.data
	var w := float(d.windup_frames) * FRAMES_TO_SECONDS
	var a := float(d.active_frames) * FRAMES_TO_SECONDS
	var r := float(d.recovery_frames) * FRAMES_TO_SECONDS
	match cast_state:
		CastState.WINDUP:
			if phase_elapsed >= w:
				_enter_phase(CastState.ACTIVE)
				_resolve_active()
		CastState.ACTIVE:
			if phase_elapsed >= a:
				_enter_phase(CastState.RECOVERY)
		CastState.RECOVERY:
			if phase_elapsed >= r:
				_finish_cast()

# === 公开 API ===

## 玩家或 AI 调用：尝试用槽位 slot 的卡施法
func try_cast(slot: int) -> bool:
	if cast_state != CastState.IDLE:
		return false
	if slot < 0 or slot >= hand_slots.size():
		return false
	var inst: CardInstance = hand_slots[slot]
	if inst == null:
		return false
	if ap < float(inst.data.cost):
		return false
	# 扣 AP
	ap -= float(inst.data.cost)
	EventBus.ap_changed.emit(self, ap, max_ap)
	# 移除手牌槽，进入弃堆
	hand_slots[slot] = null
	deck.discard_pile.append(inst.data)
	EventBus.hand_changed.emit(self)
	# 启动状态机
	current_card = inst
	_enter_phase(CastState.WINDUP)
	EventBus.cast_started.emit(self, inst)
	if animator:
		animator.play_for_card(inst.data)
	return true

func is_casting() -> bool:
	return cast_state != CastState.IDLE

## 添加块/吸收伤害
func add_block(amount: int) -> void:
	block += amount
	EventBus.block_changed.emit(self, block)

func take_damage(raw_amount: float, element: int) -> float:
	var mitigated := resistance.mitigate(raw_amount, element)
	# 后摇期间受伤放大 1.5x
	if cast_state == CastState.RECOVERY:
		mitigated *= 1.5
	# WINDUP 期被打中 = 打断
	if cast_state == CastState.WINDUP:
		_interrupt()
	var remaining := mitigated
	if block > 0:
		var absorbed: float = min(float(block), remaining)
		block -= int(ceil(absorbed))
		remaining -= absorbed
		EventBus.block_changed.emit(self, block)
	if remaining > 0:
		hp = max(0, hp - int(ceil(remaining)))
		EventBus.hp_changed.emit(self, hp, max_hp)
		if hp <= 0:
			EventBus.combatant_died.emit(self)
	return mitigated

func is_alive() -> bool:
	return hp > 0

## 警戒方向 / 朝向（被 AI 与玩家锁敌共用）
func global_position_3d() -> Vector3:
	if body3d:
		return body3d.global_position
	return Vector3.ZERO

func forward_dir() -> Vector3:
	if body3d:
		return -body3d.global_basis.z
	return Vector3.FORWARD

# === 内部 ===

func _enter_phase(new_state: int) -> void:
	cast_state = new_state
	phase_elapsed = 0.0
	EventBus.cast_phase_changed.emit(self, current_card, new_state)

func _resolve_active() -> void:
	if current_card == null:
		return
	var target := _resolve_target(current_card.data)
	var ctx := {
		"source": self,
		"target": target,
		"card": current_card,
	}
	for e: CardEffect in current_card.data.effects:
		if e.phase == CardEffect.Phase.ACTIVE:
			e.apply(ctx)

func _resolve_target(d: CardData) -> Combatant:
	match d.target_kind:
		CardData.Target.SELF: return self
		CardData.Target.ENEMY:
			return CombatantRegistry.find_target_in_cone(self, d.range_m, deg_to_rad(d.aim_cone_deg))
	return null

func _interrupt() -> void:
	if current_card:
		EventBus.cast_interrupted.emit(self, current_card)
	_finish_cast()

func _finish_cast() -> void:
	if current_card:
		EventBus.cast_ended.emit(self, current_card)
	cast_state = CastState.IDLE
	current_card = null
	phase_elapsed = 0.0
	# 抽一张补槽
	_draw_to_first_empty_slot()

func _draw_to_first_empty_slot() -> void:
	for i in hand_slots.size():
		if hand_slots[i] == null:
			var drawn := deck.draw(1)
			if drawn.size() > 0:
				hand_slots[i] = drawn[0]
				EventBus.card_drawn.emit(self, drawn[0])
			break
	EventBus.hand_changed.emit(self)

# === 元素伤害结算（被 DamageEffect 调用）===

func deal_damage_to(target: Combatant, amount: float, element: int) -> void:
	if target == null or not target.is_alive():
		return
	var matchup := Element.matchup_multiplier(element, _dominant_element(target))
	var raw := amount * matchup
	var dealt := target.take_damage(raw, element)
	EventBus.damage_dealt.emit(self, target, amount, element, dealt)

func _dominant_element(_t: Combatant) -> int:
	# MVP：暂不为目标取主元素，直接 NONE
	return Element.Type.NONE
