extends RefCounted
class_name Spellbook

## Правила арены из res://data/spells.json.
## Очередь — мультимножество стихий (порядок не важен). Сначала пары
## противоположностей снимаются, потом оставшиеся id сортируются и ищутся
## в таблице. Нет строки — срабатывает fallback «Сырая магия».

const DATA_PATH := "res://data/spells.json"

var load_errors: Array[String] = []
var max_queue: int = 3
var max_hp: int = 100
var max_shield: int = 80
var move_speed: float = 120.0
var cast_cooldown: float = 0.25
var cast_cooldown_per_orb: float = 0.15
var heal_cooldown_multiplier: float = 2.5
var arena_min_x: float = 36.0
var arena_max_x: float = 604.0
var elements: Dictionary = {}
var spells: Dictionary = {}
var fallback_name: String = "Сырая магия"
var fallback_base: int = 8
var fallback_per: int = 6
var fallback_speed: float = 240.0
var fallback_radius: float = 6.0
var fizzle_name: String = "Сферы погасли"


func load_from_file(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		load_errors = ["Файл не найден: %s" % path]
		push_error(load_errors[0])
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors = ["JSON должен быть объектом: %s" % path]
		push_error(load_errors[0])
		return false
	load_data(parsed)
	for err in load_errors:
		push_error(err)
	return load_errors.is_empty()


func load_data(data: Dictionary) -> void:
	load_errors = []
	elements = {}
	spells = {}
	var rules: Dictionary = data.get("rules", {})
	max_queue = int(rules.get("max_queue", 3))
	max_hp = int(rules.get("max_hp", 100))
	max_shield = int(rules.get("max_shield", 80))
	move_speed = float(rules.get("move_speed", 120))
	cast_cooldown = float(rules.get("cast_cooldown", 0.25))
	cast_cooldown_per_orb = float(rules.get("cast_cooldown_per_orb", 0.15))
	heal_cooldown_multiplier = float(rules.get("heal_cooldown_multiplier", 2.5))
	arena_min_x = float(rules.get("arena_min_x", 36))
	arena_max_x = float(rules.get("arena_max_x", 604))
	var raw_elements: Dictionary = data.get("elements", {})
	for id in raw_elements.keys():
		var src: Dictionary = raw_elements[id]
		var opposites: Array[String] = []
		for other in src.get("opposites", []):
			opposites.append(str(other))
		elements[str(id)] = {
			"id": str(id),
			"name": str(src.get("name", id)),
			"letter": str(src.get("letter", str(id).substr(0, 1))),
			"color": _color(str(src.get("color", "#ffffff"))),
			"opposites": opposites,
		}
	var fb: Dictionary = data.get("fallback", {})
	fallback_name = str(fb.get("name", "Сырая магия"))
	fallback_base = int(fb.get("damage_base", 8))
	fallback_per = int(fb.get("damage_per_orb", 6))
	fallback_speed = float(fb.get("speed", 240))
	fallback_radius = float(fb.get("radius", 6))
	var fizzle: Dictionary = data.get("fizzle", {})
	fizzle_name = str(fizzle.get("name", "Сферы погасли"))
	for src in data.get("spells", []):
		if typeof(src) != TYPE_DICTIONARY:
			load_errors.append("Заклинание должно быть объектом")
			continue
		_add_spell(src)


func _add_spell(src: Dictionary) -> void:
	var ids: Array[String] = []
	for raw_id in src.get("elements", []):
		var element_id := str(raw_id)
		if not elements.has(element_id):
			load_errors.append("Неизвестная стихия '%s' в заклинании %s" % [element_id, src.get("id", "?")])
			return
		ids.append(element_id)
	if ids.is_empty():
		load_errors.append("У заклинания %s нет стихий" % src.get("id", "?"))
		return
	var key := _key(ids)
	if spells.has(key):
		load_errors.append("Повтор связки %s" % key)
		return
	var casts: Dictionary = src.get("casts", {})
	var color := _blend(ids)
	var foe := _normalize_cast(casts.get("foe", {}), color, "projectile")
	var self_cast := _normalize_cast(casts.get("self", {}), color, "instant")
	if casts.has("foe") and not casts.has("self"):
		self_cast = foe.duplicate(true)
		self_cast["delivery"] = "instant"
		self_cast["lifetime"] = 0.0
	elif casts.has("self") and not casts.has("foe"):
		foe = self_cast.duplicate(true)
		if str(foe["delivery"]) == "instant":
			foe["delivery"] = "projectile"
			foe["lifetime"] = 3.0
			foe["speed"] = fallback_speed
	elif not casts.has("foe") and not casts.has("self"):
		load_errors.append("У связки %s нет casts.foe и casts.self" % key)
		return
	spells[key] = {
		"id": str(src.get("id", key)),
		"key": key,
		"elements": ids,
		"foe": foe,
		"self": self_cast,
	}


func _normalize_cast(src: Dictionary, color: Color, default_delivery: String) -> Dictionary:
	var delivery := str(src.get("delivery", default_delivery))
	if delivery not in ["projectile", "beam", "area", "instant"]:
		load_errors.append("Неизвестная подача '%s'" % delivery)
		delivery = default_delivery
	var effects: Array = []
	for raw in src.get("effects", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var kind := str(raw.get("kind", "damage"))
		var amount: Variant = raw.get("amount", 0)
		var effect := {"kind": kind, "duration": float(raw.get("duration", 0.0))}
		if kind == "slow":
			effect["amount"] = float(amount)
		else:
			effect["amount"] = int(amount)
		effects.append(effect)
	var cast_color := color
	if src.has("color"):
		cast_color = _color(str(src["color"]))
	return {
		"name": str(src.get("name", "Магия")),
		"delivery": delivery,
		"speed": _num(src, "speed", 240.0),
		"radius": _num(src, "radius", _default_radius(delivery)),
		"length": _num(src, "length", 180.0),
		"lifetime": _num(src, "lifetime", _default_lifetime(delivery)),
		"offset": _num(src, "offset", 64.0 if delivery == "area" else 0.0),
		"color": cast_color,
		"effects": effects,
	}


func resolve(queue: Array, mode: String) -> Dictionary:
	var left := cancel(queue)
	var removed := queue.size() - left.size()
	if left.is_empty():
		return {
			"fizzle": true,
			"fallback": false,
			"id": "fizzle",
			"name": fizzle_name,
			"target": mode,
			"delivery": "none",
			"speed": 0.0,
			"radius": 8.0,
			"length": 0.0,
			"lifetime": 0.25,
			"offset": 0.0,
			"color": Color(0.75, 0.75, 0.8),
			"effects": [],
			"cancelled": removed,
		}
	var key := _key(left)
	if not spells.has(key):
		return _fallback(left, mode, removed)
	var entry: Dictionary = spells[key]
	var cast: Dictionary = entry["self"] if mode == "self" else entry["foe"]
	return _pack(str(entry["id"]), cast, mode, removed, false)


func preview(queue: Array) -> Dictionary:
	if queue.is_empty():
		return {"text": "", "color": Color(1, 1, 1, 0.7)}
	var foe := resolve(queue, "foe")
	var self_cast := resolve(queue, "self")
	var text := str(foe["name"])
	if bool(foe["fizzle"]):
		text = str(foe["name"])
	elif str(foe["name"]) != str(self_cast["name"]):
		text = "враг: %s\nсебя: %s" % [foe["name"], self_cast["name"]]
	return {"text": text, "color": foe["color"]}


func cancel(queue: Array) -> Array[String]:
	var pool: Array[String] = []
	for item in queue:
		var element_id := str(item)
		if elements.has(element_id):
			pool.append(element_id)
	var index := 0
	while index < pool.size():
		var removed := false
		var element_id: String = pool[index]
		var other := index + 1
		while other < pool.size():
			if _opposites(element_id, pool[other]):
				pool.remove_at(other)
				pool.remove_at(index)
				removed = true
				break
			other += 1
		if not removed:
			index += 1
	return pool


## Пауза после каста: база + добавка за каждую сферу в очереди.
## Лечение умножает паузу, чтобы хил не отменял размен.
func cooldown_for(orb_count: int, effects: Array) -> float:
	var cooldown := cast_cooldown + cast_cooldown_per_orb * float(maxi(orb_count, 0))
	for effect in effects:
		if str(effect.get("kind", "")) == "heal":
			return cooldown * heal_cooldown_multiplier
	return cooldown


func color_of(element_id: String) -> Color:
	if elements.has(element_id):
		return elements[element_id]["color"]
	return Color.WHITE


func letter_of(element_id: String) -> String:
	if elements.has(element_id):
		return str(elements[element_id]["letter"])
	return "?"


func name_of(element_id: String) -> String:
	if elements.has(element_id):
		return str(elements[element_id]["name"])
	return element_id


func _fallback(ids: Array[String], mode: String, removed: int) -> Dictionary:
	var amount := fallback_base + fallback_per * ids.size()
	var cast := {
		"name": fallback_name,
		"delivery": "instant" if mode == "self" else "projectile",
		"speed": fallback_speed,
		"radius": fallback_radius,
		"length": 180.0,
		"lifetime": 0.0 if mode == "self" else 3.0,
		"offset": 0.0,
		"color": _blend(ids),
		"effects": [{"kind": "damage", "amount": amount, "duration": 0.0}],
	}
	return _pack("raw", cast, mode, removed, true)


func _pack(id: String, cast: Dictionary, mode: String, removed: int, is_fallback: bool) -> Dictionary:
	return {
		"fizzle": false,
		"fallback": is_fallback,
		"id": id,
		"name": cast["name"],
		"target": mode,
		"delivery": cast["delivery"],
		"speed": float(cast["speed"]),
		"radius": float(cast["radius"]),
		"length": float(cast["length"]),
		"lifetime": float(cast["lifetime"]),
		"offset": float(cast["offset"]),
		"color": cast["color"],
		"effects": (cast["effects"] as Array).duplicate(true),
		"cancelled": removed,
	}


func _key(ids: Array) -> String:
	var parts: PackedStringArray = []
	for element_id in ids:
		parts.append(str(element_id))
	parts.sort()
	return "+".join(parts)


func _opposites(a: String, b: String) -> bool:
	if not elements.has(a) or not elements.has(b):
		return false
	return b in elements[a]["opposites"] or a in elements[b]["opposites"]


func _blend(ids: Array) -> Color:
	if ids.is_empty():
		return Color.WHITE
	var sum := Color(0, 0, 0, 0)
	for element_id in ids:
		var sample: Color = color_of(str(element_id))
		sum += sample
	var mixed := Color(sum.r / ids.size(), sum.g / ids.size(), sum.b / ids.size())
	var gray := (mixed.r + mixed.g + mixed.b) / 3.0
	mixed.r = clampf(gray + (mixed.r - gray) * 1.35, 0.0, 1.0)
	mixed.g = clampf(gray + (mixed.g - gray) * 1.35, 0.0, 1.0)
	mixed.b = clampf(gray + (mixed.b - gray) * 1.35, 0.0, 1.0)
	return mixed


func _color(hex: String) -> Color:
	return Color.html(hex)


func _num(src: Dictionary, key: String, default_value: float) -> float:
	if src.has(key):
		return float(src[key])
	return default_value


func _default_radius(delivery: String) -> float:
	match delivery:
		"beam":
			return 6.0
		"area":
			return 36.0
		"instant":
			return 14.0
		_:
			return 5.0


func _default_lifetime(delivery: String) -> float:
	match delivery:
		"projectile":
			return 3.0
		"beam":
			return 0.16
		"area":
			return 0.32
		_:
			return 0.0
