## GameTuning — 全局可调常量
##
## 所有"以前在代码里写死"的数值都搬到这里，以 .tres 资源形式存在 Data/Tuning/。
## 模组通过把同名 .tres 放到 user://Tuning/ 来覆盖。
class_name GameTuning
extends Resource

@export_group("时间 / 帧率")
## 1 帧 = 多少秒（用于把 CardData 的 windup/active/recovery 帧数换算为秒）
@export var frames_to_seconds: float = 1.0 / 12.0

@export_group("受伤修正")
## 后摇期被打中受伤倍率
@export var recovery_damage_mult: float = 1.5
## 打断成功后附加伤害倍率（被 InterruptEffect 使用）
@export var interrupt_bonus_mult: float = 2.0

@export_group("AP / 牌堆默认值")
@export var default_player_max_hp: int = 30
@export var default_player_max_ap: int = 3
@export var default_player_ap_regen: float = 0.7
@export var default_player_hand_size: int = 4

@export_group("AI 默认值")
@export var default_aggro_radius: float = 7.0
@export var default_leash_radius: float = 14.0
@export var default_ai_move_speed: float = 2.5
@export var default_ai_check_interval: float = 0.4

@export_group("元素相克")
## 默认相克倍率（强）。Element.gd 现在写死 2.0，这里允许全局调
@export var matchup_strong_mult: float = 2.0
@export var matchup_weak_mult: float = 0.5
