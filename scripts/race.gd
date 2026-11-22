class_name Race
extends Node
## The race for four (0.48). The host opens a race room on the server (net.gd: four letters to give, or
## friends of his list invited into it), up to three guests join it, and each guest's WebRTC handshake with
## the host passes through the room; then the phones talk directly: a star, the host in the middle, who
## passes on what each one says to the others. Before the start, in the lobby, everyone bets coins on the
## one he thinks will go furthest (himself by default). The host starts: everybody runs the same road (the
## same seed, scenery and road tier: Game.coop_run, the host's items and powers for all, on the same clock),
## with the others drawn as ghosts (render.gd). Whoever falls is out and watches the rest; when the last one
## falls (or can no longer be caught), the host works out the result and the pot is shared (settle).
##
## Messages, JSON: on "ctl" (reliable, in order) hello, lobby, bet, start, done, result, bye, ping / pong;
## on "pos" (unreliable) "s", a runner's state at his run time "at" ("k": his place, added by the host).

signal changed                          # the lobby, the state or the text to show changed
signal message(msg: Dictionary)         # about the race, for main.gd (start, result, gone)

const SEATS := 4                        # the host (place 0) and three guests (places 1 to 3)
const LINK_TIME := 30.0                 # seconds for a guest to get linked before giving up
const POLL := 0.5                       # seconds between two looks at the room
const SEND_EVERY := 0.08                # seconds between two states sent (12 a second)
const ROOM_LIFE := 540.0                # seconds: past this the room is opened again for new guests (the
                                        # server forgets it at ten minutes; the phones linked stay linked)
const COLOURS := [Color("#ffd35c"), Color("#7ee8ff"), Color("#e7a6ff"), Color("#9dff7a")]   # each place's colour
const HUES := [0.0, 0.42, 0.62, 0.22]   # ... and the hue the ghost is turned by (render.gd)

static var stakes: Array = [0, 50, 100, 250, 500, 1000]   # reglages/progression.txt, [course a 4]

var net: Net
var save: Dictionary
var state := "idle"                     # idle | opening | lobby | joining | linking | failed
var role := ""                          # host | guest
var room := ""
var room_t := 0.0                       # seconds since the room was opened (host)
var info := ""                          # what went wrong, for the screen
var me := 0                             # my place
var seats := {}                         # place -> {name, code, on (the place he bets on), bet, dist, done, gone, live}
var links := {}                         # host: friend code -> Link; guest: "host" -> Link
var since := 0
var poll_t := 0.0
var busy := false
var running := false                    # a race is on (from its start to its result)
var paid := 0                           # coins I put in the pot for the race on (given back if it never ends)
var result := {}                        # the last race's: {dists, win, pay, pot}
var trails := {}                        # place -> Trail: the others' states, to draw them smoothly
var invited := {}                       # the friends invited and not there yet (host): code -> name
var ice_cache := {}
var _ping_t := 0.0
var _end_t := 0.0
var message_time := 0.0                 # my run's time (main.gd sets it every step): the trails' clock
var tries := 0                          # a guest's links to the host tried again (once at most)

class Link:
	var peer                            # WebRTCPeerConnection (tests/race_logic.gd puts a stand-in there)
	var ctl                             # WebRTCDataChannel: reliable, in order
	var pos                             # WebRTCDataChannel: unreliable (the states)
	var code := ""                      # the other side's friend code (host: the guest's)
	var seat := -1
	var t := 0.0                        # seconds spent linking
	var open := false

## A runner's states as they come (some late, some out of order, some lost), drawn a little in the past
## so that he moves smoothly: the same way as the partner for two (coop.gd).
class Trail:
	var buf: Array = []
	var late := 0.1
	var jitter := 0.02
	var shown := -1.0
	var view_t := 0.0
	func push(m: Dictionary, my_t: float) -> void:
		var t = float(m.get("at", -1.0))
		if t < 0:
			return
		var i = buf.size()
		while i > 0 and float(buf[i - 1]["at"]) > t:
			i -= 1
		if i > 0 and is_equal_approx(float(buf[i - 1]["at"]), t):
			return
		buf.insert(i, m)
		while buf.size() > 40:
			buf.pop_front()
		var lag = my_t - t
		late += (lag - late) * 0.1
		jitter += (absf(lag - late) - jitter) * 0.1
	func view(my_t: float) -> Dictionary:
		var target = clampf(late + 2.0 * jitter + 0.08, 0.08, 0.4)
		if shown < 0:
			shown = target
		else:
			var most = maxf(0.0, my_t - view_t) * 0.1
			shown += clampf(target - shown, -most, most)
		view_t = my_t
		return Coop.sample(buf, my_t - shown)

