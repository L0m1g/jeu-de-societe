extends Node

var game_state: Global.GAME_STATE = Global.GAME_STATE.WAITING
var current_player_peer_id: int = 0

signal turn_changed(username: String)

func _ready() -> void:
	NetworkManager.player_list_updated.connect(_on_player_list_updated)
	NetworkManager.all_players_ready.connect(_on_all_players_ready)

func _on_player_list_updated() -> void:
	print("Player list updated")

func _on_all_players_ready() -> void:
	print("All players ready!")
	game_state = Global.GAME_STATE.RUNNING
	if multiplayer.is_server():
		_start_game.rpc()

func choose_first_player() -> void:
	if not multiplayer.is_server():
		return
	
	var peer_ids = NetworkManager.players.keys()
	var random_index = peer_ids.find(randi_range(0, peer_ids.size()-1))
	current_player_peer_id = peer_ids[random_index]

	var username = NetworkManager.players[current_player_peer_id]["name"]
	update_turn_label.rpc(username)

func next_turn() -> void:
	if not multiplayer.is_server():
		return

	var peer_ids = NetworkManager.players.keys()
	var current_index = peer_ids.find(current_player_peer_id)
	var next_index = (current_index + 1) % peer_ids.size()
	current_player_peer_id = peer_ids[next_index]

	var username = NetworkManager.players[current_player_peer_id]["name"]
	update_turn_label.rpc(username)

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_screen.tscn")
	choose_first_player()

@rpc("authority", "call_local", "reliable")
func update_turn_label(username: String) -> void:
	emit_signal("turn_changed", username)
