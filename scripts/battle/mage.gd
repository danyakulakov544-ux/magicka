extends CharacterBody2D
class_name Mage

const HIT_LIFT := 36.0

var slot: int = 0
var max_hp: int = 100
var hp: int = 100
var max_shield: int = 80
var shield: int = 0
var orbs: Array[String] = []
var alive: bool = true
var move_dir: float = 0.0
var facing: float = 1.0
var initial_facing: float = 1.0
var spawn_position: Vector2 = Vector2.ZERO
var spawn_y: float = 0.0
var slow_factor: float = 1.0
var slow_left: float = 0.0
var cast_lock: float = 0.0

var visual: Node2D
var body: Sprite2D
var gem: Sprite2D
var aura: Sprite2D
var shadow: Sprite2D
var orbs_root: Node2D
var orb_sprites: Array[Sprite2D] = []
var _flash_left: float = 0.0
var _flash_color: Color = Color.WHITE


func setup(slot_index: int, robe: Color, hat: Color, hp_max: int, shield_max: int) -> void:
	slot = slot_index
	max_hp = hp_max
	hp = hp_max
	max_shield = shield_max
	shield = 0
	spawn_position = position
	spawn_y = position.y
	initial_facing = 1.0 if slot_index == 0 else -1.0
	facing = initial_facing
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	_build_visual(robe, hat)
	_build_collision()
	set_facing(initial_facing)


func chest() -> Vector2:
	return position + Vector2(0, -HIT_LIFT)


func set_facing(dir: float) -> void:
	if not alive or dir == 0.0:
		return
	facing = dir
	if visual:
		visual.scale = Vector2(3.0 * facing, 3.0)


func tick(delta: float) -> void:
	if cast_lock > 0.0:
		cast_lock = maxf(cast_lock - delta, 0.0)
	if slow_left > 0.0:
		slow_left = maxf(slow_left - delta, 0.0)
		if slow_left <= 0.0:
			slow_factor = 1.0
	if _flash_left > 0.0 and alive and visual:
		_flash_left = maxf(_flash_left - delta, 0.0)
		var blend := 1.0 - clampf(_flash_left / 0.12, 0.0, 1.0)
		visual.modulate = _flash_color.lerp(Color.WHITE, blend)


func take_damage(amount: int) -> Dictionary:
	var info := {"hp": 0, "shield": 0}
	if amount <= 0 or not alive:
		return info
	var left := amount
	if shield > 0:
		var used: int = mini(shield, left)
		shield -= used
		left -= used
		info["shield"] = used
	if left > 0:
		var before := hp
		hp = maxi(hp - left, 0)
		info["hp"] = before - hp
	if hp <= 0:
		_die()
	return info


func heal(amount: int) -> int:
	if amount <= 0 or not alive:
		return 0
	var before := hp
	hp = mini(hp + amount, max_hp)
	return hp - before


func add_shield(amount: int) -> int:
	if amount <= 0 or not alive:
		return 0
	var before := shield
	shield = mini(shield + amount, max_shield)
	return shield - before


func apply_slow(factor: float, duration: float) -> void:
	if not alive:
		return
	slow_factor = minf(slow_factor, clampf(factor, 0.15, 1.0))
	slow_left = maxf(slow_left, duration)


func apply_effects(effects: Array) -> Array:
	var popups: Array = []
	for effect in effects:
		if not alive:
			break
		var kind := str(effect.get("kind", ""))
		match kind:
			"damage":
				var info := take_damage(int(effect.get("amount", 0)))
				if int(info["hp"]) > 0:
					popups.append({"text": "-%d" % int(info["hp"]), "color": Color("ff5d4d")})
				if int(info["shield"]) > 0:
					popups.append({"text": "блок %d" % int(info["shield"]), "color": Color("9fd4ff")})
			"heal":
				var gained := heal(int(effect.get("amount", 0)))
				if gained > 0:
					popups.append({"text": "+%d" % gained, "color": Color("86f5a4")})
			"shield":
				var gained_shield := add_shield(int(effect.get("amount", 0)))
				if gained_shield > 0:
					popups.append({"text": "щит +%d" % gained_shield, "color": Color("9fd4ff")})
			"slow":
				apply_slow(float(effect.get("amount", 0.6)), float(effect.get("duration", 1.0)))
				popups.append({"text": "замедление", "color": Color("b7dcff")})
	return popups


