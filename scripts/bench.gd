extends Node
## A bench for trying the game without playing it by hand (the web version's ?bac and its bot):
##   Godot --path . -- --bac --test [--seconds=30] [--shots=<dir>] [--start=1900] [--god]
##                     [--up=flight,dash] [--mode=endless] [--mount=rhino]
## A bot presses now and then, the run is printed every second, a picture is saved every 2 seconds
## (not with --headless, which draws nothing). Always with --bac: the real save is never touched.

var main: Node
var tour_i := 0
var saved_loadout := []
var opts := {"tour60": false, "tour59": false, "tour58": false, "tour57": false, "tour56": false, "tour55": false, "tour54": false, "tour53": false, "tour52": false, "tour51": false, "tour50": false, "race": "", "friends": "", "bet": 0, "on": -1, "me": "", "tour48": false, "mock": false, "tour47": false,"showcase": false, "quality": "", "prof": false, "tour": false, "seconds": 30.0, "shots": "", "start": 0.0, "god": false, "up": [], "mode": "story", "mount": "", "screen": "", "ride": "", "biome": -1, "still": false, "hitbox": false, "coop": "", "room": "", "mate": "", "friend": "", "slow": 0, "every": 2.0, "die": -1.0}
var t := 0.0
var next_press := 0.6
var hold_left := 0.0
var next_print := 1.0
var next_shot := 1.0
var shot_n := 0
var over_for := 0.0
var runs := 0

func _ready() -> void:
	var args = Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):                         # in a browser: the options come from the address, ?test&seconds=20&god
		for kv in str(JavaScriptBridge.eval("location.search.slice(1)", true)).split("&", false):
			args.append("--" + kv)
	for a in args:
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"seconds": opts["seconds"] = float(kv[1])
			"shots": opts["shots"] = kv[1]
			"start": opts["start"] = float(kv[1])
			"god": opts["god"] = true
			"up": opts["up"] = Array(kv[1].split(",", false))
			"mode": opts["mode"] = kv[1]
			"mount": opts["mount"] = kv[1]
			"screen": opts["screen"] = kv[1]
			"ride": opts["ride"] = kv[1]
			"biome": opts["biome"] = int(kv[1])
			"still": opts["still"] = true
			"hitbox": opts["hitbox"] = true
			"tour": opts["tour"] = true
			"tour48": opts["tour48"] = true        # 0.48's: friends, the race for four, the signs, the debug lock
			"mock": opts["mock"] = true            # (with --tour48: only the pictures the mock-ups are drawn on)
			"tour60": opts["tour60"] = true        # 0.60's: the eagle's fight, each of its moments
			"tour59": opts["tour59"] = true        # 0.59's: slimes, the dungeon's pipes, the wall of wisps, the heights, the long fall
			"tour58": opts["tour58"] = true        # 0.58's: Amis → Groupe (G1), « Expulser », « Inviter », the Affrontement (V1)
			"tour57": opts["tour57"] = true        # 0.57's: Amis (Liste, Demandes), the home's panels, the Course du jour, the guest's lobby, watching
			"tour56": opts["tour56"] = true        # 0.56's: a mushroom brushed, the city's lasers and their cue, the race's end screen
			"tour55": opts["tour55"] = true        # 0.55's: the group on the home screen, the Affrontement, watching, skins in coins
			"tour54": opts["tour54"] = true        # 0.54's: a hollow under a mound, the cliff (Histoire), the leap, the gliders, the heights
			"tour53": opts["tour53"] = true        # 0.53's: the misty heights (flying only), seen from the forest's edge
			"tour52": opts["tour52"] = true        # 0.52's: Réglages without Son, the temple seen from the side and its camera, the heights
			"tour51": opts["tour51"] = true        # 0.51's: Réglages in four categories, the three parties, Amis in three tabs
			"tour50": opts["tour50"] = true        # 0.50's: the home screen B3 (modes, Défis), the wood buttons, the stone skin
			"race": opts["race"] = kv[1]           # 0.48, the race for four: host | guest (in a browser, with ?net=)
			"friends": opts["friends"] = kv[1]     # race=host: the friend codes to add and invite, separated by commas
			"bet": opts["bet"] = int(kv[1])        # race: what this one bets
			"on": opts["on"] = int(kv[1])          # ... on which place (-1: on himself)
			"me": opts["me"] = kv[1]               # race: an identity made beforehand, id:secret:code
			"prof": opts["prof"] = true
			"quality": opts["quality"] = kv[1]
			"showcase": opts["showcase"] = true
			"coop": opts["coop"] = kv[1]           # host | join (in a browser, with ?net=)
			"room": opts["room"] = kv[1]
			"friend": opts["friend"] = kv[1]      # coop=host: the friend code to add and invite
			"slow": opts["slow"] = int(kv[1])      # milliseconds lost each frame: a slow phone
			"every": opts["every"] = float(kv[1])  # seconds between two pictures (--shots)
			"die": opts["die"] = float(kv[1])      # seconds into the run: his last heart is lost then
			"mate": opts["mate"] = kv[1]          # run | bubble: a pretend partner beside him (the coop's drawing)
	if opts["shots"] != "":
		DirAccess.make_dir_recursive_absolute(opts["shots"])
	print("bench: ", opts)

func _start() -> void:
	var s: Dictionary = main.save
	s["seenIntro"] = true
	s["mode"] = opts["mode"]
	s["upgrades"] = {}
	s["equipped"] = []
	s["powersOff"] = []
	for id in opts["up"]:
		var u := SaveData.upgrade(id)
		if u.is_empty():
			continue
		s["upgrades"][id] = u["costs"].size()
		if not u.get("power", false) and s["equipped"].size() < SaveData.MAX_EQUIPPED:
			s["equipped"].append(id)
	if opts["quality"] != "":
		s["quality"] = opts["quality"]
		main.fit()
	main.go("play")
	var r: Game.Run = main.run
	r.god = opts["god"]
	main.render.hitbox = opts["hitbox"]
	if opts["start"] > 0:                            # as if the first metres had already been run
		var D: float = opts["start"] * Game.PPM
		var g := Game.SPEED_GAIN
		r.t = (-r.base + sqrt(r.base * r.base + 2 * g * D)) / g
		r.pace_t = r.t                         # (0.49: the speed's own clock)
		r.cam = D
		r.dist = opts["start"]
		r.next_x = D + 1500
		r.terrain = [Vector2(-1e9, Game.GROUND)]
		r.next_mount += opts["start"]
		r.next_fm += opts["start"]
	if opts["mount"] != "":
		var it := Game.Item.new()
		it.x = r.cam + Game.PX + 700
		it.kind = opts["mount"]
		it.y = Game.GROUND - Game.ZIG_LOW
		r.items.append(it)
	if opts["biome"] >= 0:                            # the scenery to start in
		r.biome = opts["biome"]
		r.prev_biome = opts["biome"]
		r.next_biome_at = INF
	if opts["ride"] != "":                           # already on its back (the gorilla up in the vines)
		var mt := Game.Mount.new()
		mt.kind = opts["ride"]
		mt.t = 2
		r.mount = mt
		if mt.kind == "gorilla":
			r.vine = 1
			r.p.hang = true
			r.p.y = Game.HANG_Y
	if opts["showcase"]:                             # the new things side by side, for a picture
		var px = r.cam + r.sx
		var o = Game.add_dart(r, px + 1500, 170)
		o.state = "go"
		o.biome = r.biome
		Game.add_bonus(r, px + 330)
		Game.add_bonus(r, px + 420)
		r.bonuses[0].kind = "brake"
		r.bonuses[1].kind = "urn"
		Game.add_hover(r, px + 760, Game.HEAD)
		Game.add_hover(r, px + 900, Game.LOW)
		r.wait = 0
	runs += 1

func _process(delta: float) -> void:
	if main.state == "loading":
		return
	t += delta
	if opts["tour"]:
		await _tour()
		return
	if opts["tour48"]:
		await _tour48()
		return
	if opts["tour50"]:
		await _tour50()
		return
	if opts["tour51"]:
		await _tour51()
		return
	if opts["tour52"]:
		await _tour52()
		return
	if opts["tour60"]:
		await _tour60()
		return
	if opts["tour59"]:
		await _tour59()
		return
	if opts["tour58"]:
		await _tour58()
		return
	if opts["tour57"]:
		await _tour57()
		return
	if opts["tour56"]:
		await _tour56()
		return
	if opts["tour55"]:
		await _tour55()
		return
	if opts["tour54"]:
		await _tour54()
		return
	if opts["tour53"]:
		await _tour53()
		return
	if opts["race"] != "":                           # four browsers, one race: see _race_bench
		_race_bench(delta)
		return
	if opts["coop"] != "":                           # two browsers, one run: see _coop_bench
		if opts["slow"] > 0:
			OS.delay_msec(opts["slow"])              # (frames longer than 34 ms: what made a phone fall behind)
		_coop_bench(delta)
		return
	if opts["screen"] != "":                         # only a screen to look at: no run
		if opts["screen"] == "debug" and main.debug_panel == null and t < 0.5:
			main.open_debug()
		elif opts["screen"] != "debug" and main.state != opts["screen"] and t < 0.5:
			main.go(opts["screen"])
		await _shoot(delta)
		if t >= opts["seconds"]:
			get_tree().quit()
		return
	if main.state == "menu" or main.state == "intro":
		_start()
		return
	if main.state == "tally":
		over_for += delta
		if over_for > 1.5:
			over_for = 0
			main._tally_next()
		return
	if main.state == "over":
		over_for += delta
		if over_for > 1.0:
			over_for = 0
			_start()
		return
	var r: Game.Run = main.run
	if r == null:
		return
	if opts["mate"] != "":
		r.coop = true
		var was = r.mate != null
		r.mate = {"x": r.cam + r.sx - 110, "y": Game.floor_at(r, r.cam + r.sx - 110), "vy": 0.0, "g": true, "f": false, "ph": r.p.phase + 1.5, "b": opts["mate"] == "bubble", "d": r.dist}
		if not was:
			r.mate_bubble = Vector2(r.cam + r.sx, Game.GROUND - 150)
	if opts["die"] >= 0 and r.t > opts["die"] and not r.dead and r.leap == null:   # the end, on purpose
		opts["die"] = -1.0
		r.god = false
		r.hearts = 1
		r.p.inv = 0
		Game.hit(r, null)
	next_press -= delta
	if next_press <= 0 and not opts["still"]:                              # a press now and then, held for a moment
		next_press = randf_range(0.5, 1.4)
		hold_left = randf_range(0.05, 0.4)
		main.press()
	if hold_left > 0:
		hold_left -= delta
		if hold_left <= 0:
			main.input.hold = false
	next_print -= delta
	if next_print <= 0:
		next_print = 1.0
		if opts["prof"]:                              # where the drawing time goes, and the draw calls
			var parts = []
			for k in Render.layer_us:
				parts.append("%s %.2f" % [k, Render.layer_us[k] / 1000.0 / maxf(1, Engine.get_frames_per_second())])
			Render.layer_us = {}
			print("   ms/image: ", ", ".join(parts), "  appels de dessin ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  objets ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("%5.1fs run %d  %6.0f m  %4.1f m/s  biome %d  obs %d  coins %d  gold %d  boss %s  mount %s  fps %d  %s" % [
			t, runs, r.dist, r.speed / Game.PPM, r.biome, r.obs.size(), r.coins.size(), r.gold,
			r.boss.phase if r.boss != null else "-", r.mount.kind if r.mount != null else "-", Engine.get_frames_per_second(), main.perf["text"]])
	await _shoot(delta)
	if t >= opts["seconds"]:
		print("end: %d runs, %.0f m" % [runs, r.dist])
		get_tree().quit()

