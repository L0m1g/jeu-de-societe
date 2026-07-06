extends Polygon2D

@onready var current_player_label: Label = $"../CanvasLayer/InfoPanel/VBoxContainer/CurrentPlayerLabel"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.current_player_changed.connect(_on_current_player_changed)
	GameManager.request_current_player()

func _on_current_player_changed(username: String) -> void:
	current_player_label.text = "C'est le tour de " + username + " de jouer"
