extends Control

## First-person card table. Visual prototype: no faction rules.
## Camera, light and timing follow the table brief. Props are ours.

const FONT := preload("res://fonts/NotoSans-Regular.ttf")
const TABLE_Y := 0.75
const CARD_W := 0.063
const CARD_H := 0.088
const SLOT_X: Array[float] = [-0.27, -0.09, 0.09, 0.27]
const ROW_Z := {"player": 0.12, "foe": -0.10, "queue": -0.32}

const PLAQUE := {
	"mages": Color("2e3e60"),
	"kings": Color("5c401c"),
	"dead": Color("3e3c38"),
	"beasts": Color("3e2818"),
}
const NUM := {
	"mages": Color("ece6d6"),
	"kings": Color("f8ecce"),
	"dead": Color("e6e0d2"),
	"beasts": Color("ecd6aa"),
}

var _shot := ""
var _vp: SubViewport
var _screen: TextureRect
var _world: Node3D
var _rig: Node3D
var _cam: Camera3D
var _lamp: OmniLight3D
var _flame: MeshInstance3D
var _bell: Node3D
var _scales: Node3D
var _beam: Node3D
var _left_hang: Node3D
var _right_hang: Node3D
var _lamp_anchor: Node3D
var _deck_anchor: Vector3
var _cards: Array = []
var _slot_mats: Array[StandardMaterial3D] = []
var _hover: BoardCard
var _held: BoardCard
var _time := 0.0
var _shake := Vector3.ZERO
var _view_rot := Vector3.ZERO
var _resolving := false
var _took_offer := false
var _intro_done := false
var _weight := 0
var _digits: Image
var _player_defs: Array = []
var _draw_i := 0
var _base_cam_pos: Vector3


class BoardCard extends RefCounted:
	var root: Node3D
	var face_mat: StandardMaterial3D
	var source: Image
	var data: Dictionary
	var hp: int
	var state: String = "hand"
	var hand_i: int = 0
	var row: String = ""
	var slot: int = -1
	var rest_pos: Vector3
	var rest_rot: Vector3


func _ready() -> void:
	_shot = _arg("shot")
	var hero_arg := _arg("hero")
	if hero_arg != "":
		Journey.foe_hero = hero_arg
		Journey.table_mode = "battle"
	if _shot in ["tavern", "forge", "treasure"]:
		Journey.table_mode = _shot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_digits = _image_of("res://assets/generated/digits.png")
	_build_view()
	_build_room()
	_build_table()
	_build_props()
	_build_slots()
	_build_decks()
	_deal_opening()
	_build_hint()
	_build_forge_button()
	if _shot == "hover":
		_place_foe_now()
		_pose_hover()
		_capture.call_deferred()
	elif _shot == "play":
		_place_foe_now()
		_pose_arc()
		_capture.call_deferred()
	else:
		if Journey.table_mode == "battle":
			_intro()
		if _shot != "":
			_capture_after_intro()


func _process(delta: float) -> void:
	_time += delta
	_update_camera(delta)
	_flicker()
	if _beam and _left_hang and _right_hang:
		_left_hang.rotation.z = -_beam.rotation.z
		_right_hang.rotation.z = -_beam.rotation.z
	if _held:
		var aim := _mouse_on_plane(TABLE_Y + 0.13)
		_held.root.position = _held.root.position.lerp(aim, 1.0 - exp(-delta * 16.0))
		_held.root.rotation = Vector3(-0.35, 0.0, clampf(-aim.x * 0.15, -0.2, 0.2))
	elif not _resolving:
		var m := _table_mouse()
		var found := _pick_hand(m)
		if found != _hover:
			_set_hover(found)
	_pulse_slots()


func _unhandled_input(event: InputEvent) -> void:
	if _shot != "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press()
		else:
			_release()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_leave()
		elif event.keycode == KEY_SPACE:
			_ring()


func _press() -> void:
	var m := _table_mouse()
	if Journey.table_mode == "tavern" or Journey.table_mode == "treasure":
		var offer := _pick_state(m, "offer")
		if offer != null and not _took_offer:
			_take_offer(offer)
		return
	var card := _pick_hand(m)
	if card:
		_held = card
		card.state = "held"
		_hover = null
		return
	if _near(_bell, m, 64.0):
		_ring()
		return
	if _near_point(_deck_anchor, m, 50.0):
		_draw_card()


func _release() -> void:
	if _held == null:
		return
	var card := _held
	_held = null
	var slot := _pick_slot(_table_mouse())
	if slot >= 0:
		_fly_to_slot(card, "player", slot)
	else:
		_spring_back(card)


func _intro() -> void:
	await get_tree().create_timer(0.55).timeout
	var pending: Array = []
	for c in _cards:
		if c.row == "foe" and c.state == "waiting":
			pending.append(c)
	var i := 0
	for c in pending:
		await _fly_spawned(c, "foe", 0 if i == 0 else 2)
		i += 1
		await get_tree().create_timer(0.28).timeout
	_intro_done = true


func _hero_id() -> String:
	if Journey.foe_hero != "":
		return Journey.foe_hero
	var mapped := {"kings": "human_king", "mages": "mage_king", "dead": "undead_king", "beasts": "bear"}
	return str(mapped.get(Journey.foe_deck, "human_king"))


