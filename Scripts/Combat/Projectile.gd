extends Area3D
class_name Projectile

@export var speed: float = 6.0
@export var lifetime_sec: float = 6.0
@export var projectile_gravity: float = 1.0

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 0.0
var _element: int = Element.Type.NONE
var _source: Combatant
var _elapsed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _range_m: float = 0.0
var _traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func configure(source: Combatant, direction: Vector3, damage: float, element: int, range_m: float = 0.0) -> void:
	_source = source
	_direction = direction.normalized()
	_damage = damage
	_element = element
	_velocity = _direction * speed
	_range_m = max(0.0, range_m)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime_sec:
		queue_free()
		return
	var step := _velocity * delta
	_traveled += Vector3(step.x, 0, step.z).length()
	if _range_m > 0.0 and _traveled > _range_m:
		_velocity.y -= projectile_gravity * delta
	global_position += _velocity * delta

func _on_body_entered(body: Node) -> void:
	if _source == null:
		queue_free()
		return
	var target: Combatant = _find_combatant(body)
	if target == null:
		return
	if target.faction == _source.faction:
		return
	if target.dodge_window_active:
		target.on_extreme_dodge()
		queue_free()
		return
	_source.deal_damage_to(target, _damage, _element)
	queue_free()

func _find_combatant(node: Node) -> Combatant:
	if node == null:
		return null
	var c: Combatant = node.get_node_or_null("Combatant") as Combatant
	if c:
		return c
	var parent: Node = node.get_parent()
	if parent:
		return parent.get_node_or_null("Combatant") as Combatant
	return null
