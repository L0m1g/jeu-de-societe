class_name Wizards
extends Nation

func _setup() -> void:
	key = "NATIONS_WIZARDS"
	icon_path = "res://assets/images/nations/wizards.png"
	base_tokens = 5

func _calculate_race_bonus(regions: Array) -> int:
	var count: int = 0
	for region in regions:
		if region.has_magic_source:
			count += 1
	return count
