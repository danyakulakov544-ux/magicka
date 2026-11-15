extends RefCounted
class_name BattleCommand

## Одна команда игрока. Сейчас её создаёт локальный хот-сит, позже тот же
## словарь уйдёт на хост по ENet (см. to_dict / from_dict).
## Ввод и сцена не меняют HP напрямую — только BattleArena.apply_command.

enum Action {
	MOVE,
	QUEUE_ELEMENT,
	CLEAR_QUEUE,
	CAST,
	RESTART,
	AIM,
}

var slot: int = 0
var action: Action = Action.MOVE
var element_id: String = ""
## Плоское направление хода в мире: X и Z (strafe). Длина не больше 1.
var direction: float = 0.0
var strafe: float = 0.0
var cast_at_self: bool = false
var aim_x: float = 0.0
var aim_z: float = 0.0


func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"action": int(action),
		"element_id": element_id,
		"direction": direction,
		"strafe": strafe,
		"cast_at_self": cast_at_self,
		"aim_x": aim_x,
		"aim_z": aim_z,
	}


static func from_dict(data: Dictionary) -> BattleCommand:
	var cmd := BattleCommand.new()
	cmd.slot = int(data.get("slot", 0))
	cmd.action = int(data.get("action", Action.MOVE)) as Action
	cmd.element_id = str(data.get("element_id", ""))
	cmd.direction = float(data.get("direction", 0.0))
	cmd.strafe = float(data.get("strafe", 0.0))
	cmd.cast_at_self = bool(data.get("cast_at_self", false))
	cmd.aim_x = float(data.get("aim_x", 0.0))
	cmd.aim_z = float(data.get("aim_z", 0.0))
	return cmd
