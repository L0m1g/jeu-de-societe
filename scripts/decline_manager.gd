# decline_manager.gd
extends Node

# ─── Signaux ─────────────────────────────────────────────────────
signal decline_completed(peer_id: int)
signal decline_requested(peer_id: int)

# ═════════════════════════════════════════════════════════════════
# DEMANDE DE PASSAGE EN DÉCLIN
# ═════════════════════════════════════════════════════════════════

# Appelé depuis l'interface quand le joueur choisit de décliner
func request_decline(peer_id: int) -> void:
	if multiplayer.is_server():
		_validate_decline(peer_id)
	else:
		_ask_decline.rpc_id(1)

@rpc("any_peer", "reliable")
func _ask_decline() -> void:
	if not multiplayer.is_server():
		return
	_validate_decline(multiplayer.get_remote_sender_id())

func _validate_decline(peer_id: int) -> void:
	if peer_id != GameManager.current_player_peer_id:
		push_warning("DeclineManager: pas le tour de %s" % peer_id)
		return

	var active_nation: Nation = GameManager.get_active_nation(peer_id)
	if active_nation == null:
		push_warning("DeclineManager: pas de nation active")
		return

	# Ne peut pas décliner si déjà en train de décliner ce tour
	if active_nation.is_in_decline:
		push_warning("DeclineManager: nation déjà en déclin")
		return

	_apply_decline(peer_id, active_nation)

# ═════════════════════════════════════════════════════════════════
# APPLICATION DU DÉCLIN
# ═════════════════════════════════════════════════════════════════

func _apply_decline(peer_id: int, nation: Nation) -> void:
	# ── Supprimer l'ancien déclin ──
	# Sauf si c'est un Spirit — il reste sur le plateau indéfiniment
	_remove_previous_decline(peer_id)

	# ── Ghouls : tous les pions restent sur le plateau ──
	if nation is Ghouls:
		_apply_ghoul_decline(peer_id, nation)
	else:
		_apply_standard_decline(peer_id, nation)

	# ── Notifier la nation de son passage en déclin ──
	# Défausse le pouvoir spécial sauf Spirit
	nation.on_decline()

	# ── Déplacer vers decline_nation ──
	GameManager.players[peer_id]["decline_nation"] = nation
	GameManager.players[peer_id]["active_nation"] = null
	GameManager.players[peer_id]["has_nation"] = false

	# ── Synchronisation ──
	_broadcast_decline.rpc(peer_id, _build_decline_state(peer_id, nation))

# ─── Suppression de l'ancien déclin ─────────────────────────────

func _remove_previous_decline(peer_id: int) -> void:
	var previous_decline: Nation = GameManager.players[peer_id]["decline_nation"]
	if previous_decline == null:
		return

	# Spirit : ne quitte jamais le plateau sauf s'il est conquis
	if previous_decline.special_power is PowerSpirit:
		return

	# Retirer tous les pions en déclin du plateau
	for region in previous_decline.decline_regions:
		region.decline_nation = null
		region.decline_token_count = 0

	previous_decline.decline_regions.clear()

	# Remettre la tuile sous la pile
	_return_nation_to_pool(previous_decline)

	_sync_remove_decline.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_remove_decline(peer_id: int) -> void:
	var previous: Nation = GameManager.players[peer_id]["decline_nation"]
	if previous == null:
		return
	for region in previous.decline_regions:
		region.decline_nation = null
		region.decline_token_count = 0
		region.refresh_display()
	previous.decline_regions.clear()

# ─── Déclin standard ────────────────────────────────────────────

func _apply_standard_decline(peer_id: int, nation: Nation) -> void:
	# Laisser 1 pion par région occupée, retourné côté déclin
	# Retirer tous les autres pions
	for region in nation.owned_regions:
		region.decline_nation = nation
		region.decline_token_count = 1
		region.owner_peer_id = -1
		region.owner_nation = null
		region.token_count = 0
		nation.decline_regions.append(region)

	# Vider les régions actives
	nation.owned_regions.clear()
	nation.tokens_in_reserve = 0

	# Retirer les éléments liés au pouvoir spécial actif
	_cleanup_active_power_elements(nation)

