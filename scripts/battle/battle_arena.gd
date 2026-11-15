extends Node3D

## Арена. Единственная точка, которая меняет бой: apply_command().
## Ввод и бот только присылают BattleCommand.

const SpellFx := preload("res://scripts/battle/spell_fx.gd")
const DemoDriver := preload("res://scripts/battle/demo_driver.gd")
const BODY_RADIUS := 14.0
const SPAWN_OFFSET := 18.0
const ARENA_CENTER := Vector3(320, 0, 0)

var book: Spellbook = Spellbook.new()
var mages: Array[Mage] = []
var round_over: bool = false
var winner_slot: int = -1
var last_cast_name: String = ""
var bot_enabled: bool = true

var _spells: Array = []
var _camera: Camera3D
var _focus := ARENA_CENTER

@onready var hud = $HUD
@onready var spell_layer: Node3D = $Spells
@onready var fx_layer: Node3D = $Fx


func _ready() -> void:
	bot_enabled = not get_tree().root.has_meta("magicka_test")
	if not book.load_from_file():
		hud.show_toast("Не удалось прочитать заклинания", Color("ff5d4d"))
	mages.append($Mages/Mage1 as Mage)
	mages.append($Mages/Mage2 as Mage)
	var robes: Array[Color] = [Color("3a56e8"), Color("d43b4a")]
	var hats: Array[Color] = [Color("241a66"), Color("7a1428")]
	for i in mages.size():
		mages[i].setup(i, robes[i], hats[i], book.max_hp, book.max_shield)
	_build_world()
	_build_camera()
	($Hotseat as Node).command_issued.connect(apply_command)
	_refresh_hud()
	hud.show_toast("Соберите до 3 сфер", Color.WHITE)
	if OS.get_cmdline_user_args().has("--demo"):
		bot_enabled = false
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
			var planar := Vector2(cmd.direction, cmd.strafe)
			if planar.length() > 1.0:
				planar = planar.normalized()
			mage.move_dir = planar
	elif cmd.action == BattleCommand.Action.AIM:
		if mage.alive:
			mage.use_aim = true
			mage.aim_point = Vector3(cmd.aim_x, 0, cmd.aim_z)
	elif cmd.action == BattleCommand.Action.QUEUE_ELEMENT:
		_queue(mage, cmd.element_id)
	elif cmd.action == BattleCommand.Action.CLEAR_QUEUE:
		if mage.alive and not round_over:
			mage.orbs.clear()
	elif cmd.action == BattleCommand.Action.CAST:
		_cast(mage, cmd.cast_at_self)
	_refresh_hud()


func _process(delta: float) -> void:
	_follow_camera(delta)


func _physics_process(delta: float) -> void:
	if mages.is_empty():
		return
	for mage in mages:
		mage.tick(delta)
		if mage.alive:
			var speed := book.move_speed * mage.slow_factor
			mage.velocity = Vector3(mage.move_dir.x, 0, mage.move_dir.y) * speed
			mage.move_and_slide()
			mage.position.y = 0.0
			mage.position.x = clampf(mage.position.x, book.arena_min_x, book.arena_max_x)
			mage.position.z = clampf(mage.position.z, -210.0, 210.0)
		else:
			mage.velocity = Vector3.ZERO
		var other := _other(mage)
		if other and not mage.use_aim:
			var flat := other.global_position - mage.global_position
			flat.y = 0
			if flat.length() > 0.5:
				mage.set_facing_dir(flat)
		elif mage.use_aim:
			var aimed := mage.aim_point - mage.global_position
			aimed.y = 0
			if aimed.length() > 0.5:
				mage.set_facing_dir(aimed)
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
	mage.play_cast()
	if bool(result["fizzle"]) or str(result["delivery"]) == "none":
		_burst(mage.chest(), result["color"], 8.0, 0.22)
		return
	if str(result["delivery"]) == "instant":
		_cast_instant(mage, result)
	else:
		_spawn_spell(mage, result)


