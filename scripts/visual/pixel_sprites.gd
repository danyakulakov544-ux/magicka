extends RefCounted
class_name PixelSprites

static var _cache: Dictionary = {}


static func disc(color: Color, radius: int) -> ImageTexture:
	var key := "%s:%d" % [color.to_html(true), radius]
	if _cache.has(key):
		return _cache[key]
	var size := radius * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(radius, radius)
	for y in size:
		for x in size:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= float(radius) * 0.42:
				img.set_pixel(x, y, color.lightened(0.32))
			elif dist <= float(radius) - 0.85:
				img.set_pixel(x, y, color)
			elif dist <= float(radius):
				var edge := color.darkened(0.4)
				edge.a = color.a
				img.set_pixel(x, y, edge)
	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


static func mage_texture(robe: Color, hat: Color) -> ImageTexture:
	var key := "mage:%s:%s" % [robe.to_html(false), hat.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color("f3c7a0")
	var eye := Color("1b1b1b")
	var boot := Color("241c18")
	var staff := Color("6d4a2e")
	var band := robe.darkened(0.42)
	var dark := robe.darkened(0.25)
	img.fill_rect(Rect2i(5, 0, 6, 2), hat)
	img.fill_rect(Rect2i(4, 2, 8, 2), hat)
	img.fill_rect(Rect2i(3, 4, 10, 2), hat)
	img.fill_rect(Rect2i(2, 6, 12, 2), hat.darkened(0.18))
	img.fill_rect(Rect2i(4, 8, 8, 4), skin)
	img.set_pixel(5, 9, eye)
	img.set_pixel(6, 9, eye)
	img.set_pixel(9, 9, eye)
	img.set_pixel(10, 9, eye)
	img.fill_rect(Rect2i(6, 11, 4, 1), skin.darkened(0.15))
	img.fill_rect(Rect2i(3, 12, 10, 6), robe)
	img.fill_rect(Rect2i(4, 14, 8, 1), band)
	img.fill_rect(Rect2i(4, 18, 3, 3), dark)
	img.fill_rect(Rect2i(9, 18, 3, 3), dark)
	img.fill_rect(Rect2i(4, 21, 3, 2), boot)
	img.fill_rect(Rect2i(9, 21, 3, 2), boot)
	img.fill_rect(Rect2i(13, 9, 2, 13), staff)
	img.fill_rect(Rect2i(12, 7, 4, 3), Color("ffe08a"))
	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


static func backdrop(size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var wall := Color("17141f")
	var brick := Color("221c2c")
	var mortar := Color("2c2638")
	var floor := Color("3a291f")
	var floor_b := Color("2a1c16")
	var line := Color("6b5142")
	var pillar := Color("2a2438")
	var pillar_hi := Color("3d3652")
	img.fill(wall)
	var floor_y := size.y - 56
	for y in size.y:
		for x in size.x:
			if y < floor_y:
				var row := int(y / 8)
				var offset := 8 if row % 2 == 0 else 0
				if y % 8 == 0 or (x + offset) % 16 == 0:
					img.set_pixel(x, y, mortar)
				elif (x * 3 + y * 5) % 17 == 0:
					img.set_pixel(x, y, brick)
			else:
				var grain := (x * 13 + y * 7) % 11
				if y == floor_y or y == floor_y + 1:
					img.set_pixel(x, y, line)
				elif grain == 0:
					img.set_pixel(x, y, floor_b)
				else:
					img.set_pixel(x, y, floor)
	_pillar(img, 18, 28, floor_y, pillar, pillar_hi)
	_pillar(img, size.x - 46, 28, floor_y, pillar, pillar_hi)
	_torch(img, 28, 78)
	_torch(img, size.x - 36, 78)
	return ImageTexture.create_from_image(img)


static func _pillar(img: Image, x: int, width: int, floor_y: int, body: Color, hi: Color) -> void:
	img.fill_rect(Rect2i(x, 36, width, floor_y - 36), body)
	img.fill_rect(Rect2i(x, 36, 3, floor_y - 36), hi)
	img.fill_rect(Rect2i(x - 4, 28, width + 8, 10), body.lightened(0.08))
	img.fill_rect(Rect2i(x - 6, floor_y - 10, width + 12, 10), body.darkened(0.08))


static func _torch(img: Image, x: int, y: int) -> void:
	img.fill_rect(Rect2i(x, y + 8, 3, 14), Color("5a3a28"))
	img.set_pixel(x, y + 2, Color("ffe9a0"))
	img.set_pixel(x + 1, y + 1, Color("ffb03a"))
	img.set_pixel(x + 1, y + 3, Color("ff5a2a"))
	img.set_pixel(x + 2, y + 2, Color("ffd27a"))
	img.set_pixel(x + 1, y, Color("fff1c4"))
