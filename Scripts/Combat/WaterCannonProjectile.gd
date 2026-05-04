extends Area3D
class_name WaterCannonProjectile

@export var speed: float = 4.0
@export var lifetime_sec: float = 6.0
@export var radius: float = 2.0
@export var homing_strength: float = 3.0

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 0.0
var _element: int = Element.Type.WATER
var _source: Combatant
var _target: Combatant
var _elapsed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _previous_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func configure(source: Combatant, direction: Vector3, damage: float, element: int, _range_m: float = 0.0) -> void:
	_source = source
	_target = CombatantRegistry.find_nearest_enemy(source, 999.0)
	_direction = direction.normalized()
	_damage = damage
	_element = element
	_velocity = _direction * speed
	_previous_position = global_position

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime_sec:
		queue_free()
		return
	if _target and _target.is_alive():
		var target_pos := _target.global_position_3d() + Vector3(0, 1.0, 0)
		var desired_dir := (target_pos - global_position).normalized()
		_velocity = _velocity.lerp(desired_dir * speed, min(1.0, homing_strength * delta))
	_previous_position = global_position
	global_position += _velocity * delta
	_check_proximity_hit()

func _check_proximity_hit() -> void:
	if _source == null:
		return
	var target: Combatant = _find_target_near_projectile(radius + 1.0)
	if target == null:
		return
	_explode_at_target(target)

func _find_target_near_projectile(max_distance: float) -> Combatant:
	var best: Combatant = null
	var best_distance: float = max_distance
	for candidate in CombatantRegistry.enemies_of(_source):
		var target := candidate as Combatant
		if target == null or not target.is_alive():
			continue
		var target_pos: Vector3 = target.global_position_3d()
		var planar_delta := Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
		var distance_to_target: float = planar_delta.length()
		var segment_distance: float = _planar_segment_distance_to_target(target_pos)
		distance_to_target = min(distance_to_target, segment_distance)
		if distance_to_target <= best_distance:
			best_distance = distance_to_target
			best = target
	return best

func _planar_segment_distance_to_target(target_pos: Vector3) -> float:
	var start := Vector2(_previous_position.x, _previous_position.z)
	var finish := Vector2(global_position.x, global_position.z)
	var point := Vector2(target_pos.x, target_pos.z)
	var segment := finish - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(finish)
	var t: float = clamp((point - start).dot(segment) / length_sq, 0.0, 1.0)
	var closest: Vector2 = start + segment * t
	return point.distance_to(closest)

func _on_body_entered(body: Node) -> void:
	if _source == null:
		queue_free()
		return
	var target: Combatant = _find_combatant(body)
	if target == null:
		return
	if target.faction == _source.faction:
		return
	_explode_at_target(target)

func _explode_at_target(target: Combatant) -> void:
	if target and target.is_alive():
		var target_pos: Vector3 = target.global_position_3d()
		global_position = Vector3(target_pos.x, global_position.y, target_pos.z)
	_explode()

func _explode() -> void:
	if _source == null:
		queue_free()
		return
	for c in CombatantRegistry.enemies_of(_source):
		if c == null or not c.is_alive():
			continue
		var target_pos: Vector3 = c.global_position_3d()
		var planar_delta := Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
		var dist: float = planar_delta.length()
		if dist <= radius:
			_source.deal_damage_to(c, _damage, _element)
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
