class_name Net
extends Node
## The game's side of the server (server/worker.js): friends, their scores, and the rooms where two
## phones meet before a coop run (the coop itself: coop.gd). Nothing at all is sent while `url` is empty,
## which it is until the server is deployed: its address goes in reglages/reseau.txt (load_config).
## "--net=<address>" on the command line, or "?net=<address>" in the page's address, points it elsewhere
## (the tests, at the server running on this computer: node server/dev.mjs).
##
## The player gets an identity the first time something is sent: a pseudonym, a friend code (PEPI-XXXX)
## and a secret only this device holds, kept in the save (save["online"]); it travels with the save code.

static var url := ""
static var page := "https://burnout293.github.io/Jungle-Loop/"   # the game's page, for the friend link (outside a browser)
static var stun: Array = ["stun:stun.l.google.com:19302"]
static var turn := {}                    # {"urls", "username", "credential"} when a relay is set
static var relay_only := false          # --relay / ?relay: through the relay or not at all (to try it)

## reglages/reseau.txt: « adresse | … » under [serveur], « stun | a / b » and the turn lines under [coop].
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
		if cols.size() < 2:
			continue
		var k = Tune.key(cols[0])
		var v: String = cols[1].strip_edges()
		match [section, k]:
			["serveur", "adresse"]:
				url = v.trim_suffix("/")
			["serveur", "page du jeu"]:
				if v.begins_with("https://"):
					page = v if v.ends_with("/") else v + "/"
			["coop", "stun"]:
				stun = Array(v.split("/")).map(func(s): return s.strip_edges()).filter(func(s): return s.begins_with("stun:"))
			["coop", "turn"]:
				if v.begins_with("turn"):
					turn["urls"] = v
			["coop", "turn identifiant"]:
				turn["username"] = v
			["coop", "turn mot de passe"]:
				turn["credential"] = v

## The benches (--test, ?test on this computer) and the throw-away save (--bac, ?bac) never talk to the
## real server: they would make it players and scores. Only an address given on purpose is used then.
static func set_from_args() -> void:
	var given := false
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--net="):
			url = a.trim_prefix("--net=")
			given = true
	var trying: bool = "--test" in args or "--bac" in args
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('net') || ''")
		if q is String and q != "":
			url = q.trim_suffix("/")
			given = true
		var t = JavaScriptBridge.eval("(new URLSearchParams(location.search).has('bac') || (['localhost','127.0.0.1'].includes(location.hostname) && new URLSearchParams(location.search).has('test'))) ? 1 : 0", true)
		trying = trying or int(t) == 1             # (a number: a JavaScript boolean may come back as one)
	if trying and not given:
		url = ""
	relay_only = "--relay" in args
	if OS.has_feature("web"):
		relay_only = relay_only or int(JavaScriptBridge.eval("new URLSearchParams(location.search).has('relay') ? 1 : 0", true)) == 1

static func enabled() -> bool:
	return url != ""

## What WebRTC is told to use to find the other phone (and to relay, if a TURN server is set).
static func ice_servers() -> Array:
	var out: Array = []
	if not stun.is_empty():
		out.append({"urls": stun})
	if turn.has("urls"):
		out.append({"urls": [turn["urls"]], "username": turn.get("username", ""), "credential": turn.get("credential", "")})
	return out

## One request: POST /api/<route> with `body`; the answer's JSON, or {"error": ...}.
func ask(route: String, body: Dictionary) -> Dictionary:
	if not enabled():
		return {"error": "off"}
	var req = HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	var err = req.request(url.trim_suffix("/") + "/api/" + route, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"error": "send"}
	var res = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "network"}
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {"error": "answer"}

## The player's identity on the server, made the first time (and stored in the save).
func identity(save: Dictionary, name: String = "") -> Dictionary:
	var on: Dictionary = save.get("online", {})
	if on.has("id"):
		return on
	var r = await ask("player", {"name": name if name != "" else "Pépito"})
	if r.has("error"):
		return {}
	save["online"] = {"id": r["id"], "secret": r["secret"], "code": r["code"], "name": name if name != "" else "Pépito"}
	SaveData.store(save)
	return save["online"]

