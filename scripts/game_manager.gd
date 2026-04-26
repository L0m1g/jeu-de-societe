extends Node

# ─── État général ────────────────────────────────────────────────
const LOADER_SCENE = preload("res://scenes/loader.tscn")
var game_state: Global.GameState = Global.GameState.WAITING
var turn_phase: Global.TurnPhase = Global.TurnPhase.PICK_NATION
var current_turn: int = 0
var max_turns: int = 8
var current_player_peer_id: int = 0
var player_order: Array = []

# ─── Joueurs ─────────────────────────────────────────────────────
var players: Dictionary = {}
# { peer_id: {
#     "name": String,
#     "victory_coins": int,
#     "active_nation": Nation,
#     "decline_nation": Nation,
#     "has_nation": bool,
#     "ally_peer_id": int,
#     "sorcerer_used_against": Array,
#     "stout_decline_available": bool,
#     "dragon_moved_this_turn": bool,
#     "heroes_placed_this_turn": bool,
#     "fortress_placed_this_turn": bool
# } }

# ─── Signaux ─────────────────────────────────────────────────────
signal game_state_changed(new_state: Global.GameState)
signal turn_phase_changed(new_phase: Global.TurnPhase)
signal current_player_changed(username: String)
signal victory_coins_updated(peer_id: int, coins: int)
signal turn_changed(turn: int)
signal all_players_ready

# ═════════════════════════════════════════════════════════════════
# INITIALISATION
# ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	NetworkManager.all_players_ready.connect(_on_all_players_ready)
	DraftManager.all_nations_picked.connect(_on_all_nations_picked)
	ConquestManager.conquest_phase_ended.connect(_on_conquest_phase_ended)
	ConquestManager.redeploy_ended.connect(_on_redeploy_ended)
	ScoringManager.scoring_completed.connect(_on_scoring_completed)
	DeclineManager.decline_completed.connect(_on_decline_completed)

