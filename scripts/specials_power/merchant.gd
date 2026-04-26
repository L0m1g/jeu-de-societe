class_name PowerMerchant
extends SpecialPower

func _setup() -> void:
	key = "POWER_MERCHANT"
	icon_path = "res://assets/images/powers/merchant.png"
	bonus_tokens = 2

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	return regions.size() if not nation.is_in_decline else 0