func _build_opponent() -> void:
	var heroes := {
		"human_king": "res://assets/kaykit/Knight.glb",
		"mage_king": "res://assets/kaykit/Mage.glb",
		"undead_king": "res://assets/kaykit/Skeleton_Warrior.glb",
		"bear": "res://assets/quaternius/bear.glb",
	}
	var hero := _hero_id()
	var path: String = str(heroes.get(hero, heroes["human_king"]))
	var actor := (load(path) as PackedScene).instantiate() as Node3D
	_world.add_child(actor)
	# KayKit rigs are already about human height. Skinned-mesh bounds are not.
	if hero == "bear":
		actor.scale = Vector3.ONE * 0.55
		actor.position = Vector3(0.0, TABLE_Y - 0.02, -1.05)
		actor.rotation.y = 0.0
	else:
		actor.scale = Vector3.ONE * 0.48
		actor.position = Vector3(0.0, TABLE_Y - 0.15, -0.98)
		actor.rotation.y = PI
	_hide_spare_weapons(actor, hero)
	if hero == "bear":
		_bear_idle(actor)
	else:
		_play_sit(actor)
	_wear_crown(actor)
	var face := OmniLight3D.new()
	face.light_color = Color(1.0, 0.78, 0.55)
	face.light_energy = 0.7
	face.omni_range = 1.8
	face.shadow_enabled = false
	face.position = Vector3(0.1, TABLE_Y + 0.55, -0.55)
	_world.add_child(face)


func _wear_crown(actor: Node3D) -> void:
	var head := actor.find_child("head", true, false)
	var crown := (load("res://assets/quaternius/Crown.glb") as PackedScene).instantiate() as Node3D
	var host: Node = head if head != null else actor
	host.add_child(crown)
	# Source crown is about 8 mm tall. 22× on a unit-scale head is a small circlet.
	crown.scale = Vector3.ONE * 0.35
	crown.position = Vector3(0.0, 0.18, 0.04) if head != null else actor.position + Vector3(0, 0.7, 0)
	crown.rotation = Vector3.ZERO


func _hide_spare_weapons(root: Node, hero: String) -> void:
	var keep := "1h_sword"
	if hero == "mage_king":
		keep = "2h_staff"
	elif hero == "undead_king":
		keep = "sword"
	for node in root.find_children("*", "Node3D", true, false):
		var nm := String(node.name).to_lower()
		var gear := nm.contains("sword") or nm.contains("shield") or nm.contains("spellbook") or nm.contains("wand") or nm.contains("staff") or nm.contains("axe") or nm.contains("bow")
		if gear and not nm.contains(keep):
			node.visible = false


func _play_sit(root: Node) -> void:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	var ap := found[0] as AnimationPlayer
	var chosen := ""
	for name in ap.get_animation_list():
		var text := String(name)
		if text.ends_with("Sit_Chair_Idle"):
			chosen = text
			break
	if chosen == "":
		for name in ap.get_animation_list():
			var text := String(name)
			if text == "Idle" or text.ends_with("/Idle"):
				chosen = text
				break
	if chosen == "":
		return
	var anim := ap.get_animation(chosen)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(chosen)


