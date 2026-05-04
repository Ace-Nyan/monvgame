## Combatant — 实时动作模式下的战斗者组件
##
## 设计哲学（参考 Aalis）：
##   - 自身只负责"我是谁、能干什么、当前状态"，不持有具体战斗逻辑
##   - 通过 EventBus 广播状态变化，让 UI/AI/特效层各自响应
##   - 卡牌效果（CardEffect）由本组件在 ACTIVE 阶段反向调用
##
## 必须挂在 CharacterBody3D（或带有 Node3D 父级）下，因为施法会用到位置朝向。
class_name Combatant
extends Node

enum CastState { IDLE, WINDUP, ACTIVE, RECOVERY }
enum Faction { PLAYER, ENEMY }

# === 静态配置（@export 可在编辑器或 .tres 里改）===
@export var display_name: String = "战士"
@export var faction: Faction = Faction.ENEMY
@export var max_hp: int = 30
@export var max_ap: int = 3
@export var max_mp: int = 30
@export var ap_regen_per_sec: float = 0.7        ## 每秒回复 AP
@export var hand_size: int = 10
@export var aggro_radius: float = 8.0            ## 进入此范围被警戒
@export var leash_radius: float = 16.0           ## 超出此范围脱战

@export_group("初始牌库（CardData id 列表）")
@export var starting_card_ids: Array[StringName] = []

@export_group("基础抗性")
@export var dominant_element: Element.Type = Element.Type.NONE
@export var base_def: int = 0
@export var base_res: int = 0
@export var immune_elements: Array[int] = []

# === 运行时状态 ===
var hp: int
var block: int = 0
var ap: float
var mp: int
var pending_ignore_magic_resist: Dictionary = {}
var deck: Deck
var hand_slots: Array = []                       ## 长度 = hand_size，元素是 CardInstance 或 null

var cast_state: int = CastState.IDLE
var current_card: CardInstance = null
var phase_elapsed: float = 0.0                   ## 当前阶段已过秒数

var dodge_window_active: bool = false
var _dodge_window_id: int = 0

var magic_manual_active: bool = false
var witch_form_active: bool = false
var turn_magic_damage_mult: float = 1.0
var next_turn_magic_damage_mult: float = 1.0
var pending_judgement_death: bool = false
var all_damage_true: bool = false
var debuff_magic_flat: int = 0
var debuff_physical_flat: int = 0
var damage_bonus: int = 0
var _status_labels: Dictionary = {}
var _retain_card_ids: Dictionary = {}
var _return_next_turn_ids: Array[StringName] = []
var _magic_barrage_count: int = 0

var body3d: Node3D                               ## 父级 Node3D，提供位置朝向
var animator: Node                               ## 同一父级下的肢体动画器（LimbAnimator，可为空）
var aggro_target: Combatant = null
var _visual_root: Node3D
var _visual_base_scale: Vector3 = Vector3.ONE
var _hit_meshes: Array[MeshInstance3D] = []
var _hit_materials: Array[StandardMaterial3D] = []
var _hit_material_colors: Array[Color] = []
var _hit_tween: Tween

const FRAMES_TO_SECONDS: float = 1.0 / 12.0      ## 1 frame ≈ 0.083 秒（每秒 12 帧）

func _ready() -> void:
	hp = max_hp
	ap = float(max_ap)
	mp = max_mp
	# 解析所属 3D 节点
	body3d = get_parent()
	if body3d:
		animator = body3d.get_node_or_null("Visual/LimbAnimator")
		if animator == null:
			animator = body3d.get_node_or_null("Visual/Humanoid/LimbAnimator")
		_setup_hit_feedback()
	# 构建牌库
	_build_deck()
	# 注册到 CombatantRegistry（用于互查 / AI 寻敌）
	CombatantRegistry.register(self)
	EventBus.combatant_registered.emit(self)
	EventBus.hp_changed.emit(self, hp, max_hp)
	EventBus.ap_changed.emit(self, ap, max_ap)
	# 手牌初始化由 CombatManager 管理

func _exit_tree() -> void:
	CombatantRegistry.unregister(self)
	EventBus.combatant_unregistered.emit(self)

