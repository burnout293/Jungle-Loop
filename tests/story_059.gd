extends SceneTree
# 0.59: Histoire, a way back per level, and the dungeon's pipes.
# Level 1 (the forest): no pipes on its road; knocked out, the pygmies take him and he may get away once
# (no knife needed), the second time not. Level 2 (the heights): no way back, the long fall: off the screen,
# down to the forest's floor, into it, a tomb, the end. Level 3 (the dungeon): slimes hop after him; knocked
# out, one swallows him, and he may get out once. The dungeon's pipes: anyone gets in; out of some thrown up
# high; some have their mouth in the air; a wall of will-o'-the-wisps has a pipe under it, where they cannot
# touch him. The heights: figures in series, then a breath; an arrow ahead of each figure's way through.
#   godot --headless --path . -s tests/story_059.gd -- --bac   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func step(r: Game.Run, inp, n: int, seen: Dictionary) -> void:
	for k in n:
		Game.update(r, 1.0 / 60, inp)
		for e in r.events:
			seen[e] = seen.get(e, 0) + 1
		r.events.clear()

## A run out of the temple, in `biome`, the road ahead cleared.
func ready_run(mode: String, biome: int, seed_: int) -> Game.Run:
	var r = Game.new_run({}, mode, seed_)
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	var k = 0
	while k < 60 * 60 and not (r.exploded and r.out == 2):
		step(r, inp, 1, {})
		k += 1
	step(r, inp, 60, {})
	r.biome = biome
	r.prev_biome = biome
	r.biome_x = -INF
	r.boss_at = INF
	r.next_biome_at = INF
	r.guards_off = 0
	r.obs = r.obs.filter(func(o): return false)
	r.zones = []
	return r

## Knocked out for good now (his hearts gone), then on until something happens.
func knock_out(r: Game.Run) -> void:
	r.god = false
	r.hearts = 1
	r.p.inv = 0
	r.mount = null
	Game.hit(r, null)

