extends Node2D

## Арена. Единственная точка, которая меняет бой: apply_command().
## LocalHotseat (и будущий сетевой слой) только присылают BattleCommand.

const SpellFx := preload("res://scripts/battle/spell_fx.gd")
const DemoDriver := preload("res://scripts/battle/demo_driver.gd")
const BODY_RADIUS := 14.0
const SPAWN_OFFSET := 18.0

var book: Spellbook = Spellbook.new()
var mages: Array[Mage] = []
var round_over: bool = false
var winner_slot: int = -1
var last_cast_name: String = ""

var _spells: Array = []

@onready var hud = $HUD
@onready var spell_layer: Node2D = $Spells
@onready var fx_layer: Node2D = $Fx


func _ready() -> void:
	if not book.load_from_file():
		hud.show_toast("Не удалось прочитать заклинания", Color("ff5d4d"))
	mages.append($Mages/Mage1 as Mage)
	mages.append($Mages/Mage2 as Mage)
	var robes: Array[Color] = [Color("3a56e8"), Color("d43b4a")]
	var hats: Array[Color] = [Color("1c2370"), Color("7a1428")]
	for i in mages.size():
		mages[i].setup(i, robes[i], hats[i], book.max_hp, book.max_shield)
	_build_backdrop()
	($Hotseat as Node).command_issued.connect(apply_command)
	_refresh_hud()
	hud.show_toast("Соберите до 3 сфер", Color.WHITE)
	if OS.get_cmdline_user_args().has("--demo"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i.ZERO)
		add_child(DemoDriver.new())


func apply_command(cmd: BattleCommand) -> void:
	if cmd.action == BattleCommand.Action.RESTART:
		_restart()
		_refresh_hud()
		return
	if cmd.slot < 0 or cmd.slot >= mages.size():
		return
	var mage := mages[cmd.slot]
	if cmd.action == BattleCommand.Action.MOVE:
		if mage.alive:
			mage.move_dir = clampf(cmd.direction, -1.0, 1.0)
	elif cmd.action == BattleCommand.Action.QUEUE_ELEMENT:
		_queue(mage, cmd.element_id)
	elif cmd.action == BattleCommand.Action.CLEAR_QUEUE:
		if mage.alive and not round_over:
			mage.orbs.clear()
	elif cmd.action == BattleCommand.Action.CAST:
		_cast(mage, cmd.cast_at_self)
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if mages.is_empty():
		return
	for mage in mages:
		mage.tick(delta)
		if mage.alive:
			mage.velocity = Vector2(mage.move_dir * book.move_speed * mage.slow_factor, 0.0)
			mage.move_and_slide()
			mage.position.y = mage.spawn_y
			mage.position.x = clampf(mage.position.x, book.arena_min_x, book.arena_max_x)
		else:
			mage.velocity = Vector2.ZERO
		var other := _other(mage)
		if other:
			var dx := other.position.x - mage.position.x
			if absf(dx) > 0.5:
				mage.set_facing(signf(dx))
	_tick_spells(delta)
	_refresh_hud()


func _queue(mage: Mage, element_id: String) -> void:
	if not mage.alive or round_over:
		return
	if not book.elements.has(element_id):
		hud.show_toast("Неизвестная сфера", Color.WHITE)
		return
	if mage.orbs.size() >= book.max_queue:
		hud.show_toast("Очередь полна", Color("ffe14a"))
		return
	mage.orbs.append(element_id)


func _cast(mage: Mage, at_self: bool) -> void:
	if not mage.alive or round_over:
		return
	if mage.cast_lock > 0.0:
		return
	if mage.orbs.is_empty():
		hud.show_toast("Нет сфер", Color(0.82, 0.82, 0.86))
		mage.cast_lock = 0.12
		return
	var mode := "self" if at_self else "foe"
	var orb_count := mage.orbs.size()
	var result := book.resolve(mage.orbs, mode)
	mage.orbs.clear()
	mage.cast_lock = book.cooldown_for(orb_count, result["effects"])
	last_cast_name = str(result["name"])
	hud.show_toast(last_cast_name, result["color"])
	if bool(result["fizzle"]) or str(result["delivery"]) == "none":
		_burst(mage.chest(), result["color"], 8.0, 0.22)
		return
	if str(result["delivery"]) == "instant":
		_cast_instant(mage, result)
	else:
		_spawn_spell(mage, result)


