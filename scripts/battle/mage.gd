extends CharacterBody3D
class_name Mage

const CHEST_HEIGHT := 22.0

var slot: int = 0
var max_hp: int = 100
var hp: int = 100
var max_shield: int = 80
var shield: int = 0
var orbs: Array[String] = []
var alive: bool = true
var move_dir: Vector2 = Vector2.ZERO
var facing_dir: Vector3 = Vector3.RIGHT
var use_aim: bool = false
var aim_point: Vector3 = Vector3.ZERO
var spawn_position: Vector3 = Vector3.ZERO
var slow_factor: float = 1.0
var slow_left: float = 0.0
var cast_lock: float = 0.0

var yaw_pivot: Node3D
var body: Node3D
var bars: Node3D
var anim: AnimationPlayer
var flash_mesh: MeshInstance3D
var gem: MeshInstance3D
var gem_mat: StandardMaterial3D
var shield_mesh: MeshInstance3D
var orb_meshes: Array[MeshInstance3D] = []
var hp_fill: MeshInstance3D
var shield_fill: MeshInstance3D
var hp_label: Label3D
var name_label: Label3D
var _action: String = ""
var _action_left: float = 0.0
var _flash_left: float = 0.0
var _bob: float = 0.0


func setup(slot_index: int, robe: Color, hat: Color, hp_max: int, shield_max: int) -> void:
	slot = slot_index
	max_hp = hp_max
	hp = hp_max
	max_shield = shield_max
	shield = 0
	spawn_position = position
	facing_dir = Vector3.RIGHT if slot_index == 0 else Vector3.LEFT
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	_build_visual(robe, hat)
	_build_collision()
	_build_animations()
	_apply_yaw()


func chest() -> Vector3:
	return global_position + Vector3(0, CHEST_HEIGHT, 0)


func set_facing_dir(dir: Vector3) -> void:
	if not alive:
		return
	dir.y = 0
	if dir.length() < 0.05:
		return
	facing_dir = dir.normalized()
	_apply_yaw()


func tick(delta: float) -> void:
	if cast_lock > 0.0:
		cast_lock = maxf(cast_lock - delta, 0.0)
	if slow_left > 0.0:
		slow_left = maxf(slow_left - delta, 0.0)
		if slow_left <= 0.0:
			slow_factor = 1.0
	_bob += delta
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		if flash_mesh:
			flash_mesh.visible = alive and _flash_left > 0.0
	if gem_mat:
		gem_mat.emission_energy_multiplier = 1.6 + sin(_bob * 6.0) * 0.45
	if shield_mesh and shield_mesh.visible:
		var pulse := 1.0 + sin(_bob * 4.0) * 0.03
		shield_mesh.scale = Vector3.ONE * pulse
	if _action_left > 0.0:
		_action_left = maxf(_action_left - delta, 0.0)
		if _action_left <= 0.0:
			_action = ""
	_update_anim()
	_billboard()


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
	if flash_mesh:
		flash_mesh.visible = true
		var mat := flash_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
			mat.emission = color
	play_hit()


func play_cast() -> void:
	if not alive or anim == null:
		return
	_action = "cast"
	_action_left = 0.42
	anim.play("cast")


func play_hit() -> void:
	if not alive or anim == null or _action == "cast":
		return
	_action = "hit"
	_action_left = 0.28
	anim.play("hit")


func sync_orbs(colors: Array) -> void:
	for i in orb_meshes.size():
		var mesh := orb_meshes[i]
		mesh.visible = alive
		var mat := mesh.material_override as StandardMaterial3D
		if i < colors.size():
			mat.albedo_color = colors[i]
			mat.emission = colors[i]
			mat.emission_energy_multiplier = 2.2
			mesh.scale = Vector3.ONE
		else:
			mat.albedo_color = Color(1, 1, 1, 0.18)
			mat.emission = Color(0.5, 0.5, 0.6)
			mat.emission_energy_multiplier = 0.15
			mesh.scale = Vector3.ONE * 0.72
	if gem_mat:
		if colors.size() > 0:
			gem_mat.albedo_color = colors[-1]
			gem_mat.emission = colors[-1]
		else:
			gem_mat.albedo_color = Color("ffe08a")
			gem_mat.emission = Color("ffe08a")
	_refresh_bars()


