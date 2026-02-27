extends Node

# Variables
var current_player_peer_id: int = 0
var current_turn_index: int = 0
var max_turn_index: int = 7

# Signals
signal current_player_changed(username: String)
signal turn_changed

# Functions
var _timer: float = 0.0

func _ready() -> void:
	NetworkManager.player_list_updated.connect(_on_player_list_updated)
	NetworkManager.all_players_ready.connect(_on_all_players_ready)

func _process(delta: float) -> void:
	if multiplayer.is_server() && current_turn_index < max_turn_index:
		_timer += delta
		if _timer >= 5:
			_timer = 0.0
			current_turn_index += 1
			print("Turn changed: %s" % current_turn_index)
			_turn_changed.rpc(current_turn_index)

func _on_player_list_updated() -> void:
	print("Player list updated")

func _on_all_players_ready() -> void:
	print("All players ready!")
	if multiplayer.is_server():
		_start_game.rpc()

func choose_first_player() -> void:
	if not multiplayer.is_server():
		return
	
	var peer_ids = NetworkManager.players.keys()
	var random_index = peer_ids.find(randi_range(0, peer_ids.size()-1))
	current_player_peer_id = peer_ids[random_index]

	var username = NetworkManager.players[current_player_peer_id]["name"]
	_current_player_changed.rpc(username)

func next_player() -> void:
	if not multiplayer.is_server():
		return

	var peer_ids = NetworkManager.players.keys()
	var current_index = peer_ids.find(current_player_peer_id)
	var next_index = (current_index + 1) % peer_ids.size()
	current_player_peer_id = peer_ids[next_index]

	var username = NetworkManager.players[current_player_peer_id]["name"]
	_current_player_changed.rpc(username)

func request_current_player() -> void:
	if current_player_peer_id == 0:
		return
	var username: String = NetworkManager.players[current_player_peer_id]["name"]
	emit_signal("current_player_changed", username)

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_screen.tscn")
	choose_first_player()

@rpc("authority", "call_local", "reliable")
func _current_player_changed(username: String) -> void:
	emit_signal("current_player_changed", username)

@rpc("authority", "call_local", "reliable")
func _turn_changed(turn_index: int) -> void:
	emit_signal("turn_changed", turn_index)