func _bear_idle(actor: Node3D) -> void:
	var base_scale := actor.scale
	var base_yaw := actor.rotation.y
	var breath := create_tween()
	breath.set_loops()
	breath.tween_property(actor, "scale", base_scale * Vector3(1.03, 1.06, 1.03), 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(actor, "scale", base_scale, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var look := create_tween()
	look.set_loops()
	look.tween_property(actor, "rotation:y", base_yaw + 0.18, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_property(actor, "rotation:y", base_yaw - 0.18, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_mode_props() -> void:
	if Journey.table_mode == "treasure":
		_place_model("res://assets/quaternius/Chest_Open.glb", Vector3(0.0, TABLE_Y, -0.42), 0.16, 20.0)
		_place_model("res://assets/quaternius/Gold_Ingots.glb", Vector3(-0.16, TABLE_Y, -0.36), 0.05, 15.0)
		_place_model("res://assets/quaternius/Coin.glb", Vector3(0.14, TABLE_Y, -0.34), 0.035, 40.0)
		_place_model("res://assets/quaternius/Coin.glb", Vector3(0.18, TABLE_Y, -0.3), 0.028, 10.0)
	elif Journey.table_mode == "forge":
		_place_model("res://assets/kenney/survival/workbench-anvil.glb", Vector3(0.0, TABLE_Y, -0.05), 0.28, 10.0)


func _build_forge_button() -> void:
	if Journey.table_mode != "forge":
		return
	var button := Button.new()
	button.text = "Уйти"
	button.position = Vector2(36, 56)
	button.size = Vector2(150, 48)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_leave)
	add_child(button)


func _lay_offers(player: Array) -> void:
	for i in 3:
		var data: Dictionary = player[i % player.size()]
		var card := _make_card(data)
		card.state = "offer"
		card.row = ""
		card.slot = i
		var pos := _slot_position("player", i)
		pos.z -= 0.06
		var rot := _board_rotation()
		card.root.position = pos
		card.root.rotation = rot
		card.rest_pos = pos
		card.rest_rot = rot


func _pick_state(mouse: Vector2, state: String) -> BoardCard:
	var best: BoardCard = null
	var best_d := 70.0
	for c in _cards:
		if c.state != state or not is_instance_valid(c.root):
			continue
		var d := _cam.unproject_position(c.root.global_position).distance_to(mouse)
		if d < best_d:
			best_d = d
			best = c
	return best


func _take_offer(card: BoardCard) -> void:
	_took_offer = true
	card.state = "moving"
	card.hand_i = 0
	var pose := _hand_xform(0, 1)
	var start_pos := card.root.position
	var start_q := card.root.quaternion
	var end_q := Quaternion.from_euler(pose["rot"])
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p: Vector3 = start_pos.lerp(pose["pos"], t)
		p.y += sin(t * PI) * 0.12
		card.root.position = p
		card.root.quaternion = start_q.slerp(end_q, t)
	, 0.0, 1.0, 0.36)
	tw.tween_callback(func() -> void:
		card.root.rotation = pose["rot"]
		card.rest_pos = pose["pos"]
		card.rest_rot = pose["rot"]
		card.state = "hand"
	)


func _deal_opening() -> void:
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	var player: Array = []
	var foe: Array = []
	for item in all:
		if str(item["deck"]) == Journey.player_deck:
			player.append(item)
		elif str(item["deck"]) == Journey.foe_deck:
			foe.append(item)
	if player.is_empty():
		player = all.slice(0, 4)
	if foe.is_empty():
		foe = all.slice(4, 8)
	_player_defs = player
	if Journey.table_mode == "forge":
		_intro_done = true
		return
	if Journey.table_mode == "tavern" or Journey.table_mode == "treasure":
		_lay_offers(player)
		_intro_done = true
		return
	for i in 5:
		var data: Dictionary = player[i % player.size()]
		var card := _make_card(data)
		card.state = "hand"
		card.hand_i = i
		var pose := _hand_xform(i, 5)
		card.root.position = pose["pos"]
		card.root.rotation = pose["rot"]
		card.rest_pos = pose["pos"]
		card.rest_rot = pose["rot"]
		card.root.scale = Vector3.ONE
	for j in 2:
		var data2: Dictionary = foe[j % foe.size()]
		var foe_card := _make_card(data2)
		foe_card.state = "waiting"
		foe_card.row = "foe"
		foe_card.slot = 0 if j == 0 else 2
		foe_card.root.position = Vector3(-0.05 + j * 0.1, 1.2, -0.95)
		foe_card.root.rotation = Vector3(-0.2, 0, 0)


func _place_foe_now() -> void:
	for c in _cards:
		if c.state != "waiting":
			continue
		var pos := _slot_position(c.row, c.slot)
		var rot := _board_rotation()
		c.root.position = pos
		c.root.rotation = rot
		c.rest_pos = pos
		c.rest_rot = rot
		c.state = "board"
	_intro_done = true


func _pose_hover() -> void:
	var hand := _hand_list()
	if hand.is_empty():
		return
	var card: BoardCard = hand[mini(2, hand.size() - 1)]
	var pose := _hand_xform(card.hand_i, hand.size())
	var lifted: Vector3 = pose["pos"] + Vector3(0, 0.038, -0.05)
	var rot: Vector3 = pose["rot"]
	rot.x = -0.2
	card.root.position = lifted
	card.root.rotation = rot
	card.root.scale = Vector3.ONE * 1.08
	card.state = "hover"


func _pose_arc() -> void:
	var hand := _hand_list()
	if hand.is_empty():
		return
	var card: BoardCard = hand[mini(1, hand.size() - 1)]
	var pose := _hand_xform(card.hand_i, hand.size())
	var end := _slot_position("player", 1)
	var t := 0.55
	var p: Vector3 = (pose["pos"] as Vector3).lerp(end, t)
	p.y += sin(t * PI) * 0.15
	card.root.position = p
	card.root.rotation = (pose["rot"] as Vector3).lerp(_board_rotation(), t)
	card.state = "moving"


func _make_card(data: Dictionary) -> BoardCard:
	var card := BoardCard.new()
	card.data = data
	card.hp = int(data["hp"])
	var root := Node3D.new()
	_world.add_child(root)
	card.root = root
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CARD_W, CARD_H, 0.0022)
	body.mesh = box
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("2a241c")
	edge.roughness = 0.72
	body.material_override = edge
	root.add_child(body)
	var face := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CARD_W * 0.96, CARD_H * 0.96)
	face.mesh = plane
	face.rotation_degrees.x = 90.0
	face.position = Vector3(0, 0, 0.0018)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(str(data["file"]))
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	face.material_override = mat
	root.add_child(face)
	card.face_mat = mat
	var src := _image_of(str(data["file"]))
	card.source = src
	var back := MeshInstance3D.new()
	var back_plane := PlaneMesh.new()
	back_plane.size = Vector2(CARD_W * 0.96, CARD_H * 0.96)
	back.mesh = back_plane
	back.rotation_degrees.x = 90.0
	back.position = Vector3(0, 0, -0.0013)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_texture = preload("res://assets/generated/card_back.png")
	back_mat.roughness = 0.8
	back.material_override = back_mat
	root.add_child(back)
	_cards.append(card)
	return card


func _hand_list() -> Array:
	var list: Array = []
	for c in _cards:
		if c.row == "" and c.state != "dead" and c.state != "dying":
			list.append(c)
	list.sort_custom(func(a, b): return a.hand_i < b.hand_i)
	return list


func _hand_xform(i: int, n: int) -> Dictionary:
	var t := float(i) - float(n - 1) * 0.5
	return {
		"pos": Vector3(t * 0.082, TABLE_Y + 0.05, 0.38 + abs(t) * 0.012),
		"rot": Vector3(-0.42, 0.0, -t * 0.11),
	}


func _slot_position(row: String, slot: int) -> Vector3:
	return Vector3(SLOT_X[slot], TABLE_Y + CARD_H * 0.46, float(ROW_Z[row]))


func _board_rotation() -> Vector3:
	return Vector3(-0.16, 0.0, 0.0)


func _set_hover(card: BoardCard) -> void:
	if _hover and is_instance_valid(_hover.root) and (_hover.state == "hover"):
		_hover.state = "hand"
		_tween_to(_hover, _hand_xform(_hover.hand_i, _hand_list().size()), 0.12, 1.0)
	_hover = card
	if card and card.state == "hand":
		card.state = "hover"
		var pose := _hand_xform(card.hand_i, _hand_list().size())
		var pos: Vector3 = pose["pos"] + Vector3(0, 0.036, -0.045)
		var rot: Vector3 = pose["rot"]
		rot.x = -0.2
		_tween_xform(card, pos, rot, 0.12, 1.08)


func _tween_to(card: BoardCard, pose: Dictionary, duration: float, scale_to: float) -> void:
	_tween_xform(card, pose["pos"], pose["rot"], duration, scale_to)


