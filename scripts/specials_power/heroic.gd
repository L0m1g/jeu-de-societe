class_name PowerHeroic
extends SpecialPower

var hero_regions: Array = []

func _setup() -> void:
	key = "POWER_HEROIC"
	icon_path = "res://assets/images/powers/heroic.png"
	bonus_tokens = 5
# En fin de tour : placer 2 héros dans 2 régions occupées différentes
# Ces régions sont imprenables et immunisées aux capacités adverses
# Les héros disparaissent au déclin
func on_decline(nation: Nation) -> void:
	for region in hero_regions:
		region.has_hero = false
	hero_regions.clear()
