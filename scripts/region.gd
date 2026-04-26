extends Node2D

@onready var polygon_2d: Polygon2D = $Area2D/Polygon2D

# ─── Propriétés export ───────────────────────────────────────────
@export var region_type: Global.RegionType = Global.RegionType.FOREST
@export var is_border: bool = false
@export var adjacent_regions: Array[NodePath] = []

# Éléments spéciaux
@export var has_mountain: bool = false
@export var has_fortress: bool = false
@export var has_encampment: bool = false
@export var has_troll_lair: bool = false
@export var has_magic_source: bool = false
@export var has_mine: bool = false
@export var has_cave: bool = false

# Ajouts manquants
@export var has_hole_in_ground: bool = false
var has_hero: bool = false
var has_dragon: bool = false
var encampment_count: int = 0

# Tribus oubliées
@export var has_lost_tribe: bool = false

# ─── État en jeu ─────────────────────────────────────────────────
var owner_peer_id: int = -1
var owner_nation: Nation = null
var decline_nation: Nation = null
var token_count: int = 0
var decline_token_count: int = 0
var _encampment_widget: Control = null
var _pending_encampments: int = 0
var _token_display: Control = null
var _decline_display: Control = null
var _element_displays: Array = []

# Couleur de highlight
var _base_color: Color = Color(1, 0, 0, 0)
var _highlight_color: Color = Color(0, 1, 0, 0.3)
var _is_targetable: bool = false

signal region_clicked(region: Node)
signal encampment_changed(region: Node, new_count: int)

# ═════════════════════════════════════════════════════════════════

# ─── UI de redéploiement ─────────────────────────────────────────
var _redeployment_widget: Control = null
# Pions assignés à cette région pendant le redéploiement
var _pending_tokens: int = 0

signal redeployment_changed(region: Node, new_count: int)

# ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Ajouter au groupe pour que ConquestManager puisse itérer
	add_to_group("regions")

	# Connecter les signaux de phase pour mettre à jour le highlight
	GameManager.turn_phase_changed.connect(_on_turn_phase_changed)

func _on_turn_phase_changed(phase: Global.TurnPhase) -> void:
	match phase:
		Global.TurnPhase.CONQUEST:
			_update_targetable_highlight()
			_hide_redeployment_widget()
		Global.TurnPhase.REDEPLOY:
			_clear_highlight()
			_show_redeployment_widget_if_owned()
		_:
			_clear_highlight()
			_hide_redeployment_widget()

func _update_targetable_highlight() -> void:
	var peer_id: int = multiplayer.get_unique_id()
	if peer_id != GameManager.current_player_peer_id:
		_clear_highlight()
		return

	var targetable: Array = ConquestManager.get_targetable_regions(peer_id)
	_is_targetable = self in targetable

	if _is_targetable:
		polygon_2d.color = _highlight_color
	else:
		polygon_2d.color = _base_color

func _clear_highlight() -> void:
	_is_targetable = false
	polygon_2d.color = _base_color

func _on_mouse_entered() -> void:
	if _is_targetable:
		polygon_2d.color = Color(0, 1, 0, 0.5)
	else:
		polygon_2d.color = Color(1, 1, 1, 0.1)

func _on_mouse_exited() -> void:
	if _is_targetable:
		polygon_2d.color = _highlight_color
	else:
		polygon_2d.color = _base_color

func _on_area_2d_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and \
	   event.button_index == MOUSE_BUTTON_LEFT and \
	   event.pressed:
		emit_signal("region_clicked", self)
		if _is_targetable:
			ConquestManager.request_conquest(get_path())

# ═════════════════════════════════════════════════════════════════
# WIDGET DE REDÉPLOIEMENT
# ═════════════════════════════════════════════════════════════════

func _show_redeployment_widget_if_owned() -> void:
	var local_id: int = multiplayer.get_unique_id()
	if owner_peer_id != local_id:
		return
	if not GameManager.is_current_player_local():
		return
	
	_pending_tokens = token_count
	_create_redeployment_widget()
	
	# Afficher le widget campement uniquement si Bivouacking
	var nation: Nation = GameManager.get_active_nation(local_id)
	if nation and nation.special_power is PowerBivouacking:
		_pending_encampments = _get_current_encampment_count(nation)
		_create_encampment_widget()

func _get_current_encampment_count(nation: Nation) -> int:
	var power: PowerBivouacking = nation.special_power
	for region in power.encampment_regions:
		if region == self:
			return region.encampment_count
	return 0

