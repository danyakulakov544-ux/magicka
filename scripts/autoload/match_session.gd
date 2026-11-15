extends Node

## Граница сессии. Сейчас оба слота живут на этой машине (хот-сит, одна клавиатура).
##
## Следующий шаг — Godot high-level multiplayer поверх ENet:
## хост вызывает ENetMultiplayerPeer.create_server(port), клиент —
## create_client(ip, port). Каждый пир владеет одним слотом (slot_owner).
## Клавиатура по-прежнему читается только в LocalHotseat и превращается
## в BattleCommand. Хост применяет команду в BattleArena.apply_command
## и рассылает её остальным. Маги, HUD и снаряды Input не читают.

## "local_hotseat" сейчас. Позже: "enet_host" или "enet_client".
var mode: String = "local_hotseat"

## peer id владельца слота. 1 — локальный сервер в API мультиплеера Godot.
var slot_owner: Array[int] = [1, 1]


func owns_slot(slot: int) -> bool:
	if mode == "local_hotseat":
		return true
	if slot < 0 or slot >= slot_owner.size():
		return false
	return slot_owner[slot] == multiplayer.get_unique_id()
