## DamageEffect — 对目标造成元素伤害
class_name DamageEffect
extends CardEffect

@export var amount: int = 6
@export var element: Element.Type = Element.Type.NONE
## 是否使用卡牌的 element 字段（覆盖本地 element）
@export var inherit_card_element: bool = true

func apply(ctx: Dictionary) -> void:
	var target: Combatant = ctx.get("target")
	var source: Combatant = ctx.get("source")
	var card: CardInstance = ctx.get("card")
	if target == null or source == null:
		return
	var elem := element
	if inherit_card_element and card != null:
		elem = card.data.element
	var manager: CombatManager = ctx.get("manager")
	if manager:
		manager.deal_damage(source, target, float(amount), elem, card)

func describe() -> String:
	return "造成 %d 点伤害" % amount