## reglages/progression.txt, section [course a 4]: « mises | 0 / 50 / 100 / 250 / 500 / 1000 ».
static func load_config(text: String) -> void:
	var section = ""
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = Tune.key(line.substr(1, line.length() - 2))
			continue
		var cols = line.split("|")
		if section == "course a 4" and cols.size() >= 2 and Tune.key(cols[0]) == "mises":
			var got = Array(cols[1].split("/")).map(func(c): return maxi(0, int(c.strip_edges())))
			if not got.is_empty():
				stakes = got

func busy_state() -> bool:
	return state in ["opening", "joining", "linking"]

func in_lobby() -> bool:
	return state == "lobby"

func count() -> int:
	return seats.size()

func my_seat() -> Dictionary:
	return seats.get(me, {})

## What everyone has put in, together.
func pot() -> int:
	var n = 0
	for k in seats:
		n += int(seats[k].get("bet", 0))
	return n

# ---------- the host ----------

## Opens a race room: its four letters show on the screen, friends can be invited into it.
func host() -> void:
	leave()
	role = "host"
	me = 0
	_state("opening", "")
	var r = await net.open_race(save, randi() % 2147483647)
	if role != "host" or state != "opening":
		return
	if r.has("error"):
		_fail("Impossible d'ouvrir une course (%s)." % r["error"])
		return
	room = r["room"]
	room_t = 0.0
	ice_cache = await net.ice(save)
	if role != "host" or state != "opening":
		return
	seats = {0: _seat_of_me()}
	_state("lobby", "")

## The host invites a friend of his list (his code) into the room; a fresh room first if this one is old.
func invite(code: String, name: String) -> Dictionary:
	if role != "host" or state != "lobby":
		return {"error": "room"}
	if room_t > ROOM_LIFE:
		await _reopen()
	var r = await net.invite(save, code, room)
	if not r.has("error"):
		invited[code] = name
		changed.emit()
	return r

## The room is old (the server forgets it at ten minutes): a new one for the guests to come; those linked
## already stay linked.
func _reopen() -> void:
	var r = await net.open_race(save, randi() % 2147483647)
	if r.has("room"):
		net.close_room(save, room)
		room = r["room"]
		room_t = 0.0
		since = 0
		changed.emit()

## The host starts the race, in `delay` seconds: the road, the kit (his items and powers, for all) and the bets.
func start(msg: Dictionary, delay: float = 3.0) -> void:
	if role != "host" or state != "lobby" or running:
		return
	for k in seats.keys():                       # (only those linked and in the lobby run)
		if seats[k].get("gone", false):
			seats.erase(k)
	msg["t"] = "start"
	msg["in"] = delay
	msg["seats"] = _public_seats()
	_broadcast(msg)
	_begin(msg)

# ---------- a guest ----------

## Joins the race room of these four letters (or of an invitation).
func join(code: String) -> void:
	leave()
	role = "guest"
	room = code.strip_edges().to_upper()
	_state("joining", "")
	var r = await net.join_room(save, room)
	if role != "guest" or state != "joining":
		return
	if r.has("error"):
		_fail({"unknown": "Aucune course « %s »." % room, "full": "Cette course est déjà complète.", "self": "C'est ta propre course."}.get(r["error"], "Impossible de rejoindre (%s)." % r["error"]))
		return
	if str(r.get("kind", "coop")) != "race":
		_fail("« %s » est un salon pour deux : rejoins-le depuis « À deux »." % room)
		return
	me = int(r.get("slot", 1))
	tries = 0
	seats = {0: {"name": str(r.get("host", "")), "code": "", "on": 0, "bet": 0}, me: _seat_of_me()}
	ice_cache = await net.ice(save)
	if role != "guest" or state != "joining":
		return
	var l = _link("host")
	if l == null:
		return
	links["host"] = l
	_state("linking", "")
	_signal({"t": "hi", "seat": me}, "")

