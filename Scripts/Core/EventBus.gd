## EventBus — 全局事件总线（autoload）
##
## 类似 Aalis EventBus：松耦合的发布/订阅，UI 与战斗系统不直接依赖。
## 任何模块可监听这些信号；UI 通过它响应战斗状态变化。
extends Node

# === 战斗生命周期 ===
signal combat_started(player: Combatant, enemy: Combatant)
signal combat_ended(winner: Combatant)

# === 回合 ===
signal turn_started(turn_index: int)
signal turn_ended(turn_index: int)

# === 卡牌 ===
signal card_drawn(combatant: Combatant, card: CardInstance)
signal card_queued(combatant: Combatant, card: CardInstance)        ## 出牌进入待结算
signal card_phase_changed(card: CardInstance, phase: int)            ## WINDUP/ACTIVE/RECOVERY/DONE
signal card_resolved(card: CardInstance)
signal card_interrupted(card: CardInstance)

# === 数值 ===
signal damage_dealt(source: Combatant, target: Combatant, amount: float, element: int, mitigated: float)
signal block_changed(combatant: Combatant, value: int)
signal hp_changed(combatant: Combatant, hp: int, max_hp: int)
signal resistance_changed(combatant: Combatant)
