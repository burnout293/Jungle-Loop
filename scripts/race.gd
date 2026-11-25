class_name Race
extends Node
## The race for four (0.48). The host opens a race room on the server (net.gd: four letters to give, or
## friends of his list invited into it), up to three guests join it, and each guest's WebRTC handshake with
## the host passes through the room; then the phones talk directly: a star, the host in the middle, who
## passes on what each one says to the others. Before the start, in the lobby, everyone bets coins on the
## one he thinks will go furthest (himself by default). The host starts: everybody runs the same road (the
## same seed, scenery and road tier: Game.coop_run, the host's items and powers for all, on the same clock),
## with the others drawn as ghosts (render.gd). Whoever falls is out and watches the rest; when the last one
## falls (or can no longer be caught), the host works out the result (settle).
## 0.55 (« Affrontement »): each one says he is ready (the host's « Lancer » comes once all are); a bet is any
## number of coins up to BET_MAX, and whoever bet on the furthest gets twice his bet back (nothing else is
## shared); every race of the group is kept (history). A link that drops (the phone turned, another app for a
## while) is not the end: the guest's place is kept AWAY_KEEP seconds and he links again through the room.
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
const BET_MAX := 99999999               # (0.55) the most one may bet
const AWAY_KEEP := 180.0                # (0.55) seconds a guest's place waits for him once his link dropped
                                        # (0.57: 180: long enough for a phone to start the game again)
const DOWN_GRACE := 6.0                 # ... seconds a link may say « disconnected » before it counts as lost
const RELINK_EVERY := 12.0              # ... a guest tries again this often
const RELINK_TIME := 180.0              # ... and gives up after this
const KEEP_FILE := "user://jungle-loop-group%s.json"   # (0.57) the group I am in, kept: joined again after a crash
const KEEP_LIFE := 540.0                # ... for as long as the server keeps its room (seconds)
const HUES := [0.0, 0.42, 0.62, 0.22]   # ... and the hue the ghost is turned by (render.gd)
const SLOW_MS := 200                    # (0.58) a link this slow (ms there and back) or slower shows « lent »

static var stakes: Array = [100, 500, 1000]   # reglages/progression.txt, [course a 4]: the ready-made bets

var net: Net
var save: Dictionary
var state := "idle"                     # idle | opening | lobby | joining | linking | failed
var role := ""                          # host | guest
var room := ""
var room_t := 0.0                       # seconds since the room was opened (host)
var info := ""                          # what went wrong, for the screen
var me := 0                             # my place
var seats := {}                         # place -> {name, code, skin, on (the place he bets on), bet, ready, away, dist, gold, done, gone}
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
var rules := {"score": "dist", "end": "last"}   # (0.61) the host's rules: score dist|gold, end last (5 s after one is left)|open
var last_at := -1                       # (0.61) when only one was left running (ms), -1 if not
static var LAST_WAIT := 5.0                  # (0.61) « Dernier en vie »: the race ends this long after only one is left
var kit := {}                           # (0.55) the host's items and powers, for all: shown before the start
var history: Array = []                 # (0.55) the group's races, the latest first: [{n, rows: [{k, name, bet, on, dist, gold, got, win}]}]
var relink_t := -1.0                    # (0.55) a guest linking again since (-1: not)
var relink_next := 0.0
var races := 0                          # races run in this group
var banned := {}                        # (0.58) the host: friend codes sent out of the group (not let back in)

class Link:
	var peer                            # WebRTCPeerConnection (tests/race_logic.gd puts a stand-in there)
	var ctl                             # WebRTCDataChannel: reliable, in order
	var pos                             # WebRTCDataChannel: unreliable (the states)
	var code := ""                      # the other side's friend code (host: the guest's)
	var seat := -1
	var t := 0.0                        # seconds spent linking
	var open := false
	var down := 0.0                     # (0.55) seconds it has said « disconnected »
	var rtt := -1.0                     # (0.58) milliseconds there and back (pings every 2 s), -1: not known yet

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
			var got = Array(cols[1].split("/")).map(func(c): return clampi(int(c.strip_edges()), 0, BET_MAX)).filter(func(n): return n > 0)
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

