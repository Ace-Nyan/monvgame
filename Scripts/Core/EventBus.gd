## EventBus — 全局事件总线（autoload）
##
## 实时动作模式：无"回合"概念，只有连续的 AP 与施法状态。
## UI 与战斗逻辑通过这些信号松耦合。
extends Node

# === 战斗者生命周期 ===
@warning_ignore("unused_signal")
signal combatant_registered(c)
@warning_ignore("unused_signal")
signal combatant_unregistered(c)
@warning_ignore("unused_signal")
signal combatant_died(c)

# === 警戒/脱战 ===
@warning_ignore("unused_signal")
signal aggro_started(enemy, target)
@warning_ignore("unused_signal")
signal aggro_lost(enemy)

# === 施法状态 ===
@warning_ignore("unused_signal")
signal cast_started(c, card)
@warning_ignore("unused_signal")
signal cast_phase_changed(c, card, phase)
@warning_ignore("unused_signal")
signal cast_ended(c, card)
@warning_ignore("unused_signal")
signal cast_interrupted(c, card)

# === 数值 ===
@warning_ignore("unused_signal")
signal damage_dealt(source, target, amount, element, mitigated)
@warning_ignore("unused_signal")
signal block_changed(c, value)
@warning_ignore("unused_signal")
signal hp_changed(c, hp, max_hp)
@warning_ignore("unused_signal")
signal ap_changed(c, ap, max_ap)
@warning_ignore("unused_signal")
signal mp_changed(c, mp, max_mp)
@warning_ignore("unused_signal")
signal resistance_changed(c)

# === 状态/增益 ===
@warning_ignore("unused_signal")
signal statuses_changed(c)

# === 牌堆 ===
@warning_ignore("unused_signal")
signal hand_changed(c)
@warning_ignore("unused_signal")
signal card_drawn(c, card)

# === 回合与选择 ===
@warning_ignore("unused_signal")
signal turn_phase_changed(phase)
@warning_ignore("unused_signal")
signal selected_slot_changed(slot_index)

# === 闪避 ===
@warning_ignore("unused_signal")
signal extreme_dodged(c)
