class_name Progress
extends RefCounted
## Long-term progress: the player's level and the objectives (port of js/progress.js). Both live in the
## save and are fed with what happened during the last frame of a run.

# ---------- the progression file (reglages/progression.txt) ----------
# What the player may change without touching the code: the points per metre and per level, what a
# level pays, each upgrade's level and prices, each objective's goal and rewards. load_config reads it
# over these defaults; a missing or wrong line keeps the default.

static var cfg := {"mpp": 20.0, "per_level": 1000.0, "steps": [1000.0], "level_coins": 20, "long_max": 1}
static var quest_cfg := {}                   # kind -> [{"goal", "reward", "xp"}, ...]: its steps, in order

static func load_config(text: String) -> void:
	quest_cfg.clear()
	var section = ""
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			continue
		var cols: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		if cols.size() < 2:
			continue
		match section:
			"niveaux":
				var v = float(cols[1])
				if v <= 0:
					continue
				match cols[0].to_lower():
					"metres par point", "mètres par point": cfg["mpp"] = v
					"points par niveau":                  # one per level, the last for all the next ones
						var steps = Array(cols[1].split("/")).map(func(c): return float(c.strip_edges())).filter(func(c): return c > 0)
						if steps.size() > 0:
							cfg["steps"] = steps
							cfg["per_level"] = steps[steps.size() - 1]
					"pieces par niveau", "pièces par niveau": cfg["level_coins"] = int(v)
			"ameliorations", "améliorations":
				var u = SaveData.upgrade(cols[0])
				if u.is_empty() or cols.size() < 3:
					continue
				if cols[1].is_valid_int():
					u["unlock"] = int(cols[1])
				var costs = Array(cols[2].split("/")).map(func(c): return int(c.strip_edges())).filter(func(c): return c > 0)
				if costs.size() > 0:
					u["costs"] = costs
			"defis", "défis":                    # the same kind on several lines: its steps, one after the other
				if cols[0].to_lower() in ["longs a la fois", "longs à la fois"] and cols[1].is_valid_int():
					cfg["long_max"] = maxi(0, int(cols[1]))
				elif KINDS.has(cols[0]) and cols.size() >= 4 and cols[1].is_valid_float():
					if not quest_cfg.has(cols[0]):
						quest_cfg[cols[0]] = []
					quest_cfg[cols[0]].append({"goal": maxi(1, int(cols[1])), "reward": maxi(0, int(cols[2])), "xp": maxi(0, int(cols[3])),
						"long": cols.size() >= 5 and cols[4].to_lower() == "long"})

# ---------- level: a point of experience every cfg.mpp metres, plus what the objectives pay ----------

static func level_info(xp: float) -> Dictionary:
	var steps: Array = cfg["steps"]
	var level = 1
	var rest = xp
	while true:
		var need: float = steps[mini(level - 1, steps.size() - 1)]
		if rest < need:
			return {"level": level, "into": floori(rest), "need": int(need)}
		rest -= need
		level += 1
	return {}

## The experience at which a level begins.
static func level_start(level: int) -> float:
	var steps: Array = cfg["steps"]
	var x = 0.0
	for l in range(1, level):
		x += steps[mini(l - 1, steps.size() - 1)]
	return x

static func level_reward(level: int) -> int:
	return int(cfg["level_coins"]) * level

## Adds experience; returns the levels reached on the way (usually none), their coins already paid.
static func add_xp(save: Dictionary, points: float) -> Array:
	var before: int = level_info(save["xp"])["level"]
	save["xp"] += points
	var after: int = level_info(save["xp"])["level"]
	var gained: Array = []
	for l in range(before + 1, after + 1):
		save["coins"] += level_reward(l)
		save["urns"] = int(save.get("urns", 0)) + 1      # 0.47: and an urn
		gained.append(l)
	return gained

# ---------- objectives ----------

# stat: which counter feeds it. single: must be done within one run. safe: progress restarts when a
# heart is lost. needs: only offered once one of these skills is owned. text: %d is the goal.
const KINDS := {
	"dist1": {"stat": "dist", "single": true, "base": 150, "step": 75, "text": "Cours %d m en une seule course"},
	"distT": {"stat": "dist", "base": 400, "step": 250, "text": "Cours %d m en tout"},
	"coins1": {"stat": "coins", "single": true, "base": 25, "step": 15, "text": "Ramasse %d pièces en une seule course"},
	"coinsT": {"stat": "coins", "base": 80, "step": 50, "text": "Ramasse %d pièces en tout"},
	"gems": {"stat": "gems", "base": 2, "step": 1, "text": "Trouve %d gemmes"},
	"jumps": {"stat": "jumps", "base": 30, "step": 20, "text": "Saute %d fois"},
	"plats": {"stat": "plats", "base": 3, "step": 2, "text": "Atterris sur %d plateformes"},
	"safe": {"stat": "dist", "single": true, "safe": true, "base": 80, "step": 50, "text": "Cours %d m sans te faire toucher"},
	"runs": {"stat": "runs", "base": 3, "step": 1, "text": "Lance %d courses"},
	"shrooms": {"stat": "shrooms", "base": 5, "step": 3, "text": "Frôle %d champignons bleus"},
	"monkeys": {"stat": "monkeys", "single": true, "base": 2, "step": 1, "text": "Salue %d singes en une seule course"},
	"breaks": {"stat": "breaks", "base": 4, "step": 3, "needs": ["breaker", "dash", "boots", "tnt"], "text": "Casse %d obstacles"},
	"mounts": {"stat": "mounts", "base": 1, "step": 1, "text": "Chevauche %d montures", "one": "Chevauche une monture"},
	"dodges": {"stat": "dodges", "base": 2, "step": 1, "text": "Esquive %d nuées"},
	# from 0.46: the metres on each mount (once one has been met: a record past the first one), the missiles
	"gorilla": {"stat": "gorillaDist", "base": 500, "step": 500, "seen": 700, "text": "Parcours %d m avec le Gorille"},
	"rhino": {"stat": "rhinoDist", "base": 500, "step": 500, "seen": 700, "text": "Parcours %d m avec le Rhino"},
	"dragonfly": {"stat": "dragonflyDist", "base": 500, "step": 500, "seen": 700, "text": "Parcours %d m avec la Libellule"},
	"darts1": {"stat": "missiles", "single": true, "base": 3, "step": 1, "text": "Esquive %d missiles en une seule course"},
	"dartsT": {"stat": "missiles", "base": 20, "step": 10, "text": "Esquive %d missiles"},
}

