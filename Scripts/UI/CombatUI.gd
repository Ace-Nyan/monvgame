## CombatUI — 战斗界面控制器
##
## 这是 CanvasLayer，作为 3D 场景的覆盖 UI。
## 监听 EventBus 信号刷新自身；通过 manager API 触发玩家操作。
extends CanvasLayer

@export var manager: CombatManager

@onready var hand_box: HBoxContainer = %HandBox
@onready var queued_box: HBoxContainer = %QueuedBox
@onready var enemy_intent_box: HBoxContainer = %EnemyIntentBox
@onready var player_hp: Label = %PlayerHP
@onready var enemy_hp: Label = %EnemyHP
@onready var player_block: Label = %PlayerBlock
@onready var enemy_block: Label = %EnemyBlock
@onready var player_ap: Label = %PlayerAP
@onready var turn_label: Label = %TurnLabel
@onready var player_resist: Label = %PlayerResist
@onready var enemy_resist: Label = %EnemyResist
@onready var log_label: RichTextLabel = %CombatLog
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var result_label: Label = %ResultLabel

const CARD_SCENE := preload("res://Scenes/Combat/CardView.tscn")

func _ready() -> void:
	visible = false
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.block_changed.connect(_on_block_changed)
	EventBus.resistance_changed.connect(_on_resistance_changed)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.card_queued.connect(_on_card_queued)
	EventBus.card_interrupted.connect(_on_card_interrupted)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)

func _on_combat_started(_p: Combatant, _e: Combatant) -> void:
	visible = true
	result_label.visible = false
	log_label.clear()
	_log("战斗开始")

func _on_combat_ended(winner: Combatant) -> void:
	result_label.text = "胜者：%s" % winner.display_name
	result_label.visible = true
	end_turn_btn.disabled = true

func _on_turn_started(idx: int) -> void:
	turn_label.text = "回合 %d" % idx
	end_turn_btn.disabled = false
	_refresh_hand()
	_refresh_enemy_intents()
	_refresh_resist_labels()
	_refresh_ap()

func _on_hp_changed(c: Combatant, hp: int, max_hp: int) -> void:
	if c == manager.player:
		player_hp.text = "❤ %d/%d" % [hp, max_hp]
	elif c == manager.enemy:
		enemy_hp.text = "❤ %d/%d" % [hp, max_hp]

func _on_block_changed(c: Combatant, value: int) -> void:
	if c == manager.player:
		player_block.text = "🛡 %d" % value
	else:
		enemy_block.text = "🛡 %d" % value

func _on_resistance_changed(_c: Combatant) -> void:
	_refresh_resist_labels()

func _on_card_drawn(c: Combatant, _card: CardInstance) -> void:
	if c == manager.player:
		_refresh_hand()

func _on_card_queued(_c: Combatant, _card: CardInstance) -> void:
	_refresh_hand()
	_refresh_enemy_intents()
	_refresh_queued()
	_refresh_ap()

func _on_card_interrupted(card: CardInstance) -> void:
	_log("[color=yellow]%s 的「%s」被打断！[/color]" % [card.owner.display_name, card.data.display_name])

func _on_damage_dealt(src: Combatant, tgt: Combatant, raw: float, elem: int, mitigated: float) -> void:
	var elem_name := Element.name_of(elem)
	_log("%s → %s : %d (%s, 实际 %d)" % [src.display_name, tgt.display_name, int(raw), elem_name, int(mitigated)])

func _on_end_turn_pressed() -> void:
	end_turn_btn.disabled = true
	manager.confirm_player_turn()

# === 渲染 ===

func _refresh_ap() -> void:
	if manager.player:
		player_ap.text = "AP %d/%d" % [manager.player.ap, manager.player.max_ap]

func _refresh_hand() -> void:
	for child in hand_box.get_children():
		child.queue_free()
	if manager.player == null or manager.player.deck == null:
		return
	for ci in manager.player.deck.hand:
		var view := CARD_SCENE.instantiate()
		view.set_card(ci, true)
		view.card_clicked.connect(_on_hand_card_clicked)
		hand_box.add_child(view)

func _refresh_queued() -> void:
	for child in queued_box.get_children():
		child.queue_free()
	if manager.player == null:
		return
	for ci in manager.player.queued_cards:
		var view := CARD_SCENE.instantiate()
		view.set_card(ci, false)
		view.card_clicked.connect(_on_queued_card_clicked)
		queued_box.add_child(view)

func _refresh_enemy_intents() -> void:
	for child in enemy_intent_box.get_children():
		child.queue_free()
	if manager.enemy == null:
		return
	# 只显示意图类型和元素，帧数与具体卡名保密
	for ci in manager.enemy.queued_cards:
		var lbl := Label.new()
		var col := Element.color_of(ci.data.element)
		lbl.text = "%s%s" % [ci.data.intent_icon(), Element.name_of(ci.data.element) if ci.data.element != Element.Type.NONE else ""]
		lbl.add_theme_color_override("font_color", col)
		lbl.add_theme_font_size_override("font_size", 32)
		enemy_intent_box.add_child(lbl)

func _refresh_resist_labels() -> void:
	if manager.player and manager.player.resistance:
		player_resist.text = _format_resist(manager.player.resistance)
	if manager.enemy and manager.enemy.resistance:
		enemy_resist.text = _format_resist(manager.enemy.resistance)

func _format_resist(p: ResistanceProfile) -> String:
	var parts: Array[String] = []
	for elem in [Element.Type.FIRE, Element.Type.WATER, Element.Type.GRASS]:
		var v := p.get_resistance(elem)
		if absf(v) < 0.001:
			continue
		var sign := "+" if v >= 0 else ""
		parts.append("%s%s%d%%" % [Element.name_of(elem), sign, int(round(v * 100))])
	return "  ".join(parts) if parts.size() > 0 else "—"

func _on_hand_card_clicked(card: CardInstance) -> void:
	if manager.queue_card(card):
		_log("入队：%s" % card.data.display_name)

func _on_queued_card_clicked(card: CardInstance) -> void:
	manager.unqueue_card(card)
	_refresh_hand()
	_refresh_queued()
	_refresh_ap()

func _log(text: String) -> void:
	log_label.append_text(text + "\n")
