## CardInstance — 一张卡的运行时实例
##
## 同一份 CardData 在抽到时变成 CardInstance；这样既能在 .tres 里编辑数据，
## 又能携带运行时状态（当前帧、当前阶段、是否被打断等）。
class_name CardInstance
extends RefCounted

enum Phase { PENDING, WINDUP, ACTIVE, RECOVERY, DONE, INTERRUPTED }

var data: CardData
var owner: Combatant
var phase: int = Phase.PENDING
var elapsed_frames_in_phase: int = 0
var timeline_start: int = 0     ## 在回合时间轴上的起始 tick

func _init(p_data: CardData = null, p_owner: Combatant = null) -> void:
	data = p_data
	owner = p_owner

func enter_phase(new_phase: int) -> void:
	phase = new_phase
	elapsed_frames_in_phase = 0
	EventBus.card_phase_changed.emit(self, new_phase)

func is_active() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE or phase == Phase.RECOVERY
