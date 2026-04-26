class_name Elves
extends Nation

func _setup() -> void:
	key = "NATIONS_ELVES"
	icon_path = "res://assets/images/nations/elves.png"
	base_tokens = 5

# Les Elfes ne perdent aucun pion quand une région est conquise
func on_region_lost(region: Node) -> int:
	return 0
