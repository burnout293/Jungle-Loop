class_name SaveData
extends RefCounted
## Save data, shop catalogue, export / import (port of js/save.js). The save is a plain dictionary with
## the web version's own field names, so a code exported from the web game imports here, and back.

const PREFIX := "JL1."

# The shop's catalogue. The ones to equip are « Équipements », the others (power: true) « Pouvoirs ».
# costs[n] = price of level n+1. icon = assets/img/ico-<icon>.png. unlock = the player's level from which
# it can be bought. Only three upgrades can be equipped; powers are bought once and then on, unless
# switched off (save.powersOff).
# family: "up" (Équipements, to equip), "power" (Pouvoirs), "mount" (Montures: each animal its own two,
# "mount" says whose; "short" is the name in its list).
# Levels and prices can be changed in reglages/progression.txt (Progress.load_config), hence a var.
static var UPGRADES := [
	{"id": "doubleJump", "unlock": 2, "icon": "jump", "kind": "passif", "name": "Double saut", "desc": "Un second saut en l'air.", "costs": [480]},
	{"id": "spring", "unlock": 3, "icon": "spring", "kind": "passif", "name": "Ressort", "desc": "Saute plus haut.", "costs": [1000, 2400]},
	{"id": "magnet", "unlock": 2, "icon": "magnet", "kind": "passif", "name": "Aimant", "desc": "Attire les pièces proches.", "costs": [600, 1600, 3600]},
	{"id": "lucky", "unlock": 4, "icon": "lucky", "kind": "passif", "name": "Trèfle", "desc": "Avec Gemmes dispersées, les gemmes apparaissent plus souvent.", "costs": [1200, 3200]},
	{"id": "scatter", "unlock": 6, "icon": "gems", "kind": "passif", "name": "Gemmes dispersées", "desc": "De temps en temps, une gemme prend la place d'une pièce. Jaune : 5 pièces, rouge : 10, bleue : 20.", "costs": [2000, 4800, 10000]},
	{"id": "breaker", "unlock": 3, "icon": "break", "kind": "passif", "name": "Brise-tout", "desc": "Les caisses, jarres et tonneaux du décor volent en éclats sur ton passage et lâchent 4 pièces.", "costs": [1400]},
	{"id": "heart", "unlock": 7, "icon": "heart", "kind": "passif", "name": "Vitalité", "desc": "Un cœur de plus à chaque niveau, jusqu'à 4 cœurs.", "costs": [5000, 12000, 25000]},
	{"id": "drunk", "unlock": 5, "icon": "relic", "kind": "passif", "name": "Relique altérée", "desc": "Les pouvoirs de la relique sont altérés car vous l'avez endommagée en sortant du temple. Quelle idée d'utiliser de la TNT aussi.", "costs": [1600, 3600, 7200]},
	{"id": "nature", "unlock": 4, "icon": "nature", "kind": "passif", "name": "Ami de la nature", "desc": "Les montures, rares, se montrent un peu plus souvent.", "costs": [1200, 2800, 6000]},
	{"id": "dash", "unlock": 5, "icon": "dash", "kind": "actif", "name": "Esquive", "desc": "Une force étrange vous permet une accélération soudaine en détruisant tout ce qui se trouve sur votre chemin.", "costs": [1200, 2800, 5600]},
	{"id": "boots", "unlock": 6, "icon": "boots", "kind": "actif", "name": "Bottes de métal", "desc": "Plus lourd que le cuir et plus solide que le bois. Vous ferez des ravages avec ces bottes.", "costs": [2500, 5500]},
	{"id": "tnt", "unlock": 9, "icon": "tnt", "kind": "actif", "name": "Fana de TNT", "desc": "Faire sauter l'entrée du temple à chaque nouvelle tentative ne vous suffit plus. Vous allez répandre le chaos dans cette jungle maudite !", "costs": [3000, 6000, 12000]},
	{"id": "slow", "unlock": 7, "icon": "slow", "kind": "actif", "name": "Sablier", "desc": "Ralentit le temps quelques secondes.", "costs": [1800, 4000]},
	{"id": "monster", "unlock": 8, "icon": "monster", "kind": "actif", "name": "RedMonster", "desc": "Une boisson confectionnée à partir de jus d'une créature rouge surexcitée. Qui pourrait bien boire un truc pareil ?", "costs": [2500, 5000, 10000]},
	{"id": "swiss", "unlock": 4, "icon": "knife", "kind": "passif", "name": "Couteau suisse", "desc": "Sans fin : capturé par les pygmées, tu ronges tes liens et tu t'évades, une fois par course. Niveau 2 : plus facile. Niveau 3 : deux évasions.", "costs": [1500, 3500, 8000]},
	{"id": "horn", "unlock": 4, "icon": "horn", "kind": "passif", "name": "Corne de brousse", "desc": "Sans fin : le rhino répond à l'appel, et tu sors du temple sur son dos. Il t'emmène 300 m, puis 500 m, puis 800 m.", "costs": [1500, 4000, 9000]},
	{"id": "idol", "unlock": 5, "icon": "idolgold", "kind": "passif", "name": "Idole dorée", "desc": "Sans fin : les pièces ramassées valent 25 % de plus, puis 50 %, puis 75 %.", "costs": [2000, 6000, 15000]},
	{"id": "lastLeap", "unlock": 6, "icon": "leap", "kind": "passif", "name": "Dernier élan", "desc": "Au dernier cœur perdu, tu rebondis encore pour gagner quelques mètres.", "costs": [1600, 3600, 7200]},
	{"id": "flight", "unlock": 10, "icon": "flight", "kind": "passif", "power": true, "name": "Vol", "desc": "En l'air, chaque appui te fait remonter d'un coup d'hélice. Relâche : tu retombes. Niveaux 2 et 3 : tu montes plus vite.", "costs": [4800, 7000, 10000]},
	{"id": "sprint", "unlock": 8, "icon": "shoes", "kind": "passif", "power": true, "name": "Sprint", "desc": "Cours plus vite dès le départ, les jambes en tourbillon.", "costs": [4000]},
	{"id": "sphere", "unlock": 10, "icon": "sphere", "kind": "passif", "power": true, "name": "Sphère", "desc": "Roule en boule dans les endroits exigus, troncs creux et galeries : il n'y a que des trésors là-dedans.", "costs": [6000]},
	{"id": "rewind", "unlock": 12, "icon": "rewind", "kind": "passif", "name": "Rembobinage", "desc": "Une fois par course, la relique annule ta chute.", "costs": [10000]},
	{"id": "gorillaTamed", "unlock": 3, "icon": "saddle", "kind": "passif", "power": true, "family": "mount", "mount": "gorilla", "name": "Gorille dompté", "short": "Dompté", "desc": "Le gorille t'attend et se laisse attraper de plus loin, même un peu plus bas que lui.", "costs": [1200, 2800]},
	{"id": "gorillaMagnet", "unlock": 4, "icon": "magnet", "kind": "passif", "power": true, "family": "mount", "mount": "gorilla", "name": "Aimant du gorille", "short": "Aimant", "desc": "Sur le gorille, les pièces viennent à toi, de plus en plus loin à chaque niveau.", "costs": [1500, 3500]},
	{"id": "rhinoTamed", "unlock": 3, "icon": "saddle", "kind": "passif", "power": true, "family": "mount", "mount": "rhino", "name": "Rhino dompté", "short": "Dompté", "desc": "Le rhino se laisse attraper de plus loin, même si tu sautes au-dessus de lui.", "costs": [1200, 2800]},
	{"id": "rhinoMagnet", "unlock": 4, "icon": "magnet", "kind": "passif", "power": true, "family": "mount", "mount": "rhino", "name": "Aimant du rhino", "short": "Aimant", "desc": "Sur le rhino, les pièces viennent à toi, de plus en plus loin à chaque niveau.", "costs": [1500, 3500]},
	{"id": "dragonflyTamed", "unlock": 3, "icon": "saddle", "kind": "passif", "power": true, "family": "mount", "mount": "dragonfly", "name": "Libellule domptée", "short": "Domptée", "desc": "La libellule t'attend et se laisse attraper de plus loin, même un peu à côté de sa hauteur.", "costs": [1200, 2800]},
	{"id": "dragonflyMagnet", "unlock": 4, "icon": "magnet", "kind": "passif", "power": true, "family": "mount", "mount": "dragonfly", "name": "Aimant de la libellule", "short": "Aimant", "desc": "Sur la libellule, les pièces viennent à toi, de plus en plus loin à chaque niveau.", "costs": [1500, 3500]},
]