## 0.55: everyone there says he is ready (and linked): the host may start.
func all_ready() -> bool:
	if seats.size() < 2:
		return false
	for k in seats:
		if seats[k].get("away", false) or not seats[k].get("ready", false):
			return false
	return links.values().all(func(l): return l.open)

## 0.55: I am ready (or no longer).
func set_ready(on: bool) -> void:
	if not seats.has(me) or running:
		return
	seats[me]["ready"] = on
	if role == "host":
		_broadcast_lobby()
	else:
		send({"t": "ready", "on": on})
	changed.emit()

## 0.55: the host's items and powers, for all (shown on everyone's screen before the start).
func set_kit(k: Dictionary) -> void:
	if role != "host" or kit == k:
		return
	kit = k.duplicate()
	_broadcast_lobby()
	changed.emit()

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
		banned.erase(code)                       # (0.58: invited again, let in again)
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
	seats[me]["bet"] = clampi(n, 0, BET_MAX)
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
	banned.clear()
	history = []
	kit = {}
	races = 0
	relink_t = -1.0
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

## I fell: my distance is final (0.56: and the coins I picked up, kept, for everyone's end screen).
func done(dist: int, gold: int = -1) -> void:
	if not running or not seats.has(me):
		return
	seats[me]["done"] = true
	seats[me]["dist"] = dist
	if gold >= 0:
		seats[me]["gold"] = gold
	var c = int(seats[me].get("gold", 0))
	if role == "host":
		_broadcast({"t": "done", "k": me, "d": dist, "c": c})
		_check_end()
	else:
		send({"t": "done", "d": dist, "c": c})
	changed.emit()

## (0.56) The coins I have picked up so far in the race (main.gd, as I run).
func gained(gold: int) -> void:
	if seats.has(me) and not seats[me].get("done", false):
		seats[me]["gold"] = gold

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
		v["gh"] = float(seats[k].get("gh", -1.0))
		out.append(v)
	return out

## 0.55: during the race, everyone's bet (render.gd draws it top right): [{name, bet, colour, out, me}], in
## the order of the places. « bet »: « 500 SUR LÉO », « SANS MISE ».
func board() -> Array:
	var out = []
	var keys = seats.keys()
	keys.sort()
	for k in keys:
		var st: Dictionary = seats[k]
		var b = int(st.get("bet", 0))
		var on = int(st.get("on", k))
		var on_name = "LUI" if on == k else ("TOI" if on == me else str(seats.get(on, {}).get("name", "?")).to_upper().left(8))
		out.append({"name": "TOI" if k == me else str(st.get("name", "?")).to_upper().left(8), "bet": ("%d SUR %s" % [b, on_name]) if b > 0 else "SANS MISE",
			"colour": COLOURS[k % COLOURS.size()], "out": bool(st.get("done", false)) or bool(st.get("gone", false)), "me": k == me})
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

## 0.55: from everyone's final distance, who won (the furthest, or those tied), and what each gets back:
## twice his bet if he bet on one of them, nothing otherwise. {win, pay: place -> coins, pot (all the bets)}.
static func settle(seats_: Dictionary, score: String = "dist") -> Dictionary:
	var by = "gold" if score == "gold" else "dist"   # (0.61) the host's rule: the furthest, or the most coins
	var best = -1
	for k in seats_:
		best = maxi(best, int(seats_[k].get(by, 0)))
	var win: Array = []
	for k in seats_:
		if int(seats_[k].get(by, 0)) == best:
			win.append(k)
	var pot_ = 0
	var pay = {}
	for k in seats_:
		var b = int(seats_[k].get("bet", 0))
		pot_ += b
		pay[k] = 2 * b if b > 0 and int(seats_[k].get("on", k)) in win else 0
	win.sort()
	return {"win": win, "pay": pay, "pot": pot_}

