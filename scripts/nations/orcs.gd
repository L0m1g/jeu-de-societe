class_name Orcs
extends Nation

var non_empty_conquered_this_turn: int = 0

func _setup() -> void:
	key = "NATIONS_ORCS"
	icon_path = "res://assets/images/nations/orcs.png"
	base_tokens = 5

func on_conquest(region: Node) -> void:
	super.on_conquest(region)
	if region.is_occupied():
		non_empty_conquered_this_turn += 1

func _calculate_race_bonus(regions: Array) -> int:
	return non_empty_conquered_this_turn

func on_redeploy(owned_regions_list: Array) -> void:
	super.on_redeploy(owned_regions_list)
	non_empty_conquered_this_turn = 0
