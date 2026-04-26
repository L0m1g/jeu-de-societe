# draft_manager.gd
extends Node

# ─── Pools ───────────────────────────────────────────────────────
var _nations_pool: Array = []
var _powers_pool: Array = []
var _discarded_powers: Array = []

# ─── Colonne affichée ────────────────────────────────────────────
# Array de Dictionary :
# { "nation": Nation, "power": SpecialPower, "coins": int }
var _displayed_combos: Array = []

# ─── Signaux ─────────────────────────────────────────────────────
signal displayed_combos_updated(combo_keys: Array)
signal combo_picked(peer_id: int, nation_key: String, power_key: String)
signal all_nations_picked

# ═════════════════════════════════════════════════════════════════
# SETUP
# ═════════════════════════════════════════════════════════════════

func setup_draft() -> void:
	if not multiplayer.is_server():
		return

	_nations_pool = [
		Amazons.new(), Dwarves.new(), Elves.new(), Ghouls.new(),
		Giants.new(), Halflings.new(), Humans.new(), Orcs.new(),
		Ratmen.new(), Skeletons.new(), Sorcerers.new(), Tritons.new(),
		Trolls.new(), Wizards.new()
	]
	_powers_pool = [
		PowerAlchemist.new(), PowerBerserk.new(), PowerBivouacking.new(),
		PowerCommando.new(), PowerDiplomat.new(), PowerDragonMaster.new(),
		PowerFlying.new(), PowerForest.new(), PowerFortified.new(),
		PowerHeroic.new(), PowerHill.new(), PowerMerchant.new(),
		PowerMounted.new(), PowerPillaging.new(), PowerSeafaring.new(),
		PowerSpirit.new(), PowerStout.new(), PowerSwamp.new(),
		PowerUnderworld.new(), PowerWealthy.new()
	]
	_nations_pool.shuffle()
	_powers_pool.shuffle()
	_discarded_powers.clear()
	_displayed_combos.clear()

	for i in range(5):
		_displayed_combos.append(_build_combo())

	_broadcast_combos()

# ═════════════════════════════════════════════════════════════════
# TOUR DE DRAFT
# ═════════════════════════════════════════════════════════════════

func start_draft_turn() -> void:
	if not multiplayer.is_server():
		return

	for peer_id in GameManager.player_order:
		if not GameManager.players[peer_id]["has_nation"]:
			_set_draft_player.rpc(peer_id)
			return

	# Tous les joueurs ont une nation
	emit_signal("all_nations_picked")

@rpc("authority", "call_local", "reliable")
func _set_draft_player(peer_id: int) -> void:
	GameManager.current_player_peer_id = peer_id
	emit_signal("displayed_combos_updated", _get_combo_keys())
	GameManager.emit_signal("current_player_changed",
							GameManager.players[peer_id]["name"])

# ═════════════════════════════════════════════════════════════════
# CHOIX D'UNE COMBINAISON
# ═════════════════════════════════════════════════════════════════

# Appelé depuis l'interface du client
func request_pick_combo(index: int) -> void:
	if multiplayer.is_server():
		_validate_pick(1, index)
	else:
		_ask_pick_combo.rpc_id(1, index)

@rpc("any_peer", "reliable")
func _ask_pick_combo(index: int) -> void:
	if not multiplayer.is_server():
		return
	_validate_pick(multiplayer.get_remote_sender_id(), index)