func _tween_xform(card: BoardCard, pos: Vector3, rot: Vector3, duration: float, scale_to: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card.root, "position", pos, duration)
	tw.parallel().tween_property(card.root, "rotation", rot, duration)
	tw.parallel().tween_property(card.root, "scale", Vector3.ONE * scale_to, duration)


func _fly_to_slot(card: BoardCard, row: String, slot: int) -> void:
	card.state = "moving"
	card.row = row
	card.slot = slot
	var start_pos := card.root.position
	var start_q := card.root.quaternion
	var end_pos := _slot_position(row, slot)
	var end_rot := _board_rotation()
	var end_q := Quaternion.from_euler(end_rot)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start_pos.lerp(end_pos, t)
		p.y += sin(t * PI) * 0.15
		card.root.position = p
		card.root.quaternion = start_q.slerp(end_q, t)
	, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_land(card, end_pos, end_rot)
		_reflow_hand()
	)


func _fly_spawned(card: BoardCard, row: String, slot: int) -> void:
	card.row = row
	card.slot = slot
	card.state = "moving"
	var start_pos := card.root.position
	var start_q := card.root.quaternion
	var end_pos := _slot_position(row, slot)
	var end_rot := _board_rotation()
	var end_q := Quaternion.from_euler(end_rot)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start_pos.lerp(end_pos, t)
		p.y += sin(t * PI) * 0.12
		card.root.position = p
		card.root.quaternion = start_q.slerp(end_q, t)
	, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_land(card, end_pos, end_rot)


func _land(card: BoardCard, pos: Vector3, rot: Vector3) -> void:
	card.root.position = pos
	card.root.rotation = rot
	card.root.scale = Vector3.ONE
	card.rest_pos = pos
	card.rest_rot = rot
	card.state = "board"
	_punch(0.011)
	var tw := create_tween()
	tw.tween_property(card.root, "position:y", pos.y - 0.007, 0.04)
	tw.tween_property(card.root, "position:y", pos.y, 0.05)


func _reflow_hand() -> void:
	var list := _hand_list()
	for i in list.size():
		var card: BoardCard = list[i]
		card.hand_i = i
		if card.state != "hand" and card.state != "hover":
			continue
		var pose := _hand_xform(i, list.size())
		card.rest_pos = pose["pos"]
		card.rest_rot = pose["rot"]
		if card == _hover:
			var pos: Vector3 = pose["pos"] + Vector3(0, 0.036, -0.045)
			var rot: Vector3 = pose["rot"]
			rot.x = -0.2
			_tween_xform(card, pos, rot, 0.14, 1.08)
		else:
			card.state = "hand"
			_tween_to(card, pose, 0.14, 1.0)


func _spring_back(card: BoardCard) -> void:
	card.state = "moving"
	card.row = ""
	card.slot = -1
	var list := _hand_list()
	# include this card: it is moving with empty row, so it is in the list
	var pose := _hand_xform(card.hand_i, maxi(list.size(), 1))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card.root, "position", pose["pos"], 0.2)
	tw.parallel().tween_property(card.root, "rotation", pose["rot"], 0.2)
	tw.parallel().tween_property(card.root, "scale", Vector3.ONE, 0.2)
	tw.tween_callback(func() -> void:
		card.state = "hand"
		card.rest_pos = pose["pos"]
		card.rest_rot = pose["rot"]
	)


func _draw_card() -> void:
	if _player_defs.is_empty():
		return
	if _hand_list().size() >= 7 or _resolving or _held:
		return
	var data: Dictionary = _player_defs[_draw_i % _player_defs.size()]
	_draw_i += 1
	var card := _make_card(data)
	card.state = "moving"
	card.row = ""
	card.hand_i = 50
	card.root.position = _deck_anchor + Vector3(0, 0.02, 0)
	card.root.rotation = Vector3(-0.08, PI, 0)
	var list := _hand_list()
	card.hand_i = list.size() - 1
	var pose := _hand_xform(card.hand_i, list.size())
	var start_pos := card.root.position
	var start_q := card.root.quaternion
	var end_q := Quaternion.from_euler(pose["rot"])
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p: Vector3 = start_pos.lerp(pose["pos"], t)
		p.y += sin(t * PI) * 0.1
		card.root.position = p
		card.root.quaternion = start_q.slerp(end_q, t)
	, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		card.root.rotation = pose["rot"]
		card.rest_pos = pose["pos"]
		card.rest_rot = pose["rot"]
		card.state = "hand"
	)


func _ring() -> void:
	if _resolving or _held or _shot != "":
		return
	_resolving = true
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		if _bell:
			_bell.rotation.z = sin(u * TAU * 3.0) * deg_to_rad(7.0) * (1.0 - u)
	, 0.0, 1.0, 1.0)
	_punch(0.012)
	await get_tree().create_timer(0.18).timeout
	var attackers: Array = []
	for c in _cards:
		if c.state == "board" and c.row == "player":
			attackers.append(c)
	attackers.sort_custom(func(a, b): return a.slot < b.slot)
	for c in attackers:
		await _attack(c)
		await get_tree().create_timer(0.08).timeout
	_resolving = false


func _attack(card: BoardCard) -> void:
	if card.state != "board":
		return
	card.state = "moving"
	var origin := card.rest_pos
	var origin_rot := card.rest_rot
	var wind := origin_rot
	wind.x += deg_to_rad(22.0)
	var lunge := origin + Vector3(0, 0.015, -0.07)
	var tw := create_tween()
	tw.tween_property(card.root, "rotation", wind, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card.root, "position", lunge, 0.1)
	tw.tween_callback(func() -> void: _impact(card))
	tw.tween_property(card.root, "position", origin, 0.2)
	tw.parallel().tween_property(card.root, "rotation", origin_rot, 0.2)
	await tw.finished
	if is_instance_valid(card.root) and card.state != "dead":
		card.state = "board"
		card.root.position = origin
		card.root.rotation = origin_rot


