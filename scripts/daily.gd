class_name Daily
extends RefCounted
## The Course du jour (0.57; 0.58: reglages/decisions-economie.md, part 1). Every possible race is written in
## reglages/courses-du-jour.txt (load_config): its text, its changed rules (speed, one scenery, hearts, no
## mount, only some obstacles), the items it imposes and its four tiers, shorter when it is harder. Each day
## one of them is drawn from the date (the same for everyone; a race may also be given a date of its own), on a
## road of the day's seed; it can be run again as often as one likes. Each tier (Bronze, Argent, Or, Légende)
## gives its reward once a day, when it is first passed: reaching the third gives the first and the second too.
## The rewards are the same for every race (section [recompenses]): coins, urns of a known rarity, and at
## Légende the « objet du jour », a cosmetic drawn from the urns' catalogue (Skins). Gold reached on 5 days of 7
## gives a legendary urn. save.daily: {day, got: [bool per tier], best, golds: [days Or was reached]}.

const TIER_NAMES := ["Bronze", "Argent", "Or", "Légende"]
const TIER_COLOURS := ["#e0a060", "#c9d6e8", "#ffd35c", "#e7a6ff"]
const BIOME_WORDS := {"foret": 0, "jungle": 0, "pitons": 1, "cite": 2, "ville": 2, "donjon": 3}

## Every race of the file: {name, text, speed, biome, hearts, mounts, only: [families], kit: {id: level},
## tiers: [4 distances], weight, date}. A few written here, used when the file is missing or empty.
static var races: Array = [
	{"name": "Classique", "text": "La course de tous les jours, sans surprise.", "kit": {"magnet": 2, "doubleJump": 1}, "tiers": [400, 1000, 2000, 3500], "weight": 1.0},
	{"name": "Pressé", "text": "Tu pars plus vite et tu accélères 30 % plus vite.", "speed": 1.3, "kit": {"dash": 1, "spring": 1}, "tiers": [300, 800, 1600, 2800], "weight": 1.0},
	{"name": "Un seul cœur", "text": "Un seul cœur : pas de faute permise.", "hearts": 1, "kit": {"dash": 1, "magnet": 2}, "tiers": [250, 600, 1200, 2200], "weight": 1.0},
]
## What each tier gives: {coins: n} or {urn: rarity}, and {gift: true} for the « objet du jour »; week: Or
## reached on `days` days of the last 7 gives that urn.
static var rewards: Array = [{"coins": 300}, {"urn": "common"}, {"urn": "rare"}, {"urn": "rare", "gift": true}]
static var week := {"urn": "legendary", "days": 5}

## Obstacle families a race may keep only (« obstacles | araignees, volants »): the road's kinds of each (game.gd).
const FAMILIES := {
	"herissons": ["spiky", "double"],
	"araignees": ["hover", "spiders", "nest", "lowhover", "skyhover", "curtain"],
	"volants": ["fly", "wave"],
	"rondins": ["log"],
}

static func load_config(text: String) -> void:
	var found: Array = []
	var cur = null
	var section = ""
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("["):
			var close = line.find("]")
			if close < 0:
				continue
			section = Tune.key(line.substr(1, close - 1)).strip_edges()
			if section == "course":
				cur = {"name": line.substr(close + 1).strip_edges(), "text": "", "kit": {}, "tiers": [], "weight": 1.0}
				found.append(cur)
			else:
				cur = null
			continue
		var cols: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		if cols.size() < 2:
			continue
		var key = Tune.key(cols[0]).strip_edges()
		var val: String = cols[1]
		if section == "recompenses":
			_reward_line(key, val)
			continue
		if cur == null:
			continue
		match key:
			"texte": cur["text"] = val
			"vitesse": cur["speed"] = clampf(float(val), 0.5, 2.5)
			"decor":
				var b = BIOME_WORDS.get(Tune.key(val).strip_edges(), -1)
				if b >= 0:
					cur["biome"] = b
			"coeurs": cur["hearts"] = clampi(int(val), 1, 9)
			"montures": cur["mounts"] = Tune.key(val).strip_edges() not in ["non", "aucune", "0"]
			"obstacles":
				cur["only"] = Array(val.split(",")).map(func(w): return Tune.key(w).strip_edges()).filter(func(w): return FAMILIES.has(w))
			"objets":
				for part in val.split(","):
					var words = Array(part.strip_edges().split(" ", false))
					if words.is_empty():
						continue
					var lv = 1
					if words.size() > 1 and str(words[-1]).is_valid_int():
						lv = int(words.pop_back())
					var id = _item_id(" ".join(words))
					if id != "":
						cur["kit"][id] = clampi(lv, 1, 5)
			"paliers":
				cur["tiers"] = Array(val.split("/")).map(func(w): return maxi(1, int(w.strip_edges()))).slice(0, 4)
			"poids": cur["weight"] = maxf(0.0, float(val))
			"date": cur["date"] = val.left(10)
	found = found.filter(func(r): return r["tiers"].size() == 4)
	for r in found:
		r["tiers"].sort()
	if not found.is_empty():
		races = found

