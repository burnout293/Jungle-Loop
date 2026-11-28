extends SceneTree
# 0.70: the heights remade. At the bottom the mist holds him and he flies on along it (no bounce); a walking
# animal stops on the cliff's top and a dragonfly waits beyond; the road there has lily pads, no pinnacles.

var fails := 0
var n := 0

func check(ok: bool, what: String) -> void:
	n += 1
	if not ok:
		fails += 1
	print(("ok   " if ok else "ÉCHEC ") + what)

func _init() -> void:
	# the mist
	var r = Game.new_run({"flight": 1}, "endless", 3)
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	for i in 300:
		Game.update(r, 1.0 / 60, inp)
	r.biome = Game.SKY
	r.prev_biome = Game.SKY
	r.biome_x = -INF
	r.next_biome_at = INF
	r.sky_ok = true
	r.p.cruise = 0
	for i in 30:
		Game.update(r, 1.0 / 60, inp)
	var lowest = -INF
	var rose = false
	for i in 240:                                    # four seconds without touching anything
		Game.update(r, 1.0 / 60, inp)
		var fl = Game.floor_at(r, r.cam + r.sx)
		if r.p.y >= fl:
			lowest = maxf(lowest, r.p.y - fl)
			if r.p.vy < -100:
				rose = true
	check(lowest >= 0 and lowest <= Game.MIST_SINK + 1 and not rose, "au plus bas, il vole le long de la brume, sans rebond (%.0f)" % lowest)
	# the gorilla at the cliff
	var g = Game.new_run({}, "endless", 4)
	g.god = true
	Game.launch(g)
	for i in 300:
		Game.update(g, 1.0 / 60, inp)
	var m = Game.Mount.new()
	m.kind = "gorilla"
	g.mount = m
	g.cliff_x = g.cam + g.sx + 120.0
	Game.update(g, 1.0 / 60, inp)
	var fly = g.items.filter(func(it): return it.kind == "dragonfly")
	check(g.mount == null and fly.size() == 1 and fly[0].x > g.cliff_x, "le gorille s'arrête avant les pitons ; une libellule attend plus loin")
	print("BILAN pitons 0.70 : %d vérifications, %d échecs" % [n, fails])
	quit()
