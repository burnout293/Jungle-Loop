class_name Treasure
extends RefCounted
## The temple's urns (0.47): one per level reached, sometimes one floating on the road. Broken open (main.gd,
## the Trésor), each is common, rare or legendary; a rare one comes at the latest every cfg.rare_pity urns,
## a legendary one every cfg.leg_pity. A common or rare urn gives one thing drawn from its table (by weight),
## a legendary one everything on its table. A skin already owned gives its shards (éclats) instead, and shards
## buy the skin one wants (the shop's Skins tab). Everything here is read over these defaults from
## reglages/progression.txt, section [urnes] (load_config).

static var cfg := {"rare": 15.0, "legendary": 2.0, "rare_pity": 10, "leg_pity": 50, "skin_shards": 60, "dup_shards": 30}
# what: coins, feather, shards, skin, or a consumable's id; n: from / to; w: its weight in the draw
static var table := {
	"common": [
		{"what": "coins", "n": [150, 400], "w": 30}, {"what": "feather", "n": [1, 1], "w": 12},
		{"what": "shield", "n": [1, 1], "w": 12}, {"what": "magnet", "n": [1, 1], "w": 12},
		{"what": "idol", "n": [1, 1], "w": 8}, {"what": "horn", "n": [1, 1], "w": 8},
		{"what": "shards", "n": [10, 20], "w": 18},
	],
	"rare": [
		{"what": "knife", "n": [1, 1], "w": 30}, {"what": "skin", "n": [1, 1], "w": 30},
		{"what": "coins", "n": [1000, 2000], "w": 15}, {"what": "shards", "n": [40, 60], "w": 25},
	],
	"legendary": [
		{"what": "coins", "n": [3000, 5000], "w": 1}, {"what": "knife", "n": [2, 2], "w": 1},
		{"what": "shards", "n": [80, 80], "w": 1}, {"what": "skin", "n": [1, 1], "w": 1},
	],
}
const RARITY_KEYS := {"commune": "common", "commun": "common", "rare": "rare", "legendaire": "legendary", "légendaire": "legendary"}
const NAMES := {"common": "Commune", "rare": "Rare", "legendary": "Légendaire"}
const COLOURS := {"common": "#c9d6c3", "rare": "#5cb8ff", "legendary": "#ffd35c"}

static func load_config(text: String) -> void:
	var section = ""
	var fresh := {}
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			continue
		if section != "urnes":
			continue
		var cols: Array = Array(line.split("|")).map(func(c): return c.strip_edges())
		var key: String = cols[0].to_lower()
		if cols.size() == 2 and cols[1].is_valid_float():
			match key:
				"rare": cfg["rare"] = float(cols[1])
				"legendaire", "légendaire": cfg["legendary"] = float(cols[1])
				"rare garantie": cfg["rare_pity"] = maxi(1, int(cols[1]))
				"legendaire garantie", "légendaire garantie": cfg["leg_pity"] = maxi(1, int(cols[1]))
				"eclats pour un skin", "éclats pour un skin": cfg["skin_shards"] = maxi(1, int(cols[1]))
				"eclats d'un doublon", "éclats d'un doublon": cfg["dup_shards"] = maxi(0, int(cols[1]))
		elif cols.size() >= 4 and RARITY_KEYS.has(key):
			var rar: String = RARITY_KEYS[key]
			var n = Array(cols[2].split("/")).map(func(c): return int(c.strip_edges()))
			if n.size() == 1:
				n.append(n[0])
			if not fresh.has(rar):
				fresh[rar] = []
			fresh[rar].append({"what": _what(cols[1]), "n": [maxi(1, n[0]), maxi(1, n[1])], "w": maxf(0.0, float(cols[3]))})
	for rar in fresh:                                # a rarity written in the file replaces its whole table
		table[rar] = fresh[rar]

static func _what(word: String) -> String:
	var w = word.to_lower()
	return {"pieces": "coins", "pièces": "coins", "plume": "feather", "eclats": "shards", "éclats": "shards", "bouclier": "shield",
		"aimant": "magnet", "idole": "idol", "corne": "horn", "couteau": "knife"}.get(w, w)

## Breaks one urn of the save: what it gave, already in the save. {rarity, got: [{what, n, name, icon, id}]}.
static func open(save: Dictionary) -> Dictionary:
	if int(save["urns"]) <= 0:
		return {}
	save["urns"] = int(save["urns"]) - 1
	var pity: Dictionary = save["urnPity"]
	pity["r"] = int(pity.get("r", 0)) + 1
	pity["l"] = int(pity.get("l", 0)) + 1
	var roll = randf() * 100.0
	var rar = "common"
	if pity["l"] >= int(cfg["leg_pity"]) or roll < cfg["legendary"]:
		rar = "legendary"
	elif pity["r"] >= int(cfg["rare_pity"]) or roll < cfg["legendary"] + cfg["rare"]:
		rar = "rare"
	if rar == "legendary":
		pity["l"] = 0
		pity["r"] = 0
	elif rar == "rare":
		pity["r"] = 0
	var entries: Array = table[rar] if rar == "legendary" else [_draw(table[rar])]
	var got: Array = []
	for e in entries:
		got.append(grant(save, e["what"], randi_range(e["n"][0], e["n"][1])))
	return {"rarity": rar, "got": got}

static func _draw(entries: Array) -> Dictionary:
	var total = 0.0
	for e in entries:
		total += e["w"]
	var r = randf() * total
	for e in entries:
		r -= e["w"]
		if r <= 0:
			return e
	return entries[entries.size() - 1]

## Puts n of `what` in the save; says what it was (for the opening's card).
static func grant(save: Dictionary, what: String, n: int) -> Dictionary:
	match what:
		"coins":
			save["coins"] += n
			return {"what": what, "n": n, "name": "%d pièces" % n, "icon": "coin-icon"}
		"feather":
			var paid = Progress.add_feathers(save, n)
			return {"what": what, "n": n, "name": "Plume de toucan" if paid == 0 else "Plume de toucan (+%d pièces)" % paid, "icon": "ico-feather"}
		"shards":
			save["shards"] = int(save["shards"]) + n
			return {"what": what, "n": n, "name": "%d éclats" % n, "icon": "gem-b"}
		"skin":
			var free = Skins.CATALOG.filter(func(s): return s["rarity"] == "standard" and not s["id"] in save["skins"]["owned"])
			if free.is_empty():                       # every skin owned: its shards instead
				return grant(save, "shards", int(cfg["dup_shards"]))
			var sk: Dictionary = free[randi() % free.size()]
			save["skins"]["owned"].append(sk["id"])
			return {"what": what, "n": 1, "id": sk["id"], "name": "Skin : %s %s" % [Skins.TARGETS[sk["target"]]["name"], sk["name"]], "icon": "ico-star"}
	var c = SaveData.consumable(what)
	if c.is_empty():
		return grant(save, "coins", 100)
	SaveData.give(save, what, n)
	return {"what": what, "n": n, "name": c["name"] + ("" if n == 1 else " ×%d" % n), "icon": "ico-" + c["icon"]}

## A skin bought with shards. False if not enough, or already owned.
static func buy_skin(save: Dictionary, id: String) -> bool:
	var cost = int(cfg["skin_shards"])
	if id in save["skins"]["owned"] or int(save["shards"]) < cost or Skins.skin(id).is_empty():
		return false
	save["shards"] = int(save["shards"]) - cost
	save["skins"]["owned"].append(id)
	return true
