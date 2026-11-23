extends SceneTree
# The race for four without a network (0.48): four Race nodes linked by stand-in channels, as WebRTC would
# link them once the room has done its work. The lobby fills, everyone bets, the host starts, they run and
# fall one after the other, the last one gets out of reach: the result must be the same everywhere and the
# coins right (0.55: what was bet goes out, twice the bet comes back to whoever bet on the winner). Then the
# cases that go wrong: a guest whose link drops (his place waits for him, he links again; gone for good, his
# last distance stands and his stake comes back), the host who leaves (everyone's stake comes back), a tie,
# nobody betting on the winner. 0.55 too: « Prêt », the history of the group's races.
#   godot --headless --path . -s tests/race_logic.gd   (tests/ has a .gdignore: kept out of the game)

class FakeChan:
	var other = null
	var inbox: Array = []
	var open := true
	func put_packet(b: PackedByteArray) -> int:
		if other != null and other.open:
			other.inbox.append(b)
		return OK
	func get_available_packet_count() -> int:
		return inbox.size()
	func get_packet() -> PackedByteArray:
		return inbox.pop_front()
	func get_ready_state() -> int:
		return WebRTCDataChannel.STATE_OPEN if open else WebRTCDataChannel.STATE_CLOSED

class FakePeer:
	var state := WebRTCPeerConnection.STATE_CONNECTED
	var chans: Array = []
	func poll() -> void:
		pass
	func get_connection_state() -> int:
		return state
	func close() -> void:
		state = WebRTCPeerConnection.STATE_CLOSED
		for c in chans:
			c.open = false

## (0.55) The server as the guests see it when they link again: the room is there, nothing comes.
class FakeNet extends Net:
	func join_room(_save: Dictionary, _room: String) -> Dictionary:
		return {"slot": 1, "kind": "race"}
	func send_signal(_save: Dictionary, _room: String, _data: String, _to: String = "") -> Dictionary:
		return {"seq": 1}
	func read_signals(_save: Dictionary, _room: String, _since: int) -> Dictionary:
		return {"items": []}
	func close_room(_save: Dictionary, _room: String) -> Dictionary:
		return {"ok": true}
	func leave_room(_save: Dictionary, _room: String) -> Dictionary:
		return {"ok": true}
	func ice(_save: Dictionary) -> Dictionary:
		return {}

## (0.55) No real WebRTC here: a link made again goes through the stand-in pairs (pair), never a browser's.
class TestRace extends Race:
	func _link(_code: String) -> Race.Link:
		return null

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC ", what)
	else:
		print("ok   ", what)

## Two ends of a link: the host's (to guest `code`) and the guest's (to the host).
func pair(host: Race, guest: Race, code: String) -> Array:
	var hl = Race.Link.new()
	var gl = Race.Link.new()
	var hp = FakePeer.new()
	var gp = FakePeer.new()
	for k in ["ctl", "pos"]:
		var a = FakeChan.new()
		var b = FakeChan.new()
		a.other = b
		b.other = a
		hl.set(k, a)
		gl.set(k, b)
		hp.chans.append(a)
		gp.chans.append(b)
	hl.peer = hp
	gl.peer = gp
	hl.code = code
	gl.code = "host"
	hl.seat = guest.me
	host.links[code] = hl
	guest.links["host"] = gl
	return [hp, gp]

func make(names: Array) -> Array:
	var races: Array = []
	for i in names.size():
		var r = TestRace.new()
		r.save = {"coins": 1000, "online": {"name": names[i], "code": "PEPI-000%d" % i}, "skins": {"worn": {}}}
		r.me = i
		r.net = FakeNet.new()
		r.room = "TEST"
		races.append(r)
	var host: Race = races[0]
	host.role = "host"
	host.state = "lobby"
	host.seats = {0: host._seat_of_me()}
	var peers = []
	for i in range(1, races.size()):
		var g: Race = races[i]
		g.role = "guest"
		g.state = "linking"
		g.seats = {0: {"name": names[0], "code": "", "on": 0, "bet": 0}, i: g._seat_of_me()}
		peers.append(pair(host, g, "PEPI-000%d" % i))
	return [races, peers]

func tick(races: Array, n: int = 3) -> void:
	for k in n:
		for r in races:
			r._process(0.05)

