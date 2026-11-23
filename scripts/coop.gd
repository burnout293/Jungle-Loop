class_name Coop
extends Node
## Two phones in one run. The host opens a room on the server (net.gd: four letters to give, or an
## invitation sent to a friend of his list), the guest joins it, and their WebRTC handshake (offer, answer,
## ICE candidates) passes through the room; then the two talk directly, the server is out of it. Once
## linked, both are on the home screen: the host starts Jouer or Histoire there, with his own items and
## powers for both (kit). Each phone runs its own hero on the same road (the same seed, scenery and road
## tier, see Game.coop_run) on the same clock (main.gd: no frame's time is lost) and says where he is 20
## times a second; the other one is drawn beside him, recoloured (render.gd), a few hundredths of a second
## in the past so that he moves smoothly between two of his states (view). Whoever falls floats in a
## bubble that follows the other, who jumps into it to bring him back; the run ends when both are in bubbles.
##
## Messages, JSON: on "ctl" (reliable, in order) hello, kit, ping / pong, start, bubble, rescue, back, end,
## bye; on "pos" (unreliable: a late one is useless) "s", the hero's state at his run time "at".

signal changed                          # the state, the partner or the text to show changed
signal message(msg: Dictionary)         # a message about the run, for main.gd

const LINK_TIME := 30.0                 # seconds to get connected before giving up
const POLL := 0.4                       # seconds between two looks at the room while connecting
const SEND_EVERY := 0.05                # seconds between two states sent (20 a second)
const STEP_MAX := 0.034                 # the run's longest step (see split)
const MAX_STEPS := 12                   # ... and how many in one frame at most
const BUF_MAX := 40                     # states kept to draw him from

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
var relay := false                     # the server gave a relay (TURN) for this run
var _ping_t := 0.0
var _pinged := false
var invited := ""                       # the friend the host sent an invitation to (his name)
var down_t := 0.0                       # (0.55) seconds the link has said « disconnected »
var kit := {}                           # the guest's copy of the host's items and powers: {up, eq, biome}
var buf: Array = []                     # the partner's states (pos), in the order of his run time "at"
var late := 0.1                         # seconds: how far behind his newest state arrives (smoothed)
var jitter := 0.02                      # ... and how much that varies
var shown := -1.0                       # the delay he is drawn with: follows delay() gently (see view)
var _view_t := 0.0

## Whether this build can talk WebRTC: built in in browsers, a GDExtension elsewhere (not installed).
static func supported() -> bool:
	if _supported < 0:                            # (asked once: elsewhere than a browser each try prints errors)
		var p = WebRTCPeerConnection.new()
		_supported = 1 if p.initialize({}) == OK else 0
		p.close()
	return _supported == 1

static var _supported := -1

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
	var ice = await net.ice(save)
	if role != "host" or state != "opening":
		return
	if not _make_peer(ice):
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
	var ice = await net.ice(save)
	if role != "guest" or state != "joining":
		return
	if not _make_peer(ice):
		return
	_state("linking", "")
	_signal({"t": "hi"})                         # the host makes its offer on this

## Leaves the room (and the run's link) for good.
func leave() -> void:
	if state == "ready":
		send({"t": "bye"})
	if role == "host" and room != "" and net != null:
		net.close_room(save, room)               # (its invitation goes with it)
	if peer != null:
		peer.close()
	peer = null
	ctl = null
	pos = null
	since = 0
	link_t = 0
	mate = {}
	kit = {}
	invited = ""
	clear_states()
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

## `ice`: the server's answer (net.ice), its relay added to the STUN servers of reglages/reseau.txt.
func _make_peer(ice: Dictionary) -> bool:
	var servers: Array = Net.ice_servers() + Array(ice.get("iceServers", []))
	relay = ice.get("turn", "") == "on" or Net.turn.has("urls")
	var config = {"iceServers": servers}
	if Net.relay_only:
		config["iceTransportPolicy"] = "relay"
	print("coop: %d ICE servers, relay %s%s" % [servers.size(), relay, " (relay only)" if Net.relay_only else ""])
	peer = WebRTCPeerConnection.new()
	if peer.initialize(config) != OK:
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
			"no":                                # the friend invited said « Pas maintenant »
				if role == "host" and state == "waiting":
					_fail("%s ne peut pas jouer pour l'instant." % (invited if invited != "" else "Ton ami"))
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
				_fail("La connexion n'a pas pu se faire, même par le relais." if relay else "La connexion directe n'a pas pu se faire (en 4G / 5G, c'est souvent bloqué) et le serveur n'a pas encore de relais.")
				return
		if ctl != null and ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			_state("ready", "")
			send({"t": "hello", "name": save.get("online", {}).get("name", "Pépito"), "tier": tier(save)})
			_ping()
	if state == "ready":
		var cs = peer.get_connection_state()
		down_t = down_t + delta if cs == WebRTCPeerConnection.STATE_DISCONNECTED else 0.0
		if cs in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED] or down_t > Race.DOWN_GRACE:
			_fail("L'autre joueur est parti.")   # (0.55: « disconnected » is often only a moment, as when a phone
			message.emit({"t": "bye"})           # turns or comes back from another app: a few seconds first)
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
			var got = clampf(Time.get_ticks_msec() / 1000.0 - _ping_at, 0.0, 2.0)
			rtt = got if not _pinged else rtt + (got - rtt) * 0.3
			_pinged = true
		"kit":
			kit = {"up": m.get("up", {}), "eq": m.get("eq", []), "biome": int(m.get("biome", 0))}
			changed.emit()
		"bye":
			_fail("L'autre joueur est parti.")
			message.emit(m)
		_:
			message.emit(m)

