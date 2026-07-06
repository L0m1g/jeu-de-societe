extends Node2D

# ─── Références UI ───────────────────────────────────────────────
@onready var draft_panel = $CanvasLayer/DraftPanel
@onready var combo_list = $CanvasLayer/DraftPanel/VBoxContainer/ComboList
@onready var action_panel = $CanvasLayer/ActionPanel
@onready var conquer_button = $CanvasLayer/ActionPanel/HBoxContainer/ConquerButton
@onready var decline_button = $CanvasLayer/ActionPanel/HBoxContainer/DeclineButton
@onready var end_conquest_button = $CanvasLayer/ActionPanel/HBoxContainer/EndConquestButton
@onready var roll_die_button = $CanvasLayer/ActionPanel/HBoxContainer/RollDieButton
@onready var end_turn_button = $CanvasLayer/ActionPanel/HBoxContainer/EndTurnButton
@onready var current_player_label = $CanvasLayer/InfoPanel/VBoxContainer/CurrentPlayerLabel
@onready var turn_label = $CanvasLayer/InfoPanel/VBoxContainer/TurnLabel
@onready var player_panel = $CanvasLayer/PlayerPanel
@onready var player_name_label = $CanvasLayer/PlayerPanel/VBoxContainer/PlayerNameLabel
@onready var coins_label = $CanvasLayer/PlayerPanel/VBoxContainer/CoinsLabel
@onready var nation_label = $CanvasLayer/PlayerPanel/VBoxContainer/NationsLabel
@onready var tokens_label = $CanvasLayer/PlayerPanel/VBoxContainer/TokensLabel
@onready var die_result_panel = $CanvasLayer/DieResultPanel
@onready var die_result_label = $CanvasLayer/DieResultPanel/VBoxContainer/DieResultLabel
@onready var end_game_panel = $CanvasLayer/EndGamePanel
@onready var score_list = $CanvasLayer/EndGamePanel/VBoxContainer/ScoreList
@onready var redeploy_info_panel = $CanvasLayer/RedeployInfoPanel
@onready var tokens_remaining_label = $CanvasLayer/RedeployInfoPanel/VBoxContainer/TokensRemainingLabel
@onready var validate_redeploy_button = $CanvasLayer/RedeployInfoPanel/VBoxContainer/ValidateButton
@onready var encampment_info_label = $CanvasLayer/RedeployInfoPanel/VBoxContainer/EncampmentInfoLabel

# ─── État local ──────────────────────────────────────────────────
var _local_peer_id: int = 0
var _is_local_turn: bool = false
var _current_phase: Global.TurnPhase = Global.TurnPhase.PICK_NATION
var _total_tokens_to_deploy: int = 0
var _tokens_assigned: int = 0
var _total_encampments: int = 5
var _encampments_assigned: int = 0
var _has_bivouacking: bool = false

# ═════════════════════════════════════════════════════════════════
# INITIALISATION
# ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id()

	# Connexion des signaux
	GameManager.turn_phase_changed.connect(_on_turn_phase_changed)
	GameManager.current_player_changed.connect(_on_current_player_changed)
	GameManager.victory_coins_updated.connect(_on_victory_coins_updated)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	DraftManager.displayed_combos_updated.connect(_on_displayed_combos_updated)
	DraftManager.combo_picked.connect(_on_combo_picked)
	ConquestManager.reinforcement_die_rolled.connect(_on_die_rolled)
	ScoringManager.final_scores_ready.connect(_on_final_scores_ready)

	# État initial
	_hide_all_panels()
	draft_panel.show()
	action_panel.hide()
	die_result_panel.hide()
	end_game_panel.hide()

	# Afficher le panneau joueur local uniquement
	_update_player_panel()
	
	# Initialiser les displays des éléments spéciaux
	# (montagnes, tribus oubliées présentes dès le départ)
	await get_tree().process_frame
	_init_region_displays()
	
	# Demander l'état courant au GameManager
	GameManager.request_current_player()

func _init_region_displays() -> void:
	for region in get_tree().get_nodes_in_group("regions"):
		region.refresh_display()

# ═════════════════════════════════════════════════════════════════
# GESTION DES PHASES
# ═════════════════════════════════════════════════════════════════

func _on_turn_phase_changed(phase: Global.TurnPhase) -> void:
	_current_phase = phase
	_is_local_turn = GameManager.is_current_player_local()
	_update_ui_for_phase(phase)
	
	# Initialiser le redéploiement si c'est notre tour
	if phase == Global.TurnPhase.REDEPLOY and _is_local_turn:
		_init_redeployment()

