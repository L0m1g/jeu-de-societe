class_name PowerDragonMaster
extends SpecialPower

var dragon_region: Node = null

func _setup() -> void:
	key = "POWER_DRAGON_MASTER"
	icon_path = "res://assets/images/powers/dragon_master.png"
	bonus_tokens = 5
# Une fois par tour : conquête avec 1 seul pion peu importe la défense
# La région conquise est imprenable tant que le dragon y est
# Le dragon se déplace à chaque tour vers une nouvelle région à conquérir
# Disparaît au déclin
func on_decline(nation: Nation) -> void:
	if dragon_region:
		dragon_region.has_dragon = false
		dragon_region = null