static func _reward_line(key: String, val: String) -> void:
	var idx = {"bronze": 0, "argent": 1, "or": 2, "legende": 3}.get(key, -1)
	if key == "semaine jours":
		week["days"] = clampi(int(val), 1, 7)
		return
	var r = _reward_of(val)
	if r.is_empty():
		return
	if key == "semaine":
		week["urn"] = r.get("urn", "legendary")
	elif idx >= 0:
		rewards[idx] = r

## « pieces 300 », « urne commune », « urne rare + objet du jour » -> {coins: 300} / {urn: rarity, gift}.
static func _reward_of(val: String) -> Dictionary:
	var k = Tune.key(val)
	var out := {}
	var words = Array(k.split(" ", false))
	if words.size() >= 2 and words[0] in ["pieces", "piece"] and str(words[1]).is_valid_int():
		out["coins"] = maxi(1, int(words[1]))
	elif k.begins_with("urne"):
		out["urn"] = "legendary" if k.contains("legendaire") else ("rare" if k.contains("rare") else "common")
	if k.contains("objet du jour"):
		out["gift"] = true
	return out

## An item of the file by its id (« magnet ») or its French name (« Aimant », « Double saut »).
static func _item_id(word: String) -> String:
	var k = Tune.key(word).strip_edges()
	for u in SaveData.UPGRADES:
		if Tune.key(u["id"]) == k or Tune.key(u["name"]).strip_edges() == k:
			return u["id"]
	return ""

static func today() -> String:
	return Time.get_date_string_from_system()

## The day's run: {day, seed, race (its dict), rule (the same: name, desc), kit, tiers, gift}. The same for all.
static func of_day(day: String = "") -> Dictionary:
	var d = day if day != "" else today()
	var seed_ = absi(("jungle-loop-" + d).hash()) % 2147483647
	var pick: Dictionary = {}
	for r in races:
		if str(r.get("date", "")) == d:
			pick = r
	if pick.is_empty():
		var total = 0.0
		for r in races:
			if not r.has("date"):
				total += float(r["weight"])
		var dice = RandomNumberGenerator.new()      # (its own dice, from the day's seed: well mixed)
		dice.seed = seed_
		var at = dice.randf() * total
		for r in races:
			if r.has("date"):
				continue
			at -= float(r["weight"])
			if at < 0 and float(r["weight"]) > 0:
				pick = r
				break
		if pick.is_empty():
			pick = races[0]
	var gift = _gift_of(seed_)
	return {"day": d, "seed": seed_, "race": pick, "rule": {"name": pick["name"], "desc": pick["text"]}, "kit": pick["kit"].duplicate(),
		"tiers": pick["tiers"].duplicate(), "gift": gift}

## The « objet du jour » of a seed: a rare or legendary cosmetic of the urns, drawn from the day (none: "").
static func _gift_of(seed_: int) -> String:
	var pool = Skins.URN_LOOKS.filter(func(id): return Skins.skin(id).get("rarity", "") in ["rare", "legendary"])
	var dice = RandomNumberGenerator.new()
	dice.seed = seed_ + 11
	return pool[dice.randi() % pool.size()] if not pool.is_empty() else ""

## Today's record of the tiers won, in the save (a new day: all to win again; the golds of the week kept).
static func state(save: Dictionary) -> Dictionary:
	var st = save.get("daily", {})
	if not st is Dictionary:
		st = {}
	if str(st.get("day", "")) != today():
		st = {"day": today(), "got": [], "best": 0, "golds": Array(st.get("golds", []))}
		save["daily"] = st
	if not st.has("golds"):
		st["golds"] = []
	while st["got"].size() < 4:
		st["got"].append(false)
	return st

