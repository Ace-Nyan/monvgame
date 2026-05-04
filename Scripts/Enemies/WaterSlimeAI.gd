extends Node
class_name WaterSlimeAI

@export var combatant_path: NodePath = ^"../Combatant"

var _combatant: Combatant
var _manager: CombatManager
var _use_cannon_next: bool = false
var _cannon_locked: bool = false
var _defense_mode: String = ""
var _jumps_left: int = 0

const JUMP_DISTANCE: float = 2.0

func _ready() -> void:
	_combatant = get_node_or_null(combatant_path) as Combatant
	_manager = get_tree().get_root().find_child("CombatManager", true, false) as CombatManager
	EventBus.turn_phase_changed.connect(_on_phase_changed)
	EventBus.cast_started.connect(_on_cast_started)

func prepare_enemy_turn() -> void:
	if _combatant == null:
		return
	var pick_cannon := _cannon_locked or _use_cannon_next
	_use_cannon_next = false
	var cards: Array[CardData] = []
	if pick_cannon:
		cards.append(CardRegistry.get_card(&"slime_water_cannon"))
	else:
		cards.append(CardRegistry.get_card(&"slime_water_shot"))
	cards.append(CardRegistry.get_card(&"slime_damage_up"))
	cards = cards.filter(func(c): return c != null)
	if cards.is_empty():
		return
	cards.shuffle()
	_combatant.deck.draw_pile.clear()
	_combatant.deck.discard_pile.clear()
	_combatant.deck.draw_pile.append(cards[0])

func _on_phase_changed(phase: int) -> void:
	if phase != CombatManager.Phase.ENEMY_ATTACK:
		_defense_mode = ""
		_jumps_left = 0
		return
	if _cannon_locked:
		_defense_mode = "jump"
		_jumps_left = 2
		if _combatant:
			_combatant._add_status(&"slime_defense", "防御：随机跳跃")
		return
	# 防御回合策略
	if randi() % 2 == 0:
		_defense_mode = "jump"
		_jumps_left = 2
		if _combatant:
			_combatant._add_status(&"slime_defense", "防御：随机跳跃")
	else:
		_defense_mode = "cannon"
		_use_cannon_next = true
		_cannon_locked = true
		if _combatant:
			_combatant._add_status(&"slime_defense", "防御：水炮准备(永久)")

func _on_cast_started(c: Combatant, card: CardInstance) -> void:
	if _manager == null:
		return
	if _manager.phase != CombatManager.Phase.ENEMY_ATTACK:
		return
	if _manager.response_phase != "response":
		return
	if _defense_mode != "jump":
		return
	if _jumps_left <= 0:
		return
	if c == null or c.faction != Combatant.Faction.PLAYER:
		return
	if card == null or card.data.intent != CardData.Intent.ATTACK:
		return
	_jump_random()
	_jumps_left -= 1

func _jump_random() -> void:
	if _combatant == null or _combatant.body3d == null:
		return
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var dir: Vector3 = dirs[randi() % dirs.size()]
	_combatant.body3d.global_position += dir * JUMP_DISTANCE
