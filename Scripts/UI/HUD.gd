## HUD — 游戏内常驻 HUD
##
## 显示：玩家 HP/AP、4 个热键卡槽、所有敌方头顶 IntentBillboard。
## 不暂停游戏，不抢焦点。
extends CanvasLayer

@export var player_path: NodePath
@export var intent_billboard_scene: PackedScene

var _player: Combatant
var _hp_bar: ProgressBar
var _hp_label: Label
var _ap_bar: ProgressBar
var _ap_label: Label
var _slots: Array = []                      # Array[Control]
var _billboards: Dictionary = {}            # Combatant -> IntentBillboard

func _ready() -> void:
	_hp_bar = $Root/HBoxTop/PlayerStats/HPRow/HPBar
	_hp_label = $Root/HBoxTop/PlayerStats/HPRow/HPLabel
	_ap_bar = $Root/HBoxTop/PlayerStats/APRow/APBar
	_ap_label = $Root/HBoxTop/PlayerStats/APRow/APLabel
	for i in 4:
		_slots.append($Root/Hotbar.get_node("Slot%d" % (i + 1)))

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
	EventBus.hand_changed.connect(_on_hand_changed)
	EventBus.cast_started.connect(_on_cast_started)
	EventBus.cast_phase_changed.connect(_on_cast_phase_changed)
	EventBus.cast_ended.connect(_on_cast_ended)
	EventBus.cast_interrupted.connect(_on_cast_interrupted)
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

func _on_combatant_unregistered(c: Combatant) -> void:
	if _billboards.has(c):
		var bb = _billboards[c]
		if is_instance_valid(bb):
			bb.queue_free()
		_billboards.erase(c)

func _attach_billboard(c: Combatant) -> void:
	if intent_billboard_scene == null or c.body3d == null:
		return
	var bb = intent_billboard_scene.instantiate()
	c.body3d.add_child(bb)
	bb.transform.origin = Vector3(0, 2.4, 0)
	bb.bind(c)
	_billboards[c] = bb

# === 玩家面板刷新 ===

func _refresh_player_all() -> void:
	if _player == null:
		return
	_on_hp_changed(_player, _player.hp, _player.max_hp)
	_on_ap_changed(_player, _player.ap, _player.max_ap)
	_on_hand_changed(_player)

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

func _on_hand_changed(c: Combatant) -> void:
	if c != _player:
		return
	for i in _slots.size():
		var slot: Control = _slots[i]
		var inst = c.hand_slots[i] if i < c.hand_slots.size() else null
		var name_lbl: Label = slot.get_node("VBox/Name")
		var cost_lbl: Label = slot.get_node("VBox/Cost")
		var key_lbl: Label = slot.get_node("KeyLabel")
		key_lbl.text = str(i + 1)
		if inst == null:
			name_lbl.text = "—"
			cost_lbl.text = ""
			slot.modulate = Color(0.4, 0.4, 0.4, 1)
		else:
			name_lbl.text = inst.data.display_name
			cost_lbl.text = "%d AP" % inst.data.cost
			var element_color: Color = Element.color_of(inst.data.element)
			var enough := c.ap >= float(inst.data.cost)
			slot.modulate = element_color if enough else element_color.darkened(0.5)

func _process(_delta: float) -> void:
	# AP 持续更新槽位高亮
	if _player:
		_on_hand_changed(_player)

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
