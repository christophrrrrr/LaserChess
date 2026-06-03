extends Node
## NetworkManager — autoload singleton
## WebSocket client for matchmaking lobby + score relay.

# =============================================================
# SERVER URL
# =============================================================
var server_url: String = "wss://laserchess-webserver.onrender.com"

# === SIGNALS ===
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()
signal queued(time_mode: String)
signal queue_cancelled()
signal match_started(seed_val: int, opponent_name: String, opponent_elo: int, opponent_player_id: String, time_mode: String, opponent_hat: String, server_time: float)
signal opponent_score_updated(best_score: int)
signal match_result_received(result: String, my_score: int, opp_score: int, elo_change: int, opp_name: String, opp_elo: int, opp_player_id: String)
signal opponent_disconnected_sig(elo_change: int, my_score: int, opp_score: int, opp_name: String, opp_elo: int, opp_player_id: String)
signal opponent_ghost_updated(x: int, y: int)

# === STATE ===
var _socket: WebSocketPeer = null
var _was_connected: bool = false
var session_id: int = -1
var _heartbeat_timer: float = 0.0
const _HEARTBEAT_INTERVAL: float = 25.0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if _socket == null:
		return

	_socket.poll()
	var state = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _was_connected:
			_was_connected = true
		# Heartbeat ping — keeps Render.com proxy from killing idle connections
		_heartbeat_timer += delta
		if _heartbeat_timer >= _HEARTBEAT_INTERVAL:
			_heartbeat_timer = 0.0
			_send({"type": "ping"})
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
	_heartbeat_timer = 0.0
	set_process(false)

func is_online() -> bool:
	return _was_connected and _socket != null

func queue_for_match(time_mode: String) -> void:
	_send({
		"type": "queue_for_match",
		"time_mode": time_mode,
		"player_id": PlayerData.player_id,
		"name": PlayerData.player_name,
		"elo_bullet": PlayerData.elo_bullet,
		"elo_blitz":  PlayerData.elo_blitz,
		"elo_rapid":  PlayerData.elo_rapid,
		"hat":        PlayerData.equipped_hat,
	})

func leave_queue() -> void:
	_send({"type": "leave_queue"})

func send_score(best_score: int) -> void:
	_send({"type": "score_update", "best_score": best_score})

func send_match_end(best_score: int) -> void:
	_send({"type": "match_end", "best_score": best_score})

func send_ghost_pos(x: int, y: int) -> void:
	_send({"type": "ghost_pos", "x": x, "y": y})

## Send updated player info to server (call after name/elo changes)
func update_player_info() -> void:
	if not is_online():
		return
	_send({
		"type": "update_info",
		"name": PlayerData.player_name,
		"elo_bullet": PlayerData.elo_bullet,
		"elo_blitz":  PlayerData.elo_blitz,
		"elo_rapid":  PlayerData.elo_rapid,
	})

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
	if msg_type != "opponent_score":
		print("[NET] received: ", msg_type)
	match msg_type:
		"welcome":
			session_id = data.get("session_id", -1)
			connected_to_server.emit()
		"queued":
			queued.emit(data.get("time_mode", "bullet"))
		"queue_cancelled":
			queue_cancelled.emit()
		"match_start":
			match_started.emit(
				data.get("seed", 0),
				data.get("opponent", "???"),
				data.get("opponent_elo", 1000),
				data.get("opponent_player_id", ""),
				data.get("time_mode", "bullet"),
				data.get("opponent_hat", ""),
				data.get("server_time", 0.0)
			)
		"opponent_score":
			opponent_score_updated.emit(data.get("best_score", 0))
		"match_result":
			match_result_received.emit(
				data.get("result", "draw"),
				data.get("my_score", 0),
				data.get("opp_score", 0),
				data.get("elo_change", 0),
				data.get("opponent_name", "???"),
				data.get("opponent_elo", 1000),
				data.get("opponent_player_id", "")
			)
		"opponent_disconnected":
			opponent_disconnected_sig.emit(
				data.get("elo_change", 0),
				data.get("my_score", 0),
				data.get("opp_score", 0),
				data.get("opponent_name", "???"),
				data.get("opponent_elo", 1000),
				data.get("opponent_player_id", "")
			)
		"opponent_ghost":
			opponent_ghost_updated.emit(data.get("x", 0), data.get("y", 0))
		"ghost_pos":
			opponent_ghost_updated.emit(data.get("x", 0), data.get("y", 0))
		"pong":
			pass  # heartbeat response — connection is alive
