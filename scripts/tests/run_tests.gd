extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	_test_commands()
	_test_spellbook()
	var packed: PackedScene = load("res://scenes/battle/battle_arena.tscn")
	var arena: Node = packed.instantiate()
	root.add_child(arena)
	await process_frame
	await _test_battle(arena)
	if _failures > 0:
		print("FAILED %d" % _failures)
		quit(1)
	else:
		print("ALL PASSED")
		quit(0)


func _test_commands() -> void:
	var cmd := BattleCommand.new()
	cmd.slot = 1
	cmd.action = BattleCommand.Action.CAST
	cmd.cast_at_self = true
	cmd.element_id = "fire"
	cmd.direction = -1.0
	var back := BattleCommand.from_dict(cmd.to_dict())
	_expect(back.slot == 1, "command slot")
	_expect(back.action == BattleCommand.Action.CAST, "command action")
	_expect(back.cast_at_self, "command self")
	_expect(back.element_id == "fire", "command element")
	_expect(is_equal_approx(back.direction, -1.0), "command direction")


func _test_spellbook() -> void:
	var broken := Spellbook.new()
	broken.load_data({
		"elements": {"fire": {"name": "Огонь", "color": "#ff0000", "opposites": []}},
		"spells": [{
			"id": "bad",
			"elements": ["nope"],
			"casts": {"foe": {"name": "Нет", "delivery": "projectile", "effects": []}},
		}],
	})
	_expect(not broken.load_errors.is_empty(), "unknown element is reported")

	var book := Spellbook.new()
	_expect(book.load_from_file(), "spells.json loads")
	_expect(book.load_errors.is_empty(), "no load errors")
	_expect(book.elements.size() == 5, "five elements")
	_expect(book.spells.size() == 43, "43 combos, got %d" % book.spells.size())
	_expect(book.max_queue == 3, "queue of 3")

	for element_id in book.elements.keys():
		for other in book.elements[element_id]["opposites"]:
			var back: Array = book.elements[other]["opposites"]
			_expect(element_id in back, "opposites %s/%s are symmetric" % [element_id, other])

	var fizzle := book.resolve(["fire", "water"], "foe")
	_expect(bool(fizzle["fizzle"]), "fire+water fizzles")
	var partial := book.resolve(["fire", "fire", "water"], "foe")
	_expect(str(partial["id"]) == "fire", "fire+fire+water leaves a fireball")
	_expect(_amount(partial, "damage") == 16, "partial fire damage")
	var rock := book.resolve(["fire", "water", "earth"], "foe")
	_expect(str(rock["id"]) == "earth", "fire+water+earth leaves earth")
	var life_left := book.resolve(["lightning", "earth", "life"], "self")
	_expect(str(life_left["id"]) == "life", "lightning+earth cancel, life remains")
	_expect(_amount(life_left, "heal") == 12, "remaining life heals on self")

	var inferno := book.resolve(["fire", "fire", "fire"], "foe")
	_expect(str(inferno["delivery"]) == "area", "inferno is an area")
	_expect(_amount(inferno, "damage") == 36, "inferno damage")
	var heal := book.resolve(["life"], "self")
	var smite := book.resolve(["life"], "foe")
	_expect(str(heal["name"]) == "Исцеление", "life self name")
	_expect(str(smite["name"]) == "Кара", "life foe name")
	_expect(_amount(heal, "heal") == 12, "heal amount")
	_expect(_amount(smite, "damage") == 12, "smite damage")
	var spark := book.resolve(["lightning"], "foe")
	_expect(_amount(spark, "damage") == 11, "single beam is 25 percent under 15")
	var ward := book.resolve(["earth", "life"], "self")
	_expect(_amount(ward, "shield") == 24, "stone shield")
	_expect(is_equal_approx(book.cooldown_for(1, spark["effects"]), 0.4), "one orb is 0.4s")
	_expect(is_equal_approx(book.cooldown_for(3, spark["effects"]), 0.7), "three orbs are 0.7s")
	_expect(is_equal_approx(book.cooldown_for(1, heal["effects"]), 1.0), "a heal waits 2.5x")
	var magma_a := book.resolve(["earth", "fire"], "foe")
	var magma_b := book.resolve(["fire", "earth"], "foe")
	_expect(str(magma_a["id"]) == str(magma_b["id"]), "order does not matter")
	var mud := book.resolve(["water", "earth"], "foe")
	_expect(_has_kind(mud, "slow"), "mud slows")

	for key in book.spells.keys():
		var ids: PackedStringArray = str(key).split("+")
		var foe := book.resolve(ids, "foe")
		var self_cast := book.resolve(ids, "self")
		_expect(not bool(foe["fizzle"]) and not bool(foe["fallback"]), "combo %s resolves" % key)
		_expect(str(foe["id"]) == str(book.spells[key]["id"]), "combo id %s" % key)
		_expect(not bool(self_cast["fizzle"]), "self combo %s" % key)
		var pool: Array = []
		for element_id in ids:
			pool.append(element_id)
		for i in pool.size():
			for j in range(i + 1, pool.size()):
				var opposite := book._opposites(str(pool[i]), str(pool[j]))
				_expect(not opposite, "combo %s has no opposite pair" % key)

	var saved: Dictionary = book.spells["fire+fire"].duplicate(true)
	book.spells.erase("fire+fire")
	var raw := book.resolve(["fire", "fire"], "foe")
	_expect(bool(raw["fallback"]), "missing combo falls back")
	_expect(str(raw["name"]) == "Сырая магия", "fallback name")
	_expect(_amount(raw, "damage") == 20, "fallback damage 8+6*2")
	book.spells["fire+fire"] = saved
	var restored := book.resolve(["fire", "fire"], "foe")
	_expect(str(restored["name"]) == "Большой огненный шар", "combo restored")


