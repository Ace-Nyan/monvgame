## CombatantRegistry — 全局战斗者索引（autoload）
##
## 负责：注册/注销 Combatant；按敌对关系/距离/锥形视野查找目标。
extends Node

var all: Array = []                              ## Array[Combatant]

func register(c) -> void:
	if not all.has(c):
		all.append(c)

func unregister(c) -> void:
	all.erase(c)

func enemies_of(c) -> Array:
	var out: Array = []
	for o in all:
		if not is_instance_valid(o):
			continue
		if o == c or not o.is_alive():
			continue
		if o.faction != c.faction:
			out.append(o)
	return out

## 找半径内最近的敌方（不限角度）
func find_nearest_enemy(c, radius: float):
	var best = null
	var best_d := radius
	var origin: Vector3 = c.global_position_3d()
	for o in enemies_of(c):
		var d := origin.distance_to(o.global_position_3d())
		if d < best_d:
			best_d = d
			best = o
	return best

## 在朝向锥形（半角 cone_half_rad，半径 radius）内找最近敌方
func find_target_in_cone(c, radius: float, cone_full_rad: float):
	var best = null
	var best_d := radius
	var origin: Vector3 = c.global_position_3d()
	var fwd: Vector3 = c.forward_dir()
	fwd.y = 0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var cos_half: float = cos(cone_full_rad * 0.5)
	for o in enemies_of(c):
		var to: Vector3 = o.global_position_3d() - origin
		to.y = 0
		var d := to.length()
		if d < 0.01 or d > radius:
			continue
		var dirn: Vector3 = to / d
		if dirn.dot(fwd) < cos_half:
			continue
		if d < best_d:
			best_d = d
			best = o
	# 锥形里没有 → 退化到最近
	if best == null:
		return find_nearest_enemy(c, radius)
	return best
