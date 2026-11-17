extends Node

signal peer_joined(id: int)
signal peer_left(id: int)
signal status(message: String)

const PORT := 7777

var active := false
var mode := "even"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(match_mode: String) -> bool:
	stop()
	mode = match_mode
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		status.emit("Could not open port %d. Windows Firewall may be blocking it. Allow the game on private networks, then host again." % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	status.emit("Hosting on port %d. Your address: %s" % [PORT, local_ips()])
	return true

func join_ip(ip: String, match_mode: String) -> bool:
	var trimmed := ip.strip_edges()
	if trimmed.is_empty():
		status.emit("Type your friend's IP address.")
		return false
	stop()
	mode = match_mode
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(trimmed, PORT)
	if err != OK:
		status.emit("Could not reach %s. If a firewall warning appeared, allow the game and try again." % trimmed)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	status.emit("Joining %s..." % trimmed)
	return true

func stop() -> void:
	active = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func local_ips() -> String:
	var nice: PackedStringArray = []
	for ip in IP.get_local_addresses():
		if ip.contains(":"):
			continue
		if ip.begins_with("127."):
			continue
		nice.append(ip)
	if nice.is_empty():
		return "this computer"
	return ", ".join(nice)

func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)
	if multiplayer.is_server():
		share_mode.rpc_id(id, mode)
		status.emit("A student entered the court.")

func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)
	status.emit("The other student left the court.")

func _on_connected_to_server() -> void:
	status.emit("Connected. Sword and spell are both required.")

func _on_connection_failed() -> void:
	active = false
	status.emit("The join failed. Check the IP, and allow the game through the firewall if Windows asked.")

func _on_server_disconnected() -> void:
	active = false
	status.emit("The host closed the court.")

@rpc("authority", "reliable")
func share_mode(match_mode: String) -> void:
	mode = match_mode
	Game.court_mode = match_mode
	Game.travel(Game.Place.COURT)
	Game.court_live = true
	Game.changed.emit()
	Game.toast.emit("Online %s match." % ("Open" if match_mode == "open" else "Even"))
