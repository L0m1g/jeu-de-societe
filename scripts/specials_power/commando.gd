class_name PowerCommando
extends SpecialPower

func _setup() -> void:
	key = "POWER_COMMANDO"
	icon_path = "res://assets/images/powers/commando.png"
	bonus_tokens = 4

func get_conquest_cost_modifier(nation: Nation, region: Node) -> int:
	return -1  # Toute région coûte 1 pion de moins, minimum 1
