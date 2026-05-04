## PlayerCombatController — 玩家热键 → 出牌
##
## 挂在玩家身上，与 Combatant 同级。监听 1/2/3/4 键尝试出对应槽的卡。
extends Node

@export var combatant_path: NodePath = ^"../Combatant"
@export var combat_manager_path: NodePath = ^"../CombatManager"

var _combatant: Combatant
var _manager: CombatManager
var _selected_slot: int = -1
var _queued_cast_slot: int = -1
const SLOT_ACTIONS: Array[StringName] = [&"card_slot_1", &"card_slot_2", &"card_slot_3", &"card_slot_4", &"card_slot_5"]

func _ready() -> void:
	_combatant = get_node_or_null(combatant_path) as Combatant
	_manager = get_node_or_null(combat_manager_path) as CombatManager
	EventBus.hand_changed.connect(_on_hand_changed)
	EventBus.cast_ended.connect(_on_cast_finished)
	EventBus.cast_interrupted.connect(_on_cast_finished)
	EventBus.selected_slot_changed.emit(_selected_slot)

func _unhandled_input(event: InputEvent) -> void:
	if _combatant == null or not _combatant.is_alive():
		return
	if _manager == null:
		return
	for i in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			_select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("card_next"):
		_select_next()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("card_prev"):
		_select_prev()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("card_play"):
		_handle_play()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_play()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("end_turn"):
		_manager.end_player_attack()
		get_viewport().set_input_as_handled()
		return

func _input(event: InputEvent) -> void:
	if _combatant == null or not _combatant.is_alive():
		return
	if _manager == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_play()
		get_viewport().set_input_as_handled()
		return

func _process(_delta: float) -> void:
	if _combatant == null or not _combatant.is_alive():
		return
	if _manager == null:
		return
	if Input.is_action_just_pressed("card_play"):
		_handle_play()

func _select_next() -> void:
	if _combatant == null:
		return
	_select_next_valid(1)

func _select_prev() -> void:
	if _combatant == null:
		return
	_select_next_valid(-1)

func _select_slot(index: int) -> void:
	if _combatant == null:
		return
	if index < 0 or index >= _combatant.hand_slots.size():
		return
	if _combatant.hand_slots[index] == null:
		return
	_selected_slot = index
	EventBus.selected_slot_changed.emit(_selected_slot)

func _select_next_valid(dir: int) -> void:
	if _combatant == null:
		return
	var total: int = _combatant.hand_slots.size()
	if total <= 0:
		return
	var steps: int = 0
	var idx: int = _selected_slot
	if idx < 0:
		idx = 0 if dir > 0 else total - 1
	while steps < total:
		idx = (idx + dir + total) % total
		if _combatant.hand_slots[idx] != null:
			_selected_slot = idx
			EventBus.selected_slot_changed.emit(_selected_slot)
			return
		steps += 1

func _on_hand_changed(c: Combatant) -> void:
	if c != _combatant:
		return
	if _combatant.hand_slots.size() == 0:
		return
	if _selected_slot >= 0 and _selected_slot < _combatant.hand_slots.size() and _combatant.hand_slots[_selected_slot] != null:
		return
	# 不自动选择，等待玩家手动选择

func _select_first_valid() -> void:
	for i in _combatant.hand_slots.size():
		if _combatant.hand_slots[i] != null:
			_selected_slot = i
			EventBus.selected_slot_changed.emit(_selected_slot)
			return

func _handle_play() -> void:
	if _manager == null or _combatant == null:
		return
	if _selected_slot < 0 or _selected_slot >= _combatant.hand_slots.size():
		return
	if _combatant.hand_slots[_selected_slot] == null:
		return
	if not _attempt_cast(_selected_slot):
		_queued_cast_slot = _selected_slot

func _attempt_cast(slot: int) -> bool:
	if _manager == null:
		return false
	return _manager.try_player_cast(slot)

func _on_cast_finished(c: Combatant, _card: CardInstance) -> void:
	if c != _combatant:
		return
	if _queued_cast_slot < 0:
		return
	if _queued_cast_slot >= _combatant.hand_slots.size():
		_queued_cast_slot = -1
		return
	var slot := _queued_cast_slot
	_queued_cast_slot = -1
	_attempt_cast(slot)
	_select_right_or_first(slot)

func _select_right_or_first(prev_slot: int) -> void:
	if _combatant == null:
		return
	for i in range(prev_slot, _combatant.hand_slots.size()):
		if _combatant.hand_slots[i] != null:
			_selected_slot = i
			EventBus.selected_slot_changed.emit(_selected_slot)
			return
	_select_first_valid()
