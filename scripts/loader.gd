extends CanvasLayer

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var player_count_label = $Panel/VBoxContainer/PlayerCountLabel
@onready var players_vbox = $Panel/VBoxContainer/PlayersVBox

func _ready() -> void:
	NetworkManager.player_list_updated.connect(_on_player_list_updated)
	GameManager.all_players_ready.connect(_on_all_players_ready)
	title_label.text = tr("UI_WAITING_TITLE")
	_refresh()

func _on_player_list_updated() -> void:
	_refresh()

func _refresh() -> void:
	var current: int = NetworkManager.players.size()
	var required: int = NetworkManager.required_players

	player_count_label.text = "%s / %s %s" % [
		current, required, tr("UI_PLAYERS_CONNECTED")]

	for child in players_vbox.get_children():
		child.queue_free()

	for peer_id in NetworkManager.players.keys():
		var row = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = NetworkManager.players[peer_id]["name"]
		row.add_child(name_label)

		var ready_label = Label.new()
		ready_label.text = "✓"
		ready_label.modulate = Color.GREEN
		row.add_child(ready_label)

		players_vbox.add_child(row)

func update_player_count(current: int, required: int) -> void:
	player_count_label.text = "%s / %s %s" % [
		current, required, tr("UI_PLAYERS_CONNECTED")]

func _on_all_players_ready() -> void:
	queue_free()