func reset_match() -> void:
	hp = max_hp
	shield = 0
	orbs.clear()
	alive = true
	move_dir = Vector2.ZERO
	use_aim = false
	slow_factor = 1.0
	slow_left = 0.0
	cast_lock = 0.0
	_flash_left = 0.0
	_action = ""
	_action_left = 0.0
	facing_dir = Vector3.RIGHT if slot == 0 else Vector3.LEFT
	position = spawn_position
	velocity = Vector3.ZERO
	collision_layer = 1
	collision_mask = 1
	if body:
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO
	if flash_mesh:
		flash_mesh.visible = false
	if yaw_pivot:
		yaw_pivot.visible = true
	_apply_yaw()
	if anim:
		anim.play("idle")
	sync_orbs([])


func _die() -> void:
	alive = false
	move_dir = Vector2.ZERO
	velocity = Vector3.ZERO
	orbs.clear()
	collision_layer = 0
	collision_mask = 0
	if shield_mesh:
		shield_mesh.visible = false
	if anim:
		anim.play("death")
	_action = "death"
	_action_left = 10.0


func _apply_yaw() -> void:
	if yaw_pivot == null or not alive:
		return
	yaw_pivot.rotation.y = atan2(facing_dir.x, facing_dir.z)


func _update_anim() -> void:
	if anim == null:
		return
	if not alive:
		return
	if _action != "":
		return
	var moving := move_dir.length() > 0.15
	var want := "run" if moving else "idle"
	if anim.current_animation != want:
		anim.play(want)


func _billboard() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or bars == null:
		return
	var target := camera.global_position
	if bars.global_position.distance_squared_to(target) > 0.01:
		bars.look_at(target, Vector3.UP)


func _refresh_bars() -> void:
	var hp_ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if hp_fill:
		hp_fill.scale.x = maxf(hp_ratio, 0.001)
		hp_fill.position.x = -14.0 + 14.0 * hp_ratio
		var mat := hp_fill.material_override as StandardMaterial3D
		mat.albedo_color = Color("e24b43").lerp(Color("5dce6a"), hp_ratio)
	if shield_fill:
		var shield_ratio := 0.0 if max_shield <= 0 else clampf(float(shield) / float(max_shield), 0.0, 1.0)
		shield_fill.scale.x = maxf(shield_ratio, 0.001)
		shield_fill.position.x = -14.0 + 14.0 * shield_ratio
		shield_fill.visible = alive and shield > 0
	if hp_label:
		hp_label.text = str(hp)
		hp_label.visible = alive
	if shield_mesh:
		shield_mesh.visible = alive and shield > 0


