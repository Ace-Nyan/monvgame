## EventBus — 全局事件总线（autoload）
##
## 实时动作模式：无"回合"概念，只有连续的 AP 与施法状态。
## UI 与战斗逻辑通过这些信号松耦合。
extends Node

# === 战斗者生命周期 ===
signal combatant_registered(c)
signal combatant_unregistered(c)
signal combatant_died(c)

# === 警戒/脱战 ===
signal aggro_started(enemy, target)
signal aggro_lost(enemy)

# === 施法状态 ===
signal cast_started(c, card)
signal cast_phase_changed(c, card, phase)
signal cast_ended(c, card)
signal cast_interrupted(c, card)

# === 数值 ===
signal damage_dealt(source, target, amount, element, mitigated)
signal block_changed(c, value)
signal hp_changed(c, hp, max_hp)
signal ap_changed(c, ap, max_ap)
signal resistance_changed(c)

# === 牌堆 ===
signal hand_changed(c)
signal card_drawn(c, card)