func _validate_pick(peer_id: int, index: int) -> void:
	# ── Vérifications ──
	if peer_id != GameManager.current_player_peer_id:
		push_warning("DraftManager: ce n'est pas le tour de %s" % peer_id)
		return
	if index < 0 or index >= _displayed_combos.size():
		push_warning("DraftManager: index invalide %s" % index)
		return

	var combo: Dictionary = _displayed_combos[index]
	if combo["nation"] == null:
		push_warning("DraftManager: combo vide à l'index %s" % index)
		return

	# ── Calcul du coût ──
	# Position 0 = gratuit, position 1 = 1 pièce, etc.
	# Le joueur place 1 pièce sur chaque combo AU-DESSUS du sien
	var cost: int = index
	var recovered: int = combo["coins"]
	var net_cost: int = max(0, cost - recovered)

	if GameManager.players[peer_id]["victory_coins"] < net_cost:
		push_warning("DraftManager: pas assez de pièces")
		return

	# ── Application du coût ──
	# Déposer 1 pièce sur chaque combo au-dessus
	for i in range(index):
		_displayed_combos[i]["coins"] += 1

	# Déduire le coût net et ajouter les pièces récupérées
	GameManager.players[peer_id]["victory_coins"] -= net_cost

	# ── Assignation de la nation et du pouvoir ──
	var nation: Nation = combo["nation"]
	var power: SpecialPower = combo["power"]
	nation.special_power = power
	nation.tokens_in_reserve = nation.get_total_tokens()

	GameManager.players[peer_id]["active_nation"] = nation
	GameManager.players[peer_id]["has_nation"] = true

	var nation_key: String = nation.key
	var power_key: String = power.key if power else ""
	var new_coins: int = GameManager.players[peer_id]["victory_coins"]

	# ── Renouvellement de la colonne ──
	# Retirer le combo choisi
	_displayed_combos.remove_at(index)
	# Les combos en dessous remontent d'un cran (déjà fait par remove_at)
	# Ajouter un nouveau combo en bas si le pool n'est pas vide
	if not _nations_pool.is_empty():
		_displayed_combos.append(_build_combo())

	# ── Synchronisation ──
	_apply_pick.rpc(peer_id, nation_key, power_key, new_coins, _get_combo_keys())

@rpc("authority", "call_local", "reliable")
func _apply_pick(peer_id: int, nation_key: String, power_key: String,
				 new_coins: int, combo_keys: Array) -> void:
	# Mettre à jour les pièces localement sur tous les clients
	if GameManager.players.has(peer_id):
		GameManager.players[peer_id]["victory_coins"] = new_coins

	emit_signal("combo_picked", peer_id, nation_key, power_key)
	emit_signal("displayed_combos_updated", combo_keys)
	GameManager.emit_signal("victory_coins_updated", peer_id, new_coins)

	# Host : passer au joueur suivant dans la draft
	if multiplayer.is_server():
		await get_tree().process_frame
		start_draft_turn()

# ═════════════════════════════════════════════════════════════════
# UTILITAIRES
# ═════════════════════════════════════════════════════════════════

func _build_combo() -> Dictionary:
	if _powers_pool.is_empty():
		if not _discarded_powers.is_empty():
			_powers_pool = _discarded_powers.duplicate()
			_powers_pool.shuffle()
			_discarded_powers.clear()

	return {
		"nation": _nations_pool.pop_front() if not _nations_pool.is_empty() else null,
		"power": _powers_pool.pop_front() if not _powers_pool.is_empty() else null,
		"coins": 0
	}

func _get_combo_keys() -> Array:
	var keys: Array = []
	for combo in _displayed_combos:
		keys.append({
			"nation_key": combo["nation"].key if combo["nation"] else "",
			"power_key": combo["power"].key if combo["power"] else "",
			"nation_icon": combo["nation"].icon_path if combo["nation"] else "",
			"power_icon": combo["power"].icon_path if combo["power"] else "",
			"nation_tokens": combo["nation"].base_tokens if combo["nation"] else 0,
			"power_tokens": combo["power"].bonus_tokens if combo["power"] else 0,
			"coins": combo["coins"]
		})
	return keys

func _broadcast_combos() -> void:
	_update_displayed_combos.rpc(_get_combo_keys())

@rpc("authority", "call_local", "reliable")
func _update_displayed_combos(combo_keys: Array) -> void:
	emit_signal("displayed_combos_updated", combo_keys)

# Retourne le combo affiché à un index donné (host uniquement)
func get_combo_at(index: int) -> Dictionary:
	if index < 0 or index >= _displayed_combos.size():
		return {}
	return _displayed_combos[index]

# Vérifie si le joueur local peut se permettre le combo à cet index
func can_afford_combo(index: int) -> bool:
	var peer_id: int = multiplayer.get_unique_id()
	if not GameManager.players.has(peer_id):
		return false
	var coins: int = GameManager.players[peer_id]["victory_coins"]
	var combo_coins: int = 0
	# On récupère les coins depuis les combo_keys car les clients
	# n'ont pas accès à _displayed_combos directement
	return coins >= max(0, index - combo_coins)

func return_nation_to_pool(nation: Nation) -> void:
	_nations_pool.append(nation)
	# Si la colonne a moins de 5 combos, compléter
	if _displayed_combos.size() < 5 and not _nations_pool.is_empty():
		_displayed_combos.append(_build_combo())
		_broadcast_combos()