func _shoot(delta: float) -> void:
	if opts["shots"] == "":
		return
	next_shot -= delta
	if next_shot <= 0:
		next_shot = opts["every"]
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.save_png(opts["shots"].path_join("shot-%03d.png" % shot_n))
		shot_n += 1

## --tour48: 0.48 in pictures. With --mock, only the pictures the mock-ups are drawn on (the home screen
## and a run without any of the interface over them).
var steps48: Array = []

func _tour48() -> void:
	if steps48.is_empty():
		steps48 = [
			[0.5, "setup", ""], [1.0, "shot", "48-m01-menu"],
			[1.1, "bare", "on"], [1.4, "shot", "48-m02-menu-bare"], [1.5, "bare", "off"],
			[1.6, "go", "friends"], [2.5, "shot", "48-m03-friends"],
			[2.6, "go", "menu"], [2.7, "play", ""], [7.5, "bare", "on"], [7.8, "shot", "48-m04-run-bare"],
			[7.9, "bare", "off"],
		]
		if opts["mock"]:
			steps48.append([8.0, "quit", ""])
		else:
			steps48.append_array(_steps48())
	_fake_ghosts()
	while tour_i < steps48.size() and t >= steps48[tour_i][0]:
		var st = steps48[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var s: Dictionary = main.save
				s["seenIntro"] = true
				s["mode"] = "endless"
				s["best"] = 2000
				main.endless_biome = 0                     # the forest, the game's own look
				main.still.biome = 0
				main.still.prev_biome = 0
				main.refresh_menu()
			"bare": main.ui.visible = arg != "on"
			"go": main.go(arg)
			"slopes":                                 # three forest platforms ahead: rising, flat, falling
				var r: Game.Run = main.run
				var x0 = r.cam + 1000
				Game.add_hill(r, x0 - 100, 1300, 320)
				r.hills[-1].isles = true
				r.hills[-1].biome = 0
				Game.add_isle(r, x0, Game.GROUND - 130, 1).slope = -45
				Game.add_isle(r, x0 + 340, Game.GROUND - 250, 2).slope = 0
				Game.add_isle(r, x0 + 760, Game.GROUND - 170, 1).slope = 45
			"play":
				main.save["mode"] = "endless"
				main.go("play")
				main.run.god = true
			"quit": get_tree().quit()
			_: await _step48(st[1], arg)

## --tour50: 0.50 in pictures: the home screen B3 closed, its modes unrolled (a race of three waiting, so
## Affrontement shows), the objectives come from the right, the Skins tab's buttons, and the stone skin.
var steps50: Array = []

func _tour50() -> void:
	if steps50.is_empty():
		steps50 = [
			[0.5, "setup", ""], [1.0, "shot", "50-01-accueil"],
			[1.1, "modes", ""], [1.25, "shot", "50-02-modes-ouverture"], [1.8, "shot", "50-03-modes"],
			[1.9, "fakerace", "lobby"], [2.0, "modes0", ""], [2.2, "modes", ""], [2.9, "shot", "50-04-modes-affrontement"],
			[3.0, "fakerace", "off"], [3.1, "quests", ""], [3.25, "shot", "50-05-defis-arrivee"], [3.9, "shot", "50-06-defis"],
			[4.0, "quests0", ""], [4.4, "skins", ""], [5.3, "shot", "50-07-skins-boutons"],
			[5.4, "stone", ""], [5.5, "go", "menu"], [6.5, "shot", "50-08-accueil-pierre"],
			[6.6, "wood", ""], [6.7, "go", "settings"], [7.6, "shot", "50-09-reglages"], [7.7, "go", "menu"],
			[8.6, "shot", "50-10-accueil-temple"], [8.7, "play", ""], [9.3, "shot", "50-11-depart"], [10.6, "shot", "50-12-explosion"],
			[11.6, "shot", "50-13-sortie"], [12.4, "shot", "50-14-pilier"], [13.2, "shot", "50-15-pilier-bis"],
			[13.3, "slopes", ""], [13.5, "shot", "50-16-pentes"], [14.3, "shot", "50-17-pentes-bis"], [15.1, "shot", "50-18-pentes-ter"],
			[15.5, "quit", ""],
		]
	while tour_i < steps50.size() and t >= steps50[tour_i][0]:
		var st = steps50[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var s: Dictionary = main.save
				s["seenIntro"] = true
				s["mode"] = "story"
				s["bestEndless"] = 2340
				main.endless_biome = 0
				main.still.biome = 0
				main.still.prev_biome = 0
				main.refresh_menu()
			"modes": main._home_modes(true)
			"modes0": main._home_modes(false)
			"quests": main._home_quests(true)
			"quests0": main._home_quests(false)
			"skins":
				main.picked_skin = "buttons-stone"
				main.tab = "skin"
				main.go_from("shop", "right")
			"stone":
				main.save["skins"]["owned"].append("buttons-stone")
				main.save["skins"]["worn"]["buttons"] = "buttons-stone"
				main.rebuild_due = true
			"wood":
				main.save["skins"]["worn"].erase("buttons")
				main.rebuild_due = true
			"go": main.go(arg)
			"slopes":                                 # three forest platforms ahead: rising, flat, falling
				var r: Game.Run = main.run
				var x0 = r.cam + 1000
				Game.add_hill(r, x0 - 100, 1300, 320)
				r.hills[-1].isles = true
				r.hills[-1].biome = 0
				Game.add_isle(r, x0, Game.GROUND - 130, 1).slope = -45
				Game.add_isle(r, x0 + 340, Game.GROUND - 250, 2).slope = 0
				Game.add_isle(r, x0 + 760, Game.GROUND - 170, 1).slope = 45
			"play":
				main.save["mode"] = "endless"
				main.go("play")
				main.run.god = true
			"quit": get_tree().quit()
			"fakerace":
				var rc: Race = main.race
				if arg == "lobby":
					rc.role = "host"
					rc.state = "lobby"
					rc.room = "KQ7M"
					rc.me = 0
					rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "on": 0, "bet": 100}, 1: {"name": "Léo", "code": "PEPI-K7QM", "on": 1, "bet": 250}, 2: {"name": "Inès", "code": "PEPI-INES", "on": 1, "bet": 50}}
				else:
					rc.role = ""
					rc.state = "idle"
					rc.seats = {}

## --tour51: 0.51 in pictures: Réglages's four categories, the three parties (exporting one, starting a
## new one, back to the first), then Amis's three tabs (a few friends made up).
var steps51: Array = []

func _tour51() -> void:
	if steps51.is_empty():
		steps51 = [
			[0.5, "setup", ""], [0.6, "go", "settings"], [1.5, "shot", "51-01-reglages-jeu"],
			[1.6, "settab", "show"], [1.9, "shot", "51-02-reglages-affichage"],
			[2.4, "settab", "save"], [2.7, "shot", "51-04-reglages-sauvegarde"],
			[2.8, "export", "1"], [3.1, "shot", "51-05-exporter"], [3.2, "unmodal", ""],
			[3.3, "newslot", "2"], [3.6, "shot", "51-06-nouvelle-partie"], [3.7, "unmodal", ""],
			[3.8, "switch", "2"], [4.1, "shot", "51-07-partie-2"], [4.2, "switch", "1"], [4.3, "wipe", "2"], [4.6, "shot", "51-08-partie-1"],
			[4.7, "fakefriends", ""], [4.8, "go", "friends"], [5.7, "shot", "51-09-amis-liste"],
			[5.8, "frtab", "group"], [6.1, "shot", "51-10-amis-groupe"],
			[6.2, "frtab", "scores"], [6.5, "shot", "51-11-amis-scores"],
			[6.6, "go", "menu"], [7.4, "shot", "51-12-accueil"],
			[7.5, "dungeon", ""], [8.6, "hills", ""], [9.6, "shot", "51-13-donjon"], [10.6, "shot", "51-14-donjon-bis"],
			[10.8, "quit", ""],
		]
	while tour_i < steps51.size() and t >= steps51[tour_i][0]:
		var st = steps51[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var s: Dictionary = main.save
				s["seenIntro"] = true
				s["coins"] = 3450
				s["best"] = 1240
				main.refresh_menu()
			"go": main.go(arg)
			"settab":
				main.set_tab = arg
				main.refresh_settings()
			"export": main._slot_export(int(arg))
			"newslot": main._slot_play(int(arg))
			"switch": main._switch_slot(int(arg))
			"wipe": SaveData.reset(int(arg))
			"unmodal":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
			"fakefriends": _fake_friends51()
			"dungeon":                                # a run in the dungeon, to see its mounds (0.51)
				main.race.state = "idle"
				main.race.seats = {}
				main.endless_biome = 3
				main.save["mode"] = "endless"
				main.go("play")
				main.run.god = true
			"hills":
				var r: Game.Run = main.run
				Game.add_hill(r, r.cam + 700, 1500, 300)
				Game.add_hill(r, r.cam + 2300, 1200, 300)
			"frtab":
				main.friends_tab = arg
				main.refresh_friends()
			"quit": get_tree().quit()

## A few friends, a group of three and a board, as the server would send them (no server touched).
func _fake_friends51() -> void:
	main.save["online"] = {"id": "x", "secret": "x", "code": "PEPI-6ZAW", "name": "Pépito"}
	main.save["bestEndless"] = 2340
	main.board = [
		{"code": "PEPI-6ZAW", "name": "Pépito", "me": true, "best": 1500, "week": 900, "endless": 2340, "endless_week": 1204},
		{"code": "PEPI-K7QM", "name": "Léo", "best": 1200, "week": 1100, "endless": 2100, "endless_week": 1980},
		{"code": "PEPI-INES", "name": "Inès", "best": 800, "week": 0, "endless": 1875, "endless_week": 700},
		{"code": "PEPI-PAPA", "name": "Papa", "best": 400, "week": 400, "endless": 1210, "endless_week": 0},
		{"code": "PEPI-SAMS", "name": "Sam", "best": 0, "week": 0, "endless": 0, "endless_week": 0},
	]
	main.board_cache = main.board
	var rc: Race = main.race
	rc.role = "host"
	rc.state = "lobby"
	rc.room = "KQ7M"
	rc.me = 0
	rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "on": 0, "bet": 0}, 1: {"name": "Léo", "code": "PEPI-K7QM", "on": 1, "bet": 0}}
	rc.invited = {"PEPI-INES": "Inès"}