func _cast_instant(mage: Mage, result: Dictionary) -> void:
	if str(result["target"]) == "self":
		_affect(mage, result["effects"], result["color"])
		_burst(mage.chest(), result["color"], 16.0, 0.28)
		return
	var other := _other(mage)
	var reach := float(result["length"]) + BODY_RADIUS
	if other and mage.chest().distance_to(other.chest()) <= reach:
		_affect(other, result["effects"], result["color"])
		_burst(other.chest(), result["color"], 16.0, 0.28)
	else:
		hud.show_toast("%s — мимо" % str(result["name"]), result["color"])


func _spawn_spell(mage: Mage, result: Dictionary) -> void:
	var spell := ActiveSpell.new()
	spell.owner = mage.slot
	spell.target = str(result["target"])
	spell.delivery = str(result["delivery"])
	spell.effects = result["effects"]
	spell.radius = float(result["radius"])
	spell.length = float(result["length"])
	spell.life = maxf(float(result["lifetime"]), 0.05)
	spell.max_life = spell.life
	spell.facing = mage.facing
	spell.color = result["color"]
	spell.origin = mage.chest()
	if spell.delivery == "area":
		spell.pos = spell.origin + Vector2(mage.facing * float(result["offset"]), 0.0)
	else:
		spell.pos = spell.origin + Vector2(mage.facing * SPAWN_OFFSET, 0.0)
	spell.vel = Vector2(mage.facing * float(result["speed"]), 0.0)
	var fx = SpellFx.new()
	var visual_radius := spell.radius if spell.delivery != "beam" else maxf(spell.radius, 3.0)
	fx.setup(spell.delivery, spell.color, visual_radius, spell.length, spell.facing, spell.max_life, false)
	fx.position = spell.origin if spell.delivery == "beam" else spell.pos
	spell_layer.add_child(fx)
	spell.fx = fx
	_spells.append(spell)
	if spell.delivery != "projectile":
		_collide(spell)


func _tick_spells(delta: float) -> void:
	var kept: Array = []
	for spell in _spells:
		spell.life -= delta
		if spell.delivery == "projectile":
			spell.pos += spell.vel * delta
			if spell.fx and is_instance_valid(spell.fx):
				spell.fx.position = spell.pos
		if spell.life > 0.0 and not round_over:
			_collide(spell)
		var offscreen: bool = spell.delivery == "projectile" and (spell.pos.x < -40.0 or spell.pos.x > 680.0)
		if spell.life > 0.0 and not offscreen:
			kept.append(spell)
		elif spell.fx and is_instance_valid(spell.fx):
			spell.fx.queue_free()
	_spells = kept


func _collide(spell: ActiveSpell) -> void:
	if spell.delivery == "projectile":
		for mage in mages:
			if not _can_hit(spell, mage):
				continue
			if spell.pos.distance_to(mage.chest()) <= spell.radius + BODY_RADIUS:
				_affect(mage, spell.effects, spell.color)
				spell.hit.append(mage.slot)
				spell.life = 0.0
				_burst(spell.pos, spell.color, spell.radius + 4.0, 0.16)
				return
	elif spell.delivery == "beam":
		var end := spell.origin + Vector2(spell.facing * spell.length, 0.0)
		for mage in mages:
			if not _can_hit(spell, mage):
				continue
			if _dist_to_segment(mage.chest(), spell.origin, end) <= spell.radius + BODY_RADIUS:
				_affect(mage, spell.effects, spell.color)
				spell.hit.append(mage.slot)
	elif spell.delivery == "area":
		var reach := spell.radius + 10.0
		for mage in mages:
			if not _can_hit(spell, mage):
				continue
			var chest := mage.chest()
			var in_blast := spell.pos.distance_to(chest) <= reach
			# Взрыв впереди кастера задевает и того, кто стоит вплотную между ними.
			var in_path := _dist_to_segment(chest, spell.origin, spell.pos) <= 18.0
			if in_blast or in_path:
				_affect(mage, spell.effects, spell.color)
				spell.hit.append(mage.slot)


