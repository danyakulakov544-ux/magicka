extends SceneTree

## One-shot: render circular stand-in portraits from the hero models.
## Replace the PNGs later; paths stay the same.

const HEROES := [
	{"id": "human_king", "scene": "res://assets/kaykit/Knight.glb", "border": Color("d4a24a")},
	{"id": "mage_king", "scene": "res://assets/kaykit/Mage.glb", "border": Color("6f8fd4")},
	{"id": "undead_king", "scene": "res://assets/kaykit/Skeleton_Warrior.glb", "border": Color("8d9a78")},
	{"id": "bear", "scene": "res://assets/quaternius/bear.glb", "border": Color("c47848")},
]


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for hero in HEROES:
		await _render_one(hero)
	print("portraits done")
	quit()


func _render_one(hero: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1, 0.09, 0.08, 1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.5, 0.46)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.3
	world.add_child(key)
	var packed: PackedScene = load(hero["scene"])
	var actor := packed.instantiate() as Node3D
	world.add_child(actor)
	var box := _aabb(actor)
	var height := maxf(box.size.y, 0.001)
	var focus := box.get_center()
	focus.y = box.position.y + box.size.y * 0.78
	if str(hero["id"]) == "bear":
		focus = box.get_center()
		focus.y = box.position.y + box.size.y * 0.62
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.current = true
	world.add_child(cam)
	if str(hero["id"]) == "bear":
		focus = Vector3(box.get_center().x, box.position.y + box.size.y * 0.42, box.position.z + box.size.z * 0.18)
		cam.position = Vector3(focus.x + 0.15, focus.y + 0.35, box.position.z - 0.35)
	else:
		cam.position = focus + Vector3(0.0, height * 0.08, height * 1.35)
	cam.look_at(focus, Vector3.UP)
	for _i in 6:
		await process_frame
	var image := vp.get_texture().get_image()
	_circle(image, hero["border"])
	var path := "res://assets/portraits/heroes/%s.png" % str(hero["id"])
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := image.save_png(abs_path)
	print("portrait ", hero["id"], " ", err, " ", abs_path)
	vp.queue_free()
	await process_frame


func _aabb(root: Node3D) -> AABB:
	var found := false
	var box := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var piece := _xform(root.global_transform.affine_inverse() * mi.global_transform, mi.get_aabb())
		if not found:
			box = piece
			found = true
		else:
			box = box.merge(piece)
	return box


func _xform(xf: Transform3D, a: AABB) -> AABB:
	var out := AABB()
	for i in 8:
		var p: Vector3 = xf * a.get_endpoint(i)
		if i == 0:
			out = AABB(p, Vector3.ZERO)
		else:
			out = out.expand(p)
	return out


func _circle(image: Image, border: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var c := Vector2(w, h) * 0.5
	var radius := float(w) * 0.46
	var ring := float(w) * 0.06
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(c)
			if d > radius:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > radius - ring:
				image.set_pixel(x, y, border)