# ─── Déclin Ghouls ──────────────────────────────────────────────

func _apply_ghoul_decline(peer_id: int, nation: Ghouls) -> void:
	# TOUS les pions restent sur le plateau (pas seulement 1 par région)
	for region in nation.owned_regions:
		region.decline_nation = nation
		region.decline_token_count = region.token_count
		region.owner_peer_id = -1
		region.owner_nation = null
		region.token_count = 0
		nation.decline_regions.append(region)

	nation.owned_regions.clear()
	nation.tokens_in_reserve = 0

# ─── Nettoyage des éléments du pouvoir actif ────────────────────

func _cleanup_active_power_elements(nation: Nation) -> void:
	if nation.special_power == null:
		return

	# Dragon Master : retirer le dragon
	if nation.special_power is PowerDragonMaster:
		var power: PowerDragonMaster = nation.special_power
		if power.dragon_region != null:
			power.dragon_region.has_dragon = false
			power.dragon_region = null

	# Heroic : retirer les héros
	if nation.special_power is PowerHeroic:
		var power: PowerHeroic = nation.special_power
		for region in power.hero_regions:
			region.has_hero = false
		power.hero_regions.clear()

	# Halflings : retirer les tanières si déclin
	if nation is Halflings:
		for region in nation.decline_regions:
			region.has_hole_in_ground = false

	# Bivouacking : retirer les campements
	if nation.special_power is PowerBivouacking:
		var power: PowerBivouacking = nation.special_power
		for region in power.encampment_regions:
			region.has_encampment = false
			region.encampment_count = 0
		power.encampment_regions.clear()

	# Stout : permet de décliner après un tour normal
	# Géré dans GameManager, pas de nettoyage nécessaire

# ─── Cas Spirit : deux déclins simultanés ───────────────────────

func _handle_spirit_decline(peer_id: int, new_nation: Nation) -> void:
	# Avec Spirit, l'ancien déclin reste sur le plateau
	# Le nouveau déclin s'ajoute en plus
	# Si un 3ème déclin arrive plus tard :
	#   - le Spirit reste
	#   - l'autre déclin disparaît normalement
	# Logique déjà gérée dans _remove_previous_decline
	# via la vérification PowerSpirit
	pass

# ═════════════════════════════════════════════════════════════════
# NATION ÉLIMINÉE DU PLATEAU
# ═════════════════════════════════════════════════════════════════

