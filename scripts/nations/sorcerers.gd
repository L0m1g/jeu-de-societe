class_name Sorcerers
extends Nation

func _setup() -> void:
	key = "NATIONS_SORCERES"
	icon_path = "res://assets/images/nations/sorcerers.png"
	base_tokens = 5
# Une fois par tour par adversaire :
# Remplace un pion adverse ACTIF seul dans sa région par un des leurs
# Le pion doit être le seul de son peuple dans la région
# La région doit être adjacente à une région des Sorciers
# Si un Elfe est converti, il perd quand même son pion
# Logique gérée dans GameManager : attempt_sorcerer_conversion()
