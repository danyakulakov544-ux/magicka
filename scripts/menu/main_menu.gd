extends Control

const FONT := preload("res://fonts/NotoSans-Regular.ttf")
const BG := preload("res://assets/generated/map_bg.png")

var _shot := ""


func _ready() -> void:
	_shot = _arg("shot")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.02, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -220
	col.offset_top = -200
	col.offset_right = 220
	col.offset_bottom = 200
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	add_child(col)

	var title := Label.new()
	title.text = "4D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(title, 64, Color("f0d7a2"))
	col.add_child(title)

	var sub := Label.new()
	sub.text = "карта похода  ·  карточный стол"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(sub, 20, Color("cbb892"))
	col.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for i in 4:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.texture = load("res://assets/generated/map/hero_%d.png" % i)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)

	col.add_child(_button("Карта", _open_map))
	col.add_child(_button("Стол", _open_table))

	var hint := Label.new()
	hint.text = "Стол — тёмная комната и карты. Карта — фишки по узлам."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font(hint, 16, Color("a89880"))
	col.add_child(hint)

	if _shot == "menu":
		_capture.call_deferred()


func _font(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 64)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color("f3e6c8"))
	button.add_theme_color_override("font_hover_color", Color("fff6df"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("241910")
	normal.border_color = Color("c6a15a")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color("3a2a18")
	hover.border_color = Color("f0d7a2")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	return button


func _open_map() -> void:
	Journey.clear()
	get_tree().change_scene_to_file("res://scenes/map/world_map.tscn")


func _open_table() -> void:
	Journey.clear()
	get_tree().change_scene_to_file("res://scenes/table/card_table.tscn")


func _arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--" + flag)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""


func _capture() -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("/tmp/shot_menu.png")
	get_tree().quit()
