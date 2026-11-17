class_name SaveData
extends RefCounted
## Save data, shop catalogue, export / import (port of js/save.js). The save is a plain dictionary with
## the web version's own field names, so a code exported from the web game imports here, and back.

const PREFIX := "JL1."

# The shop's catalogue. The ones to equip are « Équipements », the others (power: true) « Pouvoirs ».
# costs[n] = price of level n+1. icon = assets/img/ico-<icon>.png. unlock = the player's level from which
# it can be bought. Only three upgrades can be equipped; powers are bought once and then on, unless
# switched off (save.powersOff).
const UPGRADES := [
	{"id": "doubleJump", "unlock": 2, "icon": "jump", "kind": "passif", "name": "Double saut", "desc": "Un second saut en l'air.", "costs": [480]},
	{"id": "spring", "unlock": 3, "icon": "spring", "kind": "passif", "name": "Ressort", "desc": "Saute plus haut.", "costs": [1000, 2400]},
	{"id": "magnet", "unlock": 2, "icon": "magnet", "kind": "passif", "name": "Aimant", "desc": "Attire les pièces proches.", "costs": [600, 1600, 3600]},
	{"id": "lucky", "unlock": 4, "icon": "lucky", "kind": "passif", "name": "Trèfle", "desc": "Avec Gemmes dispersées, les gemmes apparaissent plus souvent.", "costs": [1200, 3200]},
	{"id": "scatter", "unlock": 6, "icon": "gems", "kind": "passif", "name": "Gemmes dispersées", "desc": "De temps en temps, une gemme prend la place d'une pièce. Jaune : 5 pièces, rouge : 10, bleue : 20.", "costs": [2000, 4800, 10000]},
	{"id": "breaker", "unlock": 3, "icon": "break", "kind": "passif", "name": "Brise-tout", "desc": "Les caisses, jarres et tonneaux du décor volent en éclats sur ton passage et lâchent 4 pièces.", "costs": [1400]},
	{"id": "heart", "unlock": 7, "icon": "heart", "kind": "passif", "name": "Cœur en plus", "desc": "Un second cœur : le premier coup ne t'arrête plus.", "costs": [3600]},
	{"id": "drunk", "unlock": 5, "icon": "drunk", "kind": "passif", "name": "Faune alcoolisée", "desc": "De rares créatures deviennent éthérées : pâles et titubantes, elles ne font aucun dégât.", "costs": [1600, 3600, 7200]},
	{"id": "nature", "unlock": 4, "icon": "nature", "kind": "passif", "name": "Ami de la nature", "desc": "Les montures, rares, se montrent un peu plus souvent.", "costs": [1200, 2800, 6000]},
	{"id": "jammer", "unlock": 8, "icon": "jammer", "kind": "passif", "name": "Gros sac à dos", "desc": "Pépito a prévu un sac plus grand pour la relique. Ça réduira peut-être ses effets… ou pas.", "costs": [2400]},
	{"id": "dash", "unlock": 5, "icon": "dash", "kind": "actif", "name": "Ruée", "desc": "Fonce, invincible, en pulvérisant tout. Recharge plus vite à chaque niveau.", "costs": [1200, 2800, 5600]},
	{"id": "slow", "unlock": 7, "icon": "slow", "kind": "actif", "name": "Sablier", "desc": "Ralentit le temps quelques secondes.", "costs": [1800, 4000]},
	{"id": "lastLeap", "unlock": 6, "icon": "leap", "kind": "passif", "name": "Dernier élan", "desc": "Au dernier cœur perdu, tu rebondis encore pour gagner quelques mètres.", "costs": [1600, 3600, 7200]},
	{"id": "flight", "unlock": 10, "icon": "flight", "kind": "passif", "power": true, "name": "Vol", "desc": "En l'air, chaque appui te fait remonter d'un coup d'hélice. Relâche : tu retombes.", "costs": [4800]},
	{"id": "sprint", "unlock": 8, "icon": "shoes", "kind": "passif", "power": true, "name": "Sprint", "desc": "Cours plus vite dès le départ, les jambes en tourbillon.", "costs": [4000]},
	{"id": "sphere", "unlock": 10, "icon": "sphere", "kind": "passif", "power": true, "name": "Sphère", "desc": "Roule en boule dans les endroits exigus, troncs creux et galeries : il n'y a que des trésors là-dedans.", "costs": [6000]},
	{"id": "rewind", "unlock": 12, "icon": "rewind", "kind": "passif", "name": "Rembobinage", "desc": "Une fois par course, la relique annule ta chute.", "costs": [10000]},
]

