extends Control

const FONT := preload("res://fonts/NotoSans-Regular.ttf")
const MAP_SIZE := Vector2(640, 360)

const PLAYERS := [
	{"name": "Маг", "deck": "mages", "deck_name": "Маги", "portrait": "mage_king"},
	{"name": "Король", "deck": "kings", "deck_name": "Короли", "portrait": "human_king"},
	{"name": "Медведь", "deck": "beasts", "deck_name": "Звери", "portrait": "bear"},
	{"name": "Нежить", "deck": "dead", "deck_name": "Мертвецы", "portrait": "undead_king"},
]

const BATTLE_TYPES := ["battle", "elite", "boss"]
const TABLE_TYPES := ["battle", "elite", "boss", "tavern", "forge", "treasure"]
const HERO_FOR_FOE := {
	"kings": "human_king",
	"mages": "mage_king",
	"dead": "undead_king",
	"beasts": "bear",
}

var _nodes: Dictionary = {}
var _neighbors: Dictionary = {}
var _tokens: Array[String] = []
var _selected := 0
var _visited: Dictionary = {}
var _moving := false
var _time := 0.0
var _screen: TextureRect
var _layer: PathLayer
var _icons: Dictionary = {}
var _pieces: Array[Sprite2D] = []
var _tooltip: Label
var _who: Label
var _shot := ""


class PathLayer extends Node2D:
	var host: Control

	func _draw() -> void:
		host.draw_board(self)


func _ready() -> void:
	_shot = _arg("shot")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_map()
	if Journey.map_state.is_empty():
		for _i in PLAYERS.size():
			_tokens.append("start")
		_selected = 0
	else:
		for id in Journey.map_state.get("tokens", []):
			_tokens.append(str(id))
		while _tokens.size() < PLAYERS.size():
			_tokens.append("start")
		_selected = int(Journey.map_state.get("selected", 0))
		_visited = Journey.map_state.get("visited", {}).duplicate()
	_build_view()
	_build_ui()
	_layout_tokens(false)
	if _shot == "map":
		_capture.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _layer:
		_layer.queue_redraw()
	for id in _icons:
		var spr: Sprite2D = _icons[id]
		var base: Vector2 = _nodes[id]["pos"]
		spr.position = base + Vector2(0, sin(_time * 1.7 + spr.get_index()) * 1.0)
	if not _moving:
		for i in _pieces.size():
			_pieces[i].position = _token_pos(i) + Vector2(0, sin(_time * 2.4 + i) * 1.3)
	_who.text = "%s  ·  %s" % [PLAYERS[_selected]["name"], PLAYERS[_selected]["deck_name"]]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_to_menu()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_selected = event.keycode - KEY_1
	elif event is InputEventMouseMotion:
		_hover_tip(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)


func draw_board(canvas: Node2D) -> void:
	var here: String = _tokens[_selected]
	var hot: Dictionary = {}
	for nb in _neighbors.get(here, []):
		hot[here + ">" + nb] = true
		hot[nb + ">" + here] = true
	var seen := {}
	for id in _nodes:
		for nb in _nodes[id]["links"]:
			var key: String = id + "|" + nb if id < nb else nb + "|" + id
			if seen.has(key):
				continue
			seen[key] = true
			if not hot.has(id + ">" + nb):
				continue
			var pts := _curve(_nodes[id]["pos"], _nodes[nb]["pos"])
			_dashes(canvas, pts, Color(0.95, 0.78, 0.45, 0.85), fmod(_time * 22.0, 12.0))
	for id in _nodes:
		var p: Vector2 = _nodes[id]["pos"]
		var reachable: bool = (_neighbors[here] as Array).has(id)
		if reachable and not _moving:
			var glow := Color(1.0, 0.72, 0.35, 0.22 + 0.1 * sin(_time * 3.0))
			canvas.draw_circle(p + Vector2(0, -8), 18, glow)
		if id == here:
			canvas.draw_arc(p + Vector2(0, -6), 16, 0, TAU, 24, Color(1, 0.9, 0.7, 0.7), 1.0, false)


