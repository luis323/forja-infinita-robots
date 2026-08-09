class_name RobotLanManager
extends Node

signal status_changed(message: String, player_count: int, can_start: bool)
signal battle_ready(builds: Array[Dictionary], local_index: int)
signal heavy_received(fighter_index: int)

const PORT := 27841
const MAX_CLIENTS := 3

var local_build := {}
var submitted_builds := {}
var battle_peer_ids: Array[int] = []
var hosting := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(build: Dictionary) -> Error:
	close_connection()
	local_build = build.duplicate(true)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(PORT, MAX_CLIENTS)
	if result != OK:
		status_changed.emit("No se pudo abrir la sala LAN.", 0, false)
		return result
	multiplayer.multiplayer_peer = peer
	hosting = true
	submitted_builds[1] = local_build
	status_changed.emit("SALA ABIERTA · IP %s · esperando robots" % get_local_ip(), 1, false)
	return OK

func join_game(address: String, build: Dictionary) -> Error:
	close_connection()
	local_build = build.duplicate(true)
	var peer := ENetMultiplayerPeer.new()
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		clean_address = "127.0.0.1"
	var result := peer.create_client(clean_address, PORT)
	if result != OK:
		status_changed.emit("No se pudo conectar a %s" % clean_address, 0, false)
		return result
	multiplayer.multiplayer_peer = peer
	hosting = false
	status_changed.emit("CONECTANDO A %s…" % clean_address, 0, false)
	return OK

func start_battle() -> void:
	if not hosting:
		status_changed.emit("Solo el anfitrión puede comenzar.", submitted_builds.size(), false)
		return
	if submitted_builds.size() < 2:
		status_changed.emit("Falta al menos otro robot.", submitted_builds.size(), false)
		return
	var ids: Array[int] = []
	for peer_id in submitted_builds:
		ids.append(int(peer_id))
	ids.sort()
	var builds: Array[Dictionary] = []
	for peer_id in ids:
		builds.append(Dictionary(submitted_builds[peer_id]).duplicate(true))
	_receive_battle.rpc(builds, ids)

func request_heavy(fighter_index: int) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		heavy_received.emit(fighter_index)
	elif multiplayer.is_server():
		_receive_heavy.rpc(fighter_index)
	else:
		_request_heavy.rpc_id(1, fighter_index)

func close_connection() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	hosting = false
	submitted_builds.clear()
	battle_peer_ids.clear()

func get_local_ip() -> String:
	var addresses := IP.get_local_addresses()
	for prefix in ["192.168.", "10.", "172."]:
		for address in addresses:
			if address.begins_with(prefix) and not ":" in address:
				return address
	return "IP no detectada"

func _on_peer_connected(_peer_id: int) -> void:
	if hosting:
		_broadcast_lobby_status()

func _on_peer_disconnected(peer_id: int) -> void:
	if hosting:
		submitted_builds.erase(peer_id)
		_broadcast_lobby_status()

func _on_connected_to_server() -> void:
	_submit_build.rpc_id(1, local_build)
	status_changed.emit("CONECTADO · robot enviado al anfitrión", 1, false)

func _on_connection_failed() -> void:
	status_changed.emit("CONEXIÓN FALLIDA · revisa la IP y el Wi-Fi", 0, false)

func _on_server_disconnected() -> void:
	status_changed.emit("EL ANFITRIÓN CERRÓ LA SALA", 0, false)

func _broadcast_lobby_status() -> void:
	var count := submitted_builds.size()
	_sync_lobby_status.rpc(count)

@rpc("any_peer", "call_remote", "reliable")
func _submit_build(build: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0 or submitted_builds.size() >= 4 and not submitted_builds.has(sender):
		return
	submitted_builds[sender] = build.duplicate(true)
	_broadcast_lobby_status()

@rpc("authority", "call_local", "reliable")
func _sync_lobby_status(count: int) -> void:
	status_changed.emit("ROBOTS CONECTADOS: %d / 4" % count, count, hosting and count >= 2)

@rpc("authority", "call_local", "reliable")
func _receive_battle(builds: Array[Dictionary], peer_ids: Array[int]) -> void:
	battle_peer_ids = peer_ids.duplicate()
	var local_peer_id := multiplayer.get_unique_id()
	var local_index := battle_peer_ids.find(local_peer_id)
	battle_ready.emit(builds, maxi(0, local_index))

@rpc("any_peer", "call_remote", "reliable")
func _request_heavy(fighter_index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if fighter_index < 0 or fighter_index >= battle_peer_ids.size():
		return
	if battle_peer_ids[fighter_index] != sender:
		return
	_receive_heavy.rpc(fighter_index)

@rpc("authority", "call_local", "reliable")
func _receive_heavy(fighter_index: int) -> void:
	heavy_received.emit(fighter_index)
