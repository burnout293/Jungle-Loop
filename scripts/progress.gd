class_name Progress
extends RefCounted
## Long-term progress: the player's level and the objectives (port of js/progress.js). Both live in the
## save and are fed with what happened during the last frame of a run.

# ---------- level: one point of experience per metre run, plus what the objectives pay ----------

const LEVEL_BASE := 200       # level 1 -> 2 takes 200 points, each next level 150 more
const LEVEL_STEP := 150

static func level_info(xp: float) -> Dictionary:
	var level = 1
	var need = LEVEL_BASE
	var into = xp
	while into >= need:
		into -= need
		level += 1
		need += LEVEL_STEP
	return {"level": level, "into": floori(into), "need": need}

static func level_reward(level: int) -> int:
	return 20 * level

## Adds experience; returns the levels reached on the way (usually none), their coins already paid.
static func add_xp(save: Dictionary, points: float) -> Array:
	var before: int = level_info(save["xp"])["level"]
	save["xp"] += points
	var after: int = level_info(save["xp"])["level"]
	var gained: Array = []
	for l in range(before + 1, after + 1):
		save["coins"] += level_reward(l)
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
	"breaks": {"stat": "breaks", "base": 4, "step": 3, "needs": ["breaker", "dash"], "text": "Casse %d obstacles"},
	"mounts": {"stat": "mounts", "base": 1, "step": 1, "text": "Chevauche %d montures", "one": "Chevauche une monture"},
	"dodges": {"stat": "dodges", "base": 2, "step": 1, "text": "Esquive %d nuées"},
}

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
			if KINDS[k].has("needs"):
				var ok = false
				for id in KINDS[k]["needs"]:
					if save["upgrades"].get(id, 0) > 0:
						ok = true
				if not ok:
					continue
			free.append(k)
		var chosen: String = free[randi() % free.size()]
		save["quests"].append({"k": chosen, "goal": KINDS[chosen]["base"] + KINDS[chosen]["step"] * tier, "p": 0, "reward": 30 + 15 * tier, "xp": 40 + 20 * tier})

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
		save["lastQuest"] = q["k"]
	if done.size() > 0:
		fill(save)
	return done
