class_name Coop
extends Node
## Two phones in one run (the Run illimitée). The host opens a room on the server (net.gd: four letters to
## give), the guest joins it, and their WebRTC handshake (offer, answer, ICE candidates) passes through the
## room; then the two talk directly, the server is out of it. Each phone runs its own hero on the same road
## (the same seed, starting scenery and road tier, see Game.Run.coop) and says where he is about 15 times a
## second; the other one is drawn beside him, recoloured (render.gd). Whoever falls floats in a bubble that
## follows the other, who jumps into it to bring him back; the run ends when both are in bubbles.
##
## Messages, JSON: on "ctl" (reliable, in order) hello, ping / pong, start, bubble, rescue, back, end, bye;
## on "pos" (unreliable: a late one is useless) "s", the hero's state.

signal changed                          # the state, the partner or the text to show changed
signal message(msg: Dictionary)         # a message about the run, for main.gd

const LINK_TIME := 30.0                 # seconds to get connected before giving up
const POLL := 0.4                       # seconds between two looks at the room while connecting

var net: Net
var save: Dictionary
var state := "idle"                     # idle | opening | waiting | joining | linking | ready | failed
var role := ""                          # host | guest
var room := ""
var seed := 0
var info := ""                          # what went wrong, for the screen
var mate := {}                          # {name, tier}
var rtt := 0.15                         # seconds, measured by ping / pong
var peer: WebRTCPeerConnection = null
var ctl: WebRTCDataChannel = null
var pos: WebRTCDataChannel = null
var since := 0
var poll_t := 0.0
var link_t := 0.0
var busy := false
var _ping_at := 0.0
var _ping_t := 0.0

## Whether this build can talk WebRTC: built in in browsers, a GDExtension elsewhere (not installed).
static func supported() -> bool:
	var p = WebRTCPeerConnection.new()
	var ok = p.initialize({}) == OK
	p.close()
	return ok

func busy_state() -> bool:
	return state in ["opening", "waiting", "joining", "linking"]

## Opens a room for a run on `seed_`: its four letters show on the screen.
func host(seed_: int) -> void:
	leave()
	role = "host"
	seed = seed_
	_state("opening", "")
	var r = await net.open_room(save, seed)
	if role != "host" or state != "opening":
		return
	if r.has("error"):
		_fail("Impossible d'ouvrir un salon (%s)." % r["error"])
		return
	room = r["room"]
	if not _make_peer():
		return
	_state("waiting", "")

## Joins the room of these four letters: the seed comes with it.
func join(code: String) -> void:
	leave()
	role = "guest"
	room = code.strip_edges().to_upper()
	_state("joining", "")
	var r = await net.join_room(save, room)
	if role != "guest" or state != "joining":
		return
	if r.has("error"):
		_fail({"unknown": "Aucun salon « %s »." % room, "full": "Ce salon est déjà complet.", "self": "C'est ton propre salon."}.get(r["error"], "Impossible de rejoindre (%s)." % r["error"]))
		return
	seed = int(r["seed"])
	mate = {"name": str(r.get("host", "")), "tier": 0}
	if not _make_peer():
		return
	_state("linking", "")
	_signal({"t": "hi"})                         # the host makes its offer on this

## Leaves the room (and the run's link) for good.
func leave() -> void:
	if state == "ready":
		send({"t": "bye"})
	if peer != null:
		peer.close()
	peer = null
	ctl = null
	pos = null
	since = 0
	link_t = 0
	mate = {}
	room = ""
	if state != "idle":
		_state("idle", "")

func send(msg: Dictionary, reliable: bool = true) -> void:
	var ch = ctl if reliable else pos
	if ch != null and ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		ch.put_packet(JSON.stringify(msg).to_utf8_buffer())

# ---------- inside ----------

func _state(s: String, text: String) -> void:
	state = s
	info = text
	changed.emit()

func _fail(text: String) -> void:
	if peer != null:
		peer.close()
	peer = null
	ctl = null
	pos = null
	_state("failed", text)

func _make_peer() -> bool:
	peer = WebRTCPeerConnection.new()
	if peer.initialize({"iceServers": Net.ice_servers()}) != OK:
		_fail("Ce navigateur ne sait pas jouer à deux.")
		return false
	peer.session_description_created.connect(_on_description)
	peer.ice_candidate_created.connect(_on_candidate)
	ctl = peer.create_data_channel("ctl", {"negotiated": true, "id": 1})
	pos = peer.create_data_channel("pos", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	since = 0
	link_t = 0
	return true

func _on_description(type: String, sdp: String) -> void:
	peer.set_local_description(type, sdp)
	_signal({"t": type, "sdp": sdp})

func _on_candidate(media: String, index: int, name: String) -> void:
	_signal({"t": "ice", "m": media, "i": index, "n": name})

func _signal(data: Dictionary) -> void:
	net.send_signal(save, room, JSON.stringify(data))

## The room's new messages from the other side: the handshake.
func _read() -> void:
	if busy:
		return
	busy = true
	var r = await net.read_signals(save, room, since)
	busy = false
	if peer == null or r.has("error"):
		return
	for it in r.get("items", []):
		since = maxi(since, int(it["seq"]))
		var d = JSON.parse_string(str(it["data"]))
		if not d is Dictionary:
			continue
		match str(d.get("t", "")):
			"hi":
				if role == "host" and state == "waiting":
					_state("linking", "")
					peer.create_offer()
			"offer", "answer":
				peer.set_remote_description(d["t"], str(d["sdp"]))
			"ice":
				peer.add_ice_candidate(str(d["m"]), int(d["i"]), str(d["n"]))

func _process(delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if state in ["waiting", "linking"]:
		poll_t -= delta
		if poll_t <= 0:
			poll_t = POLL
			_read()
		if state == "linking":
			link_t += delta
			if link_t > LINK_TIME or peer.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
				_fail("La connexion n'a pas pu se faire (réseau trop fermé ?).")
				return
		if ctl != null and ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			_state("ready", "")
			send({"t": "hello", "name": save.get("online", {}).get("name", "Pépito"), "tier": tier(save)})
			_ping()
	if state == "ready":
		if peer.get_connection_state() in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED, WebRTCPeerConnection.STATE_DISCONNECTED]:
			_fail("L'autre joueur est parti.")
			message.emit({"t": "bye"})
			return
		_ping_t -= delta
		if _ping_t <= 0:
			_ping()
		for ch in [ctl, pos]:
			while ch != null and ch.get_available_packet_count() > 0:
				var m = JSON.parse_string(ch.get_packet().get_string_from_utf8())
				if m is Dictionary:
					_on_message(m)

func _ping() -> void:
	_ping_t = 2.0
	_ping_at = Time.get_ticks_msec() / 1000.0
	send({"t": "ping"})

func _on_message(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"hello":
			mate = {"name": str(m.get("name", "Pépito")).left(16), "tier": int(m.get("tier", 0))}
			changed.emit()
		"ping":
			send({"t": "pong"})
		"pong":
			rtt = clampf(Time.get_ticks_msec() / 1000.0 - _ping_at, 0.0, 2.0)
		"bye":
			_fail("L'autre joueur est parti.")
			message.emit(m)
		_:
			message.emit(m)

## What the road may ask of this player: 2 with the Vol, 1 with Double saut, 0 on foot. In coop the road
## is laid for the lesser of the two, so both get through.
static func tier(s: Dictionary) -> int:
	var up = SaveData.loadout(s)
	return 2 if up.get("flight", 0) > 0 else (1 if up.get("doubleJump", 0) > 0 else 0)
