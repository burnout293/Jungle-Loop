extends SceneTree
# 0.67, 0.69: the dungeon in two. A Run illimitée all in the dungeon, untouchable: the deck runs without a break;
# every 40 m two pipes cross (up and down); rolled up, he takes the floor's pipe up to the deck and the deck's
# pipe down to the floor, at a slow and at a fast pace; without the Sphère he stays below; in each part never
# two dangers at once (one of its lines free), both parts may have one at the same place; the hard part has
# more dangers and more coins than the calm one; a swarm puts one wisp in each part.

var fails := 0
var n := 0

func check(ok: bool, what: String) -> void:
	n += 1
	if not ok:
		fails += 1
	print(("ok   " if ok else "ÉCHEC ") + what)

func dungeon_run(seed_: int, speed: float) -> Game.Run:
	var r = Game.new_run({}, "endless", seed_)
	r.biome = 3
	r.prev_biome = 3
	r.next_biome_at = INF
	r.god = true
	Game.launch(r)
	r.base = speed * Game.PPM
	r.speed = r.base
	return r

func _init() -> void:
	Game.FM_FIRST = [100000.0, 100000.0]             # (no swarm in the first runs: the pipes alone)
	for speed in [11.0, 28.0]:
		var r = dungeon_run(31, speed)
		r.up["sphere"] = 1
		r.ball_on = true
		var input = Game.Controls.new()
		var went_up = false
		var on_deck = false
		var went_down = false
		var back_down = false
		var t = 0.0
		while t < 90.0 and r.dist < 1200:
			if speed > 20.0:
				r.speed = r.base
			Game.update(r, 1.0 / 60, input)
			var p = r.p
			if p.ball != null and p.ball.tube > 0:
				went_up = true
			if went_up and p.ball == null and p.ground and p.plat != null and p.plat.kind == "slab":
				on_deck = true
			if on_deck and p.ball != null and p.ball.tube < 0:
				went_down = true
			if went_down and p.ball == null and p.ground and p.plat == null:
				back_down = true
			t += 1.0 / 60
		check(went_up, "%d m/s : dans le conduit qui monte" % speed)
		check(on_deck, "%d m/s : posé sur le pont" % speed)
		check(went_down and back_down, "%d m/s : par le conduit qui descend, de nouveau en bas" % speed)
	# the road itself
	var r2 = dungeon_run(77, 18.0)
	var inp = Game.Controls.new()
	var t2 = 0.0
	var lows: Dictionary = {}
	var highs: Dictionary = {}
	var coins_lo: Dictionary = {}
	var coins_hi: Dictionary = {}
	var ups := 0
	var downs := 0
	var seen_z: Dictionary = {}
	var deck: Array = []
	var deck_y = Game.GROUND - Game.DECK_H
	while t2 < 70.0 and r2.dist < 2000:
		Game.update(r2, 1.0 / 60, inp)
		t2 += 1.0 / 60
		for o in r2.obs:
			var key = int(o.x)
			if o.y + o.h <= deck_y + 4:
				highs[key] = o
			else:
				lows[key] = o
		for c in r2.coins:
			if coins_hi.has(c) or coins_lo.has(c):
				continue
			if c.y < deck_y:
				coins_hi[c] = true
			else:
				coins_lo[c] = true
		for z in r2.zones:
			if z.tube != 0 and not seen_z.has(z):
				seen_z[z] = true
				if z.tube > 0:
					ups += 1
				else:
					downs += 1
		for pl in r2.plats:
			if pl.kind == "slab" and not deck.has([pl.x, pl.x + pl.w]):
				deck.append([pl.x, pl.x + pl.w])
	deck.sort_custom(func(a, b): return a[0] < b[0])
	var holes = 0
	for i in range(1, deck.size()):
		if deck[i][0] > deck[i - 1][1] + 1:
			holes += 1
	check(deck.size() > 3 and holes == 0, "le pont tout du long, sans trou (%d dalles)" % deck.size())
	check(ups > 3 and downs > 3, "des conduits qui montent et qui descendent : %d / %d" % [ups, downs])
	var starts := {}                                 # (0.70) from any line to any other
	for z in seen_z:
		starts["%d>%d" % [z.from_line, z.to_line]] = true
	check(starts.size() >= 6 and seen_z.keys().all(func(z): return z.from_line != z.to_line), "des conduits entre toutes les lignes (%s)" % [starts.keys()])
	var same = func(d: Dictionary) -> int:
		var keys = d.keys()
		keys.sort()
		var bad = 0
		for i in range(1, keys.size()):
			if keys[i] - keys[i - 1] < 160:
				bad += 1
		return bad
	check(same.call(lows) == 0 and same.call(highs) == 0, "dans chaque partie, un danger à la fois (bas %d, haut %d)" % [lows.size(), highs.size()])
	var hard_lo = r2.split_hard == 0
	var hard_n = lows.size() if hard_lo else highs.size()
	var calm_n = highs.size() if hard_lo else lows.size()
	var hard_c = coins_lo.size() if hard_lo else coins_hi.size()
	var calm_c = coins_hi.size() if hard_lo else coins_lo.size()
	check(hard_n > calm_n * 1.5 and hard_c > calm_c * 2, "la partie difficile (%s) : %d dangers, %d pièces ; la tranquille : %d, %d" % ["bas" if hard_lo else "haut", hard_n, hard_c, calm_n, calm_c])
	var r3 = dungeon_run(31, 14.0)                   # without the Sphère: never in a pipe, the floor all along
	var t3 = 0.0
	var up3 = false
	while t3 < 40.0 and r3.dist < 500:
		Game.update(r3, 1.0 / 60, inp)
		t3 += 1.0 / 60
		if r3.p.ball != null or (r3.p.plat != null and r3.p.plat.kind == "slab"):
			up3 = true
	check(not up3 and r3.dist >= 500, "sans la Sphère : en bas tout du long (%d m)" % r3.dist)
	# (0.70) a mouth in the air: jumping through it, in
	var r5 = dungeon_run(9, 12.0)
	r5.up["sphere"] = 1
	r5.ball_on = true
	for i in 400:
		Game.update(r5, 1.0 / 60, inp)
	var px5 = r5.cam + r5.sx
	var fl5 = Game.floor_at(r5, px5)
	var z5 = Game._tube(r5, px5 + 10, 460, fl5, fl5 - Game.DECK_H, 1, 3, "rampe")
	r5.p.ball = null
	r5.p.ground = false
	r5.p.plat = null
	r5.p.vy = -10
	r5.p.y = z5.path[0].y + Game.BALL_MID
	var in5 = false
	for i in 6:
		Game.update(r5, 1.0 / 60, inp)
		if r5.p.ball == z5:
			in5 = true
	check(in5, "une bouche en l'air : en sautant à travers, il y entre")
	# a swarm in the dungeon in two: one wisp in each part
	var r4 = dungeon_run(5, 14.0)
	for i in 120:
		Game.update(r4, 1.0 / 60, inp)
	r4.fm = Game.Swarm.new()
	r4.fm.biome = 3
	Game.wave(r4)
	var act: Array = r4.fm.act
	check((1 if act[0] else 0) + (1 if act[1] else 0) == 1 and (1 if act[3] else 0) + (1 if act[4] else 0) == 1 and not act[2], "une nuée : un feu follet dans chaque partie (%s)" % [act])
	print("BILAN donjon en deux : %d vérifications, %d échecs" % [n, fails])
	quit()