func _impact(card: BoardCard) -> void:
	_punch(0.01)
	_drop_shard(true)
	var foe := _card_on("foe", card.slot)
	if foe == null:
		return
	foe.hp -= 1
	_paint_hp(foe)
	foe.face_mat.emission_enabled = true
	foe.face_mat.emission = Color(1.0, 0.86, 0.7)
	foe.face_mat.emission_energy_multiplier = 1.1
	var flash := create_tween()
	flash.tween_property(foe.face_mat, "emission_energy_multiplier", 0.0, 0.16)
	var back := foe.rest_pos + Vector3(0, 0.0, -0.035)
	var recoil := create_tween()
	recoil.tween_property(foe.root, "position", back, 0.08)
	recoil.tween_property(foe.root, "position", foe.rest_pos, 0.12)
	if foe.hp <= 0:
		_kill(foe)


func _kill(card: BoardCard) -> void:
	card.state = "dying"
	var tw := create_tween()
	tw.tween_property(card.root, "position:y", card.rest_pos.y - 0.06, 0.45)
	tw.parallel().tween_property(card.face_mat, "albedo_color", Color(0.25, 0.25, 0.25), 0.45)
	tw.tween_callback(func() -> void:
		card.state = "dead"
		card.row = ""
		if is_instance_valid(card.root):
			card.root.queue_free()
		_cards.erase(card)
	)


func _paint_hp(card: BoardCard) -> void:
	if card.source == null:
		return
	var img := card.source.duplicate()
	var plaque: Color = PLAQUE.get(card.data["deck"], Color("3a3228"))
	var col: Color = NUM.get(card.data["deck"], Color.WHITE)
	for y in range(186, 220):
		for x in range(118, 152):
			img.set_pixel(x, y, plaque)
	var text := str(maxi(card.hp, 0))
	var gw := 20
	var ox := 135 - text.length() * gw / 2
	for i in text.length():
		_blit_digit(img, text[i].to_int(), ox + i * gw, 188, col)
	card.face_mat.albedo_texture = ImageTexture.create_from_image(img)


func _blit_digit(img: Image, digit: int, ox: int, oy: int, col: Color) -> void:
	if _digits == null:
		return
	var gw := 20
	var gh := 28
	for y in gh:
		for x in gw:
			if _digits.get_pixel(digit * gw + x, y).a < 0.5:
				continue
			var px := ox + x
			var py := oy + y
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, col)


