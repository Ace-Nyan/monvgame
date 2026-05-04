## Combatant — 实时动作模式下的战斗者组件
##
## 数据驱动：所有数值字段来自 @export var data: CombatantData。
## 数值读取统一过 ModifierBus，所以收藏品/事件可以在不改场景的前提下加成。
class_name Combatant
extends Node

enum CastState { IDLE, WINDUP, ACTIVE, RECOVERY }
enum Faction { PLAYER, ENEMY }

## 战斗者数据资源（必填）。可在编辑器面板拖入或在 .tscn 里 ext_resource。
@export var data: CombatantData

# === 运行时状态 ===
var hp: int
var block: int = 0
var ap: float
var resistance: ResistanceProfile
var deck: Deck
var hand_slots: Array = []                       ## 长度 = hand_size

var cast_state: int = CastState.IDLE
var current_card: CardInstance = null
var phase_elapsed: float = 0.0

var body3d: Node3D
var animator: Node
var aggro_target: Combatant = null

# === 缓存的最终数值（_recompute_stats() 时刷新）===
var max_hp: int
var max_ap: int
var ap_regen_per_sec: float
var hand_size: int
var aggro_radius: float
var leash_radius: float

## 兼容字段：旧代码读 c.faction / c.display_name
var faction: int = Faction.ENEMY
var display_name: String = ""

func _ready() -> void:
	if data == null:
		push_error("[Combatant] 节点 %s 缺少 data，无法初始化" % name)
		data = CombatantData.new()
	faction = data.faction
	display_name = data.display_name
	_recompute_stats()
	hp = max_hp
	ap = float(max_ap)
	resistance = data.base_resistance.clone() if data.base_resistance else ResistanceProfile.new()

	body3d = get_parent()
	if body3d:
		animator = body3d.get_node_or_null("Visual/LimbAnimator")
		if animator == null:
			animator = body3d.get_node_or_null("Visual/Humanoid/LimbAnimator")
		# 应用 body_scale / 视觉染色
		var visual := body3d.get_node_or_null("Visual") as Node3D
		if visual:
			visual.scale = data.body_scale
			_apply_tint(visual, data.visual_tint)

	_build_deck()
	CombatantRegistry.register(self)
	EventBus.combatant_registered.emit(self)
	EventBus.hp_changed.emit(self, hp, max_hp)
	EventBus.ap_changed.emit(self, ap, max_ap)
	EventBus.resistance_changed.emit(self)

	for i in hand_size:
		_draw_to_first_empty_slot()

	# 收藏品 / 修饰符变化时重算上限
	EventBus.modifier_added.connect(_on_modifier_changed)
	EventBus.modifier_removed.connect(_on_modifier_changed)

func _exit_tree() -> void:
	CombatantRegistry.unregister(self)
	EventBus.combatant_unregistered.emit(self)

# === 数值计算（核心：把基础值过 ModifierBus）===

func _stat_ctx() -> Dictionary:
	return {
		"faction": data.faction,
		"enemy_id": data.id if data.faction == Faction.ENEMY else &"",
		"player_id": data.id if data.faction == Faction.PLAYER else &"",
	}

func _recompute_stats() -> void:
	var ctx := _stat_ctx()
	var hp_key: StringName = &"player_max_hp" if data.faction == Faction.PLAYER else &"enemy_max_hp"
	var ap_key: StringName = &"player_max_ap" if data.faction == Faction.PLAYER else &"enemy_max_ap"
	var regen_key: StringName = &"player_ap_regen" if data.faction == Faction.PLAYER else &"enemy_ap_regen"
	var hand_key: StringName = &"player_hand_size" if data.faction == Faction.PLAYER else &"enemy_hand_size"

	max_hp = ModifierBus.compute_int(hp_key, data.max_hp, ctx)
	max_ap = ModifierBus.compute_int(ap_key, data.max_ap, ctx)
	ap_regen_per_sec = ModifierBus.compute(regen_key, data.ap_regen_per_sec, ctx)
	hand_size = ModifierBus.compute_int(hand_key, data.hand_size, ctx)
	if data.faction == Faction.ENEMY:
		aggro_radius = ModifierBus.compute(&"enemy_aggro_radius", data.aggro_radius, ctx)
		leash_radius = ModifierBus.compute(&"enemy_leash_radius", data.leash_radius, ctx)
	else:
		aggro_radius = 0.0
		leash_radius = 0.0

func _on_modifier_changed(_id, _key = null) -> void:
	# 只刷新影响数值的字段；当前 hp 不超过新的 max_hp
	var old_max_hp := max_hp
	_recompute_stats()
	if hp > max_hp:
		hp = max_hp
	# 如果 max_hp 变大且玩家此时满血，自动补满（仅玩家）
	if data.faction == Faction.PLAYER and old_max_hp > 0 and hp == old_max_hp and max_hp > old_max_hp:
		hp = max_hp
	EventBus.hp_changed.emit(self, hp, max_hp)
	EventBus.ap_changed.emit(self, ap, max_ap)

# === 牌堆 ===

func _build_deck() -> void:
	var cards: Array[CardData] = []
	for id in data.starting_card_ids:
		var c := CardRegistry.get_card(id)
		if c:
			cards.append(c)
			for k in c.resonance.keys():
				resistance.add_resistance(int(k), float(c.resonance[k]))
	deck = Deck.new(self, cards)
	hand_slots.resize(hand_size)
	for i in hand_size:
		hand_slots[i] = null

# === 帧循环 ===

