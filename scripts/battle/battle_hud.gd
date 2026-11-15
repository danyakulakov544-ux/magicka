extends CanvasLayer

var root: Control
var toast: Label
var banner: ColorRect
var banner_label: Label
var _toast_left: float = 0.0
var _hp_fill: Array[ColorRect] = []
var _hp_width: Array[float] = []
var _shield_fill: Array[ColorRect] = []
var _shield_width: Array[float] = []
var _hp_text: Array[Label] = []
var _shield_text: Array[Label] = []
var _orb_fills: Array = []
var _orb_letters: Array = []
var _previews: Array[Label] = []


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font: Font = load("res://fonts/NotoSans-Regular.ttf")
	if font:
		theme.default_font = font
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 1))
	theme.set_constant("outline_size", "Label", 3)
	theme.set_font_size("font_size", "Label", 12)
	root.theme = theme
	add_child(root)
	var view := get_viewport().get_visible_rect().size
	if view.x < 200.0:
		view = Vector2(1280, 720)
	_build_panel(0, 16.0, "МАГ 1", Color("3a56e8"))
	_build_panel(1, view.x - 176.0, "МАГ 2", Color("d43b4a"))
	_build_toast(view)
	_build_hints(view)
	_build_banner()


func update_mage(slot: int, hp: int, max_hp: int, shield: int, max_shield: int, letters: Array, colors: Array, preview_text: String, preview_color: Color) -> void:
	if slot < 0 or slot >= _hp_fill.size():
		return
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_fill[slot].size.x = _hp_width[slot] * ratio
	_hp_fill[slot].color = Color("e24b43").lerp(Color("5dce6a"), ratio)
	_hp_text[slot].text = "%d" % hp
	var shield_ratio := 0.0 if max_shield <= 0 else clampf(float(shield) / float(max_shield), 0.0, 1.0)
	_shield_fill[slot].size.x = _shield_width[slot] * shield_ratio
	_shield_text[slot].text = "щит %d" % shield if shield > 0 else ""
	var fills: Array = _orb_fills[slot]
	var labels: Array = _orb_letters[slot]
	for i in fills.size():
		var fill: ColorRect = fills[i]
		var label: Label = labels[i]
		if i < colors.size():
			fill.color = colors[i]
			label.text = str(letters[i]) if i < letters.size() else ""
		else:
			fill.color = Color(1, 1, 1, 0.08)
			label.text = ""
	_previews[slot].text = preview_text
	_previews[slot].modulate = preview_color


func show_toast(text: String, color: Color) -> void:
	toast.text = text
	toast.modulate = color
	_toast_left = 1.8


func show_end(text: String) -> void:
	banner.visible = true
	banner_label.text = text


func hide_end() -> void:
	banner.visible = false


func popup(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at + Vector2(-28, -8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	root.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20.0, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)


func _process(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	if _toast_left <= 0.0:
		toast.text = ""


func _build_panel(slot: int, x: float, title: String, stripe: Color) -> void:
	var mark := ColorRect.new()
	mark.position = Vector2(x, 6)
	mark.size = Vector2(4, 14)
	mark.color = stripe
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mark)
	var name_label := _label(title, 13, Vector2(x + 8, 2), Vector2(140, 18))
	if slot == 1:
		name_label.position = Vector2(x, 2)
		name_label.size = Vector2(150, 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hp_back := _rect(Vector2(x, 22), Vector2(150, 10), Color(0, 0, 0, 0.55))
	var hp_fill := _rect(Vector2(x + 1, 23), Vector2(148, 8), Color("5dce6a"))
	var hp_label := _label("100", 10, Vector2(x, 20), Vector2(150, 12))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shield_back := _rect(Vector2(x, 34), Vector2(150, 5), Color(0, 0, 0, 0.45))
	var shield_fill := _rect(Vector2(x + 1, 35), Vector2(148, 3), Color("8ecbff"))
	var shield_label := _label("", 10, Vector2(x, 40), Vector2(150, 14))
	_hp_fill.append(hp_fill)
	_hp_width.append(148.0)
	_shield_fill.append(shield_fill)
	_shield_width.append(148.0)
	_hp_text.append(hp_label)
	_shield_text.append(shield_label)
	var fills: Array[ColorRect] = []
	var letters: Array[Label] = []
	var orb_x := x if slot == 0 else x + 150.0 - (14.0 * 3.0 + 4.0 * 2.0)
	for i in 3:
		var back := _rect(Vector2(orb_x + i * 18, 56), Vector2(14, 14), Color(0, 0, 0, 0.55))
		var fill := _rect(Vector2(orb_x + i * 18 + 2, 58), Vector2(10, 10), Color(1, 1, 1, 0.08))
		var letter := _label("", 9, Vector2(orb_x + i * 18, 55), Vector2(14, 14))
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fills.append(fill)
		letters.append(letter)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_fills.append(fills)
	_orb_letters.append(letters)
	var preview := _label("", 10, Vector2(x, 74), Vector2(150, 28))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if slot == 1:
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_previews.append(preview)


func _build_toast(view: Vector2) -> void:
	toast = _label("", 22, Vector2(view.x * 0.5 - 280.0, 8), Vector2(560, 32))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_hints(view: Vector2) -> void:
	var bar := _rect(Vector2(0, view.y - 44), Vector2(view.x, 44), Color(0, 0, 0, 0.45))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_one := _label("WASD — ход   Q/1 огонь  Z/2 вода  E/3 молния  R/4 земля  F/5 жизнь   ЛКМ — в противника   ПКМ — на себя   C — сброс", 16, Vector2(8, view.y - 40), Vector2(view.x - 16, 20))
	line_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line_two := _label("Второй маг — бот. Мышь задаёт прицел. Enter — новый раунд после победы.", 15, Vector2(8, view.y - 20), Vector2(view.x - 16, 18))
	line_two.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_banner() -> void:
	banner = ColorRect.new()
	banner.color = Color(0, 0, 0, 0.62)
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner_label = Label.new()
	banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 26)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_label)


func _label(text: String, size: int, pos: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = box
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	root.add_child(label)
	return label


func _rect(pos: Vector2, box: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = box
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	return rect
