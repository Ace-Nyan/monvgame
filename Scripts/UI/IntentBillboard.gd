## IntentBillboard — 敌人头顶世界空间状态指示
##
## 显示：HP 条 + 当前正在施法的卡名 + 阶段（前摇/释放/后摇）。
## 用 Sprite3D + SubViewport 风格太重，用 Label3D + 自绘 MeshInstance3D 简单做。
## 实际实现：用一个 Label3D（始终面向相机）显示文本，HP 条由两个 MeshInstance3D 组成。
extends Node3D

@export var hp_bar_width: float = 1.5
@export var hp_bar_height: float = 0.12

var _combatant: Combatant
var _label: Label3D
var _hp_text: Label3D
var _hp_bg: MeshInstance3D
var _hp_fg: MeshInstance3D
var _hp_fg_mat: StandardMaterial3D
var _status_label: Label3D

func _ready() -> void:
	# HP 背景
	_hp_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(hp_bar_width, hp_bar_height)
	_hp_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0, 0, 0, 0.7)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	_hp_bg.material_override = bg_mat
	add_child(_hp_bg)

	# HP 前景
	_hp_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(hp_bar_width, hp_bar_height)
	_hp_fg.mesh = fg_mesh
	_hp_fg_mat = StandardMaterial3D.new()
	_hp_fg_mat.albedo_color = Color(0.85, 0.2, 0.2)
	_hp_fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fg_mat.no_depth_test = true
	_hp_fg.material_override = _hp_fg_mat
	_hp_fg.position = Vector3(0, 0, 0.001)
	add_child(_hp_fg)

	# Intent label
	_label = Label3D.new()
	_label.text = ""
	_label.position = Vector3(0, hp_bar_height * 1.9, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.005
	_label.modulate = Color(1, 0.95, 0.7)
	_label.outline_modulate = Color(0, 0, 0, 1)
	_label.outline_size = 8
	add_child(_label)

	# HP 数值
	_hp_text = Label3D.new()
	_hp_text.text = ""
	_hp_text.position = Vector3(0, hp_bar_height * 0.9, 0)
	_hp_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_text.no_depth_test = true
	_hp_text.fixed_size = false
	_hp_text.pixel_size = 0.005
	_hp_text.modulate = Color(0.95, 0.95, 0.95)
	_hp_text.outline_modulate = Color(0, 0, 0, 1)
	_hp_text.outline_size = 8
	add_child(_hp_text)

	# 状态标签
	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.position = Vector3(0, -hp_bar_height * 1.2, 0)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.fixed_size = false
	_status_label.pixel_size = 0.004
	_status_label.modulate = Color(0.9, 0.9, 0.95)
	_status_label.outline_modulate = Color(0, 0, 0, 1)
	_status_label.outline_size = 6
	add_child(_status_label)

func bind(c: Combatant) -> void:
	_combatant = c
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.cast_started.connect(_on_cast_started)
	EventBus.cast_phase_changed.connect(_on_cast_phase_changed)
	EventBus.cast_ended.connect(_on_cast_ended)
	EventBus.cast_interrupted.connect(_on_cast_ended)
	EventBus.statuses_changed.connect(_on_statuses_changed)
	_refresh_hp()
	_refresh_status()

func _refresh_hp() -> void:
	if _combatant == null:
		return
	var pct: float = clamp(float(_combatant.hp) / float(_combatant.max_hp), 0.0, 1.0)
	_hp_fg.scale.x = pct
	_hp_fg.position.x = -hp_bar_width * 0.5 * (1.0 - pct)
	_hp_text.text = "%d / %d" % [_combatant.hp, _combatant.max_hp]

func _on_hp_changed(c: Combatant, _hp: int, _max_hp: int) -> void:
	if c == _combatant:
		_refresh_hp()

func _on_cast_started(c: Combatant, card: CardInstance) -> void:
	if c == _combatant:
		_label.text = "[前摇] " + card.data.display_name

func _on_cast_phase_changed(c: Combatant, card: CardInstance, phase: int) -> void:
	if c != _combatant:
		return
	match phase:
		Combatant.CastState.WINDUP: _label.text = "[前摇] " + card.data.display_name
		Combatant.CastState.ACTIVE: _label.text = "[释放] " + card.data.display_name
		Combatant.CastState.RECOVERY: _label.text = "[后摇] " + card.data.display_name

func _on_cast_ended(c: Combatant, _card) -> void:
	if c == _combatant:
		_label.text = ""

func _on_statuses_changed(c: Combatant) -> void:
	if c == _combatant:
		_refresh_status()

func _refresh_status() -> void:
	if _combatant == null:
		return
	_status_label.text = _combatant.status_text()
