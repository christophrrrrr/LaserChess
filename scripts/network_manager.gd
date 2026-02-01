extends Node
## NetworkManager — autoload singleton
## WebSocket client for matchmaking lobby + score relay.

# =============================================================
# SERVER URL — change this to your Render URL!
# Local testing:  "ws://localhost:8765"
# Production:     "wss://your-app-name.onrender.com"
# =============================================================
var server_url: String = "wss://laserchess-webserver.onrender.com"

# === SIGNALS ===
signal connected_to_server(my_name: String)
signal connection_failed()
signal disconnected_from_server()
signal lobby_updated(players: Array, total_online: int)
signal match_started(seed_val: int, opponent_name: String)
signal opponent_score_updated(best_score: int)
signal opponent_disconnected()
signal challenge_failed(msg: String)

# === STATE ===
var _socket: WebSocketPeer = null
var _was_connected: bool = false
var my_id: int = -1
var my_name: String = ""

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if _socket == null:
		return
	
	_socket.poll()
	var state = _socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_connected:
			_was_connected = true
		while _socket.get_available_packet_count() > 0:
			var text = _socket.get_packet().get_string_from_utf8()
			_handle_message(text)
	
	elif state == WebSocketPeer.STATE_CLOSED:
		var was = _was_connected
		_socket = null
		_was_connected = false
		set_process(false)
		if was:
			disconnected_from_server.emit()
		else:
			connection_failed.emit()

# =====================
# PUBLIC API
# =====================

func connect_to_server() -> void:
	disconnect_from_server()
	_socket = WebSocketPeer.new()
	var err = _socket.connect_to_url(server_url)
	if err != OK:
		push_error("[NET] connect_to_url failed: ", err)
		connection_failed.emit()
		return
	set_process(true)

func disconnect_from_server() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_was_connected = false
	set_process(false)

## Use is_online() instead of is_connected() to avoid clash with Godot built-in.
func is_online() -> bool:
	return _was_connected and _socket != null

func join_lobby() -> void:
	_send({"type": "join_lobby"})

func leave_lobby() -> void:
	_send({"type": "leave_lobby"})

func challenge_player(target_id: int) -> void:
	_send({"type": "challenge", "target_id": target_id})

func send_score(best_score: int) -> void:
	_send({"type": "score_update", "best_score": best_score})

func send_match_end(best_score: int) -> void:
	_send({"type": "match_end", "best_score": best_score})

func rejoin_lobby() -> void:
	_send({"type": "rejoin_lobby"})

# =====================
# INTERNAL
# =====================

func _send(data: Dictionary) -> void:
	if _socket != null and _was_connected:
		_socket.send_text(JSON.stringify(data))

func _handle_message(text: String) -> void:
	var json = JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return
	
	var msg_type = data.get("type", "")
	match msg_type:
		"welcome":
			my_id = data.get("id", -1)
			my_name = data.get("name", "")
			connected_to_server.emit(my_name)
		"lobby_list":
			lobby_updated.emit(data.get("players", []), data.get("total_online", 0))
		"match_start":
			match_started.emit(data.get("seed", 0), data.get("opponent", "???"))
		"opponent_score":
			opponent_score_updated.emit(data.get("best_score", 0))
		"match_result":
			pass  # Client determines result from local scores
		"opponent_disconnected":
			opponent_disconnected.emit()
		"challenge_failed":
			challenge_failed.emit(data.get("msg", "Player unavailable"))