func _build_visual(robe: Color, hat: Color) -> void:
	var shadow := _disk(self, 9.0, Color(0, 0, 0, 0.35), 0.08)
	shadow.position = Vector3(0, 0.06, 0)

	yaw_pivot = Node3D.new()
	yaw_pivot.name = "Yaw"
	add_child(yaw_pivot)

	body = Node3D.new()
	body.name = "Body"
	yaw_pivot.add_child(body)

	var skin := Color("f0c2a0")
	var boot := Color("2a211c")
	var wood := Color("6a4630")
	var dark := robe.darkened(0.28)
	_mesh(body, "LegL", _capsule(2.1, 9.0), Vector3(-2.4, 5.2, 0.4), _mat(dark))
	_mesh(body, "LegR", _capsule(2.1, 9.0), Vector3(2.4, 5.2, 0.4), _mat(dark))
	_mesh(body, "BootL", _sphere(2.0), Vector3(-2.4, 1.2, -0.4), _mat(boot))
	_mesh(body, "BootR", _sphere(2.0), Vector3(2.4, 1.2, -0.4), _mat(boot))
	_mesh(body, "Robe", _cone(7.2, 5.4, 16.0), Vector3(0, 16.5, 0.6), _mat(robe))
	_mesh(body, "Skirt", _cone(8.4, 6.6, 8.0), Vector3(0, 8.5, 0.8), _mat(robe.darkened(0.12)))
	_mesh(body, "Belt", _cylinder(7.4, 7.4, 1.3), Vector3(0, 14.2, 0.9), _mat(Color("e6c56a")))
	_mesh(body, "Head", _sphere(4.3), Vector3(0, 26.5, 0.2), _mat(skin))
	_mesh(body, "Nose", _sphere(0.7), Vector3(0, 26.2, -3.6), _mat(skin.darkened(0.08)))
	_mesh(body, "EyeL", _sphere(0.55), Vector3(-1.3, 27.2, -3.5), _emissive(Color.WHITE, 0.4))
	_mesh(body, "EyeR", _sphere(0.55), Vector3(1.3, 27.2, -3.5), _emissive(Color.WHITE, 0.4))
	_mesh(body, "PupilL", _sphere(0.28), Vector3(-1.3, 27.15, -3.95), _mat(Color("1b1b22")))
	_mesh(body, "PupilR", _sphere(0.28), Vector3(1.3, 27.15, -3.95), _mat(Color("1b1b22")))
	_mesh(body, "Beard", _sphere(2.2), Vector3(0, 23.6, -2.2), _mat(robe.darkened(0.45)))
	_mesh(body, "HatBrim", _cylinder(6.2, 6.2, 0.7), Vector3(0, 30.2, 0), _mat(hat))
	_mesh(body, "Hat", _cone(0.2, 4.6, 10.0), Vector3(0, 35.4, 0), _mat(hat))
	_mesh(body, "HatBand", _cylinder(4.7, 4.7, 0.8), Vector3(0, 31.2, 0), _mat(Color("e6c56a")))

	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	arm_l.position = Vector3(-6.2, 20.5, 0.2)
	body.add_child(arm_l)
	_mesh(arm_l, "Sleeve", _capsule(1.7, 8.0), Vector3(0, -3.2, -1.0), _mat(robe))

	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	arm_r.position = Vector3(5.4, 20.0, -1.0)
	body.add_child(arm_r)
	_mesh(arm_r, "Sleeve", _capsule(1.7, 7.0), Vector3(0.4, -2.4, -2.0), _mat(robe))
	_mesh(arm_r, "Staff", _cylinder(0.45, 0.45, 22.0), Vector3(1.2, 2.0, -6.0), _mat(wood))
	gem = _mesh(arm_r, "Gem", _sphere(1.35), Vector3(1.2, 12.6, -6.0), _emissive(Color("ffe08a"), 1.8))
	gem_mat = gem.material_override as StandardMaterial3D

	shield_mesh = _mesh(yaw_pivot, "Shield", _sphere(15.0), Vector3(0, 18, 0), _shield_mat())
	shield_mesh.visible = false
	flash_mesh = _mesh(body, "Flash", _sphere(8.5), Vector3(0, 18, 0), _shield_mat())
	flash_mesh.visible = false
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	bars = Node3D.new()
	bars.name = "Bars"
	bars.position = Vector3(0, 50, 0)
	add_child(bars)
	_mesh(bars, "HpBack", _box(30, 3.2, 0.4), Vector3(0, 0, 0), _flat(Color(0, 0, 0, 0.55)))
	hp_fill = _mesh(bars, "HpFill", _box(28, 2.2, 0.5), Vector3(0, 0, -0.2), _flat(Color("5dce6a")))
	shield_fill = _mesh(bars, "ShieldFill", _box(28, 1.4, 0.5), Vector3(0, -2.6, -0.2), _flat(Color("8ecbff")))
	var font: Font = load("res://fonts/NotoSans-Regular.ttf")
	name_label = Label3D.new()
	name_label.text = "Маг %d" % [slot + 1]
	name_label.position = Vector3(0, 4.6, 0)
	name_label.font_size = 42
	name_label.pixel_size = 0.055
	name_label.outline_size = 10
	name_label.modulate = Color.WHITE
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if font:
		name_label.font = font
	bars.add_child(name_label)
	hp_label = Label3D.new()
	hp_label.text = "100"
	hp_label.position = Vector3(0, -5.2, 0)
	hp_label.font_size = 36
	hp_label.pixel_size = 0.05
	hp_label.outline_size = 8
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if font:
		hp_label.font = font
	bars.add_child(hp_label)

	var orb_root := Node3D.new()
	orb_root.name = "Orbs"
	orb_root.position = Vector3(0, 41.5, 0)
	yaw_pivot.add_child(orb_root)
	for i in 3:
		var orb := _mesh(orb_root, "Orb%d" % i, _sphere(1.5), Vector3(-4.2 + i * 4.2, 0, 0), _emissive(Color(1, 1, 1, 0.2), 0.2))
		orb_meshes.append(orb)

	anim = AnimationPlayer.new()
	anim.name = "Anim"
	add_child(anim)
	_refresh_bars()


func _build_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 7.0
	shape.height = 34.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 17, 0)
	add_child(collision)


func _build_animations() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", _anim_idle())
	library.add_animation("run", _anim_run())
	library.add_animation("cast", _anim_cast())
	library.add_animation("hit", _anim_hit())
	library.add_animation("death", _anim_death())
	anim.add_animation_library("", library)
	anim.play("idle")


