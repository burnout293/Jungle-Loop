extends SceneTree
# 0.49: Histoire's own kit (two hearts, the relic's powers only), one talk per attempt (and per piece of the
# relic held), the speed that stops growing while they talk and at its cap, the layout's pressure, the
# order the dangers come in, the 15 % bigger boxes.
#   godot --headless --path . -s tests/story_049.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func first(talks: Array, at: float) -> String:
	for tk in talks:
		if tk["at"] == at:
			return str(tk["lines"][0]).split("|")[1]
	return ""

func has_turn(talks: Array) -> bool:
	for tk in talks:
		if tk["at"] > 0:
			for l in tk["lines"]:
				if "DEMI-TOUR" in str(l).to_upper():
					return true
	return false

func _init() -> void:
	Tune.load_file()
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))

	# --- one talk per attempt ---
	var t1 = Game.talks_for(1, 0)
	check(first(t1, -1).begins_with("Halte, voleur"), "1er essai : la première rencontre")
	check(Game.talks_for(2, 0) != t1 and first(Game.talks_for(2, 0), -1).begins_with("Et voilà"), "2e essai : ramené sur la broche")
	check(first(Game.talks_for(4, 0), -1).contains("quatre morceaux"), "4e essai : les quatre morceaux")
	check(first(Game.talks_for(6, 0), -1) == first(Game.talks_for(2, 0), -1), "6e essai : reprend le 2e")
	check(first(Game.talks_for(9, 0), -1) == first(Game.talks_for(5, 0), -1), "9e essai : reprend le 5e")
	check(first(Game.talks_for(1, 1), -1).contains("couronne verte"), "la couronne gagnée : son 1er dialogue")
	check(first(Game.talks_for(3, 1), -1) == first(Game.talks_for(2, 1), -1), "jade, 3e essai : reprend le 2e du jade")
	check(first(Game.talks_for(1, 3), -1) == first(Game.talks_for(1, 1), -1), "3 morceaux sans dialogue écrit : ceux du jade")
	for n in range(1, 12):
		for c in [0, 1]:
			var tk = Game.talks_for(n, c)
			check(tk.size() == 2, "essai %d, %d morceau(x) : un départ et un 1000" % [n, c])
			check(has_turn(tk), "essai %d, %d morceau(x) : un DEMI-TOUR en route" % [n, c])

	# --- Histoire's kit, the hearts ---
	check(Game.story_kit(0).is_empty(), "aucun morceau : aucun pouvoir")
	check(Game.story_kit(1) == {"flight": 1}, "la couronne de Vorace : le Vol")
	check(Game.story_kit(9).size() == 3, "trois morceaux à gagner au plus (la mâchoire est volée)")
	var rs = Game.new_run({}, "story", 5)
	check(rs.hearts == 2, "Histoire : deux cœurs")
	var re = Game.new_run({}, "endless", 5)
	check(re.hearts == 1, "Run illimitée : un cœur sans Vitalité")
	Game.grant(rs, "dash")
	check(rs.lvl("dash") == 1 and rs.dash.full > 0, "un pouvoir gagné en route sert aussitôt")

	# --- the speed: still while they talk in the temple, then growing, capped ---
	var r = Game.new_run({}, "story", 7)
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	for i in 120:                                    # (the guards talk in the temple: a touch per line, none given)
		Game.update(r, 1.0 / 60, inp)
	check(r.pace_t == 0.0, "dans le temple, pendant qu'ils parlent, la vitesse ne monte pas")
	var e = Game.new_run({}, "endless", 8)
	e.god = true
	e.pace_t = 10000.0
	Game.update(e, 1.0 / 60, inp)
	check(e.own <= Game.SPEED_CAP + 0.01, "Run illimitée : 30 m/s au plus (%.1f)" % (e.own / Game.PPM))
	var s2 = Game.new_run({}, "story", 9)
	s2.god = true
	s2.pace_t = 10000.0
	s2.wait = 0.0
	Game.update(s2, 1.0 / 60, inp)
	check(s2.own <= Game.STORY_CAP + 0.01, "Histoire : 26 m/s au plus (%.1f)" % (s2.own / Game.PPM))
	check(is_equal_approx(Game.SPEED_CAP / Game.PPM, 30.0) and is_equal_approx(Game.STORY_CAP / Game.PPM, 26.0), "plafonds lus : 30 et 26 m/s")

	# --- the layout's pressure ---
	check(Game.pressure(e, 0) == 0.0 and Game.pressure(e, 200 * Game.PPM) == 0.0, "pas de pression au début")
	check(is_equal_approx(Game.pressure(e, 5000 * Game.PPM), 1.0), "pression pleine loin (Run illimitée)")
	check(is_equal_approx(Game.pressure(rs, 5000 * Game.PPM), Game.PRESS_STORY), "Histoire : une part de la pression")

	# --- the order the dangers come in (laid by a run alone, no upgrade) ---
	var first_at = {}
	for sd in [21, 22, 23, 24]:
		var q = Game.new_run({}, "endless", sd)
		q.god = true
		q.mounts = []
		q.next_mount = INF
		Game.launch(q)
		for i in 60 * 130:
			Game.update(q, 1.0 / 60, inp)
			for o in q.obs:
				var k: String = o.kind
				var m = o.x / Game.PPM
				if k == "hover" and q.obs.filter(func(z): return z.kind == "hover" and absf(z.x - o.x) < 1000).size() >= 4:
					k = "nest?"
				if not first_at.has(k) or m < first_at[k]:
					first_at[k] = m
			if q.fm != null and not first_at.has("swarm"):
				first_at["swarm"] = q.dist
			elif q.fm != null:
				first_at["swarm"] = minf(first_at["swarm"], q.dist)
	print("premiers (m) : ", first_at)
	check(first_at.get("hover", 0.0) >= Game.FROM_LOW - 1, "araignées dès 150 m")
	check(first_at.get("swarm", 1e9) >= 300 - 1, "nuées dès 300 m")
	check(first_at.get("dart", 1e9) >= Game.FROM_DARTS - 1, "volants dès 400 m")

	# --- 15 % bigger ---
	check(is_equal_approx(Game.HERO_H, 92.0) and is_equal_approx(Game.SPIKY_W, 78.2) and is_equal_approx(Game.HOVER_W, 69.0), "boîtes 15 % plus grandes")

	print("BILAN : ", "tout bon" if fails == 0 else "%d échec(s)" % fails, " (", checks, " vérifications)")
	quit()