# The consumables (0.47 to 0.54, kept in stock) are gone in 0.55: the Corne de brousse, the Idole dorée and the
# Couteau suisse are upgrades to equip, the Bouclier and the Aimant simple are no more (reglages/
# decisions-economie.md). A save that had some in stock gets STOCK_COINS coins for each; the toucan's feathers
# (FEATHER_COINS each) and the shards (SHARD_COINS each, the only other money) are paid in coins too.
const CONSUMABLES := []
const STOCK_COINS := 200
const FEATHER_COINS := 25
const SHARD_COINS := 40

static func consumable(id: String) -> Dictionary:
	for c in CONSUMABLES:
		if c["id"] == id:
			return c
	return {}

static func stock(save: Dictionary, id: String) -> int:
	return int(save["stock"].get(id, 0))

## One more (or n) in stock.
static func give(save: Dictionary, id: String, n: int = 1) -> void:
	save["stock"][id] = stock(save, id) + n

## One taken from the stock. False when there is none.
static func use(save: Dictionary, id: String) -> bool:
	if stock(save, id) <= 0:
		return false
	save["stock"][id] = stock(save, id) - 1
	if save["stock"][id] == 0:
		save["stock"].erase(id)
	store(save)
	return true

# Taken out of the shop in 0.34 (Dompté and Aimant de monture are now one per animal; the Gros sac à dos is
# gone): a save that had them gets back what they cost.
const REMOVED := {"tamed": [1200, 2800], "mountMagnet": [1500, 3500], "jammer": [2400]}

