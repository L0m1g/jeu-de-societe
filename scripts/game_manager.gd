extends Node

@export var loader: PackedScene

var nb_player_needed: int = 6
var game_state: Global.GAME_STATE = Global.GAME_STATE.WAITING

func _process(delta: float) -> void:
	# player connected to the lobby
	var player_connected = 1
	
	if (player_connected != nb_player_needed):
		# Run the loader
		var loader = loader.instantiate()
		get_parent().add_child(loader)