func road_zones(mode: String, biome: int, seed_: int) -> Array:
	var r = Game.new_run({}, mode, seed_)
	r.biome = biome
	r.prev_biome = biome
	r.biome_x = -INF
	r.next_biome_at = INF
	r.next_x = 3000.0
	r.calm_until = 0
	r.easy_until = 0
	r.boss_at = INF
	r.talk_zones = []                                # (the guards' talks hold the road: none here)
	var stuck = 0
	while r.next_x < 120000.0 and stuck < 50:
		var nx = r.next_x
		r.cam = r.next_x - 900
		Game.spawn_pattern(r)
		stuck = stuck + 1 if r.next_x == nx else 0
	return r.zones

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))
	var inp = Game.Controls.new()

	# --- level 1: no pipes in the forest of Histoire (still in the Run illimitée's) ---
	check(road_zones("story", 0, 11).is_empty(), "Histoire, la forêt : aucun conduit sur 3 km")
	check(not road_zones("endless", 0, 11).is_empty(), "Run illimitée, la forêt : les conduits restent")

	# --- level 1: the pygmies, one escape without a knife ---
	var r = ready_run("story", 0, 5)
	knock_out(r)
	var seen = {}
	var k = 0
	while k < 60 * 8 and not (r.caught != null and r.caught.phase in ["offer", "gone"]):
		step(r, inp, 1, seen)
		k += 1
	check(r.caught != null and r.caught.phase == "offer" and r.knives + r.free_knives == 0, "niveau 1 : capturé, l'évasion lui est offerte sans couteau")
	check(Game.escape_start(r) and r.revives.has(1), "il s'évade : sa chance du niveau 1 est prise")
	for i in 20:                                     # (each touch with the cursor in the zone: a rope cut)
		if r.caught == null:
			break
		r.caught.esc.cur = r.caught.esc.zone
		Game.escape_tap(r)
	check(r.caught == null and not r.dead, "libéré, il repart")
	step(r, inp, 60 * 3, seen)
	knock_out(r)
	k = 0
	while k < 60 * 12 and not r.dead and not (r.caught != null and r.caught.phase == "offer"):
		step(r, inp, 1, seen)
		k += 1
	check(r.caught == null or r.caught.phase != "offer", "la 2e fois sur le niveau 1 : plus d'évasion")

	# --- level 2: no way back, the long fall to the forest's floor, a tomb, the end ---
	r = ready_run("story", Game.SKY, 6)
	r.sky = true
	knock_out(r)
	seen = {}
	check(r.skyfall != null and r.caught == null, "niveau 2 : assommé, pas de capture, la longue chute")
	var phases = {}
	k = 0
	while k < 60 * 10 and not r.dead:
		step(r, inp, 1, seen)
		phases[str(r.skyfall.ph)] = true
		k += 1
	check(phases.has("drop") and phases.has("fall") and phases.has("sink") and phases.has("tomb"), "il sort de l'écran, tombe de très haut, s'enfonce, la tombe (%s)" % str(phases.keys()))
	check(r.dead and r.biome == 0 and seen.has("tomb") and seen.has("plant"), "au sol de la forêt, une tombe, puis la fin")
	check(r.p.y > Game.floor_at(r, r.cam + r.sx) + Game.HERO_H * 0.5, "tout entier sous la terre")

	# --- level 3: the slimes; swallowed, once out of it ---
	r = ready_run("story", 3, 7)
	step(r, inp, 60 * 2, {})
	check(r.slimes.size() == Game.SLIME_N and r.slimes.all(func(sl): return sl.x < r.cam + r.sx), "niveau 3 : des slimes derrière lui (%d)" % r.slimes.size())
	knock_out(r)
	k = 0
	seen = {}
	while k < 60 * 6 and not (r.caught != null and r.caught.phase in ["offer", "gone"]):
		step(r, inp, 1, seen)
		k += 1
	check(r.caught != null and r.caught.get("by", "") == "slime" and r.caught.phase == "offer" and seen.has("slurp"), "assommé : un slime l'avale, une chance de s'extirper")
	check(Game.escape_start(r) and r.revives.has(3), "il s'extirpe : sa chance du niveau 3 est prise")
	for i in 20:                                     # (each touch with the cursor in the zone: a rope cut)
		if r.caught == null:
			break
		r.caught.esc.cur = r.caught.esc.zone
		Game.escape_tap(r)
	check(r.caught == null and not r.dead, "dehors, il repart (le slime rejeté en arrière)")
	step(r, inp, 60 * 3, {})
	knock_out(r)
	k = 0
	while k < 60 * 10 and not r.dead:
		step(r, inp, 1, {})
		k += 1
	check(r.dead, "avalé une 2e fois : la fin")

	# --- the dungeon's pipes ---
	var zs = road_zones("endless", 3, 21)
	check(zs.all(func(z): return z.open), "le donjon : tous ses conduits s'ouvrent à tous (%d)" % zs.size())
	check(zs.any(func(z): return z.launch) and zs.any(func(z): return z.mouth > 0) and zs.any(func(z): return z.kind == "log"), "trois sortes : propulsé en haut, bouche en l'air, droits")
	r = ready_run("endless", 3, 8)
	var px = r.cam + r.sx
	var z = Game.tight(r, "gallery", px + 40, 600, Game.GROUND + Game.GALLERY - 22)
	z.launch = true
	k = 0
	var went_in = false
	var vy_out = 0.0
	while k < 60 * 4:
		step(r, inp, 1, {})
		if r.p.ball == z:
			went_in = true
		elif went_in and r.p.ball == null:
			vy_out = r.p.vy
			break
		k += 1
	check(went_in and vy_out < -800, "un conduit propulseur : il y entre sans la Sphère, en sort lancé vers le haut (%.0f)" % vy_out)
	r = ready_run("endless", 3, 9)
	px = r.cam + r.sx
	var zm = Game.tight(r, "chute", px + 260, 600, Game.GROUND - 24)
	zm.mouth = 150.0
	inp.hold = true
	Game.jump(r, -Game.JUMP_V if "JUMP_V" in Game else -700.0)
	k = 0
	var in_mouth = false
	var low = false
	while k < 60 * 3:
		step(r, inp, 1, {})
		if r.p.ball == zm:
			in_mouth = true
			if r.p.y >= Game.floor_at(r, r.cam + r.sx) - 2:
				low = true
		k += 1
	inp.hold = false
	check(in_mouth and low, "une bouche en l'air : il y entre en sautant, et ressort au sol")

	# --- a wall of will-o'-the-wisps, a pipe under it ---
	r = ready_run("endless", 3, 10)
	r.dist = 800.0
	var f = Game.Swarm.new()
	f.biome = 3
	f.wall = true
	r.fm = f
	Game.wave(r)
	var walls = r.zones.filter(func(q): return q.wall)
	check(f.act.all(func(a): return a) and walls.size() == 1, "un mur de feux follets : toutes les voies, et un conduit dessous")
	r.god = false
	r.hearts = 3
	var hearts0 = r.hearts
	k = 0
	while k < 60 * 6 and r.fm != null:
		step(r, inp, 1, {})
		k += 1
	check(r.hearts == hearts0, "dans le conduit, les feux follets passent au-dessus sans le toucher (%d cœurs sur %d)" % [r.hearts, hearts0])

	# --- the heights: series and breaths, arrows ahead ---
	var rs = Game.new_run({"flight": 1}, "story", 12)
	rs.biome = Game.SKY
	rs.prev_biome = Game.SKY
	rs.biome_x = 0
	rs.next_biome_at = INF
	rs.next_x = 3000.0 + Game.SKY_EASY * Game.PPM
	rs.calm_until = 0
	rs.easy_until = 0
	rs.boss_at = INF
	rs.talk_zones = []
	var breaths = 0
	var longest = 0
	var run_n = 0
	var guard = 0
	while rs.next_x < 200000.0 and guard < 5000:
		guard += 1
		rs.cam = rs.next_x - 900
		var before = rs.sky_n
		Game.spawn_pattern(rs)
		if rs.sky_n == 0 and before >= Game.SKY_SERIES:
			breaths += 1
			run_n = 0
		elif rs.sky_n > before:
			run_n += 1
			longest = maxi(longest, run_n)
	check(breaths > 5 and longest <= Game.SKY_SERIES, "les pitons en séries de %d au plus, puis une respiration (%d respirations)" % [longest, breaths])
	check(rs.cues.size() > 10, "une flèche annonce le passage de chaque figure (%d)" % rs.cues.size())
	print("BILAN histoire 0.59 : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
