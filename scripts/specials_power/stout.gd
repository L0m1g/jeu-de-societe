class_name PowerStout
extends SpecialPower

func _setup() -> void:
	key = "POWER_STOUT"
	icon_path = "res://assets/images/powers/stout.png"
	bonus_tokens = 4
# Peut passer en déclin à la fin d'un tour normal de conquête après scoring
# Sans perdre un tour entier pour décliner
# Logique gérée dans GameManager : can_decline_this_turn
