class_name Trolls
extends Nation

func _setup() -> void:
	key = "NATIONS_TROLLS"
	icon_path = "res://assets/images/nations/trolls.png"
	base_tokens = 5

# Place un Troll's Lair dans chaque région conquise
# L'antre reste même en déclin
# Retiré si la région est abandonnée ou conquise par l'ennemi
func on_conquest(region: Node) -> void:
	super.on_conquest(region)
	region.has_troll_lair = true

func on_region_lost(region: Node) -> int:
	region.has_troll_lair = false
	return 1
