extends SceneTree
func _init():
	root.ready.connect(_after)

func _after():
	await create_timer(0.4).timeout
	RelicRegistry.collect(&"iron_band")
	await create_timer(0.1).timeout
	for c in CombatantRegistry.all:
		print("[%s] faction=%d max_hp=%d (base=%d) max_ap=%d ap_regen=%.2f move=%.2f" % [
			c.display_name, c.faction, c.max_hp, c.data.max_hp, c.max_ap, c.ap_regen_per_sec, c.data.ai_move_speed,
		])
	quit()