# ---------- inside ----------

func _seat_of_me() -> Dictionary:
	var on: Dictionary = save.get("online", {})
	var worn: Dictionary = save.get("skins", {}).get("worn", {})
	var gfx: Dictionary = Skins.skin(str(worn.get("ghost", ""))).get("fx", {})   # (0.58) the ghost's colour he chose
	var gh = fposmod(Color(gfx["col"]).h - 0.23, 1.0) if gfx.has("col") else -1.0
	return {"name": str(on.get("name", "Pépito")), "code": str(on.get("code", "")), "skin": str(worn.get("pepito", "")), "on": me, "bet": 0, "ready": false, "gh": gh}

func _public_seats() -> Dictionary:
	var out = {}
	for k in seats:
		var s: Dictionary = seats[k]
		out[str(k)] = {"name": s.get("name", "?"), "code": s.get("code", ""), "skin": s.get("skin", ""), "on": int(s.get("on", k)), "bet": int(s.get("bet", 0)),
			"ready": s.get("ready", false), "away": s.get("away", false), "gone": s.get("gone", false), "done": s.get("done", false), "dist": int(s.get("dist", 0)),
			"gold": int(s.get("gold", 0)), "gh": float(s.get("gh", -1.0)), "ms": _ms_of(k), "wait": maxi(0, ceili(AWAY_KEEP - float(s.get("away_t", 0.0)))) if s.get("away", false) else 0}
	return out

## (0.58) The delay (ms there and back) of a place's link as the host measures it; 0 for the host himself,
## -1 not known (linking, gone).
func _ms_of(k: int) -> int:
	if k == 0:
		return 0
	for c in links:
		var l: Link = links[c]
		if l.seat == k and l.open and l.rtt >= 0:
			return roundi(l.rtt)
	return -1

## (0.58) A place's link, as I can tell it: {"ms": delay or -1, "state": "ok" | "slow" | "away" | "linking",
## "wait": seconds his place still waits (away)}. A guest knows his own delay to the host and what the host
## says of the others.
func link_of(k: int) -> Dictionary:
	var st: Dictionary = seats.get(k, {})
	if st.is_empty():
		return {}
	var ms = -1
	if role == "guest" and (k == 0 or k == me):
		var l: Link = links.get("host")
		ms = roundi(l.rtt) if l != null and l.open and l.rtt >= 0 else -1
		if l == null or not l.open:
			return {"ms": -1, "state": "away" if relink_t >= 0 else "linking", "wait": maxi(0, ceili(RELINK_TIME - relink_t)) if relink_t >= 0 else 0}
	elif role == "host":
		if k == 0:
			return {"ms": 0, "state": "ok", "wait": 0}
		ms = _ms_of(k)
	else:
		ms = int(st.get("ms", -1))
	if st.get("away", false):
		var wait = int(st.get("wait", 0)) if role != "host" else maxi(0, ceili(AWAY_KEEP - float(st.get("away_t", 0.0))))
		return {"ms": -1, "state": "away", "wait": wait}
	if ms < 0 and role == "host" and not links.values().any(func(l): return l.seat == k and l.open):
		return {"ms": -1, "state": "linking", "wait": 0}
	return {"ms": ms, "state": "slow" if ms >= SLOW_MS else "ok", "wait": 0}

## (0.58) The host sends a guest out of the group (before a race): his link closed, his place freed, and he
## is not let back in (by an invitation he may be, again: `banned` forgets him then).
func kick(k: int) -> void:
	if role != "host" or running or k <= 0 or not seats.has(k):
		return
	var code = str(seats[k].get("code", ""))
	for c in links.keys():
		var l: Link = links[c]
		if l.seat == k:
			_put(l, {"t": "kicked"}, true)
			l.peer.close()
			links.erase(c)
	seats.erase(k)
	trails.erase(k)
	if code != "":
		banned[code] = true
		invited.erase(code)
	_broadcast_lobby()
	changed.emit()

