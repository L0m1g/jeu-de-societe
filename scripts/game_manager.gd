extends Node

var game_state: Global.GAME_STATE = Global.GAME_STATE.WAITING

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

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_screen.tscn")