const QUALITIES := ["auto", "smooth", "sharp"]
const MAX_EQUIPPED := 3

## "--bac" on the command line plays on a separate, throw-away save: for trying things without
## touching the real one.
static func path() -> String:
	var bac = "--bac" in OS.get_cmdline_user_args() or "--bac" in OS.get_cmdline_args()
	return "user://jungle-loop-save-v1" + ("-bac" if bac else "") + ".json"

static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}

static func is_power(id: String) -> bool:
	return upgrade(id).get("power", false)

static func blank() -> Dictionary:
	# best: the record of the Histoire mode; bestEndless: the Run illimitée's
	return {"v": 1, "coins": 0, "best": 0, "bestEndless": 0, "mode": "story", "loops": 0, "upgrades": {}, "musicVol": 7, "sfxVol": 7, "pixelFont": true,
		"dangerRim": false, "alertShift": false, "quality": "auto", "full": true, "seenIntro": false,
		"equipped": [], "powersOff": [], "xp": 0.0, "quests": [], "questsDone": 0, "lastQuest": ""}

static func _int(x) -> int:
	if (x is int or x is float) and x > 0 and is_finite(float(x)):
		return floori(x)
	return 0

## Keeps only known fields with sane types: an imported code is untrusted text.
static func sanitize(raw) -> Dictionary:
	var s = blank()
	if not raw is Dictionary:
		Progress.fill(s)
		return s
	s["coins"] = _int(raw.get("coins"))
	s["best"] = _int(raw.get("best"))
	s["bestEndless"] = _int(raw.get("bestEndless"))
	s["mode"] = "endless" if raw.get("mode") == "endless" else "story"
	s["loops"] = _int(raw.get("loops"))
	for pair in [["musicVol", "music"], ["sfxVol", "sfx"]]:     # volumes go from 0 (off) to 10
		var v = raw.get(pair[0])
		if (v is int or v is float) and v >= 0 and v <= 10 and float(v) == floorf(v):
			s[pair[0]] = int(v)
		else:
			s[pair[0]] = 0 if raw.get(pair[1]) == false else 7
	s["pixelFont"] = raw.get("pixelFont") != false
	s["dangerRim"] = raw.get("dangerRim") == true
	s["alertShift"] = raw.get("alertShift") == true
	s["quality"] = raw.get("quality") if raw.get("quality") in QUALITIES else "auto"
	s["full"] = raw.get("full") != false
	s["seenIntro"] = raw.get("seenIntro") == true
	var ups = raw.get("upgrades")
	for u in UPGRADES:
		var lvl = _int(ups.get(u["id"]) if ups is Dictionary else 0)
		if lvl > 0:
			s["upgrades"][u["id"]] = mini(lvl, u["costs"].size())
	# saves from before the three-slot rule: the first three owned upgrades are put on
	var wanted: Array = raw.get("equipped") if raw.get("equipped") is Array else s["upgrades"].keys()
	for id in wanted:
		if id is String and s["upgrades"].get(id, 0) > 0 and not is_power(id) and not id in s["equipped"] and s["equipped"].size() < MAX_EQUIPPED:
			s["equipped"].append(id)
	if raw.get("powersOff") is Array:
		for id in raw["powersOff"]:
			if id is String and is_power(id) and not id in s["powersOff"]:
				s["powersOff"].append(id)
	var xp = raw.get("xp")
	s["xp"] = float(xp) if (xp is int or xp is float) and xp > 0 else 0.0
	s["questsDone"] = _int(raw.get("questsDone"))
	if raw.get("lastQuest") is String and Progress.KINDS.has(raw["lastQuest"]):
		s["lastQuest"] = raw["lastQuest"]
	if raw.get("quests") is Array:
		for q in raw["quests"].slice(0, Progress.MAX_ACTIVE):
			if not q is Dictionary or not Progress.KINDS.has(q.get("k")) or _int(q.get("goal")) == 0:
				continue
			var dup = false
			for x in s["quests"]:
				if x["k"] == q["k"]:
					dup = true
			if dup:
				continue
			var p = q.get("p")
			s["quests"].append({"k": q["k"], "goal": _int(q["goal"]), "p": minf(_int(q["goal"]), float(p) if (p is int or p is float) and p > 0 else 0.0),
				"reward": _int(q.get("reward")), "xp": _int(q.get("xp")) if _int(q.get("xp")) > 0 else 40})
	Progress.fill(s)
	return s

