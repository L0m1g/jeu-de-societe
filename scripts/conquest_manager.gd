# conquest_manager.gd
extends Node

# ─── État de la conquête en cours ────────────────────────────────
var _conquests_this_turn: int = 0
var _non_empty_conquered_this_turn: int = 0
var _final_attempt_done: bool = false
var _is_first_conquest: bool = true  # Première conquête de la nation sur le plateau

# Résultat du dé de renfort (0 = pas encore lancé ce tour)
var _reinforcement_die_result: int = 0

# Région ciblée pour la dernière tentative (sélectionnée AVANT le dé)
var _final_target_region: Node = null

# ─── Signaux ─────────────────────────────────────────────────────
signal conquest_completed(peer_id: int, region: Node)
signal conquest_failed(peer_id: int, region: Node)
signal conquest_phase_ended
signal reinforcement_die_rolled(result: int)
signal redeploy_phase_started
signal redeploy_ended

# ═════════════════════════════════════════════════════════════════
# DÉMARRAGE D'UN TOUR DE CONQUÊTE
# ═════════════════════════════════════════════════════════════════

func start_conquest_turn(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_conquests_this_turn = 0
	_non_empty_conquered_this_turn = 0
	_final_attempt_done = false
	_reinforcement_die_result = 0
	_final_target_region = null

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	# Première conquête si la nation n'a pas encore de régions
	_is_first_conquest = nation.owned_regions.is_empty()

	# Ghouls en déclin : conquêtes avant la nation active
	if GameManager.players[peer_id]["decline_nation"] is Ghouls:
		_start_ghoul_conquests.rpc(peer_id)
		return

	_sync_conquest_state.rpc(peer_id, _is_first_conquest)

@rpc("authority", "call_local", "reliable")
func _sync_conquest_state(peer_id: int, is_first: bool) -> void:
	_is_first_conquest = is_first
	GameManager.emit_signal("turn_phase_changed", Global.TurnPhase.CONQUEST)

@rpc("authority", "call_local", "reliable")
func _start_ghoul_conquests(peer_id: int) -> void:
	# Signal pour que l'UI indique que les Ghouls en déclin jouent d'abord
	GameManager.emit_signal("turn_phase_changed", Global.TurnPhase.CONQUEST)

# ═════════════════════════════════════════════════════════════════
# VALIDATION D'UNE CONQUÊTE
# ═════════════════════════════════════════════════════════════════

func request_conquest(region_path: NodePath) -> void:
	if multiplayer.is_server():
		_validate_conquest(1, region_path)
	else:
		_ask_conquest.rpc_id(1, region_path)

@rpc("any_peer", "reliable")
func _ask_conquest(region_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_validate_conquest(multiplayer.get_remote_sender_id(), region_path)

func _validate_conquest(peer_id: int, region_path: NodePath) -> void:
	if peer_id != GameManager.current_player_peer_id:
		push_warning("ConquestManager: pas le tour de %s" % peer_id)
		return

	var region: Node = get_node_or_null(region_path)
	if region == null:
		push_warning("ConquestManager: région introuvable %s" % region_path)
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	# ── Vérification : région conquérable ──
	if not _can_target_region(peer_id, nation, region):
		push_warning("ConquestManager: région non ciblable")
		return

	# ── Vérification : région imprenable ──
	if region.is_immune_to_conquest():
		push_warning("ConquestManager: région imprenable")
		return
	
	# ── Vérification : accord diplomatique ──
	if region.owner_peer_id != -1:
		if GameManager.is_conquest_blocked_by_diplomat(peer_id, region.owner_peer_id):
			push_warning("ConquestManager: conquête bloquée par accord diplomatique")
			return

	# ── Calcul du coût ──
	var cost: int = _calculate_conquest_cost(nation, region)
	var available: int = nation.tokens_in_reserve

	# ── Cas normale : assez de pions ──
	if available >= cost:
		_apply_conquest(peer_id, nation, region, cost)
		return

	# ── Tentative finale avec dé ──
	# Le joueur doit avoir au moins 1 pion
	# La région ne doit pas demander plus de 3 pions de plus que disponible
	if available >= 1 and not _final_attempt_done:
		var shortfall: int = cost - available
		if shortfall <= 3:
			# Le joueur a sélectionné la région → on attend le lancer du dé
			_final_target_region = region
			_request_reinforcement_die.rpc(peer_id, region_path, cost)
			return

	push_warning("ConquestManager: pas assez de pions")

# ═════════════════════════════════════════════════════════════════
# CALCUL DU COÛT D'UNE CONQUÊTE
# ═════════════════════════════════════════════════════════════════

func _calculate_conquest_cost(nation: Nation, region: Node) -> int:
	var base_cost: int = region.get_conquest_cost()

	# Modificateur de la nation (Giants, Tritons...)
	var modifier: int = nation.get_conquest_cost_modifier(region)

	# Pour les Berserks : le dé est lancé avant, le résultat est déjà connu
	if nation.special_power is PowerBerserk and _reinforcement_die_result > 0:
		modifier -= _reinforcement_die_result
		_reinforcement_die_result = 0

	return max(1, base_cost + modifier)

# ═════════════════════════════════════════════════════════════════
# VÉRIFICATION D'ADJACENCE ET DE CIBLAGE
# ═════════════════════════════════════════════════════════════════

func _can_target_region(peer_id: int, nation: Nation, region: Node) -> bool:
	# Mers et lacs non conquérables sauf Seafaring
	if region.region_type == Global.RegionType.SEA or \
	   region.region_type == Global.RegionType.LAKE:
		if not nation.special_power is PowerSeafaring:
			return false

	# Première conquête : doit être une région de bordure
	# Sauf Halflings qui peuvent entrer n'importe où
	if _is_first_conquest:
		if not nation is Halflings and not region.is_border:
			return false
		return true

	# Flying : peut conquérir n'importe quelle région
	if nation.special_power is PowerFlying:
		return true

	# Underworld : les régions avec caverne sont adjacentes entre elles
	if nation.special_power is PowerUnderworld and region.has_cave:
		for owned in nation.owned_regions:
			if owned.has_cave:
				return true

	# Cas normal : doit être adjacente à une région occupée
	return _is_adjacent_to_owned(nation, region)

func _is_adjacent_to_owned(nation: Nation, region: Node) -> bool:
	for owned_region in nation.owned_regions:
		for adjacent in owned_region.get_adjacent_region_nodes():
			if adjacent == region:
				return true
	return false

# Retourne toutes les régions ciblables pour la nation courante
func get_targetable_regions(peer_id: int) -> Array:
	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return []

	var all_regions: Array = get_tree().get_nodes_in_group("regions")
	var targetable: Array = []

	for region in all_regions:
		if region.owner_peer_id == peer_id:
			continue  # Ne peut pas s'attaquer soi-même (sauf déclin)
		if region.is_immune_to_conquest():
			continue
		if _can_target_region(peer_id, nation, region):
			targetable.append(region)

	return targetable

# ═════════════════════════════════════════════════════════════════
# APPLICATION D'UNE CONQUÊTE
# ═════════════════════════════════════════════════════════════════

func _apply_conquest(peer_id: int, nation: Nation, region: Node, cost: int) -> void:
	var previous_owner_id: int = region.owner_peer_id

	# ── Pertes ennemies ──
	if previous_owner_id != -1:
		_apply_enemy_losses(previous_owner_id, region, nation)

	# ── Retrait des Tribus oubliées ──
	if region.lost_tribe:
		region.lost_tribe = false

	# ── Placement des pions du conquérant ──
	nation.tokens_in_reserve -= cost
	region.owner_peer_id = peer_id
	region.owner_nation = nation
	region.token_count = cost
	nation.owned_regions.append(region)

	# ── Effets de la nation sur la conquête ──
	nation.on_conquest(region)

	# ── Compteurs ──
	_conquests_this_turn += 1
	if region.is_occupied():
		_non_empty_conquered_this_turn += 1

	# ── Première conquête résolue ──
	_is_first_conquest = false
	_final_attempt_done = false
	_final_target_region = null

	# ── Synchronisation ──
	_sync_conquest_result.rpc(
		peer_id,
		region.get_path(),
		cost,
		previous_owner_id,
		nation.tokens_in_reserve
	)

@rpc("authority", "call_local", "reliable")
func _sync_conquest_result(peer_id: int, region_path: NodePath,
							tokens_placed: int, previous_owner_id: int,
							tokens_remaining: int) -> void:
	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	region.owner_peer_id = peer_id
	region.token_count = tokens_placed

	if GameManager.players.has(peer_id):
		var nation: Nation = GameManager.get_active_nation(peer_id)
		if nation:
			nation.tokens_in_reserve = tokens_remaining
	
	region.refresh_display()
	emit_signal("conquest_completed", peer_id, region)

# ═════════════════════════════════════════════════════════════════
# PERTES ENNEMIES
# ═════════════════════════════════════════════════════════════════

func _apply_enemy_losses(enemy_peer_id: int, region: Node, attacker_nation: Nation) -> void:
	var enemy_nation: Nation = GameManager.get_active_nation(enemy_peer_id)
	if enemy_nation == null:
		return

	var tokens_in_region: int = region.token_count
	var tokens_lost: int = enemy_nation.on_region_lost(region)

	# Retirer la région des possessions ennemies
	enemy_nation.owned_regions.erase(region)

	# Pions perdus définitivement (1 sauf Elfes qui perdent 0)
	# Les autres pions retournent en main
	var tokens_returned: int = tokens_in_region - tokens_lost
	enemy_nation.tokens_in_reserve += tokens_returned

	# Sorciers : si l'attaquant est un Sorcier qui convertit
	# (géré séparément via request_sorcerer_conversion)

	_sync_enemy_losses.rpc(
		enemy_peer_id,
		region.get_path(),
		tokens_lost,
		tokens_returned
	)

@rpc("authority", "call_local", "reliable")
func _sync_enemy_losses(enemy_peer_id: int, region_path: NodePath,
						 tokens_lost: int, tokens_returned: int) -> void:
	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	if GameManager.players.has(enemy_peer_id):
		var nation: Nation = GameManager.get_active_nation(enemy_peer_id)
		if nation:
			nation.tokens_in_reserve += tokens_returned
	
	region.refresh_display()

# ═════════════════════════════════════════════════════════════════
# DÉ DE RENFORT
# ═════════════════════════════════════════════════════════════════

# Berserk : lancer le dé AVANT de choisir la région
func request_berserk_die(peer_id: int) -> void:
	if not multiplayer.is_server():
		_ask_berserk_die.rpc_id(1)
		return
	_roll_berserk_die(peer_id)

@rpc("any_peer", "reliable")
func _ask_berserk_die() -> void:
	if not multiplayer.is_server():
		return
	_roll_berserk_die(multiplayer.get_remote_sender_id())

func _roll_berserk_die(peer_id: int) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return
	var result: int = _roll_reinforcement_die()
	_reinforcement_die_result = result
	_broadcast_die_result.rpc(result)

# Tentative finale : la région est choisie AVANT de lancer le dé
@rpc("authority", "call_local", "reliable")
func _request_reinforcement_die(peer_id: int, region_path: NodePath, cost: int) -> void:
	# Informer le client qu'il doit lancer le dé
	# Le lancer est fait par le host pour éviter la triche
	if not multiplayer.is_server():
		return
	var result: int = _roll_reinforcement_die()
	_apply_final_attempt(peer_id, region_path, cost, result)

func _apply_final_attempt(peer_id: int, region_path: NodePath,
						   cost: int, die_result: int) -> void:
	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	var available: int = nation.tokens_in_reserve
	_final_attempt_done = true

	_broadcast_die_result.rpc(die_result)

	if available + die_result >= cost:
		# Conquête réussie — on place tous les pions restants
		_apply_conquest(peer_id, nation, region, available)
	else:
		# Echec — les pions restants sont redéployés dans une région occupée
		_sync_final_attempt_failed.rpc(peer_id, region_path)

@rpc("authority", "call_local", "reliable")
func _broadcast_die_result(result: int) -> void:
	_reinforcement_die_result = result
	emit_signal("reinforcement_die_rolled", result)

@rpc("authority", "call_local", "reliable")
func _sync_final_attempt_failed(peer_id: int, region_path: NodePath) -> void:
	var region: Node = get_node_or_null(region_path)
	emit_signal("conquest_failed", peer_id, region)
	# L'UI demande au joueur de redéployer ses pions restants
	emit_signal("redeploy_phase_started")

func _roll_reinforcement_die() -> int:
	# Faces du dé de renfort Small World : 0, 0, 0, 1, 2, 3
	var faces: Array = [0, 0, 0, 1, 2, 3]
	return faces[randi() % faces.size()]

# ═════════════════════════════════════════════════════════════════
# CAPACITÉ SPÉCIALE SORCIERS
# ═════════════════════════════════════════════════════════════════

func request_sorcerer_conversion(target_region_path: NodePath) -> void:
	if multiplayer.is_server():
		_validate_sorcerer_conversion(1, target_region_path)
	else:
		_ask_sorcerer_conversion.rpc_id(1, target_region_path)

@rpc("any_peer", "reliable")
func _ask_sorcerer_conversion(target_region_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_validate_sorcerer_conversion(
		multiplayer.get_remote_sender_id(), target_region_path)

func _validate_sorcerer_conversion(peer_id: int,
									target_region_path: NodePath) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if not nation is Sorcerers:
		return

	var target: Node = get_node_or_null(target_region_path)
	if target == null:
		return

	var enemy_peer_id: int = target.owner_peer_id
	if enemy_peer_id == -1 or enemy_peer_id == peer_id:
		push_warning("ConquestManager: cible invalide pour Sorcier")
		return

	# Déjà utilisé contre cet adversaire ce tour
	if enemy_peer_id in GameManager.players[peer_id]["sorcerer_used_against"]:
		push_warning("ConquestManager: Sorcier déjà utilisé contre ce joueur")
		return

	# La région doit contenir exactement 1 pion actif ennemi
	if target.token_count != 1:
		push_warning("ConquestManager: la région doit avoir exactement 1 pion")
		return

	# La région doit être adjacente à une région des Sorciers
	if not _is_adjacent_to_owned(nation, target):
		push_warning("ConquestManager: région non adjacente aux Sorciers")
		return

	# Vérifier qu'il reste des pions Sorciers dans la réserve
	if nation.tokens_in_reserve <= 0:
		push_warning("ConquestManager: plus de pions Sorciers disponibles")
		return

	_apply_sorcerer_conversion(peer_id, enemy_peer_id, target, nation)

func _apply_sorcerer_conversion(peer_id: int, enemy_peer_id: int,
								 region: Node, nation: Nation) -> void:
	var enemy_nation: Nation = GameManager.get_active_nation(enemy_peer_id)
	if enemy_nation == null:
		return

	# Le pion ennemi est défaussé (même un Elfe perd son pion ici)
	enemy_nation.owned_regions.erase(region)
	# Pas de pion retourné en main pour la cible (défaussé définitivement)

	# Placer 1 pion Sorcier dans la région
	nation.tokens_in_reserve -= 1
	region.owner_peer_id = peer_id
	region.owner_nation = nation
	region.token_count = 1
	nation.owned_regions.append(region)

	GameManager.players[peer_id]["sorcerer_used_against"].append(enemy_peer_id)

	_sync_sorcerer_conversion.rpc(
		peer_id,
		enemy_peer_id,
		region.get_path(),
		nation.tokens_in_reserve
	)

@rpc("authority", "call_local", "reliable")
func _sync_sorcerer_conversion(peer_id: int, enemy_peer_id: int,
								region_path: NodePath,
								tokens_remaining: int) -> void:
	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	region.owner_peer_id = peer_id
	region.token_count = 1

	if GameManager.players.has(peer_id):
		var nation: Nation = GameManager.get_active_nation(peer_id)
		if nation:
			nation.tokens_in_reserve = tokens_remaining

	emit_signal("conquest_completed", peer_id, region)

# ═════════════════════════════════════════════════════════════════
# FIN DE PHASE DE CONQUÊTE
# ═════════════════════════════════════════════════════════════════

# Appelé quand le joueur décide d'arrêter de conquérir
func request_end_conquest(peer_id: int) -> void:
	if multiplayer.is_server():
		_end_conquest_phase(peer_id)
	else:
		_ask_end_conquest.rpc_id(1)

@rpc("any_peer", "reliable")
func _ask_end_conquest() -> void:
	if not multiplayer.is_server():
		return
	_end_conquest_phase(multiplayer.get_remote_sender_id())

func _end_conquest_phase(peer_id: int) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	# Remettre le compteur des Sorciers à zéro
	GameManager.players[peer_id]["sorcerer_used_against"].clear()

	# Effets de fin de conquête (Orcs, Skeletons compteurs)
	# déjà trackés dans on_conquest

	_broadcast_end_conquest.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _broadcast_end_conquest(peer_id: int) -> void:
	emit_signal("conquest_phase_ended")

# ═════════════════════════════════════════════════════════════════
# REDÉPLOIEMENT
# ═════════════════════════════════════════════════════════════════

func request_redeploy(peer_id: int, redeployment: Dictionary) -> void:
	# redeployment = { region_path: tokens_to_place }
	if multiplayer.is_server():
		_validate_redeploy(peer_id, redeployment)
	else:
		_ask_redeploy.rpc_id(1, redeployment)

@rpc("any_peer", "reliable")
func _ask_redeploy(redeployment: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_validate_redeploy(multiplayer.get_remote_sender_id(), redeployment)

func _validate_redeploy(peer_id: int, redeployment: Dictionary) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	# Vérifier qu'il y a au moins 1 pion par région occupée
	for region_path in redeployment.keys():
		var region: Node = get_node_or_null(region_path)
		if region == null:
			continue
		if redeployment[region_path] < 1:
			push_warning("ConquestManager: minimum 1 pion par région")
			return

	# Vérifier que le total de pions correspond
	var total_deployed: int = 0
	for count in redeployment.values():
		total_deployed += count

	var available: int = nation.tokens_in_reserve + _get_tokens_on_board(nation)
	if total_deployed > available:
		push_warning("ConquestManager: trop de pions déployés")
		return

	_apply_redeploy(peer_id, nation, redeployment)

func _apply_redeploy(peer_id: int, nation: Nation,
					  redeployment: Dictionary) -> void:
	# Appliquer les effets de redéploiement de la nation
	nation.on_redeploy(nation.owned_regions)

	# Amazones : retirer 4 pions après redéploiement
	if nation is Amazons:
		var removed: int = 0
		for region_path in redeployment.keys():
			if removed >= 4:
				break
			var region: Node = get_node_or_null(region_path)
			if region and redeployment[region_path] > 1:
				var to_remove: int = min(redeployment[region_path] - 1,
										 4 - removed)
				redeployment[region_path] -= to_remove
				removed += to_remove

	# Bivouacking : placer les campements
	if nation.special_power is PowerBivouacking:
		# Géré séparément via request_place_encampments
		pass

	_sync_redeploy.rpc(peer_id, redeployment)

@rpc("authority", "call_local", "reliable")
func _sync_redeploy(peer_id: int, redeployment: Dictionary) -> void:
	for region_path in redeployment.keys():
		var region: Node = get_node_or_null(region_path)
		if region:
			region.token_count = redeployment[region_path]
			region.refresh_display()
	emit_signal("redeploy_ended")

func request_place_encampments(placements: Dictionary) -> void:
	# placements = { region_path: encampment_count }
	if multiplayer.is_server():
		_validate_encampments(1, placements)
	else:
		_ask_place_encampments.rpc_id(1, placements)

@rpc("any_peer", "reliable")
func _ask_place_encampments(placements: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_validate_encampments(multiplayer.get_remote_sender_id(), placements)

func _validate_encampments(peer_id: int, placements: Dictionary) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return
	
	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null or not nation.special_power is PowerBivouacking:
		return

	# Vérifier total de campements = 5
	var total: int = 0
	for count in placements.values():
		total += count
	if total != PowerBivouacking.ENCAMPMENT_COUNT:
		push_warning("ConquestManager: total campements invalide")
		return

	# Vérifier que toutes les régions appartiennent au joueur
	for path in placements.keys():
		var region: Node = get_node_or_null(path)
		if region == null or region.owner_peer_id != peer_id:
			push_warning("ConquestManager: campement — région invalide")
			return
	
	_apply_encampments.rpc(peer_id, placements)

@rpc("authority", "call_local", "reliable")
func _apply_encampments(peer_id: int, placements: Dictionary) -> void:
	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null or not nation.special_power is PowerBivouacking:
		return
	
	var power: PowerBivouacking = nation.special_power

	# Retirer les anciens campements
	for region in power.encampment_regions:
		region.has_encampment = false
		region.encampment_count = 0
	power.encampment_regions.clear()

	# Placer les nouveaux
	for path in placements.keys():
		var region: Node = get_node_or_null(path)
		if region:
			region.has_encampment = true
			region.encampment_count = placements[path]
			power.encampment_regions.append(region)
	
	# Signaler à GameManager de continuer le flux des pouvoirs
	if multiplayer.is_server():
		GameManager.players[peer_id]["encampments_placed_this_turn"] = true
		GameManager._handle_end_of_turn_powers(peer_id)

# ═════════════════════════════════════════════════════════════════
# UTILITAIRES
# ═════════════════════════════════════════════════════════════════

func _get_tokens_on_board(nation: Nation) -> int:
	var total: int = 0
	for region in nation.owned_regions:
		total += region.token_count
	return total

func get_conquest_cost_for_display(peer_id: int, region: Node) -> int:
	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return 0
	return _calculate_conquest_cost(nation, region)