func _anim_idle() -> Animation:
	var animation := Animation.new()
	animation.length = 1.6
	animation.loop_mode = Animation.LOOP_LINEAR
	_pos_keys(animation, "Yaw/Body", [0.0, 0.8, 1.6], [Vector3(0, 0, 0), Vector3(0, 0.7, 0), Vector3(0, 0, 0)])
	_rot_keys(animation, "Yaw/Body/ArmR", [0.0, 0.8, 1.6], [Vector3.ZERO, Vector3(0.12, 0, 0.08), Vector3.ZERO])
	_rot_keys(animation, "Yaw/Body/Hat", [0.0, 0.8, 1.6], [Vector3.ZERO, Vector3(0.04, 0, 0.05), Vector3.ZERO])
	return animation


func _anim_run() -> Animation:
	var animation := Animation.new()
	animation.length = 0.48
	animation.loop_mode = Animation.LOOP_LINEAR
	_pos_keys(animation, "Yaw/Body", [0.0, 0.12, 0.24, 0.36, 0.48], [
		Vector3(0, 0, 0), Vector3(0, 1.1, 0), Vector3(0, 0.15, 0), Vector3(0, 1.1, 0), Vector3(0, 0, 0),
	])
	_rot_keys(animation, "Yaw/Body/LegL", [0.0, 0.24, 0.48], [Vector3(0.55, 0, 0), Vector3(-0.55, 0, 0), Vector3(0.55, 0, 0)])
	_rot_keys(animation, "Yaw/Body/LegR", [0.0, 0.24, 0.48], [Vector3(-0.55, 0, 0), Vector3(0.55, 0, 0), Vector3(-0.55, 0, 0)])
	_rot_keys(animation, "Yaw/Body/ArmL", [0.0, 0.24, 0.48], [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0)])
	_rot_keys(animation, "Yaw/Body/ArmR", [0.0, 0.24, 0.48], [Vector3(0.35, 0, 0), Vector3(-0.25, 0, 0), Vector3(0.35, 0, 0)])
	return animation


func _anim_cast() -> Animation:
	var animation := Animation.new()
	animation.length = 0.42
	animation.loop_mode = Animation.LOOP_NONE
	_rot_keys(animation, "Yaw/Body/ArmR", [0.0, 0.16, 0.42], [Vector3(0, 0, 0), Vector3(-1.15, 0.2, 0), Vector3(0.15, 0, 0)])
	_rot_keys(animation, "Yaw/Body", [0.0, 0.16, 0.42], [Vector3.ZERO, Vector3(-0.12, 0, 0), Vector3.ZERO])
	return animation


func _anim_hit() -> Animation:
	var animation := Animation.new()
	animation.length = 0.28
	animation.loop_mode = Animation.LOOP_NONE
	_rot_keys(animation, "Yaw/Body", [0.0, 0.08, 0.28], [Vector3.ZERO, Vector3(0.35, 0, 0.2), Vector3.ZERO])
	_pos_keys(animation, "Yaw/Body", [0.0, 0.08, 0.28], [Vector3.ZERO, Vector3(0, 0, 1.4), Vector3.ZERO])
	return animation


func _anim_death() -> Animation:
	var animation := Animation.new()
	animation.length = 0.7
	animation.loop_mode = Animation.LOOP_NONE
	_rot_keys(animation, "Yaw/Body", [0.0, 0.7], [Vector3.ZERO, Vector3(0, 0, 1.45)])
	_pos_keys(animation, "Yaw/Body", [0.0, 0.7], [Vector3.ZERO, Vector3(0, -6.0, 0)])
	return animation


func _pos_keys(animation: Animation, path: String, times: Array, values: Array) -> void:
	var idx := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(idx, NodePath(path))
	for i in times.size():
		animation.position_track_insert_key(idx, float(times[i]), values[i])


func _rot_keys(animation: Animation, path: String, times: Array, eulers: Array) -> void:
	var idx := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(idx, NodePath(path))
	for i in times.size():
		animation.rotation_track_insert_key(idx, float(times[i]), Quaternion.from_euler(eulers[i]))


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _disk(parent: Node3D, radius: float, color: Color, y: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.12
	var mat := _flat(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var instance := _mesh(parent, "Shadow", mesh, Vector3(0, y, 0), mat)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.1)
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	return _cylinder(top, bottom, height)


func _box(width: float, height: float, depth: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	return mesh


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	return mat


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _mat(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _shield_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.65, 0.86, 1.0, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.82, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.15
	return mat
