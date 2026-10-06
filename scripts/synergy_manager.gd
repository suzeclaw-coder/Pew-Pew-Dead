extends Node

# Singleton SynergyManager for Pew-Pew-Dead.
# Tracks collected player cards and unlocks compound synergies when pairs or sets of cards are collected.

enum Tier { RARE, EPIC }

const SYNERGIES: Array[Dictionary] = [
	{
		"id": &"bowling_ball",
		"name": "Bowling Ball",
		"desc": "Sliding through crawling zombies deals lethal crush damage and sends them flying!",
		"tier": Tier.RARE,
		"cards": [&"quick_boots", &"hot_loads"],
	},
	{
		"id": &"executioner",
		"name": "Executioner",
		"desc": "Decapitations grant a 3-second speed boost (+40%) and instant fire rate surge!",
		"tier": Tier.RARE,
		"cards": [&"fast_hands", &"headshot"],
	},
	{
		"id": &"grave_kick",
		"name": "Grave Kick",
		"desc": "Melee shove (F) emits an AOE shockwave knocking down all nearby zombies!",
		"tier": Tier.RARE,
		"cards": [&"iron_skin", &"berserker"],
	},
	{
		"id": &"adrenaline_rush",
		"name": "Adrenaline Rush",
		"desc": "When under 30% HP, gain 35% damage reduction and +25% move speed.",
		"tier": Tier.RARE,
		"cards": [&"glass_cannon"],
	},
]

# Track collected cards
var owned_cards: Array[StringName] = []
# Track currently active synergy ids
var active_synergies: Array[StringName] = []

signal synergy_activated(synergy: Dictionary)
signal synergy_deactivated(synergy: Dictionary)

func _ready() -> void:
	pass

func reset() -> void:
	owned_cards.clear()
	for s_id in active_synergies.duplicate():
		var s := get_synergy(s_id)
		synergy_deactivated.emit(s)
	active_synergies.clear()

func register_card(card_id: StringName) -> void:
	if not owned_cards.has(card_id):
		owned_cards.append(card_id)
	# Also register alias if applicable
	if card_id == &"headshot" and not owned_cards.has(&"headshot_card"):
		owned_cards.append(&"headshot_card")
	elif card_id == &"headshot_card" and not owned_cards.has(&"headshot"):
		owned_cards.append(&"headshot")
	_check_synergies()

func get_active_synergies() -> Array:
	var result: Array = []
	for id in active_synergies:
		result.append(get_synergy(id))
	return result

func has_synergy(synergy_id: StringName) -> bool:
	return active_synergies.has(synergy_id)

func get_synergy(synergy_id: StringName) -> Dictionary:
	for s in SYNERGIES:
		if s.id == synergy_id:
			return s
	return {}

func get_synergies_for_card(card_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in SYNERGIES:
		if s.cards.has(card_id):
			result.append(s)
	return result

func _check_synergies() -> void:
	for s in SYNERGIES:
		var s_id: StringName = s.id
		if active_synergies.has(s_id):
			continue
		var all_satisfied := true
		for req in s.cards:
			if not owned_cards.has(req):
				all_satisfied = false
				break
		if all_satisfied:
			active_synergies.append(s_id)
			synergy_activated.emit(s)
			print("[SynergyManager] Activated synergy: ", s.name, " - ", s.desc)