func _test_battle(arena: Node) -> void:
	_expect(arena.book.spells.size() == 43, "arena loaded the spellbook")
	var left: Mage = arena.mages[0]
	var right: Mage = arena.mages[1]
	var start_x := left.position.x
	arena.apply_command(_move(0, 1.0))
	await _frames(20)
	_expect(left.position.x > start_x + 5.0, "move command walks the mage")
	arena.apply_command(_move(0, 0.0))
	left.position.x = 220.0
	right.position.x = 300.0

	for _i in 4:
		arena.apply_command(_queue(0, "fire"))
	_expect(left.orbs.size() == 3, "queue caps at 3")
	_expect(str(arena.hud.toast.text) == "Очередь полна", "queue full toast")
	arena.apply_command(_clear(0))
	_expect(left.orbs.is_empty(), "clear queue")

	var hp_before := right.hp
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_queue(0, "water"))
	arena.apply_command(_cast(0, false))
	_expect(is_equal_approx(left.cast_lock, 0.55), "two orbs wait 0.55s, lock=%s" % left.cast_lock)
	await _frames(5)
	_expect(right.hp == hp_before, "cancelled orbs do no damage")
	_expect(str(arena.last_cast_name) == "Сферы погасли", "fizzle name")
	await _await_cast_ready(left)

	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_queue(0, "water"))
	arena.apply_command(_cast(0, false))
	_expect(is_equal_approx(left.cast_lock, 0.7), "three orbs wait 0.7s, lock=%s" % left.cast_lock)
	await _frames(40)
	_expect(right.hp == 84, "partial cancel casts a 16-damage fireball, hp=%d" % right.hp)
	await _await_cast_ready(left)

	left.hp = 50
	arena.apply_command(_queue(0, "life"))
	arena.apply_command(_cast(0, true))
	_expect(is_equal_approx(left.cast_lock, 1.0), "heal waits 1s, lock=%s" % left.cast_lock)
	await _frames(5)
	_expect(left.hp == 62, "self life heals to 62, hp=%d" % left.hp)
	_expect(str(arena.last_cast_name) == "Исцеление", "heal cast name")
	await _await_cast_ready(left)

	arena.apply_command(_queue(0, "earth"))
	arena.apply_command(_queue(0, "life"))
	arena.apply_command(_cast(0, true))
	_expect(left.shield == 24, "self earth+life grants 24 shield, shield=%d" % left.shield)
	var hp_at_shield := left.hp
	arena.apply_command(_queue(1, "fire"))
	arena.apply_command(_cast(1, false))
	await _frames(40)
	_expect(left.hp == hp_at_shield, "shield absorbs the fireball, hp=%d" % left.hp)
	_expect(left.shield == 8, "shield left 8, shield=%d" % left.shield)
	await _await_cast_ready(left)

	left.position.x = 240.0
	right.position.x = 290.0
	var hp_before_inferno := right.hp
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_cast(0, false))
	await _frames(8)
	_expect(right.hp == hp_before_inferno - 36, "point-blank inferno hits, hp=%d" % right.hp)
	await _await_cast_ready(left)

	right.hp = 10
	arena.apply_command(_queue(0, "fire"))
	arena.apply_command(_cast(0, false))
	await _frames(40)
	_expect(not right.alive, "lethal fireball kills")
	_expect(arena.round_over, "round ends")
	_expect(arena.winner_slot == 0, "mage 1 wins, winner=%d" % arena.winner_slot)

	var restart := BattleCommand.new()
	restart.action = BattleCommand.Action.RESTART
	arena.apply_command(restart)
	_expect(not arena.round_over, "restart clears the round")
	_expect(left.hp == left.max_hp and right.hp == right.max_hp, "restart restores hp")
	_expect(left.shield == 0 and right.alive, "restart restores shield and life")
	_expect(is_equal_approx(left.position.x, 118.0), "restart returns mage 1")
	_expect(is_equal_approx(right.position.x, 522.0), "restart returns mage 2")


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _await_cast_ready(mage: Mage) -> void:
	var guard := 0
	while mage.cast_lock > 0.0 and guard < 500:
		await physics_frame
		guard += 1
	_expect(mage.cast_lock <= 0.0, "cooldown finished, lock=%s" % mage.cast_lock)


func _queue(slot: int, element_id: String) -> BattleCommand:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.QUEUE_ELEMENT
	cmd.element_id = element_id
	return cmd


func _cast(slot: int, at_self: bool) -> BattleCommand:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.CAST
	cmd.cast_at_self = at_self
	return cmd


func _clear(slot: int) -> BattleCommand:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.CLEAR_QUEUE
	return cmd


func _move(slot: int, direction: float) -> BattleCommand:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.MOVE
	cmd.direction = direction
	return cmd


func _amount(result: Dictionary, kind: String) -> int:
	var total := 0
	for effect in result["effects"]:
		if str(effect["kind"]) == kind and kind != "slow":
			total += int(effect["amount"])
	return total


func _has_kind(result: Dictionary, kind: String) -> bool:
	for effect in result["effects"]:
		if str(effect["kind"]) == kind:
			return true
	return false


func _expect(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		_failures += 1
		print("FAIL ", message)