func _can_hit(spell: ActiveSpell, mage: Mage) -> bool:
	if not mage.alive:
		return false
	if mage.slot in spell.hit:
		return false
	if spell.target == "self":
		return mage.slot == spell.owner
	return mage.slot != spell.owner


func _affect(mage: Mage, effects: Array, color: Color) -> void:
	var was_alive := mage.alive
	var popups: Array = mage.apply_effects(effects)
	for i in popups.size():
		var popup: Dictionary = popups[i]
		var at := mage.chest() + Vector2(10.0 * mage.facing, -8.0 - float(i) * 12.0)
		hud.popup(at, str(popup["text"]), popup["color"])
	mage.flash(color)
	if was_alive and not mage.alive:
		_check_round()


func _check_round() -> void:
	if round_over:
		return
	var living: Array[int] = []
	for mage in mages:
		if mage.alive:
			living.append(mage.slot)
	if living.size() == 1:
		round_over = true
		winner_slot = living[0]
		hud.show_end("Победил маг %d\nEnter — новый раунд" % [winner_slot + 1])
	elif living.is_empty():
		round_over = true
		winner_slot = -1
		hud.show_end("Ничья\nEnter — новый раунд")


func _restart() -> void:
	if not round_over:
		return
	for spell in _spells:
		if spell.fx and is_instance_valid(spell.fx):
			spell.fx.queue_free()
	_spells.clear()
	for child in fx_layer.get_children():
		child.queue_free()
	for mage in mages:
		mage.reset_match()
	round_over = false
	winner_slot = -1
	hud.hide_end()
	hud.show_toast("Новый раунд", Color.WHITE)


func _refresh_hud() -> void:
	if hud == null:
		return
	for mage in mages:
		var colors: Array[Color] = []
		var letters: Array[String] = []
		for element_id in mage.orbs:
			colors.append(book.color_of(element_id))
			letters.append(book.letter_of(element_id))
		var preview: Dictionary = book.preview(mage.orbs)
		hud.update_mage(
			mage.slot,
			mage.hp,
			mage.max_hp,
			mage.shield,
			mage.max_shield,
			letters,
			colors,
			str(preview["text"]),
			preview["color"]
		)
		mage.sync_orbs(colors)


func _burst(at: Vector2, color: Color, radius: float, time: float) -> void:
	var fx = SpellFx.new()
	fx.setup("flash", color, radius, 0.0, 1.0, time, true)
	fx.position = at
	fx_layer.add_child(fx)


func _other(mage: Mage) -> Mage:
	for other in mages:
		if other != mage:
			return other
	return null


func _dist_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var span := end - start
	var length_sq := span.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(span) / length_sq, 0.0, 1.0)
	return point.distance_to(start + span * t)


func _build_backdrop() -> void:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 640))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 360))
	var sprite := Sprite2D.new()
	sprite.name = "Backdrop"
	sprite.texture = PixelSprites.backdrop(Vector2i(width, height))
	sprite.centered = false
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	sprite.z_index = -10
	add_child(sprite)
	move_child(sprite, 0)


class ActiveSpell extends RefCounted:
	var owner: int = 0
	var target: String = "foe"
	var delivery: String = "projectile"
	var effects: Array = []
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var radius: float = 6.0
	var length: float = 0.0
	var life: float = 1.0
	var max_life: float = 1.0
	var facing: float = 1.0
	var color: Color = Color.WHITE
	var origin: Vector2 = Vector2.ZERO
	var hit: Array[int] = []
	var fx: Node2D
