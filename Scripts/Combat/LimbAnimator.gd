## LimbAnimator — Node3D 层级"骨架"动画器
##
## 配合 Humanoid.tscn 使用：身体由若干 Node3D（头/躯干/双手/双腿）组成。
## 每张卡的 anim_id 对应这里的一个动画过程，整个过程秒数由 CardData 的
## windup/active/recovery 帧数决定（与 Combatant 共用 FRAMES_TO_SECONDS）。
##
## 动作通过 Tween 旋转各肢体节点实现，无需任何 .anim 资源。
class_name LimbAnimator
extends Node

@export var head_path: NodePath
@export var torso_path: NodePath
@export var arm_l_path: NodePath
@export var arm_r_path: NodePath
@export var leg_l_path: NodePath
@export var leg_r_path: NodePath

var _head: Node3D
var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D

var _active_tween: Tween

const FRAMES_TO_SECONDS: float = 1.0 / 12.0  # 仅作硬编码兜底；运行时改用 Tuning.frames_to_seconds()

func _ready() -> void:
	_head = get_node_or_null(head_path)
	_torso = get_node_or_null(torso_path)
	_arm_l = get_node_or_null(arm_l_path)
	_arm_r = get_node_or_null(arm_r_path)
	_leg_l = get_node_or_null(leg_l_path)
	_leg_r = get_node_or_null(leg_r_path)

func play_for_card(card: CardData) -> void:
	if card == null:
		return
	var fts: float = Tuning.frames_to_seconds()
	var w: float = max(0.05, float(card.windup_frames) * fts)
	var a: float = max(0.05, float(card.active_frames) * fts)
	var r: float = max(0.05, float(card.recovery_frames) * fts)
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	match String(card.anim_id):
		"swing_r": _build_swing(_arm_r, w, a, r, true)
		"swing_l": _build_swing(_arm_l, w, a, r, true)
		"thrust": _build_thrust(_arm_r, w, a, r)
		"cast": _build_cast(w, a, r)
		"guard": _build_guard(w, a, r)
		"stomp": _build_stomp(w, a, r)
		_: _build_swing(_arm_r, w, a, r, true)

# === 动作样式 ===

## 经典挥砍：windup 抬手 → active 砍下 → recovery 回位
func _build_swing(arm: Node3D, w: float, a: float, r: float, _right: bool) -> void:
	if arm == null:
		return
	var rest: Vector3 = Vector3.ZERO
	var raised: Vector3 = Vector3(deg_to_rad(-130), 0, 0)
	var slammed: Vector3 = Vector3(deg_to_rad(40), 0, 0)
	_active_tween.tween_property(arm, "rotation", raised, w).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(arm, "rotation", slammed, a).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(arm, "rotation", rest, r).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 直刺：拉后 → 突出 → 收回
func _build_thrust(arm: Node3D, w: float, a: float, r: float) -> void:
	if arm == null:
		return
	var rest: Vector3 = Vector3.ZERO
	var pulled: Vector3 = Vector3(deg_to_rad(40), 0, deg_to_rad(20))
	var thrust: Vector3 = Vector3(deg_to_rad(-90), 0, 0)
	_active_tween.tween_property(arm, "rotation", pulled, w)
	_active_tween.tween_property(arm, "rotation", thrust, a).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(arm, "rotation", rest, r)

## 施法：双手举高
func _build_cast(w: float, a: float, r: float) -> void:
	var raised: Vector3 = Vector3(deg_to_rad(-150), 0, 0)
	var rest: Vector3 = Vector3.ZERO
	if _arm_l:
		_active_tween.tween_property(_arm_l, "rotation", raised, w)
	if _arm_r:
		_active_tween.parallel().tween_property(_arm_r, "rotation", raised, w)
	_active_tween.tween_interval(a)
	if _arm_l:
		_active_tween.tween_property(_arm_l, "rotation", rest, r)
	if _arm_r:
		_active_tween.parallel().tween_property(_arm_r, "rotation", rest, r)

## 防御：双手抬至胸前
func _build_guard(w: float, a: float, r: float) -> void:
	var guard: Vector3 = Vector3(deg_to_rad(-80), deg_to_rad(20), deg_to_rad(40))
	var rest: Vector3 = Vector3.ZERO
	if _arm_l:
		_active_tween.tween_property(_arm_l, "rotation", Vector3(guard.x, -guard.y, -guard.z), w)
	if _arm_r:
		_active_tween.parallel().tween_property(_arm_r, "rotation", guard, w)
	_active_tween.tween_interval(a)
	if _arm_l:
		_active_tween.tween_property(_arm_l, "rotation", rest, r)
	if _arm_r:
		_active_tween.parallel().tween_property(_arm_r, "rotation", rest, r)

## 踏步：抬腿落下
func _build_stomp(w: float, a: float, r: float) -> void:
	if _leg_r == null:
		return
	var raised: Vector3 = Vector3(deg_to_rad(-60), 0, 0)
	var rest: Vector3 = Vector3.ZERO
	_active_tween.tween_property(_leg_r, "rotation", raised, w)
	_active_tween.tween_property(_leg_r, "rotation", rest, a)
	_active_tween.tween_interval(r)
