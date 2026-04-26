class_name PowerUnderworld
extends SpecialPower

func _setup() -> void:
	key = "POWER_UNDERWORLD"
	icon_path = "res://assets/images/powers/underworld.png"
	bonus_tokens = 5

func get_conquest_cost_modifier(nation: Nation, region: Node) -> int:
	return -1 if region.has_cave else 0
# Toutes les régions avec caverne sont considérées adjacentes entre elles
# Logique gérée dans GameManager : get_available_conquest_targets()
