extends Node

var required_players = 2
var players: Dictionary = {}

signal player_list_updated
signal all_players_ready

@rpc("any_peer", "call_local", "reliable")
func register_player(p_steam_id: int, p_username: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	print("Registering player: %s (peer %s)" % [p_username, sender_id])
	players[sender_id] = { "steam_id": p_steam_id, "name": p_username }

	emit_signal("player_list_updated")
	_check_all_players_ready()

func _check_all_players_ready():
	print("Players: %s / %s" % [players.size(), required_players])
	if players.size() >= required_players:
		emit_signal("all_players_ready")

func del_player(id: int):
	print("Player %s left the game!" % id)
	players.erase(id)
	emit_signal("player_list_updated")