func _build_deck() -> void:
	var cards: Array[CardData] = []
	var ids: Array[StringName] = starting_card_ids
	if faction == Faction.PLAYER:
		if RunState.player_deck_ids.is_empty():
			RunState.player_deck_ids = starting_card_ids.duplicate()
		ids = RunState.player_deck_ids
	for id in ids:
		var c := CardRegistry.get_card(id)
		if c:
			cards.append(c)
			# 共鸣系统已移除
	deck = Deck.new(self, cards)
	hand_slots.resize(hand_size)
	for i in hand_size:
		hand_slots[i] = null

# === 帧循环 ===

func _process(delta: float) -> void:
	# 施法状态推进
	if cast_state != CastState.IDLE:
		phase_elapsed += delta
		_tick_cast()

func _tick_cast() -> void:
	if current_card == null:
		_finish_cast()
		return
	var d := current_card.data
	var w := float(d.windup_frames) * FRAMES_TO_SECONDS
	var a := float(d.active_frames) * FRAMES_TO_SECONDS
	var r := float(d.recovery_frames) * FRAMES_TO_SECONDS
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

## 玩家或 AI 调用：尝试用槽位 slot 的卡施法
func try_cast(slot: int, use_mana: bool = false) -> bool:
	if cast_state != CastState.IDLE:
		return false
	if slot < 0 or slot >= hand_slots.size():
		return false
	var inst: CardInstance = hand_slots[slot]
	if inst == null:
		return false
	var effective_cost: int = inst.data.cost
	if inst.data.id == &"magic_barrage":
		var x_cost := mp if use_mana else int(floor(ap))
		if x_cost <= 0:
			return false
		effective_cost = x_cost
		_magic_barrage_count = x_cost
	if faction == Faction.PLAYER and RunState.relic_witch_hat:
		if inst.data.element == Element.Type.WATER and not RunState.turn_witch_hat_water_used:
			effective_cost = maxi(0, effective_cost - 1)
	if use_mana:
		if mp < effective_cost:
			return false
		mp -= effective_cost
		EventBus.mp_changed.emit(self, mp, max_mp)
	else:
		if ap < float(effective_cost):
			return false
		ap -= float(effective_cost)
		EventBus.ap_changed.emit(self, ap, max_ap)
	# 移除手牌槽，进入弃堆（除非 exhaust）
	hand_slots[slot] = null
	if inst.data and not inst.data.exhaust:
		deck.discard_pile.append(inst.data)
	_compact_hand()
	EventBus.hand_changed.emit(self)
	# 启动状态机
	current_card = inst
	_enter_phase(CastState.WINDUP)
	EventBus.cast_started.emit(self, inst)
	if animator:
		animator.play_for_card(inst.data)
	if faction == Faction.PLAYER and RunState.relic_witch_hat:
		match inst.data.element:
			Element.Type.FIRE:
				RunState.turn_witch_hat_fire_mult += 0.2
			Element.Type.WATER:
				RunState.turn_witch_hat_water_used = true
			Element.Type.GRASS:
				draw_cards(1)
	return true

func is_casting() -> bool:
	return cast_state != CastState.IDLE

## 添加块/吸收伤害
func add_block(amount: int) -> void:
	block += amount
	EventBus.block_changed.emit(self, block)

func take_damage(raw_amount: float, element: int, is_true: bool = false) -> float:
	if immune_elements.has(element):
		return 0.0
	var mitigated := _compute_damage(raw_amount, element, is_true)
	if witch_form_active:
		mitigated *= 0.5 if RunState.relic_witch_tears else 2.0
	# 后摇期间受伤放大 1.5x
	if cast_state == CastState.RECOVERY:
		mitigated *= 1.5
	# WINDUP 期被打中 = 打断
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
	if mitigated > 0.0:
		_play_hit_feedback()
	return mitigated

func _setup_hit_feedback() -> void:
	if body3d == null:
		return
	_visual_root = body3d.get_node_or_null("Visual") as Node3D
	if _visual_root == null:
		_visual_root = body3d
	_visual_base_scale = _visual_root.scale
	_hit_meshes.clear()
	_hit_materials.clear()
	_hit_material_colors.clear()
	_collect_meshes(_visual_root)