func _load_map() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))
	for raw in parsed["nodes"]:
		var n := {
			"id": str(raw["id"]),
			"type": str(raw["type"]),
			"name": str(raw["name"]),
			"foe": str(raw.get("foe", "dead")),
			"pos": Vector2(float(raw["x"]), float(raw["y"])),
			"links": [],
		}
		for link in raw["links"]:
			n["links"].append(str(link))
		_nodes[n["id"]] = n
		_neighbors[n["id"]] = []
	for id in _nodes:
		for link in _nodes[id]["links"]:
			_neighbors[id].append(link)
			if not _neighbors[link].has(id):
				_neighbors[link].append(id)


func _build_view() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(MAP_SIZE)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)

	var world := Node2D.new()
	vp.add_child(world)
	var bg := Sprite2D.new()
	bg.texture = preload("res://assets/generated/map_bg.png")
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(bg)

	_layer = PathLayer.new()
	_layer.host = self
	world.add_child(_layer)

	for id in _nodes:
		var n: Dictionary = _nodes[id]
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/generated/map/obj_%s.png" % n["type"])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.offset = Vector2(0, -spr.texture.get_height() * 0.5)
		spr.position = n["pos"]
		spr.z_index = 2
		world.add_child(spr)
		_icons[id] = spr

	for i in PLAYERS.size():
		var piece := Sprite2D.new()
		piece.texture = load("res://assets/portraits/heroes/%s.png" % str(PLAYERS[i]["portrait"]))
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		piece.centered = true
		var shown := 34.0
		piece.scale = Vector2.ONE * (shown / piece.texture.get_width())
		piece.offset = Vector2(0, -piece.texture.get_height() * 0.5)
		piece.z_index = 4
		world.add_child(piece)
		_pieces.append(piece)

	_screen = TextureRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.texture = vp.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = load("res://shaders/map_post.gdshader")
	_screen.material = post
	add_child(_screen)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Карта похода"
	title.position = Vector2(28, 18)
	_style(title, 28, Color("f0d7a2"))
	add_child(title)

	_who = Label.new()
	_who.position = Vector2(28, 54)
	_style(_who, 18, Color("e7d3a4"))
	add_child(_who)

	var hint := Label.new()
	hint.text = "1–4 фишка   ·   клик по соседнему месту   ·   бой открывает стол   ·   Esc меню"
	hint.position = Vector2(28, 676)
	_style(hint, 16, Color(0.9, 0.82, 0.68, 0.9))
	add_child(hint)

	var back := Button.new()
	back.text = "В меню"
	back.position = Vector2(1120, 20)
	back.size = Vector2(130, 40)
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(_to_menu)
	add_child(back)

	_tooltip = Label.new()
	_tooltip.visible = false
	_style(_tooltip, 16, Color("fff6df"))
	_tooltip.modulate = Color(1, 1, 1, 1)
	add_child(_tooltip)


func _style(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _click(screen: Vector2) -> void:
	if _moving:
		return
	var p := _to_map(screen)
	for i in _pieces.size():
		if _pieces[i].position.distance_to(p) < 14.0:
			_selected = i
			return
	var hit := _node_at(p, 30.0)
	if hit == "":
		return
	if not _neighbors.get(_tokens[_selected], []).has(hit):
		return
	_walk(hit)


func _hover_tip(screen: Vector2) -> void:
	var p := _to_map(screen)
	var hit := _node_at(p, 30.0)
	if hit == "":
		_tooltip.visible = false
		return
	var n: Dictionary = _nodes[hit]
	var extra := ""
	if BATTLE_TYPES.has(n["type"]) or TABLE_TYPES.has(n["type"]):
		extra = "  ·  стол"
	elif _neighbors.get(_tokens[_selected], []).has(hit):
		extra = "  ·  можно идти"
	_tooltip.text = "  %s%s  " % [n["name"], extra]
	_tooltip.visible = true
	_tooltip.position = screen + Vector2(16, 18)
	_tooltip.size = Vector2(0, 0)


func _walk(target: String) -> void:
	_moving = true
	var who := _selected
	var start: Vector2 = _pieces[who].position
	var pts := _curve(_nodes[_tokens[who]]["pos"], _nodes[target]["pos"])
	_tokens[who] = target
	var landing := _token_pos(who)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var along := _sample(pts, t)
		var hop := sin(t * PI) * 12.0
		var p := along
		if t < 0.16:
			p = start.lerp(along, t / 0.16)
		elif t > 0.8:
			p = along.lerp(landing, (t - 0.8) / 0.2)
		_pieces[who].position = p + Vector2(0, -hop)
	, 0.0, 1.0, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_moving = false
		_layout_tokens(false)
		var n: Dictionary = _nodes[target]
		if TABLE_TYPES.has(n["type"]):
			_enter_table(n)
	)