## --tour52: 0.52 in pictures: the home screen on the whole temple, Réglages (Jeu with the volumes, Affichage
## with the frame rate), then a run: the camera sliding from the temple to the doorway, the blast, the way out.
var steps52: Array = []

func _tour52() -> void:
	if steps52.is_empty():
		steps52 = [
			[0.5, "setup", ""], [1.4, "shot", "52-01-accueil-temple"],
			[1.5, "go", "settings"], [2.4, "shot", "52-02-reglages-jeu"], [2.5, "settab", "show"], [2.8, "shot", "52-03-reglages-affichage"],
			[2.9, "go", "menu"], [3.8, "play", ""], [3.85, "shot", "52-04-depart"], [4.25, "shot", "52-05-glisse"], [4.65, "shot", "52-06-glisse-bis"],
			[5.05, "shot", "52-07-porte"], [5.35, "shot", "52-08-explosion"], [5.75, "shot", "52-09-sortie"], [6.3, "shot", "52-10-dehors"],
			[6.5, "quit", ""],
		]
	while tour_i < steps52.size() and t >= steps52[tour_i][0]:
		var st = steps52[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				main.save["seenIntro"] = true
				main.endless_biome = 0
				main.still.biome = 0
				main.still.prev_biome = 0
				main.refresh_menu()
			"go": main.go(arg)
			"settab":
				main.set_tab = arg
				main.refresh_settings()
			"play":
				main.save["mode"] = "endless"
				main.go("play")
				main.run.god = true
			"quit": get_tree().quit()

## --tour60: the eagle in pictures (Histoire, the heights, untouchable): one picture a little after each of its
## moments begins (enter, a line flashing, a rush, wings raised, wings slammed, the storm, the lightning, the
## column, the amber head on it, held up), then the dungeon.
var shots60 := {}
var key60 := ""
var key60_t := 0.0

func _tour60() -> void:
	if t > 0.5 and not shots60.has("setup"):
		shots60["setup"] = true
		_run59(Game.SKY)
		var r: Game.Run = main.run
		r.up["flight"] = 1
		r.boss_done = true
		Game.EAGLE_AT = 0.0
		r.sky_dist0 = r.dist
		return
	var r2: Game.Run = main.run
	if r2 == null or not shots60.has("setup"):
		return
	var key = ""
	if r2.eagle != null:
		key = r2.eagle.phase + "-" + r2.eagle.step
	elif r2.eagle_done:
		key = "after"
	if key != key60:
		key60 = key
		key60_t = t
	var wait = {"rush-warn": 0.5, "rush-go": 0.35, "wings-raise": 0.6, "wings-slam": 0.1, "storm-": 3.0, "strike-": 0.1, "crash-": 0.7, "relic-": 0.6, "land-": 1.0, "after": 2.0, "enter-": 1.2}
	if wait.has(key) and not shots60.has(key) and t - key60_t >= wait[key]:
		shots60[key] = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(opts["shots"].path_join("60-%02d-%s.png" % [shots60.size(), key]))
	if key == "after" and shots60.has("after") or t > 95:
		get_tree().quit()

## --tour59: 0.59 in pictures: Histoire's dungeon (the slimes after him, a pipe with its mouth in the air, one
## that throws him up, a wall of will-o'-the-wisps over a pipe), swallowed by a slime (his one chance offered),
## the heights (whole columns far off, a pygmy on his glider firing a rocket, the arrow of the way through),
## then the long fall of level 2 and its tomb.
var steps59: Array = []

func _run59(biome: int) -> void:
	main.save["seenIntro"] = true
	main.save["equipped"] = []
	main.save["mode"] = "endless"
	main.daily_on = false
	main.go("play")
	var r: Game.Run = main.run
	r.wait = 0.0
	r.exploded = true
	r.out = 2
	r.intro = false
	r.mode = "story"
	r.biome = biome
	r.prev_biome = biome
	r.biome_x = -INF
	r.next_biome_at = INF
	r.boss_at = INF
	r.guards_off = 0
	r.god = true
	r.obs = r.obs.filter(func(o): return false)
	r.zones = []
	r.sky = biome == Game.SKY

func _tour59() -> void:
	if steps59.is_empty():
		steps59 = [
			[0.5, "dungeon", ""], [3.0, "shot", "59-01-slimes"],
			[3.1, "pipes", ""], [3.6, "shot", "59-02-conduits"],
			[3.7, "wall", ""], [4.6, "shot", "59-03-mur-feux-follets"],
			[6.5, "ko", ""], [8.6, "shot", "59-04-avale"],
			[8.7, "sky", ""], [10.0, "rocket", ""], [10.6, "shot", "59-05-pitons"],
			[10.7, "ko", ""], [12.2, "shot", "59-06-longue-chute"], [14.6, "shot", "59-07-tombe"], [14.8, "quit", ""],
		]
	while tour_i < steps59.size() and t >= steps59[tour_i][0]:
		var st = steps59[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"dungeon": _run59(3)
			"pipes":
				var r: Game.Run = main.run
				var px = r.cam + r.sx
				var zm = Game.tight(r, "chute", px + 520, 700, Game.GROUND - 24)
				zm.mouth = 150.0
				var zl = Game.tight(r, "gallery", px + 1300, 500, Game.GROUND + Game.GALLERY - 22)
				zl.launch = true
			"wall":
				var r: Game.Run = main.run
				r.zones = []
				r.dist = 800.0
				var f = Game.Swarm.new()
				f.biome = 3
				f.wall = true
				r.fm = f
				Game.wave(r)
			"ko":
				var r: Game.Run = main.run
				r.fm = null
				r.god = false
				r.hearts = 1
				r.p.inv = 0
				Game.hit(r, null)
			"sky": _run59(Game.SKY)
			"rocket":
				var r: Game.Run = main.run
				var o = Game.add_dart(r, r.cam + r.view_w + 40, 180.0)
				o.state = "warn"
				o.t = 0.2
				r.cues.append({"x": r.cam + r.view_w + 200, "y": Game.GROUND - 260})
			"quit": get_tree().quit()

## --tour58: 0.58 in pictures: Amis → Groupe in its layout G1 (four cards: the host, a good link, a slow one,
## one linking again with the time his place still waits), « Expulser » asked, « Inviter » on a free place (the
## friends to pick), then the Affrontement in its layout V1, as the host and as a guest.
var steps58: Array = []

func _tour58() -> void:
	if steps58.is_empty():
		steps58 = [
			[0.5, "setup", ""], [0.7, "group", ""], [1.6, "shot", "58-01-groupe-g1"],
			[1.7, "kick", ""], [2.3, "shot", "58-02-expulser"], [2.4, "unmodal", ""],
			[2.5, "free", ""], [2.6, "pick", ""], [3.2, "shot", "58-03-inviter"], [3.3, "unpick", ""],
			[3.4, "race", ""], [4.2, "shot", "58-04-affrontement-v1"],
			[4.3, "guest", ""], [5.0, "shot", "58-05-affrontement-invite"],
			[5.1, "alone", ""], [5.8, "shot", "58-06-groupe-sans-groupe"],
			[5.9, "wear", ""], [6.0, "skins", ""], [6.8, "shot", "58-07-skins-familles"],
			[6.9, "fxrun", ""], [9.0, "shot", "58-08-traine-echarpe"], [9.1, "tap", ""], [9.25, "shot", "58-09-eclat-saut"],
			[10.0, "die", ""], [13.0, "shot", "58-10-chute-tombe"],
			[13.1, "daily", ""], [13.8, "shot", "58-11-course-du-jour"], [13.9, "quit", ""],
		]
	while tour_i < steps58.size() and t >= steps58[tour_i][0]:
		var st = steps58[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var sv: Dictionary = main.save
				sv["seenIntro"] = true
				sv["coins"] = 23450
				sv["xp"] = 40000.0
				sv["upgrades"] = {"magnet": 2, "dash": 1, "horn": 2}
				sv["equipped"] = ["magnet", "dash", "horn"]
				_fake_friends51()
				var rc: Race = main.race
				rc.set_process(false)                 # (its links are stand-ins: nothing to poll)
				Coop._supported = 1                   # (as in a browser: the buttons to invite, create, join)
				Net.url = "http://127.0.0.1:9"        # (an address nobody answers: never the real server)
				rc.invited = {}
				rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "skin": "", "on": 0, "bet": 500, "ready": true},
					1: {"name": "Léo", "code": "PEPI-K7QM", "skin": "pepito-ember", "on": 1, "bet": 1000, "ready": false},
					2: {"name": "Inès", "code": "PEPI-INES", "skin": "pepito-amethyst", "on": 0, "bet": 100, "ready": true},
					3: {"name": "Papa", "code": "PEPI-PAPA", "skin": "pepito-frost", "on": 3, "bet": 0, "ready": false, "away": true, "away_t": 138.0}}
				for spec in [[1, 45.0], [2, 240.0]]:
					var l = Race.Link.new()
					l.seat = spec[0]
					l.open = true
					l.rtt = spec[1]
					rc.links["c%d" % spec[0]] = l
				rc.history = [{"n": 2, "rows": [{"k": 0, "name": "Pépito", "bet": 500, "on": 0, "dist": 1840, "gold": 212, "got": 1000, "win": true},
						{"k": 1, "name": "Léo", "bet": 1000, "on": 1, "dist": 1210, "gold": 147, "got": 0, "win": false},
						{"k": 2, "name": "Inès", "bet": 100, "on": 0, "dist": 760, "gold": 64, "got": 200, "win": false}]},
					{"n": 1, "rows": [{"k": 0, "name": "Pépito", "bet": 0, "on": 0, "dist": 950, "gold": 95, "got": 0, "win": false},
						{"k": 1, "name": "Léo", "bet": 500, "on": 1, "dist": 1430, "gold": 120, "got": 1000, "win": true}]}]
				main.race_seen = true
				main.refresh_menu()
			"group":
				main.friends_tab = "group"
				main.go("friends")
				main.refresh_friends()
			"kick": main._group_kick(1)
			"unmodal":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
			"free":
				main.race.seats.erase(3)
				main.refresh_friends()
			"pick": main._race_pick()
			"unpick":
				for ch in main.get_children():
					if ch is CanvasLayer and ch.layer == 40:
						ch.queue_free()
			"race":
				main.go("race")
				main.refresh_race()
			"guest":
				var rc: Race = main.race
				rc.role = "guest"
				rc.me = 1
				rc.links = {}
				var l = Race.Link.new()
				l.open = true
				l.rtt = 60.0
				rc.links["host"] = l
				rc.seats[0]["ms"] = 0
				rc.seats[2]["ms"] = 240
				main.refresh_race()
			"wear":                                     # the urns' cosmetics, worn
				var sv: Dictionary = main.save
				for id in ["scarf-striped", "trail-rainbow", "jump-stars", "fall-tomb", "shoes-gold", "bag-blue", "emote-gg"]:
					if not id in sv["skins"]["owned"]:
						sv["skins"]["owned"].append(id)
				sv["skins"]["worn"] = {"scarf": "scarf-striped", "trail": "trail-rainbow", "jump": "jump-stars", "fall": "fall-tomb", "shoes": "shoes-gold", "bag": "bag-blue"}
				Skins.apply(sv["skins"]["worn"])
			"skins":
				main.picked_skin = "scarf-striped"
				main.tab = "skin"
				main.go("shop")
			"fxrun":
				main.save["equipped"] = []                # (on foot: no rhino from the Corne)
				main.save["mode"] = "endless"
				main.daily_on = false
				main.go("play")
				main.run.god = true
			"tap":
				main.press()
				main.input.hold = false
			"die":
				var r: Game.Run = main.run
				r.god = false
				r.hearts = 1
				r.p.inv = 0
				Game.hit(r, null)
			"daily": main._daily_panel()
			"alone":
				var rc: Race = main.race
				rc.role = ""
				rc.state = "idle"
				rc.room = ""
				rc.seats = {}
				rc.links = {}
				main.go("friends")
				main.refresh_friends()
			"quit": get_tree().quit()

## --tour57: 0.57 in pictures: Amis's list (« Voir ») and its requests (a card to accept or refuse), the window
## of a request, the home screen's two panels (equipment, group), the Course du jour (its window, a run and its
## next tier), the Affrontement's lobby seen by a guest (« Lancer » greyed), then a race: Léo falls (his fall seen),
## I fall, I watch with the results shown.
var steps57: Array = []
var lp57 := 0
var lx57 := 0.0

func _tour57() -> void:
	if steps57.is_empty():
		steps57 = [
			[0.5, "setup", ""], [0.7, "go", "friends"], [1.5, "shot", "57-01-amis-liste"],
			[1.6, "req", ""], [2.3, "shot", "57-02-amis-demandes"],
			[2.4, "popup", ""], [3.0, "shot", "57-03-fenetre-demande"], [3.1, "unpop", ""],
			[3.2, "go", "menu"], [4.0, "shot", "57-04-accueil-panneaux"],
			[4.1, "daily", ""], [4.8, "shot", "57-05-course-du-jour"], [4.9, "dailygo", ""], [9.5, "shot", "57-06-course-du-jour-en-course"],
			[9.6, "guest", ""], [10.5, "shot", "57-07-salon-invite"],
			[10.6, "race", ""], [14.0, "leofalls", ""], [14.35, "shot", "57-08-leo-tombe"], [14.9, "leoplant", ""], [15.5, "shot", "57-09-leo-plante"],
			[16.0, "die", ""], [20.6, "results", ""], [21.2, "shot", "57-10-je-regarde-resultats"], [21.4, "quit", ""],
		]
	var rr: Game.Run = main.run
	if lp57 >= 0 and rr != null and rr.race and main.race.trails.has(1) == false and t > 10.6:
		main.race.trails[1] = Race.Trail.new()
	if rr != null and rr.race and main.race.trails.has(1):   # Léo ahead (running, then falling)
		if lp57 == 0:
			lx57 = rr.cam + rr.sx + 260.0             # (just ahead of me, on the screen, until he falls)
		var lx = lx57
		var y = Game.floor_at(rr, lx)
		main.race.trails[1].push({"at": rr.t, "x": lx, "y": y, "vy": 0.0, "g": true, "f": false, "ph": rr.t * 9.0, "d": floori(lx / Game.PPM), "c": 40,
			"lp": lp57, "ro": rr.t * 9.0 if lp57 == 1 else 0.0}, rr.t)
		main.race.seats[1]["dist"] = floori(lx / Game.PPM)
		main.race.seats[2]["dist"] = floori((lx + 300) / Game.PPM)
	while tour_i < steps57.size() and t >= steps57[tour_i][0]:
		var st = steps57[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var sv: Dictionary = main.save
				sv["seenIntro"] = true
				sv["coins"] = 23450
				sv["xp"] = 40000.0
				sv["upgrades"] = {"magnet": 2, "dash": 1, "horn": 2}
				sv["equipped"] = ["magnet", "dash", "horn"]
				_fake_friends51()
				main.requests = {"incoming": [{"code": "PEPI-MILA", "name": "Mila", "at": 0}], "outgoing": [{"code": "PEPI-NOEX", "name": "Noé", "at": 0}]}
				var rc: Race = main.race
				rc.invited = {}
				rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "skin": "", "on": 0, "bet": 500, "ready": true},
					1: {"name": "Léo", "code": "PEPI-K7QM", "skin": "pepito-ember", "on": 1, "bet": 1000, "ready": true},
					2: {"name": "Inès", "code": "PEPI-INES", "skin": "pepito-amethyst", "on": 1, "bet": 100, "ready": false}}
				main.refresh_menu()
			"go": main.go(arg)
			"req":
				main.friends_sub = "req"
				main.req_sel = "PEPI-MILA"
				main.refresh_friends()
			"popup": main._show_request("Mila", "PEPI-MILA")
			"unpop":
				if main.req_box != null:
					main.req_box.queue_free()
					main.req_box = null
			"daily": main._daily_panel()
			"dailygo":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
				main.daily_on = true
				main.go("play")
				main.run.god = true
			"guest":                                  # the lobby, seen by Léo (a guest): « Lancer » greyed
				main.daily_on = false
				var rc: Race = main.race
				rc.role = "guest"
				rc.me = 1
				main.race_seen = true
				main.go("race")
			"race":
				var rc: Race = main.race
				rc.role = "host"
				rc.me = 0
				rc.running = true
				main.race_start = {"seed": 77, "biome": 0, "tier": 0, "up": {"magnet": 2}, "at": 0.0}
				main.go("play")
				main.run.god = true
			"leofalls":
				lp57 = 1
				lx57 = main.run.cam + main.run.sx + 520.0
			"leoplant": lp57 = 2
			"die":
				var r: Game.Run = main.run
				r.god = false
				r.hearts = 1
				r.p.inv = 0
				Game.hit(r, null)
			"results": main._toggle_watch_res()
			"quit": get_tree().quit()

