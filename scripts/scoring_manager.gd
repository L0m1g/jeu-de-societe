# scoring_manager.gd
extends Node

# ─── Signaux ─────────────────────────────────────────────────────
signal scoring_completed(peer_id: int, coins_earned: int)
signal final_scores_ready(scores: Dictionary)

# ═════════════════════════════════════════════════════════════════
# CALCUL DES POINTS D'UN JOUEUR
# ═════════════════════════════════════════════════════════════════

func calculate_score(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var total_coins: int = 0

	# ── Points des régions actives ──
	var active_nation: Nation = GameManager.get_active_nation(peer_id)
	if active_nation != null and not active_nation.is_in_decline:
		total_coins += _score_active_nation(peer_id, active_nation)

	# ── Points des régions en déclin ──
	var decline_nation: Nation = GameManager.players[peer_id]["decline_nation"]
	if decline_nation != null:
		total_coins += _score_decline_nation(peer_id, decline_nation)

	# ── Appliquer les pièces ──
	GameManager.players[peer_id]["victory_coins"] += total_coins

	_broadcast_score.rpc(peer_id,
						 GameManager.players[peer_id]["victory_coins"],
						 total_coins)

# ─── Score nation active ─────────────────────────────────────────

func _score_active_nation(peer_id: int, nation: Nation) -> int:
	var total: int = 0
	var owned: Array = nation.owned_regions

	# +1 par région occupée
	total += owned.size()

	# Bonus de la nation (Humans, Wizards, Dwarves, Orcs...)
	total += nation.calculate_bonus_victory_tokens(owned)

	# Bonus du pouvoir spécial (Merchant, Alchemist, Hills...)
	if nation.special_power != null:
		total += nation.special_power.calculate_bonus_victory_tokens(
			nation, owned)

	# Bonus Fortified : +1 par forteresse (déjà dans nation.calculate_bonus)
	# Bonus Heroic : pas de points, juste immunité
	# Bonus Wealthy : première fois seulement (géré dans PowerWealthy)

	return total

# ─── Score nation en déclin ──────────────────────────────────────

func _score_decline_nation(peer_id: int, nation: Nation) -> int:
	var total: int = 0
	var decline_regions: Array = nation.decline_regions

	# +1 par région en déclin
	total += decline_regions.size()

	# Certaines nations gardent leurs bonus en déclin
	# Nains : bonus mine même en déclin
	if nation is Dwarves:
		total += nation.calculate_decline_bonus_victory_tokens(decline_regions)

	# Seafaring : garde les régions mers/lac même en déclin
	if nation.special_power is PowerSeafaring:
		total += _score_seafaring_decline(nation)

	# Spirit : bonus déjà comptabilisé via decline_regions normalement
	# Fortified : forteresses comptent même en déclin
	if nation.special_power is PowerFortified:
		for region in decline_regions:
			if region.has_fortress:
				total += 1

	return total

func _score_seafaring_decline(nation: Nation) -> int:
	var count: int = 0
	for region in nation.decline_regions:
		if region.region_type == Global.RegionType.SEA or \
		   region.region_type == Global.RegionType.LAKE:
			count += 1
	return count

# ═════════════════════════════════════════════════════════════════
# SYNCHRONISATION
# ═════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func _broadcast_score(peer_id: int, total_coins: int, earned: int) -> void:
	if GameManager.players.has(peer_id):
		GameManager.players[peer_id]["victory_coins"] = total_coins

	GameManager.emit_signal("victory_coins_updated", peer_id, total_coins)
	emit_signal("scoring_completed", peer_id, earned)

# ═════════════════════════════════════════════════════════════════
# SCORES FINAUX
# ═════════════════════════════════════════════════════════════════

func calculate_final_scores() -> void:
	if not multiplayer.is_server():
		return

	var scores: Dictionary = {}
	for peer_id in GameManager.players.keys():
		scores[peer_id] = {
			"name": GameManager.players[peer_id]["name"],
			"coins": GameManager.players[peer_id]["victory_coins"],
			"tokens_on_board": _count_tokens_on_board(peer_id)
		}

	# Déterminer le gagnant
	var winner_id: int = _determine_winner(scores)
	scores["winner"] = winner_id

	_broadcast_final_scores.rpc(scores)

func _determine_winner(scores: Dictionary) -> int:
	var best_coins: int = -1
	var best_tokens: int = -1
	var winner_id: int = -1

	for peer_id in scores.keys():
		if peer_id == "winner":
			continue
		var coins: int = scores[peer_id]["coins"]
		var tokens: int = scores[peer_id]["tokens_on_board"]

		if coins > best_coins:
			best_coins = coins
			best_tokens = tokens
			winner_id = peer_id
		elif coins == best_coins:
			# Égalité : départage par nombre de pions sur le plateau
			if tokens > best_tokens:
				best_tokens = tokens
				winner_id = peer_id

	return winner_id

func _count_tokens_on_board(peer_id: int) -> int:
	var total: int = 0

	var active: Nation = GameManager.get_active_nation(peer_id)
	if active != null:
		for region in active.owned_regions:
			total += region.token_count

	var decline: Nation = GameManager.players[peer_id]["decline_nation"]
	if decline != null:
		for region in decline.decline_regions:
			total += region.decline_token_count

	return total

@rpc("authority", "call_local", "reliable")
func _broadcast_final_scores(scores: Dictionary) -> void:
	emit_signal("final_scores_ready", scores)