## Everyone runs: each one's distance grows by `v` metres a tick until he falls at stops[i] (0: he runs on).
func run_race(races: Array, stops: Array, v: float = 20.0, ticks: int = 400) -> void:
	var dist = []
	for r in races:
		dist.append(0.0)
	for k in ticks:
		for i in races.size():
			var r: Race = races[i]
			if not r.running or r.my_seat().get("done", false) or r.my_seat().is_empty():
				continue
			dist[i] += v
			r.message_time = k * 0.05
			r.reach(r.me, dist[i])
			r.gained(floori(dist[i] / 10))           # (0.56: a coin every 10 m, as he runs)
			r.send_state({"at": k * 0.05, "x": dist[i] * 40, "y": 0, "d": floori(dist[i]), "c": floori(dist[i] / 10)})
			if stops[i] > 0 and dist[i] >= stops[i]:
				r.done(floori(dist[i]), floori(dist[i] / 10))
		for r in races:
			r._process(0.05)
		if races.all(func(r): return not r.running):
			return

func coins(r: Race) -> int:
	return int(r.save["coins"])

func _init() -> void:
	# --- a full race: four of them, bets, the last one out of reach ---
	var made = make(["Hôte", "Un", "Deux", "Trois"])
	var races: Array = made[0]
	tick(races)
	var host: Race = races[0]
	check(host.count() == 4 and races.all(func(r): return r.state == "lobby" and r.count() == 4), "the lobby fills: four places, the same on every phone")
	races[0].bet(0, 100)                         # the host on himself
	races[1].bet(1, 50)                          # Un on himself
	races[2].bet(0, 0)                           # Deux: no bet
	races[3].bet(0, 100)                         # Trois on the host
	tick(races)
	check(races.all(func(r): return r.pot() == 250), "every phone sees the same bets (250 in all)")
	check(not host.all_ready(), "nobody ready yet: no « Lancer »")
	for r in races.slice(0, 3):
		r.set_ready(true)
	tick(races)
	check(not host.all_ready() and races[1].seats[3].get("ready", true) == false, "three ready, one not: still no « Lancer »")
	races[3].set_ready(true)
	tick(races)
	check(host.all_ready() and races.all(func(r): return r.seats.values().all(func(st): return st.get("ready", false))), "all ready, seen on every phone: « Lancer »")
	host.start({"seed": 7, "biome": 0, "tier": 0, "up": {}}, 0.1)
	tick(races)
	check(races.all(func(r): return r.running), "the start reaches everybody")
	check(coins(races[0]) == 900 and coins(races[1]) == 950 and coins(races[2]) == 1000 and coins(races[3]) == 900, "the bets are paid in at the start")
	run_race(races, [700, 300, 0, 500])          # Un falls at 300, Trois at 500, the host at 700, Deux runs on
	check(races.all(func(r): return not r.running and not r.result.is_empty()), "the result comes once the last one is out of reach")
	var same = races.all(func(r): return r.result["win"] == [2] and int(r.result["pot"]) == 250)
	check(same, "the same result everywhere: Deux wins (250 bet in all)")
	check(coins(races[2]) == 1000, "nobody bet on Deux: nobody gets anything (0.55), Deux keeps his 1000")
	check(coins(races[0]) == 900 and coins(races[1]) == 950 and coins(races[3]) == 900, "the others lose their bets")
	check(races.all(func(r): return r.history.size() == 1 and r.history[0]["rows"].size() == 4), "the race is in everyone's history")
	var golds_ok = races.all(func(r):
		var g = {}
		for row in r.history[0]["rows"]:
			g[int(row["k"])] = int(row.get("gold", -1))
		return g.get(0) == 70 and g.get(1) == 30 and g.get(3) == 50 and g.get(2, 0) > 50)
	check(golds_ok, "(0.56) everyone's coins picked up, the same on every phone (70, 30, 50, and the winner's)")
	check(races.all(func(r): return not r.seats.values().any(func(st): return st.get("ready", false))), "after it, nobody is ready: each one says so again")
	check(races.all(func(r): return int(r.result["dists"][1]) == 300 and int(r.result["dists"][3]) == 500), "everyone has the same distances")

	# --- a rematch with backers: the pot goes to those who bet on the winner, as they bet ---
	races[0].bet(0, 100)
	races[1].bet(2, 200)                         # Un on Deux
	races[2].bet(2, 100)                         # Deux on himself
	races[3].bet(0, 0)
	for r in races:
		r.set_ready(true)
	tick(races)
	var before = races.map(func(r): return coins(r))
	host.start({"seed": 8, "biome": 0, "tier": 0, "up": {}}, 0.1)
	tick(races)
	run_race(races, [200, 150, 0, 100])
	var after = races.map(func(r): return coins(r))
	check(after[1] - before[1] == 200 and after[2] - before[2] == 100 and after[0] - before[0] == -100, "twice the bet to who bet on the winner: Un 200 -> 400, Deux 100 -> 200, the host loses 100")
	check(races.all(func(r): return r.history.size() == 2 and r.history[0]["n"] == 2), "the history keeps both, the latest first")

	# --- a guest leaves mid-race: his last distance stands ---
	made = make(["H", "A", "B"])
	races = made[0]
	var peers: Array = made[1]
	tick(races)
	host = races[0]
	races[0].bet(0, 100)
	races[1].bet(1, 100)
	races[2].bet(2, 100)
	tick(races)
	host.start({"seed": 9, "biome": 0, "tier": 0, "up": {}}, 0.1)
	tick(races)
	for k in 10:                                  # everyone runs a little
		for i in races.size():
			races[i].send_state({"at": k * 0.05, "x": 0, "y": 0, "d": (k + 1) * 10 * (i + 1)})
		tick(races, 1)
	peers[0][1].close()                           # A's phone goes away (he had 300 m... as last heard)
	peers[0][0].state = WebRTCPeerConnection.STATE_FAILED
	tick(races, 2)
	check(host.seats.get(1, {}).get("away", false) and not host.seats[1].get("done", false), "(0.55) the host keeps his place a while (away)")
	check(races[1].relink_t >= 0 and races[1].state == "linking", "(0.55) A links again through the room")
	for k in 50:                                  # 50 × 4 s: past AWAY_KEEP and RELINK_TIME, he never came back
		for r in races:
			r._process(4.0)
	check(host.seats.get(1, {}).get("gone", false) and host.seats[1].get("done", false), "gone for good: the host marks him out")
	check(races[1].state == "failed" and coins(races[1]) == 1000, "the one who left gets his stake back (the race never ended for him)")
	run_race([races[0], races[2]], [100, 0], 5.0)
	check(races[0].result.get("win", []) == [2] and races[2].result.get("win", []) == [2], "the others finish: B wins")

	# --- (0.55) a link drops in the lobby and comes back: the same place, the same bet ---
	made = make(["H", "A"])
	races = made[0]
	peers = made[1]
	tick(races)
	races[1].bet(0, 250)
	races[1].set_ready(true)
	tick(races)
	peers[0][1].close()
	peers[0][0].state = WebRTCPeerConnection.STATE_FAILED
	tick(races, 2)
	check(races[0].seats.get(1, {}).get("away", false) and not races[0].all_ready(), "the link drops: his place waits, he is not ready any more")
	races[1].links.clear()
	pair(races[0], races[1], "PEPI-0001")         # (as the room would link them again)
	for r in races:
		for l in r.links.values():
			l.open = false                         # (a new link: it opens, then each one says hello)
	tick(races, 3)
	check(races[0].seats.get(1, {}).get("away", true) == false and int(races[0].seats[1].get("bet", 0)) == 250 and races[0].count() == 2, "back: his own place again, his bet kept")
	check(races[1].state == "lobby" and races[1].relink_t < 0, "and he is in the lobby again")

	# --- the host leaves: every guest's stake comes back ---
	made = make(["H", "A"])
	races = made[0]
	peers = made[1]
	tick(races)
	races[0].bet(0, 300)
	races[1].bet(1, 300)
	tick(races)
	races[0].start({"seed": 10, "biome": 0, "tier": 0, "up": {}}, 0.1)
	tick(races)
	check(coins(races[1]) == 700, "the guest paid his 300 at the start")
	peers[0][0].close()
	peers[0][1].state = WebRTCPeerConnection.STATE_FAILED
	for k in 50:
		for r in races:
			r._process(4.0)
	check(races[1].state == "failed" and coins(races[1]) == 1000, "the host gone for good: the guest's 300 come back")

	# --- the sharing itself ---
	var s = Race.settle({0: {"dist": 500, "bet": 100, "on": 0}, 1: {"dist": 500, "bet": 100, "on": 1}, 2: {"dist": 200, "bet": 101, "on": 2}})
	check(s["win"] == [0, 1] and s["pay"][0] == 200 and s["pay"][1] == 200 and s["pay"][2] == 0, "a tie: whoever bet on either winner gets twice his bet")
	s = Race.settle({0: {"dist": 100, "bet": 0, "on": 0}, 1: {"dist": 50, "bet": 0, "on": 1}})
	check(s["pot"] == 0 and s["pay"][0] == 0 and s["pay"][1] == 0, "no bets: nothing moves")
	s = Race.settle({0: {"dist": 900, "bet": 0, "on": 0}, 1: {"dist": 50, "bet": 250, "on": 1}, 2: {"dist": 60, "bet": 250, "on": 1}})
	check(s["pay"][0] == 0 and s["pay"][1] == 0 and s["pay"][2] == 0, "nobody backed the winner: nobody gets anything")

	print("\nBILAN : %d vérifications, %s" % [checks, "tout bon" if fails == 0 else "%d ÉCHEC(S)" % fails])
	quit()
