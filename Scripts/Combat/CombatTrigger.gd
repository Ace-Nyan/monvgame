## CombatTrigger — 挂在 3D 场景里的"开战"协调器
##
## 监听玩家按 E 键 + 距离敌人 NPC 足够近 -> 启动 CombatManager。
## 战斗期间禁用 3D 输入。
extends Node

@export var player_combatant: Combatant
@export var enemy_combatant: Combatant
@export var trigger_distance: float = 5.0
@export var player_node: Node3D
@export var enemy_node: Node3D

@onready var _ui_scene: PackedScene = preload("res://Scenes/Combat/CombatUI.tscn")
@onready var _hint_label: Label = %CombatHint

var _manager: CombatManager
var _ui: CanvasLayer
var _in_combat: bool = false

func _ready() -> void:
	# 等待 CardRegistry 加载完毕
	await get_tree().process_frame
	_hint_label.visible = false
	EventBus.combat_ended.connect(_on_combat_ended)

func _process(_dt: float) -> void:
	if _in_combat:
		_hint_label.visible = false
		return
	if player_node == null or enemy_node == null:
		return
	var dist := player_node.global_position.distance_to(enemy_node.global_position)
	var in_range := dist <= trigger_distance
	_hint_label.visible = in_range
	if in_range:
		_hint_label.text = "按 [E] 与 %s 开战" % enemy_combatant.display_name

func _unhandled_input(event: InputEvent) -> void:
	if _in_combat:
		return
	if event.is_action_pressed("combat_start"):
		_try_start_combat()

func _try_start_combat() -> void:
	if player_node == null or enemy_node == null:
		return
	if player_node.global_position.distance_to(enemy_node.global_position) > trigger_distance:
		return
	_start_combat()

func _start_combat() -> void:
	_in_combat = true
	# 释放鼠标 + 暂停 3D
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	# 创建 manager（不能 paused 时收消息，需要设置 process_mode）
	_manager = CombatManager.new()
	_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_manager)
	# 创建 UI
	_ui = _ui_scene.instantiate()
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.manager = _manager
	get_tree().root.add_child(_ui)
	# 启动
	_manager.start(player_combatant, enemy_combatant)

func _on_combat_ended(_winner: Combatant) -> void:
	if not _in_combat:
		return
	# 留 1.5 秒让玩家看到结果
	await get_tree().create_timer(1.5, true, false, true).timeout
	_cleanup()

func _cleanup() -> void:
	if _ui:
		_ui.queue_free()
		_ui = null
	if _manager:
		_manager.queue_free()
		_manager = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_in_combat = false
