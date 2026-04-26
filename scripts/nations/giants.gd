class_name Giants
extends Nation

func _setup() -> void:
	key = "NATIONS_GIANTS"
	icon_path = "res://assets/images/nations/giants.png"
	base_tokens = 6

func _get_race_conquest_modifier(region: Node) -> int:
	# -1 si la région cible est adjacente à une montagne occupée par les Giants
	for owned in owned_regions:
		if owned.has_mountain:
			for adjacent in owned.get_adjacent_region_nodes():
				if adjacent == region:
					return -1
	return 0