## --tour56: 0.56 in pictures: a run in the forest, a mushroom brushed (lit, 70 % less); in the city, a wave of
## drones on the floor's lane and one higher (the ring closing, « SAUTE ! », the short beam); then the end
## screen of an Affrontement made up (everyone's distance, coins, bet).
var steps56: Array = []
var laser56 := false

func _tour56() -> void:
	if steps56.is_empty():
		steps56 = [
			[0.5, "setup", ""], [0.8, "play", ""], [3.0, "shroom", ""], [3.25, "shot", "56-01-champignon"], [3.9, "shot", "56-02-champignon-apres"],
			[4.0, "city", ""], [6.0, "swarm", ""], [7.3, "shot", "56-03-lasers-anneau"], [7.85, "shot", "56-04-saute"],
			[8.05, "shot", "56-05-tir"], [8.6, "shot", "56-06-apres"],
			[8.5, "recap", ""], [9.4, "shot", "56-07-fin-affrontement"], [9.6, "quit", ""],
		]
	if laser56 and main.run != null and main.run.fm != null:   # (the road flat and empty under the wave)
		main.run.obs.clear()
	while tour_i < steps56.size() and t >= steps56[tour_i][0]:
		var st = steps56[tour_i]
		tour_i += 1
		var arg: String = st[2]
		var r: Game.Run = main.run
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				main.save["seenIntro"] = true
				main.save["mode"] = "endless"
				main.endless_biome = 0
			"play":
				main.go("play")
				main.run.god = true
			"shroom":                                 # the next mushroom brought into view, just brushed
				var i0 = floori((r.cam + r.sx) / Game.PROP_CELL) + 1
				for i in range(i0, i0 + 400):
					var pr = Game.prop_at(i)
					if pr != null and pr["kind"] == Game.PROP_SHROOM and Game.biome_at(r, pr["x"]) == 0 and Game.flat_at(r, pr["x"], Game.PROP_CELL * 0.6):
						r.cam = pr["x"] - 260 * Game.PIXEL
						r.obs.clear()
						r.touched[i] = r.t
						break
			"city":                                   # the city, its road flat and empty
				r.prev_biome = 2
				r.biome = 2
				r.biome_x = r.cam - 2000
				r.obs.clear()
				r.coins.clear()
				r.plats.clear()
				r.zones.clear()
				r.pits.clear()
				r.hills.clear()
				r.decor.clear()
				r.terrain = [Vector2(r.cam - 2000, Game.GROUND)]
				r.next_x = INF
				r.next_fm = INF
				laser56 = true
			"swarm":                                  # drones on the floor's lane and the fourth one
				var f = Game.Swarm.new()
				f.biome = 2
				f.waves = 1
				r.fm = f
				Game.wave(r)
				f.act.fill(false)
				f.act[0] = true
				f.act[3] = true
			"recap":
				laser56 = false
				var rc: Race = main.race
				rc.role = "host"
				rc.state = "lobby"
				rc.room = "KQ7M"
				rc.me = 0
				rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "skin": "", "on": 0, "bet": 500, "ready": false},
					1: {"name": "Léo", "code": "PEPI-K7QM", "skin": "pepito-ember", "on": 1, "bet": 1000, "ready": false},
					2: {"name": "Inès", "code": "PEPI-INES", "skin": "pepito-amethyst", "on": 0, "bet": 100, "ready": false}}
				rc.races = 3
				rc.history = [{"n": 3, "rows": [
					{"k": 0, "name": "Pépito", "bet": 500, "on": 0, "dist": 1840, "gold": 212, "got": 1000, "win": true},
					{"k": 1, "name": "Léo", "bet": 1000, "on": 1, "dist": 1210, "gold": 147, "got": 0, "win": false},
					{"k": 2, "name": "Inès", "bet": 100, "on": 0, "dist": 760, "gold": 64, "got": 200, "win": false}]}]
				main.race_seen = false
				main.go("race")
			"quit": get_tree().quit()

