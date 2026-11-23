class_name Daily
extends RefCounted
## 0.57, the Course du jour. One road a day, the same for everyone (its seed comes from the date), with the
## day's rule (faster, all in the city, one heart...) and the day's items imposed; it can be run again as often
## as one likes. Each distance tier reached gives its reward once a day: reaching the third gives the first,
## the second and the third (save.daily: {day, got: [bool per tier], best}). The tiers and their rewards are
## read over these defaults from reglages/progression.txt, section [course du jour] (load_config).

## Each tier: its distance (metres), what it gives (coins or urns) and how many.
static var tiers: Array = [
	{"m": 300, "what": "coins", "n": 300},
	{"m": 700, "what": "coins", "n": 600},
	{"m": 1200, "what": "urn", "n": 1},
	{"m": 2000, "what": "coins", "n": 1500},
	{"m": 3000, "what": "urn", "n": 2},
]

## The day's rule, one of these (picked from the day's seed). speed: the start and the gain multiplied;
## biome: the whole run in that scenery; hearts: that many; mounts: false, none; kit: items added to the day's.
const RULES := [
	{"id": "fast", "name": "Pressé", "desc": "Tu pars plus vite et tu accélères 30 % plus vite.", "speed": 1.3},
	{"id": "city", "name": "Nuit dans la cité", "desc": "Toute la course dans la cité du futur.", "biome": 2},
	{"id": "dungeon", "name": "Au fond du donjon", "desc": "Toute la course dans le donjon.", "biome": 3},
	{"id": "glass", "name": "Un seul cœur", "desc": "Un seul cœur : pas de faute permise.", "hearts": 1},
	{"id": "walk", "name": "À pied", "desc": "Aucune monture ne vient.", "mounts": false},
	{"id": "wings", "name": "Ailé", "desc": "Le Vol pour tout le monde.", "kit": {"flight": 2}},
]

## What can be imposed: two of these a day (id, level).
const KIT_POOL := [["magnet", 2], ["doubleJump", 1], ["dash", 1], ["breaker", 1], ["spring", 1], ["slow", 1], ["boots", 1], ["scatter", 2], ["lastLeap", 2]]

static func load_config(text: String) -> void:
	var section = ""
	var got: Array = []
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = Tune.key(line.substr(1, line.length() - 2))
			continue
		if section != "course du jour":
			continue
		var cols: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		if cols.size() < 3 or Tune.key(cols[0]) != "palier" or not cols[1].is_valid_int():
			continue
		var words: Array = Array(cols[2].split(" ", false))
		if words.size() < 2 or not words[1].is_valid_int():
			continue
		var what = {"pieces": "coins", "pièces": "coins", "urne": "urn", "urnes": "urn"}.get(words[0].to_lower(), "")
		if what != "":
			got.append({"m": maxi(1, int(cols[1])), "what": what, "n": maxi(1, int(words[1]))})
	if not got.is_empty():
		got.sort_custom(func(a, b): return a["m"] < b["m"])
		tiers = got

static func today() -> String:
	return Time.get_date_string_from_system()

## The day's run: {day, seed, rule, kit}. The same for everyone that day.
static func of_day(day: String = "") -> Dictionary:
	var d = day if day != "" else today()
	var seed_ = absi(("jungle-loop-" + d).hash()) % 2147483647
	var rule: Dictionary = RULES[seed_ % RULES.size()]
	var kit := {}
	var a = (seed_ / 7) % KIT_POOL.size()
	var b = (a + 1 + (seed_ / 61) % (KIT_POOL.size() - 1)) % KIT_POOL.size()
	for pick in [KIT_POOL[a], KIT_POOL[b]]:
		kit[pick[0]] = pick[1]
	for k in rule.get("kit", {}):
		kit[k] = rule["kit"][k]
	return {"day": d, "seed": seed_, "rule": rule, "kit": kit}

## Today's record of the tiers won, in the save (a new day: all to win again).
static func state(save: Dictionary) -> Dictionary:
	var st = save.get("daily", {})
	if not st is Dictionary or str(st.get("day", "")) != today():
		st = {"day": today(), "got": [], "best": 0}
		save["daily"] = st
	while st["got"].size() < tiers.size():
		st["got"].append(false)
	return st

## How many tiers are won today.
static func won(save: Dictionary) -> int:
	return state(save)["got"].count(true)

## The tiers reached at `dist` metres not won yet today: won now (their rewards put in the save). Returns them.
static func claim(save: Dictionary, dist: float) -> Array:
	var st = state(save)
	var out: Array = []
	for i in tiers.size():
		if st["got"][i] or dist < float(tiers[i]["m"]):
			continue
		st["got"][i] = true
		var t: Dictionary = tiers[i]
		if t["what"] == "coins":
			save["coins"] = int(save["coins"]) + int(t["n"])
		else:
			save["urns"] = int(save["urns"]) + int(t["n"])
		out.append(i)
	st["best"] = maxi(int(st["best"]), floori(dist))
	return out

## A tier's reward, said: « 600 pièces », « 2 urnes ».
static func reward_text(i: int) -> String:
	var t: Dictionary = tiers[i]
	if t["what"] == "coins":
		return "%d pièces" % int(t["n"])
	return "1 urne" if int(t["n"]) == 1 else "%d urnes" % int(t["n"])

## The run of the day made from a new run of Game (main.gd): its rule applied.
static func apply(run, d: Dictionary) -> void:
	var rule: Dictionary = d["rule"]
	run.daily = true
	if rule.has("speed"):
		run.base *= float(rule["speed"])
		run.gain_mul = float(rule["speed"])
	if rule.has("biome"):
		run.biome = int(rule["biome"])
		run.prev_biome = run.biome
		run.next_biome_at = INF                      # (all the run in it)
	if rule.has("hearts"):
		run.hearts = int(rule["hearts"])
		run.max_hearts = run.hearts
	if rule.get("mounts", true) == false:
		run.mounts = []
