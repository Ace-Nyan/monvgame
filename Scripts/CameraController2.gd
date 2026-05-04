extends SpringArm3D

@export var mouse_sensitivity: float = 0.002
@export var rotation_smoothness: float = 0.2
@export var mouse_speed: float = 1.0  # 鼠标灵敏度乘数
@export var third_person_length: float = 4.0
@export var first_person_length: float = 0.2
@export var third_person_mesh_path: NodePath = ^"../MeshInstance3D"

var mouse_captured: bool = true
var target_rotation: Vector3 = Vector3.ZERO
var _first_person: bool = false
var _third_person_mesh: Node3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_rotation = rotation
	spring_length = third_person_length
	_third_person_mesh = get_node_or_null(third_person_mesh_path) as Node3D
	if _third_person_mesh:
		_third_person_mesh.visible = true

func _process(delta: float) -> void:
	# 平滑旋转
	rotation = rotation.lerp(target_rotation, rotation_smoothness)
	
	# 检查Alt键（左Alt），大多数用户习惯用左Alt
	if Input.is_key_pressed(KEY_ALT):
		if mouse_captured:
			mouse_captured = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if not mouse_captured:
			mouse_captured = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# 只有在鼠标被捕获时才控制镜头
	if mouse_captured and event is InputEventMouseMotion:
		var mouse_delta = event.relative
		target_rotation.y -= mouse_delta.x * mouse_sensitivity * mouse_speed
		target_rotation.x -= mouse_delta.y * mouse_sensitivity * mouse_speed
		target_rotation.x = clamp(target_rotation.x, -PI/2, PI/4)
	
	# V 键切换第一/第三人称
	if event.is_action_pressed("toggle_view"):
		_first_person = not _first_person
		spring_length = first_person_length if _first_person else third_person_length
		if _third_person_mesh:
			_third_person_mesh.visible = not _first_person
