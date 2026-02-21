extends Node

var multiplayer_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
var _hosted_lobby_id = 0

const LOBBY_NAME = "SmallWorld"
const LOBBY_MODE = "PvP"
var lobby_max_members = 6

var is_owned: bool = false
var steam_app_id: int = 480 # Test game app id
var steam_id: int = 0
var steam_username: String = ""

func _init():
	print("Init Steam")
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))

func _ready() -> void:
	Steam.connect("lobby_created", _on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

func _process(_delta):
	Steam.run_callbacks()

func initialize_steam():
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam Initialize?: %s " % initialize_response)
	
	if initialize_response['status'] > 0:
		print("Failed to init Steam! Shutting down. %s" % initialize_response)
		get_tree().quit()
		
	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	print("steam_id %s" % steam_id)
	
	if is_owned == false:
		print("User does not own game!")
		get_tree().quit()

func become_host():
	print("Starting host!")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_max_members)

func list_lobbies():
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	# NOTE: If you are using the test app id, you will need to apply a filter on your game name
	# Otherwise, it may not show up in the lobby list of your clients
	Steam.addRequestLobbyListStringFilter("name", LOBBY_NAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_lobby_created(connect_status: int, lobby_id):
	print("On lobby created")
	if connect_status == Steam.RESULT_OK:
		print("Created lobby: %s" % lobby_id)
		
		_hosted_lobby_id = lobby_id

		multiplayer_peer.host_with_lobby(lobby_id)
		#multiplayer.multiplayer_peer = multiplayer_peer
		
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)

func join_as_client(lobby_id):
	print("Joining lobby %s" % lobby_id)
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int) -> void:
	print("On lobby joined %s" % lobby_id)
	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		print("Lobby host already in lobby, bypassing...")
		return
		
	multiplayer_peer.connect_to_lobby(lobby_id)
	multiplayer.multiplayer_peer = multiplayer_peer
