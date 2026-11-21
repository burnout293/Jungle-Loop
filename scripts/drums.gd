class_name Drums
extends RefCounted
## The pygmies' drums (0.47): a little rhythm game, once a day for a reward (as often as one likes to
## practise). Two big drums, the low one (left) and the high one (right); beats fall from the top onto
## them, and are hit as they reach the ring. The rhythm of the day is the same for everybody (seeded by the date);
## it starts slow and gets faster. Score: a share of the best possible (perfect 2 points, good 1); the
## reward grows with it (reglages/progression.txt, section [tambours]).

static var cfg := {"length": 30.0, "bpm": [96.0, 132.0], "travel": 1.7, "perfect": 0.07, "good": 0.16}
# from this score (in %): what it gives (what, how many), every line reached adds up
static var rewards: Array = [
	{"at": 30, "what": "coins", "n": 300},
	{"at": 55, "what": "urn", "n": 1},
	{"at": 75, "what": "knife", "n": 1},
	{"at": 90, "what": "urn", "n": 1},
	{"at": 90, "what": "shards", "n": 30},
]

var notes: Array = []          # {t, lane (0 low, 1 high), hit: "" | "perfect" | "good" | "miss"}
var ticks: Array = []          # the beat (every other eighth): a soft shaker, to keep time by
var t := -2.0                  # the song's time (a little count-in before the first beat)
var points := 0
var combo := 0
var best_combo := 0
var flashes := [0.0, 0.0]      # a drum just hit, fading (per lane)
var judged := []               # the last words shown: {text, t, lane}

static func load_config(text: String) -> void:
	var section = ""
	var fresh: Array = []
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			continue
		if section != "tambours":
			continue
		var cols: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		var key: String = cols[0].to_lower()
		if key == "duree" or key == "durée":
			cfg["length"] = maxf(10.0, float(cols[1]))
		elif key == "tempo":
			var b = Array(cols[1].split("/")).map(func(c): return float(c.strip_edges()))
			if b.size() == 2 and b[0] > 30:
				cfg["bpm"] = b
		elif key.is_valid_int() and cols.size() >= 3:   # « 55 | urne | 1 »
			var what = {"pieces": "coins", "pièces": "coins", "urne": "urn", "couteau": "knife", "eclats": "shards", "éclats": "shards", "plume": "feather"}.get(cols[1].to_lower(), cols[1].to_lower())
			fresh.append({"at": int(key), "what": what, "n": maxi(1, int(cols[2]))})
	if not fresh.is_empty():
		rewards = fresh

## Today, as the phone's clock says it (one reward a day).
static func today() -> String:
	return Time.get_date_string_from_system()

## Whether today's reward is still to be played for.
static func free_today(save: Dictionary) -> bool:
	return str(save["drums"].get("day", "")) != today()

## The rhythm of `day`: eighth notes on a grid that speeds up, more of them as it goes, never both drums at once.
func make(day: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("tambours-" + day)
	notes.clear()
	ticks.clear()
	var at = 0.0
	var i_ = 0
	var L: float = cfg["length"]
	while at < L:
		var k = at / L
		var bpm = lerpf(cfg["bpm"][0], cfg["bpm"][1], k)
		var eighth = 30.0 / bpm
		var density = lerpf(0.42, 0.75, k)
		if rng.randf() < density or i_ % 4 == 0:
			var lane = 0 if rng.randf() < 0.5 else 1
			if not notes.is_empty() and at - notes[-1]["t"] < eighth * 1.5 and rng.randf() < 0.6:
				lane = notes[-1]["lane"]                 # (runs on the same drum, easier to follow)
			notes.append({"t": at, "lane": lane, "hit": ""})
		if i_ % 2 == 0:
			ticks.append(at)
		at += eighth
		i_ += 1
	t = -2.0
	points = 0
	combo = 0
	best_combo = 0

func step(d: float) -> void:
	t += d
	for i in 2:
		flashes[i] = maxf(0, flashes[i] - d * 4)
	for n in notes:
		if n["hit"] == "" and t > n["t"] + cfg["good"]:
			n["hit"] = "miss"
			combo = 0
			judged.append({"text": "Raté", "t": t, "lane": n["lane"]})
	judged = judged.filter(func(j): return t - j["t"] < 0.6)

## A drum hit: the nearest beat of that drum near the ring is judged. Returns "perfect", "good" or "".
func hit(lane: int) -> String:
	flashes[lane] = 1.0
	var best = null
	for n in notes:
		if n["hit"] != "" or n["lane"] != lane:
			continue
		if absf(n["t"] - t) <= cfg["good"] and (best == null or absf(n["t"] - t) < absf(best["t"] - t)):
			best = n
	if best == null:
		return ""
	var q = "perfect" if absf(best["t"] - t) <= cfg["perfect"] else "good"
	best["hit"] = q
	points += 2 if q == "perfect" else 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	judged.append({"text": "Parfait !" if q == "perfect" else "Bien", "t": t, "lane": lane})
	return q

func over() -> bool:
	return notes.is_empty() or t > notes[-1]["t"] + 1.2

## The score, in percent of the best possible.
func score() -> int:
	return 0 if notes.is_empty() else roundi(100.0 * points / (2.0 * notes.size()))

## What a score gives (every line reached).
static func prizes(score_: int) -> Array:
	return rewards.filter(func(r): return score_ >= int(r["at"]))

## Pays them into the save; says what they were.
static func pay(save: Dictionary, score_: int) -> Array:
	var got: Array = []
	for r in prizes(score_):
		if r["what"] == "urn":
			save["urns"] = int(save["urns"]) + int(r["n"])
			got.append({"what": "urn", "n": r["n"], "name": "%d urne%s" % [r["n"], "s" if r["n"] > 1 else ""], "icon": "ico-urn"})
		else:
			got.append(Treasure.grant(save, r["what"], int(r["n"])))
	return got
