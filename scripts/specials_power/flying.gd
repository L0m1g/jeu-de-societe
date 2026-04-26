class_name PowerFlying
extends SpecialPower

func _setup() -> void:
	key = "POWER_FLYING"
	icon_path = "res://assets/images/powers/flying.png"
	bonus_tokens = 5
# Peut conquérir n'importe quelle région sauf mers et lacs
# Sans contrainte d'adjacence
# Logique gérée dans GameManager : ignore adjacency check
