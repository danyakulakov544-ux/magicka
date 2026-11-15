extends Node

## Простой противник на втором слоте. Ходит к игроку и кастует через те же команды.

const ELEMENTS := ["fire", "fire", "lightning", "earth", "water", "life"]

var _think: float = 0.4
var _pattern: int = 0


func _physics_process(delta: float) -> void:
	var arena := get_parent()
	if arena == null or not arena.bot_enabled or arena.round_over:
		return
	if arena.mages.size() < 2:
		return
	var me: Mage = arena.mages[1]
	var foe: Mage = arena.mages[0]
	if not me.alive or not foe.alive:
		return
	var to := foe.global_position - me.global_position
	to.y = 0
	var distance := to.length()
	var planar := Vector2.ZERO
	if distance > 110.0:
		planar = Vector2(to.x, to.z).normalized()
	elif distance < 46.0:
		planar = -Vector2(to.x, to.z).normalized()
	else:
		var side := Vector2(-to.z, to.x).normalized()
		planar = side * 0.45
	var move := BattleCommand.new()
	move.slot = 1
	move.action = BattleCommand.Action.MOVE
	move.direction = planar.x
	move.strafe = planar.y
	arena.apply_command(move)

	_think -= delta
	if _think > 0.0 or me.cast_lock > 0.0:
		return
	_think = 0.55
	if me.hp < 42 and me.shield < 12:
		_self_ward(me)
		return
	if me.orbs.size() >= 2 or (me.orbs.size() >= 1 and distance < 150.0 and _pattern % 3 == 0):
		var cast := BattleCommand.new()
		cast.slot = 1
		cast.action = BattleCommand.Action.CAST
		cast.cast_at_self = false
		arena.apply_command(cast)
		_pattern += 1
		return
	var element: String = ELEMENTS[_pattern % ELEMENTS.size()]
	_pattern += 1
	var queued := BattleCommand.new()
	queued.slot = 1
	queued.action = BattleCommand.Action.QUEUE_ELEMENT
	queued.element_id = element
	arena.apply_command(queued)


func _self_ward(me: Mage) -> void:
	var arena := get_parent()
	if me.orbs.size() < 2:
		var need := "life" if me.orbs.is_empty() else "earth"
		var queued := BattleCommand.new()
		queued.slot = 1
		queued.action = BattleCommand.Action.QUEUE_ELEMENT
		queued.element_id = need
		arena.apply_command(queued)
		return
	var cast := BattleCommand.new()
	cast.slot = 1
	cast.action = BattleCommand.Action.CAST
	cast.cast_at_self = true
	arena.apply_command(cast)
