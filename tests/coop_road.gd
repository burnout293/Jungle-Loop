extends SceneTree
# The coop road: two runs with one seed, as two different devices would play them (another loadout, another
# frame rate, another screen width, the guest's place, one jumping, one idle). What the road lays (dangers,
# platforms, coins) must be the same. Each difference is tried alone against the reference, then all at once.
#   godot --headless --path . --script tests/coop_road.gd   (tests/ has a .gdignore: kept out of the game)

const SECONDS := 150.0
const STORY_SECONDS := 260.0            # Histoire: the forest, Vorace (about 2 km), her gems, two more places

var no_boss := 0                        # Histoire runs where Vorace never showed (the test would prove nothing)

func lay(seed_: int, opts: Dictionary) -> Array:
	seed(opts.get("cosmetic", 999))
	var mode: String = opts.get("mode", "endless")
	var r = Game.coop_run(opts.get("up", {}), seed_, 0, opts.get("guest", false), mode)
	r.god = true
	if mode == "endless":
		r.biome = 1
		r.prev_biome = 1
	r.view_w = opts.get("view_w", 1280)
	Game.launch(r)
	var inp = Game.Controls.new()
	var seen = {}
	var out = []
	var next_press = 0.5
	var t = 0.0
	var k = 0
	var seconds = STORY_SECONDS if mode == "story" else SECONDS
	var boss_seen = false
	while t < seconds:
		var dt: float = opts.get("dt", 1.0 / 60)
		if opts.get("jitter", false):
			dt = [1.0 / 60, 1.0 / 120, 1.0 / 45, 1.0 / 90][k % 4]
		k += 1
		t += dt
		inp.pressed = false
		if opts.get("jumpy", false):
			next_press -= dt
			if next_press <= 0:
				next_press = randf_range(0.3, 1.2)
				inp.pressed = true
			inp.hold = randf() < 0.5
		Game.update(r, dt, inp)
		if "boss" in r.events:
			boss_seen = true
		r.events.clear()
		for o in r.obs:
			if not seen.has(o) and not o.own and o.kind != "acid":   # (Vorace's acid: aimed at each hero apart)
				seen[o] = true
				out.append("%s %d %d" % [o.kind, roundi(o.x), roundi(o.y0 if o.amp > 0 else o.y)])
		for pl in r.plats:
			if not seen.has(pl):
				seen[pl] = true
				out.append("plat %d %d" % [roundi(pl.x), roundi(pl.y0 if pl.bobbing else pl.y)])
		for c in r.coins:
			if not seen.has(c) and not c.blast and c.loot < 0:
				seen[c] = true
				out.append("coin %d %d" % [roundi(c.x), roundi(c.y)])
	if mode == "story" and not boss_seen:
		no_boss += 1
	return out

func compare(name: String, a: Array, b: Array) -> bool:
	var key = func(e: String) -> int: return int(e.split(" ")[1])
	var sa = a.duplicate()
	var sb = b.duplicate()
	var by_x = func(p, q): return key.call(p) < key.call(q) or (key.call(p) == key.call(q) and p < q)
	sa.sort_custom(by_x)
	sb.sort_custom(by_x)
	var reach = mini(key.call(sa[-1]), key.call(sb[-1])) - 3000     # what both have surely laid
	sa = sa.filter(func(e): return key.call(e) < reach)
	sb = sb.filter(func(e): return key.call(e) < reach)
	var same = 0
	var first = -1
	for i in mini(sa.size(), sb.size()):
		if sa[i] == sb[i]:
			same += 1
		elif first < 0:
			first = i
	var ok = first < 0 and sa.size() == sb.size()
	print("%-28s %s  %d / %d identiques jusqu'à x=%d%s" % [name, "OK  " if ok else "ÉCART", same, maxi(sa.size(), sb.size()), reach,
		"" if first < 0 else ("  premier écart : %s / %s" % [sa[first], sb[first]])])
	return ok

func _init() -> void:
	Tune.load_file()
	var rich = {"sprint": 1, "lucky": 3, "scatter": 1, "magnet": 3, "heart": 3, "drunk": 1, "boots": 2, "tnt": 2,
		"flight": 3, "doubleJump": 1, "spring": 1, "smash": 1, "rewind": 1, "nature": 2, "dash": 2, "slow": 1}
	var base = lay(4242, {})
	var all_ok = true
	var cases = {
		"images/s 120": {"dt": 1.0 / 120},
		"images/s irrégulières": {"jitter": true},
		"écran large": {"view_w": 2400},
		"invité (1,75 m derrière)": {"guest": true},
		"saute au hasard": {"jumpy": true, "cosmetic": 12345},
	}
	for id in rich:
		cases["objet " + id] = {"up": {id: rich[id]}}
	cases["TOUT à la fois"] = {"up": rich, "dt": 1.0 / 120, "jitter": true, "view_w": 2400, "guest": true, "jumpy": true, "cosmetic": 777}
	for name in cases:
		all_ok = compare(name, base, lay(4242, cases[name])) and all_ok
	# Histoire for two: the forest, Vorace laid on the road (her pads, then her gems), the places after
	var story = lay(4242, {"mode": "story"})
	var story_cases = {
		"Histoire : images/s irrégulières": {"jitter": true},
		"Histoire : écran large": {"view_w": 2400},
		"Histoire : invité": {"guest": true},
		"Histoire : saute au hasard": {"jumpy": true, "cosmetic": 4321},
		"Histoire : TOUT à la fois": {"up": rich, "dt": 1.0 / 120, "jitter": true, "view_w": 2400, "guest": true, "jumpy": true, "cosmetic": 778},
	}
	for name in story_cases:
		var o: Dictionary = story_cases[name]
		o["mode"] = "story"
		all_ok = compare(name, story, lay(4242, o)) and all_ok
	print("Vorace est venue dans chaque Histoire : ", "oui" if no_boss == 0 else "NON (%d fois absente)" % no_boss)
	print("BILAN : ", "même route partout" if all_ok and no_boss == 0 else "des écarts")
	quit()
