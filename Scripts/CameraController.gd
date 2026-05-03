extends SpringArm3D

@export var mouse_sensitivity: float = 0.01

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		rotation.y -= mouse_delta.x * mouse_sensitivity
		rotation.x -= mouse_delta.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, -PI/2,PI/4)
