class_name Amazons
extends Nation

func _setup() -> void:
	key = "NATIONS_AMAZONS"
	icon_path = "res://assets/images/nations/amazons.png"
	base_tokens = 6

# 4 pions offensifs retirés après redéploiement, récupérés au début du tour suivant
func on_redeploy(owned_regions_list: Array) -> void:
	super.on_redeploy(owned_regions_list)
	tokens_in_reserve = max(0, tokens_in_reserve - 4)
