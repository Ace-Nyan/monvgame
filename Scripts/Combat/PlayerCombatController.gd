## PlayerCombatController — 玩家热键 → 出牌
##
## 挂在玩家身上，与 Combatant 同级。监听 1/2/3/4 键尝试出对应槽的卡。
extends Node

@export var combatant_path: NodePath = ^"../Combatant"

var _combatant: Combatant
const SLOT_ACTIONS: Array[StringName] = [&"card_slot_1", &"card_slot_2", &"card_slot_3", &"card_slot_4"]

func _ready() -> void:
	_combatant = get_node_or_null(combatant_path) as Combatant

func _unhandled_input(event: InputEvent) -> void:
	if _combatant == null or not _combatant.is_alive():
		return
	for i in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			_combatant.try_cast(i)
			get_viewport().set_input_as_handled()
			return