func _enter_table(n: Dictionary) -> void:
	_moving = true
	_visited[n["id"]] = true
	Journey.from_map = true
	Journey.player_deck = str(PLAYERS[_selected]["deck"])
	Journey.table_mode = "battle" if BATTLE_TYPES.has(n["type"]) else str(n["type"])
	Journey.foe_deck = str(n.get("foe", "dead"))
	Journey.foe_hero = str(HERO_FOR_FOE.get(Journey.foe_deck, "human_king"))
	Journey.map_state = {
		"tokens": _tokens.duplicate(),
		"selected": _selected,
		"visited": _visited.duplicate(),
	}
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/table/card_table.tscn")
	)


func _layout_tokens(_animate: bool) -> void:
	for i in _pieces.size():
		_pieces[i].position = _token_pos(i)


func _token_pos(player: int) -> Vector2:
	var node_id := _tokens[player]
	var group: Array[int] = []
	for i in _tokens.size():
		if _tokens[i] == node_id:
			group.append(i)
	var idx := group.find(player)
	var span := 16.0
	var x := (float(idx) - float(group.size() - 1) * 0.5) * span
	return _nodes[node_id]["pos"] + Vector2(x, 4)


func _node_at(p: Vector2, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id in _nodes:
		var feet: Vector2 = _nodes[id]["pos"]
		var body := feet + Vector2(0, -18)
		var d: float = minf(feet.distance_to(p), body.distance_to(p))
		if d <= best_d:
			best_d = d
			best = id
	return best


func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var dir := b - a
	var nrm := Vector2(-dir.y, dir.x).normalized()
	var bow := 10.0 if int(abs(a.x + b.y)) % 2 == 0 else -10.0
	if dir.length() < 80.0:
		bow *= 0.45
	var c := (a + b) * 0.5 + nrm * bow
	var pts := PackedVector2Array()
	for i in 14:
		var t := float(i) / 13.0
		var u := 1.0 - t
		var p := a * u * u + c * 2.0 * u * t + b * t * t
		pts.append(p.round())
	return pts


func _sample(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() < 2:
		return pts[0]
	var lengths: Array[float] = []
	var total := 0.0
	for i in pts.size() - 1:
		var length := pts[i].distance_to(pts[i + 1])
		lengths.append(length)
		total += length
	var target := total * clampf(t, 0.0, 1.0)
	for i in lengths.size():
		if target <= lengths[i] or i == lengths.size() - 1:
			var u := 0.0 if lengths[i] <= 0.001 else target / lengths[i]
			return pts[i].lerp(pts[i + 1], clampf(u, 0.0, 1.0))
		target -= lengths[i]
	return pts[pts.size() - 1]


func _dashes(canvas: Node2D, pts: PackedVector2Array, color: Color, phase: float) -> void:
	var dist := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, int(length))
		for s in steps:
			var d0 := dist + length * float(s) / float(steps)
			if int((d0 + phase) / 7.0) % 2 == 0:
				var u0 := float(s) / float(steps)
				var u1 := float(s + 1) / float(steps)
				canvas.draw_line(a.lerp(b, u0), a.lerp(b, u1), color, 1.0)
		dist += length


func _to_map(screen: Vector2) -> Vector2:
	var rect := _screen.get_global_rect()
	if rect.size.x <= 1.0:
		return screen
	return (screen - rect.position) * MAP_SIZE / rect.size


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--" + flag)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""


func _capture() -> void:
	await RenderingServer.frame_post_draw
	for _i in 4:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "/tmp/shot_map.png"
	var err := image.save_png(path)
	print("shot map ", err, " ", path, " ", image.get_width())
	get_tree().quit()
