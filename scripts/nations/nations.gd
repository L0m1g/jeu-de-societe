class_name Nation
extends Resource

var key: String = ""
var icon_path: String = ""
var base_tokens: int = 0
var special_power: SpecialPower = null
var is_in_decline: bool = false
var tokens_in_reserve: int = 0
var owned_regions: Array = []
var decline_regions: Array = []

func get_total_tokens() -> int:
	return base_tokens + (special_power.bonus_tokens if special_power else 0)

func _setup() -> void:
	pass

func _init() -> void:
	_setup()

# Coût de conquête modifié par la nation ET le pouvoir spécial
func get_conquest_cost_modifier(region: Node) -> int:
	var mod: int = 0
	mod += _get_race_conquest_modifier(region)
	if special_power and not is_in_decline:
		mod += special_power.get_conquest_cost_modifier(self, region)
	return mod

# Surcharge par les nations avec modificateur de conquête (Giants, Tritons)
func _get_race_conquest_modifier(region: Node) -> int:
	return 0

# Jetons de victoire bonus — nation + pouvoir spécial
func calculate_bonus_victory_tokens(regions: Array) -> int:
	var total: int = _calculate_race_bonus(regions)
	if special_power and not is_in_decline:
		total += special_power.calculate_bonus_victory_tokens(self, regions)
	return total

# Bonus des nations en déclin (ex: Nains gardent leur bonus mine)
func calculate_decline_bonus_victory_tokens(regions: Array) -> int:
	return 0

func _calculate_race_bonus(regions: Array) -> int:
	return 0

# Appelée quand une région est conquise par cette nation
func on_conquest(region: Node) -> void:
	if special_power and not is_in_decline:
		special_power.on_conquest(self, region)

# Appelée quand une région est perdue — retourne le nombre de pions perdus
func on_region_lost(region: Node) -> int:
	return 1

# Appelée lors du redéploiement
func on_redeploy(owned_regions_list: Array) -> void:
	if special_power and not is_in_decline:
		special_power.on_redeploy(self, owned_regions_list)

# Appelée quand la nation passe en déclin
func on_decline() -> void:
	is_in_decline = true
	if special_power:
		special_power.on_decline(self)
		# Le pouvoir spécial est défaussé sauf Spirit
		if not special_power is PowerSpirit:
			special_power = null
