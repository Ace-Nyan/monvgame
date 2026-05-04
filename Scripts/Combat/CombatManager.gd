extends Node
class_name CombatManager

enum Phase { PLAYER_ATTACK, ENEMY_ATTACK }

@export var player_path: NodePath
@export var base_draw_count: int = 5
@export var enemy_intent_delay_sec: float = 3.0
@export var response_end_delay_sec: float = 8.0

var phase: int = Phase.PLAYER_ATTACK
var player: Combatant
var enemies: Array[Combatant] = []
var _draw_count: int = 5
var _bonus_ap_next_turn: int = 0
var _is_first_turn: bool = true
var response_phase: String = ""
var response_remaining: float = 0.0
var response_intent_title: String = ""
var response_intent_desc: String = ""
var _pending_spawns: Array[Dictionary] = []
var _spawn_index: int = 0

func _ready() -> void:
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.extreme_dodged.connect(_on_extreme_dodged)
	call_deferred("_init_battle")
	set_process(true)

func _process(delta: float) -> void:
	if phase == Phase.ENEMY_ATTACK and response_phase == "response":
		response_remaining = max(0.0, response_remaining - delta)

func _init_battle() -> void:
	_despawn_existing_enemies()
	_spawn_encounter_enemies()
	_collect_combatants()
	_apply_run_state()
	_start_player_attack()

func _despawn_existing_enemies() -> void:
	for c in CombatantRegistry.all:
		var enemy := c as Combatant
		if enemy and enemy.faction == Combatant.Faction.ENEMY:
			if enemy.body3d:
				enemy.body3d.queue_free()
			else:
				enemy.queue_free()
	_spawn_index = 0
	_pending_spawns.clear()

func _spawn_encounter_enemies() -> void:
	var encounter := RunState.get_current_encounter()
	if encounter.is_empty():
		return
	var enemies_def: Array = encounter.get("enemies", [])
	for e in enemies_def:
		var spawn := String(e.get("spawn", "start"))
		if spawn == "start":
			_spawn_enemy_batch(StringName(e.get("id", "")), int(e.get("count", 0)))
		else:
			_pending_spawns.append(e)

func _spawn_enemy_batch(enemy_id: StringName, count: int) -> void:
	for i in range(count):
		_spawn_enemy(enemy_id)

func _spawn_enemy(enemy_id: StringName) -> void:
	var scene := RunState.get_enemy_scene(enemy_id)
	if scene == null:
		return
	var node := scene.instantiate()
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(node)
	if node is Node3D:
		var pos := _next_spawn_pos()
		node.global_position = pos

func _next_spawn_pos() -> Vector3:
	var positions: Array[Vector3] = [Vector3(-6, 1.6, -4), Vector3(0, 1.6, -6), Vector3(6, 1.6, -4)]
	var pos: Vector3 = positions[_spawn_index % positions.size()]
	_spawn_index += 1
	return pos

func _collect_combatants() -> void:
	enemies.clear()
	if player_path != NodePath(""):
		player = get_node_or_null(player_path) as Combatant
	if player == null:
		for c in CombatantRegistry.all:
			if c and c.faction == Combatant.Faction.PLAYER:
				player = c
				break
	for c in CombatantRegistry.all:
		if c and c.faction == Combatant.Faction.ENEMY:
			enemies.append(c)

func _apply_run_state() -> void:
	_draw_count = base_draw_count + RunState.draw_bonus
	if player:
		player.max_hp = RunState.max_hp
		player.max_mp = RunState.max_mp
		player.base_def = RunState.base_def
		player.base_res = RunState.base_res
		player.hp = clampi(RunState.hp, 0, player.max_hp)
		player.set_mana(RunState.mp)
		EventBus.hp_changed.emit(player, player.hp, player.max_hp)
		EventBus.mp_changed.emit(player, player.mp, player.max_mp)
	if RunState.current_node_type() == RunState.NODE_ELITE:
		for e in enemies:
			e.max_hp = int(round(float(e.max_hp) * 1.5))
			e.hp = e.max_hp
			EventBus.hp_changed.emit(e, e.hp, e.max_hp)

func _start_player_attack() -> void:
	phase = Phase.PLAYER_ATTACK
	EventBus.turn_phase_changed.emit(phase)
	response_phase = ""
	response_remaining = 0.0
	response_intent_title = ""
	response_intent_desc = ""
	RunState.reset_turn_bonuses()
	if player:
		player.start_turn()
		player.reset_energy_with_bonus(_bonus_ap_next_turn)
		_bonus_ap_next_turn = 0
		player.draw_cards(_draw_count)
		if _is_first_turn:
			_ensure_card_in_hand(&"roll")
			_is_first_turn = false