# Appelé quand la dernière région d'une nation en déclin est conquise
func on_decline_nation_eliminated(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var decline_nation: Nation = GameManager.players[peer_id]["decline_nation"]
	if decline_nation == null:
		return

	decline_nation.decline_regions.clear()
	_return_nation_to_pool(decline_nation)
	GameManager.players[peer_id]["decline_nation"] = null

	_sync_decline_eliminated.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_decline_eliminated(peer_id: int) -> void:
	var decline: Nation = GameManager.players[peer_id]["decline_nation"]
	if decline:
		decline.decline_regions.clear()
	GameManager.players[peer_id]["decline_nation"] = null

# ═════════════════════════════════════════════════════════════════
# RETOUR AU POOL
# ═════════════════════════════════════════════════════════════════

func _return_nation_to_pool(nation: Nation) -> void:
	# Réinitialiser l'état de la nation avant de la remettre dans le pool
	nation.is_in_decline = false
	nation.owned_regions.clear()
	nation.decline_regions.clear()
	nation.tokens_in_reserve = 0
	nation.special_power = null
	# Signaler au DraftManager qu'une nation est disponible
	DraftManager.return_nation_to_pool(nation)

# ═════════════════════════════════════════════════════════════════
# SYNCHRONISATION
# ═════════════════════════════════════════════════════════════════

func _build_decline_state(peer_id: int, nation: Nation) -> Dictionary:
	var decline_regions_paths: Array = []
	for region in nation.decline_regions:
		decline_regions_paths.append({
			"path": region.get_path(),
			"tokens": region.decline_token_count
		})

	return {
		"peer_id": peer_id,
		"nation_key": nation.key,
		"decline_regions": decline_regions_paths
	}

@rpc("authority", "call_local", "reliable")
func _broadcast_decline(peer_id: int, state: Dictionary) -> void:
	# Mettre à jour les régions localement sur tous les clients
	for region_data in state["decline_regions"]:
		var region: Node = get_node_or_null(region_data["path"])
		if region:
			region.owner_peer_id = -1
			region.owner_nation = null
			region.token_count = 0
			region.decline_token_count = region_data["tokens"]
			region.refresh_display()

	GameManager.emit_signal("turn_phase_changed", Global.TurnPhase.SCORING)
	emit_signal("decline_completed", peer_id)

# ═════════════════════════════════════════════════════════════════
# STOUT : DÉCLIN EN FIN DE TOUR NORMAL
# ═════════════════════════════════════════════════════════════════

# Le joueur avec Stout peut décliner après scoring sans perdre son tour
func request_stout_decline(peer_id: int) -> void:
	if not multiplayer.is_server():
		_ask_stout_decline.rpc_id(1)
		return
	_validate_stout_decline(peer_id)

@rpc("any_peer", "reliable")
func _ask_stout_decline() -> void:
	if not multiplayer.is_server():
		return
	_validate_stout_decline(multiplayer.get_remote_sender_id())

func _validate_stout_decline(peer_id: int) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return

	var nation: Nation = GameManager.get_active_nation(peer_id)
	if nation == null:
		return

	if not nation.special_power is PowerStout:
		push_warning("DeclineManager: Stout requis pour ce déclin")
		return

	# Appliquer le déclin sans fin de tour supplémentaire
	_apply_decline(peer_id, nation)

# ═════════════════════════════════════════════════════════════════
# GHOULS EN DÉCLIN — CONQUÊTES
# ═════════════════════════════════════════════════════════════════

# Les Ghouls en déclin conquièrent avant la nation active
func request_ghoul_conquest(region_path: NodePath) -> void:
	if multiplayer.is_server():
		_validate_ghoul_conquest(1, region_path)
	else:
		_ask_ghoul_conquest.rpc_id(1, region_path)

@rpc("any_peer", "reliable")
func _ask_ghoul_conquest(region_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_validate_ghoul_conquest(
		multiplayer.get_remote_sender_id(), region_path)

func _validate_ghoul_conquest(peer_id: int, region_path: NodePath) -> void:
	if peer_id != GameManager.current_player_peer_id:
		return

	var decline_nation: Nation = GameManager.players[peer_id]["decline_nation"]
	if not decline_nation is Ghouls:
		return

	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	if region.is_immune_to_conquest():
		push_warning("DeclineManager: région imprenable pour les Ghouls")
		return

	# Les Ghouls se comportent exactement comme une nation active
	# Déléguer à ConquestManager avec la nation en déclin
	var cost: int = region.get_conquest_cost()

	if decline_nation.tokens_in_reserve < cost:
		push_warning("DeclineManager: pas assez de pions Ghouls")
		return

	_apply_ghoul_conquest(peer_id, decline_nation, region, cost)

func _apply_ghoul_conquest(peer_id: int, ghouls: Nation,
							region: Node, cost: int) -> void:
	var previous_owner: int = region.owner_peer_id

	if previous_owner != -1:
		ConquestManager._apply_enemy_losses(previous_owner, region, ghouls)

	if region.lost_tribe:
		region.lost_tribe = false

	ghouls.tokens_in_reserve -= cost
	region.decline_nation = ghouls
	region.decline_token_count = cost
	region.owner_peer_id = -1
	region.owner_nation = null
	ghouls.decline_regions.append(region)

	_sync_ghoul_conquest.rpc(peer_id, region.get_path(), cost,
							  ghouls.tokens_in_reserve)

@rpc("authority", "call_local", "reliable")
func _sync_ghoul_conquest(peer_id: int, region_path: NodePath,
						   tokens_placed: int,
						   tokens_remaining: int) -> void:
	var region: Node = get_node_or_null(region_path)
	if region == null:
		return

	region.decline_token_count = tokens_placed

	var decline: Nation = GameManager.players[peer_id]["decline_nation"]
	if decline:
		decline.tokens_in_reserve = tokens_remaining
	
	region.refresh_display()
	ConquestManager.emit_signal("conquest_completed", peer_id, region)
