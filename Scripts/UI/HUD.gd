## HUD — 游戏内常驻 HUD
##
## 显示：玩家 HP/AP、4 个热键卡槽、所有敌方头顶 IntentBillboard。
## 不暂停游戏，不抢焦点。
extends CanvasLayer

@export var player_path: NodePath
@export var intent_billboard_scene: PackedScene
@export var combat_manager_path: NodePath

var _player: Combatant
var _hp_bar: ProgressBar
var _hp_label: Label
var _ap_bar: ProgressBar
var _ap_label: Label
var _mp_bar: ProgressBar
var _mp_label: Label
var _block_bar: ProgressBar
var _block_label: Label
var _phase_label: Label
var _enemy_count_label: Label
var _end_turn_button: Button
var _response_label: Label
var _slots: Array = []                      # Array[Control]
var _billboards: Dictionary = {}            # Combatant -> IntentBillboard
var _selected_slot: int = 0
var _manager: CombatManager
var _draw_count_label: Label
var _discard_count_label: Label
var _draw_button: Button
var _discard_button: Button
var _pile_viewer: Control
var _pile_title: Label
var _pile_list: VBoxContainer
var _pile_close_button: Button
var _deck_viewer: Control
var _deck_list: VBoxContainer
var _deck_detail_title: Label
var _deck_detail_body: Label
var _deck_close_button: Button
var _crosshair: Control
var _crosshair_tween: Tween
var _relic_bar: HBoxContainer
var _relic_tooltip: Control
var _relic_name: Label
var _relic_desc: Label
var _relic_effect: Label
var _enemy_total: int = 0
const MAX_HAND_SLOTS: int = 10

func _ready() -> void:
	_hp_bar = $Root/HBoxTop/PlayerStats/HPRow/HPBar
	_hp_label = $Root/HBoxTop/PlayerStats/HPRow/HPLabel
	_ap_bar = $Root/HBoxTop/PlayerStats/APRow/APBar
	_ap_label = $Root/HBoxTop/PlayerStats/APRow/APLabel
	_mp_bar = $Root/HBoxTop/PlayerStats/MPRow/MPBar
	_mp_label = $Root/HBoxTop/PlayerStats/MPRow/MPLabel
	_block_bar = $Root/HBoxTop/PlayerStats/BlockRow/BlockBar
	_block_label = $Root/HBoxTop/PlayerStats/BlockRow/BlockLabel
	_phase_label = $Root/HBoxTop/PlayerStats/PhaseLabel
	_enemy_count_label = $Root/HBoxTop/PlayerStats/EnemyCountLabel
	_end_turn_button = $Root/HBoxTop/RightBox/EndTurnButton
	_response_label = $Root/HBoxTop/RightBox/ResponseLabel
	_draw_count_label = $Root/BottomLeft/DrawPilePanel/VBox/Count
	_discard_count_label = $Root/BottomRight/DiscardPilePanel/VBox/Count
	_draw_button = $Root/BottomLeft/DrawPilePanel/VBox/Button
	_discard_button = $Root/BottomRight/DiscardPilePanel/VBox/Button
	_pile_viewer = $Root/PileViewer
	_pile_title = $Root/PileViewer/Panel/VBox/Title
	_pile_list = $Root/PileViewer/Panel/VBox/Scroll/List
	_pile_close_button = $Root/PileViewer/Panel/VBox/CloseButton
	_deck_viewer = $Root/DeckViewer
	_deck_list = $Root/DeckViewer/Panel/VBox/Content/ListScroll/List
	_deck_detail_title = $Root/DeckViewer/Panel/VBox/Content/Detail/DetailVBox/DetailTitle
	_deck_detail_body = $Root/DeckViewer/Panel/VBox/Content/Detail/DetailVBox/DetailBody
	_deck_close_button = $Root/DeckViewer/Panel/VBox/CloseButton
	_crosshair = $Root/Crosshair
	_relic_bar = $Root/RelicBar
	_relic_tooltip = $Root/RelicTooltip
	_relic_name = $Root/RelicTooltip/VBox/Name
	_relic_desc = $Root/RelicTooltip/VBox/Desc
	_relic_effect = $Root/RelicTooltip/VBox/Effect
	if combat_manager_path != NodePath(""):
		_manager = get_node_or_null(combat_manager_path) as CombatManager
	var hotbar: HBoxContainer = $Root/Hotbar
	var template: PanelContainer = hotbar.get_node("Slot1")
	var existing: int = hotbar.get_child_count()
	for i in range(existing + 1, MAX_HAND_SLOTS + 1):
		var slot: PanelContainer = template.duplicate() as PanelContainer
		slot.name = "Slot%d" % i
		hotbar.add_child(slot)
	for i in range(1, MAX_HAND_SLOTS + 1):
		var slot_node: Control = hotbar.get_node_or_null("Slot%d" % i) as Control
		if slot_node:
			_slots.append(slot_node)
	if _end_turn_button:
		_end_turn_button.pressed.connect(_on_end_turn_pressed)
	if _draw_button:
		_draw_button.pressed.connect(_on_draw_pile_pressed)
	if _discard_button:
		_discard_button.pressed.connect(_on_discard_pile_pressed)
	if _pile_close_button:
		_pile_close_button.pressed.connect(_close_pile_viewer)
	if _deck_close_button:
		_deck_close_button.pressed.connect(_close_deck_viewer)

	# 先尝试 NodePath
	if player_path != NodePath(""):
		var node := get_node_or_null(player_path)
		if node:
			_player = node as Combatant
	# 监听信号
	EventBus.combatant_registered.connect(_on_combatant_registered)
	EventBus.combatant_unregistered.connect(_on_combatant_unregistered)
	EventBus.combatant_died.connect(_on_combatant_unregistered)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.ap_changed.connect(_on_ap_changed)
	EventBus.mp_changed.connect(_on_mp_changed)
	EventBus.block_changed.connect(_on_block_changed)
	EventBus.hand_changed.connect(_on_hand_changed)
	EventBus.cast_started.connect(_on_cast_started)
	EventBus.cast_phase_changed.connect(_on_cast_phase_changed)
	EventBus.cast_ended.connect(_on_cast_ended)
	EventBus.cast_interrupted.connect(_on_cast_interrupted)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
	EventBus.selected_slot_changed.connect(_on_selected_slot_changed)
	RelicManager.relics_changed.connect(_refresh_relics)
	# 兜底：连接信号前已经注册的 Combatant 不会再次触发 combatant_registered，
	# 因此显式扫一遍引导玩家面板与敌人头顶气泡。
	for c in CombatantRegistry.all:
		_on_combatant_registered(c)