func _update_ui_for_phase(phase: Global.TurnPhase) -> void:
	# Cacher tous les boutons d'abord
	_hide_action_buttons()

	match phase:
		Global.TurnPhase.PICK_NATION:
			draft_panel.show()
			action_panel.hide()

		Global.TurnPhase.CHOOSE_ACTION:
			draft_panel.hide()
			if _is_local_turn:
				action_panel.show()
				conquer_button.show()
				decline_button.show()
				# Ne peut pas décliner si pas encore de nation en déclin possible
				var nation = GameManager.get_active_nation(_local_peer_id)
				if nation == null:
					decline_button.disabled = true

		Global.TurnPhase.CONQUEST:
			draft_panel.hide()
			if _is_local_turn:
				action_panel.show()
				end_conquest_button.show()
				# Berserk : dé avant chaque conquête
				var nation = GameManager.get_active_nation(_local_peer_id)
				if nation and nation.special_power is PowerBerserk:
					roll_die_button.show()

		Global.TurnPhase.REDEPLOY:
			if _is_local_turn:
				action_panel.show()
				end_turn_button.show()

		Global.TurnPhase.DECLINE:
			action_panel.hide()

		Global.TurnPhase.SCORING:
			action_panel.hide()

func _hide_action_buttons() -> void:
	conquer_button.hide()
	decline_button.hide()
	end_conquest_button.hide()
	roll_die_button.hide()
	end_turn_button.hide()

func _hide_all_panels() -> void:
	draft_panel.hide()
	action_panel.hide()
	die_result_panel.hide()
	end_game_panel.hide()

# ═════════════════════════════════════════════════════════════════
# DRAFT — AFFICHAGE DE LA COLONNE
# ═════════════════════════════════════════════════════════════════

func _on_displayed_combos_updated(combo_keys: Array) -> void:
	# Vider la liste
	for child in combo_list.get_children():
		child.queue_free()

	# Reconstruire les 5 combos
	for i in range(combo_keys.size()):
		var combo_data: Dictionary = combo_keys[i]
		var combo_row = _build_combo_row(i, combo_data)
		combo_list.add_child(combo_row)

