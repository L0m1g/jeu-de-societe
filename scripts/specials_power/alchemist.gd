class_name PowerAlchemist
extends SpecialPower

func _setup() -> void:
	key = "POWER_ALCHEMIST"
	icon_path = "res://assets/images/powers/alchemist.png"
	bonus_tokens = 4

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	return 2 if not nation.is_in_decline else 0