func _create_redeployment_widget() -> void:
	if _redeployment_widget != null:
		_redeployment_widget.queue_free()
	
	# Calculer le centre du polygone
	var center: Vector2 = _get_polygon_center()
	
	# Conteneur principal
	var widget = VBoxContainer.new()
	widget.position = center - Vector2(40, 30)
	widget.name = "RedeployWidget"
	
	# Compteur
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = str(_pending_tokens)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color.WHITE)
	widget.add_child(count_label)
	
	# Boutons + et -
	var buttons = HBoxContainer.new()
	
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(30, 30)
	minus_btn.pressed.connect(_on_minus_pressed)
	buttons.add_child(minus_btn)
	
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 30)
	plus_btn.pressed.connect(_on_plus_pressed)
	buttons.add_child(plus_btn)
	
	widget.add_child(buttons)
	add_child(widget)
	_redeployment_widget = widget

func _hide_redeployment_widget() -> void:
	if _redeployment_widget != null:
		_redeployment_widget.queue_free()
		_redeployment_widget = null
	_hide_encampment_widget()

func _hide_encampment_widget() -> void:
	if _encampment_widget != null:
		_encampment_widget.queue_free()
		_encampment_widget = null

func _on_minus_pressed() -> void:
	if _pending_tokens <= 1:
		return  # Minimum 1 pion par région
	_pending_tokens -= 1
	_update_count_label()
	emit_signal("redeployment_changed", self, _pending_tokens)

func _on_plus_pressed() -> void:
	_pending_tokens += 1
	_update_count_label()
	emit_signal("redeployment_changed", self, _pending_tokens)

func _update_count_label() -> void:
	if _redeployment_widget:
		var label = _redeployment_widget.get_node_or_null("CountLabel")
		if label:
			label.text = str(_pending_tokens)

func _get_polygon_center() -> Vector2:
	var polygon: Polygon2D = $Area2D/Polygon2D
	if polygon == null:
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point in polygon.polygon:
		center += point
	return center / polygon.polygon.size()

func get_pending_tokens() -> int:
	return _pending_tokens

# ═════════════════════════════════════════════════════════════════
# WIDGET CAMPEMENT
# ═════════════════════════════════════════════════════════════════

func _create_encampment_widget() -> void:
	if _encampment_widget != null:
		_encampment_widget.queue_free()
	
	var center: Vector2 = _get_polygon_center()
	
	var widget = VBoxContainer.new()
	# Positionner sous le widget pions
	widget.position = center - Vector2(40, -40)
	widget.name = "EncampmentWidget"
	
	# Label campements
	var camp_label = Label.new()
	camp_label.name = "CampLabel"
	camp_label.text = tr("UI_ENCAMPMENTS") + ": %s" % _pending_encampments
	camp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camp_label.add_theme_color_override("font_color", Color.YELLOW)
	widget.add_child(camp_label)
	
	# Boutons + et -
	var buttons = HBoxContainer.new()
	buttons.name = "CampButtons"
	
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(30, 30)
	minus_btn.pressed.connect(_on_camp_minus_pressed)
	buttons.add_child(minus_btn)
	
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 30)
	plus_btn.pressed.connect(_on_camp_plus_pressed)
	buttons.add_child(plus_btn)
	
	widget.add_child(buttons)
	add_child(widget)
	_encampment_widget = widget

func _on_camp_minus_pressed() -> void:
	if _pending_encampments <= 0:
		return
	_pending_encampments -= 1
	_update_camp_label()
	emit_signal("encampment_changed", self, _pending_encampments)

func _on_camp_plus_pressed() -> void:
	_pending_encampments += 1
	_update_camp_label()
	emit_signal("encampment_changed", self, _pending_encampments)

func _update_camp_label() -> void:
	if _encampment_widget:
		var label = _encampment_widget.get_node_or_null("CampLabel")
		if label:
			label.text = tr("UI_ENCAMPMENTS") + ": %s" % _pending_encampments

func get_pending_encampments() -> int:
	return _pending_encampments

# Désactiver/activer le bouton + des campements
func set_camp_plus_disabled(disabled: bool) -> void:
	if _encampment_widget == null:
		return
	var buttons = _encampment_widget.get_node_or_null("CampButtons")
	if buttons:
		buttons.get_child(1).disabled = disabled

# ═════════════════════════════════════════════════════════════════
# AFFICHAGE DES PIONS ACTIFS
# ═════════════════════════════════════════════════════════════════

func update_token_display() -> void:
	_clear_token_display()
	
	if owner_peer_id == -1 or owner_nation == null or token_count <= 0:
		return
	
	var center: Vector2 = _get_polygon_center()
	
	var container = HBoxContainer.new()
	container.name = "TokenDisplay"
	# Positionner en haut du centre de la région
	container.position = center - Vector2(24, 24)
	
	# Icône de la nation
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	if owner_nation.icon_path != "":
		var texture = load(owner_nation.icon_path)
		if texture:
			icon.texture = texture
	container.add_child(icon)
	
	# Chiffre
	var count_label = Label.new()
	count_label.text = str(token_count)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_font_size_override("font_size", 14)
	container.add_child(count_label)
	
	add_child(container)
	_token_display = container

