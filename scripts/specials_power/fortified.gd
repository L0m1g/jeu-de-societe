class_name PowerFortified
extends SpecialPower

var fortresses_placed: int = 0
const MAX_FORTRESSES_ON_MAP: int = 6

func _setup() -> void:
	key = "POWER_FORTIFIED"
	icon_path = "res://assets/images/powers/fortified.png"
	bonus_tokens = 3
# Une fois par tour : placer 1 forteresse dans une région occupée
# +1 jeton de victoire par forteresse en fin de tour (sauf si en déclin)
# La forteresse augmente la défense de +1 même en déclin
# Retirée si la région est abandonnée ou conquise
# Max 1 forteresse par région, max 6 sur le plateau

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	if nation.is_in_decline:
		return 0
	var count: int = 0
	for region in regions:
		if region.has_fortress:
			count += 1
	return count
