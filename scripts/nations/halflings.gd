class_name Halflings
extends Nation

var holes_placed: int = 0

func _setup() -> void:
	key = "NATIONS_HALFLINGS"
	icon_path = "res://assets/images/nations/halflings.png"
	base_tokens = 6

# Peuvent entrer par n'importe quelle région (pas seulement bordure)
# Placent un Hole-in-the-Ground dans les 2 premières régions conquises
# Ces régions sont imprenables et immunisées aux capacités adverses
func on_conquest(region: Node) -> void:
	super.on_conquest(region)
	if holes_placed < 2:
		region.has_hole_in_ground = true
		holes_placed += 1

func on_decline() -> void:
	super.on_decline()
	holes_placed = 0
