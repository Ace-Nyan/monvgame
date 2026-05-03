## BlockEffect — 自身获得护盾，本回合内吸收伤害
class_name BlockEffect
extends CardEffect

@export var amount: int = 5

func apply(ctx: Dictionary) -> void:
	var source: Combatant = ctx.get("source")
	if source:
		source.add_block(amount)

func describe() -> String:
	return "获得 %d 点护盾" % amount