func _clear_token_display() -> void:
	if _token_display != null:
		_token_display.queue_free()
		_token_display = null

# ═════════════════════════════════════════════════════════════════
# AFFICHAGE DES PIONS EN DÉCLIN
# ═════════════════════════════════════════════════════════════════

func update_decline_display() -> void:
	_clear_decline_display()
	
	if decline_nation == null or decline_token_count <= 0:
		return
	
	var center: Vector2 = _get_polygon_center()
	
	var container = HBoxContainer.new()
	container.name = "DeclineDisplay"
	# Positionner légèrement en dessous du display actif
	container.position = center - Vector2(24, -8)
	
	# Icône grisée
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	if decline_nation.icon_path != "":
		var texture = load(decline_nation.icon_path)
		if texture:
			icon.texture = texture
	# Filtre grisé
	icon.modulate = Color(0.5, 0.5, 0.5, 0.9)
	container.add_child(icon)
	
	# Chiffre grisé
	var count_label = Label.new()
	count_label.text = str(decline_token_count)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	count_label.add_theme_font_size_override("font_size", 12)
	container.add_child(count_label)
	
	add_child(container)
	_decline_display = container

func _clear_decline_display() -> void:
	if _decline_display != null:
		_decline_display.queue_free()
		_decline_display = null

# ═════════════════════════════════════════════════════════════════
# AFFICHAGE DES ÉLÉMENTS SPÉCIAUX
# ═════════════════════════════════════════════════════════════════

func update_element_displays() -> void:
	_clear_element_displays()
	
	var center: Vector2 = _get_polygon_center()
	var offset_x: float = -48.0
	var elements: Array = _get_active_elements()
	
	for element in elements:
		var sprite = Sprite2D.new()
		var texture = load(element["path"])
		if texture == null:
			continue
		sprite.texture = texture
		sprite.scale = Vector2(0.3, 0.3)
		# Disposer les éléments en ligne en bas de la région
		sprite.position = center + Vector2(offset_x, 24)
		offset_x += 32.0
		add_child(sprite)
		_element_displays.append(sprite)

func _get_active_elements() -> Array:
	var elements: Array = []
	
	if has_mountain:
		elements.append({
			"path": "res://assets/images/elements/mountains.png"
			})
	if has_fortress:
		elements.append({
			"path": "res://assets/images/elements/fortresses.png"
			})
	if has_encampment:
		elements.append({
			"path": "res://assets/images/elements/encampments.png"
			})
	if has_troll_lair:
		elements.append({
			"path": "res://assets/images/elements/troll_lairs.png"
			})
	if has_dragon:
		elements.append({
			"path": "res://assets/images/elements/dragon.png"
			})
	if has_hero:
		elements.append({
			"path": "res://assets/images/elements/heroes.png"
			})
	if has_hole_in_ground:
		elements.append({
			"path": "res://assets/images/elements/holes_in_the_ground.png"
			})
	if has_lost_tribe:
		elements.append({
			"path": "res://assets/images/elements/lost_tribes.png"
			})
	return elements

func _clear_element_displays() -> void:
	for sprite in _element_displays:
		if sprite:
			sprite.queue_free()
	_element_displays.clear()

# ═════════════════════════════════════════════════════════════════
# MISE À JOUR COMPLÈTE
# ═════════════════════════════════════════════════════════════════

func refresh_display() -> void:
	update_token_display()
	update_decline_display()
	update_element_displays()

# ─── Calculs ─────────────────────────────────────────────────────

func get_defense_strength() -> int:
	var strength: int = token_count
	if has_mountain: strength += 1
	if has_fortress: strength += 1
	if has_troll_lair: strength += 1
	if has_encampment: strength += encampment_count
	if has_lost_tribe: strength += 1
	if decline_token_count > 0: strength += decline_token_count
	return strength

func get_conquest_cost() -> int:
	var cost: int = 2
	if has_mountain: cost += 1
	if has_fortress: cost += 1
	if has_troll_lair: cost += 1
	if has_encampment: cost += encampment_count
	if has_lost_tribe: cost += 1
	if token_count > 0: cost += token_count
	if decline_token_count > 0: cost += decline_token_count
	return cost

func get_adjacent_region_nodes() -> Array:
	var nodes: Array = []
	for path in adjacent_regions:
		var node = get_node_or_null(path)
		if node:
			nodes.append(node)
	return nodes

func is_occupied() -> bool:
	return owner_peer_id != -1 or decline_token_count > 0 or has_lost_tribe

func is_empty() -> bool:
	return not is_occupied()

func is_immune_to_conquest() -> bool:
	return has_hero or has_dragon or has_hole_in_ground
