## CardInstance — 一张卡的运行时实例
##
## 同一份 CardData 在抽到时变成 CardInstance，挂在 Combatant 的手牌槽里。
## 实时模型下卡的 phase 由 Combatant 状态机驱动，CardInstance 只是数据载体。
class_name CardInstance
extends RefCounted

var data: CardData
var owner_ref: WeakRef            ## Combatant，用 WeakRef 避免循环引用

func _init(p_data: CardData = null, p_owner = null) -> void:
	data = p_data
	if p_owner != null:
		owner_ref = weakref(p_owner)

func owner_combatant():
	if owner_ref:
		return owner_ref.get_ref()
	return null