func _read_seats(d: Dictionary) -> void:
	var mine = seats.get(me, _seat_of_me())
	seats = {}
	for k in d:
		var s: Dictionary = d[k]
		seats[int(k)] = {"name": str(s.get("name", "?")).left(16), "code": str(s.get("code", "")), "skin": str(s.get("skin", "")).left(40), "on": int(s.get("on", int(k))),
			"bet": clampi(int(s.get("bet", 0)), 0, BET_MAX), "ready": bool(s.get("ready", false)), "away": bool(s.get("away", false)), "ms": int(s.get("ms", -1)), "wait": int(s.get("wait", 0)), "gh": clampf(float(s.get("gh", -1.0)), -1.0, 1.0),
			"gone": bool(s.get("gone", false)), "done": bool(s.get("done", false)), "dist": int(s.get("dist", 0)),
			"gold": maxi(0, int(s.get("gold", 0)))}
	if not seats.has(me):
		seats[me] = mine

func _state(s: String, text: String) -> void:
	state = s
	info = text
	_keep()
	changed.emit()

## (0.57) The group I am in, written on the phone (its room, my role and place, its races so far): if the game
## stops (a crash, a slow phone), the next start offers to join it again. Gone when I leave it.
func _keep() -> void:
	var path = keep_path()
	if role == "" or room == "" or state in ["idle", "failed"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"room": room, "role": role, "me": me, "at": Time.get_unix_time_from_system(), "history": history, "races": races}))
		f.close()

## (0.57) The group kept on the phone, if it is fresh enough to be joined again: {room, role, me, ...}, else {}.
static func keep_path() -> String:
	return KEEP_FILE % ("-bac" if SaveData._bac() else "")   # (tries and tests: never the real one)

static func kept() -> Dictionary:
	if not FileAccess.file_exists(keep_path()):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(keep_path()))
	if not d is Dictionary or str(d.get("room", "")) == "" or Time.get_unix_time_from_system() - float(d.get("at", 0)) > KEEP_LIFE:
		return {}
	return d

## (0.57) Back in a group after the game stopped: a guest joins its room again (the host kept his place);
## the host takes his room again, and the guests, linking again through it, come back.
func rejoin(d: Dictionary) -> void:
	var keep_h = Array(d.get("history", []))
	var keep_n = int(d.get("races", keep_h.size()))
	if str(d.get("role", "")) != "host":
		join(str(d["room"]))                         # (it leaves what was there first, then joins)
		history = keep_h
		races = keep_n
		return
	leave()
	history = keep_h
	races = keep_n
	role = "host"
	me = 0
	room = str(d["room"])
	room_t = ROOM_LIFE - 60.0                        # (a new room soon, the guests told)
	ice_cache = await net.ice(save)
	seats = {0: _seat_of_me()}
	_state("lobby", "")

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
	_broadcast({"t": "lobby", "seats": _public_seats(), "room": room, "running": running, "kit": kit, "n": races, "rules": rules})

## (0.61) The host sets a rule of the group (in the lobby): "score" dist|gold, "end" last|open.
func set_rule(key: String, value: String) -> void:
	if role != "host" or running or not rules.has(key):
		return
	rules[key] = value
	_broadcast_lobby()
	changed.emit()