func _with_me(save: Dictionary, body: Dictionary) -> Dictionary:
	var me = await identity(save)
	if me.is_empty():
		return {}
	body["id"] = me["id"]
	body["secret"] = me["secret"]
	return body

func _call(save: Dictionary, route: String, body: Dictionary) -> Dictionary:
	var b = await _with_me(save, body)
	return {"error": "off"} if b.is_empty() else await ask(route, b)

## The pseudonym shown to friends (16 characters at most, the server cleans it).
func rename(save: Dictionary, name: String) -> Dictionary:
	var r = await _call(save, "player/name", {"name": name})
	if r.has("name"):
		save["online"]["name"] = r["name"]
		SaveData.store(save)
	return r

## 0.48: everything about this player goes from the server (Réglages › Sauvegarde); the save forgets him.
func delete_me(save: Dictionary) -> Dictionary:
	if not save.get("online", {}).has("id"):
		return {"ok": true}
	var r = await _call(save, "player/delete", {})
	if r.get("ok", false):
		save.erase("online")
		SaveData.store(save)
	return r

## A run's distance, for the friends' board (the best of all time and of the week are worked out there).
func send_score(save: Dictionary, mode: String, dist: int) -> Dictionary:
	return await _call(save, "score", {"mode": mode, "dist": dist})

func add_friend(save: Dictionary, code: String) -> Dictionary:
	return await _call(save, "friends/add", {"code": code})

func friends(save: Dictionary) -> Dictionary:
	return await _call(save, "friends", {})

## 0.48: both stop being friends (and their invitations to each other go).
func remove_friend(save: Dictionary, code: String) -> Dictionary:
	return await _call(save, "friends/remove", {"code": code})

# ---------- the coop's meeting (the connection itself: coop.gd) ----------

## The host opens a room with the run's seed: four letters to give the other player.
func open_room(save: Dictionary, seed_: int) -> Dictionary:
	return await _call(save, "room", {"seed": seed_})

## 0.48: the host opens a race room (him and three more): four letters too.
func open_race(save: Dictionary, seed_: int) -> Dictionary:
	return await _call(save, "race", {"seed": seed_})

## The guest joins with the four letters and gets the seed: both phones will run the same road. For a race
## room, his place too: {seed, host, kind: coop | race, slot}.
func join_room(save: Dictionary, room: String) -> Dictionary:
	return await _call(save, "room/join", {"room": room})

## A race guest leaves the room: his place is free again.
func leave_room(save: Dictionary, room: String) -> Dictionary:
	return await _call(save, "room/leave", {"room": room})

## The two halves of the WebRTC handshake (offer, answer, ICE candidates) pass through the room. `to`: in a
## race room, the host speaks to one guest (his friend code); a guest always speaks to the host.
func send_signal(save: Dictionary, room: String, data: String, to: String = "") -> Dictionary:
	var body = {"room": room, "data": data}
	if to != "":
		body["to"] = to
	return await _call(save, "signal", body)

func read_signals(save: Dictionary, room: String, since: int) -> Dictionary:
	return await _call(save, "signals", {"room": room, "since": since})

## The relay (TURN) for a run for two, with credentials for a few hours: {iceServers, turn: on | off | ...}.
## Empty while the server has no TURN key (server/turn.ps1).
func ice(save: Dictionary) -> Dictionary:
	return await _call(save, "ice", {})

## Invites a friend (his code) into the room just opened: he sees it on his screen (invites).
func invite(save: Dictionary, code: String, room: String) -> Dictionary:
	return await _call(save, "invite", {"code": code, "room": room})

## The invitations waiting for this player: {items: [{room, name, code}]}.
func invites(save: Dictionary) -> Dictionary:
	return await _call(save, "invites", {})

## « Pas maintenant »: the invitation goes, the host is told.
func invite_no(save: Dictionary, room: String) -> Dictionary:
	return await _call(save, "invite/no", {"room": room})

## The host left his room: it goes (and its invitation).
func close_room(save: Dictionary, room: String) -> Dictionary:
	return await _call(save, "room/close", {"room": room})
