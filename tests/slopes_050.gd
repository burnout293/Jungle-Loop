extends SceneTree
# 0.50: the forest's platforms that slope (fixed): the top under any x, landing on one, running up and down
# it, the coins of the "hills" stretch following it (and its gem, 110 above the top under it).
#   godot --headless --path . -s tests/slopes_050.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

## Runs a road a while, then lays a sloped platform under the hero and drops him on it: where he stands,
## frame after frame, against the platform's top under him.
func ride(slope: float) -> Dictionary:
	var r = Game.new_run({}, "endless")
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	var t = 0.0
	while t < 6.0:                                   # out of the temple, running
		Game.update(r, 1.0 / 60, inp)
		t += 1.0 / 60
	r.obs.clear()
	var px = r.cam + r.sx
	var pl = Game.add_isle(r, px - 40, 0.0, 1)
	pl.y = minf(Game.floor_at(r, pl.x), Game.floor_at(r, pl.x + pl.w)) - 180 - maxf(0, -slope)
	pl.slope = slope
	r.p.y = Game.top_at(pl, px) - 90
	r.p.vy = 0
	r.p.ground = false
	var landed = false
	var worst = 0.0
	var on_frames = 0
	for k in 240:
		Game.update(r, 1.0 / 60, inp)
		var x = r.cam + r.sx
		if r.p.plat == pl:
			landed = true
			on_frames += 1
			worst = maxf(worst, absf(r.p.y - Game.top_at(pl, x)))
		elif landed:
			break
	return {"landed": landed, "worst": worst, "frames": on_frames}

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	var pl = Game.Plat.new()
	pl.x = 1000
	pl.y = 400
	pl.w = 240
	pl.slope = -45
	check(is_equal_approx(Game.top_at(pl, 1000), 400), "la pente : le bord gauche")
	check(is_equal_approx(Game.top_at(pl, 1240), 355), "la pente : le bord droit, 45 plus haut")
	check(is_equal_approx(Game.top_at(pl, 1120), 377.5), "la pente : le milieu")
	check(Game.top_at(pl, 900) == 400 and Game.top_at(pl, 1400) == 355, "la pente : bornée aux deux bouts")
	for slope in [-45.0, -27.0, 0.0, 27.0, 45.0]:
		var res = ride(slope)
		check(res["landed"], "pente %d : il s'y pose" % slope)
		check(res["frames"] > 8, "pente %d : il y court un moment (%d images)" % [slope, res["frames"]])
		check(res["worst"] < 0.5, "pente %d : ses pieds suivent le dessus (écart %.2f)" % [slope, res["worst"]])
	# the "hills" stretches of the forest: their sloped platforms, their coins on the slope
	var sloped = 0
	var coins_off = 0
	for sd in 60:                                    # (the same roads each time: seeds 500 to 559)
		var r = Game.coop_run({}, 500 + sd, 0, false, "endless")
		r.coop = false
		r.biome = 0
		r.prev_biome = 0
		Game.launch(r)
		var inp = Game.Controls.new()
		r.god = true
		var t = 0.0
		while t < 25.0:
			Game.update(r, 1.0 / 30, inp)
			t += 1.0 / 30
			for p2 in r.plats:
				if p2.slope != 0 and not p2.has_meta("seen"):
					p2.set_meta("seen", true)
					sloped += 1
					for co in r.coins:
						var off = absf(co.y - (Game.top_at(p2, co.x) - 40))
						if co.x > p2.x and co.x < p2.x + p2.w and off > 1 and off < 20:   # (a coin of its line, not where it should be)
							coins_off += 1
							print("pièce x %d y %d, dessus %d, plateforme %d..%d pente %d" % [co.x, co.y, Game.top_at(p2, co.x), p2.x, p2.x + p2.w, p2.slope])
	check(sloped > 0, "des plateformes en pente sortent dans la forêt (%d vues)" % sloped)
	check(coins_off == 0, "les pièces suivent la pente (%d à côté)" % coins_off)
	print("BILAN pentes : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
