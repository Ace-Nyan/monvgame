## Combatant — 战斗参与者组件
##
## 挂在 Node3D（玩家 / 敌人 NPC）下即可参战。
## 持有 HP、护盾、AP、抗性、牌库；不关心场景中具体节点结构。
##
## 共鸣：每张卡的 resonance 字典会被汇总到 base_resistance 之上，
## 形成 effective_resistance（每场战斗开始时计算一次）。
class_name Combatant
extends Node

signal died

@export var display_name: String = "战士"
@export var max_hp: int = 30
@export var max_ap: int = 3
@export var hand_size: int = 4
@export var is_player: bool = false

@export_group("初始牌库（CardData id 列表）")
@export var starting_card_ids: Array[StringName] = []

@export_group("基础抗性")
@export var base_resistance: ResistanceProfile

var hp: int = 30
var block: int = 0
var ap: int = 3
var resistance: ResistanceProfile
var deck: Deck

## 当前已"提交"到时间轴上的卡（本回合内）
var queued_cards: Array[CardInstance] = []

func _ready() -> void:
	hp = max_hp
	ap = max_ap
	if base_resistance == null:
		base_resistance = ResistanceProfile.new()

## 由 CombatManager 在战斗开始时调用
func init_for_combat() -> void:
	hp = max_hp
	block = 0
	ap = max_ap
	queued_cards.clear()
	# 抗性 = 基础 + 共鸣
	resistance = base_resistance.clone()
	# 构建牌库
	var cards: Array[CardData] = []
	for id in starting_card_ids:
		var c := CardRegistry.get_card(id)
		if c:
			cards.append(c)
			# 共鸣
			for k in c.resonance.keys():
				resistance.add_resistance(int(k), float(c.resonance[k]))
	deck = Deck.new(self, cards)
	EventBus.hp_changed.emit(self, hp, max_hp)
	EventBus.resistance_changed.emit(self)

func draw_to_hand_size() -> void:
	var need: int = hand_size - deck.hand.size()
	if need > 0:
		deck.draw(need)

func refresh_ap() -> void:
	ap = max_ap

func can_play(card: CardInstance) -> bool:
	return card.data != null and card.data.cost <= ap

func add_block(amount: int) -> void:
	block += amount
	EventBus.block_changed.emit(self, block)

func take_damage(raw_amount: float, element: int) -> float:
	var mitigated := resistance.mitigate(raw_amount, element)
	# 护盾吸收
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
			died.emit()
	return mitigated

func is_alive() -> bool:
	return hp > 0
