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
	var result: PackedStringArray = PackedStringArray()
	for address in IP.get_local_addresses():
		var text := str(address)
		if text.begins_with("127.") or text.begins_with("0.") or ":" in text:
			continue
		if text not in result:
			result.append(text)
	return result


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
