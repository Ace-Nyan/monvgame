## RollEffect — 瞬间翻滚并开启极限闪避窗口
class_name RollEffect
extends CardEffect

@export var distance: float = 4.0
@export var dodge_window_sec: float = 0.25

func apply(ctx: Dictionary) -> void:
	var source: Combatant = ctx.get("source")
	if source:
		source.perform_roll(distance, dodge_window_sec)

func describe() -> String:
	return "翻滚并短暂无敌"
