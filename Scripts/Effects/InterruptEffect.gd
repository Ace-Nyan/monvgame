## InterruptEffect — 若目标当前正处于 WINDUP，则取消其卡牌
class_name InterruptEffect
extends CardEffect

@export var fizzle_damage_multiplier: float = 1.5  ## 打断成功后顺带额外伤害

func apply(ctx: Dictionary) -> void:
	var target: Combatant = ctx.get("target")
	var source: Combatant = ctx.get("source")
	if target == null:
		return
	# 仅在目标处于 WINDUP 时打断
	if target.cast_state == Combatant.CastState.WINDUP:
		target._interrupt()
		if source:
			source.deal_damage_to(target, fizzle_damage_multiplier * 2.0, Element.Type.NONE)

func describe() -> String:
	return "若敌人正在前摇，打断之"
