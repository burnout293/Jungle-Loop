extends Node
## A bench for trying the game without playing it by hand (the web version's ?bac and its bot):
##   Godot --path . -- --bac --test [--seconds=30] [--shots=<dir>] [--start=1900] [--god]
##                     [--up=flight,dash] [--mode=endless] [--mount=rhino]
## A bot presses now and then, the run is printed every second, a picture is saved every 2 seconds
## (not with --headless, which draws nothing). Always with --bac: the real save is never touched.

var main: Node
var tour_i := 0
var opts := {"showcase": false, "quality": "", "prof": false, "tour": false, "seconds": 30.0, "shots": "", "start": 0.0, "god": false, "up": [], "mode": "story", "mount": "", "screen": "", "ride": "", "biome": -1, "still": false, "hitbox": false, "coop": "", "room": "", "mate": ""}
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
			"prof": opts["prof"] = true
			"quality": opts["quality"] = kv[1]
			"showcase": opts["showcase"] = true
			"coop": opts["coop"] = kv[1]           # host | join (in a browser, with ?net=)
			"room": opts["room"] = kv[1]
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
		r.bonuses[1].kind = "brake" if r.bonuses[0].kind == "life" else "life"
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
	if opts["coop"] != "":                           # two browsers, one run: see _coop_bench
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
		[5.62, "xp", "300"], [5.64, "tab", "up"], [5.68, "shot", "06b-shop-locked"], [5.69, "xp", "back"], [5.695, "tab", "power"], [5.698, "shot", "06c-shop-powers"],
		[5.7, "go", "settings"], [6.6, "shot", "07-settings"],
		[6.7, "toggle", "tg-font"], [7.6, "shot", "08-settings-rounded-font"],
		[7.7, "toggle", "tg-font"], [8.6, "shot", "09-settings-pixel-again"],
		[8.7, "confirm", ""], [9.2, "shot", "10-confirm"], [9.3, "close", ""],
		[9.4, "go", "menu"], [10.2, "equip", "magnet"], [10.4, "slot", "magnet"], [10.8, "shot", "11-menu-slot"],
		[11.0, "play", ""], [11.05, "give", "tnt boots slow dash"],
		[12.0, "touch", "0 down game"], [12.05, "check", "hold"], [12.3, "touch", "1 down btn-pause"], [12.35, "check", "state"],
		[12.4, "touch", "0 up game"], [12.45, "check", "hold"], [12.5, "resume", ""], [13.5, "shot", "12-play"],
		[13.6, "pause", ""], [14.4, "shot", "13-pause"],
		[14.5, "go", "settings"], [15.3, "shot", "14-settings-in-run"],
		[15.4, "go", "menu"], [16.2, "shot", "15-back-to-pause"],
		[16.3, "resume", ""], [16.35, "levels", "4"], [16.4, "die", ""], [18.6, "shot", "16-over-record"],
		[18.62, "close", ""], [18.64, "rebuild", ""], [18.95, "shot", "16b-over-rebuilt"],
		[19.0, "photo", ""], [19.6, "shot", "17-photo-full"], [19.65, "close", ""],
		[19.7, "go", "shop"], [19.75, "tab", "mount"], [19.8, "mpick", "rhinoTamed"], [21.0, "shot", "18-shop-tamed"],
		[21.1, "moff", "rhino"], [21.15, "mpick", "rhino"], [22.2, "shot", "19-shop-rhino-off"], [22.3, "moff", "rhino"],
		[22.4, "tab", "up"], [22.45, "pick", "boots"], [24.2, "shot", "20-shop-boots"],
		[24.3, "pick", "tnt"], [25.6, "shot", "21-shop-tnt"], [25.7, "pick", "dash"], [26.7, "shot", "22-shop-dash"],
		[26.8, "pick", "drunk"], [28.9, "shot", "23-shop-relic"],
		[29.0, "go", "menu"], [29.9, "tip", "endless"], [30.0, "shot", "24-menu-tip"], [30.05, "tip", ""],
		[30.2, "play", ""], [31.6, "scene", "1"], [32.0, "shot", "25-ruins"], [32.2, "scene", "3"], [32.6, "shot", "26-dungeon"],
		[32.7, "go", "shop"], [32.75, "tab", "up"], [32.8, "own", "tnt"], [32.85, "pick", "tnt"], [34.0, "shot", "27-shop-tnt-owned"],
		[34.1, "own", "dash"], [34.15, "pick", "dash"], [35.2, "shot", "28-shop-dash-owned"],
		[35.3, "tab", "power"], [35.35, "own", "flight"], [35.4, "pick", "flight"], [36.5, "shot", "29-shop-flight-owned"],
		[36.6, "tab", "mount"], [36.65, "mpick", "dragonfly"], [37.8, "shot", "30-shop-dragonfly"], [37.85, "mtick", ""], [38.2, "mtick", ""], [38.25, "mpick", "rhino"], [39.3, "shot", "31-shop-rhino"],
		[39.4, "quit", ""],
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
			"photo": main._show_photo()
			"confirm": main._confirm("Effacer toute la progression ? C'est définitif.", func() -> void: pass)
			"close":
				if main.modal != null:
					main.modal.queue_free()
					main.modal = null
				for ch in main.get_children():          # the photo in full, too
					if ch is CanvasLayer and ch.layer == 45:
						ch.queue_free()
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
			"give":                                     # the actives on the HUD, for its picture
				for k in arg.split(" "):
					main.run.up[k] = 1
				main.run.dash.full = Game.DASH_CD[1]
				main.run.boots.full = Game.BOOTS_CD[1]
				main.run.tnt.full = Game.TNT_CD[1]
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

