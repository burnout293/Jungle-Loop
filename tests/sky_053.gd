extends SceneTree
# 0.53: the misty heights (« Les pitons brumeux », in the ruins' place): when they come (Histoire after Vorace,
# the Run illimitée only with the Vol worn, never first), the Vol always on there, the take-off at their edge,
# the mist that costs a heart and lifts him back up, and a road of the air only (no floor danger, no hole,
# no platform, pinnacles).
#   godot --headless --path . -s tests/sky_053.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

## The sceneries a run goes through, from the forest, mark after mark.
func order(run: Game.Run, n: int) -> Array:
	var out = [0]
	var b = 0
	for i in n:
		b = Game.next_biome(run, b)
		out.append(b)
	return out

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))
	var story = Game.new_run({}, "story", 5)
	check(story.sky_ok and Game.next_biome(story, 0) == Game.SKY, "Histoire : les pitons après la forêt (après Vorace)")
	var walk = Game.new_run({}, "endless", 5)
	check(not walk.sky_ok and not (Game.SKY in order(walk, 8)), "Sans fin sans le Vol : jamais les pitons")
	var fly = Game.new_run({"flight": 1}, "endless", 5)
	check(fly.sky_ok and Game.SKY in order(fly, 8), "Sans fin avec le Vol : les pitons viennent")
	check(Game.story_kit(1).has("flight"), "la couronne de Vorace donne le Vol")

	# --- in the heights: the Vol on, the take-off, the mist ---
	var r = Game.new_run({}, "endless", 7)
	r.god = false
	r.hearts = 3
	Game.launch(r)
	var inp = Game.Controls.new()
	var t = 0.0
	while t < 5.0:                                   # out of the temple, running
		Game.update(r, 1.0 / 60, inp)
		t += 1.0 / 60
	check(r.lvl("flight") == 0, "hors des pitons, sans le Vol : pas de Vol")
	var at = r.cam + r.sx + 200
	r.prev_biome = r.biome
	r.biome = Game.SKY
	r.biome_x = at
	r.obs.clear()
	r.zones.clear()
	r.plats.clear()
	r.next_x = at + 300
	var took_off = false
	for k in 60:
		Game.update(r, 1.0 / 60, inp)
		if r.sky and not r.p.ground and r.p.cruise > 0:
			took_off = true
	check(r.sky and r.lvl("flight") >= 1, "dans les pitons : le Vol toujours là")
	check(took_off, "à leur lisière, il s'envole tout seul")
	var hearts = r.hearts
	r.p.cruise = 0
	r.p.inv = 0
	r.obs.clear()
	var lifted = false
	for k in 600:                                    # no press: he drops into the mist
		r.obs.clear()
		Game.update(r, 1.0 / 60, inp)
		if "mist" in r.events:
			lifted = r.p.y < Game.floor_at(r, r.cam + r.sx)
			break
		r.events.clear()
	check(r.hearts == hearts - 1, "tombé dans la brume : un cœur en moins (%d → %d)" % [hearts, r.hearts])
	check(lifted and not r.dead, "et il est remonté dans les airs")

	# --- the road of the heights ---
	var road = Game.new_run({"flight": 1}, "endless", 11)
	road.god = true
	Game.launch(road)
	road.prev_biome = road.biome
	road.biome = Game.SKY
	road.biome_x = 1500.0
	road.next_x = 1600.0
	road.next_biome_at = INF
	road.calm_until = 0
	road.easy_until = 0
	var kinds = {}
	var floor_danger = 0
	var pinnacles = 0
	var plats = 0
	var zones = 0
	var counted = {}
	for k in 60 * 40:                                # what is laid past the heights' edge, all along
		Game.update(road, 1.0 / 60, inp)
		road.events.clear()
		for o in road.obs:
			if o.x > 1700.0 and not counted.has(o):
				counted[o] = true
				kinds[o.kind] = true
				if o.kind == "spiky":
					floor_danger += 1
				if o.kind == "pinnacle":
					pinnacles += 1
		for pl in road.plats:
			if pl.x > 1700.0 and not counted.has(pl):
				counted[pl] = true
				plats += 1
		for z in road.zones:
			if z.x > 1700.0 and not counted.has(z):
				counted[z] = true
				zones += 1
	check(floor_danger == 0, "pas de danger au sol dans les pitons")
	check(plats == 0 and zones == 0, "ni plateforme ni trou dans les pitons (%d, %d)" % [plats, zones])
	check(kinds.size() > 0 and not kinds.has("spiky"), "des dangers des airs sur la route (%s, %d pitons)" % [str(kinds.keys()), pinnacles])
	var r2 = Game.new_run({"flight": 1}, "endless", 3)
	r2.biome = Game.SKY
	r2.prev_biome = Game.SKY
	r2.biome_x = 0
	r2.next_x = 900.0
	var any_pin = false
	for k in 400:
		Game.spawn_pattern(r2)
		if r2.obs.any(func(o): return o.kind == "pinnacle"):
			any_pin = true
			break
	check(any_pin, "des pitons sortent de la brume")
	print("BILAN pitons : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
