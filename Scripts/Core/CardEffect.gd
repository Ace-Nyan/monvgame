## CardEffect — 卡牌效果基类（可组合）
##
## 设计哲学：每个效果是一个独立 Resource，可以挂到 CardData.effects 数组里。
## 单卡可叠加多个效果（如「火焰冲击」= 伤害 + 燃烧异常）。
##
## 子类只需重写 apply()，无需关心调度与事件派发。
class_name CardEffect
extends Resource

## 触发时机：默认 ACTIVE 帧
enum Phase { WINDUP, ACTIVE, RECOVERY }

@export var phase: Phase = Phase.ACTIVE

## 由 CombatManager 调用
## ctx 字典格式：
##   { source: Combatant, target: Combatant, card: CardInstance, manager: CombatManager }
func apply(_ctx: Dictionary) -> void:
	pass

## 给 UI 用的描述（子类覆盖）
func describe() -> String:
	return ""