## How many tiers are won today.
static func won(save: Dictionary) -> int:
	return state(save)["got"].slice(0, 4).count(true)

## The tiers reached at `dist` metres not won yet today: won now (their rewards in the save). Returns what was
## won, each {i (the tier; 4: the week's bonus), text, icon}.
static func claim(save: Dictionary, dist: float, d: Dictionary = {}) -> Array:
	var day = d if not d.is_empty() else of_day()
	var st = state(save)
	var out: Array = []
	for i in 4:
		if st["got"][i] or dist < float(day["tiers"][i]):
			continue
		st["got"][i] = true
		var r: Dictionary = rewards[i]
		var said = _give(save, r, day)
		out.append({"i": i, "text": "%s : %s" % [TIER_NAMES[i], said], "icon": "coin-icon" if r.has("coins") else "ico-urn"})
		if i == 2:                                   # Or: a day for the week's bonus
			var golds: Array = st["golds"]
			if not golds.has(day["day"]):
				golds.append(day["day"])
			var now = Time.get_unix_time_from_datetime_string(day["day"])
			st["golds"] = golds.filter(func(g): return now - Time.get_unix_time_from_datetime_string(str(g)) < 7 * 86400)
			if st["golds"].size() >= int(week["days"]):
				Treasure.add_urn(save, str(week["urn"]))
				st["golds"] = []
				out.append({"i": 4, "text": "L'Or %d jours sur 7 : une urne %s !" % [int(week["days"]), Treasure.NAMES[str(week["urn"])].to_lower()], "icon": "ico-urn"})
	st["best"] = maxi(int(st["best"]), floori(dist))
	return out

static func _give(save: Dictionary, r: Dictionary, day: Dictionary) -> String:
	var words: Array = []
	if r.has("coins"):
		save["coins"] = int(save["coins"]) + int(r["coins"])
		words.append("%d pièces" % int(r["coins"]))
	if r.has("urn"):
		Treasure.add_urn(save, str(r["urn"]))
		words.append("urne %s" % Treasure.NAMES[str(r["urn"])].to_lower())
	if r.get("gift", false) and str(day.get("gift", "")) != "":
		var g = Treasure.give_look(save, str(day["gift"]))
		words.append(str(g["name"]))
	return " + ".join(words)

## A tier's reward, said: « 300 pièces », « urne rare + objet du jour ».
static func reward_text(i: int) -> String:
	var r: Dictionary = rewards[i]
	var words: Array = []
	if r.has("coins"):
		words.append("%d pièces" % int(r["coins"]))
	if r.has("urn"):
		words.append("urne %s" % Treasure.NAMES[str(r["urn"])].to_lower())
	if r.get("gift", false):
		words.append("objet du jour")
	return " + ".join(words)

## The run of the day made from a new run of Game (main.gd): its rules applied.
static func apply(run, d: Dictionary) -> void:
	var r: Dictionary = d.get("race", {})
	run.daily = true
	if r.has("speed"):
		run.base *= float(r["speed"])
		run.gain_mul = float(r["speed"])
	if r.has("biome") and (int(r["biome"]) != Game.SKY or int(d["kit"].get("flight", 0)) > 0):
		run.biome = int(r["biome"])
		run.prev_biome = run.biome
		run.next_biome_at = INF                      # (all the run in it)
	if r.has("hearts"):
		run.hearts = int(r["hearts"])
		run.max_hearts = run.hearts
	if r.get("mounts", true) == false:
		run.mounts = []
	var only: Array = []
	for fam in r.get("only", []):
		only.append_array(FAMILIES[fam])
	if not only.is_empty():                          # the dangers of the families kept, none of the others
		var drop: Array = []
		for fam in FAMILIES:
			if fam not in r.get("only", []):
				drop.append_array(FAMILIES[fam])
		run.drop_kinds = drop

## The day's four tiers as boards along the road (render.gd draws them in their colours).
static func tier_signs(d: Dictionary) -> Array:
	var out: Array = []
	for i in 4:
		out.append({"d": int(d["tiers"][i]), "name": TIER_NAMES[i], "own": false, "tier": i, "x": INF})
	return out
