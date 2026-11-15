extends Node

## Единственное место, где читается клавиатура.
## На выходе — BattleCommand, без изменения HP и очередей.
## Клавиши физические (как на QWERTY), русская раскладка не мешает.

signal command_issued(command: BattleCommand)

const BINDINGS := {
	0: {
		"left": KEY_A,
		"right": KEY_D,
		"cast": KEY_SPACE,
		"self": KEY_S,
		"clear": KEY_C,
		"elements": {
			KEY_Q: "fire",
			KEY_W: "water",
			KEY_E: "lightning",
			KEY_R: "earth",
			KEY_F: "life",
		},
	},
	1: {
		"left": KEY_LEFT,
		"right": KEY_RIGHT,
		"cast": KEY_K,
		"self": KEY_J,
		"clear": KEY_SEMICOLON,
		"elements": {
			KEY_U: "fire",
			KEY_I: "water",
			KEY_O: "lightning",
			KEY_P: "earth",
			KEY_H: "life",
		},
	},
}

var _held_dir: Array[float] = [0.0, 0.0]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		var restart := BattleCommand.new()
		restart.action = BattleCommand.Action.RESTART
		command_issued.emit(restart)
		return
	if MatchSession.mode != "local_hotseat":
		return
	for raw_slot in BINDINGS.keys():
		var slot := int(raw_slot)
		if not MatchSession.owns_slot(slot):
			continue
		var binding: Dictionary = BINDINGS[slot]
		var elements: Dictionary = binding["elements"]
		if code == int(binding["clear"]):
			_emit(slot, BattleCommand.Action.CLEAR_QUEUE)
		elif code == int(binding["cast"]):
			_emit_cast(slot, false)
		elif code == int(binding["self"]):
			_emit_cast(slot, true)
		elif elements.has(code):
			var queued := BattleCommand.new()
			queued.slot = slot
			queued.action = BattleCommand.Action.QUEUE_ELEMENT
			queued.element_id = str(elements[code])
			command_issued.emit(queued)


func _physics_process(_delta: float) -> void:
	if MatchSession.mode != "local_hotseat":
		return
	for raw_slot in BINDINGS.keys():
		var slot := int(raw_slot)
		if not MatchSession.owns_slot(slot):
			continue
		var binding: Dictionary = BINDINGS[slot]
		var dir := 0.0
		if Input.is_physical_key_pressed(int(binding["left"])):
			dir -= 1.0
		if Input.is_physical_key_pressed(int(binding["right"])):
			dir += 1.0
		if dir == _held_dir[slot]:
			continue
		_held_dir[slot] = dir
		var cmd := BattleCommand.new()
		cmd.slot = slot
		cmd.action = BattleCommand.Action.MOVE
		cmd.direction = dir
		command_issued.emit(cmd)


func _emit(slot: int, action: BattleCommand.Action) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = action
	command_issued.emit(cmd)


func _emit_cast(slot: int, at_self: bool) -> void:
	var cmd := BattleCommand.new()
	cmd.slot = slot
	cmd.action = BattleCommand.Action.CAST
	cmd.cast_at_self = at_self
	command_issued.emit(cmd)
