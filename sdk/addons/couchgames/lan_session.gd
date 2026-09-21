extends Node
## Direct ENet LAN session. One computer hosts; others join by address.
## The game host is a player's Godot process, separate from the Rust desktop host.

signal hosted
signal connected
signal connection_failed(reason: String)
signal disconnected(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT := 24567
const PROTOCOL := "giga-couch-lan-1"

var port := DEFAULT_PORT
var max_clients := 7
var status := "idle"
var last_error := ""
var _signals_bound := false


func _process(_delta: float) -> void:
	var api := multiplayer
	if api == null or api.multiplayer_peer == null:
		return
	# Custom MultiplayerAPI branches are not polled by SceneTree.
	if api != get_tree().get_multiplayer():
		api.poll()


func is_host() -> bool:
	return status == "hosting" and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func unique_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()


func connected_peers() -> PackedInt32Array:
	if multiplayer.multiplayer_peer == null:
		return PackedInt32Array()
	return multiplayer.get_peers()


func host_game(bind_port: int = DEFAULT_PORT) -> Error:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(bind_port, max_clients)
	if err != OK:
		last_error = "Could not host on port %d." % bind_port
		status = "idle"
		connection_failed.emit(last_error)
		return err
	port = bind_port
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	status = "hosting"
	hosted.emit()
	return OK


func join_game(address: String, bind_port: int = DEFAULT_PORT) -> Error:
	close_session()
	var trimmed := address.strip_edges()
	if trimmed.is_empty():
		last_error = "Enter the host computer's address."
		connection_failed.emit(last_error)
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(trimmed, bind_port)
	if err != OK:
		last_error = "Could not reach %s:%d." % [trimmed, bind_port]
		connection_failed.emit(last_error)
		return err
	port = bind_port
	multiplayer.multiplayer_peer = peer
	_bind_signals()
	status = "connecting"
	return OK


func close_session() -> void:
	_unbind_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if status in ["hosting", "connecting", "connected"]:
		var reason := last_error if last_error != "" else "Session closed."
		status = "idle"
		disconnected.emit(reason)
	else:
		status = "idle"


func parse_address(value: String) -> Dictionary:
	var trimmed := value.strip_edges()
	var bind_port := port if port > 0 else DEFAULT_PORT
	var host := trimmed
	if trimmed.contains(":"):
		var parts := trimmed.rsplit(":", true, 1)
		host = parts[0]
		if parts[1].is_valid_int():
			bind_port = int(parts[1])
	return {"host": host, "port": bind_port}


func local_addresses() -> PackedStringArray:
	return collect_lan_addresses(IP.get_local_interfaces())


static func collect_lan_addresses(interfaces: Array) -> PackedStringArray:
	var ranked: Array[Dictionary] = []
	for iface in interfaces:
		if not (iface is Dictionary):
			continue
		var name := str(iface.get("name", "")).to_lower()
		var friendly := str(iface.get("friendly", "")).to_lower()
		if _skip_interface(name):
			continue
		var addrs: Variant = iface.get("addresses", PackedStringArray())
		for address in addrs:
			var text := str(address)
			if _skip_ip(text):
				continue
			var score := _ip_score(text)
			if name.begins_with("en") or "wifi" in name or "wlan" in name or "wi-fi" in friendly:
				score += 8
			ranked.append({"ip": text, "score": score})
	ranked.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var result: PackedStringArray = PackedStringArray()
	for row in ranked:
		var ip := str(row["ip"])
		if ip not in result:
			result.append(ip)
	return result


static func _skip_interface(name: String) -> bool:
	for prefix in ["lo", "awdl", "llw", "utun", "bridge", "gif", "stf", "anpi", "ap", "vbox", "docker"]:
		if name == prefix or name.begins_with(prefix):
			return true
	return false


static func _skip_ip(text: String) -> bool:
	if text.is_empty() or ":" in text:
		return true
	if text.begins_with("127.") or text.begins_with("0.") or text.begins_with("255."):
		return true
	return false


static func _ip_score(text: String) -> int:
	if text.begins_with("192.168."):
		return 30
	if text.begins_with("10."):
		return 20
	var parts := text.split(".")
	if parts.size() == 4 and parts[0] == "172":
		var second := int(parts[1])
		if second >= 16 and second <= 31:
			return 18
	if text.begins_with("169.254."):
		return 2
	return 10


func _bind_signals() -> void:
	if _signals_bound:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_signals_bound = true


func _unbind_signals() -> void:
	if not _signals_bound:
		return
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	_signals_bound = false


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	status = "connected"
	last_error = ""
	connected.emit()


func _on_connection_failed() -> void:
	last_error = "The host did not accept the connection."
	status = "idle"
	_unbind_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
	last_error = "The host left the session."
	status = "idle"
	_unbind_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	disconnected.emit(last_error)