## --tour55: 0.55 in pictures: a group of three made up (looks, bets, ready or not, two races in its history),
## the home screen with it, the Affrontement's screen, Amis → Groupe, the skins in coins, the Trésor, the day's
## free change of an objective; then an Affrontement run (the items top left, the bets top right, no pause), a
## fall, and the race watched (Léo made up, running ahead).
var steps55: Array = []
var rival55 := false

func _tour55() -> void:
	if steps55.is_empty():
		steps55 = [
			[0.5, "setup", ""], [0.7, "go", "menu"], [1.6, "shot", "55-01-accueil-groupe"],
			[1.7, "modes", ""], [2.4, "shot", "55-02-jouer"], [2.5, "go", "race"], [3.3, "shot", "55-03-affrontement"],
			[3.4, "ready", ""], [3.8, "shot", "55-04-tous-prets"],
			[3.9, "go", "friends"], [4.0, "frtab", "group"], [4.8, "shot", "55-05-amis-groupe"],
			[4.9, "go", "shop"], [5.0, "tab", "skin"], [5.9, "shot", "55-06-skins"],
			[6.0, "go", "menu"], [6.1, "treasure", ""], [6.9, "shot", "55-07-tresor"], [7.0, "untreasure", ""],
			[7.1, "quests", ""], [7.9, "shot", "55-08-defis"],
			[8.0, "race", ""], [13.0, "shot", "55-09-course"], [14.5, "shot", "55-10-course-bis"],
			[14.6, "die", ""], [17.5, "shot", "55-11-spectateur"], [19.5, "shot", "55-12-spectateur-bis"],
			[19.6, "end", ""], [20.0, "go", "race"], [20.4, "rotate", "portrait"], [21.2, "shot", "55-13-debout"],
			[21.3, "rotate", "landscape"], [22.4, "shot", "55-14-apres-rotation"], [22.6, "quit", ""],
		]
	if rival55 and main.run != null and main.run.race:   # Léo, ahead, running on (his states as the host passes them on)
		var r: Game.Run = main.run
		var rc: Race = main.race
		if not rc.trails.has(1):
			rc.trails[1] = Race.Trail.new()
		var lx = 900.0 + r.t * 560.0
		rc.trails[1].push({"at": r.t, "x": lx, "y": Game.floor_at(r, lx), "vy": 0.0, "g": true, "f": false, "ph": r.t * 9.0, "d": floori(lx / Game.PPM)}, r.t)
		rc.seats[1]["dist"] = floori(lx / Game.PPM)
	while tour_i < steps55.size() and t >= steps55[tour_i][0]:
		var st = steps55[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"setup":
				var sv: Dictionary = main.save
				sv["seenIntro"] = true
				sv["coins"] = 23450
				sv["xp"] = 40000.0
				sv["urns"] = 2
				sv["upgrades"] = {"magnet": 2, "dash": 1, "horn": 2, "flight": 1}
				sv["equipped"] = ["magnet", "dash", "horn"]
				sv["skins"]["owned"] = ["pepito-frost"]
				sv["skins"]["worn"] = {"pepito": "pepito-frost"}
				Skins.apply(sv["skins"]["worn"])
				_fake_friends51()
				var rc: Race = main.race
				rc.invited = {}
				rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "skin": "pepito-frost", "on": 0, "bet": 500, "ready": true},
					1: {"name": "Léo", "code": "PEPI-K7QM", "skin": "pepito-ember", "on": 1, "bet": 1000, "ready": false},
					2: {"name": "Inès", "code": "PEPI-INES", "skin": "pepito-amethyst", "on": 1, "bet": 100, "ready": true}}
				rc.kit = SaveData.loadout(sv)
				rc.races = 2
				rc.history = [
					{"n": 2, "rows": [{"k": 0, "name": "Pépito", "bet": 500, "on": 0, "dist": 1840, "got": 1000, "win": true},
						{"k": 1, "name": "Léo", "bet": 1000, "on": 1, "dist": 1210, "got": 0, "win": false},
						{"k": 2, "name": "Inès", "bet": 100, "on": 0, "dist": 760, "got": 200, "win": false}]},
					{"n": 1, "rows": [{"k": 0, "name": "Pépito", "bet": 0, "on": 0, "dist": 950, "got": 0, "win": false},
						{"k": 1, "name": "Léo", "bet": 250, "on": 1, "dist": 1430, "got": 500, "win": true},
						{"k": 2, "name": "Inès", "bet": 0, "on": 2, "dist": 400, "got": 0, "win": false}]},
				]
				main.refresh_menu()
			"go": main.go(arg)
			"modes": main._home_modes(true)
			"ready":
				for k in main.race.seats:
					main.race.seats[k]["ready"] = true
				main.refresh_race()
			"frtab":
				main.friends_tab = arg
				main.refresh_friends()
			"tab":
				main.tab = arg
				main.refresh_shop()
			"treasure": main._treasure()
			"untreasure": main._close_treasure()
			"quests": main._home_quests(true)
			"race":                                   # an Affrontement run, the group's three running
				main._home_quests(false)
				main.race.running = true
				main.race_start = {"seed": 77, "biome": 0, "tier": 0, "up": main.race.kit, "at": 0.0}
				main.go("play")
				main.run.god = true
				rival55 = true
			"end":                                    # (the race made up ends: the screen of the group again)
				rival55 = false
				main.race.running = false
				main.race.seats[0]["done"] = false
			"rotate":                                 # the phone turned upright, then back (0.55: all shown again)
				var wsz = get_window().size
				get_window().size = Vector2i(mini(wsz.x, wsz.y), maxi(wsz.x, wsz.y)) if arg == "portrait" else Vector2i(1280, 720)
			"die":
				var r: Game.Run = main.run
				r.god = false
				r.hearts = 1
				r.p.inv = 0
				if r.mount != null:
					Game.dismount(r)
				Game.hit(r, null)
			"quit": get_tree().quit()

## --tour54: 0.54 in pictures: Histoire (the temple's talk left out), a hollow laid under a mound, then Vorace
## taken as beaten: the guards back after him, their talk, the cliff, the leap, the Vol, the gliders, the heights'
## figures; last, the shop with the Couteau suisse.
var steps54: Array = []

func _tour54() -> void:
	if steps54.is_empty():
		steps54 = [[0.5, "setup", ""], [0.8, "play", ""], [3.0, "hollow", ""], [3.9, "shot", "54-01-creux-monticule"], [4.6, "cliff", ""]]
		var k = 2
		var at = 5.4
		while at < 44.0:
			steps54.append([at, "shot", "54-%02d-falaise" % k])
			k += 1
			at += 1.4
		steps54.append_array([[44.5, "shop", ""], [45.4, "shot", "54-99-boutique"], [45.6, "quit", ""]])
	while tour_i < steps54.size() and t >= steps54[tour_i][0]:
		var st = steps54[tour_i]
		tour_i += 1
		var r: Game.Run = main.run
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(str(st[2]) + ".png"))
			"setup":
				main.save["seenIntro"] = true
				main.save["mode"] = "story"
				main.save["relic"] = 0
				main.save["storyTry"] = 0
				Game.TALKS = Game.TALKS.filter(func(tk): return tk["at"] != -1.0)   # (no temple talk: straight out)
			"play":
				main.go("play")
				main.run.god = true
			"hollow":                                 # a hollow just ahead, a mound behind it
				var at = r.cam + r.view_w * 0.5
				r.terrain = r.terrain.filter(func(v): return v.x < at)
				r.terrain.append(Vector2(at, Game.GROUND))
				Game.relief(r, at + 40, [[0, 0], [70, -Game.HOLLOW], [770, -Game.HOLLOW], [840, 0]])
				r.obs = r.obs.filter(func(o): return o.x < at - 200)
				r.coins = r.coins.filter(func(c2): return c2.x < at - 200)
				r.plats = r.plats.filter(func(pl): return pl.x + pl.w < at - 100)
				r.zones = r.zones.filter(func(z): return z.x + z.w < at - 100)
				r.hills = r.hills.filter(func(hl): return hl.x + hl.w < at - 100)
				r.decor = r.decor.filter(func(dc): return dc.x < at - 200)
				Game.add_hill(r, at - 60, 1000, 320)
				r.next_x = at + 1100
			"cliff":                                  # Vorace taken as beaten: the guards come back, the heights next
				r.won = 0
				r.guards_off = r.t
				r.boss_at = INF
				r.biome = 0
				r.prev_biome = 0
				r.next_biome_at = r.dist
			"shop":
				main.save["xp"] = 40000.0
				main.go("shop")
			"quit": get_tree().quit()

## --tour53: 0.53 in pictures: a Run illimitée with the Vol, the heights brought just ahead: the forest's edge,
## the take-off, pinnacles and flyers over the mist, a fall into the mist (and the lift back up).
var steps53: Array = []

func _tour53() -> void:
	if steps53.is_empty():
		steps53 = [
			[0.5, "setup", ""], [0.8, "play", ""], [3.6, "sky", ""], [4.6, "shot", "53-01-lisiere"], [5.6, "shot", "53-02-envol"],
			[6.8, "shot", "53-03-pitons"], [8.0, "shot", "53-04-pitons-bis"], [9.2, "shot", "53-05-pitons-ter"], [10.4, "shot", "53-06-volants"],
			[11.6, "shot", "53-07-brume"], [12.8, "shot", "53-08-loin"], [13.0, "quit", ""],
		]
	while tour_i < steps53.size() and t >= steps53[tour_i][0]:
		var st = steps53[tour_i]
		tour_i += 1
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(str(st[2]) + ".png"))
			"setup":
				main.save["seenIntro"] = true
				main.endless_biome = 0
			"play":
				main.save["mode"] = "endless"
				main.go("play")
				main.run.god = true
				main.run.up["flight"] = 1
				main.run.sky_ok = true
			"sky":                                    # the heights from just ahead, their road laid from there
				var r: Game.Run = main.run
				var at = r.cam + r.view_w * 0.45
				r.prev_biome = r.biome
				r.biome = Game.SKY
				r.biome_x = at
				r.obs = r.obs.filter(func(o): return o.x < at - 200)
				r.coins = r.coins.filter(func(c2): return c2.x < at - 200)
				r.plats = r.plats.filter(func(pl): return pl.x + pl.w < at - 100)
				r.zones = r.zones.filter(func(z): return z.x + z.w < at - 100)
				r.hills = r.hills.filter(func(hl): return hl.x + hl.w < at - 100)
				r.decor = r.decor.filter(func(dc): return dc.x < at - 200)
				r.next_x = at + 200
				r.calm_until = 0
				r.easy_until = 0
			"quit": get_tree().quit()