func _drop_shard(to_right: bool) -> void:
	_weight += 1 if to_right else -1
	var hang := _right_hang if to_right else _left_hang
	if hang == null or _beam == null:
		return
	var shard := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.022)
	shard.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = preload("res://assets/generated/shard.png")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	shard.material_override = mat
	hang.add_child(shard)
	shard.position = Vector3(0, 0.14, 0)
	var tw := create_tween()
	tw.tween_property(shard, "position:y", 0.02, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var target := clampf(float(_weight), -4.0, 4.0) * deg_to_rad(3.4)
	var start := _beam.rotation.z
	var tip := create_tween()
	tip.tween_method(func(u: float) -> void:
		var damp := exp(-u * 3.2)
		var wobble := sin(u * PI * 5.0) * damp * 0.06
		_beam.rotation.z = lerpf(start, target, 1.0 - damp) + wobble
	, 0.0, 1.0, 0.7)


func _pick_hand(mouse: Vector2) -> BoardCard:
	var best: BoardCard = null
	var best_score := 9999.0
	for c in _cards:
		if c.state != "hand" and c.state != "hover":
			continue
		if not is_instance_valid(c.root):
			continue
		var sp := _cam.unproject_position(c.root.global_position)
		var d := sp.distance_to(mouse)
		if d > 52.0:
			continue
		var score := d - float(c.hand_i) * 6.0
		if score < best_score:
			best_score = score
			best = c
	return best


func _pick_slot(mouse: Vector2) -> int:
	var best := -1
	var best_d := 58.0
	for i in SLOT_X.size():
		if _slot_taken("player", i):
			continue
		var sp := _cam.unproject_position(_slot_position("player", i))
		var d := sp.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = i
	return best


func _slot_taken(row: String, slot: int) -> bool:
	for c in _cards:
		if c.row == row and c.slot == slot and c.state != "dead":
			return true
	return false


func _card_on(row: String, slot: int) -> BoardCard:
	for c in _cards:
		if c.row == row and c.slot == slot and (c.state == "board" or c.state == "moving"):
			return c
	return null


func _near(node: Node3D, mouse: Vector2, radius: float) -> bool:
	if node == null:
		return false
	return _cam.unproject_position(node.global_position).distance_to(mouse) < radius


func _near_point(point: Vector3, mouse: Vector2, radius: float) -> bool:
	return _cam.unproject_position(point).distance_to(mouse) < radius


func _table_mouse() -> Vector2:
	var rect := _screen.get_global_rect()
	var m := get_viewport().get_mouse_position()
	if rect.size.x <= 1.0:
		return m
	return (m - rect.position) / rect.size * Vector2(_vp.size)


func _mouse_on_plane(y: float) -> Vector3:
	var m := _table_mouse()
	var origin := _cam.project_ray_origin(m)
	var dir := _cam.project_ray_normal(m)
	if absf(dir.y) < 0.0001:
		return origin
	var t := clampf((y - origin.y) / dir.y, 0.02, 4.0)
	var p := origin + dir * t
	p.x = clampf(p.x, -0.62, 0.62)
	p.z = clampf(p.z, -0.15, 0.62)
	return p


func _view_target() -> Vector3:
	# Fixed seats. Mouse never moves the head.
	if _shot == "west":
		return Vector3(deg_to_rad(3.0), deg_to_rad(24.0), 0.0)
	if _shot != "":
		return Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		return Vector3(deg_to_rad(-18.0), 0.0, 0.0)
	if Input.is_key_pressed(KEY_S):
		return Vector3(deg_to_rad(14.0), 0.0, 0.0)
	if Input.is_key_pressed(KEY_A):
		return Vector3(deg_to_rad(3.0), deg_to_rad(24.0), 0.0)
	if Input.is_key_pressed(KEY_D):
		return Vector3(deg_to_rad(3.0), deg_to_rad(-24.0), 0.0)
	return Vector3.ZERO


func _update_camera(delta: float) -> void:
	var target := _view_target()
	_view_rot = _view_rot.lerp(target, 1.0 - exp(-delta * 7.0))
	_cam.rotation = _view_rot
	var breathe := sin(_time * TAU / 4.0) * 0.002
	_shake = _shake.lerp(Vector3.ZERO, 1.0 - exp(-delta * 12.0))
	_rig.position = _base_cam_pos + Vector3(0, breathe, 0) + _shake


func _punch(amount: float) -> void:
	_shake = Vector3(randf_range(-0.4, 0.4), -1.0, randf_range(-0.2, 0.2)).normalized() * amount


func _flicker() -> void:
	if _lamp == null:
		return
	var n := sin(_time * 22.0) * 0.45 + sin(_time * 37.0) * 0.35 + sin(_time * 9.0) * 0.2
	_lamp.light_energy = 1.15 * (1.0 + n * 0.08)
	if _flame:
		_flame.scale = Vector3.ONE * (1.0 + n * 0.08)


func _pulse_slots() -> void:
	var i := 0
	for row in ["queue", "foe", "player"]:
		for s in 4:
			if i >= _slot_mats.size():
				return
			var taken := _slot_taken(row, s)
			var pulse := 0.45 + sin(_time * 2.2 + float(s) + float(i)) * 0.12
			_slot_mats[i].emission_energy_multiplier = 0.12 if taken else pulse
			i += 1


func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.positional_shadow_atlas_size = 2048
	_vp.handle_input_locally = false
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_screen = TextureRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.texture = _vp.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/table_post.gdshader")
	_screen.material = mat
	add_child(_screen)


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/polyhaven/rogland_clear_night_1k.hdr")
	sky.sky_material = pano
	world_env.sky = sky
	world_env.background_mode = Environment.BG_SKY
	world_env.background_energy_multiplier = 0.75
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_env.ambient_light_energy = 0.16
	world_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.tonemap_exposure = 1.05
	world_env.glow_enabled = true
	world_env.glow_intensity = 0.18
	world_env.glow_bloom = 0.05
	world_env.glow_hdr_threshold = 0.95
	world_env.fog_enabled = true
	world_env.fog_mode = Environment.FOG_MODE_DEPTH
	world_env.fog_depth_begin = 2.6
	world_env.fog_depth_end = 7.0
	world_env.fog_depth_curve = 1.15
	world_env.fog_light_color = Color(0.04, 0.05, 0.08)
	world_env.fog_light_energy = 0.2
	env.environment = world_env
	_world.add_child(env)

	_rig = Node3D.new()
	_base_cam_pos = Vector3(0.0, 1.04, 0.84)
	_rig.position = _base_cam_pos
	_world.add_child(_rig)
	_rig.look_at(Vector3(0.0, 0.8, 0.02), Vector3.UP)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.current = true
	_cam.near = 0.04
	_cam.far = 20.0
	_rig.add_child(_cam)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 0.03
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.shadow_enabled = false
	_world.add_child(sun)

	var fill := OmniLight3D.new()
	fill.light_color = Color(0.35, 0.45, 0.55)
	fill.light_energy = 0.1
	fill.omni_range = 3.4
	fill.shadow_enabled = false
	fill.position = Vector3(-0.2, 1.35, 0.4)
	_world.add_child(fill)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(8, 0.1, 8)
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.2, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.015, 0.012, 0.01)
	floor_mat.roughness = 1.0
	floor.material_override = floor_mat
	_world.add_child(floor)

	var beam := _box(Vector3(2.4, 0.08, 0.1), Vector3(0, 1.85, -0.4), _wood(Color(0.22, 0.14, 0.09), 0.4))
	_world.add_child(beam)


func _build_table() -> void:
	var top := _box(Vector3(1.66, 0.06, 1.2), Vector3(0, TABLE_Y - 0.03, -0.04), _wood(Color(0.4, 0.44, 0.4), 1.3))
	_world.add_child(top)
	var apron := _box(Vector3(1.58, 0.1, 1.12), Vector3(0, TABLE_Y - 0.11, -0.04), _wood(Color(0.28, 0.18, 0.11), 1.2))
	_world.add_child(apron)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var leg := _box(Vector3(0.07, 0.7, 0.07), Vector3(sx * 0.72, 0.32, -0.04 + sz * 0.5), _wood(Color(0.24, 0.15, 0.09), 1.0))
			_world.add_child(leg)