func _on_combatant_registered(c: Combatant) -> void:
	if _player == null and c.faction == Combatant.Faction.PLAYER:
		_player = c
		_refresh_player_all()
	if c.faction == Combatant.Faction.ENEMY:
		_attach_billboard(c)
		_refresh_enemy_count()

func _on_combatant_unregistered(c: Combatant) -> void:
	if _billboards.has(c):
		var bb = _billboards[c]
		if is_instance_valid(bb):
			bb.queue_free()
		_billboards.erase(c)
	if c.faction == Combatant.Faction.ENEMY:
		_refresh_enemy_count()

func _attach_billboard(c: Combatant) -> void:
	if intent_billboard_scene == null or c.body3d == null:
		return
	var bb = intent_billboard_scene.instantiate()
	c.body3d.add_child.call_deferred(bb)
	bb.call_deferred("set_position", Vector3(0, 2.4, 0))
	bb.call_deferred("bind", c)
	_billboards[c] = bb

# === 玩家面板刷新 ===

func _refresh_player_all() -> void:
	if _player == null:
		return
	_on_hp_changed(_player, _player.hp, _player.max_hp)
	_on_ap_changed(_player, _player.ap, _player.max_ap)
	_on_mp_changed(_player, _player.mp, _player.max_mp)
	_on_block_changed(_player, _player.block)
	_on_hand_changed(_player)
	_refresh_pile_counts()
	_refresh_relics()
	_refresh_enemy_count()

func _on_hp_changed(c: Combatant, hp: int, max_hp: int) -> void:
	if c != _player:
		return
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]

func _on_ap_changed(c: Combatant, ap: float, max_ap: int) -> void:
	if c != _player:
		return
	_ap_bar.max_value = float(max_ap)
	_ap_bar.value = ap
	_ap_label.text = "%.1f / %d" % [ap, max_ap]

func _on_mp_changed(c: Combatant, mp: int, max_mp: int) -> void:
	if c != _player:
		return
	_mp_bar.max_value = float(max_mp)
	_mp_bar.value = float(mp)
	_mp_label.text = "%d / %d" % [mp, max_mp]

