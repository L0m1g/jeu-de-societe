class_name Ghouls
extends Nation

func _setup() -> void:
	key = "NATIONS_GHOULS"
	icon_path = "res://assets/images/nations/ghouls.png"
	base_tokens = 5

# TOUS les pions restent sur le plateau au déclin (pas seulement 1 par région)
# En déclin, peuvent continuer à conquérir avant la nation active
# Logique gérée dans GameManager : ghouls_can_conquer_in_decline
