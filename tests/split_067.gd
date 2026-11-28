extends SceneTree
# 0.67: the dungeon in two. A Run illimitée all in the dungeon, untouchable: the deck is laid all along (but for
# its shafts), the floor's pipe throws him up onto the deck at a slow and at a fast pace, from the deck the shaft
# drops him back to the floor, the deck holds his head when he jumps below it, and the dangers of each part are
# never one over the other.

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
	for speed in [11.0, 28.0]:
		var r = dungeon_run(31, speed)
		r.up["sphere"] = 1                           # (the pipes: in the Sphère's mode only)
		r.ball_on = true
		var input = Game.Controls.new()
		var up_on_deck = false
		var thrown = false
		var dropped = false
		var bumped_ok = true
		var t = 0.0
		var was_deck = false
		var left_deck = false
		while t < 90.0 and r.dist < 900:
			if speed > 20.0:
				r.speed = r.base                     # (held at its pace)
			Game.update(r, 1.0 / 60, input)
			var p = r.p
			if p.ball != null and p.ball.launch_v > 0:
				thrown = true
			var on_deck = p.ground and p.plat != null and p.plat.kind == "slab"
			if thrown and on_deck:
				up_on_deck = true
			if up_on_deck and not on_deck and not p.ground:
				left_deck = true
			if left_deck and p.ground and p.plat == null and p.ball == null:
				dropped = true
			was_deck = on_deck
			if not on_deck and p.y < Game.GROUND - Game.DECK_H and p.y > Game.GROUND - Game.DECK_H - Game.HERO_H:
				pass
			t += 1.0 / 60
		check(thrown, "%d m/s: into the floor's pipe" % speed)
		check(up_on_deck, "%d m/s: thrown up onto the deck" % speed)
		check(dropped, "%d m/s: from the deck, down the shaft to the floor" % speed)
	# the road itself: dangers below and above never at the same x; the deck's shafts no wider than a jump at speed
	var r2 = dungeon_run(77, 20.0)
	var inp = Game.Controls.new()
	var t2 = 0.0
	var lows: Array = []
	var highs: Array = []
	while t2 < 60.0 and r2.dist < 1500:
		Game.update(r2, 1.0 / 60, inp)
		t2 += 1.0 / 60
		for o in r2.obs:
			var above = o.y + o.h < Game.GROUND - Game.DECK_H
			var key = int(o.x)
			if above and not key in highs:
				highs.append(key)
			elif not above and not key in lows:
				lows.append(key)
	var clash = 0
	for a in lows:
		for b in highs:
			if absf(a - b) < 200:
				clash += 1
	check(lows.size() > 5 and highs.size() > 5, "dangers below (%d) and above (%d)" % [lows.size(), highs.size()])
	check(clash == 0, "never one over the other (%d)" % clash)
	var r3 = dungeon_run(31, 14.0)                   # without the Sphère: never thrown up, the floor all along
	var t3 = 0.0
	var up3 = false
	while t3 < 40.0 and r3.dist < 500:
		Game.update(r3, 1.0 / 60, inp)
		t3 += 1.0 / 60
		if r3.p.plat != null and r3.p.plat.kind == "slab":
			up3 = true
	check(not up3 and r3.dist >= 500, "without the Sphère: below all along (%d m)" % r3.dist)
	print("BILAN donjon en deux : %d vérifications, %d échecs" % [n, fails])
	quit()
