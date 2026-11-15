extends Node2D

var kind: String = "flash"
var duration: float = 0.2
var self_free: bool = false
var _age: float = 0.0


func setup(kind_name: String, spell_color: Color, spell_radius: float, spell_length: float, spell_facing: float, time: float, frees_self: bool) -> void:
	kind = kind_name
	duration = maxf(time, 0.05)
	self_free = frees_self
	texture_filter = TEXTURE_FILTER_NEAREST
	z_index = 5
	var sprite := Sprite2D.new()
	sprite.name = "Graphic"
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(sprite)
	if kind == "beam":
		var width := maxi(int(absf(spell_length)), 1)
		var height := maxi(int(round(spell_radius * 2.0)), 4)
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(spell_color)
		var core := spell_color.lightened(0.4)
		var core_h := mini(2, height)
		image.fill_rect(Rect2i(0, maxi(int(height / 2.0) - 1, 0), width, core_h), core)
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.position = Vector2(0.0 if spell_facing >= 0.0 else -float(width), -float(height) * 0.5)
	else:
		var radius := maxi(int(round(spell_radius)), 2)
		sprite.texture = PixelSprites.disc(spell_color, radius)
		sprite.centered = true
		if kind == "area":
			modulate.a = 0.8


func _process(delta: float) -> void:
	if kind == "projectile":
		return
	_age += delta
	var t := clampf(_age / duration, 0.0, 1.0)
	if kind == "area":
		scale = Vector2.ONE * lerpf(0.35, 1.0, t)
		modulate.a = 0.78 * (1.0 - t * 0.25)
	else:
		modulate.a = 1.0 - t
	if self_free and _age >= duration:
		queue_free()