static func rules_text(r: Dictionary) -> String:
	return "%s · %s" % ["Pièces" if r.get("score", "dist") == "gold" else "Distance", "Illimité" if r.get("end", "last") == "open" else "Dernier en vie"]

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
				if banned.has(code):                 # (0.58) sent out of the group: not let back in
					continue
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
	if role == "host" and room_t > ROOM_LIFE and not busy and state == "lobby":
		_renew()                                     # (0.55) a fresh room before the server forgets this one
	for k in links.keys():
		if not links.has(k):
			continue
		var l: Link = links[k]
		l.peer.poll()
		var st = l.peer.get_connection_state()
		if not l.open:
			l.t += delta
			if l.ctl.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
				l.open = true
				var mine = _seat_of_me()
				_put(l, {"t": "hello", "seat": me, "name": mine["name"], "code": mine["code"], "skin": mine["skin"], "gh": mine["gh"]}, true)
				if role == "guest":
					relink_t = -1.0
					_state("lobby", "")
					if seats.has(me):                # (0.55: linked again: my bet and my readiness, as they were)
						send({"t": "bet", "on": int(seats[me].get("on", me)), "n": int(seats[me].get("bet", 0))})
						send({"t": "ready", "on": bool(seats[me].get("ready", false))})
			elif l.t > LINK_TIME or st == WebRTCPeerConnection.STATE_FAILED:
				if role == "guest":
					if relink_t >= 0:                # (0.55: linking again: the next try comes by itself)
						continue
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
		elif st == WebRTCPeerConnection.STATE_DISCONNECTED:   # (0.55) often only a moment: wait a little
			l.down += delta
			if l.down > DOWN_GRACE:
				_lost(k)
				continue
		elif st in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED]:
			_lost(k)
			continue
		else:
			l.down = 0.0
		for ch in [l.ctl, l.pos]:
			while ch != null and ch.get_available_packet_count() > 0:
				var m = JSON.parse_string(ch.get_packet().get_string_from_utf8())
				if m is Dictionary:
					_on_message(k, l, m)
	var away = seats.values().any(func(st_): return st_.get("away", false))
	if role == "host" and away:                      # (0.55) places kept for those whose link dropped, a while
		for kk in seats.keys():
			var st_: Dictionary = seats[kk]
			if not st_.get("away", false):
				continue
			st_["away_t"] = float(st_.get("away_t", 0.0)) + delta
			if st_["away_t"] > AWAY_KEEP:
				if running:
					st_["away"] = false
					st_["gone"] = true
					st_["done"] = true
				else:
					seats.erase(kk)
				_broadcast_lobby()
				changed.emit()
				if running:
					_check_end()
	if role == "guest" and relink_t >= 0:            # (0.55) the guest linking again through the room
		relink_t += delta
		relink_next -= delta
		if relink_t > RELINK_TIME:
			relink_t = -1.0
			_fail("La connexion avec l'hôte est perdue.")
			message.emit({"t": "gone"})
			return
		if relink_next <= 0 and not busy:
			relink_next = RELINK_EVERY
			_relink()
	if (state in ["lobby", "linking"] and (role == "host" or state == "linking") and not running) or (role == "host" and away) or (role == "guest" and relink_t >= 0):
		poll_t -= delta
		if poll_t <= 0:
			poll_t = POLL
			_read()
	_ping_t -= delta
	if _ping_t <= 0:
		_ping_t = 2.0
		_broadcast({"t": "ping", "at": Time.get_ticks_msec()})
	if running and role == "host":               # (the last one running may get out of reach of the others)
		_end_t -= delta
		if _end_t <= 0:
			_end_t = 0.5
			_check_end()

## A link went (0.55: not the end). On the host, that guest's place waits AWAY_KEEP seconds for him (his last
## distance stands if a race is on and he never comes back); on a guest, he links again through the room.
func _lost(k: String) -> void:
	var l: Link = links[k]
	l.peer.close()
	links.erase(k)
	if role == "guest":
		if relink_t < 0:
			relink_t = 0.0
			relink_next = 0.0
			tries = 1
			_state("linking", "")
		return
	if seats.has(l.seat):
		seats[l.seat]["away"] = true
		seats[l.seat]["away_t"] = 0.0
		seats[l.seat]["ready"] = false
	_broadcast_lobby()
	changed.emit()

## (0.55) The host: a fresh room, and the guests told (lobby), so that a link that drops later can come back
## through it.
func _renew() -> void:
	busy = true
	await _reopen()
	busy = false
	_broadcast_lobby()