func _process(delta: float) -> void:
	if cast_state == CastState.IDLE and ap < float(max_ap):
		ap = min(float(max_ap), ap + ap_regen_per_sec * delta)
		EventBus.ap_changed.emit(self, ap, max_ap)
	if cast_state != CastState.IDLE:
		phase_elapsed += delta
		_tick_cast()

func _tick_cast() -> void:
	if current_card == null:
		_finish_cast()
		return
	var d := current_card.data
	var fts: float = Tuning.frames_to_seconds()
	var w := float(d.windup_frames) * fts
	var a := float(d.active_frames) * fts
	var r := float(d.recovery_frames) * fts
	match cast_state:
		CastState.WINDUP:
			if phase_elapsed >= w:
				_enter_phase(CastState.ACTIVE)
				_resolve_active()
		CastState.ACTIVE:
			if phase_elapsed >= a:
				_enter_phase(CastState.RECOVERY)
		CastState.RECOVERY:
			if phase_elapsed >= r:
				_finish_cast()

# === 公开 API ===

func try_cast(slot: int) -> bool:
	if cast_state != CastState.IDLE:
		return false
	if slot < 0 or slot >= hand_slots.size():
		return false
	var inst: CardInstance = hand_slots[slot]
	if inst == null:
		return false
	if ap < float(inst.data.cost):
		return false
	ap -= float(inst.data.cost)
	EventBus.ap_changed.emit(self, ap, max_ap)
	hand_slots[slot] = null
	deck.discard_pile.append(inst.data)
	EventBus.hand_changed.emit(self)
	current_card = inst
	_enter_phase(CastState.WINDUP)
	EventBus.cast_started.emit(self, inst)
	if animator:
		animator.play_for_card(inst.data)
	return true

func is_casting() -> bool:
	return cast_state != CastState.IDLE

func add_block(amount: int) -> void:
	block += amount
	EventBus.block_changed.emit(self, block)

func take_damage(raw_amount: float, element: int) -> float:
	var mitigated := resistance.mitigate(raw_amount, element)
	if cast_state == CastState.RECOVERY:
		mitigated *= Tuning.recovery_damage_mult()
	if cast_state == CastState.WINDUP:
		_interrupt()
	var remaining := mitigated
	if block > 0:
		var absorbed: float = min(float(block), remaining)
		block -= int(ceil(absorbed))
		remaining -= absorbed
		EventBus.block_changed.emit(self, block)
	if remaining > 0:
		hp = max(0, hp - int(ceil(remaining)))
		EventBus.hp_changed.emit(self, hp, max_hp)
		if hp <= 0:
			EventBus.combatant_died.emit(self)
	return mitigated

func is_alive() -> bool:
	return hp > 0

func global_position_3d() -> Vector3:
	if body3d:
		return body3d.global_position
	return Vector3.ZERO

func forward_dir() -> Vector3:
	if body3d:
		return -body3d.global_basis.z
	return Vector3.FORWARD

@warning_ignore("unused_parameter")
func deal_damage_to(target: Combatant, amount: float, element: int) -> void:
	if target == null or not target.is_alive():
		return
	var matchup := Element.matchup_multiplier(element, Element.Type.NONE)
	var raw := amount * matchup
	var dealt := target.take_damage(raw, element)
	EventBus.damage_dealt.emit(self, target, amount, element, dealt)

# === 兼容字段访问（display_name / faction / starting_card_ids 等）===

func get_display_name() -> String:
	return data.display_name if data else ""

func get_faction() -> int:
	return data.faction if data else Faction.ENEMY

# === 内部 ===

func _enter_phase(new_state: int) -> void:
	cast_state = new_state
	phase_elapsed = 0.0
	EventBus.cast_phase_changed.emit(self, current_card, new_state)

func _resolve_active() -> void:
	if current_card == null:
		return
	var target := _resolve_target(current_card.data)
	var ctx := {
		"source": self,
		"target": target,
		"card": current_card,
	}
	for e: CardEffect in current_card.data.effects:
		if e.phase == CardEffect.Phase.ACTIVE:
			e.apply(ctx)

func _resolve_target(d: CardData) -> Combatant:
	match d.target_kind:
		CardData.Target.SELF: return self
		CardData.Target.ENEMY:
			return CombatantRegistry.find_target_in_cone(self, d.range_m, deg_to_rad(d.aim_cone_deg))
	return null

func _interrupt() -> void:
	if current_card:
		EventBus.cast_interrupted.emit(self, current_card)
	_finish_cast()

func _finish_cast() -> void:
	if current_card:
		EventBus.cast_ended.emit(self, current_card)
	cast_state = CastState.IDLE
	current_card = null
	phase_elapsed = 0.0
	_draw_to_first_empty_slot()

func _draw_to_first_empty_slot() -> void:
	for i in hand_slots.size():
		if hand_slots[i] == null:
			var drawn := deck.draw(1)
			if drawn.size() > 0:
				hand_slots[i] = drawn[0]
				EventBus.card_drawn.emit(self, drawn[0])
			break
	EventBus.hand_changed.emit(self)

func _apply_tint(node: Node, tint: Color) -> void:
	if tint == Color(1, 1, 1, 1):
		return
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		var existing := mesh.get_active_material(0)
		if existing is StandardMaterial3D:
			var dup: StandardMaterial3D = existing.duplicate()
			dup.albedo_color = dup.albedo_color * tint
			mesh.material_override = dup
	for child in node.get_children():
		_apply_tint(child, tint)
