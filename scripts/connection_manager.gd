extends Node

func _ready():
	#if OS.has_feature("dedicated_server"):
		#print("Starting dedicated server...")
		#%NetworkManager.become_host(true)
	SteamManager.initialize_steam()
	Steam.lobby_match_list.connect(_on_lobby_match_list)

func become_host():
	print("Become host pressed")
	SteamManager.become_host()

func list_lobbies():
	print("List lobbies")
	%"Options".hide()
	%"Lobbies".show()
	SteamManager.list_lobbies()
	
func list_steam_lobbies():
	print("List Steam lobbies")
	SteamManager.list_lobbies()

func join_lobby(lobby_id = 0):
	print("Joining lobby %s" % lobby_id)
	SteamManager.join_as_client(lobby_id)

func _on_lobby_match_list(lobbies: Array):
	print("On lobby match list")
	
	for lobby_child in $"../Steam_HUD/Panel/Lobbies/VBoxContainer".get_children():
		lobby_child.queue_free()
		
	for lobby in lobbies:
		var lobby_name: String = Steam.getLobbyData(lobby, "name")
		
		if lobby_name != "":
			var lobby_mode: String = Steam.getLobbyData(lobby, "mode")
			
			var lobby_button: Button = Button.new()
			lobby_button.set_text(lobby_name + " | " + lobby_mode)
			lobby_button.set_size(Vector2(100, 30))
			lobby_button.add_theme_font_size_override("font_size", 8)
			
			lobby_button.set_name("lobby_%s" % lobby)
			lobby_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lobby_button.connect("pressed", Callable(self, "join_lobby").bind(lobby))
			
			$"../Steam_HUD/Panel/Lobbies/VBoxContainer".add_child(lobby_button)
