class_name Dwarves
extends Nation

func _setup() -> void:
	key = "NATIONS_DWARVES"
	icon_path = "res://assets/images/nations/dwarves.png"
	base_tokens = 4

func _calculate_race_bonus(regions: Array) -> int:
	var count: int = 0
	for region in regions:
		if region.has_mine:
			count += 1
	return count

# Les Nains gardent leur bonus mine même en déclin
func calculate_decline_bonus_victory_tokens(regions: Array) -> int:
	return _calculate_race_bonus(regions)
