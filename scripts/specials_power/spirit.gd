class_name PowerSpirit
extends SpecialPower

func _setup() -> void:
	key = "POWER_SPIRIT"
	icon_path = "res://assets/images/powers/spirit.png"
	bonus_tokens = 5
# En déclin, ne compte pas dans la limite de 1 peuple en déclin
# Permet d'avoir 2 peuples en déclin simultanément
# Les Spirits en déclin restent sur le plateau jusqu'à être conquis
# Si un 3ème peuple décline : les Spirits restent, l'autre déclin disparaît
# Logique gérée dans GameManager : has_spirit_power
