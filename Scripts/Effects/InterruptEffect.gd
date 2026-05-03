## InterruptEffect — 若目标当前正处于 WINDUP，则取消其卡牌
class_name InterruptEffect
extends CardEffect

@export var fizzle_damage_multiplier: float = 1.5  ## 打断成功后顺带额外伤害

func apply(ctx: Dictionary) -> void:
	var target: Combatant = ctx.get("target")
	var manager: CombatManager = ctx.get("manager")
	if target == null or manager == null:
		return
	manager.interrupt(target, fizzle_damage_multiplier)

func describe() -> String:
	return "若敌人正在前摇，打断之"