## (0.55) A guest linking again: into the room again (the same place), a new link, a new « hi ».
func _relink() -> void:
	busy = true
	var r = await net.join_room(save, room)
	busy = false
	if role != "guest" or relink_t < 0:
		return
	if r.has("error") and str(r["error"]) == "unknown":
		return                                       # (the room is gone: the next try, or the end of trying)
	if r.has("slot"):
		me = int(r["slot"])
	if links.has("host"):
		links["host"].peer.close()
	var l = _link("host")
	if l == null:
		return
	links["host"] = l
	_signal({"t": "hi", "seat": me}, "")

func _on_message(k: String, l: Link, m: Dictionary) -> void:
	var t = str(m.get("t", ""))
	if role == "host":
		match t:
			"hello":
				var code = str(m.get("code", ""))
				if banned.has(code):
					_put(l, {"t": "kicked"}, true)
					return
				var back = -1                    # (0.55) one coming back: his own place, as it was
				for kk in seats:
					if code != "" and str(seats[kk].get("code", "")) == code and kk != 0:
						back = kk
				if back > 0:
					l.seat = back
					seats[back]["away"] = false
					seats[back]["away_t"] = 0.0
					seats[back]["skin"] = str(m.get("skin", "")).left(40)
					_broadcast_lobby()
					changed.emit()
					return
				var seat = l.seat if l.seat > 0 else int(m.get("seat", -1))
				if seat < 1 or seat >= SEATS or (seats.has(seat) and seats[seat].get("code", "") != code):
					seat = _free_seat()
				if seat < 0 or running:
					_put(l, {"t": "full"}, true)
					return
				l.seat = seat
				seats[seat] = {"name": str(m.get("name", "Pépito")).left(16), "code": code, "skin": str(m.get("skin", "")).left(40), "on": seat, "bet": 0, "ready": false,
					"gh": clampf(float(m.get("gh", -1.0)), -1.0, 1.0)}
				invited.erase(seats[seat]["code"])
				_broadcast_lobby()
				changed.emit()
			"bet":
				if seats.has(l.seat) and not running:
					var on = int(m.get("on", l.seat))
					seats[l.seat]["on"] = on if seats.has(on) else l.seat
					seats[l.seat]["bet"] = clampi(int(m.get("n", 0)), 0, BET_MAX)
					_broadcast_lobby()
					changed.emit()
			"ready":                             # (0.55) a guest ready, or no longer
				if seats.has(l.seat) and not running:
					seats[l.seat]["ready"] = bool(m.get("on", false))
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
					seats[l.seat]["gold"] = maxi(0, int(m.get("c", seats[l.seat].get("gold", 0))))
					_broadcast({"t": "done", "k": l.seat, "d": int(m.get("d", 0)), "c": int(seats[l.seat]["gold"])}, true, k)
					_check_end()
					changed.emit()
			"bye":
				_lost(k)
			"ping":
				_put(l, {"t": "pong", "at": m.get("at", -1)}, true)
			"pong":                              # (0.58) the delay of this guest's link
				_pong(l, m)
		return
	match t:                                     # a guest: what the host says (or passes on)
		"lobby":
			_read_seats(m.get("seats", {}))
			if str(m.get("room", "")) != "":
				room = str(m["room"])
			if m.get("kit") is Dictionary:
				kit = m["kit"]
			if m.get("rules") is Dictionary:
				rules = {"score": "gold" if str(m["rules"].get("score", "")) == "gold" else "dist", "end": "open" if str(m["rules"].get("end", "")) == "open" else "last"}
			races = maxi(races, int(m.get("n", 0)))
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
				seats[kk]["gold"] = maxi(0, int(m.get("c", seats[kk].get("gold", 0))))
				changed.emit()
		"result":
			_end(m)
		"bye":
			_fail("L'hôte a fermé la course.")
			message.emit({"t": "gone"})
		"ping":
			send({"t": "pong", "at": m.get("at", -1)})
		"pong":
			_pong(l, m)
		"kicked":                                # (0.58) the host sent me out of the group
			if net != null and room != "":
				net.leave_room(save, room)
			_fail("L'hôte t'a retiré du groupe.")
			message.emit({"t": "gone"})

