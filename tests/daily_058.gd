extends SceneTree
# 0.58: the Course du jour from reglages/courses-du-jour.txt and the urns of reglages/decisions-economie.md
# (part 1). Every race of the file is whole (four tiers in order, items that exist); the same race for everyone
# on a day, another the next; a race given a date of its own wins that day; each rule does what it says (a
# race keeping only some dangers has none of the others on its road); the tiers: Bronze coins, Argent a common
# urn, Or a rare one, Légende a rare one and the « objet du jour », each once a day; Or on 5 days of 7 gives a
# legendary urn; the save keeps it all; urns of a known rarity are opened first, the best first, and hold
# cosmetics or coins only. Also: the group kept on the phone (to join it again after a crash).
#   godot --headless --path . -s tests/daily_058.gd -- --bac   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func road(seed_: int, kit: Dictionary, drop: Array = []) -> Array:
	var r = Game.new_run(kit, "endless", seed_)
	r.drop_kinds = drop
	r.next_x = 3000.0
	r.calm_until = 0
	r.easy_until = 0
	while r.next_x < 60000.0:
		r.cam = r.next_x - 900
		Game.spawn_pattern(r)
	return r.obs.map(func(o): return "%s %d %d" % [o.kind, roundi(o.x), roundi(o.y)])

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Treasure.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))
	Daily.load_config(FileAccess.get_file_as_string("res://reglages/courses-du-jour.txt"))
	check(Daily.races.size() >= 8, "le fichier : toutes ses courses lues (%d)" % Daily.races.size())
	var whole = true
	for r in Daily.races:
		var t: Array = r["tiers"]
		if t.size() != 4 or not (t[0] < t[1] and t[1] < t[2] and t[2] < t[3]) or r["kit"].is_empty() or str(r["text"]) == "":
			whole = false
			print("  course incomplète : ", r["name"])
		for id in r["kit"]:
			if SaveData.upgrade(id).is_empty():
				whole = false
	check(whole, "chaque course : un texte, des objets qui existent, quatre paliers dans l'ordre")
	var hard = Daily.races.filter(func(r): return r.get("hearts", 9) == 1)
	var plain = Daily.races.filter(func(r): return r["name"] == "Classique")
	check(not hard.is_empty() and not plain.is_empty() and hard[0]["tiers"][2] < plain[0]["tiers"][2], "une course dure a des paliers plus courts (Un seul cœur : Or à %d m, Classique : %d m)" % [hard[0]["tiers"][2], plain[0]["tiers"][2]])
	check(Daily.rewards[0].has("coins") and Daily.rewards[1].get("urn", "") == "common" and Daily.rewards[2].get("urn", "") == "rare" and Daily.rewards[3].get("gift", false), "les récompenses du fichier : pièces, urne commune, urne rare, urne rare + objet du jour")

	var a = Daily.of_day("2026-11-24")
	var b = Daily.of_day("2026-11-24")
	var c = Daily.of_day("2026-11-25")
	check(a == b, "le même jour : la même course pour tous (graine, règles, objets, paliers)")
	check(a["seed"] != c["seed"], "le lendemain : une autre graine")
	var names = {}
	for k in 60:
		names[Daily.of_day("2026-%02d-%02d" % [1 + k / 28, 1 + k % 28])["race"]["name"]] = true
	check(names.size() >= 5, "les courses changent d'un jour à l'autre (%d sur 60 jours)" % names.size())
	check(Skins.skin(str(a["gift"])).get("rarity", "") in ["rare", "legendary"] and str(a["gift"]) in Skins.URN_LOOKS, "l'objet du jour : un cosmétique rare ou légendaire des urnes")
	check(road(a["seed"], a["kit"]) == road(a["seed"], a["kit"]), "la même graine : la même route")

	var keep = Daily.races
	Daily.load_config("[course] Noël\ntexte | Joyeux Noël.\nobjets | Aimant 2\npaliers | 100 / 200 / 300 / 400\ndate | 2026-12-25\n[course] Autre\ntexte | x\nobjets | Esquive 1\npaliers | 1/2/3/4")
	check(Daily.of_day("2026-12-25")["race"]["name"] == "Noël" and Daily.of_day("2026-12-24")["race"]["name"] == "Autre", "une course datée : ce jour-là, à la place du tirage")
	Daily.races = keep

	for r in Daily.races:                            # each rule does what it says
		var run = Game.new_run({}, "endless", 5)
		run.biome = 0
		Daily.apply(run, {"race": r, "kit": r["kit"], "tiers": r["tiers"]})
		var ok = run.daily
		if r.has("speed"):
			ok = ok and run.gain_mul > 1.0 and run.base > Game.SPEED_BASE
		if r.has("biome") and int(r["biome"]) != Game.SKY:
			ok = ok and run.biome == r["biome"] and run.next_biome_at == INF
		if r.has("hearts"):
			ok = ok and run.hearts == r["hearts"] and run.max_hearts == r["hearts"]
		if r.get("mounts", true) == false:
			ok = ok and run.mounts.is_empty()
		if r.has("only"):
			ok = ok and not run.drop_kinds.is_empty()
		check(ok, "la course « %s » : ses règles s'appliquent" % r["name"])
	var spiders = Daily.races.filter(func(r): return r.get("only", []) == ["araignees"])
	if not spiders.is_empty():
		var rr = Game.new_run({}, "endless", 5)
		Daily.apply(rr, {"race": spiders[0], "kit": {}, "tiers": spiders[0]["tiers"]})
		var laid = road(77, {}, rr.drop_kinds)
		var flyers = laid.filter(func(o): return o.begins_with("dart") or o.begins_with("spiky"))
		var spid = laid.filter(func(o): return o.begins_with("hover"))
		check(flyers.is_empty() and spid.size() > 10, "« Nid d'araignées » : des araignées (%d), aucun volant ni hérisson (%d)" % [spid.size(), flyers.size()])
	var skies = Daily.races.filter(func(r): return r.get("only", []).has("volants") and not r.get("only", []).has("araignees"))
	if not skies.is_empty():
		var rs = Game.new_run({}, "endless", 5)
		Daily.apply(rs, {"race": skies[0], "kit": {}, "tiers": skies[0]["tiers"]})
		var laid2 = road(78, {}, rs.drop_kinds)
		var spid2 = laid2.filter(func(o): return o.begins_with("hover"))
		var darts = laid2.filter(func(o): return o.begins_with("dart"))
		check(darts.size() > 5 and spid2.size() <= laid2.size() / 20, "« Ciel de volants » : des volants (%d), presque pas d'araignées (%d sur %d)" % [darts.size(), spid2.size(), laid2.size()])

	# --- the tiers, once a day; the week's bonus ---
	var s = SaveData.blank()
	s["coins"] = 0
	var day = Daily.of_day()
	var got = Daily.claim(s, float(day["tiers"][1]) + 5, day)
	check(got.map(func(g): return g["i"]) == [0, 1] and int(s["coins"]) == int(Daily.rewards[0]["coins"]) and int(s["urnBag"]["common"]) == 1, "l'Argent atteint : le Bronze (pièces) et l'Argent (une urne commune)")
	check(Daily.claim(s, float(day["tiers"][1]) + 50, day).is_empty(), "rejouée : un palier déjà gagné ne se gagne plus")
	got = Daily.claim(s, float(day["tiers"][2]) + 1, day)
	check(got.map(func(g): return g["i"]) == [2] and int(s["urnBag"]["rare"]) == 1 and s["daily"]["golds"] == [day["day"]], "l'Or : une urne rare, et un jour d'Or pour la semaine")
	var owned0 = s["skins"]["owned"].size()
	var coins0 = int(s["coins"])
	got = Daily.claim(s, float(day["tiers"][3]) + 1, day)
	check(got.map(func(g): return g["i"]) == [3] and int(s["urnBag"]["rare"]) == 2 and (s["skins"]["owned"].size() == owned0 + 1 or int(s["coins"]) > coins0), "la Légende : une urne rare et l'objet du jour")
	check(str(day["gift"]) in s["skins"]["owned"], "l'objet du jour est à lui")
	check(Daily.won(s) == 4 and int(s["daily"]["best"]) >= int(day["tiers"][3]), "4 paliers gagnés aujourd'hui, le meilleur du jour gardé")
	var w = SaveData.blank()                         # Or on four other days of the week, then today: the bonus
	var today_t = Time.get_unix_time_from_datetime_string(Daily.today())
	var past: Array = []
	for k in [1, 2, 4, 6]:
		past.append(Time.get_date_string_from_unix_time(today_t - k * 86400))
	w["daily"] = {"day": past[0], "got": [true, true, true, false], "best": 9999, "golds": past.duplicate()}
	got = Daily.claim(w, float(day["tiers"][2]) + 1, day)
	check(got.any(func(g): return g["i"] == 4) and int(w["urnBag"]["legendary"]) == 1 and w["daily"]["golds"].is_empty(), "l'Or 5 jours sur 7 : une urne légendaire (et on recompte)")
	var old = SaveData.blank()
	old["daily"] = {"day": Daily.today(), "got": [false, false, false, false], "best": 0, "golds": [Time.get_date_string_from_unix_time(today_t - 9 * 86400)] + past.slice(0, 3)}
	got = Daily.claim(old, float(day["tiers"][2]) + 1, day)
	check(not got.any(func(g): return g["i"] == 4) and old["daily"]["golds"].size() == 4, "un Or d'il y a plus de 7 jours ne compte plus")
	s["daily"]["day"] = "2000-01-01"                 # (yesterday's)
	check(Daily.won(s) == 0 and Daily.claim(s, float(day["tiers"][0]), day).size() == 1, "un nouveau jour : tout est à regagner")
	var kept = SaveData.sanitize(JSON.parse_string(JSON.stringify(s)))
	check(kept["daily"]["day"] == Daily.today() and kept["daily"]["got"][0] == true and kept["urnBag"]["rare"] == 2 and kept["daily"].has("golds"), "la sauvegarde garde la course du jour, ses jours d'Or et les urnes de rareté connue")

	# --- the urns: those of a known rarity first, the best first; cosmetics or coins only ---
	var u = SaveData.blank()
	u["urns"] = 2
	Treasure.add_urn(u, "common")
	Treasure.add_urn(u, "legendary")
	check(Treasure.total(u) == 4, "toutes les urnes comptées (4)")
	var drawn = Treasure.identify(u)                 # (0.68) every urn gets its rarity as the Trésor opens
	check(drawn.size() == 2 and int(u["urns"]) == 0 and Treasure.total(u) == 4, "(0.68) les urnes gagnées reçoivent leur rareté (%s)" % [drawn])
	var r1 = Treasure.open(u)
	var r2 = Treasure.open(u, "common")
	check(r1["rarity"] == "legendary" and r2["rarity"] == "common" and Treasure.total(u) == 2, "la meilleure d'abord, ou celle choisie")
	var whats = {}
	u["urns"] = 300
	seed(58)
	for k in 300:
		for g in Treasure.open(u)["got"]:
			whats[g["what"]] = true
	check(whats.keys().all(func(k): return k in ["coins", "skin"]) and u["skins"]["owned"].all(func(id): return id in Skins.URN_LOOKS), "dans les urnes : des cosmétiques des trois familles ou des pièces, rien d'autre")
	var fams = {}
	for id in Skins.URN_LOOKS:
		fams[Skins.TARGETS[Skins.skin(id)["target"]]["family"]] = true
	check(fams.size() == 3 and not Skins.URN_LOOKS.has("gorilla-silver") and not Skins.URN_LOOKS.has("buttons-stone"), "trois familles (apparence, effets, social) ; les skins des montures et des boutons restent à la boutique")

	# --- the group kept on the phone (0.57) ---
	var race = Race.new()
	race.save = {"coins": 0, "online": {"name": "Pépito", "code": "PEPI-TEST"}, "skins": {"worn": {}}}
	race.role = "guest"
	race.room = "ABCD"
	race.me = 2
	race._state("lobby", "")
	var kp = Race.kept()
	check(kp.get("room", "") == "ABCD" and kp.get("role", "") == "guest" and int(kp.get("me", -1)) == 2, "le groupe gardé sur le téléphone (salle, rôle, place)")
	race.role = ""
	race.room = ""
	race._state("idle", "")
	check(Race.kept().is_empty(), "quitté : plus rien de gardé")
	race.free()
	print("BILAN course du jour : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
