class_name PowerMounted
extends SpecialPower

func _setup() -> void:
	key = "POWER_MOUNTED"
	icon_path = "res://assets/images/powers/mounted.png"
	bonus_tokens = 5

func get_conquest_cost_modifier(nation: Nation, region: Node) -> int:
	if region.region_type == Global.RegionType.HILL or \
	   region.region_type == Global.RegionType.FIELD:
		return -1
	return 0