## The steps of the full 0.48 tour (after the mock-up pictures).
func _steps48() -> Array:
	return [
		[8.2, "fakefriends", ""], [8.3, "go", "friends"], [9.2, "shot", "48-01-amis-liste"],
		[9.3, "sel", "PEPI-K7QM"], [9.6, "shot", "48-02-amis-fiche"],
		[9.7, "qr", ""], [10.2, "shot", "48-03-qr"], [10.3, "unlayer", ""],
		[10.4, "remove", ""], [10.8, "shot", "48-04-retirer"], [10.9, "unmodal", ""],
		[11.0, "fakerace", "lobby"], [11.1, "go", "race"], [12.0, "shot", "48-05-course-salon"],
		[12.1, "fakerace", "live"], [12.4, "shot", "48-06-course-attente"],
		[12.5, "fakerace", "result"], [12.8, "shot", "48-07-course-resultat"],
		[12.9, "fakerace", "off"], [13.0, "go", "menu"],
		[13.2, "signs", ""], [13.3, "play", ""], [17.0, "shot", "48-08-panneau-ami"], [19.4, "shot", "48-09-panneau-record"],
		[19.5, "ghosts", "on"], [20.5, "shot", "48-10-fantomes"], [21.5, "shot", "48-11-fantomes-bis"], [21.6, "ghosts", "off"],
		[21.7, "pause", ""], [21.8, "go", "menu"], [22.6, "lock", ""], [23.0, "shot", "48-12-mot-de-passe"], [23.1, "unmodal", ""],
		[23.3, "quit", ""],
	]

var ghost_fake := false

func _step48(what: String, arg: String) -> void:
	match what:
		"fakefriends":                            # a list as the server would give it
			main.save["online"] = {"id": "x", "secret": "x", "code": "PEPI-6ZAW", "name": "Pépito"}
			main.board = [
				{"code": "PEPI-6ZAW", "name": "Pépito", "me": true, "best": 1500, "week": 900, "endless": 2100, "endless_week": 1200},
				{"code": "PEPI-K7QM", "name": "Léo", "best": 1200, "week": 1100, "endless": 2340, "endless_week": 1980},
				{"code": "PEPI-INES", "name": "Inès", "best": 800, "week": 0, "endless": 1875, "endless_week": 700},
				{"code": "PEPI-PAPA", "name": "Papa", "best": 400, "week": 400, "endless": 1210, "endless_week": 0},
				{"code": "PEPI-SAMS", "name": "Sam", "best": 0, "week": 0, "endless": 0, "endless_week": 0},
			]
			main.board_cache = main.board
		"sel":
			main.fr_sel = arg
			main.refresh_friends()
		"qr": main._show_qr()
		"unlayer":
			for ch in main.get_children():
				if ch is CanvasLayer and ch.layer == 40:
					ch.queue_free()
		"remove": main._remove_friend("PEPI-K7QM", "Léo")
		"unmodal":
			if main.modal != null:
				main.modal.queue_free()
				main.modal = null
		"fakerace":
			var rc: Race = main.race
			match arg:
				"lobby":
					rc.role = "host"
					rc.state = "lobby"
					rc.room = "KQ7M"
					rc.me = 0
					rc.seats = {0: {"name": "Pépito", "code": "PEPI-6ZAW", "on": 0, "bet": 100}, 1: {"name": "Léo", "code": "PEPI-K7QM", "on": 1, "bet": 250}, 2: {"name": "Inès", "code": "PEPI-INES", "on": 1, "bet": 50}}
					rc.invited = {"PEPI-PAPA": "Papa"}
					main.race_seen = true
				"live":
					rc.running = true
					rc.invited = {}
					rc.seats[0]["done"] = true
					rc.seats[0]["dist"] = 1204
					rc.seats[1]["dist"] = 960            # (still running, behind: the race goes on)
					rc.seats[2]["done"] = true
					rc.seats[2]["dist"] = 640
				"result":
					rc.running = false
					var view = rc.seats.duplicate(true)
					view[1]["dist"] = 2412
					var st = Race.settle(view)
					rc.result = {"pot": st["pot"], "win": st["win"], "pay": st["pay"], "dists": {0: 1204, 1: 2412, 2: 640}, "paid": 100, "got": int(st["pay"][0])}
					main.race_seen = false
				"off":
					rc.running = false
					rc.result = {}
					rc.seats = {}
					rc.role = ""
					rc.room = ""
					rc.state = "idle"
			main.refresh_race()
		"signs":
			main.save["bestEndless"] = 120
			main.board_cache = [{"code": "PEPI-K7QM", "name": "Léo", "endless": 40, "best": 0}, {"code": "PEPI-INES", "name": "Inès", "endless": 52, "best": 0}]
		"ghosts": ghost_fake = arg == "on"
		"pause": main.pause()
		"lock": main._debug_password()

## The fake ghosts of the tour: three others beside him, one far ahead (his name at the edge).
func _fake_ghosts() -> void:
	var r = main.run
	if r == null:
		return
	if not ghost_fake:
		r.rivals = []
		r.board = []
		return
	var x = r.cam + r.sx
	r.board = [
		{"name": "PAPA", "dist": floori(r.dist) + 75, "colour": Race.COLOURS[3], "out": false, "me": false},
		{"name": "LÉO", "dist": floori(r.dist) + 4, "colour": Race.COLOURS[1], "out": false, "me": false},
		{"name": "TOI", "dist": floori(r.dist), "colour": Race.COLOURS[0], "out": false, "me": true},
		{"name": "INÈS", "dist": floori(r.dist) - 3, "colour": Race.COLOURS[2], "out": false, "me": false},
	]
	r.rivals = [
		{"k": 1, "name": "Léo", "x": x + 150, "y": Game.GROUND - absf(sin(t * 2.2)) * 90, "g": false, "ph": r.p.phase, "out": false},
		{"k": 2, "name": "Inès", "x": x - 110, "y": Game.GROUND, "g": true, "ph": r.p.phase + 0.5, "out": false},
		{"k": 3, "name": "Papa", "x": x + 3000, "y": Game.GROUND, "g": true, "ph": 0.0, "out": false},
	]

# ---------- the race for four, in four browsers (race_test48.mjs) ----------

var race_step := 0
var race_t := 0.0
var race_said := {}
var race_codes: Array = []

func _race_bench(delta: float) -> void:
	var rc: Race = main.race
	var host = opts["race"] == "host"
	if race_step == 0 and t > 0.5 and main.state == "menu":
		race_step = 1                                 # (this runs every frame: not again while it waits)
		var s: Dictionary = main.save
		s["seenIntro"] = true
		s["coins"] = 1000
		s["loops"] = 5                                # (no first-run hints)
		s["quality"] = "eco"                          # (four browsers on one computer: 30 images a second)
		main.fit()
		if host:
			s["upgrades"] = {"doubleJump": 1, "heart": 1}
			s["equipped"] = ["doubleJump", "heart"]
			s["powersOff"] = []
		if opts["me"] != "":                          # (made beforehand: no request now)
			var part = opts["me"].uri_decode().split(":")
			s["online"] = {"id": part[0], "secret": part[1], "code": part[2], "name": "Pépito"}
		var me = await main.net.identity(s)
		print("RACE CODE ", me.get("code", "?"))
		if host:
			race_codes = Array(opts["friends"].split(",", false))
			for code in race_codes:
				main.w["fr-add"].text = code
				await main._add_friend()
			await main._load_friends()
			print("RACE FRIENDS ", main.board.size() - 1)
			race_step = 2
		else:
			race_step = 10                            # then: the invitation (main polls every few seconds)
	if race_step == 2:
		race_step = 21
		for code in race_codes:
			var f = main._friend(code)
			await main._race_invite(code, str(f.get("name", "?")))
		print("RACE INVITED ", race_codes.size(), " room ", rc.room)
		race_step = 3
		race_t = t
	if race_step == 10 and main.invite_box != null:
		print("RACE INVITED-ME")
		race_step = 11
		race_t = t
	if race_step == 11 and t - race_t > 1.0:
		_press(_find_button(main.invite_box, "Rejoindre"))
		race_step = 3
		race_t = t
	if rc.state == "failed" and not race_said.has("fail"):
		race_said["fail"] = true
		print("RACE FAILED ", rc.info)
	var everyone = rc.count() == 1 + race_codes.size() or (t - race_t > 90.0 and rc.count() >= 2)   # (one may not make it)
	if race_step == 3 and rc.state == "lobby" and rc.seats.has(rc.me) and (not host or (everyone and rc.links.values().all(func(l): return l.open))):
		race_step = 4
		race_t = t
		rc.bet(rc.me if opts["on"] < 0 else opts["on"], opts["bet"])
		print("RACE LOBBY %s seat=%d count=%d" % [opts["race"], rc.me, rc.count()])
	if race_step == 4 and host and t - race_t > 3.0:
		race_step = 5
		print("RACE POT before start: ", rc.pot(), " seats=", rc._public_seats())
		_press(main.w["rc-go"])
	if main.state == "play" and main.run != null and main.run.race:
		var r: Game.Run = main.run
		if not race_said.has("run"):
			race_said["run"] = true
			print("RACE RUN %s coins=%d paid=%d" % [opts["race"], int(main.save["coins"]), rc.paid])
		r.god = r.t < opts["die"] if opts["die"] > 0 else true
		if r.t > 4.0 and not race_said.has("ghosts"):
			race_said["ghosts"] = true
			var seen = r.rivals.map(func(v): return "%s %+d m" % [v["name"], roundi((float(v["x"]) - (r.cam + r.sx)) / Game.PPM)])
			print("RACE GHOSTS %s %s" % [opts["race"], seen])
		next_press -= delta
		if next_press <= 0:
			next_press = randf_range(0.5, 1.2)
			main.press()
		if opts["die"] > 0 and r.t > opts["die"] and not r.dead and not race_said.has("hit"):
			race_said["hit"] = true                   # (once: hit again while thrown, he would be thrown again)
			r.god = false
			r.hearts = 1
			r.rewind_left = 0
			r.p.inv = 0
			Game.hit(r, null)
	if main.state == "race" and race_said.has("run"):
		if not race_said.has("over"):
			race_said["over"] = true
			print("RACE OVER %s dist=%d" % [opts["race"], int(rc.my_seat().get("dist", 0))])
	if not rc.result.is_empty() and not race_said.has("result"):
		race_said["result"] = true
		print("RACE RESULT %s win=%s pot=%d paid=%d got=%d coins=%d dists=%s" % [opts["race"], rc.result["win"], rc.result["pot"], rc.result["paid"], rc.result["got"], int(main.save["coins"]), rc.result["dists"]])

