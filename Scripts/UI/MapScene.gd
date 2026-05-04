extends Control

@onready var _nodes_root: VBoxContainer = $Root/Nodes
@onready var _preview: Control = $BattlePreview
@onready var _preview_name: Label = $BattlePreview/Panel/VBox/EncounterName
@onready var _preview_list: VBoxContainer = $BattlePreview/Panel/VBox/EnemyList
@onready var _preview_detail: Label = $BattlePreview/Panel/VBox/EnemyDetail
@onready var _preview_enter: Button = $BattlePreview/Panel/VBox/Buttons/EnterButton
@onready var _preview_detail_button: Button = $BattlePreview/Panel/VBox/Buttons/DetailButton
@onready var _preview_cancel: Button = $BattlePreview/Panel/VBox/Buttons/CancelButton

const TYPE_LABELS := {
	RunState.NODE_BATTLE: "作战",
	RunState.NODE_ELITE: "精英作战",
	RunState.NODE_EVENT: "不期而遇",
	RunState.NODE_SAFEHOUSE: "安全屋",
	RunState.NODE_WISH: "得偿所愿",
	RunState.NODE_SHOP: "商店",
}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_preview_enter.pressed.connect(_on_preview_enter)
	_preview_cancel.pressed.connect(_close_preview)
	_preview_detail_button.pressed.connect(_on_preview_detail)
	_render_route()

func _render_route() -> void:
	for c in _nodes_root.get_children():
		c.queue_free()
	if RunState.is_route_complete():
		var done := Label.new()
		done.text = "本轮已完成"
		_nodes_root.add_child(done)
		var back := Button.new()
		back.text = "返回主界面"
		back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn"))
		_nodes_root.add_child(back)
		return
	for i in RunState.route.size():
		var node_type: StringName = RunState.route[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 44)
		btn.text = _label_for_node(i, node_type)
		btn.disabled = i > RunState.current_index
		btn.pressed.connect(_on_node_pressed.bind(i))
		_nodes_root.add_child(btn)

func _label_for_node(index: int, node_type: StringName) -> String:
	var title: String = String(TYPE_LABELS.get(node_type, "未知"))
	if index < RunState.current_index:
		return "第%d关 - %s (已完成)" % [index + 1, title]
	if index == RunState.current_index:
		return "第%d关 - %s" % [index + 1, title]
	return "第%d关 - %s (锁定)" % [index + 1, title]

func _on_node_pressed(index: int) -> void:
	if index != RunState.current_index:
		return
	var node_type: StringName = RunState.current_node_type()
	match node_type:
		RunState.NODE_BATTLE, RunState.NODE_ELITE:
			RunState.prepare_encounter_for_node(node_type)
			_open_preview()
		RunState.NODE_EVENT:
			get_tree().change_scene_to_file("res://Scenes/Events/EventScene.tscn")
		RunState.NODE_SAFEHOUSE:
			get_tree().change_scene_to_file("res://Scenes/Events/SafehouseScene.tscn")
		RunState.NODE_WISH:
			get_tree().change_scene_to_file("res://Scenes/Events/WishScene.tscn")
		RunState.NODE_SHOP:
			get_tree().change_scene_to_file("res://Scenes/Events/ShopScene.tscn")
		_:
			pass

func _open_preview() -> void:
	if _preview == null:
		return
	_populate_preview()
	_preview.visible = true
	_preview_enter.grab_focus()

func _close_preview() -> void:
	if _preview:
		_preview.visible = false

func _populate_preview() -> void:
	var encounter := RunState.get_current_encounter()
	_preview_name.text = String(encounter.get("name", ""))
	for c in _preview_list.get_children():
		c.queue_free()
	_preview_detail.text = ""
	_preview_detail.visible = false
	_preview_detail_button.text = "查看详情"
	var enemies: Array = encounter.get("enemies", [])
	if enemies.is_empty():
		return
	for e in enemies:
		var info := RunState.get_enemy_info(StringName(e.get("id", "")))
		var name := String(info.get("name", e.get("id", "")))
		var spawn := String(e.get("spawn", "start"))
		var line := "%s x%d" % [name, int(e.get("count", 0))]
		if spawn == "after_clear":
			line += " (追加波次)"
		var label := Label.new()
		label.text = line
		_preview_list.add_child(label)
	if enemies.size() > 0:
		var first: Dictionary = enemies[0] as Dictionary
		var info := RunState.get_enemy_info(StringName(first.get("id", "")))
		_preview_detail.text = _enemy_detail_text(info)

func _enemy_detail_text(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("编号: %s" % info.get("id", ""))
	lines.append("名称: %s" % info.get("name", ""))
	lines.append("属性: %s" % info.get("stats", ""))
	lines.append("特性: %s" % info.get("traits", ""))
	lines.append("攻击: %s" % info.get("attack", ""))
	lines.append("防御: %s" % info.get("defense", ""))
	return "\n".join(lines)

func _on_preview_enter() -> void:
	RunState.confirm_pending_encounter()
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")

func _on_preview_detail() -> void:
	_preview_detail.visible = not _preview_detail.visible
	_preview_detail_button.text = "隐藏详情" if _preview_detail.visible else "查看详情"
