extends Polygon2D

@onready var current_player_label: Label = $current_player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.turn_changed.connect(_on_turn_changed)

func _on_turn_changed(username: String) -> void:
	current_player_label.text = "C'est le tour de " + username + " de jouer"
