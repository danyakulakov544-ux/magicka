extends Node3D

var kind: String = "flash"
var duration: float = 0.2
var self_free: bool = false
var _age: float = 0.0
var _mesh: MeshInstance3D
var _beam_dir: Vector3 = Vector3.RIGHT
var _beam_length: float = 1.0
var _mat: StandardMaterial3D
var _base_alpha: float = 1.0


func setup(kind_name: String, spell_color: Color, spell_radius: float, spell_length: float, direction: Vector3, time: float, frees_self: bool) -> void:
	kind = kind_name
	duration = maxf(time, 0.05)
	self_free = frees_self
	var dir := direction
	if dir.length() < 0.001:
		dir = Vector3.RIGHT
	dir = dir.normalized()
	_beam_dir = dir
	_beam_length = maxf(spell_length, 4.0)

	if kind == "beam":
		var box := BoxMesh.new()
		box.size = Vector3(maxf(spell_radius * 1.4, 3.5), maxf(spell_radius * 1.4, 3.5), _beam_length)
		_mesh = MeshInstance3D.new()
		_mesh.mesh = box
		_mat = _glow(spell_color, 0.85, true)
		_base_alpha = 0.85
		_mesh.material_override = _mat
		add_child(_mesh)
		_sparks(spell_color, 22, true, Vector3(0, 0, -1), 0.35)
	elif kind == "area":
		var disc := CylinderMesh.new()
		disc.top_radius = maxf(spell_radius, 8.0)
		disc.bottom_radius = maxf(spell_radius, 8.0) * 0.72
		disc.height = 0.8
		disc.cap_top = true
		disc.cap_bottom = true
		_mesh = MeshInstance3D.new()
		_mesh.mesh = disc
		_mat = _glow(spell_color, 0.45, true)
		_base_alpha = 0.45
		_mesh.material_override = _mat
		add_child(_mesh)
		scale = Vector3(0.25, 1, 0.25)
		_sparks(spell_color, 28, true, Vector3.UP, 0.7)
	elif kind == "heal":
		_sparks(spell_color, 24, true, Vector3.UP, 1.1)
	else:
		var ball := SphereMesh.new()
		ball.radius = maxf(spell_radius, 2.2)
		ball.height = ball.radius * 2.0
		_mesh = MeshInstance3D.new()
		_mesh.mesh = ball
		_mat = _glow(spell_color, 1.0, false)
		_base_alpha = 1.0
		_mesh.material_override = _mat
		add_child(_mesh)
		if kind == "projectile":
			_sparks(spell_color, 16, false, Vector3(0, 0.2, 0), 0.45)
		else:
			_sparks(spell_color, 14, true, Vector3.UP, 0.55)
		var light := OmniLight3D.new()
		light.light_color = spell_color
		light.light_energy = 1.4 if kind == "projectile" else 0.8
		light.omni_range = maxf(spell_radius * 4.0, 18.0)
		add_child(light)


func _ready() -> void:
	if kind == "beam":
		var origin := global_position
		global_position = origin + _beam_dir * _beam_length * 0.5
		var aim := global_position + _beam_dir
		if global_position.distance_squared_to(aim) > 0.001:
			look_at(aim, Vector3.UP)
	elif kind == "area":
		global_position.y = 0.4


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / duration, 0.0, 1.0)
	if kind == "area":
		var grow := lerpf(0.2, 1.0, t)
		scale = Vector3(grow, 1.0, grow)
		_set_alpha(1.0 - t * 0.35)
	elif kind == "beam":
		_set_alpha(1.0 - t * 0.55)
	elif kind != "projectile":
		_set_alpha(1.0 - t)
		if _mesh:
			_mesh.scale = Vector3.ONE * lerpf(0.6, 1.8, t)
	if self_free and _age >= duration:
		queue_free()


func _set_alpha(amount: float) -> void:
	if _mat == null:
		return
	var color := _mat.albedo_color
	color.a = _base_alpha * clampf(amount, 0.0, 1.0)
	_mat.albedo_color = color


func _glow(color: Color, alpha: float, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _sparks(color: Color, amount: int, one_shot: bool, direction: Vector3, life: float) -> void:
	var bits := SphereMesh.new()
	bits.radius = 0.7
	bits.height = 1.4
	var particles := CPUParticles3D.new()
	particles.mesh = bits
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = one_shot
	particles.explosiveness = 0.85 if one_shot else 0.0
	particles.direction = direction
	particles.spread = 28.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.gravity = Vector3(0, 6, 0) if one_shot else Vector3.ZERO
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var mat := _glow(color, 0.9, true)
	particles.mesh.material = mat
	particles.emitting = true
	add_child(particles)
