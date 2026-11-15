extends Node

## Игрок за первым слотом. Бот занимает второй.
## Клавиши физические (QWERTY), русская раскладка не мешает.
## Мышь задаёт прицел, ЛКМ бьёт вперёд, ПКМ — на себя.

signal command_issued(command: BattleCommand)

const ELEMENTS := {
	KEY_Q: "fire",
	KEY_Z: "water",
	KEY_E: "lightning",
	KEY_R: "earth",
	KEY_F: "life",
	KEY_1: "fire",
	KEY_2: "water",
	KEY_3: "lightning",
	KEY_4: "earth",
	KEY_5: "life",
}

var _held := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if MatchSession.mode != "local_hotseat":
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_aim()
			_emit_cast(false)
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			_aim()
			_emit_cast(true)
		return
	if event is InputEventMouseMotion:
		_aim()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var code := key.physical_keycode
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			var restart := BattleCommand.new()
			restart.action = BattleCommand.Action.RESTART
			command_issued.emit(restart)
			return
		if code == KEY_C:
			var clear := BattleCommand.new()
			clear.slot = 0
			clear.action = BattleCommand.Action.CLEAR_QUEUE
			command_issued.emit(clear)
		elif ELEMENTS.has(code):
			var queued := BattleCommand.new()
			queued.slot = 0
			queued.action = BattleCommand.Action.QUEUE_ELEMENT
			queued.element_id = str(ELEMENTS[code])
			command_issued.emit(queued)


func _physics_process(_delta: float) -> void:
	if MatchSession.mode != "local_hotseat":
		return
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	if camera:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x
		forward.y = 0
		right.y = 0
		if forward.length() > 0.001:
			forward = forward.normalized()
		if right.length() > 0.001:
			right = right.normalized()
	var wish := _wasd(forward, right)
	var planar := Vector2(wish.x, wish.z)
	if planar.length() > 1.0:
		planar = planar.normalized()
	if planar.distance_to(_held) < 0.01:
		return
	_held = planar
	var cmd := BattleCommand.new()
	cmd.slot = 0
	cmd.action = BattleCommand.Action.MOVE
	cmd.direction = planar.x
	cmd.strafe = planar.y
	command_issued.emit(cmd)


func _wasd(forward: Vector3, right: Vector3) -> Vector3:
	var wish := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		wish -= right
	if Input.is_physical_key_pressed(KEY_D):
		wish += right
	if Input.is_physical_key_pressed(KEY_W):
		wish += forward
	if Input.is_physical_key_pressed(KEY_S):
		wish -= forward
	return wish


func _aim() -> void:
	var point := _ground_point()
	var cmd := BattleCommand.new()
	cmd.slot = 0
	cmd.action = BattleCommand.Action.AIM
	cmd.aim_x = point.x
	cmd.aim_z = point.z
	command_issued.emit(cmd)


func _ground_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return origin
	var t := (0.0 - origin.y) / direction.y
	return origin + direction * t


func _emit_cast(at_self: bool) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = 0
	cmd.action = BattleCommand.Action.CAST
	cmd.cast_at_self = at_self
	command_issued.emit(cmd)
