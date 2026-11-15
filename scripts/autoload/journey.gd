extends Node

## What the map and the table pass to each other. No rules live here.
var table_mode: String = "battle"
var foe_hero: String = ""
var from_map: bool = false
var player_deck: String = "mages"
var foe_deck: String = "dead"
var map_state: Dictionary = {}


func clear() -> void:
	from_map = false
	player_deck = "mages"
	foe_deck = "dead"
	foe_hero = ""
	table_mode = "battle"
	map_state = {}
