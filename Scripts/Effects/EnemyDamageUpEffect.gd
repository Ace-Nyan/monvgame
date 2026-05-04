## EnemyDamageUpEffect — 永久提升自身伤害
class_name EnemyDamageUpEffect
extends CardEffect

@export var amount: int = 2

func apply(ctx: Dictionary) -> void:
	var source: Combatant = ctx.get("source")
	if source == null:
		return
	source.damage_bonus += amount
	source._add_status(&"damage_up", "伤害+%d" % source.damage_bonus)

func describe() -> String:
	return "永久提升自身伤害 %d" % amount