## Which family of the shop an upgrade belongs to.
static func family(u: Dictionary) -> String:
	return u.get("family", "power" if u.get("power", false) else "up")

## Qualité (Réglages): the finest picture, a lighter one held at 60 images a second, or 30 to save the
## battery. "" until chosen: main.gd picks Max on a PC, Perf on a phone. (The web version's "smooth" and
## "sharp", in an imported code, become Max and Perf.)
const QUALITIES := ["max", "perf", "eco"]
const MAX_EQUIPPED := 3

## "--bac" on the command line plays on a separate, throw-away save: for trying things without
## touching the real one.
static func _bac() -> bool:
	return "--bac" in OS.get_cmdline_user_args() or "--bac" in OS.get_cmdline_args()

## 0.51: three games (« parties ») side by side, each its own save; the one played is remembered
## (user://jungle-loop-slot.txt). Partie 1 is the save of before (same file), 2 and 3 have "-p2", "-p3".
const SLOTS := 3
static var slot := 0

static func current_slot() -> int:
	if slot == 0:
		var f = "user://jungle-loop-slot" + ("-bac" if _bac() else "") + ".txt"
		slot = clampi(FileAccess.get_file_as_string(f).strip_edges().to_int(), 1, SLOTS) if FileAccess.file_exists(f) else 1
	return slot

static func set_slot(n: int) -> void:
	slot = clampi(n, 1, SLOTS)
	var f = FileAccess.open("user://jungle-loop-slot" + ("-bac" if _bac() else "") + ".txt", FileAccess.WRITE)
	if f != null:
		f.store_string(str(slot))
		f.close()

static func path(n: int = 0) -> String:
	var k = n if n > 0 else current_slot()
	return "user://jungle-loop-save-v1" + ("-bac" if _bac() else "") + ("" if k == 1 else "-p%d" % k) + ".json"

## Whether a partie has been played (its file is there).
static func slot_used(n: int) -> bool:
	return FileAccess.file_exists(path(n)) or FileAccess.file_exists(path(n) + ".new")