static func load_save() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return sanitize(null)
	return sanitize(JSON.parse_string(FileAccess.get_file_as_string(path())))

static func store(save: Dictionary) -> void:
	var f = FileAccess.open(path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save))

static func reset() -> Dictionary:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))
	return sanitize(null)

static func export_code(save: Dictionary) -> String:
	return PREFIX + Marshalls.utf8_to_base64(JSON.stringify(save))

## Returns a save, or null when the code is not valid.
static func import_code(code: String):
	var txt = code.strip_edges()
	if not txt.begins_with(PREFIX):
		return null
	var raw = JSON.parse_string(Marshalls.base64_to_utf8(txt.substr(PREFIX.length())))
	if not raw is Dictionary or raw.get("v") != 1:
		return null
	return sanitize(raw)

static func level(save: Dictionary, id: String) -> int:
	return int(save["upgrades"].get(id, 0))

static func unlocked(save: Dictionary, u: Dictionary) -> bool:
	return not u.has("unlock") or Progress.level_info(save["xp"])["level"] >= u["unlock"] or level(save, u["id"]) > 0

## The price of the next level, or -1 when there is none.
static func next_cost(save: Dictionary, u: Dictionary) -> int:
	var lvl = level(save, u["id"])
	return int(u["costs"][lvl]) if lvl < u["costs"].size() else -1

static func buy(save: Dictionary, u: Dictionary) -> bool:
	var cost = next_cost(save, u)
	if cost < 0 or save["coins"] < cost:
		return false
	if u.has("needs") and level(save, u["needs"]) == 0:
		return false
	if not unlocked(save, u):
		return false
	save["coins"] -= cost
	save["upgrades"][u["id"]] = level(save, u["id"]) + 1
	if not u.get("power", false) and not u["id"] in save["equipped"] and save["equipped"].size() < MAX_EQUIPPED:
		save["equipped"].append(u["id"])
	store(save)
	return true

## What a run starts with: the equipped upgrades, at the level owned, and every power bought.
static func loadout(save: Dictionary) -> Dictionary:
	var up = {}
	for id in save["equipped"]:
		up[id] = level(save, id)
	for u in UPGRADES:
		if u.get("power", false) and level(save, u["id"]) > 0 and not u["id"] in save["powersOff"]:
			up[u["id"]] = level(save, u["id"])
	return up

## Switches an owned power off, or back on.
static func toggle_power(save: Dictionary, id: String) -> void:
	if id in save["powersOff"]:
		save["powersOff"].erase(id)
	else:
		save["powersOff"].append(id)
	store(save)

## Puts an owned upgrade on or takes it off. Returns false when the three slots are taken.
static func toggle_equip(save: Dictionary, id: String) -> bool:
	if is_power(id):
		return false
	if id in save["equipped"]:
		save["equipped"].erase(id)
	elif level(save, id) > 0 and save["equipped"].size() < MAX_EQUIPPED:
		save["equipped"].append(id)
	else:
		return false
	store(save)
	return true