func _collect_meshes(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh:
			_hit_meshes.append(mesh)
			_cache_hit_material(mesh)
		_collect_meshes(child)

func _cache_hit_material(mesh: MeshInstance3D) -> void:
	var mat: Material = mesh.material_override
	if mat == null and mesh.mesh:
		mat = mesh.get_active_material(0)
	var std: StandardMaterial3D = mat as StandardMaterial3D
	if std == null:
		return
	var inst: StandardMaterial3D = std.duplicate() as StandardMaterial3D
	mesh.material_override = inst
	_hit_materials.append(inst)
	_hit_material_colors.append(inst.albedo_color)

func _play_hit_feedback() -> void:
	if _hit_materials.is_empty() or _visual_root == null:
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_visual_root.scale = _visual_base_scale * 1.05
	for i in _hit_materials.size():
		_hit_materials[i].albedo_color = Color(1, 0.5, 0.5, 1)
	_hit_tween.tween_property(_visual_root, "scale", _visual_base_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in _hit_materials.size():
		var restore: Color = _hit_material_colors[i]
		_hit_tween.parallel().tween_property(_hit_materials[i], "albedo_color", restore, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func is_alive() -> bool:
	return hp > 0

## 警戒方向 / 朝向（被 AI 与玩家锁敌共用）
func global_position_3d() -> Vector3:
	if body3d:
		return body3d.global_position
	return Vector3.ZERO

func forward_dir() -> Vector3:
	if body3d:
		return -body3d.global_basis.z
	return Vector3.FORWARD

# === 内部 ===

func _enter_phase(new_state: int) -> void:
	cast_state = new_state
	phase_elapsed = 0.0
	EventBus.cast_phase_changed.emit(self, current_card, new_state)

func _resolve_active() -> void:
	if current_card == null:
		return
	var card_id := current_card.data.id
	if card_id == &"magic_manual":
		magic_manual_active = true
		_add_status(&"magic_manual", "手册：同属性攻击+50%(本回合)")
		return
	if card_id == &"witch_form":
		witch_form_active = true
		_add_status(&"witch_form", "魔女化：伤害+100% / 受伤+100%")
		return
	if card_id == &"mana_boost":
		next_turn_magic_damage_mult = maxf(next_turn_magic_damage_mult, 1.5)
		_add_status(&"mana_boost", "魔力提升：下回合魔法伤害+50%")
		return
	if card_id == &"delirium":
		_resolve_delirium()
		return
	if witch_form_active and RunState.relic_witch_tears and current_card.data.intent == CardData.Intent.ATTACK:
		if RunState.character_magic_elements.has(current_card.data.element):
			_resolve_multi_target_attack(current_card)
			return
	var target := _resolve_target(current_card.data)
	if card_id == &"witch_touch" and target:
		target.debuff_magic_flat = max(target.debuff_magic_flat, 20)
		target.debuff_physical_flat = max(target.debuff_physical_flat, 11)
		target._add_status(&"witch_touch", "魔女之触：伤害-20魔法/-11物理")
		return
	if card_id == &"magic_barrage":
		_resolve_magic_barrage(target, _magic_barrage_count)
		_magic_barrage_count = 0
		return
	var ctx := {
		"source": self,
		"target": target,
		"card": current_card,
	}
	var did_projectile := false
	if current_card.data.projectile_scene != null:
		_spawn_projectile_from_card(current_card)
		did_projectile = true
	for e: CardEffect in current_card.data.effects:
		if e.phase != CardEffect.Phase.ACTIVE:
			continue
		if did_projectile and e is DamageEffect:
			continue
		e.apply(ctx)

func _resolve_target(d: CardData) -> Combatant:
	match d.target_kind:
		CardData.Target.SELF: return self
		CardData.Target.ENEMY:
			if faction == Faction.ENEMY:
				return CombatantRegistry.find_nearest_enemy(self, 999.0)
			return CombatantRegistry.find_target_in_cone(self, d.range_m, deg_to_rad(d.aim_cone_deg))
	return null

func _resolve_delirium() -> void:
	if RunState.character_magic_elements.is_empty():
		return
	var idx := randi() % RunState.character_magic_elements.size()
	var elem: int = RunState.character_magic_elements[idx]
	var draw_count := randi_range(1, 2)
	_draw_cards_by_element(elem, draw_count)

func _draw_cards_by_element(element: int, count: int) -> void:
	if deck == null:
		return
	var drawn := 0
	while drawn < count:
		var data := _take_card_from_draw_pile_by_element(element)
		if data == null:
			break
		_place_card_in_hand(data)
		drawn += 1
	EventBus.hand_changed.emit(self)

func _take_card_from_draw_pile_by_element(element: int) -> CardData:
	for i in range(deck.draw_pile.size() - 1, -1, -1):
		var c := deck.draw_pile[i]
		if c and c.element == element:
			deck.draw_pile.remove_at(i)
			return c
	if not deck.discard_pile.is_empty():
		deck.draw_pile.append_array(deck.discard_pile)
		deck.discard_pile.clear()
		deck.draw_pile.shuffle()
		for i in range(deck.draw_pile.size() - 1, -1, -1):
			var c := deck.draw_pile[i]
			if c and c.element == element:
				deck.draw_pile.remove_at(i)
				return c
	return null

func _place_card_in_hand(data: CardData) -> void:
	if data == null:
		return
	for i in hand_slots.size():
		if hand_slots[i] == null:
			hand_slots[i] = CardInstance.new(data, self)
			EventBus.card_drawn.emit(self, hand_slots[i])
			return
	if deck:
		deck.discard_pile.append(data)

func _resolve_multi_target_attack(card: CardInstance) -> void:
	var enemies: Array[Combatant] = []
	for c in CombatantRegistry.all:
		if c and c.faction == Faction.ENEMY and c.is_alive():
			enemies.append(c)
	for e in enemies:
		var ctx := {
			"source": self,
			"target": e,
			"card": card,
		}
		for eff: CardEffect in card.data.effects:
			if eff.phase != CardEffect.Phase.ACTIVE:
				continue
			eff.apply(ctx)

func _resolve_magic_barrage(target: Combatant, count: int) -> void:
	var shots := maxi(0, count)
	if shots <= 0:
		return
	var elem := current_card.data.element
	for i in range(shots):
		_spawn_projectile_custom(10.0, elem, current_card.data.range_m)

func _spawn_projectile_custom(dmg: float, elem: int, range_m: float) -> void:
	if current_card == null or current_card.data == null:
		return
	if current_card.data.projectile_scene == null:
		return
	var node: Node = current_card.data.projectile_scene.instantiate()
	if node == null:
		return
	var proj := node as Node3D
	if proj == null:
		return
	var origin := global_position_3d()
	origin.y += 1.2
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(proj)
	proj.global_position = origin
	var dir: Vector3 = forward_dir()
	if faction == Faction.PLAYER:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
			dir = cam.project_ray_normal(center)
	else:
		var target: Combatant = CombatantRegistry.find_nearest_enemy(self, 999.0)
		if target:
			dir = (target.global_position_3d() - origin).normalized()
	if proj.has_method("configure"):
		proj.call("configure", self, dir.normalized(), dmg, elem, range_m)

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

func set_hand_size(new_size: int) -> void:
	hand_size = maxi(1, new_size)
	hand_slots.resize(hand_size)
	for i in hand_size:
		if hand_slots[i] == null:
			hand_slots[i] = null
	EventBus.hand_changed.emit(self)

func draw_cards(count: int) -> void:
	var drawn := deck.draw(count)
	for inst in drawn:
		var placed := false
		for i in hand_slots.size():
			if hand_slots[i] == null:
				hand_slots[i] = inst
				EventBus.card_drawn.emit(self, inst)
				placed = true
				break
		if not placed:
			break
	EventBus.hand_changed.emit(self)

func discard_hand_to_pile() -> void:
	for i in hand_slots.size():
		var inst: CardInstance = hand_slots[i]
		if inst == null or inst.data == null:
			continue
		if inst.data.retain or _retain_card_ids.has(inst.data.id):
			continue
		if not inst.data.exhaust:
			deck.discard_pile.append(inst.data)
		hand_slots[i] = null
	_compact_hand()
	EventBus.hand_changed.emit(self)

func _compact_hand() -> void:
	var write_idx := 0
	for i in hand_slots.size():
		var inst: CardInstance = hand_slots[i]
		if inst != null:
			if i != write_idx:
				hand_slots[write_idx] = inst
				hand_slots[i] = null
			write_idx += 1

func reset_energy() -> void:
	reset_energy_with_bonus(0)

func reset_energy_with_bonus(bonus_ap: int) -> void:
	var display_max := max_ap + bonus_ap
	ap = float(display_max)
	EventBus.ap_changed.emit(self, ap, display_max)

func start_turn() -> void:
	turn_magic_damage_mult = next_turn_magic_damage_mult
	next_turn_magic_damage_mult = 1.0
	if turn_magic_damage_mult > 1.0:
		_add_status(&"mana_boost_active", "魔力提升：魔法伤害+50%(本回合)")
	else:
		_remove_status(&"mana_boost_active")
	if _return_next_turn_ids.size() > 0:
		for id in _return_next_turn_ids:
			_return_card_to_hand(id)
		_return_next_turn_ids.clear()

func end_round() -> void:
	magic_manual_active = false
	_remove_status(&"magic_manual")

func _return_card_to_hand(id: StringName) -> void:
	if deck == null:
		return
	var card_data: CardData = null
	for i in deck.discard_pile.size():
		var c: CardData = deck.discard_pile[i]
		if c and c.id == id:
			card_data = c
			deck.discard_pile.remove_at(i)
			break
	if card_data == null:
		return
	for i in hand_slots.size():
		if hand_slots[i] == null:
			hand_slots[i] = CardInstance.new(card_data, self)
			EventBus.hand_changed.emit(self)
			return

func set_mana(value: int) -> void:
	mp = clamp(value, 0, max_mp)
	EventBus.mp_changed.emit(self, mp, max_mp)

func reset_block() -> void:
	block = 0
	EventBus.block_changed.emit(self, block)

func perform_roll(distance: float, dodge_window_sec: float) -> void:
	if body3d == null:
		return
	var move_dir: Vector3 = Vector3.ZERO
	if body3d.has_method("get_move_dir"):
		move_dir = body3d.call("get_move_dir")
	if move_dir.length() < 0.01:
		move_dir = -forward_dir()
	move_dir.y = 0
	if move_dir.length() < 0.01:
		return
	move_dir = move_dir.normalized()
	body3d.global_position += move_dir * distance
	_open_dodge_window(dodge_window_sec)

func _open_dodge_window(duration: float) -> void:
	_dodge_window_id += 1
	var my_id: int = _dodge_window_id
	dodge_window_active = true
	await get_tree().create_timer(duration).timeout
	if my_id == _dodge_window_id:
		dodge_window_active = false

func on_extreme_dodge() -> void:
	if faction != Faction.PLAYER:
		return
	if not dodge_window_active:
		return
	dodge_window_active = false
	EventBus.extreme_dodged.emit(self)

func _spawn_projectile_from_card(card: CardInstance) -> void:
	if card == null or card.data == null or card.data.projectile_scene == null:
		return
	var payload: Dictionary = _get_projectile_payload(card)
	var dmg: float = float(payload.get("damage", 0.0))
	var elem: int = int(payload.get("element", card.data.element))
	var node: Node = card.data.projectile_scene.instantiate()
	if node == null:
		return
	var proj := node as Node3D
	if proj == null:
		return
	var origin := global_position_3d()
	origin.y += 1.2
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(proj)
	proj.global_position = origin
	var dir: Vector3 = forward_dir()
	if faction == Faction.PLAYER:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
			dir = cam.project_ray_normal(center)
	else:
		var target: Combatant = CombatantRegistry.find_nearest_enemy(self, 999.0)
		if target:
			dir = (target.global_position_3d() - origin).normalized()
	if proj.has_method("configure"):
		proj.call("configure", self, dir.normalized(), dmg, elem, card.data.range_m)

func _get_projectile_payload(card: CardInstance) -> Dictionary:
	var damage: float = 0.0
	var element: int = card.data.element
	for effect in card.data.effects:
		if effect == null:
			continue
		var amount_value: Variant = effect.get("amount")
		if amount_value == null:
			continue
		damage = float(amount_value)
		var inherit_value: Variant = effect.get("inherit_card_element")
		var inherit_card_element: bool = true if inherit_value == null else bool(inherit_value)
		if not inherit_card_element:
			var element_value: Variant = effect.get("element")
			if element_value != null:
				element = int(element_value)
		break
	if damage <= 0.0:
		match card.data.id:
			&"fireball":
				damage = 7.0
			&"water_jet":
				damage = 6.0
			&"slime_water_shot", &"slime_water_cannon":
				damage = 8.0
			&"magic_barrage":
				damage = 10.0
	return {
		"damage": damage,
		"element": element,
	}

func _draw_to_first_empty_slot() -> void:
	for i in hand_slots.size():
		if hand_slots[i] == null:
			var drawn := deck.draw(1)
			if drawn.size() > 0:
				hand_slots[i] = drawn[0]
				EventBus.card_drawn.emit(self, drawn[0])
			break
	EventBus.hand_changed.emit(self)

# === 元素伤害结算（被 DamageEffect 调用）===

func deal_damage_to(target: Combatant, amount: float, element: int) -> void:
	if target == null or not target.is_alive():
		return
	var target_hp_before: int = target.hp
	amount += float(damage_bonus)
	if all_damage_true:
		element = Element.Type.NONE
	if element == Element.Type.NONE and debuff_physical_flat > 0:
		amount = max(0.0, amount - float(debuff_physical_flat))
	if element != Element.Type.NONE and debuff_magic_flat > 0:
		amount = max(0.0, amount - float(debuff_magic_flat))
	if faction == Faction.PLAYER and RunState.relic_witch_hat and element == Element.Type.FIRE:
		if RunState.turn_witch_hat_fire_mult > 0.0:
			amount *= 1.0 + RunState.turn_witch_hat_fire_mult
	if faction == Faction.PLAYER and witch_form_active and RunState.character_magic_elements.has(element):
		amount *= 2.0
	if faction == Faction.PLAYER and turn_magic_damage_mult > 1.0 and element != Element.Type.NONE:
		amount *= turn_magic_damage_mult
	if faction == Faction.PLAYER and magic_manual_active and current_card and current_card.data.intent == CardData.Intent.ATTACK:
		if target.dominant_element == element:
			amount *= 1.5
			magic_manual_active = false
			_remove_status(&"magic_manual")
	var matchup := Element.matchup_multiplier(element, _dominant_element(target))
	var raw := amount * matchup
	var dealt := target.take_damage(raw, element, all_damage_true)
	if display_name == "水史莱姆" and target.faction == Faction.PLAYER:
		print("[WaterSlimeDamage] amount=", amount, " raw=", raw, " dealt=", dealt, " hp:", target_hp_before, "->", target.hp, " block=", target.block, " element=", element)
	EventBus.damage_dealt.emit(self, target, amount, element, dealt)
	if current_card and current_card.data.id == &"witch_judgement" and dealt > 0.0:
		all_damage_true = true
		pending_judgement_death = true
		_add_status(&"witch_judgement", "审判：伤害真实化/回合结束死亡")


func _dominant_element(_t: Combatant) -> int:
	return dominant_element

func _compute_damage(raw_amount: float, element: int, is_true: bool) -> float:
	if is_true:
		return max(0.0, raw_amount)
	if element == Element.Type.NONE:
		return max(0.0, raw_amount - float(base_def))
	var ignore_pct := float(pending_ignore_magic_resist.get(element, 0.0))
	if pending_ignore_magic_resist.has(element):
		pending_ignore_magic_resist.erase(element)
	var effective_res: float = max(0.0, float(base_res) - ignore_pct)
	return max(0.0, raw_amount * (100.0 - effective_res) / 100.0)

func _add_status(id: StringName, label: String) -> void:
	_status_labels[id] = label
	EventBus.statuses_changed.emit(self)

func _remove_status(id: StringName) -> void:
	if _status_labels.has(id):
		_status_labels.erase(id)
		EventBus.statuses_changed.emit(self)

func status_text() -> String:
	if _status_labels.is_empty():
		return ""
	var parts: Array[String] = []
	for k in _status_labels.keys():
		parts.append(String(_status_labels[k]))
	return " / ".join(parts)