func _build_props() -> void:
	var light_pos := Vector3(0.46, TABLE_Y + 0.2, -0.28)
	_lamp_anchor = _build_lamp(Vector3(0.46, TABLE_Y, -0.28), light_pos)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.7, 0.4)
	_lamp.light_energy = 1.15
	_lamp.omni_range = 2.2
	_lamp.shadow_enabled = true
	_lamp.shadow_bias = 0.08
	_lamp.shadow_normal_bias = 1.2
	_lamp.position = light_pos
	_world.add_child(_lamp)
	_flame = _add_flame(light_pos)

	var candle := _place_model("res://assets/kenney/graveyard/candle.glb", Vector3(-0.18, TABLE_Y, -0.4), 0.1, 15.0)
	_tint(candle, Color(0.95, 0.86, 0.7))
	_add_flame(Vector3(-0.18, TABLE_Y + 0.11, -0.4))
	var candle2 := _place_model("res://assets/kenney/graveyard/candle.glb", Vector3(0.18, TABLE_Y, -0.44), 0.08, -20.0)
	_tint(candle2, Color(0.95, 0.86, 0.7))
	_add_flame(Vector3(0.18, TABLE_Y + 0.09, -0.44))

	var relic := _place_model("res://assets/kenney/graveyard/detail-chalice.glb", Vector3(0.08, TABLE_Y, -0.5), 0.09, 0.0)
	_tint(relic, Color(0.72, 0.62, 0.48))
	var books := _place_model("res://assets/kenney/furniture/books.glb", Vector3(0.28, TABLE_Y, -0.46), 0.045, 70.0)
	_tint(books, Color(0.55, 0.32, 0.22))

	var bowl := _place_model("res://assets/kenney/food/bowl.glb", Vector3(0.5, TABLE_Y, 0.34), 0.04, 0.0)
	_tint(bowl, Color(0.62, 0.5, 0.36))
	for k in 4:
		var bit := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.008
		sphere.height = 0.016
		bit.mesh = sphere
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.95, 0.72, 0.35)
		sm.emission_enabled = true
		sm.emission = Color(0.9, 0.55, 0.2)
		sm.emission_energy_multiplier = 0.35
		sm.roughness = 0.4
		bit.material_override = sm
		bit.position = bowl.position + Vector3(-0.012 + (k % 2) * 0.016, 0.02, -0.008 + int(k / 2) * 0.014)
		_world.add_child(bit)

	_build_scales(Vector3(-0.58, TABLE_Y, -0.06))
	_build_bell(Vector3(-0.46, TABLE_Y, 0.22))
	_build_dice(Vector3(-0.4, TABLE_Y, 0.26))
	_build_mode_props()
	if Journey.table_mode == "battle":
		_build_opponent()

	for n in 8:
		var mote := MeshInstance3D.new()
		var q := SphereMesh.new()
		q.radius = 0.004
		q.height = 0.008
		mote.mesh = q
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = Color(1.0, 0.78, 0.45)
		mm.emission_enabled = true
		mm.emission = Color(1.0, 0.7, 0.35)
		mm.emission_energy_multiplier = 0.8
		mote.material_override = mm
		mote.position = Vector3(randf_range(-0.7, 0.7), randf_range(0.85, 1.3), randf_range(-0.6, 0.4))
		mote.set_meta("origin", mote.position)
		mote.set_meta("phase", randf() * TAU)
		_world.add_child(mote)
		mote.set_script(null)


func _process_motes() -> void:
	pass


func _build_scales(at: Vector3) -> void:
	_scales = Node3D.new()
	_scales.position = at
	_world.add_child(_scales)
	var wood := _wood(Color(0.3, 0.18, 0.1), 1.0)
	var bronze := _bronze()
	_scales.add_child(_mesh_box(Vector3(0.12, 0.015, 0.07), Vector3(0, 0.008, 0), wood))
	_scales.add_child(_mesh_cyl(0.008, 0.11, Vector3(0, 0.07, 0), bronze))
	_beam = Node3D.new()
	_beam.position = Vector3(0, 0.125, 0)
	_scales.add_child(_beam)
	_beam.add_child(_mesh_box(Vector3(0.2, 0.008, 0.01), Vector3.ZERO, bronze))
	_left_hang = Node3D.new()
	_left_hang.position = Vector3(-0.08, 0, 0)
	_beam.add_child(_left_hang)
	_right_hang = Node3D.new()
	_right_hang.position = Vector3(0.08, 0, 0)
	_beam.add_child(_right_hang)
	for hang in [_left_hang, _right_hang]:
		hang.add_child(_mesh_box(Vector3(0.004, 0.045, 0.004), Vector3(0, -0.02, 0), bronze))
		hang.add_child(_mesh_cyl(0.028, 0.008, Vector3(0, -0.046, 0), bronze))


func _build_bell(at: Vector3) -> void:
	_bell = Node3D.new()
	_bell.position = at
	_world.add_child(_bell)
	var profile := PackedVector2Array([
		Vector2(0.01, 0.0),
		Vector2(0.018, 0.01),
		Vector2(0.014, 0.028),
		Vector2(0.02, 0.04),
		Vector2(0.042, 0.062),
		Vector2(0.05, 0.078),
		Vector2(0.046, 0.084),
	])
	var mesh := _lathe(profile, 18)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _bronze()
	_bell.add_child(mi)
	var tongue := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.008
	sph.height = 0.016
	tongue.mesh = sph
	tongue.material_override = _bronze()
	tongue.position = Vector3(0, 0.05, 0)
	_bell.add_child(tongue)


func _build_dice(at: Vector3) -> void:
	for i in 2:
		var die := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.022, 0.022, 0.022)
		die.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/kenney/dice/dieWhite5.png" if i == 0 else "res://assets/kenney/dice/dieRed3.png")
		mat.roughness = 0.55
		die.material_override = mat
		die.position = at + Vector3(i * 0.03, 0.012, i * 0.01)
		die.rotation = Vector3(0, deg_to_rad(20 + i * 40), 0)
		_world.add_child(die)


func _build_slots() -> void:
	var tex: Texture2D = preload("res://assets/generated/slot_mark.png")
	for row in ["queue", "foe", "player"]:
		for s in 4:
			var mark := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.075, 0.05)
			mark.mesh = plane
			mark.rotation_degrees.x = -90
			mark.position = Vector3(SLOT_X[s], TABLE_Y + 0.001, float(ROW_Z[row]))
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_texture = tex
			mat.albedo_color = Color(1.0, 0.78, 0.48, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.62, 0.32)
			mat.emission_energy_multiplier = 0.45
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mark.material_override = mat
			_world.add_child(mark)
			_slot_mats.append(mat)