func _cast_instant(mage: Mage, result: Dictionary) -> void:
	var kind := "heal" if _has_kind(result["effects"], "heal") else "flash"
	if str(result["target"]) == "self":
		_affect(mage, result["effects"], result["color"])
		_burst(mage.chest(), result["color"], 10.0, 0.45, kind)
		return
	var other := _other(mage)
	var reach := float(result["length"]) + BODY_RADIUS
	if other and _flat_distance(mage.chest(), other.chest()) <= reach:
		_affect(other, result["effects"], result["color"])
		_burst(other.chest(), result["color"], 10.0, 0.45, kind)
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
	spell.dir = mage.facing_dir
	if spell.dir.length() < 0.01:
		spell.dir = Vector3.RIGHT
	spell.dir = spell.dir.normalized()
	spell.color = result["color"]
	spell.origin = mage.chest()
	if spell.delivery == "area":
		spell.pos = spell.origin + spell.dir * float(result["offset"])
	else:
		spell.pos = spell.origin + spell.dir * SPAWN_OFFSET
	spell.vel = spell.dir * float(result["speed"])
	var fx: Node3D = SpellFx.new()
	var visual_radius := spell.radius if spell.delivery != "beam" else maxf(spell.radius, 3.0)
	fx.setup(spell.delivery, spell.color, visual_radius, spell.length, spell.dir, spell.max_life, false)
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
		var offscreen: bool = spell.delivery == "projectile" and (spell.pos.x < -80.0 or spell.pos.x > 760.0 or absf(spell.pos.z) > 360.0)
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
			if _flat_distance(spell.pos, mage.chest()) <= spell.radius + BODY_RADIUS:
				_affect(mage, spell.effects, spell.color)
				spell.hit.append(mage.slot)
				spell.life = 0.0
				_burst(spell.pos, spell.color, spell.radius + 4.0, 0.2)
				return
	elif spell.delivery == "beam":
		var end: Vector3 = spell.origin + spell.dir * spell.length
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
			var chest: Vector3 = mage.chest()
			var in_blast := _flat_distance(spell.pos, chest) <= reach
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
		var at := mage.chest() + Vector3(0, 8.0 + float(i) * 4.0, 0)
		_popup(at, str(popup["text"]), popup["color"])
	mage.flash(color)
	if _has_kind(effects, "heal"):
		_burst(mage.chest(), Color("7dffa8"), 8.0, 0.6, "heal")
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


func _burst(at: Vector3, color: Color, radius: float, time: float, kind: String = "flash") -> void:
	var fx: Node3D = SpellFx.new()
	fx.setup(kind, color, radius, 0.0, Vector3.UP, time, true)
	fx.position = at
	fx_layer.add_child(fx)


func _popup(at: Vector3, text: String, color: Color) -> void:
	if _camera == null:
		return
	if not _camera.is_position_behind(at):
		hud.popup(_camera.unproject_position(at), text, color)


func _other(mage: Mage) -> Mage:
	for other in mages:
		if other != mage:
			return other
	return null


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _dist_to_segment(point: Vector3, start: Vector3, end: Vector3) -> float:
	var a := Vector2(start.x, start.z)
	var b := Vector2(end.x, end.z)
	var p := Vector2(point.x, point.z)
	var span := b - a
	var length_sq := span.length_squared()
	if length_sq <= 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(span) / length_sq, 0.0, 1.0)
	return p.distance_to(a + span * t)


func _has_kind(effects: Array, kind: String) -> bool:
	for effect in effects:
		if str(effect.get("kind", "")) == kind:
			return true
	return false