## What a device keeps whatever the partie: carried from one partie to the other when switching.
const DEVICE := ["musicVol", "sfxVol", "quality", "pixelFont", "dangerRim", "alertShift", "showFps", "full"]

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
		"dangerRim": false, "alertShift": false, "showFps": false, "quality": "", "full": true, "seenIntro": false,
		"equipped": [], "powersOff": [], "xp": 0.0, "quests": [], "questsDone": 0, "questSteps": {}, "lastQuest": "", "rerollDay": "", "stock": {}, "urns": 0, "urnPity": {"r": 0, "l": 0}, "skins": {"owned": [], "worn": {}}, "online": {}, "mountsOff": [], "xpv": 2, "relic": 0, "storyTry": 0}

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
	s["relic"] = mini(_int(raw.get("relic")), Game.RELIC_PIECES.size())   # 0.49: the relic's pieces won (Histoire)
	s["storyTry"] = _int(raw.get("storyTry"))
	for pair in [["musicVol", "music"], ["sfxVol", "sfx"]]:     # volumes go from 0 (off) to 10
		var v = raw.get(pair[0])
		if (v is int or v is float) and v >= 0 and v <= 10 and float(v) == floorf(v):
			s[pair[0]] = int(v)
		else:
			s[pair[0]] = 0 if raw.get(pair[1]) == false else 7
	s["pixelFont"] = raw.get("pixelFont") != false
	s["dangerRim"] = raw.get("dangerRim") == true
	s["alertShift"] = raw.get("alertShift") == true
	s["showFps"] = raw.get("showFps") == true
	var ql = {"smooth": "max", "sharp": "perf"}.get(raw.get("quality"), raw.get("quality"))
	s["quality"] = ql if ql in QUALITIES else ""
	s["full"] = raw.get("full") != false
	s["seenIntro"] = raw.get("seenIntro") == true
	var mo = raw.get("mountsOff")
	if mo is Array:
		s["mountsOff"] = mo.filter(func(k): return k in ["gorilla", "rhino", "dragonfly"])
	# the server's identity (net.gd): kept as given, if it has its four strings (it travels in the codes)
	var on = raw.get("online")
	if on is Dictionary and on.get("id") is String and on.get("secret") is String and on.get("code") is String:
		s["online"] = {"id": on["id"], "secret": on["secret"], "code": on["code"], "name": str(on.get("name", ""))}
	var ups = raw.get("upgrades")
	if ups is Dictionary:
		for id in REMOVED:
			var had = mini(_int(ups.get(id)), REMOVED[id].size())
			for i in had:
				s["coins"] += REMOVED[id][i]
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
	s["urns"] = _int(raw.get("urns"))
	# 0.55: one money only. What a save of before still holds is paid in coins (once: it is not kept)
	s["coins"] += mini(_int(raw.get("feathers")), 99) * FEATHER_COINS + _int(raw.get("shards")) * SHARD_COINS
	if raw.get("stock") is Dictionary:
		for id in raw["stock"]:
			s["coins"] += mini(_int(raw["stock"][id]), 999) * STOCK_COINS
	if raw.get("rerollDay") is String:               # the day the free change of an objective was used (0.55)
		s["rerollDay"] = str(raw["rerollDay"]).left(10)
	if raw.get("urnPity") is Dictionary:             # urns opened since the last rare, the last legendary
		s["urnPity"] = {"r": _int(raw["urnPity"].get("r")), "l": _int(raw["urnPity"].get("l"))}
	var sk = raw.get("skins")
	if sk is Dictionary:                              # the skins owned, and the one worn by each (0.47)
		if sk.get("owned") is Array:
			for id in sk["owned"]:
				if id is String and not Skins.skin(id).is_empty() and not id in s["skins"]["owned"]:
					s["skins"]["owned"].append(id)
		if sk.get("worn") is Dictionary:
			for target in sk["worn"]:
				var id = sk["worn"][target]
				if id is String and id in s["skins"]["owned"] and Skins.skin(id).get("target") == target:
					s["skins"]["worn"][target] = id
	if raw.get("questSteps") is Dictionary:          # how many times each kind of objective was completed
		for k in raw["questSteps"]:
			if Progress.KINDS.has(k) and _int(raw["questSteps"][k]) > 0:
				s["questSteps"][k] = _int(raw["questSteps"][k])
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
			if q.get("long") == true:
				s["quests"][s["quests"].size() - 1]["long"] = true
	# experience: since 0.33 a point is 20 m (it was a metre). An older save is brought to the new scale,
	# and its objectives under way pay what reglages/progression.txt says.
	if raw.get("xpv") != 2:
		s["xp"] = s["xp"] / 20.0
		for q in s["quests"]:
			if Progress.quest_cfg.has(q["k"]):
				q["reward"] = Progress.quest_cfg[q["k"]][0]["reward"]
				q["xp"] = Progress.quest_cfg[q["k"]][0]["xp"]
	s["xpv"] = 2
	Progress.fill(s)
	return s

## The save; if it was cut short (the phone stopped the game while it was being written), the copy written
## just before it (0.48: before, a cut save came back empty, all progress gone).
static func load_save(n: int = 0) -> Dictionary:
	for p in [path(n), path(n) + ".new"]:
		if FileAccess.file_exists(p):
			var raw = JSON.parse_string(FileAccess.get_file_as_string(p))
			if raw is Dictionary:
				return sanitize(raw)
	return sanitize(null)

## Written twice, one copy after the other: whenever the game is stopped, one of the two is whole.
static func store(save: Dictionary, n: int = 0) -> void:
	var text = JSON.stringify(save)
	for p in [path(n) + ".new", path(n)]:
		var f = FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			return
		f.store_string(text)
		f.close()

static func reset(n: int = 0) -> Dictionary:
	for p in [path(n), path(n) + ".new"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
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
