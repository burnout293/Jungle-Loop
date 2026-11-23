extends SceneTree
# 0.56: the city's drones. Their beam burns a short while (LASER_LIVE), three beeps come before it (the ring
# closes on each drone), and « SAUTE ! » shows JUMP_CUE seconds before a beam on the floor's lane: a plain tap
# then always gets him over it; standing, it hits him.
#   godot --headless --path . -s tests/laser_056.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

## A run in the city, out of the temple; a wave of drones aiming at the floor's lane only. If `tap`, the
## player taps once when « SAUTE ! » shows. Returns [hearts lost, beeps, bursts, cue seen].
func wave(tap: bool, seed_: int, late: float = 0.0) -> Array:
	var r = Game.new_run({}, "endless", seed_)
	r.god = false
	r.hearts = 3
	r.biome = 2
	r.prev_biome = 2
	Game.launch(r)
	var inp = Game.Controls.new()
	for k in 60 * 4:
		r.obs.clear()
		Game.update(r, 1.0 / 60, inp)
		r.events.clear()
	r.next_fm = INF
	r.obs.clear()
	r.terrain = [Vector2(r.cam - 2000, Game.GROUND)]   # (the floor flat, as the road is laid during a swarm)
	r.next_x = INF
	var f = Game.Swarm.new()
	f.biome = 2
	f.waves = 1
	r.fm = f
	Game.wave(r)
	f.act.fill(false)
	f.act[0] = true
	var h0 = r.hearts
	var ticks = 0
	var bursts = 0
	var cued = false
	var tapped = false
	var seen_at = -1.0
	for k in 60 * 4:
		r.obs.clear()
		r.zones.clear()
		r.pits.clear()
		var soon = Game.laser_in(r.fm)
		var cue = r.fm != null and soon < Render.JUMP_CUE and soon > -Game.LASER_LIVE and Game.laser_jump(r)
		cued = cued or cue
		if cue and seen_at < 0:
			seen_at = r.t
		inp.pressed = tap and cue and not tapped and r.p.ground and r.t - seen_at >= late - 0.001
		if inp.pressed:
			tapped = true
		inp.hold = false
		Game.update(r, 1.0 / 60, inp)
		for e in r.events:
			if e == "lasertick":
				ticks += 1
			elif e == "laser":
				bursts += 1
		r.events.clear()
		if r.fm == null:
			break
	return [h0 - r.hearts, ticks, bursts, cued]

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	check(absf(Game.LASER_OFF - Game.LASER_ON - 0.15) < 0.001, "le laser ne brûle que 0,15 s (0,45 avant)")
	var hit_standing = 0
	var hit_tapping = 0
	var hit_late = 0
	for sd in 8:
		var stay = wave(false, 30 + sd)
		var jump = wave(true, 30 + sd)
		var late = wave(true, 30 + sd, 0.15)        # (a player reacting 0.15 s after « SAUTE ! »)
		hit_standing += stay[0]
		hit_tapping += jump[0]
		hit_late += late[0]
		if sd == 0:
			check(stay[1] == 3 and stay[2] == 1, "trois bips avant le tir, puis le tir (%d, %d)" % [stay[1], stay[2]])
			check(jump[3], "« SAUTE ! » s'affiche")
	check(hit_standing == 8, "resté au sol, le laser du sol le touche (%d sur 8)" % hit_standing)
	check(hit_tapping == 0, "un simple saut au « SAUTE ! » passe toujours (%d touché(s) sur 8)" % hit_tapping)
	check(hit_late == 0, "même 0,15 s après le « SAUTE ! » (%d touché(s) sur 8)" % hit_late)
	print("BILAN lasers : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