func _on_block_changed(c: Combatant, value: int) -> void:
	if c != _player:
		return
	var max_value := maxi(_player.max_hp, value)
	_block_bar.max_value = float(max_value)
	_block_bar.value = float(value)
	_block_label.text = "护盾 %d" % value

func _refresh_enemy_count() -> void:
	if _enemy_count_label == null:
		return
	var total := _compute_total_enemies()
	var alive := _count_alive_enemies()
	if total < alive:
		total = alive
	_enemy_total = total
	_enemy_count_label.text = "敌人 %d/%d" % [alive, total]

func _compute_total_enemies() -> int:
	var encounter := RunState.get_current_encounter()
	if not encounter.is_empty():
		var enemies: Array = encounter.get("enemies", [])
		var total := 0
		for e in enemies:
			total += int(e.get("count", 0))
		return total
	var total := 0
	for c in CombatantRegistry.all:
		var enemy := c as Combatant
		if enemy and enemy.faction == Combatant.Faction.ENEMY:
			total += 1
	return total

func _count_alive_enemies() -> int:
	var alive := 0
	for c in CombatantRegistry.all:
		var enemy := c as Combatant
		if enemy and enemy.faction == Combatant.Faction.ENEMY and enemy.is_alive():
			alive += 1
	return alive

func _on_hand_changed(c: Combatant) -> void:
	if c != _player:
		return
	for i in _slots.size():
		var slot: Control = _slots[i]
		var inst = c.hand_slots[i] if i < c.hand_slots.size() else null
		var name_lbl: Label = slot.get_node("VBox/Name")
		var cost_lbl: Label = slot.get_node("VBox/Cost")
		var dmg_lbl: Label = slot.get_node_or_null("VBox/Damage") as Label
		if dmg_lbl == null:
			var vbox: VBoxContainer = slot.get_node("VBox") as VBoxContainer
			dmg_lbl = Label.new()
			dmg_lbl.name = "Damage"
			dmg_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(dmg_lbl)
		var key_lbl: Label = slot.get_node("KeyLabel")
		key_lbl.text = str(i + 1)
		if inst == null:
			slot.visible = false
			name_lbl.text = "—"
			cost_lbl.text = ""
			dmg_lbl.text = ""
			slot.modulate = Color(0.4, 0.4, 0.4, 1)
		else:
			slot.visible = true
			name_lbl.text = inst.data.display_name
			var is_response := _manager and _manager.phase == CombatManager.Phase.ENEMY_ATTACK
			var effective_cost := _effective_cost(c, inst, is_response)
			cost_lbl.text = "%d %s" % [effective_cost, "MP" if is_response else "AP"]
			dmg_lbl.text = _estimate_damage_text(c, inst)
			var element_color: Color = Element.color_of(inst.data.element)
			var enough: bool = (c.mp >= effective_cost) if is_response else (c.ap >= float(effective_cost))
			var tint := element_color if enough else element_color.darkened(0.5)
			if i == _selected_slot:
				tint = tint.lightened(0.35)
				slot.scale = Vector2(1.08, 1.08)
				slot.z_index = 10
			else:
				slot.scale = Vector2.ONE
				slot.z_index = 0
			slot.modulate = tint

func _process(_delta: float) -> void:
	# AP 持续更新槽位高亮
	if _player:
		_on_hand_changed(_player)
		_refresh_pile_counts()
	_update_response_ui()

func _update_response_ui() -> void:
	if _response_label == null or _manager == null:
		return
	if _manager.phase != CombatManager.Phase.ENEMY_ATTACK:
		_response_label.text = ""
		return
	if _manager.response_phase == "enemy":
		if _manager.response_intent_title == "":
			_response_label.text = "敌人策略：准备中"
			return
		var desc := _manager.response_intent_desc
		if desc == "":
			_response_label.text = "敌人策略：%s" % _manager.response_intent_title
		else:
			_response_label.text = "敌人策略：%s\n%s" % [_manager.response_intent_title, desc]
		return
	if _manager.response_phase == "response":
		_response_label.text = "应对剩余：%.1f 秒" % _manager.response_remaining

func _on_cast_started(c: Combatant, _card: CardInstance) -> void:
	if c == _player:
		_on_hand_changed(_player)

