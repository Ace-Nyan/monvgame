## Tuning — 全局调参 autoload
##
## 加载 res://Data/Tuning/default.tres，模组可以放 user://Tuning/default.tres 覆盖。
## 直接通过 Tuning.frames_to_seconds 等访问字段。
extends Node

const DEFAULT_PATH := "res://Data/Tuning/default.tres"
const USER_PATH := "user://Tuning/default.tres"

var data: GameTuning

func _ready() -> void:
	if FileAccess.file_exists(USER_PATH):
		data = load(USER_PATH) as GameTuning
	if data == null:
		data = load(DEFAULT_PATH) as GameTuning
	if data == null:
		push_warning("[Tuning] 无法加载 GameTuning，使用空白默认值")
		data = GameTuning.new()

# === 便捷转发（避免到处写 Tuning.data.xxx）===

func frames_to_seconds() -> float: return data.frames_to_seconds
func recovery_damage_mult() -> float: return data.recovery_damage_mult
func interrupt_bonus_mult() -> float: return data.interrupt_bonus_mult