## My bet: `n` coins on place `on` (myself by default). Kept until the start, when it is paid in.
func bet(on: int, n: int) -> void:
	if not seats.has(me) or running:
		return
	seats[me]["on"] = on
	seats[me]["bet"] = n
	if role == "host":
		_broadcast_lobby()
	else:
		send({"t": "bet", "on": on, "n": n})
	changed.emit()

## Leaves the race (and its links) for good. A race on: what was put in is lost, like a fall.
func leave() -> void:
	if role != "" and state in ["lobby", "linking"] or running:
		_broadcast({"t": "bye"})
	if role == "host" and room != "" and net != null:
		net.close_room(save, room)
	elif role == "guest" and room != "" and net != null:
		net.leave_room(save, room)
	for k in links:
		var l: Link = links[k]
		if l.peer != null:
			l.peer.close()
	links.clear()
	seats.clear()
	trails.clear()
	invited.clear()
	running = false
	paid = 0
	since = 0
	room = ""
	role = ""
	if state != "idle":
		_state("idle", "")

# ---------- during the race ----------

## My state, for the others' screens (main.gd, 12 times a second).
func send_state(s: Dictionary) -> void:
	s["t"] = "s"
	s["k"] = me
	if role == "host":
		_broadcast(s, false)
	else:
		send(s, false)

## I fell: my distance is final.
func done(dist: int) -> void:
	if not running or not seats.has(me):
		return
	seats[me]["done"] = true
	seats[me]["dist"] = dist
	if role == "host":
		_broadcast({"t": "done", "k": me, "d": dist})
		_check_end()
	else:
		send({"t": "done", "d": dist})
	changed.emit()

## Where each of the others is to be drawn at my run time `my_t`: [{k, name, colour, x, y, ...}].
func views(my_t: float) -> Array:
	var out = []
	for k in trails:
		if not seats.has(k) or k == me:
			continue
		var v: Dictionary = trails[k].view(my_t)
		if v.is_empty():
			continue
		v["k"] = k
		v["name"] = str(seats[k].get("name", "?"))
		v["out"] = bool(seats[k].get("done", false)) or bool(seats[k].get("gone", false))
		out.append(v)
	return out

## The board of places during the race (render.gd draws it): [{name, dist, colour, out, me}], the furthest first.
func board() -> Array:
	var out = []
	for k in standings():
		var st: Dictionary = seats[k]
		out.append({"name": "TOI" if k == me else str(st.get("name", "?")).to_upper().left(8), "dist": int(st.get("dist", 0)), "colour": COLOURS[k % COLOURS.size()], "out": bool(st.get("done", false)) or bool(st.get("gone", false)), "me": k == me})
	return out

## The places in order: the furthest first (the distance each has reached so far, or his final one).
func standings() -> Array:
	var keys = seats.keys()
	keys.sort_custom(func(a, b): return _reach(a) > _reach(b))
	return keys

func _reach(k: int) -> float:
	var s: Dictionary = seats[k]
	return float(s.get("dist", 0))

## A runner's distance as the others last heard it (main.gd keeps mine up to date while I run).
func reach(k: int, dist: float) -> void:
	if seats.has(k) and not seats[k].get("done", false):
		seats[k]["dist"] = int(dist)

## How the pot is shared, from everyone's final distance: those who bet on the furthest share it in
## proportion to what they put in; nobody did: the furthest (or those tied) take it. {pay: place -> coins}.
static func settle(seats_: Dictionary) -> Dictionary:
	var best = -1
	for k in seats_:
		best = maxi(best, int(seats_[k].get("dist", 0)))
	var win: Array = []
	for k in seats_:
		if int(seats_[k].get("dist", 0)) == best:
			win.append(k)
	var pot_ = 0
	for k in seats_:
		pot_ += int(seats_[k].get("bet", 0))
	var backers: Array = []
	var backed = 0
	for k in seats_:
		var b = int(seats_[k].get("bet", 0))
		if b > 0 and int(seats_[k].get("on", k)) in win:
			backers.append(k)
			backed += b
	var pay = {}
	for k in seats_:
		pay[k] = 0
	if pot_ > 0:
		var takers = backers if not backers.is_empty() else win
		var given = 0
		for k in takers:
			var share = (pot_ * int(seats_[k].get("bet", 0)) / backed) if not backers.is_empty() else pot_ / win.size()
			pay[k] = share
			given += share
		pay[takers[0]] += pot_ - given                # (what rounding left: to the first of them)
	win.sort()
	return {"win": win, "pay": pay, "pot": pot_}

