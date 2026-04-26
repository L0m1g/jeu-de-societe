class_name SpecialPower
extends Resource

var key: String = ""
var icon_path: String = ""
var bonus_tokens: int = 0

func _setup() -> void:
	pass

func _init() -> void:
	_setup()

func get_conquest_cost_modifier(nation: Nation, region: Node) -> int:
	return 0

func calculate_bonus_victory_tokens(nation: Nation, regions: Array) -> int:
	return 0

func on_conquest(nation: Nation, region: Node) -> void:
	pass

func on_redeploy(nation: Nation, owned_regions: Array) -> void:
	pass

func on_decline(nation: Nation) -> void:
	pass