func _on_cast_phase_changed(_c, _card, _phase) -> void:
	pass

func _on_cast_ended(c: Combatant, _card: CardInstance) -> void:
	if c == _player:
		_on_hand_changed(_player)

func _on_cast_interrupted(c: Combatant, _card: CardInstance) -> void:
	if c == _player:
		_on_hand_changed(_player)

func _on_turn_phase_changed(phase: int) -> void:
	_phase_label.text = "攻击回合" if phase == CombatManager.Phase.PLAYER_ATTACK else "应对回合"
	if _end_turn_button:
		_end_turn_button.disabled = phase != CombatManager.Phase.PLAYER_ATTACK

func _on_selected_slot_changed(slot_index: int) -> void:
	_selected_slot = slot_index
	if _player:
		_on_hand_changed(_player)

func _on_end_turn_pressed() -> void:
	if _manager:
		_manager.end_player_attack()

func _on_damage_dealt(source: Combatant, _target: Combatant, _amount: float, _element: int, _mitigated: float) -> void:
	if _player == null or source != _player:
		return
	_animate_crosshair_hit()
	if _player:
		_on_hand_changed(_player)

func _animate_crosshair_hit() -> void:
	if _crosshair == null:
		return
	if _crosshair_tween and _crosshair_tween.is_valid():
		_crosshair_tween.kill()
	_crosshair.scale = Vector2(1, 1)
	_crosshair.modulate = Color(1, 1, 1, 0.85)
	_crosshair_tween = create_tween()
	_crosshair_tween.tween_property(_crosshair, "scale", Vector2(1.6, 1.6), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_crosshair_tween.parallel().tween_property(_crosshair, "modulate", Color(1, 1, 1, 0.2), 0.08)
	_crosshair_tween.tween_property(_crosshair, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_crosshair_tween.parallel().tween_property(_crosshair, "modulate", Color(1, 1, 1, 0.85), 0.12)

func _on_draw_pile_pressed() -> void:
	if _pile_viewer.visible:
		_close_pile_viewer()
		return
	_show_pile("抽牌堆", true)

func _on_discard_pile_pressed() -> void:
	if _pile_viewer.visible:
		_close_pile_viewer()
		return
	_show_pile("弃牌堆", false)

func _show_pile(title: String, is_draw_pile: bool) -> void:
	if _player == null or _player.deck == null:
		return
	_pile_title.text = title
	for c in _pile_list.get_children():
		c.queue_free()
	var source: Array[CardData] = _player.deck.draw_pile if is_draw_pile else _player.deck.discard_pile
	for card in source:
		var label: Label = Label.new()
		label.text = card.display_name
		_pile_list.add_child(label)
	_pile_viewer.visible = true
	_pile_close_button.grab_focus()

func _close_pile_viewer() -> void:
	_pile_viewer.visible = false

func _open_deck_viewer() -> void:
	if _deck_viewer.visible:
		_close_deck_viewer()
		return
	_build_deck_list()
	_deck_viewer.visible = true
	_deck_close_button.grab_focus()

func _close_deck_viewer() -> void:
	_deck_viewer.visible = false

func _build_deck_list() -> void:
	if _player == null:
		return
	for c in _deck_list.get_children():
		c.queue_free()
	var cards: Array[CardData] = []
	if _player.deck:
		for c in _player.deck.draw_pile:
			cards.append(c)
		for c in _player.deck.discard_pile:
			cards.append(c)
		for inst in _player.hand_slots:
			if inst and inst.data:
				cards.append(inst.data)
	if cards.is_empty():
		return
	for card in cards:
		var btn := Button.new()
		btn.text = card.display_name
		btn.pressed.connect(_on_deck_card_pressed.bind(card))
		_deck_list.add_child(btn)
	_set_deck_detail(cards[0])

func _on_deck_card_pressed(card: CardData) -> void:
	_set_deck_detail(card)

func _set_deck_detail(card: CardData) -> void:
	if card == null:
		return
	_deck_detail_title.text = card.display_name
	_deck_detail_body.text = _card_detail_text(card)

func _card_detail_text(card: CardData) -> String:
	var lines: Array[String] = []
	lines.append("能耗: %d" % card.cost)
	lines.append("属性: %s" % Element.name_of(card.element))
	lines.append("意图: %s" % card.intent_icon())
	var attack_type := "近战" if card.projectile_scene == null else "远程"
	lines.append("攻击方式: %s" % attack_type)
	lines.append("射程: %.1f" % card.range_m)
	var damage := 0
	for e: CardEffect in card.effects:
		if e is DamageEffect:
			var dmg: DamageEffect = e
			damage += dmg.amount
	if damage > 0:
		lines.append("伤害: %d" % damage)
	if card.description != "":
		lines.append("描述: %s" % card.description)
	var effect_lines: Array[String] = []
	for e: CardEffect in card.effects:
		var d := e.describe()
		if d != "":
			effect_lines.append(d)
	if effect_lines.size() > 0:
		lines.append("效果: %s" % "; ".join(effect_lines))
	return "\n".join(lines)

func _refresh_pile_counts() -> void:
	if _player == null or _player.deck == null:
		return
	_draw_count_label.text = str(_player.deck.draw_pile.size())
	_discard_count_label.text = str(_player.deck.discard_pile.size())

func _refresh_relics() -> void:
	if _relic_bar == null:
		return
	for c in _relic_bar.get_children():
		c.queue_free()
	for r in RelicManager.relics:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.color = r.icon_color
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_entered.connect(_on_relic_hover.bind(r))
		icon.mouse_exited.connect(_on_relic_hover_exit)
		_relic_bar.add_child(icon)

func _effective_cost(c: Combatant, inst: CardInstance, is_response: bool) -> int:
	var cost := inst.data.cost
	if inst.data.id == &"magic_barrage":
		return c.mp if is_response else int(floor(c.ap))
	if c.faction == Combatant.Faction.PLAYER and RunState.relic_witch_hat:
		if inst.data.element == Element.Type.WATER and not RunState.turn_witch_hat_water_used:
			cost = maxi(0, cost - 1)
	return cost

func _estimate_damage_text(c: Combatant, inst: CardInstance) -> String:
	if inst == null or inst.data == null:
		return ""
	if inst.data.id == &"magic_barrage":
		var x := int(floor(c.mp)) if (_manager and _manager.phase == CombatManager.Phase.ENEMY_ATTACK) else int(floor(c.ap))
		if x <= 0:
			return ""
		var per_shot := _apply_damage_modifiers(c, 10.0, inst.data)
		return "伤害: %d x %d" % [int(round(per_shot)), x]
	var total := 0.0
	for e: CardEffect in inst.data.effects:
		if e is DamageEffect:
			var dmg: DamageEffect = e
			total += float(dmg.amount)
	if total <= 0.0:
		return ""
	var target: Combatant = CombatantRegistry.find_target_in_cone(c, inst.data.range_m, deg_to_rad(inst.data.aim_cone_deg))
	total = _apply_damage_modifiers(c, total, inst.data, target)
	return "伤害: %d" % int(round(total))

func _apply_damage_modifiers(c: Combatant, base_damage: float, card: CardData, target: Combatant = null) -> float:
	var total := base_damage
	var element := card.element
	if c.faction == Combatant.Faction.PLAYER and RunState.relic_witch_hat and element == Element.Type.FIRE:
		total *= 1.0 + RunState.turn_witch_hat_fire_mult
	if c.faction == Combatant.Faction.PLAYER and c.witch_form_active and RunState.character_magic_elements.has(element):
		total *= 2.0
	if c.faction == Combatant.Faction.PLAYER and c.turn_magic_damage_mult > 1.0 and element != Element.Type.NONE:
		total *= c.turn_magic_damage_mult
	if c.faction == Combatant.Faction.PLAYER and c.magic_manual_active and card.intent == CardData.Intent.ATTACK and target:
		if target.dominant_element == element:
			total *= 1.5
	return total

func _on_relic_hover(r: RelicData) -> void:
	_relic_name.text = r.display_name
	_relic_desc.text = r.description
	_relic_effect.text = r.effect_text
	_relic_tooltip.visible = true

func _on_relic_hover_exit() -> void:
	_relic_tooltip.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_open_deck_viewer()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("view_draw_pile"):
		if _pile_viewer.visible:
			_close_pile_viewer()
		else:
			_show_pile("抽牌堆", true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("view_discard_pile"):
		if _pile_viewer.visible:
			_close_pile_viewer()
		else:
			_show_pile("弃牌堆", false)
		get_viewport().set_input_as_handled()
		return
