class_name Tritons
extends Nation

func _setup() -> void:
	key = "NATIONS_TRITONS"
	icon_path = "res://assets/images/nations/tritons.png"
	base_tokens = 5

func _get_race_conquest_modifier(region: Node) -> int:
	# -1 pour toute région côtière (adjacente à une mer ou un lac)
	if region.region_type == Global.RegionType.COAST:
		return -1
	for adjacent in region.get_adjacent_region_nodes():
		if adjacent.region_type == Global.RegionType.SEA or \
		   adjacent.region_type == Global.RegionType.LAKE:
			return -1
	return 0
