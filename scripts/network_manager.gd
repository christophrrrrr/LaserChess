extends Node
## NetworkManager — autoload singleton
## Handles WebSocket connection to the relay server.

# === CONFIG ===
var server_url: String = "ws://localhost:8765"

# === CONNECTION STATE ===
enum State { DISCONNECTED, CONNECTING, CONNECTED, QUEUED, IN_MATCH }
var state: State = State.DISCONNECTED

# === SIGNALS ===
signal connected()
signal disconnected()
signal queued()
signal match_found(match_seed: int, opponent_name: String)
signal opponent_score_updated(best_score: int)
signal match_result_received(result: String, my_score: int, opponent_score: int)
signal opponent_disconnected(my_score: int, opponent_score: int)
signal error_received(msg: String)

# === INTERNALS ===
var _socket: WebSocketPeer = null
var _my_name: String = ""
var _opponent_name: String = ""
var _match_id: String = ""

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if _socket == null:
		return
	
	_socket.poll()
	
	var socket_state = _socket.get_ready_state()
	
	match socket_state:
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING:
				state = State.CONNECTED
				connected.emit()
			
			# Read all available packets
			while _socket.get_available_packet_count() > 0:
				var packet = _socket.get_packet()
				var text = packet.get_string_from_utf8()
				_handle_message(text)
		
		WebSocketPeer.STATE_CLOSING:
			pass  # Wait for close to finish
		
		WebSocketPeer.STATE_CLOSED:
			var code = _socket.get_close_code()
			print("[NET] Connection closed (code: ", code, ")")
			_socket = null
			state = State.DISCONNECTED
			set_process(false)
			disconnected.emit()

# =====================
# PUBLIC API
# =====================

func connect_to_server(url: String = "") -> void:
	if url != "":
		server_url = url
	
	if _socket != null:
		_socket.close()
		_socket = null
	
	_socket = WebSocketPeer.new()
	var err = _socket.connect_to_url(server_url)
	
	if err != OK:
		push_error("[NET] Failed to connect: ", err)
		state = State.DISCONNECTED
		error_received.emit("Failed to connect to server")
		return
	
	state = State.CONNECTING
	set_process(true)
	print("[NET] Connecting to ", server_url)

func join_queue() -> void:
	_send({"type": "queue"})

func leave_queue() -> void:
	_send({"type": "leave_queue"})
	state = State.CONNECTED

func send_score_update(best_score: int) -> void:
	_send({"type": "score_update", "best_score": best_score})

func send_match_end(best_score: int) -> void:
	_send({"type": "match_end", "best_score": best_score})

func disconnect_from_server() -> void:
	if _socket != null:
		_socket.close()
	state = State.DISCONNECTED

func is_connected_to_server() -> bool:
	return state != State.DISCONNECTED and state != State.CONNECTING

func get_my_name() -> String:
	return _my_name

func get_opponent_name() -> String:
	return _opponent_name

# =====================
# MESSAGE HANDLING
# =====================

func _handle_message(text: String) -> void:
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("[NET] Bad JSON: ", text)
		return
	
	var data = json.data
	if not data is Dictionary:
		return
	
	var msg_type = data.get("type", "")
	
	match msg_type:
		"welcome":
			_my_name = data.get("name", "")
			print("[NET] Server assigned name: ", _my_name)
		
		"queued":
			state = State.QUEUED
			queued.emit()
			print("[NET] In queue, waiting for opponent...")
		
		"match_found":
			state = State.IN_MATCH
			_match_id = data.get("match_id", "")
			_opponent_name = data.get("opponent", "???")
			var match_seed = data.get("seed", 0)
			match_found.emit(match_seed, _opponent_name)
			print("[NET] Match found! vs ", _opponent_name, " seed=", match_seed)
		
		"opponent_score":
			var best = data.get("best_score", 0)
			opponent_score_updated.emit(best)
		
		"match_result":
			var result = data.get("result", "draw")
			var my_s = data.get("my_score", 0)
			var opp_s = data.get("opponent_score", 0)
			state = State.CONNECTED
			_match_id = ""
			match_result_received.emit(result, my_s, opp_s)
			print("[NET] Match result: ", result, " (", my_s, " - ", opp_s, ")")
		
		"opponent_disconnected":
			var my_s = data.get("my_score", 0)
			var opp_s = data.get("opponent_score", 0)
			state = State.CONNECTED
			_match_id = ""
			opponent_disconnected.emit(my_s, opp_s)
			print("[NET] Opponent disconnected. Win by default.")
		
		"left_queue":
			state = State.CONNECTED
		
		"error":
			var msg = data.get("msg", "Unknown error")
			error_received.emit(msg)
			push_warning("[NET] Server error: ", msg)

func _send(data: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_warning("[NET] Cannot send, not connected")
		return
	_socket.send_text(JSON.stringify(data))