# ---------- inside ----------

func _seat_of_me() -> Dictionary:
	var on: Dictionary = save.get("online", {})
	return {"name": str(on.get("name", "Pépito")), "code": str(on.get("code", "")), "on": me, "bet": 0}

func _public_seats() -> Dictionary:
	var out = {}
	for k in seats:
		var s: Dictionary = seats[k]
		out[str(k)] = {"name": s.get("name", "?"), "code": s.get("code", ""), "on": int(s.get("on", k)), "bet": int(s.get("bet", 0)), "gone": s.get("gone", false), "done": s.get("done", false), "dist": int(s.get("dist", 0))}
	return out

func _read_seats(d: Dictionary) -> void:
	var mine = seats.get(me, _seat_of_me())
	seats = {}
	for k in d:
		var s: Dictionary = d[k]
		seats[int(k)] = {"name": str(s.get("name", "?")).left(16), "code": str(s.get("code", "")), "on": int(s.get("on", int(k))), "bet": int(s.get("bet", 0)), "gone": bool(s.get("gone", false)), "done": bool(s.get("done", false)), "dist": int(s.get("dist", 0))}
	if not seats.has(me):
		seats[me] = mine

func _state(s: String, text: String) -> void:
	state = s
	info = text
	changed.emit()

func _fail(text: String) -> void:
	for k in links:
		var l: Link = links[k]
		if l.peer != null:
			l.peer.close()
	links.clear()
	if running and paid > 0:                       # the race never ended for me: my coins come back
		save["coins"] = int(save["coins"]) + paid
		SaveData.store(save)
		text += " Ta mise t'est rendue."
	running = false
	paid = 0
	_state("failed", text)

