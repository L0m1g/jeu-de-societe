class_name PowerPillaging
extends SpecialPower

var non_empty_conquered_this_turn: int = 0

func _setup() -> void:
	key = "POWER_PILLAGING"
	icon_path = "res://assets/images/powers/pillaging.png"
	bonus_tokens = 5

func on_conquest(nation: Nation, region: Node) -> void:
	if region.is_occupied():
		non_empty_conquered_this_turn += 1

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	return non_empty_conquered_this_turn

func on_redeploy(nation: Nation, owned_regions: Array) -> void:
	non_empty_conquered_this_turn = 0
