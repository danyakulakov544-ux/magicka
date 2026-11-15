extends Node

## Короткая самоиграйка для проверки картинки: godot --path . -- --demo
## Не участвует в обычном запуске.

var arena: Node
var _time: float = 0.0
var _fired: Dictionary = {}
var _shot_pending: bool = false
var _shot_saved: bool = false


func _ready() -> void:
	arena = get_parent()


func _physics_process(delta: float) -> void:
	_time += delta
	_at(0.25, func() -> void:
		_move(0, 1.0)
		_move(1, -1.0)
	)
	_at(1.15, func() -> void:
		_move(0, 0.0)
		_move(1, 0.0)
	)
	_at(1.25, func() -> void:
		_q(1, "earth")
		_q(1, "life")
	)
	_at(1.55, func() -> void: _cast(1, true))
	_at(1.7, func() -> void:
		_q(0, "fire")
		_q(0, "fire")
	)
	_at(2.0, func() -> void: _cast(0, false))
	_at(2.15, func() -> void:
		_q(0, "water")
		_q(1, "lightning")
	)
	_at(2.3, func() -> void: _request_shot())
	_at(2.6, func() -> void:
		_move(0, 1.0)
		_move(1, -1.0)
	)
	_at(3.0, func() -> void:
		_move(0, 0.0)
		_move(1, 0.0)
	)
	_at(3.5, func() -> void:
		_clear(0)
		_q(0, "lightning")
		_q(0, "lightning")
		_q(0, "lightning")
	)
	_at(3.85, func() -> void: _cast(0, false))
	_at(4.2, func() -> void:
		_clear(1)
		_q(1, "water")
		_q(1, "lightning")
		_cast(1, false)
	)
	_at(4.7, func() -> void:
		_clear(0)
		_q(0, "fire")
		_q(0, "fire")
		_q(0, "fire")
	)
	_at(5.05, func() -> void: _cast(0, false))
	_at(5.5, func() -> void:
		_clear(0)
		_q(0, "fire")
		_q(0, "fire")
	)
	_at(5.85, func() -> void: _cast(0, false))
	_at(6.25, func() -> void:
		_clear(0)
		_q(0, "fire")
	)
	_at(6.6, func() -> void: _cast(0, false))
	if _time > 9.0 and OS.get_cmdline_user_args().has("--demo-quit"):
		get_tree().quit()


func _process(_delta: float) -> void:
	if _shot_pending and not _shot_saved:
		_shot_pending = false
		_shot_saved = true
		_save_shot()


func _at(at_time: float, action: Callable) -> void:
	var key := "%.2f" % at_time
	if _time >= at_time and not _fired.has(key):
		_fired[key] = true
		action.call()


func _request_shot() -> void:
	if _shot_path() != "":
		_shot_pending = true


func _shot_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot="):
			return str(arg).trim_prefix("--shot=")
	return ""


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		push_error("Скриншот: пустой кадр")
		return
	var path := _shot_path()
	var err := image.save_png(path)
	print("SHOT %s err=%s size=%s" % [path, err, image.get_size()])


func _move(slot: int, direction: float) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.MOVE
	cmd.direction = direction
	arena.apply_command(cmd)


func _q(slot: int, element_id: String) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.QUEUE_ELEMENT
	cmd.element_id = element_id
	arena.apply_command(cmd)


func _clear(slot: int) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.CLEAR_QUEUE
	arena.apply_command(cmd)


func _cast(slot: int, at_self: bool) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.CAST
	cmd.cast_at_self = at_self
	arena.apply_command(cmd)
