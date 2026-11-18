class_name Net
extends Node
## The game's side of the server (server/worker.js): friends' scores now, the coop's meeting rooms later.
## Nothing at all is sent while `url` is empty, which it is until the server is deployed (server/README.md):
## then set SERVER below. "--net=<address>" on the command line points it elsewhere (the tests, at the
## server running on this computer: node server/dev.mjs).
##
## The player gets an identity the first time something is sent: a pseudonym, a friend code (PEPI-XXXX)
## and a secret only this device holds, kept in the save (save["online"]); it travels with the save code.

const SERVER := ""                       # e.g. "https://jungle-loop.<account>.workers.dev"
static var url := SERVER

static func set_from_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net="):
			url = a.trim_prefix("--net=")

static func enabled() -> bool:
	return url != ""

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
	save["online"] = {"id": r["id"], "secret": r["secret"], "code": r["code"], "name": name}
	SaveData.store(save)
	return save["online"]

func _with_me(save: Dictionary, body: Dictionary) -> Dictionary:
	var me = await identity(save)
	if me.is_empty():
		return {}
	body["id"] = me["id"]
	body["secret"] = me["secret"]
	return body

## A run's distance, for the friends' board (the best of all time and of the week are worked out there).
func send_score(save: Dictionary, mode: String, dist: int) -> Dictionary:
	var body = await _with_me(save, {"mode": mode, "dist": dist})
	return {"error": "off"} if body.is_empty() else await ask("score", body)

func add_friend(save: Dictionary, code: String) -> Dictionary:
	var body = await _with_me(save, {"code": code})
	return {"error": "off"} if body.is_empty() else await ask("friends/add", body)

func friends(save: Dictionary) -> Dictionary:
	var body = await _with_me(save, {})
	return {"error": "off"} if body.is_empty() else await ask("friends", body)

# ---------- the coop's meeting (the WebRTC connection itself comes with the coop) ----------

## The host opens a room with the run's seed: four letters to give the other player.
func open_room(save: Dictionary, seed_: int) -> Dictionary:
	var body = await _with_me(save, {"seed": seed_})
	return {"error": "off"} if body.is_empty() else await ask("room", body)

## The guest joins with the four letters and gets the seed: both phones will run the same road.
func join_room(save: Dictionary, room: String) -> Dictionary:
	var body = await _with_me(save, {"room": room})
	return {"error": "off"} if body.is_empty() else await ask("room/join", body)

## The two halves of the WebRTC handshake (offer, answer, ICE candidates) pass through the room.
func send_signal(save: Dictionary, room: String, data: String) -> Dictionary:
	var body = await _with_me(save, {"room": room, "data": data})
	return {"error": "off"} if body.is_empty() else await ask("signal", body)

func read_signals(save: Dictionary, room: String, since: int) -> Dictionary:
	var body = await _with_me(save, {"room": room, "since": since})
	return {"error": "off"} if body.is_empty() else await ask("signals", body)