# ---------- coop: two browsers on this computer (node server/dev.mjs), ?test&net=…&coop=host|join&room=… ----------
# The host opens a room and prints its letters; the guest, started with them, joins; the host starts the
# run. Both run with the invincibility on, a bot jumping now and then. At 5 s the guest is put in a bubble
# (the host jumps until he has brought him back); at 12 s both are (each brings the other back); from 20 s
# nobody jumps and both are put in bubbles: the run ends on both sides.

var coop_step := 0
var coop_t := 0.0
var coop_said := {}
var coop_next := 1.0

func _coop_bench(delta: float) -> void:
	var c: Coop = main.coop
	if coop_step == 0 and t > 0.5 and main.state == "menu":
		main.save["seenIntro"] = true
		main.friends_tab = "coop"
		main.go("friends")
		if opts["coop"] == "host":
			main._coop_host()
		else:
			main.w["co-code"].text = opts["room"]
			main._coop_join()
		coop_step = 1
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
	if coop_step == 1 and c.state == "ready" and opts["coop"] == "host" and t - coop_t > 1.5:
		coop_step = 2
		main._coop_go()
	if main.state == "over" and not coop_said.has("over"):
		coop_said["over"] = true
		print("COOP OVER ", c.role, " dist=", floori(main.run.dist), " rtt=", c.rtt)
	if main.state != "play" or main.run == null or not main.run.coop:
		return
	var r: Game.Run = main.run
	r.god = true
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
	if opts["coop"] == "join" and r.t > 5.0 and not coop_said.has("b1"):
		coop_said["b1"] = true
		force.call()
	if r.t > 12.0 and not coop_said.has("b2"):
		if not r.bubble:
			coop_said["b2"] = true
			force.call()
	if ending and not r.bubble and not r.dead:
		main.input.hold = false
		force.call()
	coop_next -= delta
	if coop_next <= 0:
		coop_next = 1.0
		print("COOP %s t=%.1f d=%.0f mate=%s bubble=%s" % [opts["coop"], r.t, r.dist, ("%.0f%s" % [float(r.mate.get("d", 0)), " (bulle)" if mate_b else ""]) if r.mate != null else "-", r.bubble])
