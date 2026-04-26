class_name Humans
extends Nation

func _setup() -> void:
	key = "NATIONS_HUMANS"
	icon_path = "res://assets/images/nations/humans.png"
	base_tokens = 5

func _calculate_race_bonus(regions: Array) -> int:
	var count: int = 0
	for region in regions:
		if region.region_type == Global.RegionType.FIELD:
			count += 1
	return count
