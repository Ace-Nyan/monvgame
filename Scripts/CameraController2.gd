extends SpringArm3D

@export var mouse_sensitivity: float = 0.002
@export var rotation_smoothness: float = 0.2
@export var mouse_speed: float = 1.0  # 鼠标灵敏度乘数

var mouse_captured: bool = true
var target_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_rotation = rotation

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
	
	# ESC键切换（可选功能）
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		mouse_captured = not mouse_captured
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
