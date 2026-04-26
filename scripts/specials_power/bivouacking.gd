class_name PowerBivouacking
extends SpecialPower

const ENCAMPMENT_COUNT: int = 5
var encampment_regions: Array = []

func _setup() -> void:
	key = "POWER_BIVOUACKING"
	icon_path = "res://assets/images/powers/bivouacking.png"
	bonus_tokens = 5

# Les campements sont redéployés librement à chaque redéploiement
# Ils ne sont jamais perdus lors d'une attaque, retournent au joueur
# Disparaissent au déclin
func on_decline(nation: Nation) -> void:
	for region in encampment_regions:
		region.has_encampment = false
		region.encampment_count = 0
	encampment_regions.clear()