## What the road may ask of this player: 2 with the Vol, 1 with Double saut, 0 on foot.
static func tier(s: Dictionary) -> int:
	return tier_of(SaveData.loadout(s))

## The same for a loadout (for two: the host's, worn by both).
static func tier_of(up: Dictionary) -> int:
	return 2 if int(up.get("flight", 0)) > 0 else (1 if int(up.get("doubleJump", 0)) > 0 else 0)

## For two, the run goes through every bit of real time it owes (main.gd): alone, a frame longer than
## STEP_MAX slows the game down, which for two would leave him behind the other for good. In steps of
## STEP_MAX at most, MAX_STEPS in a frame at most (the rest waits for the next frame).
static func split(owed: float) -> Array:
	var out = []
	while owed > 0.0005 and out.size() < MAX_STEPS:
		var h = minf(STEP_MAX, owed)
		owed -= h
		out.append(h)
	return out

# ---------- the partner, drawn smoothly ----------

func clear_states() -> void:
	buf.clear()
	late = 0.1
	jitter = 0.02
	shown = -1.0

## One of his states arrived (pos: some late, some out of order, some lost), `my_t` this run's time now.
func push(m: Dictionary, my_t: float) -> void:
	var t = float(m.get("at", -1.0))
	if t < 0:
		return
	var i = buf.size()
	while i > 0 and float(buf[i - 1]["at"]) > t:
		i -= 1
	if i > 0 and is_equal_approx(float(buf[i - 1]["at"]), t):
		return                                   # (the same one twice)
	buf.insert(i, m)
	while buf.size() > BUF_MAX:
		buf.pop_front()
	var lag = my_t - t
	late += (lag - late) * 0.1
	jitter += (absf(lag - late) - jitter) * 0.1

## How far in the past he is drawn: enough to always have his next state in hand.
func delay() -> float:
	return clampf(late + 2.0 * jitter + SEND_EVERY, 0.06, 0.35)

## Where to draw him at this run's time `my_t` (empty: nothing heard yet). The delay follows the network
## at 10 % of the time at most: he never jolts forward or back when it changes, he runs a touch faster or
## slower for a moment.
func view(my_t: float) -> Dictionary:
	var target = delay()
	if shown < 0:
		shown = target
	else:
		var most = maxf(0.0, my_t - _view_t) * 0.1
		shown += clampf(target - shown, -most, most)
	_view_t = my_t
	return sample(buf, my_t - shown)

## His state at his run time T, between the two states around it; past the newest one, carried on at his
## speed (a quarter of a second at most), his height held.
static func sample(states: Array, T: float) -> Dictionary:
	if states.is_empty():
		return {}
	if T <= float(states[0]["at"]):
		return states[0].duplicate()
	var last: Dictionary = states[-1]
	if T >= float(last["at"]):
		var s = last.duplicate()
		s["x"] = float(last["x"]) + float(last.get("v", 0.0)) * minf(T - float(last["at"]), 0.25)
		s["at"] = minf(T, float(last["at"]) + 0.25)
		return s
	var i = states.size() - 1
	while i > 0 and float(states[i - 1]["at"]) > T:
		i -= 1
	var a: Dictionary = states[i - 1]
	var b: Dictionary = states[i]
	var k = (T - float(a["at"])) / maxf(0.0001, float(b["at"]) - float(a["at"]))
	var s = (a if k < 0.5 else b).duplicate()        # on the ground or not, flying, in a bubble: the nearer one
	for key in ["x", "y", "vy", "ph"]:
		s[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), k)
	s["at"] = T
	return s