func _ensure_card_in_hand(card_id: StringName) -> void:
	if player == null or player.deck == null:
		return
	for inst in player.hand_slots:
		if inst and inst.data and inst.data.id == card_id:
			return
	var card_data: CardData = null
	for i in player.deck.draw_pile.size():
		var c: CardData = player.deck.draw_pile[i]
		if c and c.id == card_id:
			card_data = c
			player.deck.draw_pile.remove_at(i)
			break
	if card_data == null:
		for i in player.deck.discard_pile.size():
			var c: CardData = player.deck.discard_pile[i]
			if c and c.id == card_id:
				card_data = c
				player.deck.discard_pile.remove_at(i)
				break
	if card_data == null:
		return
	var placed: bool = false
	for i in player.hand_slots.size():
		if player.hand_slots[i] == null:
			player.hand_slots[i] = CardInstance.new(card_data, player)
			placed = true
			break
	if not placed:
		var replaced: CardInstance = player.hand_slots[0]
		if replaced and replaced.data:
			player.deck.discard_pile.append(replaced.data)
		player.hand_slots[0] = CardInstance.new(card_data, player)
	EventBus.hand_changed.emit(player)

func end_player_attack() -> void:
	if phase != Phase.PLAYER_ATTACK:
		return
	phase = Phase.ENEMY_ATTACK
	EventBus.turn_phase_changed.emit(phase)
	_start_enemy_attack()

func can_player_cast(card: CardData) -> bool:
	if card == null:
		return false
	return true

func try_player_cast(slot: int) -> bool:
	if player == null:
		return false
	if slot < 0 or slot >= player.hand_slots.size():
		return false
	var inst: CardInstance = player.hand_slots[slot]
	if inst == null:
		return false
	if not can_player_cast(inst.data):
		return false
	var use_mana: bool = phase == Phase.ENEMY_ATTACK
	return player.try_cast(slot, use_mana)

func _start_enemy_attack() -> void:
	response_phase = "enemy"
	response_remaining = response_end_delay_sec
	response_intent_title = ""
	response_intent_desc = ""
	_enemy_attack_sequence()

func _enemy_attack_sequence() -> void:
	await _enemy_actions()
	await get_tree().create_timer(response_end_delay_sec).timeout
	_end_round()

func _enemy_actions() -> void:
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		var ai := e.body3d.get_node_or_null("WaterSlimeAI") as WaterSlimeAI
		if ai:
			ai.prepare_enemy_turn()
		e.reset_energy()
		e.draw_cards(e.hand_size)
		var slot := _find_enemy_attack_slot(e)
		if slot < 0:
			continue
		var inst: CardInstance = e.hand_slots[slot]
		if inst and inst.data:
			response_intent_title = inst.data.display_name
			response_intent_desc = inst.data.description
		await get_tree().create_timer(enemy_intent_delay_sec).timeout
		e.try_cast(slot, false)
		await _wait_until_idle(e)
	response_phase = "response"
	response_intent_title = ""
	response_intent_desc = ""

func _find_enemy_attack_slot(e: Combatant) -> int:
	for i in e.hand_slots.size():
		var inst: CardInstance = e.hand_slots[i]
		if inst == null:
			continue
		if inst.data.intent == CardData.Intent.ATTACK:
			return i
	return -1

func _wait_until_idle(e: Combatant) -> void:
	while e and e.is_casting():
		await get_tree().process_frame

func _end_round() -> void:
	response_phase = ""
	response_remaining = 0.0
	if player:
		player.end_round()
		player.discard_hand_to_pile()
		if not RunState.keep_block:
			player.reset_block()
		if player.pending_judgement_death:
			RunState.max_hp = maxi(1, RunState.max_hp - 10)
			player.max_hp = RunState.max_hp
			player.hp = 0
			EventBus.hp_changed.emit(player, player.hp, player.max_hp)
			EventBus.combatant_died.emit(player)
			return
	for e in enemies:
		if e:
			e.discard_hand_to_pile()
			e.reset_block()
	if _spawn_pending_if_needed():
		return
	if _all_enemies_defeated():
		_end_battle(true)
		return
	_start_player_attack()

func _all_enemies_defeated() -> bool:
	for e in enemies:
		if e and e.is_alive():
			return false
	return true

func _spawn_pending_if_needed() -> bool:
	if not _all_enemies_defeated():
		return false
	if _pending_spawns.is_empty():
		return false
	var next: Dictionary = _pending_spawns.pop_front() as Dictionary
	_spawn_enemy_batch(StringName(next.get("id", "")), int(next.get("count", 0)))
	_collect_combatants()
	_start_player_attack()
	return true

func _end_battle(victory: bool) -> void:
	if player:
		RunState.hp = player.hp
		RunState.mp = player.mp
	if victory:
		var reward := 5
		if RunState.current_node_type() == RunState.NODE_ELITE:
			reward *= 2
		RunState.last_reward_gold = reward
		RunState.gold += reward
	if victory:
		get_tree().change_scene_to_file("res://Scenes/Events/RewardScene.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _on_combatant_died(c: Combatant) -> void:
	if player and c == player:
		_end_battle(false)
		return
	if c and c.faction == Combatant.Faction.ENEMY:
		if c.body3d and is_instance_valid(c.body3d):
			c.body3d.queue_free()
		else:
			c.queue_free()
	if _spawn_pending_if_needed():
		return
	if _all_enemies_defeated():
		_end_battle(true)

func _on_extreme_dodged(c: Combatant) -> void:
	if player and c == player:
		_bonus_ap_next_turn += 1
