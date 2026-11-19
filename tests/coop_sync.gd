extends SceneTree
# Two phones in one run, side by side in time.
# 1. The pace: one phone at 60 images a second, the other at 24 with a hitch every 3 s. Alone each frame
#    counts 34 ms at most (a slow frame slows the game down): for two the slow phone fell behind for good,
#    about what was seen on a phone and a PC. With Coop.split, every bit of real time is played.
# 2. The partner drawn: his states sent 20 times a second over a bumpy network (late, early, lost, out of
#    order). Drawn from the newest one he jumps; drawn from Coop.view he moves smoothly, a little in the past.
#   godot --headless --path . --script tests/coop_sync.gd   (tests/ has a .gdignore: kept out of the game)

const SECONDS := 75.0                   # about 1000 m of a Run illimitée

var fails := 0

func check(what: String, ok: bool, info := "") -> void:
	print(("ok    " if ok else "ÉCHEC ") + what + ("" if info == "" else "  (" + info + ")"))
	if not ok:
		fails += 1

func new_run() -> Game.Run:
	var r = Game.coop_run({}, 4242, 0, false)
	r.god = true
	r.view_w = 1280
	Game.launch(r)
	return r

## Where the hero is after SECONDS of real time, with these frames, played the old way or with Coop.split.
func pace(frames: Callable, split: bool) -> float:
	var r = new_run()
	var inp = Game.Controls.new()
	var t = 0.0
	var owed = 0.0
	var k = 0
	while t < SECONDS - 1e-6:
		var delta = minf(frames.call(k), SECONDS - t)
		k += 1
		t += delta
		if split:
			owed += delta
			for h in Coop.split(owed):
				owed -= h
				Game.update(r, h, inp)
				r.events.clear()
		else:
			Game.update(r, minf(0.034, delta), inp)
			r.events.clear()
	return r.cam + r.sx

func _init() -> void:
	Tune.load_file()
	var fast = func(k: int) -> float: return 1.0 / 60
	var slow = func(k: int) -> float: return 0.25 if k % 72 == 71 else 1.0 / 24
	var old_gap = pace(fast, false) - pace(slow, false)
	var new_gap = pace(fast, true) - pace(slow, true)
	print("Écart après %d s, 60 i/s contre 24 i/s et un à-coup toutes les 3 s :" % SECONDS)
	print("   avant : %.0f unités (%.1f m)     maintenant : %.1f unités" % [old_gap, old_gap / Game.PPM, new_gap])
	check("avant, le téléphone lent restait derrière (au-delà d'un écran)", old_gap > 1280, "%.0f" % old_gap)
	check("maintenant, les deux sont au même endroit (à un quart de mètre près)", absf(new_gap) < 10.0, "%.2f" % new_gap)

	# --- 2. drawing the partner ---
	var him = new_run()
	var inp = Game.Controls.new()
	var truth = []                               # his place at each of his frames
	var sent = []                                # what he sent: [arrival time, message]
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	var next_send = 0.0
	var next_jump = 0.7
	while him.t < 30.0:
		inp.pressed = false
		next_jump -= 1.0 / 60
		if next_jump <= 0:
			next_jump = rng.randf_range(0.4, 1.3)
			inp.pressed = true
		Game.update(him, 1.0 / 60, inp)
		him.events.clear()
		truth.append([him.t, him.cam + him.sx, him.p.y])
		if him.t >= next_send:
			next_send += Coop.SEND_EVERY
			if rng.randf() < 0.05:
				continue                         # lost
			var m = {"t": "s", "at": him.t, "x": him.cam + him.sx, "y": him.p.y, "vy": him.p.vy, "v": him.speed, "g": him.p.ground, "f": false, "ph": him.p.phase, "b": false}
			sent.append([him.t + 0.06 + rng.randf_range(-0.03, 0.05), m])   # 60 ms, more or less
	sent.sort_custom(func(a, b): return a[0] < b[0])
	var c = Coop.new()
	var latest = null
	var i = 0
	var T = 2.0
	var prev_view = null
	var prev_raw = null
	var jumps_view = 0
	var jumps_raw = 0
	var worst = 0.0
	var frames = 0
	while T < 29.0:
		while i < sent.size() and sent[i][0] <= T:
			c.push(sent[i][1], T)
			if latest == null or sent[i][1]["at"] > latest["at"]:
				latest = sent[i][1]
			i += 1
		var v = c.view(T)
		var speed = float(latest["v"])
		if prev_view != null:
			if absf((float(v["x"]) - float(prev_view["x"])) - speed / 60.0) > speed / 60.0 * 0.5:
				jumps_view += 1
				if OS.get_environment("COOP_DEBUG") != "":
					print("à-coup T=%.3f dx=%.1f attendu %.1f  at=%.3f newest=%.3f delay=%.3f" % [T, float(v["x"]) - float(prev_view["x"]), speed / 60.0, float(v["at"]), float(c.buf[-1]["at"]), c.delay()])
			if absf((float(latest["x"]) - float(prev_raw["x"])) - speed / 60.0) > speed / 60.0 * 0.5:
				jumps_raw += 1
		# against where he really was at the time he is drawn at
		var at = float(v["at"])
		var j = 0
		while j + 1 < truth.size() and truth[j + 1][0] <= at:
			j += 1
		var err = absf(float(v["x"]) - lerpf(truth[j][1], truth[mini(j + 1, truth.size() - 1)][1], clampf((at - truth[j][0]) * 60.0, 0, 1)))
		if err > worst and OS.get_environment("COOP_DEBUG") != "":
			print("écart %.1f à T=%.3f at=%.3f newest=%.3f oldest=%.3f" % [err, T, at, float(c.buf[-1]["at"]), float(c.buf[0]["at"])])
		worst = maxf(worst, err)
		prev_view = v
		prev_raw = latest
		frames += 1
		T += 1.0 / 60
	print("Sur %d images : à-coups dessiné au plus récent %d, dessiné par Coop.view %d ; retard %.0f ms" % [frames, jumps_raw, jumps_view, c.shown * 1000])
	check("dessiné au plus récent, il saute souvent (ce qui se voyait)", jumps_raw > frames / 4, "%d" % jumps_raw)
	check("dessiné par Coop.view, presque plus d'à-coups", jumps_view < frames / 100, "%d" % jumps_view)
	check("et là où il était vraiment à ce moment (à 6 unités près)", worst < 6.0, "%.1f" % worst)
	check("un retard court (moins de 0,2 s)", c.shown < 0.2, "%.3f s" % c.shown)
	c.free()
	print("BILAN : ", "tout bon" if fails == 0 else "%d échec(s)" % fails)
	quit()
