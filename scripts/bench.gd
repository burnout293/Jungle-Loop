extends Node
## A bench for trying the game without playing it by hand (the web version's ?bac and its bot):
##   Godot --path . -- --bac --test [--seconds=30] [--shots=<dir>] [--start=1900] [--god]
##                     [--up=flight,dash] [--mode=endless] [--mount=rhino]
## A bot presses now and then, the run is printed every second, a picture is saved every 2 seconds
## (not with --headless, which draws nothing). Always with --bac: the real save is never touched.

var main: Node
var tour_i := 0
var saved_loadout := []
var opts := {"showcase": false, "quality": "", "prof": false, "tour": false, "seconds": 30.0, "shots": "", "start": 0.0, "god": false, "up": [], "mode": "story", "mount": "", "screen": "", "ride": "", "biome": -1, "still": false, "hitbox": false, "coop": "", "room": "", "mate": "", "friend": "", "slow": 0, "every": 2.0, "die": -1.0}
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
		[49.0, "story", ""], [50.0, "shot", "33-story-say"], [51.0, "tap", ""], [51.3, "tap", ""], [51.6, "tap", ""],
		[52.0, "shot", "34-story-line3"], [52.1, "tap", ""], [52.4, "tap", ""], [55.0, "shot", "35-guards-chasing"],
		[56.5, "shot", "36-guards-chasing2"], [57.0, "darts", ""], [57.4, "shot", "37-warn-stack"],
		[57.5, "lantern", ""], [57.7, "shot", "38-lantern-lit"], [58.4, "shot", "39-lantern-later"],
		[59, "quit", ""],
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
			main.friends_tab = "friends"
			main.go("friends")
			main.w["fr-add"].text = opts["friend"]
			await main._add_friend()
			coop_step = 2
		else:
			main.friends_tab = "coop"
			main.go("friends")
			if host:
				main._coop_host()
			else:
				main.w["co-code"].text = opts["room"]
				main._coop_join()
			coop_step = 3
	if coop_step == 2:                               # the friend in the list: « Inviter »
		var b = _find_button(main.w["fr-board"], "Inviter")
		if b != null:
			print("COOP INVITE-LIST")
			coop_step = 21
			coop_t = t
	if coop_step == 21 and t - coop_t > 1.0:
		_press(_find_button(main.w["fr-board"], "Inviter"))
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