## The step of a kind offered now: the first, then the next one each time it is completed; past the last,
## the last again.
static func quest_step(save: Dictionary, k: String) -> Dictionary:
	var steps: Array = quest_cfg.get(k, [])
	if steps.is_empty():
		return {}
	return steps[mini(int(save["questSteps"].get(k, 0)), steps.size() - 1)]

const MAX_ACTIVE := 3
const MAX_TIER := 12

static func quest_text(q: Dictionary) -> String:
	var kind: Dictionary = KINDS[q["k"]]
	if q["goal"] <= 1 and kind.has("one"):
		return kind["one"]
	return kind["text"] % int(q["goal"])

## Keeps three objectives going: each new one is of a kind not already on the list. They get harder,
## and pay more (coins and experience), as the player completes them.
static func fill(save: Dictionary) -> void:
	while save["quests"].size() < MAX_ACTIVE:
		var tier = mini(MAX_TIER, floori(save["questsDone"] / 3.0))
		var free: Array = []
		for k in KINDS:
			var taken = false
			for q in save["quests"]:
				if q["k"] == k:
					taken = true
			if taken or k == save["lastQuest"]:
				continue
			if KINDS[k].has("seen") and maxi(int(save["best"]), int(save["bestEndless"])) < KINDS[k]["seen"]:
				continue                             # a mount never met yet: not its objectives
			if quest_step(save, k).get("long", false) and save["quests"].filter(func(q): return q.get("long", false)).size() >= int(cfg["long_max"]):
				continue                             # one long objective at a time (they would take every place)
			if KINDS[k].has("needs"):
				var ok = false
				for id in KINDS[k]["needs"]:
					if save["upgrades"].get(id, 0) > 0:
						ok = true
				if not ok:
					continue
			free.append(k)
		var chosen: String = free[randi() % free.size()]
		var qc: Dictionary = quest_step(save, chosen)
		if qc.is_empty():
			qc = {"goal": KINDS[chosen]["base"] + KINDS[chosen]["step"] * tier, "reward": 30 + 15 * tier, "xp": 40 + 20 * tier}
		var nq = {"k": chosen, "goal": qc["goal"], "p": 0, "reward": qc["reward"], "xp": qc["xp"]}
		if qc.get("long", false):
			nq["long"] = true
		save["quests"].append(nq)

## 0.55: one objective a day may be changed for nothing (the toucan's feathers are gone).
static func today() -> String:
	return Time.get_date_string_from_system()

static func reroll_free(save: Dictionary) -> bool:
	return str(save.get("rerollDay", "")) != today()

## The day's free change: this objective goes, another kind takes its place (at the same place on the list).
## False when today's has been used.
static func reroll(save: Dictionary, q: Dictionary) -> bool:
	var i = save["quests"].find(q)
	if i < 0 or not reroll_free(save):
		return false
	save["rerollDay"] = today()
	save["quests"].remove_at(i)
	var was = save["lastQuest"]
	save["lastQuest"] = q["k"]                       # (not the same kind again at once)
	fill(save)
	save["lastQuest"] = was
	var nq = save["quests"].pop_back()
	save["quests"].insert(i, nq)
	return true

static func start_run(save: Dictionary) -> void:
	for q in save["quests"]:
		if KINDS[q["k"]].get("single", false):
			q["p"] = 0

## `stats` holds what just happened: dist, coins, gems, jumps, plats, breaks, runs, hurt... Returns the
## objectives completed by it; each one is replaced at once and its coins are paid (the caller adds their
## experience, to announce any level gained).
static func feed(save: Dictionary, stats: Dictionary) -> Array:
	var done: Array = []
	for q in save["quests"]:
		var kind: Dictionary = KINDS[q["k"]]
		if stats.get("hurt", false) and kind.get("safe", false):
			q["p"] = 0
		q["p"] = minf(q["goal"], q["p"] + stats.get(kind["stat"], 0))
		if q["p"] >= q["goal"]:
			done.append(q)
	for q in done:
		save["quests"].erase(q)
		save["coins"] += q["reward"]
		save["questsDone"] += 1
		save["questSteps"][q["k"]] = int(save["questSteps"].get(q["k"], 0)) + 1
		save["lastQuest"] = q["k"]
	if done.size() > 0:
		fill(save)
	return done
