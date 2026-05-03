## Deck — 战斗者的牌堆三件套（抽牌堆 / 手牌 / 弃牌堆）
class_name Deck
extends RefCounted

var draw_pile: Array[CardData] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardData] = []

var owner: Combatant

func _init(p_owner: Combatant = null, starting_cards: Array = []) -> void:
	owner = p_owner
	for c in starting_cards:
		if c is CardData:
			draw_pile.append(c)
	shuffle()

func shuffle() -> void:
	draw_pile.shuffle()

func _refill_from_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()

func draw(n: int = 1) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in n:
		if draw_pile.is_empty():
			_refill_from_discard()
		if draw_pile.is_empty():
			break
		var data: CardData = draw_pile.pop_back()
		var inst := CardInstance.new(data, owner)
		drawn.append(inst)
	return drawn

func discard(card: CardInstance) -> void:
	hand.erase(card)
	if card.data:
		discard_pile.append(card.data)

func discard_hand() -> void:
	for c in hand:
		if c.data:
			discard_pile.append(c.data)
	hand.clear()

func contains_data(id: StringName) -> bool:
	for c in draw_pile:
		if c.id == id: return true
	for c in discard_pile:
		if c.id == id: return true
	for ci in hand:
		if ci.data and ci.data.id == id: return true
	return false

func all_data() -> Array[CardData]:
	var out: Array[CardData] = []
	out.append_array(draw_pile)
	out.append_array(discard_pile)
	for ci in hand:
		if ci.data:
			out.append(ci.data)
	return out