func _follow_camera(delta: float) -> void:
	if _camera == null or mages.size() < 2:
		return
	var separation := mages[0].global_position.distance_to(mages[1].global_position)
	var span := clampf(separation * 0.62 + 150.0, 210.0, 520.0)
	var focus := (mages[0].global_position + mages[1].global_position) * 0.5
	focus.y = 16.0
	var weight := 1.0 - exp(-3.4 * delta)
	_focus = _focus.lerp(focus, weight)
	var offset := Vector3(0.95, 1.22, 1.05).normalized() * span
	_camera.global_position = _focus + offset
	_camera.look_at(_focus, Vector3.UP)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Rig"
	_camera.fov = 42.0
	_camera.current = true
	add_child(_camera)
	_focus = ARENA_CENTER + Vector3(0, 16, 0)
	_follow_camera(1.0)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("14111c")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("6e6788")
	world.ambient_light_energy = 0.85
	world.fog_enabled = true
	world.fog_light_color = Color("2a2438")
	world.fog_density = 0.0012
	world.fog_aerial_perspective = 0.15
	env.environment = world
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 36, 0)
	sun.light_color = Color("ffe6c4")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, -140, 0)
	fill.light_color = Color("8ea4ff")
	fill.light_energy = 0.35
	add_child(fill)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(980, 760)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = ARENA_CENTER
	floor.material_override = _floor_material()
	add_child(floor)

	var curb := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 214.0
	torus.outer_radius = 236.0
	torus.rings = 48
	torus.ring_segments = 12
	curb.mesh = torus
	curb.position = ARENA_CENTER + Vector3(0, 3.2, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("3a3348")
	stone.roughness = 0.86
	curb.material_override = stone
	add_child(curb)

	for i in 8:
		var angle := TAU * float(i) / 8.0
		var at := ARENA_CENTER + Vector3(cos(angle), 0, sin(angle)) * 248.0
		_pillar(at, i % 2 == 0)

	var rune := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 78.0
	ring.outer_radius = 86.0
	ring.rings = 40
	ring.ring_segments = 8
	rune.mesh = ring
	rune.position = ARENA_CENTER + Vector3(0, 0.4, 0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("e7c56a")
	glow.emission_enabled = true
	glow.emission = Color("e7c56a")
	glow.emission_energy_multiplier = 1.3
	rune.material_override = glow
	add_child(rune)


func _pillar(at: Vector3, brazier: bool) -> void:
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 7.0
	mesh.bottom_radius = 9.0
	mesh.height = 46.0
	column.mesh = mesh
	column.position = at + Vector3(0, 23, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2c2638")
	mat.roughness = 0.9
	column.material_override = mat
	add_child(column)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 11.0
	cap_mesh.bottom_radius = 11.0
	cap_mesh.height = 3.0
	cap.mesh = cap_mesh
	cap.position = at + Vector3(0, 47, 0)
	cap.material_override = mat
	add_child(cap)
	if not brazier:
		return
	var flame := MeshInstance3D.new()
	var fire := SphereMesh.new()
	fire.radius = 3.2
	fire.height = 7.0
	flame.mesh = fire
	flame.position = at + Vector3(0, 52, 0)
	var fire_mat := StandardMaterial3D.new()
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_mat.albedo_color = Color(1, 0.62, 0.22, 0.9)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color("ff8a2a")
	fire_mat.emission_energy_multiplier = 2.5
	flame.material_override = fire_mat
	add_child(flame)
	var light := OmniLight3D.new()
	light.position = flame.position
	light.light_color = Color("ffb15a")
	light.light_energy = 1.1
	light.omni_range = 90.0
	add_child(light)


func _floor_material() -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var mortar := x % 16 == 0 or y % 16 == 0
			var tile := 0.02 if (int(x / 16) + int(y / 16)) % 2 == 0 else 0.0
			var grain := sin(float(x) * 1.7) * sin(float(y) * 1.3) * 0.012
			var shade := 0.2 + tile + grain
			if mortar:
				shade *= 0.72
			image.set_pixel(x, y, Color(shade * 0.9, shade * 0.84, shade))
	var texture := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.92
	mat.uv1_scale = Vector3(8, 8, 1)
	return mat


class ActiveSpell extends RefCounted:
	var owner: int = 0
	var target: String = "foe"
	var delivery: String = "projectile"
	var effects: Array = []
	var pos: Vector3 = Vector3.ZERO
	var vel: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.RIGHT
	var radius: float = 6.0
	var length: float = 0.0
	var life: float = 1.0
	var max_life: float = 1.0
	var color: Color = Color.WHITE
	var origin: Vector3 = Vector3.ZERO
	var hit: Array[int] = []
	var fx: Node3D