func flash(color: Color) -> void:
	if not alive:
		return
	_flash_left = 0.12
	_flash_color = color.lightened(0.4)


func sync_orbs(colors: Array) -> void:
	if orbs_root:
		orbs_root.visible = alive
	for i in orb_sprites.size():
		var sprite := orb_sprites[i]
		if i < orbs.size() and i < colors.size():
			sprite.texture = PixelSprites.disc(colors[i], 5)
			sprite.modulate = Color.WHITE
		else:
			sprite.texture = PixelSprites.disc(Color(1, 1, 1, 0.16), 4)
			sprite.modulate = Color(1, 1, 1, 0.55)
	if gem:
		if orbs.size() > 0 and colors.size() > 0:
			gem.texture = PixelSprites.disc(colors[-1], 1)
		else:
			gem.texture = PixelSprites.disc(Color("ffe08a"), 1)
	if aura:
		aura.visible = alive and shield > 0
		if max_shield > 0:
			var strength := float(shield) / float(max_shield)
			aura.modulate = Color(0.7, 0.88, 1.0, 0.16 + 0.4 * strength)


func reset_match() -> void:
	hp = max_hp
	shield = 0
	orbs.clear()
	alive = true
	move_dir = 0.0
	facing = initial_facing
	slow_factor = 1.0
	slow_left = 0.0
	cast_lock = 0.0
	_flash_left = 0.0
	position = spawn_position
	velocity = Vector2.ZERO
	collision_layer = 1
	collision_mask = 1
	if visual:
		visual.rotation_degrees = 0.0
		visual.modulate = Color.WHITE
		visual.scale = Vector2(3.0 * facing, 3.0)
	if aura:
		aura.visible = false
	if orbs_root:
		orbs_root.visible = true
	sync_orbs([])


func _die() -> void:
	alive = false
	move_dir = 0.0
	velocity = Vector2.ZERO
	orbs.clear()
	collision_layer = 0
	collision_mask = 0
	if visual:
		visual.rotation_degrees = 78.0 if facing >= 0.0 else -78.0
		visual.modulate = Color(0.42, 0.42, 0.5)
	if aura:
		aura.visible = false
	if orbs_root:
		orbs_root.visible = false


func _build_visual(robe: Color, hat: Color) -> void:
	shadow = Sprite2D.new()
	shadow.texture = PixelSprites.disc(Color(0, 0, 0, 0.45), 7)
	shadow.position = Vector2(0, -3)
	shadow.scale = Vector2(1.7, 0.45)
	shadow.texture_filter = TEXTURE_FILTER_NEAREST
	shadow.z_index = -2
	add_child(shadow)

	aura = Sprite2D.new()
	aura.texture = PixelSprites.disc(Color("9fd4ff"), 18)
	aura.position = Vector2(0, -HIT_LIFT)
	aura.visible = false
	aura.z_index = -1
	aura.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(aura)

	visual = Node2D.new()
	visual.texture_filter = TEXTURE_FILTER_NEAREST
	visual.z_index = 1
	add_child(visual)

	body = Sprite2D.new()
	body.texture = PixelSprites.mage_texture(robe, hat)
	body.centered = false
	body.position = Vector2(-8, -24)
	body.texture_filter = TEXTURE_FILTER_NEAREST
	visual.add_child(body)

	gem = Sprite2D.new()
	gem.texture = PixelSprites.disc(Color("ffe08a"), 1)
	gem.centered = true
	gem.position = Vector2(6, -16)
	gem.texture_filter = TEXTURE_FILTER_NEAREST
	visual.add_child(gem)

	orbs_root = Node2D.new()
	orbs_root.position = Vector2(0, -92)
	orbs_root.z_index = 3
	add_child(orbs_root)
	for i in 3:
		var sprite := Sprite2D.new()
		sprite.position = Vector2(-16 + i * 16, 0 if i != 1 else -3)
		sprite.texture_filter = TEXTURE_FILTER_NEAREST
		orbs_root.add_child(sprite)
		orb_sprites.append(sprite)
	sync_orbs([])


func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 52)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -26)
	add_child(collision)
