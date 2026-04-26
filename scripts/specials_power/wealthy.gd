class_name PowerWealthy
extends SpecialPower

var bonus_collected: bool = false

func _setup() -> void:
	key = "POWER_WEALTHY"
	icon_path = "res://assets/images/powers/wealthy.png"
	bonus_tokens = 4

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	if not bonus_collected and not nation.is_in_decline:
		bonus_collected = true
		return 7
	return 0