## --tour: every screen in turn, with pictures taken while they slide (the menus' check).
func _tour() -> void:
	var steps = [
		[0.9, "shot", "01-menu"],
		[1.0, "go", "shop"], [1.15, "shot", "02-shop-sliding"], [2.0, "shot", "03-shop"],
		[2.1, "pick", "magnet"], [3.6, "shot", "04-shop-magnet"],
		[3.7, "buy", "magnet"], [4.0, "shot", "05-buy-confetti"],
		[4.2, "tab", "mount"], [5.6, "shot", "06-shop-mounts"],
		[5.62, "xp", "300"], [5.64, "tab", "up"], [5.68, "shot", "06b-shop-locked"], [5.69, "xp", "back"], [5.695, "tab", "power"], [5.698, "shot", "06c-shop-powers"],
		[5.7, "go", "settings"], [6.6, "shot", "07-settings"],
		[6.7, "toggle", "tg-font"], [7.6, "shot", "08-settings-rounded-font"],
		[7.7, "toggle", "tg-font"], [8.6, "shot", "09-settings-pixel-again"],
		[8.7, "confirm", ""], [9.2, "shot", "10-confirm"], [9.3, "close", ""],
		[9.4, "go", "menu"], [10.2, "equip", "magnet"], [10.4, "slot", "magnet"], [10.8, "shot", "11-menu-slot"],
		[10.82, "loadout", "magnet boots tnt"], [10.84, "slot", "boots"], [10.95, "shot", "11b-menu-three"], [10.96, "loadout", "-"], [10.97, "slot", "boots"],
		[11.0, "play", ""], [11.02, "skipintro", ""], [11.05, "give", "tnt boots slow dash monster"],
		[12.0, "touch", "0 down game"], [12.05, "check", "hold"], [12.3, "touch", "1 down btn-pause"], [12.35, "check", "state"],
		[12.4, "touch", "0 up game"], [12.45, "check", "hold"], [12.5, "resume", ""], [13.0, "life", ""], [13.5, "shot", "12-play"],
		[13.6, "pause", ""], [14.4, "shot", "13-pause"],
		[14.5, "go", "settings"], [15.3, "shot", "14-settings-in-run"],
		[15.4, "go", "menu"], [16.2, "shot", "15-back-to-pause"],
		[16.3, "resume", ""], [16.35, "qdone", ""], [16.4, "die", ""], [17.4, "shot", "16a-head-first"],
		[20.2, "shot", "16b-tally-counting"], [21.8, "tallytap", ""], [22.6, "shot", "16c-tally-levels"], [22.65, "close", ""], [23.6, "shot", "16d-tally-done"],
		[23.7, "next", ""], [24.6, "shot", "16e-over-quests"], [26.4, "shot", "16f-over-quests-done"],
		[26.5, "rebuild", ""], [26.8, "shot", "16g-over-rebuilt"],
		[26.9, "photo", ""], [27.5, "shot", "17-photo-full"], [27.55, "close", ""],
		[27.6, "go", "shop"], [27.65, "tab", "mount"], [27.7, "mpick", "rhinoTamed"], [28.9, "shot", "18-shop-tamed"],
		[29, "moff", "rhino"], [29.05, "mpick", "rhino"], [30.1, "shot", "19-shop-rhino-off"], [30.2, "moff", "rhino"],
		[30.3, "tab", "up"], [30.35, "pick", "boots"], [32.1, "shot", "20-shop-boots"],
		[32.2, "pick", "tnt"], [33.5, "shot", "21-shop-tnt"], [33.6, "pick", "dash"], [34.6, "shot", "22-shop-dash"],
		[34.7, "pick", "drunk"], [36.8, "shot", "23-shop-relic"],
		[36.9, "go", "menu"], [37.8, "tip", "endless"], [37.9, "shot", "24-menu-tip"], [37.95, "tip", ""],
		[38.1, "play", ""], [38.12, "skipintro", ""], [39.5, "scene", "1"], [39.9, "shot", "25-ruins"], [40.1, "scene", "3"], [40.5, "shot", "26-dungeon"],
		[40.6, "go", "shop"], [40.65, "tab", "up"], [40.7, "own", "tnt"], [40.75, "pick", "tnt"], [41.9, "shot", "27-shop-tnt-owned"],
		[42, "own", "dash"], [42.05, "pick", "dash"], [43.1, "shot", "28-shop-dash-owned"],
		[43.2, "tab", "power"], [43.25, "own", "flight"], [43.3, "pick", "flight"], [44.4, "shot", "29-shop-flight-owned"],
		[44.5, "tab", "mount"], [44.55, "mpick", "dragonfly"], [45.7, "shot", "30-shop-dragonfly"], [45.75, "mtick", ""], [46.1, "mtick", ""], [46.15, "mpick", "rhino"], [47.2, "shot", "31-shop-rhino"],
		[47.25, "tab", "up"], [47.3, "own", "monster"], [47.35, "pick", "monster"], [48.9, "shot", "32-shop-monster"],
		[49.0, "story", ""], [50.0, "shot", "33-story-chef"], [50.2, "tap", ""], [50.35, "tap", ""], [50.9, "shot", "34-story-pepito"],
		[51.0, "skiptalk", ""], [52.5, "shot", "35-exit-still"], [53.0, "shot", "36-guards-out"],
		[53.6, "shot", "37-camera-catch"], [55.0, "shot", "38-guards-heels"], [55.2, "darts", ""],
		[55.6, "shot", "39-warn-slow"], [56.4, "shot", "40-warn-later"], [56.5, "catch", ""],
		[57.6, "shot", "41-caught-pounce"], [58.6, "shot", "42-caught-cloud"], [59.2, "shot", "43-caught-cloud2"],
		[60.2, "shot", "44-caught-spit"], [61.0, "shot", "45-caught-spit2"],
		[61.5, "quit", ""],
	]
	while tour_i < steps.size() and t >= steps[tour_i][0]:
		var st = steps[tour_i]
		tour_i += 1
		var arg: String = st[2]
		match st[1]:
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(opts["shots"].path_join(arg + ".png"))
			"go": main.go(arg)
			"pick":
				main.picked = arg
				main.refresh_shop()
			"buy":
				main.save["coins"] = maxi(main.save["coins"], 5000)
				main._buy(SaveData.upgrade(arg))
			"tab":
				main.tab = arg
				main.refresh_shop()
			"mpick":                                    # the Montures tab: an animal or a mount upgrade
				main.picked_mount = arg
				main.refresh_shop()
			"mtick":                                    # the box of « Sur le chemin », pressed as a finger would
				var boxes = main.w["shop-list"].find_children("*", "Button", true, false).filter(func(b): return not b.is_queued_for_deletion() and b.custom_minimum_size == Vector2(main.a(28), main.a(28)))
				if boxes.size() == 1:
					boxes[0].pressed.emit()
				print("mtick: boxes %d, off %s" % [boxes.size(), main.save["mountsOff"]])
			"moff":
				if arg in main.save["mountsOff"]:
					main.save["mountsOff"].erase(arg)
				else:
					main.save["mountsOff"].append(arg)
				main.refresh_shop()
			"levels": main.levels_due = [int(arg)]      # as if this level had been reached during the run
			"rebuild": main._rebuild()                  # what a turn of the phone does
			"toggle": main._toggle(arg)
			"xp":
				if arg == "back":
					main.save["xp"] = main.get_meta("xp_kept", main.save["xp"])
				else:
					main.set_meta("xp_kept", main.save["xp"])
					main.save["xp"] = int(arg)
			"qdone":                                    # during the run: an objective done, another half way, a level passed
				var q0: Dictionary = main.save["quests"][0]
				var q1: Dictionary = main.save["quests"][1]
				var k1: String = Progress.KINDS[q1["k"]]["stat"]
				main.progress({Progress.KINDS[q0["k"]]["stat"]: q0["goal"]})
				if k1 != Progress.KINDS[q0["k"]]["stat"]:
					main.progress({k1: ceili((q1["goal"] - q1["p"]) * 0.5)})
				main.progress({"dist": Progress.cfg["per_level"] * Progress.cfg["mpp"] * 1.2})
			"skipintro":                                # (the temple's scene of Histoire: not in the tour's timing)
				main.run.wait = minf(main.run.wait, 0.05)
				main.run.say_queue.clear()
				main.run.saying = ""
			"photo": main._show_photo()
			"life":                                     # a floating life picked up: two hearts on the HUD
				main.run.hearts += 1
				main.run.max_hearts = maxi(main.run.max_hearts, main.run.hearts)
				main._fill_hud()
			"story":                                    # Histoire alone: the guards' lines wait for a touch
				main.save["seenIntro"] = true
				main.save["mode"] = "story"
				main.go("play")
				main.run.hearts = 99
			"tallytap": main._tally_tap()              # a touch on the count: the step under way, finished
			"skiptalk":                                 # the rest of the temple's lines read at once: the blast
				main.run.say_queue.clear()
				main.run.saying = ""
			"catch":                                    # Histoire: his last heart lost, the guards at his heels
				main.run.obs.clear()
				main.run.god = false
				main.run.hearts = 1
				Game.hit(main.run, null)
			"tap":
				main.press()
				main.input.hold = false
			"darts":                                    # three flyers' warnings at once, at his height
				for k in 3:
					var o = Game.add_dart(main.run, main.run.cam + main.run.view_w + 40, 46.0)
					o.state = "warn"
					o.t = 0.1 * k
			"lantern":                                  # the next lantern and mushroom brought into view, brushed
				var r = main.run
				var i0 = floori((r.cam + r.sx) / Game.PROP_CELL) + 1
				for i in range(i0, i0 + 400):
					var pr = Game.prop_at(i)
					if pr != null and pr["kind"] == Game.PROP_LANTERN and Game.biome_at(r, pr["x"]) == 0 and Game.flat_at(r, pr["x"], Game.PROP_CELL * 0.6):
						r.cam = pr["x"] - 260 * Game.PIXEL
						r.obs.clear()
						for j in range(i - 3, i + 4):
							r.touched[j] = r.t
						break
			"next": main._tally_next()                 # the count's « Suivant »
			"confirm": main._confirm("Effacer toute la progression ? C'est définitif.", func() -> void: pass)
			"close":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
				for ch in main.get_children():          # the photo in full, too
					if ch is CanvasLayer and ch.layer == 45:
						ch.queue_free()
				if main.state == "tally" and main.tally_phase == "levels":
					main._tally_end()                   # (what its « Super ! » does)
			"equip":
				if not (arg in main.save["equipped"]):
					SaveData.toggle_equip(main.save, arg)
				main.refresh_menu()
			"slot": main._slot_info(arg)
			"loadout":                                  # three items on the home screen for a picture ("-": back as they were)
				if arg == "-":
					main.save["equipped"] = saved_loadout
				else:
					saved_loadout = main.save["equipped"].duplicate()
					for id in arg.split(" "):
						main.save["upgrades"][id] = maxi(1, int(main.save["upgrades"].get(id, 0)))
					main.save["equipped"] = Array(arg.split(" "))
				main.refresh_menu()
			"play":
				main.save["seenIntro"] = true
				main.save["best"] = 0
				main.go("play")
				main.run.god = true
			"give":                                     # the actives on the HUD, for its picture
				for k in arg.split(" "):
					main.run.up[k] = 1
				main.run.dash.full = Game.DASH_CD[1]
				main.run.boots.full = Game.BOOTS_CD[1]
				main.run.tnt.full = Game.TNT_CD[1]
				main.run.monster.full = Game.MONSTER_CD[1]
				main._fill_hud()
			"tip": main._menu_tip(main.MENU_TIPS.get(arg, ""))
			"scene":                                    # a scenery, a danger on the floor and an hourglass in view
				var r = main.run
				r.biome = int(arg)
				r.prev_biome = int(arg)
				r.biome_x = -1e9
				r.god = true
				var x = r.cam + r.sx + 520
				Game.add_spiky(r, x)
				var it = Game.Item.new()
				it.kind = "brake"
				it.x = x + 260
				it.y = Game.GROUND - 140
				r.bonuses.append(it)
			"own":                                      # bought at level 1, not equipped: its card shows both buttons
				main.save["upgrades"][arg] = 1
				main.save["equipped"].erase(arg)
				main.save["coins"] = maxi(main.save["coins"], 20000)
				main.refresh_shop()
			"pause": main.pause()
			"resume": main.resume()
			"die":
				main.run.god = false
				main.run.hearts = 1
				main.run.p.inv = 0
				var o = Game.Obs.new()
				o.kind = "spiky"
				Game.hit(main.run, o)
			"touch":                                    # a finger: "<index> <down|up> <game|button name>"
				var parts = arg.split(" ")
				var ev = InputEventScreenTouch.new()
				ev.index = int(parts[0])
				ev.pressed = parts[1] == "down"
				var pos = Vector2(640, 400)
				if parts[2] != "game":
					pos = (main.w[parts[2]] as Control).get_global_rect().get_center()
				ev.position = pos
				Input.parse_input_event(ev)
			"check":
				match arg:
					"hold": print("touch check: hold ", main.input.hold, ", fingers ", main.touches.keys(), ", on ground ", main.run.p.ground)
					"state": print("touch check: state ", main.state)
			"quit": get_tree().quit()