func _link(code: String) -> Link:
	var servers: Array = Net.ice_servers() + Array(ice_cache.get("iceServers", []))
	var config = {"iceServers": servers}
	if Net.relay_only:
		config["iceTransportPolicy"] = "relay"
	var l = Link.new()
	l.code = code
	l.peer = WebRTCPeerConnection.new()
	if l.peer.initialize(config) != OK:
		_fail("Ce navigateur ne sait pas jouer à plusieurs.")
		return null
	var to = code if role == "host" else ""
	l.peer.session_description_created.connect(func(type: String, sdp: String) -> void:
		l.peer.set_local_description(type, sdp)
		_signal({"t": type, "sdp": sdp}, to))
	l.peer.ice_candidate_created.connect(func(media: String, index: int, name: String) -> void:
		_signal({"t": "ice", "m": media, "i": index, "n": name}, to))
	l.ctl = l.peer.create_data_channel("ctl", {"negotiated": true, "id": 1})
	l.pos = l.peer.create_data_channel("pos", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	return l

func _signal(data: Dictionary, to: String) -> void:
	net.send_signal(save, room, JSON.stringify(data), to)

func send(msg: Dictionary, reliable: bool = true) -> void:
	if links.has("host"):
		_put(links["host"], msg, reliable)

func _put(l: Link, msg: Dictionary, reliable: bool) -> void:
	var ch = l.ctl if reliable else l.pos
	if ch != null and ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		ch.put_packet(JSON.stringify(msg).to_utf8_buffer())

## The host to every guest (but `except`, the one it comes from).
func _broadcast(msg: Dictionary, reliable: bool = true, except: String = "") -> void:
	if role == "host":
		for k in links:
			if k != except:
				_put(links[k], msg, reliable)
	else:
		send(msg, reliable)

func _broadcast_lobby() -> void:
	_broadcast({"t": "lobby", "seats": _public_seats(), "room": room, "running": running})

## The room's new messages: the handshakes (host: from each guest; guest: from the host).
func _read() -> void:
	if busy or room == "":
		return
	busy = true
	var r = await net.read_signals(save, room, since)
	busy = false
	if r.has("error"):
		return
	for it in r.get("items", []):
		since = maxi(since, int(it["seq"]))
		var d = JSON.parse_string(str(it["data"]))
		if not d is Dictionary:
			continue
		var t = str(d.get("t", ""))
		if role == "host":
			var code = str(it.get("code", ""))
			if t == "no":                            # a friend invited said « Pas maintenant »
				invited.erase(code)
				changed.emit()
				continue
			if t == "hi":
				if links.has(code):
					links[code].peer.close()
				var l = _link(code)
				if l == null:
					return
				l.seat = int(d.get("seat", -1))
				links[code] = l
				invited.erase(code)
				l.peer.create_offer()
				continue
			if links.has(code):
				_handshake(links[code], d)
		elif links.has("host"):
			_handshake(links["host"], d)

func _handshake(l: Link, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"offer", "answer":
			l.peer.set_remote_description(str(d["t"]), str(d["sdp"]))
		"ice":
			l.peer.add_ice_candidate(str(d["m"]), int(d["i"]), str(d["n"]))

func _process(delta: float) -> void:
	if role == "":
		return
	room_t += delta
	for k in links.keys():
		var l: Link = links[k]
		l.peer.poll()
		var st = l.peer.get_connection_state()
		if not l.open:
			l.t += delta
			if l.ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
				l.open = true
				_put(l, {"t": "hello", "seat": me, "name": _seat_of_me()["name"], "code": _seat_of_me()["code"]}, true)
				if role == "guest":
					_state("lobby", "")
			elif l.t > LINK_TIME or st == WebRTCPeerConnection.STATE_FAILED:
				if role == "guest":
					if tries < 1:                    # once more, from the start (the host takes a new « hi »)
						tries += 1
						l.peer.close()
						var again = _link("host")
						if again == null:
							return
						links["host"] = again
						_signal({"t": "hi", "seat": me}, "")
						continue
					_fail("La connexion avec l'hôte n'a pas pu se faire.")
					return
				l.peer.close()
				links.erase(k)
				continue
		elif st in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED, WebRTCPeerConnection.STATE_DISCONNECTED]:
			_lost(k)
			continue
		for ch in [l.ctl, l.pos]:
			while ch != null and ch.get_available_packet_count() > 0:
				var m = JSON.parse_string(ch.get_packet().get_string_from_utf8())
				if m is Dictionary:
					_on_message(k, l, m)
	if state in ["lobby", "linking"] and (role == "host" or state == "linking") and not running:
		poll_t -= delta
		if poll_t <= 0:
			poll_t = POLL
			_read()
	_ping_t -= delta
	if _ping_t <= 0:
		_ping_t = 2.0
		_broadcast({"t": "ping"})
	if running and role == "host":               # (the last one running may get out of reach of the others)
		_end_t -= delta
		if _end_t <= 0:
			_end_t = 0.5
			_check_end()

## A link went: on the host, that guest is out (his last distance stands if a race is on); on a guest, the
## host left, so the race is over for everyone.
func _lost(k: String) -> void:
	var l: Link = links[k]
	l.peer.close()
	links.erase(k)
	if role == "guest":
		_fail("L'hôte est parti.")
		message.emit({"t": "gone"})
		return
	if seats.has(l.seat):
		if running:
			seats[l.seat]["gone"] = true
			seats[l.seat]["done"] = true
		else:
			seats.erase(l.seat)
	_broadcast_lobby()
	if running:
		_check_end()
	changed.emit()

func _on_message(k: String, l: Link, m: Dictionary) -> void:
	var t = str(m.get("t", ""))
	if role == "host":
		match t:
			"hello":
				var seat = l.seat if l.seat > 0 else int(m.get("seat", -1))
				if seat < 1 or seat >= SEATS or (seats.has(seat) and seats[seat].get("code", "") != str(m.get("code", ""))):
					seat = _free_seat()
				if seat < 0 or running:
					_put(l, {"t": "full"}, true)
					return
				l.seat = seat
				seats[seat] = {"name": str(m.get("name", "Pépito")).left(16), "code": str(m.get("code", "")), "on": seat, "bet": 0}
				invited.erase(seats[seat]["code"])
				_broadcast_lobby()
				changed.emit()
			"bet":
				if seats.has(l.seat) and not running:
					var on = int(m.get("on", l.seat))
					seats[l.seat]["on"] = on if seats.has(on) else l.seat
					seats[l.seat]["bet"] = clampi(int(m.get("n", 0)), 0, 1000000)
					_broadcast_lobby()
					changed.emit()
			"s":
				m["k"] = l.seat
				_on_state(m)
				_broadcast(m, false, k)
			"done":
				if seats.has(l.seat):
					seats[l.seat]["done"] = true
					seats[l.seat]["dist"] = int(m.get("d", 0))
					_broadcast({"t": "done", "k": l.seat, "d": int(m.get("d", 0))}, true, k)
					_check_end()
					changed.emit()
			"bye":
				_lost(k)
			"ping":
				_put(l, {"t": "pong"}, true)
		return
	match t:                                     # a guest: what the host says (or passes on)
		"lobby":
			_read_seats(m.get("seats", {}))
			if str(m.get("room", "")) != "":
				room = str(m["room"])
			changed.emit()
		"full":
			_fail("Cette course est déjà complète ou déjà partie.")
		"start":
			_begin(m)
		"s":
			_on_state(m)
		"done":
			var kk = int(m.get("k", -1))
			if seats.has(kk):
				seats[kk]["done"] = true
				seats[kk]["dist"] = int(m.get("d", 0))
				changed.emit()
		"result":
			_end(m)
		"bye":
			_fail("L'hôte a fermé la course.")
			message.emit({"t": "gone"})
		"ping":
			send({"t": "pong"})

func _free_seat() -> int:
	for i in range(1, SEATS):
		if not seats.has(i):
			return i
	return -1

func _on_state(m: Dictionary) -> void:
	var k = int(m.get("k", -1))
	if k < 0 or k == me or not seats.has(k):
		return
	if not trails.has(k):
		trails[k] = Trail.new()
	trails[k].push(m, float(message_time))
	if not seats[k].get("done", false):
		seats[k]["dist"] = int(m.get("d", seats[k].get("dist", 0)))

## The race starts here (for the host as for the guests): the bets are paid in, the trails emptied.
func _begin(m: Dictionary) -> void:
	_read_seats(m.get("seats", _public_seats()))
	for k in seats:
		seats[k]["dist"] = 0
		seats[k]["done"] = false
	trails.clear()
	result = {}
	var b = mini(int(seats.get(me, {}).get("bet", 0)), int(save["coins"]))
	if seats.has(me):
		seats[me]["bet"] = b
	paid = b
	save["coins"] = int(save["coins"]) - b
	SaveData.store(save)
	running = true
	message.emit(m)
	changed.emit()

## The host: is it over? Everyone has fallen, or only one runs on and is beyond everyone else already.
func _check_end() -> void:
	if role != "host" or not running:
		return
	var on: Array = []
	var best_done = 0
	for k in seats:
		if seats[k].get("done", false):
			best_done = maxi(best_done, int(seats[k].get("dist", 0)))
		else:
			on.append(k)
	if on.size() > 1 or (on.size() == 1 and int(seats[on[0]].get("dist", 0)) <= best_done):
		return
	var dists = {}
	for k in seats:
		dists[k] = int(seats[k].get("dist", 0))
	if on.size() == 1:                            # (he runs on for his record: the race is his)
		dists[on[0]] = maxi(dists[on[0]], best_done + 1)
	var view = seats.duplicate(true)
	for k in view:
		view[k]["dist"] = dists[k]
	var s = settle(view)
	var msg = {"t": "result", "pot": s["pot"], "win": s["win"], "pay": {}, "dists": {}}
	for k in seats:
		msg["pay"][str(k)] = s["pay"][k]
		msg["dists"][str(k)] = dists[k]
	_broadcast(msg)
	_end(msg)

## The result: my share of the pot is paid.
func _end(m: Dictionary) -> void:
	if not running:
		return
	running = false
	var pay = m.get("pay", {})
	var mine = int(pay.get(str(me), 0))
	save["coins"] = int(save["coins"]) + mine
	SaveData.store(save)
	result = {"pot": int(m.get("pot", 0)), "win": Array(m.get("win", [])).map(func(x): return int(x)), "pay": {}, "dists": {}, "paid": paid, "got": mine}
	for k in pay:
		result["pay"][int(k)] = int(pay[k])
	for k in m.get("dists", {}):
		result["dists"][int(k)] = int(m["dists"][k])
		if seats.has(int(k)):
			seats[int(k)]["dist"] = int(m["dists"][k])
	paid = 0
	for k in seats:                               # (the bets stay as they were for a rematch)
		seats[k]["done"] = false
	message.emit({"t": "result"})
	changed.emit()
