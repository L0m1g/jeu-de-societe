class_name Skeletons
extends Nation

var non_empty_conquered_this_turn: int = 0

func _setup() -> void:
	key = "NATIONS_SKELETONS"
	icon_path = "res://assets/images/nations/skeletons.png"
	base_tokens = 6

func on_conquest(region: Node) -> void:
	super.on_conquest(region)
	if region.is_occupied():
		non_empty_conquered_this_turn += 1

# +1 pion par tranche de 2 régions non-vides conquises
func on_redeploy(owned_regions_list: Array) -> void:
	super.on_redeploy(owned_regions_list)
	var bonus: int = non_empty_conquered_this_turn / 2
	tokens_in_reserve += bonus
	non_empty_conquered_this_turn = 0