# ---------- coop: two browsers on this computer (node server/dev.mjs) ----------
#   ?test&net=…&coop=guest              waits on the home screen for an invitation (prints his friend code)
#                                       and takes it
#   ?test&net=…&coop=host&friend=CODE   adds that friend, invites him from the list (« Inviter »), and once
#                                       linked starts Histoire from the home screen, then Jouer after it
#   ?test&net=…&coop=host / coop=join&room=XXXX   the same with a room's four letters
# The host wears Double saut, RedMonster, Vitalité and the Vol; the guest nothing (the host's go on both).
# At 6 s the host drinks RedMonster: it must start on both (Game.remote_act).
# Both run with the invincibility on, a bot jumping now and then. At 5 s the guest is put in a bubble (the
# host jumps until he has brought him back); at 12 s both are (each brings the other back); from 20 s
# nobody jumps and both are put in bubbles: the run ends on both sides. Each prints, every second, how far
# ahead the partner is now (his last state carried to now at his speed): it must not grow.

var coop_step := 0
var coop_t := 0.0
var coop_said := {}
var coop_next := 1.0
var coop_runs := 0
var coop_tally := 0.0

func _press(b) -> void:
	if b is Button and is_instance_valid(b):
		b.pressed.emit()

func _find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root
	for ch in root.get_children():
		var f = _find_button(ch, text)
		if f != null:
			return f
	return null

func _coop_bench(delta: float) -> void:
	var c: Coop = main.coop
	var host = opts["coop"] == "host"
	if main.state == "tally":                        # the count at the end: Suivant after a moment
		coop_tally += delta
		if coop_tally > 1.5:
			coop_tally = 0.0
			main._tally_next()
		return
	if coop_step == 0 and t > 0.5 and main.state == "menu":
		var s: Dictionary = main.save
		s["seenIntro"] = true
		if host:
			s["upgrades"] = {"doubleJump": 1, "monster": 1, "heart": 1, "flight": 1}
			s["equipped"] = ["doubleJump", "monster", "heart"]
			s["powersOff"] = []
			main.refresh_menu()
		else:
			s["upgrades"] = {}
			s["equipped"] = []
		coop_step = 1
		if opts["coop"] == "guest":
			var me = await main.net.identity(s)
			print("COOP CODE ", me.get("code", "?"))
			coop_step = 10                           # then: the invitation (main polls every few seconds)
		elif host and opts["friend"] != "":
			main.friends_tab = "list"
			main.go("friends")
			main.w["fr-add"].text = opts["friend"]
			await main._add_friend()
			coop_step = 2
		else:
			main.friends_tab = "group"
			main.go("friends")
			if host:
				main._coop_host()
			else:
				main.w["co-code"].text = opts["room"]
				main._coop_join()
			coop_step = 3
	if coop_step == 2:                               # the friend in the list: his card, « Inviter à deux »
		if main.board.size() > 1:
			main.fr_sel = str(main.board[1].get("code", ""))
			main.refresh_friends()
			print("COOP INVITE-LIST")
			coop_step = 21
			coop_t = t
	if coop_step == 21 and t - coop_t > 1.0:
		_press(main.w["fr-inv2"])
		coop_step = 3
	if coop_step == 10 and main.invite_box != null:
		print("COOP INVITED")
		coop_step = 11
		coop_t = t
	if coop_step == 11 and t - coop_t > 1.2:
		_press(_find_button(main.invite_box, "Rejoindre"))
		coop_step = 3
	if c.room != "" and not coop_said.has("room"):
		coop_said["room"] = true
		print("COOP ROOM ", c.room)
	if c.state == "failed" and not coop_said.has("fail"):
		coop_said["fail"] = true
		print("COOP FAILED ", c.info)
	if c.state == "ready" and not coop_said.has("ready"):
		coop_said["ready"] = true
		coop_t = t
		print("COOP READY ", c.role, " mate=", c.mate)
	if coop_step == 3 and c.state == "ready" and main.state == "menu" and t - coop_t > 2.0:
		coop_step = 4
		print("COOP HOME %s kit=%s band=%s" % [c.role, c.kit.get("eq", []) if not host else main.save["equipped"], main.w["menu-coop-text"].text])
		coop_t = t
	if coop_step == 4 and host and t - coop_t > 1.5:
		coop_step = 5
		_press(main.w["menu-go-story"])               # Histoire, from the home screen, for both
	if coop_step == 4 and not host and t - coop_t > 0.5 and not coop_said.has("tap"):
		coop_said["tap"] = true                       # the guest's Jouer: only a word on the band
		_press(main.w["menu-go-endless"])
		print("COOP GUEST-TAP band=", main.w["menu-coop-text"].text, " state=", main.state)
	if main.state == "over" and not coop_said.get("in_over", false):
		coop_said["in_over"] = true
		print("COOP OVER ", c.role, " mode=", main.run.mode, " dist=", floori(main.run.dist), " rtt=", c.rtt)
		coop_runs += 1
		coop_t = t
	if main.state != "over":
		coop_said["in_over"] = false
	if main.state == "over" and coop_runs == 1 and t - coop_t > 2.5 and not coop_said.has("again"):
		coop_said["again"] = true                     # then Jouer: back home, the host starts it
		main.go("menu")
		coop_t = t
		coop_step = 6
	if coop_step == 6 and host and t - coop_t > 1.5 and main.state == "menu":
		coop_step = 7
		_press(main.w["menu-go-endless"])
	if main.state != "play" or main.run == null or not main.run.coop:
		return
	var r: Game.Run = main.run
	if r.t > 3.0 and not coop_said.has("gear%d" % coop_runs):
		coop_said["gear%d" % coop_runs] = true
		print("COOP GEAR %s mode=%s hearts=%d up=%s tier=%d" % [c.role, r.mode, r.hearts, r.up, Game.tier_of(r)])
	r.god = true
	if host and r.t > 6.0 and not coop_said.has("drink%d" % coop_runs):
		coop_said["drink%d" % coop_runs] = true
		main.input.monster = true
	if r.monster.t > 0 and not coop_said.has("fizz%d" % coop_runs):
		coop_said["fizz%d" % coop_runs] = true
		print("COOP ACT %s monster t=%.2f for %.1f s, recharge %.1f s" % [c.role, r.t, r.monster.t, r.monster.cd])
	var mate_b: bool = r.mate != null and r.mate.get("b", false)
	next_press -= delta
	var ending = r.t > 20.0
	if next_press <= 0 and not ending:              # a jump now and then; often when the partner floats
		next_press = 0.35 if mate_b else randf_range(0.6, 1.4)
		hold_left = 0.25
		main.press()
	if hold_left > 0:
		hold_left -= delta
		if hold_left <= 0:
			main.input.hold = false
	var force = func() -> void:
		r.god = false
		r.hearts = 1
		r.rewind_left = 0
		r.p.inv = 0
		Game.hit(r, null)
		r.god = true
	if not host and r.t > 5.0 and not coop_said.has("b1%d" % coop_runs):
		coop_said["b1%d" % coop_runs] = true
		force.call()
	if r.t > 12.0 and not coop_said.has("b2%d" % coop_runs):
		if not r.bubble:
			coop_said["b2%d" % coop_runs] = true
			force.call()
	if ending and not r.bubble and not r.dead:
		main.input.hold = false
		force.call()
	coop_next -= delta
	if coop_next <= 0:
		coop_next = 1.0
		var ahead = "-"
		if r.mate != null:
			var now_x = float(r.mate.get("x", 0)) + float(r.mate.get("v", 0)) * (r.t - float(r.mate.get("at", r.t)))
			ahead = "%.0f" % (now_x - (r.cam + r.sx))
		print("COOP %s t=%.1f d=%.0f ahead=%s delay=%.0fms bubble=%s mate_b=%s" % [opts["coop"], r.t, r.dist, ahead, c.shown * 1000, r.bubble, mate_b])