## (0.58) A pong: the delay there and back of this link, smoothed (a ping lost is no harm).
func _pong(l: Link, m: Dictionary) -> void:
	var at = float(m.get("at", -1))
	if at < 0:
		return
	var ms = maxf(0.0, Time.get_ticks_msec() - at)
	l.rtt = ms if l.rtt < 0 else l.rtt + (ms - l.rtt) * 0.4

func _free_seat() -> int:
	for i in range(1, SEATS):
		if not seats.has(i):
			return i
	return -1

## (0.55) The race just ended, kept for the group's history (the latest first, twenty at most).
func _remember() -> void:
	races += 1
	var rows: Array = []
	var keys = seats.keys()
	keys.sort()
	for k in keys:
		var st: Dictionary = seats[k]
		rows.append({"k": k, "name": str(st.get("name", "?")), "bet": int(st.get("bet", 0)), "on": int(st.get("on", k)),
			"dist": int(result.get("dists", {}).get(k, st.get("dist", 0))), "gold": int(st.get("gold", 0)),
			"got": int(result.get("pay", {}).get(k, 0)), "win": k in result.get("win", [])})
	history.push_front({"n": races, "rows": rows})
	if history.size() > 20:
		history.pop_back()
	_keep()

func _on_state(m: Dictionary) -> void:
	var k = int(m.get("k", -1))
	if k < 0 or k == me or not seats.has(k):
		return
	if not trails.has(k):
		trails[k] = Trail.new()
	trails[k].push(m, float(message_time))
	if not seats[k].get("done", false):
		seats[k]["dist"] = int(m.get("d", seats[k].get("dist", 0)))
		seats[k]["gold"] = maxi(0, int(m.get("c", seats[k].get("gold", 0))))   # (0.56: his coins so far)

## The race starts here (for the host as for the guests): the bets are paid in, the trails emptied.
func _begin(m: Dictionary) -> void:
	_read_seats(m.get("seats", _public_seats()))
	for k in seats:
		seats[k]["dist"] = 0
		seats[k]["gold"] = 0
		seats[k]["done"] = false
	trails.clear()
	result = {}
	last_at = -1
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
		if seats[k].get("done", false) or (seats[k].get("away", false) and float(seats[k].get("away_t", 0.0)) > AWAY_KEEP):
			best_done = maxi(best_done, int(seats[k].get("dist", 0)))
		else:
			on.append(k)
	if on.size() > 1:
		last_at = -1
		return
	if on.size() == 1:                            # (0.61) one left: « Illimité » runs on to his fall; « Dernier
		if rules.get("end", "last") == "open":    # en vie » ends LAST_WAIT s later (by distance: once he is
			return                                # beyond everyone, so he is never stopped short of winning)
		if rules.get("score", "dist") == "dist" and int(seats[on[0]].get("dist", 0)) <= best_done:
			return
		if last_at < 0:
			last_at = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_at < LAST_WAIT * 1000.0:
			return
	var dists = {}
	for k in seats:
		dists[k] = int(seats[k].get("dist", 0))
	var view = seats.duplicate(true)
	var s = settle(view, str(rules.get("score", "dist")))
	var msg = {"t": "result", "pot": s["pot"], "win": s["win"], "pay": {}, "dists": {}, "golds": {}}
	for k in seats:
		msg["pay"][str(k)] = s["pay"][k]
		msg["dists"][str(k)] = dists[k]
		msg["golds"][str(k)] = int(seats[k].get("gold", 0))
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
	for k in m.get("golds", {}):                     # (0.56) everyone's coins picked up (mine: as I have them)
		if seats.has(int(k)) and int(k) != me:
			seats[int(k)]["gold"] = maxi(0, int(m["golds"][k]))
	paid = 0
	_remember()
	for k in seats:                               # (0.61: every bet back to 0 for the next race; 0.55: ready again)
		seats[k]["done"] = false
		seats[k]["ready"] = false
		seats[k]["bet"] = 0
	message.emit({"t": "result"})
	changed.emit()
