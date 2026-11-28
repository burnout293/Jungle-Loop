class_name Treasure
extends RefCounted
## The temple's urns (0.47): one per level reached, sometimes one floating on the road. Broken open (main.gd,
## the Trésor), each is common, rare or legendary; a rare one comes at the latest every cfg.rare_pity urns,
## a legendary one every cfg.leg_pity. A common or rare urn gives one thing drawn from its table (by weight),
## a legendary one everything on its table. 0.55 (reglages/decisions-economie.md): one money only, the coins;
## a skin already owned gives coins instead (about 15 % of its price), and the skins are bought with coins (the
## shop's Skins tab), at the price of their rarity. Urns are won (levels, the boss, the road), never bought.
## 0.58: they hold cosmetics only (Skins.URN_LOOKS: Pépito's look, effects, social) and coins; the Course du
## jour gives urns of a known rarity (save.urnBag), opened first, the best first.
## Everything here is read over these defaults from reglages/progression.txt, section [urnes] (load_config).

static var cfg := {"rare": 15.0, "legendary": 2.0, "rare_pity": 10, "leg_pity": 50,
	"price": {"standard": 2500, "rare": 10000, "legendary": 50000}, "dup": {"standard": 400, "rare": 1500, "legendary": 5000}}
# what: coins or skin; n: from / to; w: its weight in the draw
static var table := {
	"common": [{"what": "coins", "n": [150, 400], "w": 60}, {"what": "look:standard", "n": [1, 1], "w": 40}],
	"rare": [{"what": "look:rare", "n": [1, 1], "w": 50}, {"what": "look:standard", "n": [1, 1], "w": 25}, {"what": "coins", "n": [1000, 2000], "w": 25}],
	"legendary": [{"what": "look:legendary", "n": [1, 1], "w": 1}, {"what": "look:rare", "n": [1, 1], "w": 1}, {"what": "coins", "n": [3000, 5000], "w": 1}],
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
				"skin commun": cfg["price"]["standard"] = maxi(1, int(cols[1]))
				"skin rare": cfg["price"]["rare"] = maxi(1, int(cols[1]))
				"skin legendaire", "skin légendaire": cfg["price"]["legendary"] = maxi(1, int(cols[1]))
				"doublon commun": cfg["dup"]["standard"] = maxi(0, int(cols[1]))
				"doublon rare": cfg["dup"]["rare"] = maxi(0, int(cols[1]))
				"doublon legendaire", "doublon légendaire": cfg["dup"]["legendary"] = maxi(0, int(cols[1]))
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
	var w = Tune.key(word).strip_edges()
	if w.begins_with("objet"):                       # (0.58) « objet commun / rare / legendaire »: a cosmetic of it
		return "look:legendary" if w.contains("legendaire") else ("look:rare" if w.contains("rare") else "look:standard")
	return {"pieces": "coins", "skin": "look:standard"}.get(w, w)

## (0.58) Every urn of the save: the ones of a known rarity (the Course du jour's) and the others.
static func total(save: Dictionary) -> int:
	var n = int(save.get("urns", 0))
	var bag: Dictionary = save.get("urnBag", {})
	for k in bag:
		n += int(bag[k])
	return n

## (0.58) An urn of a known rarity (common, rare, legendary), put in the save.
static func add_urn(save: Dictionary, rarity: String, n: int = 1) -> void:
	if not save.get("urnBag") is Dictionary:
		save["urnBag"] = {}
	save["urnBag"][rarity] = int(save["urnBag"].get(rarity, 0)) + n

## (0.58) A cosmetic given (the urns, the Course du jour's « objet du jour »): already owned, coins instead.
static func give_look(save: Dictionary, id: String) -> Dictionary:
	var sk = Skins.skin(id)
	if sk.is_empty():
		return grant(save, "coins", 100)
	var label = "%s : %s" % [Skins.TARGETS[sk["target"]]["name"], sk["name"]]
	if id in save["skins"]["owned"]:
		var dup = int(cfg["dup"].get(sk["rarity"], 400))
		save["coins"] += dup
		return {"what": "coins", "n": dup, "name": "Doublon (%s) : %d pièces" % [label, dup], "icon": "coin-icon"}
	save["skins"]["owned"].append(id)
	return {"what": "skin", "n": 1, "id": id, "name": label, "icon": "ico-star"}

## (0.68) Every urn of the save gets its rarity: the ones won (levels, the road, the boss) are drawn now (with the
## same odds and guarantees as before, when they were drawn as broken) and go into the bag of known rarities, so
## the Trésor shows each in its own colours. Returns the rarities drawn.
static func identify(save: Dictionary) -> Array:
	var out: Array = []
	while int(save.get("urns", 0)) > 0:
		save["urns"] = int(save["urns"]) - 1
		var rar = _roll(save)
		add_urn(save, rar)
		out.append(rar)
	return out

## Breaks one urn of the save (0.68: of the rarity asked, else the best there is): what it gave, already in the
## save. {rarity, got: [{what, n, name, icon, id}]}.
static func open(save: Dictionary, want: String = "") -> Dictionary:
	identify(save)
	var bag: Dictionary = save.get("urnBag", {})
	if want != "" and int(bag.get(want, 0)) > 0:
		bag[want] = int(bag[want]) - 1
		return _open_as(save, want)
	for rk in ["legendary", "rare", "common"]:        # (0.58) the Course du jour's first, the best first
		if int(bag.get(rk, 0)) > 0:
			bag[rk] = int(bag[rk]) - 1
			return _open_as(save, rk)
	return {}

## The count of one rarity in the bag.
static func count(save: Dictionary, rar: String) -> int:
	return int(save.get("urnBag", {}).get(rar, 0))

## One urn's rarity, drawn: legendary every cfg.leg_pity at the latest, rare every cfg.rare_pity.
static func _roll(save: Dictionary) -> String:
	if not save.get("urnPity") is Dictionary:
		save["urnPity"] = {"r": 0, "l": 0}
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
	return rar

static func _open_as(save: Dictionary, rar: String) -> Dictionary:
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
		"skin":                                      # (an old line of the file: a common cosmetic)
			return grant(save, "look:standard", 1)
	if what.begins_with("look:"):                    # (0.58) a cosmetic of that rarity, drawn among the urns'
		var rar = what.trim_prefix("look:")
		var pool = Skins.URN_LOOKS.filter(func(id): return Skins.skin(id)["rarity"] == rar)
		if pool.is_empty():
			return grant(save, "coins", int(cfg["dup"].get(rar, 400)))
		return give_look(save, pool[randi() % pool.size()])
	return grant(save, "coins", 100)

## A skin's price in coins (0.55: the price of its rarity).
static func skin_price(id: String) -> int:
	return int(cfg["price"].get(Skins.skin(id).get("rarity", "standard"), 2500))

## A skin bought with coins. False if not enough, or already owned.
static func buy_skin(save: Dictionary, id: String) -> bool:
	var cost = skin_price(id)
	if id in save["skins"]["owned"] or int(save["coins"]) < cost or Skins.skin(id).is_empty():
		return false
	save["coins"] = int(save["coins"]) - cost
	save["skins"]["owned"].append(id)
	return true
