class_name PowerSwamp
extends SpecialPower

func _setup() -> void:
	key = "POWER_SWAMP"
	icon_path = "res://assets/images/powers/swamp.png"
	bonus_tokens = 4

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	var count: int = 0
	for region in regions:
		if region.region_type == Global.RegionType.SWAMP:
			count += 1
	return count
