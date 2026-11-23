extends SceneTree
# 0.55: one money (the coins: no shards, no feathers, no consumables in stock: a save of before gets coins for
# them), the skins bought with coins at the price of their rarity, the urns giving coins or skins (a skin
# already owned: coins), the day's free change of an objective, the Corne de brousse and the Idole dorée
# equipped (Run illimitée), no feather on the road; the flyers on foot at the height they were laid at, never
# twice the same in a row, the aimed ones never twice where the last one crossed; the Affrontement watched once
# fallen (the road goes on being laid in front of the one watched).
#   godot --headless --path . -s tests/eco_055.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))
	Progress.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))
	Treasure.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))

	# --- a save of before: what it held is paid in coins ---
	var old = {"v": 1, "coins": 1000, "feathers": 2, "shards": 50, "stock": {"shield": 2, "knife": 1, "idol": 1}, "drums": {"day": "x", "best": 80}}
	var s = SaveData.sanitize(old)
	check(int(s["coins"]) == 1000 + 2 * 25 + 50 * 40 + 4 * 200, "l'ancienne sauvegarde : plumes, éclats et objets en stock payés en pièces (%d)" % int(s["coins"]))
	check(not s.has("feathers") and not s.has("shards") and not s.has("drums") and s["stock"].is_empty(), "plus de plumes, d'éclats, de Tambours ni de stock")
	var again = SaveData.sanitize(JSON.parse_string(JSON.stringify(s)))
	check(int(again["coins"]) == int(s["coins"]), "payé une fois seulement (rechargée : %d)" % int(again["coins"]))
	check(SaveData.CONSUMABLES.is_empty(), "plus aucun consommable")
	for id in ["swiss", "horn", "idol"]:
		var u = SaveData.upgrade(id)
		check(not u.is_empty() and SaveData.family(u) == "up" and u["costs"].size() == 3, "%s : un équipement à trois niveaux" % id)

	# --- skins in coins; urns: coins or skins ---
	check(Treasure.skin_price("pepito-frost") == 2500 and Skins.RARITIES["standard"]["name"] == "Commun", "un skin commun : 2500 pièces")
	var b = SaveData.blank()
	b["coins"] = 3000
	check(Treasure.buy_skin(b, "pepito-frost") and int(b["coins"]) == 500 and "pepito-frost" in b["skins"]["owned"], "acheté avec des pièces")
	check(not Treasure.buy_skin(b, "pepito-gold"), "pas assez de pièces : pas de skin")
	var kinds = {}
	var u2 = SaveData.blank()
	u2["urns"] = 400
	for i in 400:
		var res = Treasure.open(u2)
		for g in res["got"]:
			kinds[g["what"]] = true
	check(kinds.keys().all(func(k): return k in ["coins", "skin"]), "les urnes : des pièces ou des skins seulement (%s)" % str(kinds.keys()))
	check(u2["skins"]["owned"].size() == Skins.CATALOG.size(), "en 400 urnes, tous les skins (les doublons en pièces)")

	# --- the day's free change of an objective ---
	var q = SaveData.blank()
	Progress.fill(q)
	var first = q["quests"][0]
	check(Progress.reroll_free(q) and Progress.reroll(q, first), "un défi changé gratuitement")
	check(not Progress.reroll_free(q) and not Progress.reroll(q, q["quests"][0]), "une fois par jour seulement")

	# --- the Corne de brousse, the Idole dorée (Run illimitée, alone) ---
	var r = Game.new_run({"horn": 2, "idol": 1}, "endless", 3)
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	for k in 60 * 3:
		Game.update(r, 1.0 / 60, inp)
	check(r.mount != null and r.mount.kind == "rhino" and absf(r.mount.until - 500.0) < 1, "la Corne : il sort du temple sur le rhino, pour 500 m")
	check(absf(r.idol - 0.25) < 0.001, "l'Idole dorée niveau 1 : +25 %")
	var g0 = r.gold
	Game.add_gold(r, 4)
	check(r.gold - g0 == 5, "4 pièces ramassées en valent 5")
	var st = Game.new_run({"horn": 3, "idol": 3}, "story", 3)
	check(st.idol == 0.0, "pas d'Idole en Histoire")
	var bon = {}
	var br = Game.new_run({}, "endless", 5)
	for i in 300:
		Game.add_bonus(br, 30000.0 + i * 100)
	for it in br.bonuses:
		bon[it.kind] = true
	check(not bon.has("feather") and bon.has("brake"), "sur la route, plus de plume (%s)" % str(bon.keys()))

	# --- the flyers ---
	var f = Game.new_run({}, "endless", 9)
	var last = -1.0
	var same = 0
	for i in 200:
		var a = Game.dart_alt(f, 0)
		if absf(a - last) < 1:
			same += 1
		last = a
	check(same == 0, "à pied : jamais deux missiles de suite à la même hauteur")
	var m = Game.new_run({}, "endless", 4)
	m.god = true
	Game.launch(m)
	for k in 60 * 4:
		Game.update(m, 1.0 / 60, inp)
	m.obs.clear()
	var o = Game.add_dart(m, m.cam + m.view_w + 20, 170.0)
	var ys = []
	var k2 = 0
	while o.state != "go" and k2 < 600:
		m.p.y = Game.GROUND - 100 - 200 * absf(sin(k2 * 0.1))
		m.p.ground = false
		Game.update(m, 1.0 / 60, inp)
		m.events.clear()
		if o.state == "warn":
			ys.append(Game.floor_at(m, m.cam + m.sx) - (o.y + Game.DART_H / 2))
		k2 += 1
	check(ys.size() > 60 and ys.max() - ys.min() < 0.5 and absf(ys[0] - 170.0) < 1, "à pied, son « ! » reste à sa hauteur (170), quoi qu'il fasse")
	var v = Game.new_run({"flight": 1}, "endless", 6)
	v.god = true
	Game.launch(v)
	for k in 60 * 4:
		Game.update(v, 1.0 / 60, inp)
	var crossed = []
	for n in 3:
		v.obs.clear()
		var d = Game.add_dart(v, v.cam + v.view_w + 20, 170.0)
		d.aim = true
		var kk = 0
		while d.state != "go" and kk < 600:
			v.p.y = Game.floor_at(v, v.cam + v.sx) - 300   # he stays at one height
			v.p.vy = 0
			v.p.ground = false
			v.p.cruise = 1.0
			Game.update(v, 1.0 / 60, inp)
			v.events.clear()
			kk += 1
		crossed.append(d.alt)
	check(absf(crossed[1] - crossed[0]) >= Game.DART_SPREAD and absf(crossed[2] - crossed[1]) >= Game.DART_SPREAD, "avec le Vol, même s'il ne bouge pas, jamais deux missiles de suite au même endroit (%s)" % str(crossed))

	# --- watching an Affrontement ---
	var w = Game.coop_run({}, 21, 1, false, "endless")
	w.race = true
	w.god = true
	Game.launch(w)
	for k in 60 * 3:
		Game.update(w, 1.0 / 60, inp)
	w.dead = true
	w.spectating = true
	var x = w.cam + w.sx + 3000
	var laid0 = w.next_x
	for k in 60 * 5:
		x += 600.0 / 60
		Game.update(w, 1.0 / 60, inp)
		Game.spectate(w, 1.0 / 60, x)
	check(absf(w.cam + w.home - x) < 200, "la caméra suit celui qu'il regarde")
	check(w.next_x > laid0 + 2000 and w.next_x >= w.cam + w.view_w, "la route continue d'être posée devant lui")
	print("BILAN économie : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
