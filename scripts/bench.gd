extends Node
## A bench for trying the game without playing it by hand (the web version's ?bac and its bot):
##   Godot --path . -- --bac --test [--seconds=30] [--shots=<dir>] [--start=1900] [--god]
##                     [--up=flight,dash] [--mode=endless] [--mount=rhino]
## A bot presses now and then, the run is printed every second, a picture is saved every 2 seconds
## (not with --headless, which draws nothing). Always with --bac: the real save is never touched.

var main: Node
var tour_i := 0
var opts := {"tour": false, "seconds": 30.0, "shots": "", "start": 0.0, "god": false, "up": [], "mode": "story", "mount": "", "screen": "", "ride": "", "biome": -1, "still": false, "hitbox": false}
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
	main.go("play")
	var r: Game.Run = main.run
	r.god = opts["god"]
	main.render.hitbox = opts["hitbox"]
	if opts["start"] > 0:                            # as if the first metres had already been run
		var D: float = opts["start"] * Game.PPM
		var g := Game.SPEED_GAIN
		r.t = (-r.base + sqrt(r.base * r.base + 2 * g * D)) / g
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
	runs += 1

func _process(delta: float) -> void:
	if main.state == "loading":
		return
	t += delta
	if opts["tour"]:
		await _tour()
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
	if main.state == "over":
		over_for += delta
		if over_for > 1.0:
			over_for = 0
			_start()
		return
	var r: Game.Run = main.run
	if r == null:
		return
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
		next_shot = 2.0
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.save_png(opts["shots"].path_join("shot-%03d.png" % shot_n))
		shot_n += 1

## --tour: every screen in turn, with pictures taken while they slide (the menus' check).
func _tour() -> void:
	var steps = [
		[0.9, "shot", "01-menu"],
		[1.0, "go", "shop"], [1.15, "shot", "02-shop-sliding"], [2.0, "shot", "03-shop"],
		[2.1, "pick", "magnet"], [3.6, "shot", "04-shop-magnet"],
		[3.7, "buy", "magnet"], [4.0, "shot", "05-buy-confetti"],
		[4.2, "tab", "mount"], [5.6, "shot", "06-shop-mounts"],
		[5.7, "go", "settings"], [6.6, "shot", "07-settings"],
		[6.7, "toggle", "tg-font"], [7.6, "shot", "08-settings-rounded-font"],
		[7.7, "toggle", "tg-font"], [8.6, "shot", "09-settings-pixel-again"],
		[8.7, "confirm", ""], [9.2, "shot", "10-confirm"], [9.3, "close", ""],
		[9.4, "go", "menu"], [10.2, "equip", "magnet"], [10.4, "slot", "magnet"], [10.8, "shot", "11-menu-slot"],
		[11.0, "play", ""],
		[12.0, "touch", "0 down game"], [12.05, "check", "hold"], [12.3, "touch", "1 down btn-pause"], [12.35, "check", "state"],
		[12.4, "touch", "0 up game"], [12.45, "check", "hold"], [12.5, "resume", ""], [13.5, "shot", "12-play"],
		[13.6, "pause", ""], [14.4, "shot", "13-pause"],
		[14.5, "go", "settings"], [15.3, "shot", "14-settings-in-run"],
		[15.4, "go", "menu"], [16.2, "shot", "15-back-to-pause"],
		[16.3, "resume", ""], [16.4, "die", ""], [18.6, "shot", "16-over-record"],
		[19.0, "quit", ""],
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
			"toggle": main._toggle(arg)
			"confirm": main._confirm("Effacer toute la progression ? C'est définitif.", func() -> void: pass)
			"close":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
			"equip":
				if not (arg in main.save["equipped"]):
					SaveData.toggle_equip(main.save, arg)
				main.refresh_menu()
			"slot": main._slot_info(arg)
			"play":
				main.save["seenIntro"] = true
				main.save["best"] = 0
				main.go("play")
				main.run.god = true
			"pause": main.pause()
			"resume": main.resume()
			"die":
				main.run.god = false
				main.run.hearts = 1
				main.run.p.inv = 0
				main.run.dead = true
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