func _build_combo_row(index: int, data: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.name = "combo_%s" % index

	# Icône nation
	var nation_icon = TextureRect.new()
	nation_icon.custom_minimum_size = Vector2(48, 48)
	if data["nation_icon"] != "":
		nation_icon.texture = load(data["nation_icon"])
	container.add_child(nation_icon)

	# Infos nation
	var nation_info = VBoxContainer.new()
	var nation_name = Label.new()
	nation_name.text = tr(data["nation_key"])
	var nation_tokens = Label.new()
	nation_tokens.text = "%s pions" % (
		data["nation_tokens"] + data["power_tokens"])
	nation_info.add_child(nation_name)
	nation_info.add_child(nation_tokens)
	container.add_child(nation_info)

	# Séparateur
	var sep = VSeparator.new()
	container.add_child(sep)

	# Icône pouvoir
	var power_icon = TextureRect.new()
	power_icon.custom_minimum_size = Vector2(48, 48)
	if data["power_icon"] != "":
		power_icon.texture = load(data["power_icon"])
	container.add_child(power_icon)

	# Nom pouvoir
	var power_name = Label.new()
	power_name.text = tr(data["power_key"])
	container.add_child(power_name)

	# Coût en pièces
	if data["coins"] > 0:
		var coins_label_node = Label.new()
		coins_label_node.text = "+%s" % data["coins"]
		coins_label_node.modulate = Color.GOLD
		container.add_child(coins_label_node)

	# Bouton de sélection
	var pick_button = Button.new()
	pick_button.text = "%s pièce(s)" % index if index > 0 else tr("UI_FREE")
	pick_button.disabled = not _is_local_turn or \
						   not DraftManager.can_afford_combo(index)
	pick_button.pressed.connect(
		func(): DraftManager.request_pick_combo(index))
	container.add_child(pick_button)

	return container

func _on_combo_picked(peer_id: int, nation_key: String,
					   power_key: String) -> void:
	var name_str: String = GameManager.players[peer_id]["name"]
	print("%s a choisi %s + %s" % [name_str, tr(nation_key), tr(power_key)])
	_update_player_panel()

# ═════════════════════════════════════════════════════════════════
# INFOS JOUEUR COURANT
# ═════════════════════════════════════════════════════════════════

func _on_current_player_changed(username: String) -> void:
	current_player_label.text = tr("UI_CURRENT_PLAYER") + " " + username
	_is_local_turn = GameManager.is_current_player_local()
	_update_ui_for_phase(_current_phase)

func _on_turn_changed(turn: int) -> void:
	turn_label.text = tr("UI_TURN") + " %s / %s" % [
		turn, GameManager.max_turns]

func _on_victory_coins_updated(peer_id: int, coins: int) -> void:
	if peer_id == _local_peer_id:
		coins_label.text = tr("UI_COINS") + " %s" % coins

func _update_player_panel() -> void:
	if not GameManager.players.has(_local_peer_id):
		return

	var player_data: Dictionary = GameManager.players[_local_peer_id]
	player_name_label.text = player_data["name"]
	coins_label.text = tr("UI_COINS") + " %s" % player_data["victory_coins"]

	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation:
		nation_label.text = tr(nation.key)
		tokens_label.text = tr("UI_TOKENS") + " %s" % nation.tokens_in_reserve
	else:
		nation_label.text = tr("UI_NO_NATION")
		tokens_label.text = ""

# ═════════════════════════════════════════════════════════════════
# BOUTONS D'ACTION
# ═════════════════════════════════════════════════════════════════

func _on_conquer_button_pressed() -> void:
	GameManager.request_action("conquest")

func _on_decline_button_pressed() -> void:
	GameManager.request_action("decline")

func _on_end_conquest_button_pressed() -> void:
	ConquestManager.request_end_conquest(_local_peer_id)

func _on_roll_die_button_pressed() -> void:
	ConquestManager.request_berserk_die(_local_peer_id)

func _on_end_turn_button_pressed() -> void:
	# Récupérer le redéploiement actuel depuis le plateau
	var redeployment: Dictionary = _collect_redeployment()
	if redeployment.is_empty():
		push_warning("main_screen: redéploiement vide")
		return
	ConquestManager.request_redeploy(_local_peer_id, redeployment)

func _collect_redeployment() -> Dictionary:
	var redeployment: Dictionary = {}
	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation == null:
		return redeployment
	for region in nation.owned_regions:
		redeployment[region.get_path()] = region.token_count
	return redeployment

# ═════════════════════════════════════════════════════════════════
# DÉ DE RENFORT
# ═════════════════════════════════════════════════════════════════

func _on_die_rolled(result: int) -> void:
	die_result_panel.show()
	die_result_label.text = str(result)
	# Cacher après 2 secondes
	await get_tree().create_timer(2.0).timeout
	die_result_panel.hide()

# ═════════════════════════════════════════════════════════════════
# REDEPLOIEMENT
# ═════════════════════════════════════════════════════════════════

func _init_redeployment() -> void:
	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation == null:
		return
	
	# Pions
	_tokens_assigned = 0
	var tokens_on_board: int = 0
	for region in get_tree().get_nodes_in_group("regions"):
		if region.owner_peer_id == _local_peer_id:
			tokens_on_board += region.token_count
	_total_tokens_to_deploy = tokens_on_board + nation.tokens_in_reserve
	
	# Campements
	_has_bivouacking = nation.special_power is PowerBivouacking
	if _has_bivouacking:
		_encampments_assigned = 0
		# Calculer les campements déjà placés
		var power: PowerBivouacking = nation.special_power
		for region in power.encampment_regions:
			_encampments_assigned += region.encampment_count
	
	# Connecter les signaux des régions
	for region in get_tree().get_nodes_in_group("regions"):
		if region.owner_peer_id == _local_peer_id:
			if not region.redeployment_changed.is_connected(
				_on_region_redeployment_changed):
					region.redeployment_changed.connect(
						_on_region_redeployment_changed)
			if _has_bivouacking:
				if not region.encampment_changed.is_connected(
					_on_region_encampment_changed):
						region.encampment_changed.connect(
							_on_region_encampment_changed)
	
	_update_redeploy_info()
	redeploy_info_panel.show()
	encampment_info_label.visible = _has_bivouacking

func _on_region_encampment_changed(region: Node, new_count: int) -> void:
	_encampments_assigned = 0
	for r in get_tree().get_nodes_in_group("regions"):
		if r.owner_peer_id == _local_peer_id:
			_encampments_assigned += r.get_pending_encampments()
	
	var remaining_camps: int = _total_encampments - _encampments_assigned
	
	# Désactiver + sur toutes les régions si quota atteint
	for r in get_tree().get_nodes_in_group("regions"):
		if r.owner_peer_id == _local_peer_id:
			r.set_camp_plus_disabled(remaining_camps <= 0)
	_update_redeploy_info()

func _on_region_redeployment_changed(region: Node, new_count: int) -> void:
	# Recalculer le total assigné
	_tokens_assigned = 0
	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation == null:
		return
	
	for r in get_tree().get_nodes_in_group("regions"):
		if r.owner_peer_id == _local_peer_id:
			_tokens_assigned += r.get_pending_tokens()
	
	# Vérifier que le bouton + de toutes les régions
	# est désactivé si plus de pions disponibles
	var remaining: int = _total_tokens_to_deploy - _tokens_assigned
	_update_redeploy_buttons(remaining)
	_update_redeploy_info()

func _update_redeploy_buttons(remaining: int) -> void:
	for region in get_tree().get_nodes_in_group("regions"):
		if region.owner_peer_id != _local_peer_id:
			continue
		var widget = region.get_node_or_null("RedeployWidget")
		if widget == null:
			continue
		var buttons = widget.get_node_or_null("HBoxContainer")
		if buttons == null:
			continue
		# Désactiver + si plus de pions disponibles
		var plus_btn = buttons.get_child(1)
		if plus_btn:
			plus_btn.disabled = remaining <= 0

func _update_redeploy_info() -> void:
	var remaining_tokens: int = _total_tokens_to_deploy - _tokens_assigned
	tokens_remaining_label.text = tr("UI_TOKENS_REMAINING") + " %s" % remaining_tokens
	
	# Afficher le compte des campements si Bivouacking
	if _has_bivouacking:
		var remaining_camps: int = _total_encampments - _encampments_assigned
		encampment_info_label.text = tr("UI_ENCAMPMENTS_REMAINING") + \
		" %s / %s" % [_encampments_assigned,_total_encampments]
	
	# Valider uniquement si tous les pions ET campements sont placés
	var tokens_ok: bool = remaining_tokens == 0
	var camps_ok: bool = not _has_bivouacking or _encampments_assigned == _total_encampments
	validate_redeploy_button.disabled = not (tokens_ok and camps_ok)

func _on_validate_redeploy_pressed() -> void:
	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation == null:
		return
	
	# Redéploiement des pions
	var redeployment: Dictionary = {}
	for region in get_tree().get_nodes_in_group("regions"):
		if region.owner_peer_id == _local_peer_id:
			redeployment[region.get_path()] = region.get_pending_tokens()
	
	# Placement des campements Bivouacking
	if _has_bivouacking:
		var placements: Dictionary = {}
		for region in get_tree().get_nodes_in_group("regions"):
			if region.owner_peer_id == _local_peer_id:
				var count: int = region.get_pending_encampments()
				if count > 0:
					placements[region.get_path()] = count
		ConquestManager.request_place_encampments(placements)
	
	ConquestManager.request_redeploy(_local_peer_id, redeployment)
	redeploy_info_panel.hide()
	
	# Déconnecter les signaux des régions
	for region in get_tree().get_nodes_in_group("regions"):
		if region.redeployment_changed.is_connected(
			_on_region_redeployment_changed):
				region.redeployment_changed.disconnect(
					_on_region_redeployment_changed)
		if region.encampment_changed.is_connected(
			_on_region_encampment_changed):
				region.encampment_changed.disconnect(
					_on_region_encampment_changed)

func _collect_encampment_placements() -> Dictionary:
	# Pour l'instant retourne les régions avec campements existants
	# L'UI de placement des campements est gérée séparément
	var placements: Dictionary = {}
	var nation: Nation = GameManager.get_active_nation(_local_peer_id)
	if nation == null or not nation.special_power is PowerBivouacking:
		return placements
	var power: PowerBivouacking = nation.special_power
	for region in power.encampment_regions:
		placements[region.get_path()] = region.encampment_count
	return placements

# ═════════════════════════════════════════════════════════════════
# FIN DE PARTIE
# ═════════════════════════════════════════════════════════════════

func _on_game_state_changed(new_state: Global.GameState) -> void:
	if new_state == Global.GameState.END:
		_hide_all_panels()
		end_game_panel.show()

func _on_final_scores_ready(scores: Dictionary) -> void:
	for child in score_list.get_children():
		child.queue_free()

	# Trier par score décroissant
	var sorted_peers: Array = scores.keys()
	sorted_peers.erase("winner")
	sorted_peers.sort_custom(func(a, b):
		return scores[a]["coins"] > scores[b]["coins"])

	for peer_id in sorted_peers:
		var row = HBoxContainer.new()

		var is_winner: bool = peer_id == scores["winner"]

		var name_label = Label.new()
		name_label.text = scores[peer_id]["name"]
		if is_winner:
			name_label.text += " 👑"
			name_label.modulate = Color.GOLD
		row.add_child(name_label)

		var coins_label_node = Label.new()
		coins_label_node.text = "%s pièces" % scores[peer_id]["coins"]
		row.add_child(coins_label_node)

		score_list.add_child(row)
