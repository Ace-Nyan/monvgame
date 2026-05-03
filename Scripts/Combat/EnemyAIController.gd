## EnemyAIController — 敌人 AI（警戒 + 接敌 + 出牌）
##
## 行为状态机：
##   IDLE: 周期性扫描，玩家进入 aggro_radius → CHASE
##   CHASE: 朝玩家移动；进入 desired_range 范围 → ATTACK
##   ATTACK: 选第一张可用且有效的手牌出招；冷却后回 CHASE
##   出 leash_radius → IDLE
extends Node

@export var combatant_path: NodePath = ^"../Combatant"
@export var move_speed: float = 2.5
@export var attack_check_interval: float = 0.4

var _combatant: Combatant
var _body: CharacterBody3D
var _state: int = 0  # 0 idle, 1 chase, 2 attack
var _scan_timer: float = 0.0
var _target = null

func _ready() -> void:
	_combatant = get_node_or_null(combatant_path) as Combatant
	if _combatant:
		_body = _combatant.body3d as CharacterBody3D

func _physics_process(delta: float) -> void:
	if _combatant == null or not _combatant.is_alive():
		return
	if _body == null:
		return
	# 重力（简单）
	if not _body.is_on_floor():
		_body.velocity.y -= 30.0 * delta
	else:
		_body.velocity.y = 0
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = attack_check_interval
		_rescan()
	match _state:
		0:
			_body.velocity.x = 0
			_body.velocity.z = 0
		1:
			_chase(delta)
		2:
			_attack(delta)
	_body.move_and_slide()

func _rescan() -> void:
	# 寻找最近敌方（玩家阵营）
	if _combatant == null:
		return
	var nearest = CombatantRegistry.find_nearest_enemy(_combatant, _combatant.leash_radius)
	if nearest == null:
		if _state != 0:
			EventBus.aggro_lost.emit(_combatant)
		_state = 0
		_target = null
		return
	var dist = _combatant.global_position_3d().distance_to(nearest.global_position_3d())
	if _state == 0 and dist <= _combatant.aggro_radius:
		EventBus.aggro_started.emit(_combatant, nearest)
		_state = 1
		_target = nearest
	elif _state != 0:
		_target = nearest
		# 接敌距离：取手牌中最大射程，至少 1.6
		var desired := _max_hand_range()
		if dist <= desired:
			_state = 2
		else:
			_state = 1

func _max_hand_range() -> float:
	var r := 1.6
	for c in _combatant.hand_slots:
		if c != null and c.data.range_m > r:
			r = c.data.range_m
	return r

func _chase(delta: float) -> void:
	if _target == null:
		return
	var to: Vector3 = _target.global_position_3d() - _body.global_position
	to.y = 0
	if to.length() < 0.1:
		return
	to = to.normalized()
	_body.velocity.x = to.x * move_speed
	_body.velocity.z = to.z * move_speed
	# 朝向目标
	_face_dir(to)

func _attack(_delta: float) -> void:
	_body.velocity.x = 0
	_body.velocity.z = 0
	if _target:
		var to: Vector3 = _target.global_position_3d() - _body.global_position
		to.y = 0
		if to.length() > 0.05:
			_face_dir(to.normalized())
	if _combatant.is_casting():
		return
	# 选第一张能打出的牌
	for i in _combatant.hand_slots.size():
		var inst = _combatant.hand_slots[i]
		if inst == null:
			continue
		if _combatant.ap < float(inst.data.cost):
			continue
		_combatant.try_cast(i)
		break

func _face_dir(dir: Vector3) -> void:
	var yaw := atan2(dir.x, dir.z)
	# 让前向 -Z 对准目标 → 旋转 yaw + PI
	_body.rotation.y = yaw + PI