func _build_decks() -> void:
	var back: Texture2D = preload("res://assets/generated/card_back.png")
	_deck_anchor = Vector3(0.6, TABLE_Y + CARD_H * 0.46, 0.08)
	_stack_backs(back, _deck_anchor, 7)
	_stack_backs(back, Vector3(0.6, TABLE_Y + CARD_H * 0.46, -0.14), 4)


func _stack_backs(back: Texture2D, origin: Vector3, count: int) -> void:
	for i in count:
		var root := Node3D.new()
		root.position = origin + Vector3(0, i * 0.0016, 0)
		root.rotation = Vector3(-0.1, PI, 0)
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(CARD_W, CARD_H)
		mi.mesh = plane
		mi.rotation_degrees.x = -90
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = back
		mat.roughness = 0.8
		mi.material_override = mat
		root.add_child(mi)
		_world.add_child(root)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	_vp.add_child(layer)
	var hint := Label.new()
	hint.text = "ЛКМ — карта в слот    WASD — взгляд    Пробел — гонг    Esc — назад"
	if Journey.table_mode == "tavern" or Journey.table_mode == "treasure":
		hint.text = "Кликни одну карту, чтобы взять    Esc — назад"
	elif Journey.table_mode == "forge":
		hint.text = "Кузня. Наковальня пока просто стоит здесь    Esc — назад"
	hint.position = Vector2(70, 8)
	hint.size = Vector2(820, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.8, 0.64, 0.72))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)


func _leave() -> void:
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		if Journey.from_map:
			get_tree().change_scene_to_file("res://scenes/map/world_map.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)


func _place_model(path: String, pos: Vector3, height: float, yaw: float) -> Node3D:
	var packed: PackedScene = load(path)
	var inst := packed.instantiate() as Node3D
	_world.add_child(inst)
	inst.rotation.y = deg_to_rad(yaw)
	var box := _merged_aabb(inst)
	var s := height / maxf(box.size.y, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = pos
	inst.position.y = TABLE_Y - box.position.y * s
	return inst


func _merged_aabb(root: Node3D) -> AABB:
	var found := false
	var box := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := root.global_transform.affine_inverse() * mi.global_transform
		var piece := _xform_aabb(local, mi.get_aabb())
		if not found:
			box = piece
			found = true
		else:
			box = box.merge(piece)
	if not found:
		return AABB(Vector3.ZERO, Vector3(0.1, 0.1, 0.1))
	return box


func _xform_aabb(xf: Transform3D, a: AABB) -> AABB:
	var out := AABB()
	for i in 8:
		var p: Vector3 = xf * a.get_endpoint(i)
		if i == 0:
			out = AABB(p, Vector3.ZERO)
		else:
			out = out.expand(p)
	return out


func _top_of(node: Node3D) -> Vector3:
	var box := _merged_aabb(node)
	var top := node.global_transform * Vector3(0, box.position.y + box.size.y, 0)
	return top


func _build_lamp(at: Vector3, _flame_at: Vector3) -> Node3D:
	var lamp := Node3D.new()
	lamp.position = at
	_world.add_child(lamp)
	var metal := _bronze()
	lamp.add_child(_mesh_cyl(0.035, 0.012, Vector3(0, 0.006, 0), metal))
	lamp.add_child(_mesh_cyl(0.01, 0.07, Vector3(0, 0.045, 0), metal))
	var shade := _mesh_cyl(0.04, 0.028, Vector3(0, 0.09, 0), metal)
	lamp.add_child(shade)
	return lamp


func _silhouette(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.09, 0.07, 0.06)
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_silhouette(child)


func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src = mi.get_active_material(i)
				if src is StandardMaterial3D:
					var dup: StandardMaterial3D = src.duplicate()
					dup.albedo_color = color
					dup.roughness = maxf(dup.roughness, 0.65)
					mi.set_surface_override_material(i, dup)
	for child in node.get_children():
		_tint(child, color)


func _add_flame(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.06)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = preload("res://assets/generated/flame.png")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = at
	_world.add_child(mi)
	return mi


func _wood(stain: Color, uv: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/polyhaven/wood_diff.jpg")
	mat.albedo_color = stain
	mat.normal_enabled = true
	mat.normal_texture = preload("res://assets/polyhaven/wood_nor.jpg")
	mat.normal_scale = 0.35
	mat.roughness_texture = preload("res://assets/polyhaven/wood_rough.jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.uv1_scale = Vector3(uv, uv * 0.7, 1)
	return mat


func _bronze() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.42, 0.22)
	mat.metallic = 0.85
	mat.roughness = 0.38
	return mat


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _mesh_box(size, pos, mat)


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _mesh_cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _lathe(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		for j in profile.size() - 1:
			var r0 := profile[j].x
			var y0 := profile[j].y
			var r1 := profile[j + 1].x
			var y1 := profile[j + 1].y
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	return st.commit()


func _image_of(path: String) -> Image:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	return tex.get_image()


func _arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--" + flag)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return ""


func _capture_after_intro() -> void:
	while not _intro_done:
		await get_tree().process_frame
	await get_tree().create_timer(0.85).timeout
	var hero := _arg("hero")
	var name := _shot if _shot != "" else "table"
	if hero != "":
		name = hero
	await _save_shot("/tmp/shot_%s.png" % name)


func _capture() -> void:
	for _i in 6:
		await get_tree().process_frame
	var name := "hover" if _shot == "hover" else "play"
	await _save_shot("/tmp/shot_%s.png" % name)


func _save_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("shot ", path, " ", err, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