func _on_all_players_ready() -> void:
	emit_signal("all_players_ready")
	if multiplayer.is_server():
		_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	# Connecter le signal avant de changer de scène
	get_tree().tree_changed.connect(_on_scene_ready, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file("res://scenes/main_screen.tscn")

func _on_scene_ready() -> void:
	await get_tree().process_frame
	
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return
	
	var loader = LOADER_SCENE.instantiate()
	current_scene.add_child(loader)
	
	_initialize_players()
	_determine_player_order()
	game_state = Global.GameState.DRAFT
	emit_signal("game_state_changed", game_state)
	DraftManager.setup_draft()
	DraftManager.start_draft_turn()

func _initialize_players() -> void:
	for peer_id in NetworkManager.players.keys():
		players[peer_id] = {
			"name": NetworkManager.players[peer_id]["name"],
			"victory_coins": 5,
			"active_nation": null,
			"decline_nation": null,
			"has_nation": false,
			"ally_peer_id": -1,
			"sorcerer_used_against": [],
			"stout_decline_available": false,
			"dragon_moved_this_turn": false,
			"heroes_placed_this_turn": false,
			"fortress_placed_this_turn": false,
			"encampments_placed_this_turn": false,
			"diplomat_chosen_this_turn": false
		}

func _determine_player_order() -> void:
	if not multiplayer.is_server():
		return
	player_order = players.keys()
	player_order.shuffle()
	_sync_player_order.rpc(player_order)

@rpc("authority", "call_local", "reliable")
func _sync_player_order(order: Array) -> void:
	player_order = order

# ═════════════════════════════════════════════════════════════════
# TRANSITIONS DE PHASE
# ═════════════════════════════════════════════════════════════════

func _on_all_nations_picked() -> void:
	if not multiplayer.is_server():
		return
	game_state = Global.GameState.PLAYING
	current_turn = 1
	_begin_turn.rpc(player_order[0], current_turn)

@rpc("authority", "call_local", "reliable")
func _begin_turn(peer_id: int, turn: int) -> void:
	current_player_peer_id = peer_id
	current_turn = turn
	_reset_turn_flags(peer_id)
	emit_signal("current_player_changed", players[peer_id]["name"])
	emit_signal("turn_changed", turn)
	# Le joueur choisit conquérir ou décliner
	turn_phase = Global.TurnPhase.CHOOSE_ACTION
	emit_signal("turn_phase_changed", turn_phase)

func _reset_turn_flags(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["sorcerer_used_against"].clear()
	players[peer_id]["dragon_moved_this_turn"] = false
	players[peer_id]["heroes_placed_this_turn"] = false
	players[peer_id]["fortress_placed_this_turn"] = false
	players[peer_id]["stout_decline_available"] = false
	players[peer_id]["encampments_placed_this_turn"] = false
	players[peer_id]["diplomat_chosen_this_turn"] = false

	# Stout : disponible si la nation a ce pouvoir
	var nation: Nation = get_active_nation(peer_id)
	if nation and nation.special_power is PowerStout:
		players[peer_id]["stout_decline_available"] = true

	# Amazones : récupérer les 4 pions offensifs en début de tour
	if nation is Amazons and not nation.is_in_decline:
		nation.tokens_in_reserve += 4

# ─── Le joueur choisit son action ───────────────────────────────

func request_action(action: String) -> void:
	# action = "conquest" ou "decline"
	if multiplayer.is_server():
		_validate_action(1, action)
	else:
		_ask_action.rpc_id(1, action)

@rpc("any_peer", "reliable")
func _ask_action(action: String) -> void:
	if not multiplayer.is_server():
		return
	_validate_action(multiplayer.get_remote_sender_id(), action)

func _validate_action(peer_id: int, action: String) -> void:
	if peer_id != current_player_peer_id:
		return
	if turn_phase != Global.TurnPhase.CHOOSE_ACTION:
		return

	match action:
		"conquest":
			_begin_conquest_phase.rpc(peer_id)
		"decline":
			_begin_decline_phase.rpc(peer_id)
		_:
			push_warning("GameManager: action inconnue %s" % action)

@rpc("authority", "call_local", "reliable")
func _begin_conquest_phase(peer_id: int) -> void:
	turn_phase = Global.TurnPhase.CONQUEST
	emit_signal("turn_phase_changed", turn_phase)
	if multiplayer.is_server():
		ConquestManager.start_conquest_turn(peer_id)

@rpc("authority", "call_local", "reliable")
func _begin_decline_phase(peer_id: int) -> void:
	turn_phase = Global.TurnPhase.DECLINE
	emit_signal("turn_phase_changed", turn_phase)
	if multiplayer.is_server():
		DeclineManager.request_decline(peer_id)

# ─── Fin de conquête → redéploiement ────────────────────────────

func _on_conquest_phase_ended() -> void:
	if not multiplayer.is_server():
		return
	_begin_redeploy_phase.rpc(current_player_peer_id)

@rpc("authority", "call_local", "reliable")
func _begin_redeploy_phase(peer_id: int) -> void:
	turn_phase = Global.TurnPhase.REDEPLOY
	emit_signal("turn_phase_changed", turn_phase)

# ─── Fin de redéploiement → scoring ─────────────────────────────

func _on_redeploy_ended() -> void:
	if not multiplayer.is_server():
		return
	_handle_end_of_turn_powers(current_player_peer_id)

func _handle_end_of_turn_powers(peer_id: int) -> void:
	var nation: Nation = get_active_nation(peer_id)
	if nation == null:
		_begin_scoring_phase(peer_id)
		return
	
	# Bivouacking : placer les campements
	if nation.special_power is PowerBivouacking and \
	   not players[peer_id]["encampments_placed_this_turn"]:
		_request_encampment_placement.rpc(peer_id)
		return
	
	# Fortified : placer une forteresse
	if nation.special_power is PowerFortified and \
	   not players[peer_id]["fortress_placed_this_turn"]:
		_request_fortress_placement.rpc(peer_id)
		return

	# Heroic : placer les 2 héros
	if nation.special_power is PowerHeroic and \
	   not players[peer_id]["heroes_placed_this_turn"]:
		_request_hero_placement.rpc(peer_id)
		return

	# Diplomat : choisir un allié
	if nation.special_power is PowerDiplomat:
		_request_diplomat_choice.rpc(peer_id)
		return

	# Stout : proposer le déclin optionnel
	if players[peer_id]["stout_decline_available"]:
		_request_stout_choice.rpc(peer_id)
		return

	_begin_scoring_phase(peer_id)

func _begin_scoring_phase(peer_id: int) -> void:
	_start_scoring.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _start_scoring(peer_id: int) -> void:
	turn_phase = Global.TurnPhase.SCORING
	emit_signal("turn_phase_changed", turn_phase)
	if multiplayer.is_server():
		ScoringManager.calculate_score(peer_id)

# ─── Fin de déclin → scoring ─────────────────────────────────────

func _on_decline_completed(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_begin_scoring_phase(peer_id)

# ─── Fin de scoring → joueur suivant ────────────────────────────

func _on_scoring_completed(peer_id: int, _coins: int) -> void:
	if not multiplayer.is_server():
		return
	_advance_to_next_player()

func _advance_to_next_player() -> void:
	var current_index: int = player_order.find(current_player_peer_id)
	var next_index: int = (current_index + 1) % player_order.size()

	if next_index == 0:
		current_turn += 1
		if current_turn > max_turns:
			_end_game.rpc()
			return

	_begin_turn.rpc(player_order[next_index], current_turn)

# ═════════════════════════════════════════════════════════════════
# POUVOIRS DE FIN DE TOUR
# ═════════════════════════════════════════════════════════════════

# ─── Bivouacking ────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _request_encampment_placement(peer_id: int) -> void:
	# Signal pour que l'UI demande au joueur de placer ses 5 campements
	emit_signal("turn_phase_changed", Global.TurnPhase.REDEPLOY)

# ─── Fortified ──────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _request_fortress_placement(peer_id: int) -> void:
	# Signal pour que l'UI demande au joueur de choisir une région
	emit_signal("turn_phase_changed", Global.TurnPhase.REDEPLOY)

func request_place_fortress(region_path: NodePath) -> void:
	if multiplayer.is_server():
		_validate_fortress_placement(1, region_path)
	else:
		_ask_place_fortress.rpc_id(1, region_path)

@rpc("any_peer", "reliable")
func _ask_place_fortress(region_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_validate_fortress_placement(
		multiplayer.get_remote_sender_id(), region_path)

func _validate_fortress_placement(peer_id: int,
								   region_path: NodePath) -> void:
	if peer_id != current_player_peer_id:
		return
	if players[peer_id]["fortress_placed_this_turn"]:
		return

	var region: Node = get_node_or_null(region_path)
	if region == null or region.owner_peer_id != peer_id:
		push_warning("GameManager: forteresse — région invalide")
		return
	if region.has_fortress:
		push_warning("GameManager: forteresse déjà présente")
		return

	# Vérifier le maximum de 6 forteresses sur le plateau
	var fortress_count: int = _count_fortresses_on_board()
	if fortress_count >= 6:
		push_warning("GameManager: maximum de forteresses atteint")
		return

	players[peer_id]["fortress_placed_this_turn"] = true
	_apply_fortress_placement.rpc(peer_id, region_path)

func _count_fortresses_on_board() -> int:
	var count: int = 0
	for region in get_tree().get_nodes_in_group("regions"):
		if region.has_fortress:
			count += 1
	return count

@rpc("authority", "call_local", "reliable")
func _apply_fortress_placement(peer_id: int, region_path: NodePath) -> void:
	var region: Node = get_node_or_null(region_path)
	if region:
		region.has_fortress = true
	if multiplayer.is_server():
		_handle_end_of_turn_powers(peer_id)

# ─── Heroic ─────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _request_hero_placement(peer_id: int) -> void:
	emit_signal("turn_phase_changed", Global.TurnPhase.REDEPLOY)

func request_place_heroes(region_paths: Array) -> void:
	if multiplayer.is_server():
		_validate_hero_placement(1, region_paths)
	else:
		_ask_place_heroes.rpc_id(1, region_paths)

@rpc("any_peer", "reliable")
func _ask_place_heroes(region_paths: Array) -> void:
	if not multiplayer.is_server():
		return
	_validate_hero_placement(
		multiplayer.get_remote_sender_id(), region_paths)

func _validate_hero_placement(peer_id: int, region_paths: Array) -> void:
	if peer_id != current_player_peer_id:
		return
	if players[peer_id]["heroes_placed_this_turn"]:
		return
	if region_paths.size() != 2:
		push_warning("GameManager: 2 régions requises pour les héros")
		return

	# Vérifier que les deux régions appartiennent au joueur
	for path in region_paths:
		var region: Node = get_node_or_null(path)
		if region == null or region.owner_peer_id != peer_id:
			push_warning("GameManager: héros — région invalide")
			return

	# Vérifier que les deux régions sont différentes
	if region_paths[0] == region_paths[1]:
		push_warning("GameManager: les 2 régions doivent être différentes")
		return

	players[peer_id]["heroes_placed_this_turn"] = true

	# Retirer les anciens héros
	var nation: Nation = get_active_nation(peer_id)
	if nation and nation.special_power is PowerHeroic:
		var power: PowerHeroic = nation.special_power
		for old_region in power.hero_regions:
			old_region.has_hero = false
		power.hero_regions.clear()

	_apply_hero_placement.rpc(peer_id, region_paths)

@rpc("authority", "call_local", "reliable")
func _apply_hero_placement(peer_id: int, region_paths: Array) -> void:
	var nation: Nation = get_active_nation(peer_id)
	for path in region_paths:
		var region: Node = get_node_or_null(path)
		if region:
			region.has_hero = true
			if nation and nation.special_power is PowerHeroic:
				nation.special_power.hero_regions.append(region)
	if multiplayer.is_server():
		_handle_end_of_turn_powers(peer_id)

# ─── Diplomat ───────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _request_diplomat_choice(peer_id: int) -> void:
	emit_signal("turn_phase_changed", Global.TurnPhase.REDEPLOY)

func request_set_ally(target_peer_id: int) -> void:
	if multiplayer.is_server():
		_validate_diplomat_choice(1, target_peer_id)
	else:
		_ask_set_ally.rpc_id(1, target_peer_id)

@rpc("any_peer", "reliable")
func _ask_set_ally(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_validate_diplomat_choice(
		multiplayer.get_remote_sender_id(), target_peer_id)

func _validate_diplomat_choice(peer_id: int, target_peer_id: int) -> void:
	if peer_id != current_player_peer_id:
		return

	# Ne peut pas choisir quelqu'un qu'il a attaqué ce tour
	# ConquestManager track les régions conquises — à vérifier
	if target_peer_id == peer_id:
		push_warning("GameManager: ne peut pas s'allier à soi-même")
		return
	if not players.has(target_peer_id):
		push_warning("GameManager: joueur cible introuvable")
		return

	# Réinitialiser l'ancien accord de paix
	var old_ally: int = players[peer_id]["ally_peer_id"]
	if old_ally != -1 and players.has(old_ally):
		players[old_ally]["ally_peer_id"] = -1

	_apply_diplomat_choice.rpc(peer_id, target_peer_id)

@rpc("authority", "call_local", "reliable")
func _apply_diplomat_choice(peer_id: int, target_peer_id: int) -> void:
	players[peer_id]["ally_peer_id"] = target_peer_id
	players[target_peer_id]["ally_peer_id"] = peer_id
	if multiplayer.is_server():
		players[peer_id]["diplomat_chosen_this_turn"] = true
		_handle_end_of_turn_powers(peer_id)

# Vérifier si une conquête est bloquée par un accord diplomatique
func is_conquest_blocked_by_diplomat(attacker_id: int,
									  defender_id: int) -> bool:
	if not players.has(attacker_id) or not players.has(defender_id):
		return false
	return players[attacker_id]["ally_peer_id"] == defender_id

func request_skip_diplomat() -> void:
	if multiplayer.is_server():
		_validate_skip_diplomat(1)
	else:
		_ask_skip_diplomat.rpc_id(1)

@rpc("any_peer", "reliable")
func _ask_skip_diplomat() -> void:
	if not multiplayer.is_server():
		return
	_validate_skip_diplomat(multiplayer.get_remote_sender_id())

func _validate_skip_diplomat(peer_id: int) -> void:
	if peer_id != current_player_peer_id:
		return
	_apply_skip_diplomat.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _apply_skip_diplomat(peer_id: int) -> void:
	if multiplayer.is_server():
		players[peer_id]["diplomat_chosen_this_turn"] = true
		_handle_end_of_turn_powers(peer_id)

# ─── Stout ──────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _request_stout_choice(peer_id: int) -> void:
	# L'UI propose au joueur de décliner maintenant ou pas
	emit_signal("turn_phase_changed", Global.TurnPhase.REDEPLOY)

func request_stout_decision(decline_now: bool) -> void:
	if multiplayer.is_server():
		_validate_stout_decision(1, decline_now)
	else:
		_ask_stout_decision.rpc_id(1, decline_now)

@rpc("any_peer", "reliable")
func _ask_stout_decision(decline_now: bool) -> void:
	if not multiplayer.is_server():
		return
	_validate_stout_decision(
		multiplayer.get_remote_sender_id(), decline_now)

func _validate_stout_decision(peer_id: int, decline_now: bool) -> void:
	if peer_id != current_player_peer_id:
		return
	players[peer_id]["stout_decline_available"] = false
	if decline_now:
		DeclineManager.request_stout_decline(peer_id)
	else:
		if multiplayer.is_server():
			_handle_end_of_turn_powers(peer_id)

# ─── Dragon Master ───────────────────────────────────────────────

func request_move_dragon(region_path: NodePath) -> void:
	if multiplayer.is_server():
		_validate_dragon_move(1, region_path)
	else:
		_ask_move_dragon.rpc_id(1, region_path)

@rpc("any_peer", "reliable")
func _ask_move_dragon(region_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_validate_dragon_move(
		multiplayer.get_remote_sender_id(), region_path)

func _validate_dragon_move(peer_id: int, region_path: NodePath) -> void:
	if peer_id != current_player_peer_id:
		return
	if players[peer_id]["dragon_moved_this_turn"]:
		push_warning("GameManager: dragon déjà déplacé ce tour")
		return

	var nation: Nation = get_active_nation(peer_id)
	if nation == null or not nation.special_power is PowerDragonMaster:
		return

	var target: Node = get_node_or_null(region_path)
	if target == null:
		return

	var power: PowerDragonMaster = nation.special_power

	# Retirer le dragon de l'ancienne région
	if power.dragon_region != null:
		power.dragon_region.has_dragon = false

	# Le dragon conquiert la nouvelle région avec 1 seul pion
	# Déléguer à ConquestManager avec coût forcé à 1
	players[peer_id]["dragon_moved_this_turn"] = true
	ConquestManager._apply_conquest(peer_id, nation, target, 1)
	power.dragon_region = target
	target.has_dragon = true

	_sync_dragon_move.rpc(peer_id, region_path)

@rpc("authority", "call_local", "reliable")
func _sync_dragon_move(peer_id: int, region_path: NodePath) -> void:
	var region: Node = get_node_or_null(region_path)
	if region:
		region.has_dragon = true

# ═════════════════════════════════════════════════════════════════
# FIN DE PARTIE
# ═════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func _end_game() -> void:
	game_state = Global.GameState.END
	emit_signal("game_state_changed", game_state)
	if multiplayer.is_server():
		ScoringManager.calculate_final_scores()

# ═════════════════════════════════════════════════════════════════
# UTILITAIRES
# ═════════════════════════════════════════════════════════════════

func get_active_nation(peer_id: int) -> Nation:
	if not players.has(peer_id):
		return null
	return players[peer_id]["active_nation"]

func get_player_coins(peer_id: int) -> int:
	if not players.has(peer_id):
		return 0
	return players[peer_id]["victory_coins"]

func is_current_player_local() -> bool:
	return current_player_peer_id == multiplayer.get_unique_id()

func request_current_player() -> void:
	if current_player_peer_id == 0:
		return
	emit_signal("current_player_changed",
				players[current_player_peer_id]["name"])
