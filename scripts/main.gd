extends Node
## Glue: screens, input, HUD and the frame loop (port of js/main.js, index.html and style.css).
## The screen is 1280 x 720 units, shown in 16:9 with bars around it (project settings); one art
## pixel is U units, and the interface is measured in art pixels like the web version's (--ui).

const VERSION := "0.69.0"
const U := 2.25
const W := 1280.0
const H := 720.0
const M := 8.0                         # margin at the edges of the frame (art pixels)

const INK := Color("#fff8e6")
const DIM := Color("#c9d6c3")
const LINE := Color("#1a1024")
const BOX := Color("#232a44")
const BOX_HI := Color("#3b4670")
const GOLD := Color("#ffd35c")
const RELIC := Color("#5cf2e0")
const LEAF := Color("#6cc22e")

const DEATHS := ["Ficelé comme un rôti…", "Direction : la broche.", "Retour au temple !", "Presque. Enfin… non.",
	"La jungle : 1 — Toi : 0", "Ça piquait, hein ?", "Encore ! Encore !", "Les pygmées te ramènent."]
const TABS := {"up": "Équipements", "power": "Pouvoirs", "mount": "Montures", "skin": "Skins"}
# The home screen's three buttons: what each one is about, in a panel while hovered or held.
const MENU_TIPS := {
	"endless": "Essayez autant que vous souhaitez de vous échapper de cette forêt, mais il y a peu de chances que vous vous en sortiez vivant.",
	"story": "Deux vies, et seulement les pouvoirs de la relique : chaque gardien vaincu en rend un morceau, et un pouvoir de plus.",
	"shop": "Parce que tout aventurier a le droit à sa panoplie de gadgets.",
}
const ACTS := ["tnt", "boots", "slow", "dash", "monster"]   # the HUD's buttons, right to left as shown
const MOUNT_TEXT := {
	"gorilla": "Il saute plus haut, et son second saut l'emmène jusqu'aux lianes du haut de l'écran. Appuie pour en redescendre.",
	"rhino": "Il saute peu mais court de plus en plus vite, pulvérise les caisses et ramasse large. Rien ne le blesse, et il repart tout seul au bout de 8 secondes.",
	"dragonfly": "Il vole : appuie pour monter, relâche pour descendre.",
}

var save: Dictionary
var state := "loading"                 # loading | menu | intro | shop | settings | play | pause | over
var run: Game.Run = null
var still: Game.Run                    # never updated: the frozen temple scene behind the menus
var input := Game.Controls.new()
var render: Render
var game_vp: SubViewport               # the game is drawn here, q x q real pixels per art pixel (the web canvas)
var game_view: TextureRect             # and shown from here, fitted to the frame
var demo := Demo.new()                 # the shop's animated preview
var demo_render: Render
var demo_vp: SubViewport
var q := 3                             # real pixels per art pixel of the game's picture (see fit)
var time := 0.0
var dead_for := 0.0
var banner_timer := 0.0
var last_dist := 0.0
var hint_step := 0                     # 0 none, 1 "tap to jump", 2 "hold to jump higher"
var hint_timer := 0.0
var picked := "doubleJump"
var tab := "up"
var picked_mount := "gorilla"
var in_run := false                    # the settings were opened from the pause screen: the run waits behind them
var set_tab := "game"                  # Réglages: the category open (0.51: Jeu, Affichage, Son, Sauvegarde)
var open_slot := 0                     # the partie a save file being opened goes to
var fk := 0.95                         # evens out the sizes of the typefaces
var font: Font
var bold: Font                         # buttons, the HUD and titles: the bold cut
var plain: Font                        # Godot's own: what must be read letter by letter (a room's letters, pseudos, codes)
var ui: Control
var screens := {}
var w := {}                            # the widgets that change, by name
var icons := {}
var styles := {}
var title_letters: Array = []
var hud_state := {"dist": -1, "gold": -1, "hearts": -1}
var debug_layer: CanvasLayer
var debug_panel: Control = null
var taps: Array = []                   # touches on the level badge: five in a row open the debug menu
var net: Net                           # the server (net.gd): nothing is sent until it is deployed
var adopted_note := ""                # said once on the menu: the web version's game was taken over
var photo: ImageTexture = null          # the game as it was the moment he fell, for the end screen
var quick_on := false                  # (0.68) the « Partie rapide » searching (its lobby's free places say so)
const QUICK_EVERY := 5.0               # (0.68) ... looking again this often while alone in my room
var esc_hold := 0.0                    # (0.68) freed: the escape's panel stays this long
var photo_taken := false
var touches := {}                     # fingers down on the game (not on a button): the jump is held while one stays
var confetti_layer: Control
var modal: CanvasLayer = null          # the in-game « Oui / Non » question, while one is asked
var levels_due: Array = []             # levels gained during the run, shown in a panel once it is over
var over_info := {}                    # what the end screen shows, kept to fill it again after a turn
var web_cbs := []                      # the browser's callbacks, kept alive (web only)
var rebuild_due := false               # the window changed size: the pixel typeface's sizes are worked out again
var rebuild_t := 0.0
var fps_param := false                 # "?fps" in the address (web): the frame rate shown, as in the web version                   # (once it has stopped changing for a moment)
var perf := {"n": 0, "game": 0, "draw": 0, "text": ""}   # what a frame costs, averaged: the FPS corner shows it
var endless_biome := 0                 # where the next Run illimitée (Jouer) starts: the home screen shows it
var held: Button = null                # a home screen button held down (a long press shows its panel)
var fly_side := ""                     # 0.50: the next screen shown comes from this side (its button's)
var held_t := 0.0
var tip_held := false                  # its panel came from a long press: that press launches nothing
var coop: Coop                         # two phones in one run (coop.gd)
var coop_start := {}                   # a coop run about to start: {mode, seed, biome, tier, up, at}
var coop_send_t := 0.0
var coop_last := false                 # the last run was for two
var coop_owed := 0.0                   # for two: real seconds the run still owes (no frame's time is ever lost)
var coop_note := ""                    # a word on the home screen's band for two, for a moment
var coop_note_t := 0.0
var coop_was := ""                     # the link's state last seen (main notices the partner leaving)
var peeking := false                   # the pause's eye: its menu hidden, the game looked at
var run_xp0 := 0.0                     # the experience when the run began (the end counts from there)
var run_quests0: Array = []            # the objectives when it began: [{q, p}] (the end shows them move on)
var tally_tw: Tween = null             # the end's count, while it runs
var tally_level := 0                   # the level the count has shown so far
var tally_phase := ""                  # count, impact, bar, levels, done: what a touch finishes
var tally_age := 0.0                   # how long it has been counting (the beat of the number)
var tally_dur := 1.0                   # how long the count lasts
var tally_tick_t := 0.0                # the last tick heard (the count, the bars filling)
var over_tweens: Array = []            # the end screen's moves, stopped if it is left or built again
var kit_sent := ""                     # the host's items and powers last sent to the guest (JSON)
var invite_t := 3.0                    # seconds before the next look for an invitation
var invite_busy := false
var invite_seen := {}                  # the rooms of the invitations already shown
var invite_box: CanvasLayer = null
const INVITE_POLL := 5.0
var testing := false                   # a bench drives the game (--test, ?test on this computer): nothing looked up online
var update_busy := false
var update_online := ""                # the version online (version.txt beside the game), once looked at
var mystery_shown := ""                # (0.65) the mystery rule already revealed on this phone
const FINAL_SPEED := 1.4               # (0.65) a treasure's last race: its speed, times this
var update_text := ""                  # what Réglages says about it
var update_sure := false               # « à jour » said: pressing again reloads anyway
var update_notes := ""                 # 0.49.1: what the new version brings (nouveautes.txt beside the game)
var update_offered := false            # 0.49.1: the update offered once this session (a window at the start)
const INVITE_SCREENS := ["menu", "shop", "friends", "over", "tally", "settings"]
var friends_tab := "list"              # Amis: list, group, scores (0.51)
var group_note := ""                    # (0.58) a word for Amis → Groupe (a code too short, a friend list empty)
var board: Array = []                  # the friends' board, as the server sent it
var treasure: CanvasLayer = null       # the Trésor (0.47): the urns to break, what is in the bag
var urn_busy := false                  # an urn is being broken (its shake): one at a time
var urn_pick := ""                     # (0.68) the rarity of urn to open next (the Trésor)
var picked_skin := ""                  # the shop's Skins tab: the row picked ("<target>:" for an original look)
var race: Race                         # 0.48: the race for four (race.gd)
var race_start := {}                   # a race about to start: {seed, biome, tier, up, at}
var race_send_t := 0.0
var race_seen := true                  # the last race's result has been looked at (the lobby shows again)
var watch_k := -1                      # (0.55) fallen in a race: the place of the one I watch
var daily_on := false                  # (0.57) the Course du jour is what Jouer / Rejouer starts
var watch_res := false                 # (0.57) ... and the results shown over the view
var watch_done := false                # (0.57) ... the race decided while watching
var look_cache := {}                   # (0.55) Pépito in each skin (the group's looks): skin id -> texture
var race_note := ""                    # a word for the race screen (who left...)
var race_count := -1                   # the second of the count before the start last shown
var board_cache: Array = []            # the friends' list as last heard: their records on the road (signs)
var fr_sel := ""                       # Amis: the friend chosen in the list (his code), "" for my own card
var friends_sub := "list"              # (0.57) Liste d'amis: its two tabs, list | req (the requests)
var requests := {"incoming": [], "outgoing": []}   # (0.57) the friend requests, as the server last said
var req_sel := ""                      # (0.57) the request chosen (its code)
var req_seen := {}                     # (0.57) the requests already shown in a window this session
var req_t := 2.0                       # (0.57) seconds before the next look for a request
var req_box: CanvasLayer = null
var scanning := false                  # (0.57) the QR scanner is open over the game
const OFFER_TIME := 3.0

# ---------- start ----------

func _ready() -> void:
	Progress.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))   # prices, levels, objectives
	Treasure.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))   # the urns (0.47)
	Tune.load_file()                              # reglages/equilibrage.txt: the game's numbers (before Debug takes its origin)
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))   # Histoire: what the guards say
	save = SaveData.load_save()
	Net.load_config(FileAccess.get_file_as_string("res://reglages/reseau.txt"))   # the server's address, empty for now
	Net.set_from_args()
	net = Net.new()
	add_child(net)
	coop = Coop.new()
	coop.net = net
	coop.save = save
	add_child(coop)
	coop.changed.connect(_on_coop_changed)
	coop.message.connect(_on_coop)
	race = Race.new()
	race.net = net
	race.save = save
	add_child(race)
	race.changed.connect(_on_race_changed)
	race.message.connect(_on_race)
	Race.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))   # the stakes (0.48)
	Daily.load_config(FileAccess.get_file_as_string("res://reglages/courses-du-jour.txt"))  # (0.58) every daily race
	_adopt_web_save()
	Audio.set_volumes(save["musicVol"], save["sfxVol"])
	Debug.setup()
	render = Render.new()
	game_vp = _viewport(render)
	game_view = TextureRect.new()
	game_view.texture = game_vp.get_texture()
	game_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_view.stretch_mode = TextureRect.STRETCH_SCALE
	game_view.size = Vector2(W, H)
	game_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_view)
	demo_render = Render.new()
	demo_render.view_w = Demo.W
	demo_vp = _viewport(demo_render)
	demo_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_window().size_changed.connect(fit)
	fit()
	still = Game.new_run({})
	still.cam = -Game.TEMPLE_PAN                  # (0.52) the home screen shows the whole temple, as the run starts
	_roll_biome()
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.size = Vector2(W, H)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_font()
	var loading = _label("Chargement…", ts("m"), DIM)
	loading.position = Vector2(0, H / 2 - 20)
	loading.size = Vector2(W, 40)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(loading)
	w["loading"] = loading
	# the bench: a bot plays (see bench.gd); in a browser only on this computer, with "?test" in the address
	var web_test = OS.has_feature("web") and _js_yes("['localhost','127.0.0.1'].includes(location.hostname) && location.search.includes('test')")
	# (a release build ignores --test: the bench sets upgrades in the save, a way round the debug lock)
	testing = ("--test" in OS.get_cmdline_user_args() and OS.is_debug_build()) or web_test
	if testing:
		var bench = load("res://scripts/bench.gd").new()
		bench.main = self
		add_child(bench)
	_load.call_deferred()

func _load() -> void:
	await get_tree().process_frame                # the "loading" text is on screen first
	if OS.has_feature("web") and not testing:
		_look_update.call_deferred(false)          # a newer version online: a « ! » on the gear
	var t0 = Time.get_ticks_msec()
	Art.load_all()
	Skins.apply(save["skins"]["worn"])               # the skins worn (0.47)
	var t_art = Time.get_ticks_msec() - t0
	Art.set_danger_rim(save["dangerRim"])
	render.shift = save["alertShift"]
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	for n in ["ui-btn-slate-38", "ui-btn-slate-30", "ui-btn-green-50", "ui-btn-gold-38", "ui-btn-gold-30", "ui-gear", "ui-title", "coin-icon", "heart"]:
		icons[n] = _tex(n)
	_styles()
	_build()
	w["loading"].queue_free()
	await get_tree().process_frame               # every block has its size: each one is told where it flies from
	_aim_flyers()
	if adopted_note != "":
		_menu_note.call_deferred(adopted_note)
	print("Jungle Loop %s : prêt en %d ms (dont images %d ms)" % [VERSION, Time.get_ticks_msec() - t0, t_art])
	go("menu")
	_js("window.jlReady && window.jlReady()")    # 0.50: the page's loading chase runs off (html/shell.src.html)
	_refresh_board()
	_check_friend_link.call_deferred()
	_offer_rejoin.call_deferred()

## (0.57) The game stopped while in a group (a crash, a slow phone): « Rejoindre ton groupe ? » at the start.
func _offer_rejoin() -> void:
	if not Net.enabled() or testing or not Coop.supported():
		return
	var d = Race.kept()
	if d.is_empty():
		return
	_confirm("Le jeu s'est fermé pendant que tu étais dans un groupe (%s). Le rejoindre ?" % str(d["room"]), func() -> void:
		race.save = save
		race_seen = true
		await race.rejoin(d)
		if race.role == "host":
			race.set_kit(SaveData.loadout(save))
		go("race"), "Rejoindre", "Non merci")
	if modal != null:                                # « Non merci »: the group is forgotten
		modal.tree_exited.connect(func() -> void:
			if race.role == "":
				race._keep(), CONNECT_ONE_SHOT)

## The game used to be the web version, at this same address: its progress is in the browser's
## localStorage (jungle-loop-save-v1), in the same format as the save codes. The first time this version
## runs there, it takes that game over, unless its own has come further (more experience); what it had
## is kept aside (user://jungle-loop-save-before-web.json). Done once (jungle-loop-godot-adopted).
func _adopt_web_save() -> bool:
	if not OS.has_feature("web") or "--bac" in OS.get_cmdline_user_args() or _js_yes("location.search.includes('bac')"):
		return false
	if _js_yes("localStorage.getItem('jungle-loop-godot-adopted')"):
		return false
	var raw = _js("localStorage.getItem('jungle-loop-save-v1') || ''")
	_js("localStorage.setItem('jungle-loop-godot-adopted', '1')")
	if raw == null or str(raw) == "":
		return false
	var parsed = JSON.parse_string(str(raw))
	if not (parsed is Dictionary):
		return false
	var web = SaveData.sanitize(parsed)
	var had = FileAccess.file_exists(SaveData.path())
	if had and int(save["xp"]) >= int(web["xp"]):
		return false                                 # this version's own game has come further
	if had:
		var f = FileAccess.open("user://jungle-loop-save-before-web.json", FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(save))
	save = web
	coop.save = save                                 # (0.56: the race and the two-player link see the same save)
	race.save = save
	SaveData.store(save)
	adopted_note = "Ta partie a été reprise : niveau %d, %d pièces, record %d m." % [Progress.level_info(save["xp"])["level"], save["coins"], save["best"]]
	print("Partie de la version web reprise : ", adopted_note)
	return true

## A short note on the menu, in the box over the slots; a touch puts it away.
func _menu_note(text: String) -> void:
	var box: PanelContainer = w["menu-info"]
	for ch in box.get_children():
		ch.queue_free()
	box.set_meta("id", "")
	var l = _label(text, ts("s"), INK, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = a(280)
	box.add_child(l)
	box.visible = true

func _viewport(r: Render) -> SubViewport:
	var vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.size = Vector2i(569, 320)
	vp.add_child(r)
	add_child(vp)
	return vp

## A phone or a tablet (touch first), in an app or in a browser.
func _touch() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

## The quality chosen in Réglages, or the one that suits the device until one is.
func quality() -> String:
	var ql: String = save.get("quality", "")
	return ql if ql in SaveData.QUALITIES else ("perf" if _touch() else "max")

## The game is always shown in 16:9 (569 x 320 art pixels). Its picture holds q x q real pixels per art
## pixel, then is fitted to the screen. Qualité (Réglages):
##   Max: as many as the screen can show (4 at most), softened as it is fitted; as many images a second
##        as the screen refreshes (120 on some phones).
##   Perf: 2 at most, shown as hard squares (a phone fills four times fewer pixels), held at 60 images a
##        second: steady, where a 120 Hz screen would otherwise swing between 45 and 65.
##   Éco: the same picture, 30 images a second, fewer little creatures and less weather: the battery.
func fit() -> void:
	var win = Vector2(get_window().size)
	var real = U * minf(win.x / W, win.y / H)
	var mode = quality()
	if mode == "max":
		q = clampi(ceili(real - 0.01), 1, 4)
	else:
		q = clampi(floori(real + 0.01), 1, 2)
	game_vp.size = Vector2i(569 * q, 320 * q)
	demo_vp.size = Vector2i(roundi(Demo.W * q), roundi(Demo.H * q))
	# finer than the screen: fitted smoothly; coarser (2 or less): hard squares, smoothed it would only blur
	var smooth = mode == "max" and (q >= real - 0.01 or q > 2)
	game_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	if w.has("demo-view"):
		w["demo-view"].texture_filter = game_view.texture_filter
	Engine.max_fps = {"max": 0, "perf": 60, "eco": 30}[mode]
	Ambient.lite = mode == "eco"

func _tex(name: String) -> Texture2D:
	var path = "res://assets/img/" + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func icon(name: String) -> Texture2D:
	if not icons.has(name):
		icons[name] = _tex(name)
	return icons[name]

# ---------- looks ----------

## The game's own pixel typeface, Silkscreen, kept sharp (no smoothing), or the rounded Fredoka for
## whoever reads it better (a setting); Godot's own if their files are missing (assets/fonts, OFL).
func _font() -> void:
	var dir = "res://assets/fonts/"
	fk = 0.95
	font = ThemeDB.fallback_font
	bold = font
	plain = ThemeDB.fallback_font
	if save["pixelFont"] and ResourceLoader.exists(dir + "Silkscreen-Regular.ttf"):
		font = load(dir + "Silkscreen-Regular.ttf")
		bold = load(dir + "Silkscreen-Bold.ttf") if ResourceLoader.exists(dir + "Silkscreen-Bold.ttf") else font
		for f in [font, bold]:
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		fk = 0.82
	elif not save["pixelFont"] and ResourceLoader.exists(dir + "Fredoka-Variable.ttf"):
		var base = load(dir + "Fredoka-Variable.ttf")
		var wght = TextServerManager.get_primary_interface().name_to_tag("wght")
		font = FontVariation.new()
		font.base_font = base
		font.variation_opentype = {wght: 500}
		bold = FontVariation.new()
		bold.base_font = base
		bold.variation_opentype = {wght: 700}
	# the symbols neither typeface has (◈ ● ○ ★ ↻ −), drawn on Silkscreen's grid (tools/make_symbols.py):
	# a browser or a phone has no system font to find them in
	if ResourceLoader.exists(dir + "JungleSymbols.ttf") and font != ThemeDB.fallback_font:
		var sym: FontFile = load(dir + "JungleSymbols.ttf")
		sym.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		sym.hinting = TextServer.HINTING_NONE
		sym.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		for f in [font, bold]:
			f.fallbacks = [sym]
	var th = Theme.new()
	th.default_font = font
	th.default_font_size = ts("m")
	ui.theme = th

## Text sizes, in units: small, middle, large, extra large (style.css --t-s ... --t-xl). The pixel
## typeface is only sharp when one of its own pixels covers a whole number of the screen's: like the web
## version, its sizes are brought to the nearest such size (it is drawn on a grid of 8).
func ts(k: String) -> int:
	var base = {"s": 11, "m": 14, "l": 19, "xl": 26, "huge": 52}[k] * fk * U
	if not save["pixelFont"] or k == "huge":
		return roundi(base)
	var sc = _ui_scale()
	return maxi(1, roundi(maxf(8, roundf(base * sc / 8 - 0.12) * 8) / sc))

## A size for the plain typeface (tp: the same steps as ts, without the pixel grid).
func tp(k: String) -> int:
	return roundi({"s": 11, "m": 14, "l": 19, "xl": 26, "huge": 52}[k] * 0.95 * U)

## A label in the plain typeface: a room's letters, a pseudo, a friend code, read letter by letter.
func _plain(l: Label, k: String) -> Label:
	l.label_settings.font = plain
	l.label_settings.font_size = tp(k)
	return l

## Real pixels per unit of the 1280 x 720 frame.
func _ui_scale() -> float:
	var win = Vector2(get_window().size)
	return maxf(0.1, minf(win.x / W, win.y / H))

func a(v: float) -> float:
	return v * U

func _flat(bg: Color, border: Color = LINE, bw: float = 1.5) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(roundi(bw * U))
	s.set_content_margin_all(a(4))
	return s

# ---------- the UI kit v2 (assets/img/ui-v2: tools/import_ui_v2_godot.py) ----------
# Stone, vines and a turquoise gem, made at the exact size of each box in art pixels: nothing is ever
# stretched out of shape or cut. Buttons and bars keep their ends whole and stretch only a middle made of
# identical columns; fixed panels are their box's exact size; the panels that follow their text repeat
# identical rows. Each picture is enlarged to the frame's art pixel (U), as the web version shows it.
const KIT_CAP := {30: 27, 38: 33, 50: 43, 58: 43}                  # buttons: the width of their ends
const WOOD_CAP := {30: 30, 38: 34, 50: 40, 58: 40}                 # 0.50: the wood ones (tools/make_wood_ui.py)
const KIT_FRAME := [16, 15, 21, 13]                          # panels: the stone frame left, right, top, bottom
const KIT_BAR := {8: [12, 13, 2, 6, 8, 9], 12: [15, 17, 4, 8, 12, 10]}   # ends l/r, trough rows, fill insets l/r

func _kit(name: String) -> Texture2D:
	var dir = "wood/" if _wood_ui() and (name.begins_with("btn-") or name.begins_with("sq-")) else ""
	var key = "kit:" + dir + name
	if icons.has(key):
		return icons[key]
	var path = "res://assets/img/ui-v2/" + dir + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var im = (load(path) as Texture2D).get_image()
		im.resize(roundi(im.get_width() * U), roundi(im.get_height() * U), Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(im)
	icons[key] = tex
	return tex

## 0.50: the buttons are of mossy wood (assets/img/ui-v2/wood); the stone ones are the skin « Pierre du
## temple » (Skins, target "buttons"), worn or not: the whole interface is built again when it changes.
func _wood_ui() -> bool:
	return str(save["skins"]["worn"].get("buttons", "")) != "buttons-stone"

func _cap(h: int) -> int:
	return WOOD_CAP[h] if _wood_ui() else KIT_CAP[h]

## A box of the kit: `slice` [left, right, top, bottom] art pixels kept whole, `pad` the room inside.
func _kit_box(name: String, slice: Array, pad: Array, mod: Color = Color.WHITE) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = _kit(name)
	sb.texture_margin_left = a(slice[0])
	sb.texture_margin_right = a(slice[1])
	sb.texture_margin_top = a(slice[2])
	sb.texture_margin_bottom = a(slice[3])
	sb.content_margin_left = a(pad[0])
	sb.content_margin_right = a(pad[1])
	sb.content_margin_top = a(pad[2])
	sb.content_margin_bottom = a(pad[3])
	sb.modulate_color = mod
	return sb

## A panel of a fixed size (pane-left 262 x 204...): the room inside is what the frame leaves.
func _kit_panel(name: String, more: float = 0.0) -> StyleBoxTexture:
	return _kit_box(name, [0, 0, 0, 0], [KIT_FRAME[0] + 2 + more, KIT_FRAME[1] + 2 + more, KIT_FRAME[2] + 1 + more, KIT_FRAME[3] + 1])

## A panel of a fixed width whose height follows its text (intro-pane 361, menu-info 300).
func _kit_tall(name: String) -> StyleBoxTexture:
	return _kit_box(name, [0, 0, 51, 55], [KIT_FRAME[0] + 6, KIT_FRAME[1] + 6, KIT_FRAME[2] + 4, KIT_FRAME[3] + 4])

## A square button of the kit at its exact size (36 or 28): `icon_name` gem, gear, play, close, check, blank.
func _kit_square(b: Button, icon_name: String, size: int) -> void:
	var n = "sq-%s-%d" % [icon_name, size]
	b.custom_minimum_size = Vector2(a(size), a(size))
	b.add_theme_stylebox_override("normal", _kit_box(n, [0, 0, 0, 0], [0, 0, 0, 0]))
	b.add_theme_stylebox_override("hover", _kit_box(n, [0, 0, 0, 0], [0, 0, 0, 0], Color(1.12, 1.12, 1.12)))
	b.add_theme_stylebox_override("pressed", _down(_kit_box(n, [0, 0, 0, 0], [0, 0, 0, 0], Color(0.85, 0.85, 0.85))))
	b.add_theme_stylebox_override("disabled", _kit_box(n, [0, 0, 0, 0], [0, 0, 0, 0], Color(0.6, 0.6, 0.65)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## The shop's buttons (assets/img/ui-v2/shop, made at their boxes' exact sizes: Retour 54 x 36, the
## families' tabs 54 x 64, the items' rows 236 x 30), one picture per state, shown whole. The one chosen
## (a tab, a row) keeps its "selected" picture whatever the pointer does. `pad`: the room inside the stone.
const SHOP_PAD := {"back": [8, 7, 8, 9], "tab": [8, 7, 8, 9], "item": [0, 0, 0, 0]}

func _shop_skin(b: Button, kind: String, sel: bool) -> void:
	var press = "pressed" if kind == "back" else "selected"
	var pics = {"normal": press if sel else "normal", "hover": press if sel else "hover", "pressed": press, "disabled": "normal"}
	for st in pics:
		b.add_theme_stylebox_override(st, _kit_box("shop/%s-%s" % [kind, pics[st]], [0, 0, 0, 0], SHOP_PAD[kind]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold)
	var colour = GOLD if sel else (INK if kind == "back" else DIM)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, colour)

## A plaque of temple stone, its gilded ends kept whole and only its middle stretched (border-image).
func _plaque(name: String, h: float, cap: float, mod: Color = Color.WHITE, inset: float = 0.6) -> StyleBoxTexture:
	var t: Texture2D = icons.get(name)
	var s = StyleBoxTexture.new()
	if t != null:
		var im = t.get_image()
		im.resize(roundi(im.get_width() * U), roundi(im.get_height() * U), Image.INTERPOLATE_NEAREST)
		s.texture = ImageTexture.create_from_image(im)
		s.texture_margin_left = a(cap)
		s.texture_margin_right = a(cap)
		s.texture_margin_top = a(h / 2)
		s.texture_margin_bottom = a(h / 2)
	s.modulate_color = mod
	s.content_margin_left = a(cap * inset)       # the text keeps off the gilded ends (the small ones are short)
	s.content_margin_right = a(cap * inset)
	s.content_margin_top = 0                     # the text lies over the plaque: its ends are not padding
	s.content_margin_bottom = 0
	return s

## The same box, drawn two art pixels lower, with what it holds (a pressed button).
func _down(sb: StyleBox) -> StyleBox:
	sb.expand_margin_top = -a(2)
	sb.expand_margin_bottom = a(2)
	sb.content_margin_top = maxf(sb.content_margin_top, 0) + a(4)
	return sb

func _styles() -> void:
	# The kit's buttons: four states of one plaque (slate; its teal hover state stands for what is chosen,
	# "gold" / "on": the kit has no gold or green). The text lies between the ends, as on the web.
	# "play": Jouer, a gold frame and taller; "go" / "stop": a green or red-orange plate (Reprendre,
	# Abandonner); "dark": a slate one in the shade (Histoire). Made by tools/make_ui_colours.py.
	for spec in [["", 38, ""], ["big", 50, ""], ["small", 30, ""], ["gold", 38, ""], ["small gold", 30, ""],
			["play", 58, "-gold"], ["go", 50, "-green"], ["stop", 38, "-red"], ["dark", 50, ""]]:
		var h: int = spec[1]
		var cap: int = _cap(h)
		var chosen: bool = (spec[0] as String).contains("gold")
		var pad = [cap * 0.8, cap * 0.8, 2 if _wood_ui() else 0, 0]   # (the wood's moss on top: the text a bit lower)
		var slice = [cap, cap, h / 2.0, h / 2.0]
		var c: String = spec[2]
		var shade = Color(0.72, 0.72, 0.8) if spec[0] == "dark" else Color.WHITE
		var lit = Color(0.86, 0.86, 0.92) if spec[0] == "dark" else (Color(1.1, 1.1, 1.1) if chosen else Color.WHITE)
		styles[spec[0]] = {
			"normal": _kit_box("btn-%s-%d%s" % ["hover" if chosen else "normal", h, c], slice, pad, shade),
			"hover": _kit_box("btn-hover-%d%s" % [h, c], slice, pad, lit),
			"pressed": _down(_kit_box("btn-pressed-%d%s" % [h, c], slice, pad, shade)),
			"disabled": _kit_box("btn-disabled-%d%s" % [h, c], slice, pad),
			"h": h,
			"cap": cap,
		}
	styles["box"] = _flat(BOX)
	styles["box-sel"] = _flat(Color("#2c3558"), GOLD)
	styles["box-down"] = _down(_flat(BOX.darkened(0.1)))
	styles["box-sel-down"] = _down(_flat(Color("#2c3558").darkened(0.1), GOLD))
	styles["pane"] = _flat(Color(24 / 255.0, 30 / 255.0, 54 / 255.0, 0.96))
	styles["pane"].set_content_margin_all(a(9))

# ---------- widgets ----------

func _label(text: String, size: int, colour: Color = INK, shadow: float = 2.0) -> Label:
	var l = Label.new()
	l.text = text
	var ls = LabelSettings.new()
	ls.font = bold if size >= ts("l") else font
	ls.font_size = size
	ls.font_color = colour
	if shadow > 0:
		ls.shadow_color = LINE
		ls.shadow_offset = Vector2(0, a(shadow))
		ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _set_colour(l: Label, colour: Color) -> void:
	l.label_settings.font_color = colour

## A button: "" (slate), "big" (green), "small", "gold" / "on" (gold), "plain", "danger", "square", "tab".
func _button(text: String, cls: String, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	_style_button(b, cls)
	var on_press = func() -> void:
		Audio.sfx("click")
		fn.call()
	b.pressed.connect(on_press)
	return b

func _style_button(b: Button, cls: String) -> void:
	var parts = cls.split(" ", false)
	var size = "small" if "small" in parts else ("big" if "big" in parts else "")
	var gold = "gold" in parts or "on" in parts
	var flat = "square" in parts or "tab" in parts
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold)
	if flat:
		var sel = "sel" in parts
		for st in ["normal", "hover", "disabled"]:
			b.add_theme_stylebox_override(st, styles["box-sel"] if sel else styles["box"])
		b.add_theme_stylebox_override("pressed", styles["box-sel-down"] if sel else styles["box-down"])
		b.add_theme_color_override("font_color", GOLD if sel else (INK if "square" in parts else DIM))
		b.add_theme_font_size_override("font_size", ts("s"))
		return
	var key = (size + " gold").strip_edges() if gold and size != "big" else size
	if not styles.has(key):
		key = size
	for special in ["play", "go", "stop", "dark"]:
		if special in parts:
			key = special
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, styles[key][st])
	b.custom_minimum_size = Vector2(a(30 + 2 * styles[key]["cap"]), a(styles[key]["h"]))
	var colour = Color("#fff3d6")
	if gold:
		colour = GOLD if "gold" in parts else Color.WHITE
	elif "plain" in parts:
		colour = DIM
	elif "danger" in parts:
		colour = Color("#ff8ea6")
	elif size == "big" or key in ["play", "go", "stop", "dark"]:
		colour = Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, colour)
	b.add_theme_color_override("font_disabled_color", colour.darkened(0.4))
	b.add_theme_color_override("font_outline_color", Color(10 / 255.0, 14 / 255.0, 34 / 255.0, 0.85))
	b.add_theme_constant_override("outline_size", roundi(a(1.5)))
	b.add_theme_font_size_override("font_size", ts("xl") if key == "play" else (ts("l") if size == "big" or key == "go" or key == "dark" else (ts("s") if size == "small" else ts("m"))))

func _icon_rect(tex: Texture2D, h: float) -> TextureRect:
	var r = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ratio = float(tex.get_width()) / tex.get_height() if tex != null else 1.0
	r.custom_minimum_size = Vector2(a(h) * ratio, a(h))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _box(cls: String = "box") -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", styles[cls])
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _vbox(gap: float) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(a(gap)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func _hbox(gap: float) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(a(gap)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	return h

## A bar to fill: `set_bar` sets how full it is.
## A bar to fill: the kit's bar-8 (levels, objectives) or bar-12 (volumes), its gem end and far end kept
## whole; the colour fills its trough. `set_bar` sets how full it is.
func _bar(width: float, height: float, colour: Color) -> Panel:
	var kh = 12 if height >= 10 else 8
	var m: Array = KIT_BAR[kh]
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", _kit_box("bar-%d" % kh, [m[0], m[1], 0, 0], [0, 0, 0, 0]))
	p.custom_minimum_size = Vector2(a(maxf(width, m[0] + m[1] + 4)), a(kh))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("ins", [a(m[4]), a(m[5])])
	var f = ColorRect.new()
	f.color = colour
	f.offset_left = a(m[4])
	f.offset_top = a(m[2])
	f.anchor_bottom = 1
	f.offset_bottom = -a(kh - m[3])
	f.offset_right = a(m[4])
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.name = "fill"
	p.add_child(f)
	return p

func set_bar(bar: Panel, k: float) -> void:
	var f: ColorRect = bar.get_node("fill")
	var ins: Array = bar.get_meta("ins", [a(1.5), a(1.5)])
	k = clampf(k, 0, 1)
	f.anchor_right = k
	f.offset_right = ins[0] - k * (ins[0] + ins[1])

func _place(c: Control, x: float, y: float, width: float = -1, height: float = -1) -> Control:
	c.position = Vector2(a(x), a(y))
	if width >= 0 or height >= 0:
		c.size = Vector2(a(width) if width >= 0 else c.size.x, a(height) if height >= 0 else c.size.y)
	return c

func _screen(name: String, dim: bool) -> Control:
	var s = Control.new()
	s.size = Vector2(W, H)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	if dim:
		var bg = ColorRect.new()
		bg.name = "bg"
		bg.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.6)
		bg.size = Vector2(W, H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_meta("still", true)
		s.add_child(bg)
	ui.add_child(s)
	screens[name] = s
	return s

func _head(s: Control, text: String) -> Label:
	var l = _label(text, ts("xl"), GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(l, 0, 13, 569, 30)
	s.add_child(l)
	return l

## What goes inside a panel of fixed size: if it were ever taller than the room, it scrolls (by a finger or
## the wheel) rather than make the panel grow, which would stretch its picture.
func _fixed(c: Control) -> ScrollContainer:
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	return sc

func _pane(s: Control, right: bool, height: float = 204) -> PanelContainer:
	var p = PanelContainer.new()
	var kit = ("pane-right" if right else "pane-left") if height <= 204 else ("settings-right" if right else "settings-left")
	p.add_theme_stylebox_override("panel", _kit_panel(kit))
	if right:
		_place(p, 569 - 14 - 265, 50, 265, height)
	else:
		_place(p, 14, 50, 262, height)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(p)
	return p

func _actions(s: Control, buttons: Array, min_w: float = 190) -> void:
	var row = _hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, a(min_w))
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(b)
	_place(row, 0, 320 - 8 - 50, 569, 50)
	s.add_child(row)

# ---------- the screens ----------

func _build() -> void:
	# the debug menu's strip: thin, red, above absolutely everything, while anything is changed there
	var top = CanvasLayer.new()
	top.layer = 100
	add_child(top)
	var strip = ColorRect.new()
	strip.color = Color("#e0203a")
	strip.size = Vector2(W, 16)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag = Label.new()
	tag.text = "D E B U G"
	tag.add_theme_font_override("font", ThemeDB.fallback_font)
	tag.add_theme_font_size_override("font_size", 12)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(W, 16)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(tag)
	top.add_child(strip)
	debug_layer = CanvasLayer.new()
	debug_layer.layer = 50
	add_child(debug_layer)
	Debug.strip = strip
	Debug.on_change = _debug_changed
	Debug.apply(false)                               # the strip as the kept settings say
	w["info"] = _label("", roundi(8 * U), Color.WHITE, 0)
	w["info"].z_index = 10
	_place(w["info"], 4, 320 - 16 - 12, 560, 12)
	ui.add_child(w["info"])
	w["fps"] = _label("", roundi(8 * U), Color.WHITE, 0)
	w["fps"].z_index = 10
	_place(w["fps"], 4, 320 - 4 - 12, 560, 12)
	ui.add_child(w["fps"])
	var fx = CanvasLayer.new()                       # confetti, over the screens
	fx.layer = 5
	add_child(fx)
	confetti_layer = Confetti.new()
	confetti_layer.size = Vector2(W, H)
	confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(confetti_layer)
	_build_screens()
	get_window().size_changed.connect(_on_resized)
	_web_setup()

## Every screen. Built again when the typeface changes (a setting) or the window's size does.
func _build_screens() -> void:
	_build_hud()
	_build_menu()
	_build_intro()
	_build_shop()
	_build_settings()
	_build_score("over")
	_build_score("pause")
	_build_tally()
	_build_friends()
	_build_race()
	var turn = _label("Tourne l'écran pour jouer en grand ↻", ts("m"), INK)   # a phone held upright
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(turn, 0, 74, 569, 20)
	turn.name = "turn"
	w["turn"] = turn
	ui.add_child(turn)
	_check_turn()

## Builds the screens again with the typeface and sizes of now, and puts back what was showing.
func _rebuild() -> void:
	rebuild_due = false
	_stop_over()
	for ch in get_children():                        # (0.55) the windows over the screens (a question, the list of
		if ch is CanvasLayer and ch.layer == 40:     # friends to invite, the Trésor) were sized for the old screen
			ch.queue_free()
	modal = null
	treasure = null
	urn_busy = false
	for k in screens:
		screens[k].queue_free()
	screens = {}
	if w.has("turn"):
		w["turn"].queue_free()
	title_letters = []
	_font()
	_styles()
	_build_screens()
	await get_tree().process_frame
	_aim_flyers()
	for k in screens:
		screens[k].visible = false
	if run != null:
		_fill_hud()
	match state:
		"menu": refresh_menu()
		"shop": refresh_shop()
		"settings": refresh_settings()
		"race": refresh_race()                       # (0.55: the Affrontement and Amis too, after a turn)
		"friends": refresh_friends()
	var name = "hud" if state == "play" else state
	if screens.has(name):
		show_screen(name)
	if state == "pause":
		pause_view()
	if state == "over":
		over_view(false)
		_quest_cards(w["over-quests"])
		w["over-shot"].scale = Vector2.ONE
	if state == "tally":
		tally_view()

func _on_resized() -> void:
	_check_turn()
	fit()                                            # (0.55) the game's picture for the new size at once
	if save["pixelFont"]:
		rebuild_due = true                       # soon, or at the next screen change: never in the middle of a run
		rebuild_t = 0.3

func _check_turn() -> void:
	if w.has("turn") and is_instance_valid(w["turn"]):
		var win = Vector2(get_window().size)
		w["turn"].visible = win.x < win.y * 0.75

func _fill_hud() -> void:
	hud_state = {"dist": -1, "gold": -1, "hearts": -1}
	var hearts: HBoxContainer = w["hud-hearts"]
	for ch in hearts.get_children():
		hearts.remove_child(ch)                      # (at once: queue_free alone left them among the children)
		ch.queue_free()
	for i in run.max_hearts:
		hearts.add_child(_icon_rect(icon("heart"), 20))
	hearts.visible = run.max_hearts > 1          # a single life needs no counter
	for k in ACTS:
		w["btn-" + k].visible = run.lvl(k) > 0
	w["btn-ball"].visible = run.lvl("sphere") > 0
	w["btn-pause"].visible = not run.coop            # (0.55) for two or more, no pause: the others run on
	w["btn-emote"].visible = run.coop and not run.race and not _emotes().is_empty()   # (0.58) words for two
	w["emote-row"].visible = false
	var kit: HBoxContainer = w["hud-kit"]
	for ch in kit.get_children():
		kit.remove_child(ch)
		ch.queue_free()
	if run.race:                                     # (0.55) the Affrontement: what everyone runs with
		for u in SaveData.UPGRADES:
			if run.lvl(u["id"]) > 0:
				kit.add_child(_icon_rect(icon("ico-" + u["icon"]), 16))
	w["hud-watch"].visible = run.spectating
	w["hud-res-btn"].visible = run.spectating
	w["hud-daily"].visible = run.daily
	w["hud-res"].visible = run.spectating and watch_res

func _build_hud() -> void:
	var s = _screen("hud", false)
	var top = _hbox(12)
	_place(top, M, 6, 569 - 2 * M, 36)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	var pill = _hbox(5)
	pill.add_child(_icon_rect(icon("coin-icon"), 20))
	w["hud-coins"] = _label("0", ts("l"), GOLD)
	pill.add_child(w["hud-coins"])
	top.add_child(pill)
	w["hud-dist"] = _label("0 m", ts("l"))
	top.add_child(w["hud-dist"])
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	w["hud-hearts"] = _hbox(3)
	top.add_child(w["hud-hearts"])
	var pause_b = _button("", "square", pause)
	_kit_square(pause_b, "blank", 36)
	var bars = func() -> void:                       # two upright bars, as on the web
		var down = a(2) if pause_b.button_pressed else 0.0
		for dx in [-a(4.5), a(2)]:
			pause_b.draw_rect(Rect2(pause_b.size.x / 2 + dx - a(1), pause_b.size.y / 2 - a(7.5) + down, a(5), a(15)), INK)
	pause_b.draw.connect(bars)
	w["btn-pause"] = pause_b
	top.add_child(pause_b)
	var emo_b = _button("!", "square", _emote_menu)  # (0.58) for two: words to say (the emotes owned)
	_kit_square(emo_b, "blank", 36)
	emo_b.add_theme_font_size_override("font_size", ts("l"))
	emo_b.visible = false
	w["btn-emote"] = emo_b
	top.add_child(emo_b)
	s.add_child(top)
	var emo_row = _vbox(3)                           # (its choices, under it, a few seconds)
	emo_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(emo_row, 569 - M - 130, 46, 130, 120)
	emo_row.visible = false
	w["emote-row"] = emo_row
	s.add_child(emo_row)
	w["hud-daily"] = _label("", ts("s"), GOLD, 1)    # (0.57) the Course du jour: the next tier
	_place(w["hud-daily"], M, 44, 300, 14)
	w["hud-daily"].visible = false
	s.add_child(w["hud-daily"])
	w["hud-kit"] = _hbox(3)                          # (0.55) the Affrontement: the items and powers on, top left
	_place(w["hud-kit"], M, 44, 300, 18)
	w["hud-kit"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(w["hud-kit"])
	var resb = _button("Résultats", "small", _toggle_watch_res)   # (0.57) watching: the results, shown or hidden
	_place(resb, 569 / 2.0 - 60, 76, 120, 24)
	resb.visible = false
	s.add_child(resb)
	w["hud-res-btn"] = resb
	var wres = PanelContainer.new()
	wres.add_theme_stylebox_override("panel", styles["box"])
	_place(wres, 569 / 2.0 - 220, 104, 440, 140)
	var wv = _vbox(3)
	var wtop = _hbox(6)
	w["hud-res-title"] = _label("", ts("s"), GOLD, 0)
	w["hud-res-title"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wtop.add_child(w["hud-res-title"])
	var back = _button("Retour au salon", "small", func() -> void:
		watch_res = false
		_race_over())
	back.custom_minimum_size = Vector2(a(110), a(20))
	wtop.add_child(back)
	w["hud-res-back"] = back
	wv.add_child(wtop)
	var wg = GridContainer.new()
	wg.columns = 6
	wg.add_theme_constant_override("h_separation", roundi(a(8)))
	wg.add_theme_constant_override("v_separation", roundi(a(2)))
	wv.add_child(wg)
	w["hud-res-grid"] = wg
	wres.add_child(wv)
	wres.visible = false
	s.add_child(wres)
	w["hud-res"] = wres
	w["hud-watch"] = _label("", ts("s"), GOLD, 1)     # (0.55) fallen: who I watch
	w["hud-watch"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(w["hud-watch"], 0, 60, 569, 14)
	w["hud-watch"].visible = false
	s.add_child(w["hud-watch"])
	w["toasts"] = _vbox(4)
	w["toasts"].set_meta("still", true)
	w["toasts"].alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(w["toasts"], 0, 38, 569, 120)
	s.add_child(w["toasts"])
	w["banner"] = _label("", ts("xl"), INK)
	w["banner"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["banner"].label_settings.outline_size = roundi(a(3))
	w["banner"].label_settings.outline_color = RELIC.darkened(0.5)
	_place(w["banner"], 0, 320 * 0.22, 569, 34)
	w["banner"].pivot_offset = Vector2(W / 2, a(17))
	w["banner"].modulate.a = 0
	w["banner"].set_meta("still", true)
	s.add_child(w["banner"])
	var say = PanelContainer.new()                   # Histoire: what the guards say, typed out, at the top
	say.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	say.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var say_col = _vbox(1)
	var who = _label("LES GARDES", ts("s"), RELIC, 0)  # who says it (reglages/dialogues.txt); Pépito in green
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	say_col.add_child(who)
	w["say-who"] = who
	w["say-text"] = _plain(_label("", ts("m"), INK, 0), "m")
	w["say-text"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["say-text"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["say-text"].custom_minimum_size.x = a(330)
	say_col.add_child(w["say-text"])
	w["say-more"] = _label("Touche pour continuer", ts("s"), DIM, 0)
	w["say-more"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	w["say-more"].modulate.a = 0
	say_col.add_child(w["say-more"])
	say.add_child(say_col)
	_place(say, 569 / 2.0 - 180, 46, 360, 44)
	say.visible = false
	say.set_meta("still", true)
	w["say"] = say
	s.add_child(say)
	w["hint"] = _label("", ts("l"))
	w["hint"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(w["hint"], 0, 320 * 0.76 - 20, 569, 24)
	w["hint"].pivot_offset = Vector2(W / 2, a(12))
	w["hint"].visible = false
	w["hint"].set_meta("still", true)
	s.add_child(w["hint"])
	var acts = _hbox(10)
	acts.alignment = BoxContainer.ALIGNMENT_END   # the ones not owned take no room
	for k in ACTS:
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, "square")
		b.custom_minimum_size = Vector2(a(52), a(52))
		b.icon = icon("ico-" + k)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", roundi(a(34)))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cool = Cooldown.new()
		cool.size = b.custom_minimum_size
		cool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cool)
		var on_down = func() -> void:
			_act(k)
		b.button_down.connect(on_down)
		acts.add_child(b)
		w["btn-" + k] = b
		w["cd-" + k] = cool
	var bb = Button.new()                               # (0.65) the Sphère's mode: Normal / Sphère, no wait
	bb.focus_mode = Control.FOCUS_NONE
	_style_button(bb, "square")
	bb.custom_minimum_size = Vector2(a(52), a(52))
	bb.icon = icon("ico-sphere")
	bb.expand_icon = true
	bb.add_theme_constant_override("icon_max_width", roundi(a(34)))
	bb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.button_down.connect(func() -> void: input.ball = true)
	acts.add_child(bb)
	acts.move_child(bb, 0)
	w["btn-ball"] = bb
	_place(acts, 569 - 12 - 360, 320 - 12 - 52, 360, 52)       # room for the five (three at most are equipped) and the Sphère
	s.add_child(acts)
	# 0.47: caught by the pygmies: the Couteau suisse offered, then the escape (a cursor, a zone, the ropes).
	# (0.68) The knife big, its countdown round it: touched, the escape; each rope cut pops with a sound, and
	# freed, a fanfare (EscapeView draws both phases).
	var esc = PanelContainer.new()
	esc.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	esc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ec = _vbox(2)
	ec.alignment = BoxContainer.ALIGNMENT_CENTER
	w["esc-label"] = _label("", ts("m"), INK, 0)
	w["esc-label"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec.add_child(w["esc-label"])
	var ev = EscapeView.new()
	ev.custom_minimum_size = Vector2(a(276), a(104))
	ev.knife = icon("ico-knife")
	ev.digits = bold
	ev.digits_size = ts("xl")
	ev.u = U
	ev.mouse_filter = Control.MOUSE_FILTER_STOP
	ev.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			if ev.on_knife(e.position):
				_use_knife())
	ec.add_child(ev)
	w["esc-bar"] = ev
	w["esc-hint"] = _label("", ts("s"), DIM, 0)
	w["esc-hint"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec.add_child(w["esc-hint"])
	esc.add_child(ec)
	_place(esc, 569 / 2.0 - 150, 22, 300, 156)
	esc.visible = false
	s.add_child(esc)
	w["esc"] = esc

## Paper falling over the screens: a buy (14 pieces), a record (60).
func confetti(count: int) -> void:
	confetti_layer.add(count)

class Confetti extends Control:
	const COLOURS := [Color("#ffd35c"), Color("#5cf2e0"), Color("#e0456b"), Color("#7bd13c"), Color("#fff8e6")]
	var bits: Array = []
	func add(count: int) -> void:
		for i in count:
			bits.append({"x": randf() * size.x, "c": COLOURS[randi() % COLOURS.size()], "dur": 1.4 + randf() * 1.6, "t": -randf() * 0.5, "spin": randf() * TAU})
	func _process(delta: float) -> void:
		if bits.is_empty():
			return
		for b in bits:
			b["t"] += delta
		bits = bits.filter(func(b): return b["t"] < b["dur"])
		queue_redraw()
	func _draw() -> void:
		var u = size.y / 320.0
		for b in bits:
			if b["t"] < 0:
				continue
			var k = b["t"] / b["dur"]
			draw_set_transform(Vector2(b["x"], -0.06 * size.y + k * 360 * u), b["spin"] + k * 4 * PI, Vector2.ONE)
			draw_rect(Rect2(-2.5 * u, -4 * u, 5 * u, 8 * u), b["c"])
		draw_set_transform(Vector2.ZERO)

## The shade sweeping round an active's button while it charges (conic-gradient in the web version).
## (0.68) The escape, drawn: offered, the Couteau suisse big in a ring that empties with the seconds left (the
## number beside it), a touch on it and the escape begins; then the bar (0.47: the zone in green, the cursor in
## gold going to and fro, as Game keeps them), the ropes as big dots under it, the seconds left beside it. A rope
## cut: its dot pops (a ring, rays, the knife slashing over it); a miss: the bar shakes, red. Freed: every dot
## gold, a burst, for a moment.
class EscapeView extends Control:
	var e: Dictionary = {}                       # the escape (Game's), or empty while offered
	var phase := ""                              # offer, escape, free
	var left := 0.0                              # seconds left
	var full := 1.0
	var knife: Texture2D
	var digits: Font
	var digits_size := 26
	var u := 1.0
	var t := 0.0
	var pops: Array = []                         # {i, t}: a rope cut
	var miss_t := -1.0
	var free_t := -1.0
	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		t += delta
		for q in pops:
			q["t"] += delta
		pops = pops.filter(func(q): return q["t"] < 0.6)
		if miss_t >= 0:
			miss_t += delta
			if miss_t > 0.35:
				miss_t = -1.0
		if free_t >= 0:
			free_t += delta
		queue_redraw()
	func pop(i: int) -> void:
		pops.append({"i": i, "t": 0.0})
	func miss() -> void:
		miss_t = 0.0
	func freed() -> void:
		free_t = 0.0
		phase = "free"
	func _dial_c() -> Vector2:
		return Vector2(size.x / 2 - 22 * u, size.y / 2)
	func on_knife(pos: Vector2) -> bool:
		return phase == "offer" and pos.distance_to(_dial_c()) < 50 * u
	func _num(at: Vector2, text: String, col: Color) -> void:
		if digits == null:
			return
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(0, 3)]:
			draw_string(digits, at + o * u * 0.6, text, HORIZONTAL_ALIGNMENT_LEFT, -1, digits_size, Color("#1a1024"))
		draw_string(digits, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, digits_size, col)
	func _draw() -> void:
		var ink = Color("#1a1024")
		var gold = Color("#ffd35c")
		var red = Color("#ff5a6e")
		var k = clampf(left / maxf(full, 0.01), 0.0, 1.0)
		var hurry = left < 2.0
		if phase == "offer":
			var c = _dial_c()
			var r = 40.0 * u
			var beat = 1.0 + (0.07 if hurry else 0.04) * sin(t * (14.0 if hurry else 7.0))
			draw_circle(c, r + 6 * u, ink)
			draw_circle(c, r, Color("#3b2a1c"))
			draw_arc(c, r - 1 * u, 0, TAU, 48, Color(1, 1, 1, 0.1), 5 * u)
			if k > 0:
				draw_arc(c, r - 1 * u, -PI / 2, -PI / 2 + TAU * k, 48, red if hurry else gold, 5 * u)
			var glow = 0.25 + 0.15 * sin(t * 6)
			draw_circle(c, r * 0.72, Color(1, 0.83, 0.36, glow * 0.35))
			if knife != null:
				var ks = 56.0 * u / maxf(knife.get_width(), knife.get_height()) * beat
				var kw = knife.get_width() * ks
				var kh = knife.get_height() * ks
				draw_set_transform(c, -0.25 + 0.06 * sin(t * 3), Vector2.ONE)
				draw_texture_rect(knife, Rect2(-kw / 2, -kh / 2, kw, kh), false)
				draw_set_transform(Vector2.ZERO)
			_num(Vector2(c.x + r + 16 * u, c.y + 12 * u), str(ceili(left)), red if hurry else gold)
			return
		# the bar, the ropes, the seconds
		var W_ = 216.0 * u
		var H_ = 26.0 * u
		var x0 = 4.0 * u
		var y0 = 10.0 * u
		if miss_t >= 0:
			x0 += sin(miss_t * 70) * 5 * u * (1 - miss_t / 0.35)
		draw_rect(Rect2(x0 - 2 * u, y0 - 2 * u, W_ + 4 * u, H_ + 4 * u), ink)
		draw_rect(Rect2(x0, y0, W_, H_), Color("#3b2a1c"))
		if not e.is_empty():
			var zw: float = e["w"] * W_
			var zx: float = x0 + e["zone"] * W_ - zw / 2
			draw_rect(Rect2(zx, y0, zw, H_), Color("#6cc22e"))
			draw_rect(Rect2(zx, y0, zw, 3 * u), Color("#a8f060"))
			if phase == "escape":
				var cx: float = x0 + e["cur"] * W_
				draw_rect(Rect2(cx - 3 * u, y0 - 4 * u, 6 * u, H_ + 8 * u), ink)
				draw_rect(Rect2(cx - 1.5 * u, y0 - 3 * u, 3 * u, H_ + 6 * u), gold)
		if miss_t >= 0:
			draw_rect(Rect2(x0, y0, W_, H_), Color(1, 0.2, 0.25, 0.5 * (1 - miss_t / 0.35)))
		var n = int(e.get("ropes", 3)) if not e.is_empty() else 3
		var cut_n = n if phase == "free" else (n - int(e.get("rope", n)) if not e.is_empty() else 0)
		var r = 11.0 * u
		var dy = y0 + H_ + 26 * u
		for i in n:
			var c = Vector2(x0 + W_ / 2 + (i - (n - 1) / 2.0) * r * 3.4, dy)
			var cut = i < cut_n
			var grow = 1.0
			for q in pops:
				if q["i"] == i:
					var pk = q["t"] / 0.6
					grow = 1.0 + 0.8 * sin(PI * minf(1.0, pk * 1.6)) * (1 - pk)
					draw_arc(c, r * (1.0 + 2.4 * pk), 0, TAU, 32, Color(1, 0.9, 0.4, 1 - pk), 3 * u)
					for ray in 8:
						var ang = ray * TAU / 8 + 0.3
						var d0 = r * (1.3 + 1.6 * pk)
						draw_line(c + Vector2(cos(ang), sin(ang)) * d0, c + Vector2(cos(ang), sin(ang)) * (d0 + 7 * u * (1 - pk)), Color(1, 0.95, 0.6, 1 - pk), 2 * u)
					if knife != null and pk < 0.5:   # the knife slashing over the rope
						var ks = 26.0 * u / knife.get_width()
						draw_set_transform(c + Vector2(0, -r * 1.6), lerpf(-1.1, 0.9, pk * 2), Vector2(ks, ks))
						draw_texture(knife, Vector2(-knife.get_width() / 2.0, -knife.get_height() / 2.0), Color(1, 1, 1, 1 - pk * 2))
						draw_set_transform(Vector2.ZERO)
			draw_circle(c, (r + 3 * u) * grow, ink)
			draw_circle(c, r * grow, gold if cut else Color("#2a2030"))
			if cut:                                  # a tick in it
				var s_ = r * grow * 0.5
				draw_polyline(PackedVector2Array([c + Vector2(-s_, 0), c + Vector2(-s_ * 0.2, s_ * 0.7), c + Vector2(s_, -s_ * 0.6)]), ink, 2.5 * u)
		if phase == "free":
			var fk = clampf(free_t / 0.7, 0, 1)
			draw_arc(Vector2(x0 + W_ / 2, dy), 30 * u + 120 * u * fk, 0, TAU, 48, Color(1, 0.85, 0.35, 1 - fk), 4 * u)
		else:
			_num(Vector2(x0 + W_ + 14 * u, y0 + H_ + 4 * u), str(ceili(left)), red if hurry else gold)

class Cooldown extends Control:
	var k := 0.0
	func _draw() -> void:
		if k <= 0:
			return
		var c = size / 2
		var r = size.length() / 2
		var pts = PackedVector2Array([c])
		var steps = maxi(2, ceili(32 * k))
		for i in steps + 1:
			var ang = -PI / 2 + TAU * k * i / steps
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		# clipped to the button: the points are pulled back inside its rectangle
		for i in pts.size():
			pts[i] = Vector2(clampf(pts[i].x, 0, size.x), clampf(pts[i].y, 0, size.y))
		draw_colored_polygon(pts, Color(10 / 255.0, 6 / 255.0, 24 / 255.0, 0.78))

func _build_menu() -> void:
	# 0.50, home B3: on the left Réglages, Amis and Trésor (0.55: no Tambours), on the right Améliorations, Skins and
	# Défis, each with its name under it; JOUER at the bottom in the middle, whose list of modes unrolls
	# upwards (Histoire, Sans fin, and Affrontement when a group is there). What a button opens comes from
	# its side of the screen (go_from, _slide).
	var s = _screen("menu", false)
	var left = _vbox(3)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(left, M - 6, M, 48, 210)
	var gear = _home_square("gear", "", 0, "RÉGLAGES", func() -> void: go_from("settings", "left"))
	left.add_child(gear)
	w["menu-upd"] = _home_dot(gear.get_meta("button"), "!", 25)    # a newer version online (Réglages → Mettre à jour)
	w["menu-upd"].visible = _update_ready()
	var pals = _home_square("blank", "ico-friends", 26, "AMIS", func() -> void: go_from("friends", "left"))
	pals.visible = Net.enabled()                     # only once a server is set (reglages/reseau.txt)
	left.add_child(pals)
	w["menu-friends"] = pals
	var urnb = _home_square("blank", "ico-urn", 20, "TRÉSOR", _treasure)   # 0.47: the urns, the bag
	left.add_child(urnb)
	w["menu-urnb"] = urnb.get_meta("button")
	w["menu-urns"] = _home_dot(urnb.get_meta("button"), "0", 23)          # a gold count when urns wait
	w["menu-urns-n"] = w["menu-urns"].get_child(0)
	w["menu-urns"].visible = false
	s.add_child(left)
	# the stone plaque of the title, its letters hopping one after the other
	var plaque = TextureRect.new()
	plaque.texture = icon("ui-title")
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_SCALE
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(plaque, 159.5, 4, 250, 68)
	s.add_child(plaque)
	var letters = _hbox(0)
	letters.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(letters, 159.5, 4, 250, 63)
	var i = 0
	for ch in "Jungle Loop":
		var l = _label(ch, roundi(29 * fk * U), Color("#ffe9a0") if i % 2 == 0 else GOLD, 0)
		l.label_settings.shadow_color = Color("#b8801c")
		l.label_settings.shadow_offset = Vector2(0, a(2))
		l.label_settings.outline_size = roundi(a(1.5))
		l.label_settings.outline_color = LINE
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		letters.add_child(l)
		title_letters.append(l)
		i += 1
	s.add_child(letters)
	var status = _vbox(4)
	status.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(status, 569 - M - 200, M, 200, 54)
	w["menu-level"] = _level_box(false)
	w["menu-level"].mouse_filter = Control.MOUSE_FILTER_STOP
	w["menu-level"].gui_input.connect(_on_level_input)
	w["menu-level"].size_flags_horizontal = Control.SIZE_SHRINK_END
	status.add_child(w["menu-level"])
	w["menu-coins"] = _coins_pill()
	w["menu-coins"].size_flags_horizontal = Control.SIZE_SHRINK_END
	status.add_child(w["menu-coins"])
	s.add_child(status)
	var right = _vbox(3)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(right, 569 - M - 84 + 4, 66, 84, 170)
	var on_up = func() -> void:
		tab = "up"
		go_from("shop", "right")
	right.add_child(_home_square("blank", "coin-icon", 16, "AMÉLIORATIONS", on_up, true))
	var on_skins = func() -> void:
		tab = "skin"
		go_from("shop", "right")
	right.add_child(_home_square("blank", "ico-star", 22, "SKINS", on_skins, true))
	var quests_sq = _home_square("blank", "ico-target", 22, "DÉFIS", func() -> void: _home_quests(not w["menu-quests-box"].visible), true)
	right.add_child(quests_sq)
	w["menu-quests-btn"] = quests_sq.get_meta("button")
	s.add_child(right)
	var band = _box()                                # for two: with whom, and leaving
	var band_row = _hbox(4)
	w["menu-coop-text"] = _plain(_label("", ts("s"), GOLD, 0), "s")
	w["menu-coop-text"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["menu-coop-text"].clip_text = true
	w["menu-coop-text"].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band_row.add_child(w["menu-coop-text"])
	var quit_two = _button("Quitter", "tab", func() -> void: coop.leave())
	quit_two.custom_minimum_size = Vector2(a(62), a(18))
	quit_two.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band_row.add_child(quit_two)
	band.add_child(band_row)
	band.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(band, 569 / 2.0 - 118, 76, 236, 26)
	band.visible = false
	w["menu-coop"] = band
	s.add_child(band)
	# Défis: the objectives, in a panel that comes in from the right edge
	var qbox = PanelContainer.new()
	qbox.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	qbox.mouse_filter = Control.MOUSE_FILTER_STOP
	qbox.set_meta("still", true)
	qbox.z_index = 5
	var qcol = _vbox(4)
	var qtitle = _label("DÉFIS", ts("m"), GOLD, 1.5)
	qtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qcol.add_child(qtitle)
	w["menu-quests"] = _vbox(4)
	w["menu-quests"].custom_minimum_size.x = a(250)
	qcol.add_child(w["menu-quests"])
	qbox.add_child(qcol)
	_place(qbox, 569 - M - 84 - 302, 66, 300, 60)
	qbox.set_meta("home_rest", qbox.position)
	qbox.visible = false
	w["menu-quests-box"] = qbox
	s.add_child(qbox)
	# JOUER and its list of modes, which unrolls from behind it (top to bottom: Histoire, Sans fin, Affrontement)
	var modes = Control.new()
	modes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modes.set_meta("still", true)
	modes.size = Vector2(W, H)
	modes.z_index = 3
	for spec in [["story", "ico-relic", "HISTOIRE"], ["endless", "ico-leap", "SANS FIN"], ["daily", "ico-urn", "COURSE DU JOUR"], ["race", "ico-friends", "AFFRONTEMENT"], ["quick", "ico-friends", "PARTIE RAPIDE"]]:
		var mode: String = spec[0]
		var on_mode = func() -> void:
			if tip_held:
				tip_held = false                             # (it was held to read its panel)
				return
			_pick_mode(mode)
		var sub = _note("", DIM)
		var b = _row(icon(spec[1]), spec[2], sub, false, 0, on_mode)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.visible = false
		b.set_meta("mode", mode)
		b.set_meta("sub", sub)
		if mode != "race" and mode != "daily" and mode != "quick":
			_menu_tip_on(b, mode)
		modes.add_child(b)
		w["menu-go-" + mode] = b
	s.add_child(modes)
	w["menu-modes"] = modes
	var play = _button("Jouer", "play", func() -> void: _home_modes(not w["menu-modes"].get_meta("open", false)))
	play.custom_minimum_size = Vector2(a(168), a(58))
	_place(play, 569 / 2.0 - 84, 320 - M - 58, 168, 58)
	w["menu-play"] = play
	s.add_child(play)
	w["menu-tip"] = PanelContainer.new()            # what a mode is about: hovered, or held down
	w["menu-tip"].add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	w["menu-tip"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	w["menu-tip"].visible = false
	w["menu-tip"].set_meta("still", true)
	w["menu-tip"].z_index = 6
	var tip_l = _label("", ts("s"), INK, 0)
	tip_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_l.custom_minimum_size.x = a(260)
	w["menu-tip"].add_child(tip_l)
	w["menu-tip-text"] = tip_l
	_place(w["menu-tip"], 569 / 2.0 - 150, 90, 300, 60)
	s.add_child(w["menu-tip"])
	w["menu-info"] = PanelContainer.new()
	w["menu-info"].add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	w["menu-info"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(w["menu-info"], 569 / 2.0 - 150, 320 - M - 58 - 6 - 110, 300, 110)
	w["menu-info"].visible = false
	w["menu-info"].set_meta("still", true)
	w["menu-info"].z_index = 4
	s.add_child(w["menu-info"])
	# (0.57) two small panels in the bottom corners: the items equipped (left), the group (right, only when
	# there is one)
	var gbox = PanelContainer.new()
	gbox.add_theme_stylebox_override("panel", _home_panel(150))   # (0.68) a plaque of their own (PixelLab)
	gbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gcol = _vbox(1)
	var gt = _label("TON GROUPE", ts("s"), RELIC, 0)
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gcol.add_child(gt)
	w["menu-group"] = _hbox(4)
	w["menu-group"].alignment = BoxContainer.ALIGNMENT_CENTER
	w["menu-group"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	gcol.add_child(w["menu-group"])
	gbox.add_child(gcol)
	_place(gbox, 569 - M - 150, 320 - M - 58, 150, 58)
	gbox.visible = false
	s.add_child(gbox)
	w["menu-group-box"] = gbox
	var lbox = PanelContainer.new()
	lbox.add_theme_stylebox_override("panel", _home_panel(126))
	lbox.mouse_filter = Control.MOUSE_FILTER_PASS
	var lcol = _vbox(1)
	var lt = _label("ÉQUIPEMENT", ts("s"), RELIC, 0)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcol.add_child(lt)
	w["menu-loadout"] = _hbox(2)                     # what goes on the next run
	w["menu-loadout"].alignment = BoxContainer.ALIGNMENT_CENTER   # one or two items stay in the middle
	lcol.add_child(w["menu-loadout"])
	lbox.add_child(lcol)
	_place(lbox, M, 320 - M - 58, 126, 58)
	s.add_child(lbox)
	w["menu-loadout-box"] = lbox
	var version = _label("v" + VERSION, roundi(7 * U), DIM, 1)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # (0.57: under JOUER, the corners have panels)
	version.modulate.a = 0.75
	_place(version, 569 / 2.0 - 60, 320 - 9, 120, 9)
	s.add_child(version)

## (0.68) The home screen's corner panels: their own plaque at its exact size (tools/make_home_panels.py), the
## content inside its frame; without the picture, the plain box.
func _home_panel(width: int) -> StyleBox:
	var tex = icon("ui-v2/wood/panel-%d" % width)
	if tex == null:
		return styles["box"]
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_left = a(17)
	sb.content_margin_right = a(17)
	sb.content_margin_top = a(9)
	sb.content_margin_bottom = a(6)
	return sb

## A square of the home screen with its name under it: `kit` the kit's square (gear, or blank with `ico`).
## Its button is the column's meta "button" (for the dots, the bench).
func _home_square(kit: String, ico: String, ico_w: float, caption: String, fn: Callable, at_right: bool = false) -> VBoxContainer:
	var col = _vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	_kit_square(b, kit, 36)
	if ico != "":
		b.icon = icon(ico)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", roundi(a(ico_w)))
	b.size_flags_horizontal = Control.SIZE_SHRINK_END if at_right else Control.SIZE_SHRINK_CENTER
	var on_press = func() -> void:
		Audio.sfx("click")
		if not (b == w.get("menu-quests-btn")):
			_home_close()
		fn.call()
	b.pressed.connect(on_press)
	col.add_child(b)
	var l = _label(caption, roundi(7.5 * fk * U), INK, 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if at_right else HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	col.set_meta("button", b)
	return col

## A gold dot over a home square's corner: "!" or a count.
func _home_dot(b: Button, text: String, x: float) -> PanelContainer:
	var dot = PanelContainer.new()
	var sb = _flat(GOLD, LINE, 1.0)
	sb.set_corner_radius_all(roundi(a(8)))
	sb.content_margin_left = a(3)
	sb.content_margin_right = a(3)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = _label(text, ts("s") if text != "!" else ts("m"), LINE, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(l)
	dot.position = Vector2(a(x), -a(5))
	dot.size = Vector2(a(16), a(16))
	b.add_child(dot)
	return dot

## The list of modes: open, each mode rises from behind JOUER to its place, Histoire first; closed, they
## go back behind it, the last first. Affrontement only when a race has two players or more.
func _home_modes(open: bool) -> void:
	var modes: Control = w["menu-modes"]
	if open == modes.get_meta("open", false):
		return
	modes.set_meta("open", open)
	if open:
		_home_quests(false)
		w["menu-info"].visible = false
		_mark_slots("")
		_mode_texts()
	var from_y = a(320 - M - 58 + 6)                 # behind JOUER
	for b in modes.get_children():
		if b.has_meta("tw"):
			(b.get_meta("tw") as Tween).kill()
	if open:
		var listed: Array = modes.get_children().filter(func(b): return b.get_meta("mode") not in ["race", "quick"] or (Net.enabled() and Coop.supported()))
		for b in modes.get_children():
			if not b in listed:
				b.visible = false
		for idx in range(listed.size()):
			var b: Button = listed[idx]
			var rest_y = a(320 - M - 58 - 6) - (listed.size() - idx) * a(30 + 4)
			b.position = Vector2(a(569 / 2.0 - 118), from_y)
			b.modulate.a = 0.0
			b.visible = true
			var tw = create_tween()
			b.set_meta("tw", tw)
			tw.tween_interval(idx * 0.07)
			tw.tween_property(b, "position:y", rest_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(b, "modulate:a", 1.0, 0.18)
	else:
		var shown: Array = modes.get_children().filter(func(b): return b.visible)
		for k in range(shown.size()):
			var b: Button = shown[k]
			var tw = create_tween()
			b.set_meta("tw", tw)
			tw.tween_interval((shown.size() - 1 - k) * 0.05)
			tw.tween_property(b, "position:y", from_y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(b, "modulate:a", 0.0, 0.22)
			tw.tween_callback(func() -> void: b.visible = false)
		_menu_tip("")

## The words beside each mode: where Histoire stands, the record, the group.
func _mode_texts() -> void:
	if not w.has("menu-modes"):
		return
	var subs = {
		"story": "%d/4 MORCEAUX · %d VIES" % [int(save["relic"]) + 1, Game.STORY_HEARTS],   # (0.53: the jaw, stolen, counts)
		"endless": "RECORD %d M" % best_of("endless"),
		"race": ("TON GROUPE · %d/4" % race.count()) if race.role != "" else "CRÉE TON GROUPE",
		"daily": "PALIERS %d/4 · %s" % [Daily.won(save), str(Daily.of_day()["rule"]["name"]).to_upper()],
		"quick": "CONTRE D'AUTRES JOUEURS",
	}
	for b in w["menu-modes"].get_children():
		(b.get_meta("sub") as Label).text = subs[b.get_meta("mode")]

## 0.55, the home screen: the group's players (their look, their name, ready or not) right of JOUER.
func _fill_group() -> void:
	if not w.has("menu-group") or not is_instance_valid(w["menu-group"]):
		return
	var box: HBoxContainer = w["menu-group"]
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	w["menu-group-box"].visible = race.role != "" and race.count() > 0   # (0.57: its panel, only with a group)
	var order = race.seats.keys()
	order.sort()
	for k in order:
		var seat: Dictionary = race.seats[k]
		var col = _vbox(0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var av = TextureRect.new()
		av.texture = _look(str(seat.get("skin", "")))
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		av.custom_minimum_size = Vector2(a(20), a(26))
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.modulate = Color(1, 1, 1, 0.5) if seat.get("away", false) else Color.WHITE
		col.add_child(av)
		var nm = _plain(_label(("Toi" if k == race.me else str(seat.get("name", "?"))).left(7), ts("s"), Race.COLOURS[k % Race.COLOURS.size()], 1), "s")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size.x = a(34)
		col.add_child(nm)
		box.add_child(col)

## A race whose lobby has two players or more: Affrontement is offered.
func _race_ready() -> bool:
	return race != null and race.state == "lobby" and not race.running and race.count() >= 2

## A mode picked in the list: for two the host starts it for both; Affrontement is the race of the group.
func _pick_mode(mode: String) -> void:
	_home_modes(false)
	if mode == "quick":                              # (0.66) strangers, in a race
		_race_quick()
		return
	if mode == "race":                               # 0.51: the group's room first, where the bets are made
		race_seen = true
		if race.role == "":                          # (0.55) no group yet: one is made, its screen shows
			quick_on = false
			_race_host()
		else:
			go("race")
		return
	if mode == "daily":                              # (0.57) the Course du jour: its rule, items and tiers first
		_daily_panel()
		return
	daily_on = false
	if coop.state == "ready":                        # linked for two: the host starts it for both
		if coop.role == "host":
			_coop_go(mode)
		else:
			_coop_say("C'est %s qui lance." % _mate_name())
		return
	save["mode"] = mode                              # Histoire or Sans fin: « Rejouer » keeps it
	SaveData.store(save)
	go("play")

## (0.57) The Course du jour's window: the day, its rule, the items it imposes, its tiers (won today: ticked)
## and today's best; « Courir » starts it (« Rejouer » at the end starts it again).
func _daily_panel() -> void:
	var d = Daily.of_day()
	var st = Daily.state(save)
	if modal != null:
		modal.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	modal = layer
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.75)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_panel("shop-preview-wide", 3))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 215, 12, 430, 296)
	var col = _vbox(5)
	var parts = str(d["day"]).split("-")
	var title = _label("COURSE DU JOUR · %s/%s" % [parts[2], parts[1]] if parts.size() == 3 else "COURSE DU JOUR", ts("l"), GOLD, 1.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var rule: Dictionary = d["rule"]
	var rl = _label("RÈGLE DU JOUR : %s" % str(rule["name"]).to_upper(), ts("s"), RELIC, 0)
	col.add_child(rl)
	col.add_child(_wrap(str(rule["desc"]) + " La même route pour tous aujourd'hui ; rejoue-la autant que tu veux.", INK))
	col.add_child(_label("ÉQUIPEMENT IMPOSÉ", ts("s"), RELIC, 0))
	var kit = _hbox(8)
	for id in d["kit"]:
		var u = SaveData.upgrade(id)
		if u.is_empty():
			continue
		var it = _hbox(3)
		it.add_child(_icon_rect(icon("ico-" + u["icon"]), 16))
		it.add_child(_label("%s %d" % [u["name"], int(d["kit"][id])], ts("s"), INK, 0))
		kit.add_child(it)
	col.add_child(kit)
	col.add_child(_label("PALIERS (chacun une fois par jour ; l'Or donne aussi le Bronze et l'Argent)", ts("s"), RELIC, 0))
	var tl = GridContainer.new()
	tl.columns = 4
	tl.add_theme_constant_override("h_separation", roundi(a(12)))
	tl.add_theme_constant_override("v_separation", roundi(a(2)))
	for i in 4:
		var got: bool = st["got"][i]
		var colr = Color("#9dff7a") if got else Color(Daily.TIER_COLOURS[i])
		tl.add_child(_label(Daily.TIER_NAMES[i].to_upper(), ts("s"), colr, 0))
		tl.add_child(_label("%d m" % int(d["tiers"][i]), ts("s"), INK if not got else DIM, 0))
		tl.add_child(_label(Daily.reward_text(i), ts("s"), GOLD if not got else DIM, 0))
		tl.add_child(_label("gagné" if got else "", ts("s"), colr, 0))
	col.add_child(tl)
	var gift = Skins.skin(str(d.get("gift", "")))
	var more: Array = []
	if not gift.is_empty():
		more.append("Objet du jour : %s · %s%s" % [Skins.TARGETS[gift["target"]]["name"], gift["name"], " (déjà à toi : des pièces)" if gift["id"] in save["skins"]["owned"] else ""])
	more.append("L'Or cette semaine : %d / %d jours (une urne %s)" % [st["golds"].size(), int(Daily.week["days"]), Treasure.NAMES[str(Daily.week["urn"])].to_lower()])
	if int(st["best"]) > 0:
		more.append("Ton meilleur aujourd'hui : %d m" % int(st["best"]))
	col.add_child(_wrap("\n".join(more), DIM))
	var row = _hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close = func() -> void:
		layer.queue_free()
		modal = null
	row.add_child(_button("Fermer", "small plain", close))
	var go_b = _button("Courir", "small gold", func() -> void:
		close.call()
		daily_on = true
		go("play"))
	go_b.custom_minimum_size.x = a(110)
	row.add_child(go_b)
	col.add_child(row)
	p.add_child(col)
	root.add_child(p)
	Audio.sfx("click")

## The objectives' panel, in from the right edge or back out.
func _home_quests(open: bool) -> void:
	if not w.has("menu-quests-box"):
		return
	var box: Control = w["menu-quests-box"]
	if open:
		_home_modes(false)
		w["menu-info"].visible = false
		_mark_slots("")
	_slide(box, open, "right")

## A panel of the home screen (or a window) brought in from `side`, or sent back there and hidden.
func _slide(p: Control, open: bool, side: String) -> void:
	if not p.has_meta("home_rest"):
		p.set_meta("home_rest", p.position)
	var rest: Vector2 = p.get_meta("home_rest")
	var away = _away_of(side)
	if not open and not p.visible:
		return
	if p.has_meta("tw"):
		(p.get_meta("tw") as Tween).kill()
	var tw = create_tween()
	p.set_meta("tw", tw)
	if open:
		if not p.visible:
			p.position = rest + away
		p.visible = true
		tw.tween_property(p, "position", rest, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(p, "position", rest + away, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: p.visible = false)

func _away_of(side: String) -> Vector2:
	return {"left": Vector2(-a(580), 0), "right": Vector2(a(580), 0), "top": Vector2(0, -a(330)), "bottom": Vector2(0, a(330))}.get(side, Vector2(0, a(330)))

## The list of modes and the objectives put away (another button pressed, the screen left).
func _home_close() -> void:
	if w.has("menu-modes") and is_instance_valid(w["menu-modes"]):
		_home_modes(false)
	if w.has("menu-quests-box") and is_instance_valid(w["menu-quests-box"]):
		_home_quests(false)

## Opens a screen whose blocks all come from `side` (the side of the button that opens it).
func go_from(name: String, side: String) -> void:
	fly_side = side
	go(name)

## The panel of a home screen button: shown while the pointer is over it, or once it has been held
## down a moment (a finger): then letting go launches nothing.
func _menu_tip_on(b: Button, which: String) -> void:
	b.set_meta("tip", MENU_TIPS.get(which, ""))
	b.mouse_entered.connect(func() -> void: _menu_tip(b.get_meta("tip"), b))
	b.mouse_exited.connect(func() -> void: _menu_tip(""))
	var on_down = func() -> void:
		held = b
		held_t = time
		tip_held = false
	b.button_down.connect(on_down)
	var on_up = func() -> void:
		if held == b:
			held = null
	b.button_up.connect(on_up)

func _menu_tip(text: String, b: Button = null) -> void:
	if not w.has("menu-tip") or not is_instance_valid(w["menu-tip"]):
		return
	var tip: PanelContainer = w["menu-tip"]
	tip.visible = text != "" and state == "menu"
	if not tip.visible:
		return
	w["menu-tip-text"].text = text
	tip.reset_size()
	if b != null:                                    # above the list of modes (0.50)
		var top = b.position.y
		for mb in w["menu-modes"].get_children():
			if mb.visible:
				top = minf(top, mb.position.y)
		tip.position = Vector2(a(569 / 2.0) - tip.size.x / 2, top - tip.size.y - a(4))

## Where the next Run illimitée starts: any of the four sceneries. The home screen shows it already,
## the temple standing in it.
func _roll_biome() -> void:
	endless_biome = [0, 2, 3][randi() % 3]        # (0.53: never the heights first: the run starts out of the temple, on foot)
	if still != null:
		still.biome = endless_biome
		still.prev_biome = endless_biome
		still.home_scene = randi() % 3               # (0.66) one of the temple's scenes, at random

## A HUD button pressed: tnt, boots, slow, dash or monster.
func _act(k: String) -> void:
	match k:
		"monster": input.monster = true
		"dash": input.dash = true
		"slow": input.slow = true
		"boots": input.stomp = true
		"tnt": input.tnt = true

func _coins_pill() -> PanelContainer:
	var p = _box()
	var row = _hbox(4)
	row.add_child(_icon_rect(icon("coin-icon"), 15))
	var l = _label("0", ts("m"), GOLD, 0)
	l.name = "n"
	row.add_child(l)
	p.add_child(row)
	return p

func _set_coins(pill: PanelContainer, value: int) -> void:
	(pill.find_child("n", true, false) as Label).text = str(value)

func _level_box(full: bool) -> PanelContainer:
	var p = _box()
	var row = _hbox(6)
	row.add_child(_icon_rect(icon("ico-star"), 15))
	var l = _label("", ts("m"), INK, 0)
	l.name = "lvl"
	row.add_child(l)
	var bar = _bar(46 if not full else 80, 8, LEAF)
	bar.name = "bar"
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not full:
		row.add_child(bar)
		p.add_child(row)
		return p
	var pts = _label("", ts("s"), DIM, 0)            # full: the name and the points, then the bar beneath
	pts.name = "pts"
	pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pts)
	var col = _vbox(3)
	col.add_child(row)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bar)
	p.add_child(col)
	return p

func _set_level(box: PanelContainer, full: bool) -> void:
	var info = Progress.level_info(save["xp"])
	(box.find_child("lvl", true, false) as Label).text = ("Niveau " if full else "Niv. ") + str(info["level"])
	set_bar(box.find_child("bar", true, false), float(info["into"]) / info["need"])
	if full:
		(box.find_child("pts", true, false) as Label).text = "%d / %d XP" % [info["into"], info["need"]]

## The three objectives, as cards: text, rewards, progress.
func _quest_cards(holder: VBoxContainer) -> void:
	for ch in holder.get_children():
		ch.queue_free()
	var reroll = w.has("menu-quests") and holder == w["menu-quests"] and Progress.reroll_free(save)   # (0.55: one a day)
	for q in save["quests"]:
		holder.add_child(_quest_card(q, float(q["p"]), reroll))

## One objective's card, as it stands at `p`: text, rewards, progress (the end moves it on: _card_at).
func _quest_card(q: Dictionary, p: float, reroll: bool = false) -> PanelContainer:
	var card = _box()
	var col = _vbox(3)
	var row = _hbox(6)
	if reroll:                                       # 0.55: once a day, this objective changed for nothing
		var fb = Button.new()
		fb.focus_mode = Control.FOCUS_NONE
		_style_button(fb, "square")
		fb.custom_minimum_size = Vector2(a(26), a(26))
		fb.icon = icon("ico-rewind") if icon("ico-rewind") != null else icon("ico-star")
		fb.expand_icon = true
		fb.add_theme_constant_override("icon_max_width", roundi(a(18)))
		fb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fb.tooltip_text = "Changer ce défi (une fois par jour)"
		var on_change = func() -> void:
			if Progress.reroll(save, q):
				SaveData.store(save)
				Audio.sfx("quest")
				refresh_menu()
		fb.pressed.connect(on_change)
		row.add_child(fb)
	var txt = _label("%s (%d/%d)" % [Progress.quest_text(q), floori(p), q["goal"]], ts("s"), INK, 0)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size.x = a(118)
	row.add_child(txt)
	var rew = _vbox(0)
	var r1 = _price(q["reward"], GOLD)
	r1.alignment = BoxContainer.ALIGNMENT_END
	(r1.get_child(0) as Label).text = "+%d" % q["reward"]
	var r2 = _label("+%d XP" % q["xp"], ts("s"), RELIC, 0)
	r2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rew.add_child(r1)
	rew.add_child(r2)
	row.add_child(rew)
	col.add_child(row)
	var bar = _bar(10, 8, RELIC)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bar)
	card.add_child(col)
	set_bar(bar, p / q["goal"])
	card.set_meta("bar", bar)
	card.set_meta("txt", txt)
	return card

## The card's progress shown at `p` (moving on: a blip as it fills, higher and higher).
func _card_at(card: PanelContainer, q: Dictionary, p: float, sound: bool = false) -> void:
	if not is_instance_valid(card):
		return
	if sound and state == "over" and time - tally_tick_t > 0.05:
		tally_tick_t = time
		Audio.sfx("fill", 0.8 + clampf(p / q["goal"], 0, 1))
	set_bar(card.get_meta("bar"), p / q["goal"])
	(card.get_meta("txt") as Label).text = "%s (%d/%d)" % [Progress.quest_text(q), floori(p), q["goal"]]

# ---------- the end: the count (tally), then the end screen ----------

## The count, in one panel: the metres counting up from nothing (slowly at first, faster and faster; the
## longer the run, the longer it lasts; the number beating harder every 0.8 s), then a punch: the distance
## as it ends and the coins won; then the level bar (fast, then slowing down; a level passed: a burst, then
## its panel); then « Suivant ». A touch anywhere finishes the step under way.
func _build_tally() -> void:
	var s = _screen("tally", true)
	var catcher = Control.new()                      # a touch anywhere on the screen: _tally_tap
	catcher.size = Vector2(W, H)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_tally_input)
	s.add_child(catcher)
	w["tally-title"] = _head(s, DEATHS[0])
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col = _vbox(3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var d_head = _label("DISTANCE", ts("s"), RELIC, 0)
	d_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(d_head)
	w["tally-dist"] = _label("0 m", ts("huge"), INK, 3)
	w["tally-dist"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w["tally-dist"])
	var gain = _hbox(5)
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	w["tally-gold"] = _label("+0", ts("xl"), GOLD)
	gain.add_child(w["tally-gold"])
	gain.add_child(_icon_rect(icon("coin-icon"), 20))
	w["tally-gain"] = gain
	col.add_child(gain)
	w["tally-best"] = _label("", ts("s"), DIM, 0)
	w["tally-best"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w["tally-best"])
	w["tally-level"] = _level_box(true)
	col.add_child(w["tally-level"])
	var xrow = _hbox(8)
	xrow.alignment = BoxContainer.ALIGNMENT_CENTER
	w["tally-xp"] = _label("+0 XP", ts("m"), RELIC)
	xrow.add_child(w["tally-xp"])
	w["tally-up"] = _label("NIVEAU SUPÉRIEUR !", ts("m"), GOLD, 1.5)
	w["tally-up"].modulate.a = 0
	xrow.add_child(w["tally-up"])
	w["tally-xprow"] = xrow
	col.add_child(xrow)
	var room = Control.new()                         # (a little room above the frame's lower edge)
	room.custom_minimum_size.y = a(6)
	col.add_child(room)
	p.add_child(col)
	_place(p, 569 / 2.0 - 150, 42, 300, 150)
	s.add_child(p)
	w["tally-next"] = _button("Suivant", "big", _tally_next)
	_actions(s, [w["tally-next"]])

func _tally_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_tally_tap()

func _tally_kill() -> void:
	if tally_tw != null and tally_tw.is_valid():
		tally_tw.kill()
	tally_tw = null

## The count, from nothing: 200 m take 0.5 s, 2300 m 4 s (6 s at most), slow at first then faster and faster.
func tally_play() -> void:
	if over_info.is_empty():
		return
	_tally_kill()
	var dist: int = over_info["dist"]
	var xp0: float = over_info.get("xp0", save["xp"])
	w["tally-title"].text = over_info["title"]
	w["tally-best"].text = ""
	w["tally-up"].modulate.a = 0
	for k in ["tally-gain", "tally-best", "tally-level", "tally-xprow"]:
		w[k].modulate.a = 0
	w["tally-next"].visible = false
	tally_level = Progress.level_info(xp0)["level"]
	_tally_dist(0)
	_tally_gold(0)
	_tally_xp(xp0, xp0)
	tally_phase = "count"
	tally_age = 0.0
	tally_dur = clampf(0.5 + (dist - 200) / 600.0, 0.35, 6.0)
	var tw = create_tween()
	tally_tw = tw
	tw.tween_interval(0.2)
	tw.tween_method(_tally_dist, 0.0, float(dist), tally_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_tally_impact)

## While it counts, the number beats once every 0.8 s, harder and harder.
func _tally_beat(delta: float) -> void:
	var l: Label = w.get("tally-dist")
	if l == null or not is_instance_valid(l) or tally_phase != "count":
		return
	tally_age += delta
	var k = clampf((tally_age - 0.2) / tally_dur, 0, 1)
	var ph = fmod(tally_age, 0.8) / 0.8
	var beat = sin(PI * ph / 0.3) if ph < 0.3 else 0.0
	l.pivot_offset = l.size / 2
	l.scale = Vector2.ONE * (1.0 + (0.05 + 0.3 * k) * beat)

func _tally_dist(v: float) -> void:
	var shown = "%d m" % roundi(v)
	if w["tally-dist"].text != shown and state == "tally" and time - tally_tick_t > 0.06:
		tally_tick_t = time                          # a tick, higher and higher as it climbs
		Audio.sfx("tick", 0.8 + 0.8 * clampf(v / maxf(1.0, float(over_info.get("dist", 1))), 0, 1))
	w["tally-dist"].text = shown

func _tally_gold(v: float) -> void:
	w["tally-gold"].text = "+%d" % roundi(v)

## The count reaches its end: the number swells at once and settles, the coins won come in with it.
func _tally_impact() -> void:
	_tally_kill()
	tally_phase = "impact"
	_tally_dist(over_info["dist"])
	_tally_gold(over_info["gold"])
	var l: Label = w["tally-dist"]
	l.pivot_offset = l.size / 2
	l.scale = Vector2(1.75, 1.75)
	var gain: Control = w["tally-gain"]
	gain.pivot_offset = gain.size / 2
	gain.scale = Vector2(1.6, 1.6)
	Audio.sfx("impact")
	var tw = create_tween().set_parallel()
	tally_tw = tw
	tw.tween_property(l, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gain, "modulate:a", 1.0, 0.12)
	tw.tween_property(gain, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_tally_best)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_callback(_tally_bar)

## (the top of the panel as the punch leaves it)
func _tally_top() -> void:
	_tally_dist(over_info["dist"])
	_tally_gold(over_info["gold"])
	w["tally-dist"].scale = Vector2.ONE
	w["tally-gain"].scale = Vector2.ONE
	w["tally-gain"].modulate.a = 1
	_tally_best()

## The level bar: in, then filled with the experience won, fast at first and slowing down.
func _tally_bar() -> void:
	_tally_kill()
	tally_phase = "bar"
	var xp0: float = over_info.get("xp0", save["xp"])
	var xp1: float = over_info.get("xp1", save["xp"])
	var tw = create_tween().set_parallel()
	tally_tw = tw
	tw.tween_property(w["tally-level"], "modulate:a", 1.0, 0.2)
	tw.tween_property(w["tally-xprow"], "modulate:a", 1.0, 0.2)
	tw.chain().tween_method(func(v: float) -> void: _tally_xp(xp0, v, true), xp0, xp1, clampf(0.9 + (xp1 - xp0) / 300.0, 1.0, 2.6)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.25)
	tw.chain().tween_callback(_tally_levels)

## The experience counted up to `x` (from xp0): the gain, the level bar (a blip as it fills, higher and
## higher), a burst at each level passed.
func _tally_xp(xp0: float, x: float, sound: bool = false) -> void:
	w["tally-xp"].text = "+%d XP" % roundi(x - xp0)
	var info = Progress.level_info(x)
	var box: PanelContainer = w["tally-level"]
	var k = float(info["into"]) / info["need"]
	(box.find_child("lvl", true, false) as Label).text = "Niveau " + str(info["level"])
	set_bar(box.find_child("bar", true, false), k)
	(box.find_child("pts", true, false) as Label).text = "%d / %d XP" % [info["into"], info["need"]]
	if sound and state == "tally" and time - tally_tick_t > 0.05 and roundi(x) != roundi(xp0):
		tally_tick_t = time
		Audio.sfx("fill", 0.8 + k)
	if info["level"] > tally_level and state == "tally":
		tally_level = info["level"]
		Audio.sfx("level")
		confetti(40)
		var up: Label = w["tally-up"]
		up.pivot_offset = up.size / 2
		up.modulate.a = 1
		up.scale = Vector2(0.5, 0.5)
		var tw = create_tween()
		tw.tween_property(up, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		box.pivot_offset = box.size / 2
		box.scale = Vector2(1.12, 1.12)
		create_tween().tween_property(box, "scale", Vector2.ONE, 0.3)

func _tally_best() -> void:
	var record: bool = over_info["record"]
	w["tally-best"].modulate.a = 1
	w["tally-best"].text = "Debug : record non enregistré" if over_info["debug"] else ("★ Nouveau record ! ★" if record else "Record : %d m" % best_of(over_info["mode"]))
	_set_colour(w["tally-best"], GOLD if record else DIM)
	w["tally-best"].label_settings.font_size = ts("m") if record else ts("s")
	w["tally-best"].set_meta("hop", record)
	if record and state == "tally" and tally_phase != "done":
		confetti(60)
		Audio.sfx("record")

## The bar full: a level passed, its panel (then « Suivant »); otherwise « Suivant » at once.
func _tally_levels() -> void:
	tally_tw = null
	if not levels_due.is_empty() and state == "tally":
		tally_phase = "levels"
		show_levels(_tally_end)
	else:
		_tally_end()

## « Suivant » comes in.
func _tally_end() -> void:
	tally_phase = "done"
	if state != "tally":
		return
	var b: Control = w["tally-next"]
	b.visible = true
	b.pivot_offset = b.size / 2
	b.scale = Vector2(0.6, 0.6)
	b.modulate.a = 0
	var tw = create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 1.0, 0.2)

## A touch (or the jump key) during the count: the step under way, finished at once.
func _tally_tap() -> void:
	if state != "tally":
		return
	var xp0: float = over_info.get("xp0", save["xp"])
	var xp1: float = over_info.get("xp1", save["xp"])
	match tally_phase:
		"count":
			_tally_impact()
		"impact":
			_tally_kill()
			_tally_top()
			_tally_bar()
		"bar":
			_tally_kill()
			w["tally-level"].modulate.a = 1
			w["tally-xprow"].modulate.a = 1
			_tally_xp(xp0, xp1)
			_tally_levels()
		"levels":                                    # (the levels' panel gone without its button: on to Suivant)
			if modal == null:
				_tally_end()
		"done":
			_tally_next()

## The count as it ends (the screen built again, or Suivant pressed during it).
func tally_view() -> void:
	if over_info.is_empty():
		return
	w["tally-title"].text = over_info["title"]
	tally_phase = "done"
	for k in ["tally-gain", "tally-best", "tally-level", "tally-xprow"]:
		w[k].modulate.a = 1
	_tally_top()
	tally_level = 999
	_tally_xp(over_info.get("xp0", save["xp"]), over_info.get("xp1", save["xp"]))
	w["tally-next"].visible = true
	w["tally-next"].modulate.a = 1
	w["tally-next"].scale = Vector2.ONE

## « Suivant »: the end screen, where the objectives move on and the photo comes in.
func _tally_next() -> void:
	if state != "tally":
		return
	if tally_phase != "done":
		_tally_kill()
		tally_view()
	Audio.sfx("click")
	state = "over"
	show_screen("over")
	over_play()
	if not levels_due.is_empty():                    # (Suivant before the levels' panel: it comes now)
		show_levels.call_deferred()

## The end screen comes alive: the photo of the fall drops in; each objective moves from where the run
## found it to where it left it; one completed shines (« Réussi ! »), goes, and the one replacing it comes in.
func over_play() -> void:
	_stop_over()
	var shot: Control = w["over-shot"]
	shot.pivot_offset = shot.size / 2
	shot.scale = Vector2(0.2, 0.2)
	shot.rotation = -0.5
	shot.modulate.a = 0
	var pt = create_tween().set_parallel()
	over_tweens.append(pt)
	pt.tween_property(shot, "scale", Vector2.ONE, 0.5).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(shot, "rotation", -0.03, 0.5).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(shot, "modulate:a", 1.0, 0.25).set_delay(0.15)
	var holder: VBoxContainer = w["over-quests"]
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.queue_free()
	var finals: Array = save["quests"]
	var fresh: Array = finals.filter(func(f): return not run_quests0.any(func(s): return is_same(s["q"], f)))
	var i = 0
	for s in run_quests0:
		var q: Dictionary = s["q"]
		var done = not finals.any(func(f): return is_same(f, q))
		var card = _quest_card(q, s["p"])
		holder.add_child(card)
		var target: float = float(q["goal"]) if done else float(q["p"])
		if target <= s["p"] and not done:
			i += 1
			continue
		var tw = create_tween()
		over_tweens.append(tw)
		tw.tween_interval(0.6 + i * 0.4)
		tw.tween_method(func(v: float) -> void: _card_at(card, q, v, true), float(s["p"]), target, 0.7).set_ease(Tween.EASE_OUT)
		if done:
			var nq = fresh.pop_front() if not fresh.is_empty() else null
			tw.tween_callback(func() -> void: _card_done(card, q))
			tw.tween_interval(1.0)
			tw.tween_property(card, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func() -> void: _card_swap(holder, card, nq))
		i += 1
	for nq in fresh:                                 # (more new ones than completed: shown at once)
		holder.add_child(_quest_card(nq, float(nq["p"])))

func _stop_over() -> void:
	for tw in over_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	over_tweens.clear()

## An objective completed: it shines, « Réussi ! » and what it paid.
func _card_done(card: PanelContainer, q: Dictionary) -> void:
	if not is_instance_valid(card):
		return
	Audio.sfx("level")
	var txt: Label = card.get_meta("txt")
	txt.text = "RÉUSSI !  +%d pièces  +%d XP" % [q["reward"], q["xp"]]
	_set_colour(txt, GOLD)
	card.pivot_offset = card.size / 2
	card.modulate = Color(1.5, 1.35, 0.9)
	card.scale = Vector2(1.08, 1.08)
	var tw = create_tween().set_parallel()
	tw.tween_property(card, "modulate", Color.WHITE, 0.5)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The completed card goes; the new objective takes its place.
func _card_swap(holder: VBoxContainer, card: PanelContainer, nq) -> void:
	if not is_instance_valid(card):
		return
	var at = card.get_index()
	holder.remove_child(card)
	card.queue_free()
	if nq == null:
		return
	var fresh_card = _quest_card(nq, float(nq["p"]))
	holder.add_child(fresh_card)
	holder.move_child(fresh_card, at)
	fresh_card.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(fresh_card, "modulate:a", 1.0, 0.35)
	Audio.sfx("click")

func _build_intro() -> void:
	var s = _screen("intro", true)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("intro-pane"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(p, 104, 52, 361, 150)
	var col = _vbox(10)
	var h = _label("La relique", ts("xl"), GOLD)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	for text in ["Pépito a dérobé le cœur de la relique du temple et l'a glissé dans son sac à dos. Il ne reste qu'à sortir de la jungle.",
			"Mais les pygmées du temple veillent : à chaque chute, ils le rattrapent et le ramènent au temple, ficelé sur une broche."]:
		var l = _label(text, ts("m"), INK, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = a(340)
		col.add_child(l)
	p.add_child(col)
	s.add_child(p)
	_actions(s, [_button("Fuir !", "big", func() -> void: go("play"))])

## The shop: the four families down the left side, under the thumb; their items as a list in the middle;
## on the right, the one picked: its name, its animated preview, what it does, its price and its buttons.
func _build_shop() -> void:
	var s = _screen("shop", true)
	var side = _vbox(4)
	_place(side, 6, 6, 54, 308)
	var back = _button("Retour", "tab", func() -> void: go("menu"))
	_shop_skin(back, "back", false)
	back.custom_minimum_size = Vector2(a(54), a(36))
	back.add_theme_font_size_override("font_size", roundi(6.5 * U))
	side.add_child(back)
	for spec in [["up", "magnet", "Équip."], ["power", "flight", "Pouvoirs"], ["mount", "nature", "Montures"], ["skin", "star", "Skins"]]:
		var key: String = spec[0]
		var on_tab = func() -> void:
			tab = key
			refresh_shop()
		var b = _button(spec[2], "tab", on_tab)
		b.icon = icon("ico-" + spec[1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", roundi(a(26)))
		b.clip_text = true
		b.custom_minimum_size = Vector2(a(54), a(64))  # the picture's exact size
		side.add_child(b)
		w["tab-" + key] = b
	s.add_child(side)
	w["shop-title"] = _label("", ts("s"), RELIC, 1.5)
	_place(w["shop-title"], 68, 11, 230, 14)
	s.add_child(w["shop-title"])
	w["shop-coins"] = _coins_pill()
	_place(w["shop-coins"], 569 - M - 80, 4, 80, 22)
	s.add_child(w["shop-coins"])
	var scroll = ScrollContainer.new()               # dragged with a finger, or the wheel; no bar
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_place(scroll, 66, 30, 236, 282)
	w["shop-scroll"] = scroll
	w["shop-list"] = _vbox(3)
	w["shop-list"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["shop-list"].mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(w["shop-list"])
	s.add_child(scroll)
	var prev = PanelContainer.new()
	prev.add_theme_stylebox_override("panel", _kit_panel("shop-preview-wide", 3))   # 253 x 282: off the corner leaves
	prev.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(prev, 308, 30, 253, 282)
	w["card-panel"] = prev
	var pc = _vbox(5)
	var head = _hbox(6)
	w["card-name"] = _label("", ts("m"), GOLD, 0)
	w["card-name"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["card-name"].clip_text = true
	head.add_child(w["card-name"])
	w["card-pips"] = _label("", ts("m"), GOLD, 0)
	head.add_child(w["card-pips"])
	pc.add_child(head)
	# the animated preview: a tiny real run, drawn by a second renderer into its own picture
	var frame = PanelContainer.new()
	var fs = StyleBoxFlat.new()
	fs.bg_color = Color("#0a0f14")
	fs.border_color = LINE
	fs.set_border_width_all(roundi(a(1.5)))
	frame.add_theme_stylebox_override("panel", fs)
	var view = TextureRect.new()
	view.texture = demo_vp.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # (lower when the text is long: _card_size)
	view.custom_minimum_size = Vector2(a(210), a(210 * Demo.H / Demo.W))   # inside the stone frame
	view.texture_filter = game_view.texture_filter
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(view)
	pc.add_child(frame)
	w["demo-view"] = view
	w["demo-desc"] = _label("", ts("s"), INK, 0)
	w["demo-desc"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["demo-desc"].custom_minimum_size.x = a(210)
	pc.add_child(w["demo-desc"])
	w["card-status"] = _label("", ts("s"), DIM, 0)
	w["card-status"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["card-status"].custom_minimum_size.x = a(210)
	pc.add_child(w["card-status"])
	var fill = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(fill)
	w["card-actions"] = _hbox(6)
	w["card-actions"].alignment = BoxContainer.ALIGNMENT_END
	pc.add_child(w["card-actions"])
	prev.add_child(pc)
	s.add_child(prev)

## Réglages (0.51), laid out as the shop: the categories down the left side (Retour, Jeu, Affichage,
## Sauvegarde; 0.52: the volumes at the top of Jeu, no Son any more), the one open in a stone pane in the middle. Sauvegarde holds the three parties (SaveData
## slots): each one's level and coins, « Jouer » to switch to it, its code out and in, erasing it. Opened
## from the pause, Sauvegarde only says it waits for the end of the run.
const SET_TABS := [["game", "target", "Jeu"], ["show", "gems", "Affichage"], ["save", "shield", "Sauvegarde"]]

func _build_settings() -> void:
	var s = _screen("settings", true)
	var on_set_tab = func(key: String) -> void:
		set_tab = key
		refresh_settings()
	_side_tabs(s, SET_TABS, "settab-", on_set_tab)
	w["set-title"] = _label("", ts("s"), RELIC, 1.5)
	w["set-title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(w["set-title"], 133, 11, 361, 14)
	s.add_child(w["set-title"])
	var pane = PanelContainer.new()
	pane.add_theme_stylebox_override("panel", _kit_tall("intro-pane"))   # 361 wide, its middle rows repeated
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(pane, 133, 30, 361, 282)
	s.add_child(pane)
	w["set-pane"] = pane
	var all = _vbox(0)
	# Jeu: the volumes first (0.52)
	var game = _vbox(4)
	for spec in [["Musique", "musicVol"], ["Effets", "sfxVol"]]:
		var key: String = spec[1]
		var row = _toggle_row(spec[0])
		var vol = _hbox(4)
		vol.add_child(_small_square("−", func() -> void: _volume(key, -1)))
		var bar = _bar(110, 12, GOLD)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vol.add_child(bar)
		w["vol-" + key] = bar
		vol.add_child(_small_square("+", func() -> void: _volume(key, 1)))
		row.add_child(vol)
		game.add_child(row)
	for spec in [["Contours des dangers", "tg-rim", "Un liseré rouge autour de tout ce qui fait mal."],
			["Signalements décalés", "tg-shift", "Les alertes des Fonceurs apparaissent plus à gauche, loin du pouce."]]:
		game.add_child(_set_toggle(spec[0], spec[1], spec[2]))
	var vrow = _toggle_row("Version " + VERSION)
	var cb = _button("Changements", "small", _show_changes)   # (0.64) the changelog
	cb.custom_minimum_size.x = a(100)
	vrow.add_child(cb)
	if OS.has_feature("web"):                        # the browser keeps the game's files: a fresh copy on demand
		var ub = _button("Mettre à jour", "small", _check_update)
		ub.custom_minimum_size.x = a(110)
		vrow.add_child(ub)
	game.add_child(vrow)
	var um = _label(update_text if OS.has_feature("web") else "Une nouvelle version : le jeu la reçoit en se relançant.", ts("s"), DIM, 0)
	um.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	um.custom_minimum_size.x = a(300)
	w["upd-msg"] = um
	game.add_child(um)
	var fb = _hbox(6)                                  # (0.68) a word to the author: the site's form (retours.html)
	var fbb = _button("Donner mon avis", "small", _send_feedback)
	fbb.custom_minimum_size.x = a(150)
	fb.add_child(fbb)
	var fbn = _label("Un bug, une idée : une page s'ouvre.", ts("s"), DIM, 0)
	fbn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.add_child(fbn)
	game.add_child(fb)
	w["panel-game"] = game
	all.add_child(game)
	# Affichage
	var show = _vbox(4)
	var qual = _set_toggle("Qualité", "tg-quality", "")
	w["q-sub"] = qual.get_meta("sub")
	show.add_child(qual)
	var full = _set_toggle("Plein écran", "tg-full", "Le jeu prend tout l'écran.")
	full.visible = _can_full()
	show.add_child(full)
	show.add_child(_set_toggle("Police pixel", "tg-font", "Non : une police ronde, plus facile à lire."))
	show.add_child(_set_toggle("Images par seconde", "tg-fps", "Leur nombre, affiché pendant la course."))
	w["panel-show"] = show
	all.add_child(show)
	# Sauvegarde: the three parties
	var keep = _vbox(6)
	for n in range(1, SaveData.SLOTS + 1):
		var card = _vbox(3)
		var head = _hbox(6)
		var name_l = _label("PARTIE %d" % n, ts("m"), INK, 0)
		head.add_child(name_l)
		var info = _label("", ts("s"), DIM, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		head.add_child(info)
		var on_l = _label("EN COURS", ts("s"), RELIC, 0)
		head.add_child(on_l)
		var play = _button("Jouer", "small gold", func() -> void: _slot_play(n))
		play.custom_minimum_size.x = a(64)
		head.add_child(play)
		card.add_child(head)
		var acts = _hbox(4)
		var specs = [["Exporter", func() -> void: _slot_export(n)], ["Importer", func() -> void: _slot_import(n)], ["Réinitialiser", func() -> void: _slot_reset(n)]]
		for spec in specs:
			var b = _button(spec[0], "small danger" if spec[0] == "Réinitialiser" else "small", spec[1])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			acts.add_child(b)
		card.add_child(acts)
		keep.add_child(card)
		w["slot-%d" % n] = {"name": name_l, "info": info, "on": on_l, "play": play}
	w["save-msg"] = _label("", ts("s"), DIM, 0)
	w["save-msg"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["save-msg"].custom_minimum_size.x = a(300)
	keep.add_child(w["save-msg"])
	var forget = func() -> void:                     # 0.48: the player's data on the server (the stores ask for it)
		_confirm("Effacer tes données en ligne ? Ton pseudo, ton code ami, tes records et tes amitiés disparaissent du serveur. Ta progression reste.", func() -> void:
			coop.leave()
			race.leave()
			var r = await net.delete_me(save)
			board = []
			board_cache = []
			_msg("Données en ligne effacées." if r.get("ok", false) else "Pas de réponse du serveur : réessaie plus tard."))
	var wipe = _button("Effacer mes données en ligne", "small danger", forget)
	wipe.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	keep.add_child(wipe)
	w["save-online"] = wipe
	w["panel-save"] = keep
	all.add_child(keep)
	var later = _wrap("Pendant une course, la sauvegarde attend la fin : reviens ici depuis l'accueil.", DIM)
	w["panel-save-later"] = later
	all.add_child(later)
	pane.add_child(_fixed(all))

## The shop's left column for any screen (0.51: Réglages too): Retour, then one tab per [key, icon, name],
## at the pictures' exact sizes (54 x 36, 54 x 64). `prefix`: where the tabs go in `w` (prefix + key).
func _side_tabs(s: Control, specs: Array, prefix: String, on_tab: Callable) -> void:
	var side = _vbox(4)
	_place(side, 6, 6, 54, 308)
	var back = _button("Retour", "tab", func() -> void: go("menu"))
	_shop_skin(back, "back", false)
	back.custom_minimum_size = Vector2(a(54), a(36))
	back.add_theme_font_size_override("font_size", roundi(6.5 * U))
	side.add_child(back)
	for spec in specs:
		var key: String = spec[0]
		var b = _button(spec[2], "tab", func() -> void: on_tab.call(key))
		b.icon = icon("ico-" + spec[1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", roundi(a(26)))
		b.clip_text = true
		b.custom_minimum_size = Vector2(a(54), a(64))  # the picture's exact size
		side.add_child(b)
		w[prefix + key] = b
	s.add_child(side)

## Paints a left column's tabs: the open one in its "selected" picture; each name as big as fits its stone.
func _paint_side_tabs(specs: Array, prefix: String, sel: String) -> void:
	for spec in specs:
		var b: Button = w[prefix + spec[0]]
		_shop_skin(b, "tab", spec[0] == sel)
		var fs = 5.5 * U
		while fs > 4.0 * U and bold.get_string_size(spec[2], HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(fs)).x > a(54 - 14):
			fs -= 0.25 * U
		b.add_theme_font_size_override("font_size", roundi(fs))

## A setting's row: its name, its button (« Oui » / « Non », or Qualité's), and a line under it.
func _set_toggle(text: String, id: String, sub_text: String) -> VBoxContainer:
	var box = _vbox(1)
	var row = _toggle_row(text)
	var b = _button("", "small on", func() -> void: _toggle(id))
	b.custom_minimum_size.x = a(80)
	row.add_child(b)
	w[id] = b
	box.add_child(row)
	var sub = _label(sub_text, ts("s"), DIM, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = a(300)
	box.add_child(sub)
	box.set_meta("sub", sub)
	return box

func _toggle_row(text: String) -> HBoxContainer:
	var row = _hbox(4)
	var l = _label(text, ts("m"), INK, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = a(100)
	row.add_child(l)
	return row

func _small_square(text: String, fn: Callable) -> Button:
	var b = _button(text, "square", fn)
	_kit_square(b, "blank", 28)
	b.add_theme_font_size_override("font_size", ts("l"))
	return b

func _build_score(name: String) -> void:
	var s = _screen(name, true)
	w[name + "-title"] = _head(s, "Pause" if name == "pause" else DEATHS[0])
	var left = _pane(s, false)
	var col = _vbox(6 if name == "over" else 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	if name == "over":                               # the photo of the fall: a touch shows it in full
		var shot = Button.new()
		shot.focus_mode = Control.FOCUS_NONE
		shot.flat = true
		shot.custom_minimum_size = Vector2(a(96), a(54))
		shot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color("#0a0f14")
		sb.border_color = Color("#fff8e6")
		sb.set_border_width_all(roundi(a(2)))
		for st in ["normal", "hover", "pressed", "focus"]:
			shot.add_theme_stylebox_override(st, sb)
		var pic = TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = a(2)
		pic.offset_top = a(2)
		pic.offset_right = -a(2)
		pic.offset_bottom = -a(2)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(pic)
		shot.rotation = -0.03
		var on_shot = func() -> void:
			Audio.sfx("click")
			_show_photo()
		shot.pressed.connect(on_shot)
		w["over-shot"] = shot
		w["over-pic"] = pic
		col.add_child(shot)
	w[name + "-dist"] = _label("0 m", ts("huge") if name == "pause" else roundi(ts("huge") * 0.72), INK, 3)
	w[name + "-best"] = _label("", ts("s"), DIM, 0)
	w[name + "-dist"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w[name + "-dist"])
	var gain = _hbox(5)                              # the coins of the run, with the coin
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	w[name + "-gold"] = _label("", ts("xl"), GOLD)
	gain.add_child(w[name + "-gold"])
	gain.add_child(_icon_rect(icon("coin-icon"), 20))
	col.add_child(gain)
	w[name + "-best"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w[name + "-best"])
	left.add_child(_fixed(col))
	var right = _pane(s, true)
	var rc = _vbox(6)
	w[name + "-level"] = _level_box(true)
	rc.add_child(w[name + "-level"])
	w[name + "-quests"] = _vbox(4)
	rc.add_child(w[name + "-quests"])
	right.add_child(_fixed(rc))
	if name == "over":
		_actions(s, [_button("Menu", "", func() -> void: go("menu")), _button("Rejouer", "big", _replay)])
	else:
		_actions(s, [_button("Abandonner", "stop", func() -> void: go("menu")), _button("Réglages", "", func() -> void: go("settings")), _button("Reprendre", "go", resume)], 150)
		var eye = Button.new()                       # the eye: the menu goes, the game is seen (still paused); again: back
		eye.focus_mode = Control.FOCUS_NONE
		_kit_square(eye, "blank", 36)
		var drawn = Eye.new()
		drawn.set_anchors_preset(Control.PRESET_FULL_RECT)
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye.add_child(drawn)
		_place(eye, 569 - M - 36, M, 36, 36)
		eye.set_meta("still", true)
		var on_eye = func() -> void:
			Audio.sfx("click")
			_peek(not peeking)
		eye.pressed.connect(on_eye)
		w["pause-eye"] = eye
		w["pause-eye-icon"] = drawn
		s.add_child(eye)

# ---------- moving between screens ----------

## Every block of a screen leaves towards, and comes back from, the edge of the frame it sits closest to
## (the web version's "fly" blocks). Worked out once, from where each block rests.
func _aim_flyers() -> void:
	for k in screens:
		for ch in screens[k].get_children():
			if not (ch is Control) or ch.has_meta("still"):
				continue
			_set_rest(ch, ch.position)

func _set_rest(ch: Control, pos: Vector2) -> void:
	var r = Rect2(pos, ch.size)
	var gaps = {"left": r.position.x, "right": W - r.end.x, "top": r.position.y, "bottom": H - r.end.y}
	var best = "left"
	for g in gaps:
		if gaps[g] < gaps[best]:
			best = g
	var away = {"left": Vector2(-a(580), 0), "right": Vector2(a(580), 0), "top": Vector2(0, -a(330)), "bottom": Vector2(0, a(330))}[best]
	ch.set_meta("rest", pos)
	ch.set_meta("away", away)
	ch.set_meta("away0", away)                      # (go_from may send them another way for a while)
	var sc: Control = ch.get_parent()
	if not sc.visible or sc.has_meta("closing"):
		ch.position = pos + away
	else:
		ch.position = pos

## Shows one screen (or the HUD): its blocks slide in with a little overshoot while the others' slide out.
func show_screen(name: String) -> void:
	for k in screens:
		var sc: Control = screens[k]
		var on = k == name
		var shown_now = sc.visible and not sc.has_meta("closing")
		if on == shown_now:
			continue
		if sc.has_meta("tw"):
			(sc.get_meta("tw") as Tween).kill()
		var tw = create_tween().set_parallel()
		sc.set_meta("tw", tw)
		var bg = sc.get_node_or_null("bg")
		if on:
			var was_hidden = not sc.visible
			sc.remove_meta("closing")
			sc.visible = true
			sc.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
			for ch in sc.get_children():
				if ch.has_meta("rest"):
					if ch.has_meta("away0"):             # 0.50: from the side of the button that opened it
						ch.set_meta("away", _away_of(fly_side) if fly_side != "" else ch.get_meta("away0"))
						if was_hidden:
							ch.position = ch.get_meta("rest") + ch.get_meta("away")
					tw.tween_property(ch, "position", ch.get_meta("rest"), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if bg != null:
				tw.tween_property(bg, "modulate:a", 1.0, 0.35)
		else:
			sc.set_meta("closing", true)
			sc.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED   # nothing can be touched on its way out
			for ch in sc.get_children():
				if ch.has_meta("rest"):
					tw.tween_property(ch, "position", ch.get_meta("rest") + ch.get_meta("away"), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			if bg != null:
				tw.tween_property(bg, "modulate:a", 0.0, 0.35)
			var hide_it = func() -> void:
				if sc.has_meta("closing"):
					sc.visible = false
					sc.remove_meta("closing")
			tw.chain().tween_callback(hide_it)
	demo_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if name == "shop" else SubViewport.UPDATE_DISABLED
	fly_side = ""

func refresh_menu() -> void:
	_set_level(w["menu-level"], false)
	var nu = Treasure.total(save)                     # (0.58: the Course du jour's urns too)
	w["menu-urns"].visible = nu > 0
	w["menu-urns-n"].text = str(nu) if nu < 100 else "99+"
	_set_coins(w["menu-coins"], save["coins"])
	_quest_cards(w["menu-quests"])
	_mode_texts()
	_fill_group()
	_send_kit()
	_coop_band()
	for ch in w["menu-loadout"].get_children():
		ch.queue_free()
	var eq: Array = save["equipped"]
	if _coop_guest():                                # for two the host's items go on the run, for both, and
		eq = coop.kit.get("eq", [])                  # Jouer starts in his scenery: shown behind already
		if coop.kit.has("biome") and int(coop.kit["biome"]) != endless_biome:
			endless_biome = int(coop.kit["biome"])
			if still != null:
				still.biome = endless_biome
				still.prev_biome = endless_biome
	w["menu-loadout-box"].visible = eq.size() > 0    # (0.57: its panel, only when something is equipped)
	for i in mini(3, eq.size()):                     # what goes on the next run: only the items equipped,
		var id: String = eq[i]                       # their pictures alone (no frame, no empty place)
		var slot = Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(a(28), a(28))
		var bare = StyleBoxEmpty.new()
		bare.set_content_margin_all(a(4))
		for k in ["normal", "hover", "pressed", "disabled"]:
			slot.add_theme_stylebox_override(k, bare)
		var down: StyleBoxEmpty = bare.duplicate()        # pressed: the picture two art pixels lower
		down.content_margin_top = a(6)
		down.content_margin_bottom = a(2)
		slot.add_theme_stylebox_override("pressed", down)
		slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		slot.icon = icon("ico-" + SaveData.upgrade(id)["icon"])
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_color_override("icon_hover_color", Color(1.15, 1.15, 1.15))
		var on_slot = func() -> void:              # a touch says what it holds
			Audio.sfx("click")
			_slot_info(id)
		slot.pressed.connect(on_slot)
		slot.set_meta("id", id)
		w["menu-loadout"].add_child(slot)

## The item whose note is open stands out a little (brighter, a touch bigger), without a frame.
func _mark_slots(id: String) -> void:
	for sl in w["menu-loadout"].get_children():
		var on: bool = id != "" and sl.get_meta("id", "") == id
		sl.modulate = Color(1.3, 1.25, 1.1) if on else Color.WHITE
		sl.pivot_offset = sl.size / 2
		sl.scale = Vector2.ONE * (1.12 if on else 1.0)

func _slot_info(id: String) -> void:
	var box: PanelContainer = w["menu-info"]
	if box.visible and box.get_meta("id", "") == id:
		box.visible = false
		_mark_slots("")
		return
	_mark_slots(id)
	for ch in box.get_children():
		ch.queue_free()
	box.set_meta("id", id)
	var u = SaveData.upgrade(id)
	var lvl = int(coop.kit.get("up", {}).get(id, 0)) if _coop_guest() else SaveData.level(save, id)
	var col = _vbox(2)
	var name_l = _label(u["name"] + ("  " + "●".repeat(lvl) + "○".repeat(u["costs"].size() - lvl) if u["costs"].size() > 1 else ""), ts("m"), GOLD, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d = _label(u["desc"], ts("s"), INK, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size.x = a(280)
	col.add_child(name_l)
	col.add_child(d)
	box.add_child(col)
	box.visible = true

func refresh_settings() -> void:
	if w.has("save-online") and is_instance_valid(w["save-online"]):
		w["save-online"].visible = Net.enabled() and save.get("online", {}).has("id")
	for pair in [["tg-font", save["pixelFont"]], ["tg-full", _is_full()], ["tg-rim", save["dangerRim"]], ["tg-shift", save["alertShift"]], ["tg-fps", save["showFps"]]]:
		var b: Button = w[pair[0]]
		b.text = "Oui" if pair[1] else "Non"
		_style_button(b, "small on" if pair[1] else "small plain")
	w["tg-quality"].text = {"max": "Max", "perf": "Perf", "eco": "Éco"}[quality()]
	w["q-sub"].text = {"max": "L'image la plus fine.",
		"perf": "Plus légère, 60 images/s : plus fluide.",
		"eco": "30 images/s : la batterie dure plus."}[quality()]
	for key in ["musicVol", "sfxVol"]:
		set_bar(w["vol-" + key], save[key] / 10.0)
	var keys = SET_TABS.map(func(t): return t[0])
	if not set_tab in keys:
		set_tab = "game"
	_paint_side_tabs(SET_TABS, "settab-", set_tab)
	for spec in SET_TABS:
		w["panel-" + spec[0]].visible = set_tab == spec[0] and not (spec[0] == "save" and in_run)
		if spec[0] == set_tab:
			w["set-title"].text = spec[2].to_upper()
	w["panel-save-later"].visible = set_tab == "save" and in_run   # opened from the pause: the save waits
	var cur = SaveData.current_slot()
	for n in range(1, SaveData.SLOTS + 1):
		var sl: Dictionary = w["slot-%d" % n]
		var on = n == cur
		sl["name"].add_theme_color_override("font_color", GOLD if on else INK)
		sl["on"].visible = on
		sl["play"].visible = not on
		sl["info"].text = _slot_line(save if on else (SaveData.load_save(n) if SaveData.slot_used(n) else {}))

## A partie in a line: its level, its coins, its record; « Nouvelle partie » when it has not been played.
func _slot_line(s: Dictionary) -> String:
	if s.is_empty():
		return "Nouvelle partie"
	return "Niv. %d · %d pièces · %d m" % [Progress.level_info(s["xp"])["level"], int(s["coins"]), int(s["best"])]

# ---------- the three parties (0.51) ----------

## Plays partie n from now on: this one kept as it is, the other one loaded with this device's settings.
func _slot_play(n: int) -> void:
	if SaveData.slot_used(n):
		_switch_slot(n)
	else:
		_confirm("Commencer une nouvelle partie dans la Partie %d ?\nLes autres restent comme elles sont." % n, func() -> void: _switch_slot(n))

func _switch_slot(n: int) -> void:
	SaveData.store(save)
	coop.leave()                                     # (each partie is its own player online)
	race.leave()
	var dev := {}
	for k in SaveData.DEVICE:
		dev[k] = save[k]
	SaveData.set_slot(n)
	save = SaveData.load_save()
	for k in dev:
		save[k] = dev[k]
	SaveData.store(save)
	coop.save = save
	race.save = save
	board = []
	board_cache = []
	rebuild_due = true                               # (its buttons may be of stone)
	_after_load()
	_msg("Partie %d : en route !" % n)

func _slot_export(n: int) -> void:
	var cur = n == SaveData.current_slot()
	if not cur and not SaveData.slot_used(n):
		_msg("La Partie %d est vide : rien à exporter." % n)
		return
	var code = SaveData.export_code(save if cur else SaveData.load_save(n))
	var copy = func() -> void:
		DisplayServer.clipboard_set(code)
		_msg("Partie %d : code copié. Colle-le où tu veux le garder." % n)
	var to_file = func() -> void: _save_file(code)
	_choose("Exporter la Partie %d :" % n, [["Copier le code", copy], ["Fichier", to_file]])

func _slot_import(n: int) -> void:
	var paste = func() -> void:
		var code := ""
		if OS.has_feature("web"):                    # a browser asks for it (a phone's field cannot be typed in)
			var got = JavaScriptBridge.eval("window.prompt('Colle ici ton code de sauvegarde :') || ''", true)
			code = str(got) if got != null else ""
		else:
			code = DisplayServer.clipboard_get()
		if code.strip_edges() == "":
			_msg("Copie d'abord un code de sauvegarde, puis reviens ici.")
			return
		_import(code, n)
	var from_file = func() -> void: _open_file(n)
	_choose("Importer dans la Partie %d :" % n, [["Coller un code", paste], ["Fichier", from_file]])

func _slot_reset(n: int) -> void:
	var do_reset = func() -> void:
		if n == SaveData.current_slot():
			save = SaveData.reset()
			coop.save = save
			race.save = save
			SaveData.store(save)
			_after_load()
		else:
			SaveData.reset(n)
		_msg("Partie %d effacée." % n)
		refresh_settings()
	_confirm("Effacer la Partie %d ? C'est définitif." % n, do_reset)

## A question with two answers or more (each [text, what it does]), and « Annuler ».
func _choose(text: String, choices: Array) -> void:
	if modal != null:
		modal.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 150, 80, 300, 110)
	var col = _vbox(10)
	var l = _label(text, ts("m"), INK, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = a(258)
	col.add_child(l)
	var row = _hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close = func() -> void:
		layer.queue_free()
		modal = null
	row.add_child(_button("Annuler", "small plain", close))
	for c in choices:
		var fn: Callable = c[1]
		var pick = func() -> void:
			close.call()
			fn.call()
		row.add_child(_button(c[0], "small gold", pick))
	col.add_child(row)
	p.add_child(col)
	root.add_child(p)
	modal = layer

func _volume(key: String, d: int) -> void:
	save[key] = clampi(save[key] + d, 0, 10)
	Audio.set_volumes(save["musicVol"], save["sfxVol"])
	SaveData.store(save)
	refresh_settings()
	if key == "musicVol":
		Audio.music("run" if in_run else "menu")
	else:
		Audio.sfx("coin")                            # heard at once

func _toggle(id: String) -> void:
	match id:
		"tg-font":
			save["pixelFont"] = not save["pixelFont"]
			SaveData.store(save)
			_rebuild()
			return
		"tg-quality":                                # Max, Perf, Éco in turn
			save["quality"] = SaveData.QUALITIES[(SaveData.QUALITIES.find(quality()) + 1) % SaveData.QUALITIES.size()]
			fit()
		"tg-full":
			save["full"] = not _is_full()
			_apply_fullscreen()
		"tg-rim":
			save["dangerRim"] = not save["dangerRim"]
			Art.set_danger_rim(save["dangerRim"])
		"tg-shift":
			save["alertShift"] = not save["alertShift"]
			render.shift = save["alertShift"]
		"tg-fps":
			save["showFps"] = not save["showFps"]
	SaveData.store(save)
	refresh_settings()

func _is_full_web() -> bool:
	return _js_yes("document.fullscreenElement")

func _is_full() -> bool:
	if OS.has_feature("web"):
		return _is_full_web()
	var m = DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _apply_fullscreen() -> void:
	if OS.has_feature("web"):
		if not _can_full():
			return
		if save["full"]:
			_js("document.documentElement.requestFullscreen({navigationUI:'hide'}).then(function(){try{screen.orientation.lock('landscape')}catch(e){}}).catch(function(){})")
		else:
			_js("document.fullscreenElement && document.exitFullscreen().catch(function(){})")
		return
	if OS.has_feature("mobile"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if save["full"] else DisplayServer.WINDOW_MODE_WINDOWED)

func _msg(t: String) -> void:
	w["save-msg"].text = t

## A code put in partie n (0.51: any of the three), once the player says yes.
func _import(code: String, n: int = 0) -> void:
	var s = SaveData.import_code(code)
	var k = n if n > 0 else SaveData.current_slot()
	if s == null:
		_msg("Code invalide : rien n'a été changé.")
		return
	var do_import = func() -> void:
		if k == SaveData.current_slot():
			save = s
			coop.save = save
			race.save = save
			SaveData.store(save)
			rebuild_due = true
			_after_load()
		else:
			SaveData.store(s, k)
		_msg("Partie importée dans la Partie %d." % k)
		refresh_settings()
	var verb = "Remplacer la Partie %d par celle-ci ?" if SaveData.slot_used(k) or k == SaveData.current_slot() else "Mettre cette partie dans la Partie %d ?"
	_confirm((verb % k) + "\n%d pièces · record %d m · %d courses" % [s["coins"], s["best"], s["loops"]], do_import)

func _after_load() -> void:
	Audio.set_volumes(save["musicVol"], save["sfxVol"])
	Skins.apply(save["skins"]["worn"])
	Art.set_danger_rim(save["dangerRim"])
	render.shift = save["alertShift"]
	refresh_settings()

## A question in the game's own look (the web version's confirm()): a pane, « Non » and « Oui ».
func _confirm(text: String, fn: Callable, yes_text: String = "Oui", no_text: String = "Non") -> void:
	if modal != null:
		modal.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))   # 300 wide, as tall as its text
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 150, 80, 300, 110)
	var col = _vbox(10)
	var l = _label(text, ts("m"), INK, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = a(258)
	col.add_child(l)
	var row = _hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close = func() -> void:
		layer.queue_free()
		modal = null
	var yes = func() -> void:
		close.call()
		fn.call()
	row.add_child(_button(no_text, "small plain", close))
	row.add_child(_button(yes_text, "small gold", yes))
	col.add_child(row)
	p.add_child(col)
	root.add_child(p)
	modal = layer

## The code in a file: downloaded in a browser, saved where the player chooses elsewhere.
func _save_file(code: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(code.to_utf8_buffer(), "jungle-loop-sauvegarde.txt", "text/plain")
		return
	var d = FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.current_file = "jungle-loop-sauvegarde.txt"
	d.filters = PackedStringArray(["*.txt ; Sauvegarde"])
	var on_file = func(path: String) -> void:
		var f = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(code)
			_msg("Sauvegarde enregistrée.")
	d.file_selected.connect(on_file)
	add_child(d)
	d.popup_centered_ratio(0.6)

## A save file opened, for partie n (0.51).
func _open_file(n: int = 0) -> void:
	open_slot = n
	if OS.has_feature("web"):                        # a file picker of the browser's; the text comes back here
		var win = JavaScriptBridge.get_interface("window")
		var cb = JavaScriptBridge.create_callback(_on_opened)
		web_cbs.append(cb)
		win.jlOpened = cb
		JavaScriptBridge.eval("(function(){var i=document.createElement('input');i.type='file';i.accept='.txt,.json';i.onchange=function(){var f=i.files[0];if(f)f.text().then(function(t){window.jlOpened(t);});};i.click();})()", true)
		return
	var d = FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.filters = PackedStringArray(["*.txt, *.json ; Sauvegarde"])
	var on_file = func(path: String) -> void:
		_import(FileAccess.get_file_as_string(path), n)
	d.file_selected.connect(on_file)
	add_child(d)
	d.popup_centered_ratio(0.6)

func _on_opened(args: Array) -> void:
	_import(str(args[0]) if args.size() > 0 else "", open_slot)

# ---------- the browser (web only) ----------

func _js(code: String):
	return JavaScriptBridge.eval(code, true) if OS.has_feature("web") else null

# ---------- updating the game (in a browser) ----------
# The browser keeps the game's files (its service worker, its cache): a new version may take a few
# reloads to show. tools/publish_web.py writes version.txt beside the game; the game reads it once at the
# start (a « ! » on the gear when it is newer) and when « Mettre à jour » is pressed (Réglages): newer, the
# game reloads without the files kept; the save is elsewhere (IndexedDB) and stays.

func _update_ready() -> bool:
	return update_online != "" and _newer(update_online, VERSION)

## Whether version a ("0.41.0") comes after version b.
static func _newer(a: String, b: String) -> bool:
	var pa = a.split(".")
	var pb = b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x = pa[i].to_int() if i < pa.size() else 0
		var y = pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false

func _upd_say(text: String) -> void:
	update_text = text
	if w.has("upd-msg") and is_instance_valid(w["upd-msg"]):
		w["upd-msg"].text = text

## « Mettre à jour »: a look online, then a fresh copy if there is a newer one; pressed again once it said
## « à jour », a fresh copy anyway.
func _check_update() -> void:
	if update_sure:
		_upd_say("Rechargement…")
		_reload_fresh()
		return
	_look_update(true)

## The version online (version.txt beside the game). `asked`: pressed in Réglages (a newer one is fetched
## at once); otherwise the look at the start (the gear's « ! »).
func _look_update(asked: bool) -> void:
	if update_busy or not OS.has_feature("web"):
		return
	update_busy = true
	if asked:
		_upd_say("Recherche d'une nouvelle version…")
	var here = str(_js("(function () { var u = location.href.split('#')[0].split('?')[0]; return u.substring(0, u.lastIndexOf('/') + 1); })()"))
	var req = HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	var online = ""
	if req.request(here + "version.txt?t=%d" % int(Time.get_unix_time_from_system() * 1000)) == OK:
		var res = await req.request_completed
		if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
			online = (res[3] as PackedByteArray).get_string_from_utf8().strip_edges()
	req.queue_free()
	update_busy = false
	if RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(online) == null:
		if asked:
			_upd_say("Pas de réponse : vérifie ta connexion, puis réessaie.")
		return
	update_online = online
	if w.has("menu-upd") and is_instance_valid(w["menu-upd"]):
		w["menu-upd"].visible = _update_ready()
	if not asked:
		if _update_ready():
			_upd_say("La version %s est en ligne : appuie sur Mettre à jour." % online)
			update_notes = await _fetch_text(here + "nouveautes.txt?t=%d" % int(Time.get_unix_time_from_system() * 1000))
			_offer_update()
		return
	if _newer(online, VERSION):
		_upd_say("Version %s trouvée : mise à jour…" % online)
		await get_tree().create_timer(0.8).timeout
		_reload_fresh()
	else:
		_upd_say("Le jeu est à jour (v%s). Appuie encore pour le recharger quand même." % VERSION)
		update_sure = true

## 0.49.1: a text file beside the game ("" when missing or unreadable), at most 4 lines of 200 letters.
func _fetch_text(url: String) -> String:
	var req = HTTPRequest.new()
	req.timeout = 6.0
	add_child(req)
	var out = ""
	if req.request(url) == OK:
		var res = await req.request_completed
		if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
			var lines: Array = []
			for l in (res[3] as PackedByteArray).get_string_from_utf8().split("\n"):
				var t = l.strip_edges()
				if t != "" and not t.begins_with("#"):
					lines.append(t.left(200))
			out = "\n".join(lines.slice(0, 4))
	req.queue_free()
	return out

## 0.49.1: at the start, a newer version online is offered in a window, once a session, on the home screen
## (later if it is not there yet: go("menu") asks again). « Mettre à jour »: the game reloads fresh (the save
## stays); « Plus tard »: the gear keeps its « ! » and Réglages its button.
func _offer_update() -> void:
	if update_offered or testing or not _update_ready():
		return
	if state != "menu" or modal != null:
		return
	update_offered = true
	var text = "Nouvelle version %s disponible !" % update_online
	if update_notes != "":
		text += "\n\n" + update_notes
	text += "\n\nLe jeu se recharge, ta partie est gardée."
	_confirm(text, _update_now, "Mettre à jour", "Plus tard")

## (0.68) « Donner mon avis »: the site's form, in the browser (or the phone's), the pseudo, the version and the
## platform after the # (filled in there, never sent by the browser itself).
func _send_feedback() -> void:
	var where = "web" if OS.has_feature("web") else OS.get_name().to_lower()
	var pseudo = str(save.get("online", {}).get("name", ""))
	var url = Net.page + "retours.html#pseudo=%s&v=%s&os=%s" % [pseudo.uri_encode(), VERSION.uri_encode(), where.uri_encode()]
	OS.shell_open(url)
	Audio.sfx("click")

## (0.64) « Changements »: reglages/changements.txt, the latest versions first.
func _show_changes() -> void:
	var out: Array = []
	for line in FileAccess.get_file_as_string("res://reglages/changements.txt").split("\n"):
		var t = line.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		out.append(("Version " + t.substr(1).strip_edges()) if t.begins_with("=") else "• " + t)
		if out.size() >= 14:
			break
	_confirm("\n".join(out), func() -> void: pass, "OK", "Fermer")

func _update_now() -> void:
	_upd_say("Rechargement…")
	_reload_fresh()

## The game again, fresh: the service worker and its cache go, the game's files are fetched anew (past
## the browser's own cache too), then the page reloads. The engine (index.wasm, 40 Mo) is kept: it only
## changes with Godot's version.
func _reload_fresh() -> void:
	_js("(async function () {" +
		" try { for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister(); } catch (e) {}" +
		" try { for (const k of await caches.keys()) await caches.delete(k); } catch (e) {}" +
		" for (const f of [location.href.split('#')[0], 'index.html', 'index.js', 'index.pck', 'index.service.worker.js', 'version.txt']) {" +
		" try { await fetch(f, { cache: 'reload' }); } catch (e) {} }" +
		" location.reload(); })()")

## A yes-or-no question to the browser. (Its answer is made a number first: a true or false coming
## back from JavaScript is not always a bool on Godot's side, and comparing it to one stops the script.)
func _js_yes(code: String) -> bool:
	var v = _js("(" + code + ") ? 1 : 0")
	return v != null and int(v) == 1

## Full screen where the browser has it (not on iPhone, where the game is added to the home screen
## instead); installed as an app it already fills the screen. Elsewhere, the window.
func _can_full() -> bool:
	if OS.has_feature("web"):
		return _js_yes("document.fullscreenEnabled && document.documentElement.requestFullscreen && !matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches")
	return not OS.has_feature("mobile")

## Hiding the tab pauses the run and silences the game; closing it keeps the coins picked up so far.
func _web_setup() -> void:
	if not OS.has_feature("web"):
		return
	fps_param = str(_js("location.search")).contains("fps")
	var doc = JavaScriptBridge.get_interface("document")
	var win = JavaScriptBridge.get_interface("window")
	var on_vis = JavaScriptBridge.create_callback(_on_visibility)
	var on_hide = JavaScriptBridge.create_callback(_on_pagehide)
	web_cbs.append_array([on_vis, on_hide])
	doc.addEventListener("visibilitychange", on_vis)
	win.addEventListener("pagehide", on_hide)

func _on_visibility(_args: Array) -> void:
	var hidden = _js_yes("document.hidden")
	if hidden:
		pause()
	Audio.sleep(hidden)

func _on_pagehide(_args: Array) -> void:
	if state == "play" or state == "pause" or in_run:
		bank()

# ---------- the shop ----------

func refresh_shop(just_bought: String = "") -> void:
	_set_coins(w["shop-coins"], save["coins"])
	for k in TABS:
		_shop_skin(w["tab-" + k], "tab", k == tab)
		w["tab-" + k].add_theme_font_size_override("font_size", roundi(5.5 * U))
	w["shop-title"].text = (TABS[tab] + (" · %d / %d" % [save["equipped"].size(), SaveData.MAX_EQUIPPED] if tab == "up" else "")).to_upper()
	var list: VBoxContainer = w["shop-list"]
	for ch in list.get_children():
		ch.queue_free()
	for ch in w["card-actions"].get_children():     # out at once: freed later, they would still widen the card
		w["card-actions"].remove_child(ch)
		ch.queue_free()
	_card_size.call_deferred()
	w["card-pips"].text = ""
	if tab == "mount":                               # a tab per animal; under it, its rows (on the road or not, its
		var open_k: String = picked_mount if picked_mount in Game.MOUNT_KINDS else str(SaveData.upgrade(picked_mount).get("mount", "gorilla"))
		var kinds = _hbox(4)                         # two upgrades), then the animal itself, big and alive
		kinds.mouse_filter = Control.MOUSE_FILTER_PASS
		for k in Game.MOUNT_KINDS:
			var mk: String = k
			var on_kind = func() -> void:
				picked_mount = mk
				refresh_shop()
			kinds.add_child(_kind_tab(Game.MOUNTS[k]["name"].to_upper(), k == open_k, k in save["mountsOff"], on_kind))
		list.add_child(kinds)
		var gap = Control.new()
		gap.custom_minimum_size.y = a(3)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(gap)
		var off_o: bool = open_k in save["mountsOff"]
		var tick = Button.new()                      # the box ticks or unticks at once; the row only picks
		tick.focus_mode = Control.FOCUS_NONE
		_kit_square(tick, "blank" if off_o else "check", 28)
		var on_tick = func() -> void:
			Audio.sfx("click")
			_toggle_mount(open_k)
		tick.pressed.connect(on_tick)
		var on_road = func() -> void:
			picked_mount = open_k
			refresh_shop()
		list.add_child(_row(null, "Sur le chemin", tick, picked_mount == open_k, 0, on_road))
		for u in SaveData.UPGRADES:
			if u.get("mount", "") == open_k:
				list.add_child(_up_row(u, picked_mount, just_bought))
		var stage = MountStage.new()
		stage.tex = Art.tex.get("mount-" + open_k, icon("mount-" + open_k))   # (with its worn skin)
		stage.frames = int(Art.meta["mounts"][open_k]["frames"])
		stage.flies = Game.MOUNTS[open_k].get("fly", false)
		stage.custom_minimum_size = Vector2(a(236), a(134))
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if off_o:
			stage.modulate = Color(0.45, 0.45, 0.52)
		list.add_child(stage)
		if picked_mount == open_k:
			_card(Game.MOUNTS[open_k]["name"], "Désactivée : elle ne t'attend plus sur le chemin." if off_o else "", MOUNT_TEXT[open_k])
			_show_demo("m-" + open_k, 1)
			var on_toggle = func() -> void:
				_toggle_mount(open_k)
			w["card-actions"].add_child(_button("Activer" if off_o else "Désactiver", "small on" if off_o else "small plain", on_toggle))
			return                                   # an animal's card
	if tab == "skin":
		_skins_tab(list)
		return
	Skins.apply(save["skins"]["worn"])               # (a skin looked at in the Skins tab: back to the worn ones)
	var full: bool = save["equipped"].size() >= SaveData.MAX_EQUIPPED
	var shown: Array = SaveData.UPGRADES.filter(func(u): return SaveData.family(u) == tab)
	shown.sort_custom(func(p, q): return p["unlock"] < q["unlock"] or (p["unlock"] == q["unlock"] and SaveData.UPGRADES.find(p) < SaveData.UPGRADES.find(q)))   # by the level they come at
	if tab != "mount" and not shown.any(func(u): return u["id"] == picked):
		picked = shown[0]["id"]
	var sel_id: String = picked_mount if tab == "mount" else picked
	if tab != "mount":                               # (the animals' upgrades are listed under them, above)
		for u in shown:
			list.add_child(_up_row(u, sel_id, just_bought))
	var u = SaveData.upgrade(sel_id)
	var st = _state_of(u)
	var status = ""
	if not SaveData.unlocked(save, u):
		status = "Se débloque au niveau %d, puis s'achète." % u["unlock"]
	elif st["locked"]:
		status = "Demande : " + SaveData.upgrade(u["needs"])["name"]
	elif u.get("power", false):
		status = "Pouvoir permanent, sans emplacement." if st["lvl"] == 0 else ("Désactivé." if st["off"] else "Actif.")
	elif st["on"]:
		status = "Équipé."
	elif st["lvl"] > 0:
		status = "Possédé. Les 3 emplacements sont pris." if full else "Possédé."
	else:
		status = "Bouton en jeu." if u["kind"] == "actif" else "Toujours actif une fois équipé."
	_card(u["name"], status, u["desc"])
	if u["costs"].size() > 1:
		w["card-pips"].text = _pips(u, st["lvl"])
	_show_demo(u["id"], st["lvl"])
	var acts: HBoxContainer = w["card-actions"]
	if st["lvl"] > 0 and st["cost"] >= 0:
		var b = _coin_button("Niv. %d · %d" % [st["lvl"] + 1, st["cost"]], func() -> void: _buy(u))
		b.custom_minimum_size.x = a(132)               # (alone; next to another button, see _fit_actions)
		b.disabled = save["coins"] < st["cost"]
		acts.add_child(b)
	if st["lvl"] == 0:
		var b = _coin_button(str(st["cost"]), func() -> void: _buy(u))
		b.disabled = st["locked"] or save["coins"] < st["cost"]
		acts.add_child(b)
	elif u.get("power", false):
		var on_power = func() -> void:
			SaveData.toggle_power(save, u["id"])
			refresh_shop()
		acts.add_child(_button("Activer" if st["off"] else "Désactiver", "small on" if st["off"] else "small plain", on_power))
	else:
		var on_equip = func() -> void:
			SaveData.toggle_equip(save, u["id"])
			refresh_shop()
		var b = _button("Retirer" if st["on"] else "Équiper", "small plain" if st["on"] else "small on", on_equip)
		b.disabled = not st["on"] and full
		acts.add_child(b)
	_fit_actions(acts, st, u)

## (0.58) What each kind of skin is, for its card.
const SKIN_TEXT := {"pepito": "Les mêmes feuilles, dans d'autres couleurs.", "shoes": "Ses baskets, dans d'autres couleurs.",
	"bag": "Son sac à dos, dans d'autres couleurs.", "scarf": "Une écharpe nouée au cou, qui flotte derrière lui.",
	"rotor": "Les feuilles de son hélice, quand il vole.", "trail": "Ce qu'il laisse derrière lui quand il court.",
	"jump": "Un éclat sous ses pieds quand il saute.", "fall": "Quand il tombe pour de bon : la tête plantée, et ça à côté.",
	"sign": "Ton panneau de record, tel que tes amis le voient sur leur route.", "ghost": "Ta couleur dans l'Affrontement, sur l'écran des autres.",
	"emote": "Des mots à dire à deux : le bouton « ! » pendant la course.",
	"buttons": "Les boutons de pierre d'avant, gravés et couverts de lianes."}

## The Skins tab (0.47): each target (Pépito, the mounts, the pygmies) under its name, its original look then
## its skins; a skin picked is shown at once (the preview, and the game behind); owned, it is worn with
## « Porter »; not owned, it comes out of the urns or is bought with coins. 0.58: grouped in the urns' three
## families (Pépito's look, effects, social) then the rest; the emotes are all owned at once (none worn).
func _skins_tab(list: VBoxContainer) -> void:
	w["shop-title"].text = "SKINS"
	var worn: Dictionary = save["skins"]["worn"]
	var owned: Array = save["skins"]["owned"]
	if picked_skin == "":
		picked_skin = "pepito:"
	var target: String = picked_skin.split(":")[0] if picked_skin.ends_with(":") else str(Skins.skin(picked_skin).get("target", "pepito"))
	var look: Dictionary = worn.duplicate()          # what is shown: the picked skin, over the worn ones
	if picked_skin.ends_with(":"):
		look.erase(target)
	else:
		look[target] = picked_skin
	Skins.apply(look)
	var fam_now = "-"
	for t in Skins.ORDER:
		var fam: String = Skins.TARGETS[t].get("family", "")
		if fam != fam_now:                           # (0.58) the family's title
			fam_now = fam
			for f in Skins.FAMILIES:
				if f[0] == fam:
					list.add_child(_label(f[1], ts("s"), GOLD, 1.5))
		var head = _label(Skins.TARGETS[t]["name"].to_upper(), ts("s"), RELIC, 1.5)
		list.add_child(head)
		var many: bool = Skins.TARGETS[t].get("many", false)
		if not many:
			var orig_id: String = t + ":"
			var orig_right = _note("Porté" if not worn.has(t) else "", RELIC)
			var on_orig = func() -> void:
				picked_skin = orig_id
				refresh_shop()
			list.add_child(_row(null, "Original" if fam in ["", "look"] else "Aucun", orig_right, picked_skin == orig_id, 0, on_orig))
		for sk in Skins.of_target(t):
			var id: String = sk["id"]
			var right: Control
			if worn.get(t, "") == id and not many:
				right = _note("Porté", RELIC)
			elif id in owned:
				right = _note("Possédé", DIM)
			else:
				right = _price(Treasure.skin_price(id), GOLD if int(save["coins"]) >= Treasure.skin_price(id) else DIM)
			var on_skin = func() -> void:
				picked_skin = id
				refresh_shop()
			var row = _row(null, sk["name"], right, picked_skin == id, 0, on_skin)
			list.add_child(row)
		if t == "buttons":                           # 0.50: a button of the look picked (or worn)
			var look_id = picked_skin if Skins.skin(picked_skin).get("target", "") == "buttons" else ("" if picked_skin == "buttons:" else str(worn.get("buttons", "")))
			var pic = TextureRect.new()
			var pic_path = "res://assets/img/ui-v2/%sbtn-normal-50.png" % ("" if look_id == "buttons-stone" else "wood/")
			pic.texture = load(pic_path) if ResourceLoader.exists(pic_path) else null
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.custom_minimum_size = Vector2(a(236), a(54))
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			list.add_child(pic)
		if t == "pygmies":                           # the pygmies have no preview run: one of them, alive
			var stage = MountStage.new()
			stage.tex = Art.tex.get("guard-club")
			stage.frames = 8
			stage.custom_minimum_size = Vector2(a(236), a(100))
			stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
			list.add_child(stage)
	var sk2 = Skins.skin(picked_skin)
	var acts: HBoxContainer = w["card-actions"]
	var many2: bool = Skins.TARGETS[target].get("many", false)
	if sk2.is_empty():
		_card(Skins.TARGETS[target]["name"] + " · Original", "Porté." if not worn.has(target) else "", "Le bois moussu de la forêt." if target == "buttons" else str(Skins.TARGETS[target].get("none", "Son allure de toujours.")))
		if worn.has(target):
			var on_plain = func() -> void:
				save["skins"]["worn"].erase(target)
				SaveData.store(save)
				Audio.sfx("click")
				if target == "sign" and Net.enabled():
					net.set_look(save, "")
				if target == "buttons":
					rebuild_due = true                   # the whole interface, at the next screen
				refresh_shop()
			acts.add_child(_button("Porter", "small on", on_plain))
	else:
		var rar: Dictionary = Skins.RARITIES[sk2["rarity"]]
		var have: bool = picked_skin in owned
		var on_now: bool = worn.get(target, "") == picked_skin
		var where = " · Dans les urnes, ou contre des pièces." if sk2["id"] in Skins.URN_LOOKS else " · Contre des pièces."
		_card(Skins.TARGETS[target]["name"] + " · " + sk2["name"], rar["name"] + ((" · Possédée : à toi, à deux." if have else where) if many2 else (" · Porté." if on_now else (" · Possédé." if have else where))), str(SKIN_TEXT.get(target, "Les mêmes images, dans d'autres couleurs.")))
		if have and not on_now and not many2:
			var on_wear = func() -> void:
				save["skins"]["worn"][target] = picked_skin
				SaveData.store(save)
				Audio.sfx("click")
				if target == "sign" and Net.enabled():  # (0.58) my board, as my friends will see it
					net.set_look(save, picked_skin)
				if target == "buttons":
					rebuild_due = true                   # the whole interface, at the next screen
				refresh_shop()
			acts.add_child(_button("Porter", "small on", on_wear))
		elif not have:
			var cost = Treasure.skin_price(picked_skin)
			var b = _coin_button(str(cost), func() -> void: _buy_skin(picked_skin))
			b.disabled = int(save["coins"]) < cost
			acts.add_child(b)
	_show_demo({"pepito": "sprint", "gorilla": "m-gorilla", "rhino": "m-rhino", "dragonfly": "m-dragonfly"}.get(target, "sprint"), 1)

func _buy_skin(id: String) -> void:
	var ok = Treasure.buy_skin(save, id)
	Audio.sfx("buy" if ok else "no")
	if ok:
		SaveData.store(save)
		confetti(14)
	refresh_shop()

## The Trésor (0.47): on the left the urns, broken one by one (a shake, then what came out, in the colour of
## its rarity); on the right the bag (0.55: the coins and the skins owned; one money only).
func _treasure() -> void:
	if not Treasure.identify(save).is_empty():        # (0.68) each urn won gets its rarity, shown as it is
		SaveData.store(save)
	if treasure != null:
		treasure.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	treasure = layer
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.75)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_panel("shop-preview-wide", 3))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 205, 14, 410, 292)
	var col = _vbox(6)
	var title = _label("TRÉSOR", ts("l"), GOLD, 1.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row = _hbox(14)
	var left = _vbox(5)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.custom_minimum_size.x = a(150)
	var urns = _hbox(4)                              # (0.68) the three rarities, each its own urn; the one to open chosen
	urns.alignment = BoxContainer.ALIGNMENT_CENTER
	for rk in ["common", "rare", "legendary"]:
		var cell = _vbox(1)
		cell.alignment = BoxContainer.ALIGNMENT_END
		var ub = Button.new()
		ub.flat = true
		ub.focus_mode = Control.FOCUS_NONE
		ub.custom_minimum_size = Vector2(a(46), a(60))
		ub.icon = icon("urn-" + rk)
		ub.expand_icon = true
		ub.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ub.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		ub.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ub.pressed.connect(func() -> void:
			if Treasure.count(save, rk) > 0 and not urn_busy:
				urn_pick = rk
				Audio.sfx("click")
				_treasure_fill())
		cell.add_child(ub)
		w["tr-u-" + rk] = ub
		var cl = _label("", ts("s"), Color(Treasure.COLOURS[rk]), 0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cl)
		w["tr-n-" + rk] = cl
		urns.add_child(cell)
	left.add_child(urns)
	w["tr-count"] = _label("", ts("s"), INK, 0)
	w["tr-count"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(w["tr-count"])
	var open = _button("Ouvrir", "gold", _break_urn)
	open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open.custom_minimum_size = Vector2(a(110), a(34))
	left.add_child(open)
	w["tr-open"] = open
	row.add_child(left)
	var right = _vbox(4)
	right.custom_minimum_size.x = a(196)
	right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_label("TON SAC", ts("s"), RELIC, 1.5))
	w["tr-bag"] = _vbox(3)
	right.add_child(w["tr-bag"])
	row.add_child(right)
	col.add_child(row)
	var close = _button("Fermer", "small plain", func() -> void: _close_treasure())
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close)
	p.add_child(col)
	root.add_child(p)
	_treasure_fill()

func _close_treasure() -> void:
	if treasure != null:
		treasure.queue_free()
		treasure = null
	urn_busy = false
	Audio.sfx("click")
	if state == "menu":
		refresh_menu()
	elif state == "shop":
		refresh_shop()

## The urns (0.68: by rarity, the one to open chosen) and the bag, as the save has them now.
func _treasure_fill() -> void:
	var nu = Treasure.total(save)
	if Treasure.count(save, urn_pick) <= 0:
		urn_pick = ""
		for rk in ["legendary", "rare", "common"]:   # the best there is, by default
			if Treasure.count(save, rk) > 0:
				urn_pick = rk
				break
	for rk in ["common", "rare", "legendary"]:
		var n = Treasure.count(save, rk)
		var ub: Button = w["tr-u-" + rk]
		ub.modulate = Color.WHITE if n > 0 else Color(0.35, 0.35, 0.4, 0.6)
		ub.scale = Vector2.ONE
		ub.pivot_offset = ub.size / 2
		var pick = rk == urn_pick
		w["tr-n-" + rk].text = ("× %d" % n) if n > 0 else "—"
		ub.add_theme_stylebox_override("normal", _flat(Color(1, 0.83, 0.36, 0.18), GOLD, 2.0) if pick else StyleBoxEmpty.new())
		ub.add_theme_stylebox_override("hover", ub.get_theme_stylebox("normal"))
		ub.add_theme_stylebox_override("pressed", ub.get_theme_stylebox("normal"))
	w["tr-count"].text = ("Urne %s choisie" % Treasure.NAMES[urn_pick].to_lower()) if urn_pick != "" else "Aucune urne : gagne des niveaux !"
	w["tr-open"].disabled = nu <= 0 or urn_busy
	var bagbox: VBoxContainer = w["tr-bag"]
	for ch in bagbox.get_children():
		bagbox.remove_child(ch)
		ch.queue_free()
	var lines: Array = [["coin-icon", "Pièces", str(int(save["coins"]))],
		["ico-star", "Collection des urnes", "%d / %d" % [save["skins"]["owned"].filter(func(id): return id in Skins.URN_LOOKS).size(), Skins.URN_LOOKS.size()]],
		["ico-star", "Autres skins", "%d / %d" % [save["skins"]["owned"].filter(func(id): return not id in Skins.URN_LOOKS).size(), Skins.CATALOG.size() - Skins.URN_LOOKS.size()]]]
	for ln in lines:
		var h = _hbox(5)
		h.add_child(_icon_rect(icon(ln[0]), 14))
		var l = _label(ln[1], ts("s"), INK, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_label(ln[2], ts("s"), GOLD, 0))
		bagbox.add_child(h)

## « Ouvrir » (0.68): an event, over everything (UrnShow): the urn of the rarity chosen comes to the middle, swells
## and shakes as its cracks let the light out, then bursts; what came out, one thing after the other. The rarer,
## the longer and the bigger (rays, shards, a fanfare, confetti for a legendary one).
func _break_urn() -> void:
	if urn_busy or Treasure.total(save) <= 0:
		return
	var res = Treasure.open(save, urn_pick)
	SaveData.store(save)
	if res.is_empty():
		_treasure_fill()
		return
	urn_busy = true
	w["tr-open"].disabled = true
	if res["got"].any(func(g): return g["what"] == "skin"):
		Skins.apply(save["skins"]["worn"])
	var show = UrnShow.new()
	show.size = Vector2(W, H)
	show.u = U
	show.rar = res["rarity"]
	show.got = res["got"]
	show.urn = icon("urn-" + res["rarity"])
	show.title_font = bold
	show.text_font = font
	show.sizes = [ts("xl"), ts("m"), ts("s")]
	show.colour = Color(Treasure.COLOURS[res["rarity"]])
	show.title = "URNE %s !" % Treasure.NAMES[res["rarity"]].to_upper()
	for g in res["got"]:
		show.icons.append(icon(g["icon"]))
	show.sound.connect(func(name: String) -> void: Audio.sfx(name))
	show.burst.connect(func() -> void:
		if res["rarity"] != "common":
			confetti(70 if res["rarity"] == "legendary" else 24))
	show.closed.connect(func() -> void:
		urn_busy = false
		show.queue_free()
		if treasure != null:
			_treasure_fill())
	treasure.add_child(show)

## (0.68) The opening of an urn, drawn over the Trésor. Its time: the urn coming to the middle (0.35 s), then
## the charge (CHARGE by rarity: it swells, shakes harder and harder, cracks three times, light and sparks
## through the cracks, rays turning behind it for a rare or a legendary one), the burst (a white flash, a ring,
## the urn in shards, a shake of the whole screen), then what came out, one after the other, each with its pop.
## A touch during the charge goes straight to the burst; once everything is out, a touch closes it.
class UrnShow extends Control:
	signal sound(name: String)
	signal burst
	signal closed
	const CHARGE := {"common": 1.1, "rare": 2.0, "legendary": 3.1}
	const COME := 0.35
	const ITEM_GAP := {"common": 0.35, "rare": 0.45, "legendary": 0.6}
	var u := 1.0
	var rar := "common"
	var got: Array = []
	var icons: Array = []
	var urn: Texture2D
	var title_font: Font
	var text_font: Font
	var sizes: Array = [26, 14, 11]
	var colour := Color.WHITE
	var title := ""
	var t := 0.0
	var burst_at := -1.0
	var shards: Array = []
	var sparks: Array = []
	var cracks: Array = []
	var shown := 0
	var heard := {}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var rng = RandomNumberGenerator.new()
		for k in 3:                                  # three cracks, each a zigzag from near the middle outwards
			var pts = PackedVector2Array()
			var ang = rng.randf_range(0, TAU)
			var at = Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.2))
			pts.append(at)
			for j in 4:
				ang += rng.randf_range(-0.7, 0.7)
				at += Vector2(cos(ang), sin(ang)) * rng.randf_range(0.1, 0.16)
				pts.append(at)
			cracks.append(pts)
		sound.emit("urnrise" + {"common": "1", "rare": "2", "legendary": "3"}[rar])
	func _charge() -> float:
		return CHARGE[rar]
	func _gui_input(e: InputEvent) -> void:
		var tap = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
		if not tap:
			return
		accept_event()
		if burst_at < 0 and t > COME:
			t = COME + _charge()                     # straight to the burst
		elif burst_at >= 0 and shown >= got.size() and t - burst_at > 0.6 + got.size() * ITEM_GAP[rar]:
			closed.emit()
		elif burst_at >= 0:
			t = burst_at + 0.6 + got.size() * ITEM_GAP[rar]   # everything out at once
	func _process(delta: float) -> void:
		t += delta
		var end_charge = COME + _charge()
		if burst_at < 0 and t >= end_charge:
			burst_at = t
			_explode()
		if burst_at < 0 and t > COME:                # sparks through the cracks
			var k = (t - COME) / _charge()
			var n = int(randf() < 0.3 + k * ({"common": 0.6, "rare": 1.2, "legendary": 2.0}[rar]))
			for i in n:
				sparks.append({"p": _mid() + Vector2(randf_range(-14, 14), randf_range(-20, 10)) * u * _scale(), "v": Vector2(randf_range(-60, 60), randf_range(-220, -80)) * u, "life": randf_range(0.4, 0.8), "t": 0.0, "c": colour.lerp(Color.WHITE, randf() * 0.6)})
		if burst_at >= 0:
			var since = t - burst_at
			var want = clampi(floori((since - 0.6) / ITEM_GAP[rar]) + 1, 0, got.size()) if since >= 0.6 else 0
			while shown < want:
				shown += 1
				sound.emit("itempop")
			if since > 0.6 + got.size() * ITEM_GAP[rar] + 0.1 and not heard.has("win"):
				heard["win"] = true
				sound.emit("urnwin" + {"common": "1", "rare": "2", "legendary": "3"}[rar])
		for s_ in shards:
			s_["t"] += delta
			s_["v"].y += 900 * u * delta
			s_["p"] += s_["v"] * delta
			s_["r"] += s_["w"] * delta
		for q in sparks:
			q["t"] += delta
			q["v"].y += 260 * u * delta
			q["p"] += q["v"] * delta
		sparks = sparks.filter(func(q): return q["t"] < q["life"])
		shards = shards.filter(func(s_): return s_["t"] < 1.6)
		queue_redraw()
	func _mid() -> Vector2:
		return Vector2(size.x / 2, size.y * 0.47)
	func _scale() -> float:                          # the urn's size: it comes in, then swells
		var come = clampf(t / COME, 0, 1)
		var k = clampf((t - COME) / _charge(), 0, 1) if burst_at < 0 else 1.0
		var top = {"common": 2.4, "rare": 2.8, "legendary": 3.2}[rar]
		return lerpf(0.6, 1.9, come * come * (3 - 2 * come)) + (top - 1.9) * k * k
	func _explode() -> void:
		sound.emit("urnburst")
		burst.emit()
		var n = {"common": 10, "rare": 16, "legendary": 24}[rar]
		var w_ = urn.get_width() if urn != null else 40
		var h_ = urn.get_height() if urn != null else 50
		for i in n:
			var sx_ = randf_range(0, w_ * 0.7)
			var sy_ = randf_range(0, h_ * 0.7)
			var ang = randf_range(0, TAU)
			var sp = randf_range(260, 620) * ({"common": 0.8, "rare": 1.0, "legendary": 1.3}[rar])
			shards.append({"src": Rect2(sx_, sy_, w_ * 0.3, h_ * 0.3), "p": _mid(), "v": Vector2(cos(ang), sin(ang) - 0.6) * sp * u, "r": 0.0, "w": randf_range(-9, 9), "t": 0.0})
		for i in n * 3:
			var ang = randf_range(0, TAU)
			sparks.append({"p": _mid(), "v": Vector2(cos(ang), sin(ang)) * randf_range(120, 520) * u, "life": randf_range(0.5, 1.1), "t": 0.0, "c": colour.lerp(Color.WHITE, randf() * 0.7)})
	func _draw() -> void:
		var mid = _mid()
		var shake = Vector2.ZERO
		var since = t - burst_at if burst_at >= 0 else -1.0
		if since >= 0 and since < 0.4:              # the whole screen shakes as it bursts
			var amp = {"common": 4.0, "rare": 7.0, "legendary": 11.0}[rar] * u * (1 - since / 0.4)
			shake = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		draw_set_transform(shake)
		draw_rect(Rect2(-40, -40, size.x + 80, size.y + 80), Color(6 / 255.0, 4 / 255.0, 16 / 255.0, 0.88 * clampf(t / 0.25, 0, 1)))
		var k = clampf((t - COME) / _charge(), 0, 1) if burst_at < 0 else 1.0
		# rays turning behind it: a rare one 8, a legendary one 16 and a second set the other way
		if rar != "common":
			var nr = 8 if rar == "rare" else 16
			var grow = k if burst_at < 0 else 1.0 + minf(1.0, since) * 0.6
			var ra = (90 + 220 * grow) * u
			for set_ in (2 if rar == "legendary" else 1):
				for i in nr:
					var a0 = t * (0.5 if set_ == 0 else -0.35) + i * TAU / nr
					var pts = PackedVector2Array([mid, mid + Vector2(cos(a0 - 0.09), sin(a0 - 0.09)) * ra, mid + Vector2(cos(a0 + 0.09), sin(a0 + 0.09)) * ra])
					draw_colored_polygon(pts, Color(colour.r, colour.g, colour.b, (0.16 if set_ == 0 else 0.1) * clampf(grow, 0, 1)))
		var glow_r = (30 + 70 * k) * u * (1.0 if burst_at < 0 else 1.0 + minf(1.0, since) * 1.5)
		for g in 4:
			draw_circle(mid, glow_r * (1.0 - g * 0.2), Color(colour.r, colour.g, colour.b, 0.08 + 0.05 * g))
		if burst_at < 0 and urn != null:             # the urn, swelling and shaking, its cracks glowing
			var sc = _scale() * u
			var amp = (1.0 + 5.0 * k * k) * u * ({"common": 1.0, "rare": 1.3, "legendary": 1.7}[rar]) if t > COME else 0.0
			var off = Vector2(sin(t * 47) * amp, cos(t * 39) * amp * 0.4)
			var rot = sin(t * 31) * 0.05 * k
			draw_set_transform(mid + off + shake, rot, Vector2(sc, sc))
			draw_texture(urn, Vector2(-urn.get_width() / 2.0, -urn.get_height() / 2.0))
			var lines = 0 if k < 0.35 else (1 if k < 0.65 else (2 if k < 0.88 else 3))
			for i in lines:
				var pts = PackedVector2Array()
				for q in cracks[i]:
					pts.append(Vector2(q.x * urn.get_width(), q.y * urn.get_height()))
				draw_polyline(pts, Color(1, 1, 1, 0.9), 1.6)
				draw_polyline(pts, Color(colour.r, colour.g, colour.b, 0.7), 3.0)
			draw_set_transform(shake)
		for s_ in shards:                            # the shards of the urn, spinning away
			if urn == null:
				break
			var sc2 = _scale() * u
			draw_set_transform(s_["p"] + shake, s_["r"], Vector2(sc2, sc2))
			var src: Rect2 = s_["src"]
			draw_texture_rect_region(urn, Rect2(-src.size / 2, src.size), src, Color(1, 1, 1, clampf(1.6 - s_["t"], 0, 1)))
			draw_set_transform(shake)
		for q in sparks:
			var a_ = 1.0 - q["t"] / q["life"]
			draw_rect(Rect2(q["p"] - Vector2(2, 2) * u, Vector2(4, 4) * u), Color(q["c"].r, q["c"].g, q["c"].b, a_))
		if since >= 0:
			if since < 0.5:                          # the flash, the ring
				draw_rect(Rect2(-40, -40, size.x + 80, size.y + 80), Color(1, 1, 1, 0.9 * (1 - since / 0.5) * ({"common": 0.5, "rare": 0.8, "legendary": 1.0}[rar])))
			if since < 0.8:
				draw_arc(mid, (20 + 520 * since) * u, 0, TAU, 64, Color(colour.r, colour.g, colour.b, 1 - since / 0.8), 6 * u)
			# the title, then what came out
			if since > 0.25 and title_font != null:
				var tk = clampf((since - 0.25) / 0.3, 0, 1)
				var tsz = int(sizes[0] * (1.0 + 0.4 * (1 - tk)))
				var tw = title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz).x
				var ty = size.y * 0.2
				for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 3)]:
					draw_string(title_font, Vector2(size.x / 2 - tw / 2, ty) + o * u, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(0.1, 0.06, 0.14, tk))
				draw_string(title_font, Vector2(size.x / 2 - tw / 2, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsz, Color(colour.r, colour.g, colour.b, tk))
			var n = got.size()
			var cw = 150.0 * u
			var ch = 44.0 * u
			var cols = mini(n, 2)
			for i in shown:
				var row_ = i / 2
				var col_ = i % 2
				var in_row = mini(cols, n - row_ * 2)
				var x = size.x / 2 - in_row * (cw + 10 * u) / 2 + col_ * (cw + 10 * u)
				var y = size.y * 0.5 + row_ * (ch + 8 * u)
				var appear = clampf((since - 0.6 - i * ITEM_GAP[rar]) / 0.25, 0, 1)
				var pop = 1.0 + 0.25 * sin(PI * appear) * (1 - appear * 0.5)
				var r_ = Rect2(x + cw / 2 * (1 - pop), y + ch / 2 * (1 - pop), cw * pop, ch * pop)
				draw_rect(r_.grow(2 * u), Color(0.1, 0.06, 0.14, appear))
				draw_rect(r_, Color(0.18, 0.13, 0.1, appear))
				draw_rect(Rect2(r_.position, Vector2(r_.size.x, 3 * u)), Color(colour.r, colour.g, colour.b, appear))
				var ic: Texture2D = icons[i] if i < icons.size() else null
				if ic != null:
					var ih = 30.0 * u * pop
					var iw = ih * ic.get_width() / maxf(1, ic.get_height())
					draw_texture_rect(ic, Rect2(r_.position.x + 7 * u, r_.position.y + (r_.size.y - ih) / 2, iw, ih), false, Color(1, 1, 1, appear))
				if text_font != null:
					var name_: String = str(got[i]["name"])
					draw_string(text_font, Vector2(r_.position.x + 44 * u, r_.position.y + r_.size.y / 2 + sizes[2] * 0.35), name_, HORIZONTAL_ALIGNMENT_LEFT, cw - 50 * u, sizes[2], Color(1, 0.97, 0.9, appear))
			if shown >= n and since > 0.6 + n * ITEM_GAP[rar] + 0.3 and text_font != null:
				var hint = "Touche pour continuer"
				var hw = text_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[2]).x
				draw_string(text_font, Vector2(size.x / 2 - hw / 2, size.y * 0.93), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[2], Color(0.79, 0.84, 0.76, 0.5 + 0.5 * absf(sin(t * 3))))
		draw_set_transform(Vector2.ZERO)

## An animal on the road or not (the Montures tab: its box, or its card's button).
func _toggle_mount(mk: String) -> void:
	if mk in save["mountsOff"]:
		save["mountsOff"].erase(mk)
	else:
		save["mountsOff"].append(mk)
	SaveData.store(save)
	refresh_shop()

## One of the Montures tab's three tabs (an animal): the one open in gold, an animal kept off the road greyed.
## Narrow (76 art pixels): the text may run over the plaque's gilded ends.
func _kind_tab(text: String, open: bool, off: bool, fn: Callable) -> Button:
	var b = _button(text, "gold" if open else "", fn)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = a(3)
		sb.content_margin_right = a(3)
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(a(76), a(38))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", ts("s"))
	b.mouse_filter = Control.MOUSE_FILTER_PASS        # a finger dragging over it scrolls the list, as on the rows
	if off:
		b.modulate = Color(0.7, 0.7, 0.75)
	return b

## The animal of the Montures tab, big and alive under its rows, on a warm glow (greyed by its owner when it
## stays off the road; the dragonfly floats). Drawn at the art's scale: 236 art pixels across.
class MountStage extends Control:
	var tex: Texture2D
	var frames := 4
	var flies := false
	var t := 0.0
	func _ready() -> void:
		var k = custom_minimum_size.x / 236.0
		var g = GradientTexture2D.new()
		g.width = 128
		g.height = 128
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var gr = Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.65])
		gr.colors = PackedColorArray([Color(1, 0.88, 0.47, 0.25), Color(1, 0.88, 0.47, 0.0)])
		g.gradient = gr
		var glow = TextureRect.new()
		glow.texture = g
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.show_behind_parent = true
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = Vector2(44 * k, 21 * k)
		glow.size = Vector2(150 * k, 110 * k)
		add_child(glow)
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		if tex == null:
			return
		var k = size.x / 236.0
		var fw = tex.get_width() / float(frames)
		var h = float(tex.get_height())
		var f = floori(t * 10) % frames
		var bob = sin(t * 3.0) * 2.5 if flies else 0.0
		var at = Vector2(roundf((size.x - fw * k) / 2), roundf((115 - h + bob) * k))
		draw_texture_rect_region(tex, Rect2(at, Vector2(fw, h) * k), Rect2(fw * f, 0, fw, h))

## The card back to its picture's size, once its new content is in (it never stretches): when the text is
## too long for it, the preview gets lower (and narrower, the same shape) by what is missing, half at most.
func _card_size() -> void:
	if not (w.has("card-panel") and is_instance_valid(w["card-panel"])):
		return
	var panel: Control = w["card-panel"]
	var view: Control = w["demo-view"]
	var full = Vector2(a(210), a(210 * Demo.H / Demo.W))
	view.custom_minimum_size = full
	var inside: Control = panel.get_child(0)
	var frame_h = panel.get_combined_minimum_size().y - inside.get_combined_minimum_size().y
	var over = inside.get_combined_minimum_size().y - (a(282) - frame_h)
	if over > 0:
		view.custom_minimum_size.y = maxf(full.y - over - a(1), full.y * 0.5)
	panel.size = Vector2(a(253), a(282))

## The card's buttons must fit inside it (210 art pixels): with two of them, the next level's button says
## less and less (« Niv. 2 · 6000 », « Niv.2 6000 », « 6000 »), and « Désactiver » becomes « Couper ».
func _fit_actions(acts: HBoxContainer, st: Dictionary, u: Dictionary) -> void:
	var kids = acts.get_children()
	if kids.size() < 2:
		return
	var up: Button = kids[0]
	var other: Button = kids[1]
	var room = a(210) - a(6)
	up.custom_minimum_size.x = 0
	for txt in ["Niv. %d · %d" % [st["lvl"] + 1, st["cost"]], "Niv.%d %d" % [st["lvl"] + 1, st["cost"]], str(st["cost"])]:
		up.text = txt
		if up.get_combined_minimum_size().x + other.get_combined_minimum_size().x <= room:
			return
	if other.text == "Désactiver":
		other.text = "Couper"

## A row of the shop's list for an upgrade: its picture, its name, its price or its state.
func _up_row(u: Dictionary, sel_id: String, just_bought: String) -> Button:
	var st = _state_of(u)
	var right: Control
	var gated = not SaveData.unlocked(save, u)
	if gated:
		right = _note("", DIM)                       # the blue ribbon says it
	elif st["lvl"] == 0:
		right = _price(st["cost"], GOLD if not st["locked"] else DIM)
	elif u.get("power", false):
		right = _note("Coupé" if st["off"] else "Actif", DIM if st["off"] else RELIC)
	elif st["on"]:
		right = _note("Équipé", RELIC)
	else:
		right = _note(_pips(u, st["lvl"]) if u["costs"].size() > 1 else "Possédé", DIM)
	var id: String = u["id"]
	var on_pick = func() -> void:
		if tab == "mount":
			picked_mount = id
		else:
			picked = id
		refresh_shop()
	var row = _row(icon("ico-" + u["icon"]), u.get("short", u["name"]), right, id == sel_id, u["unlock"] if gated else 0, on_pick)
	if st["locked"] and not gated:
		row.modulate = Color(0.7, 0.7, 0.75)
	if id == just_bought:
		row.modulate = GOLD
		create_tween().tween_property(row, "modulate", Color.WHITE, 0.5)
	return row

func _pips(u: Dictionary, lvl: int) -> String:
	return "●".repeat(lvl) + "○".repeat(u["costs"].size() - lvl)

## A short word on the right of a row.
func _note(text: String, colour: Color) -> Control:
	var l = _label(text, ts("s"), colour, 0)
	return l

## A price: the number and the coin, the same coin as at the top of the screen.
func _price(n: int, colour: Color) -> Control:
	var h = _hbox(3)
	h.add_child(_label(str(n), ts("s"), colour, 0))
	h.add_child(_icon_rect(icon("coin-icon"), 10))
	return h

## A gold button whose text ends with the coin.
func _coin_button(text: String, fn: Callable) -> Button:
	var b = _button(text, "small gold", fn)
	b.icon = icon("coin-icon")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_constant_override("icon_max_width", roundi(a(11)))
	b.add_theme_constant_override("h_separation", roundi(a(3)))
	b.custom_minimum_size.x = a(110)
	return b

## A row of the list: the picture, the name, a word or the price on the right. `gate` > 0: not unlocked
## yet, a blue ribbon across it says at which level.
func _row(tex: Texture2D, name: String, right: Control, sel: bool, gate: int, fn: Callable) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS        # a finger dragging over the rows scrolls the list
	b.custom_minimum_size = Vector2(a(236), a(30))
	_shop_skin(b, "item", sel)
	var h = _hbox(6)                                # the picture straight on the stone (no dark square since
	h.set_anchors_preset(Control.PRESET_FULL_RECT)  # 0.33), the name, the price or state 9 px off the right end
	h.offset_left = a(8)
	h.offset_right = -a(9)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	if tex != null:                                 # (« Sur le chemin » has no picture)
		var r = TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(a(26), a(24))
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if gate > 0:
			r.modulate = Color(0.45, 0.45, 0.5)
		h.add_child(r)
	var l = _label(name, ts("s"), (GOLD if sel else INK) if gate == 0 else DIM, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	h.add_child(l)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	b.add_child(h)
	if gate > 0:
		b.add_child(_ribbon("NIV. %d" % gate))
	var on_row = func() -> void:
		Audio.sfx("click")
		fn.call()
	b.pressed.connect(on_row)
	return b

## The blue ribbon across a locked row, tilted, at its right end: « NIV. 3 ».
func _ribbon(text: String) -> Control:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#2f6fe0")
	sb.border_color = LINE
	sb.set_border_width_all(roundi(a(1.5)))
	sb.content_margin_left = a(8)
	sb.content_margin_right = a(8)
	sb.content_margin_top = a(1)
	sb.content_margin_bottom = a(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = _label(text, ts("s"), Color.WHITE, 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size = Vector2(a(70), a(15))
	p.position = Vector2(a(236 - 78), a(7.5))
	p.pivot_offset = p.size / 2
	p.rotation = -0.21
	return p

func _state_of(u: Dictionary) -> Dictionary:
	var lvl = SaveData.level(save, u["id"])
	var on: bool = u["id"] in save["equipped"]
	var off: bool = u["id"] in save["powersOff"]
	var locked: bool = (u.has("needs") and SaveData.level(save, u["needs"]) == 0) or not SaveData.unlocked(save, u)
	return {"lvl": lvl, "on": on, "off": off, "cost": SaveData.next_cost(save, u), "locked": locked, "active": on or (u.get("power", false) and lvl > 0 and not off)}

func _card(name: String, status: String, desc: String) -> void:
	w["card-name"].text = name
	w["card-status"].text = status
	w["demo-desc"].text = desc

## A new preview only when another one is asked for: picking the same tile again lets it run on.
func _show_demo(id: String, lvl: int) -> void:
	if id != demo.shown or maxi(1, lvl) != demo.level or demo.run == null:
		demo.show_demo(id, lvl)

func _buy(u: Dictionary) -> void:
	var ok = SaveData.buy(save, u)
	Audio.sfx("buy" if ok else "no")
	if ok:
		confetti(14)
		picked = u["id"]
	refresh_shop(u["id"] if ok else "")

# ---------- runs ----------

## The record of the mode played.
func best_of(mode: String) -> int:
	return int(save["bestEndless"] if mode == "endless" else save["best"])

## Puts the run's coins in the bank and saves. Called once per run, whatever ends it.
func bank() -> void:
	if run == null or run.banked:
		return
	run.banked = true
	_roll_biome()                                    # the next Run illimitée, somewhere else maybe
	save["coins"] += run.gold
	save["loops"] += 1
	save["urns"] = int(save["urns"]) + run.urns
	if not run.debug and Net.enabled() and not run.daily:   # the friends' board (once the server is up)
		net.send_score(save, run.mode, floori(run.dist))
	if run.daily:
		Daily.claim(save, run.dist)                  # (0.57) the day's best (its own record, not Sans fin's)
	elif run.debug:
		pass                                         # in debug: no record
	elif run.mode == "endless":
		save["bestEndless"] = maxi(save["bestEndless"], floori(run.dist))
	else:
		save["best"] = maxi(save["best"], floori(run.dist))
	SaveData.store(save)

func go(name: String) -> void:
	if in_run:                                       # leaving the settings opened from the pause: back to the pause
		in_run = false
		if name == "menu":
			state = "pause"
			show_screen("pause")
			Audio.duck(true)
			return
	Audio.duck(name == "settings" and state == "pause")   # (the settings opened from the pause: still quiet)
	if state == "shop" and name != "shop":
		Skins.apply(save["skins"]["worn"])
	_menu_tip("")
	if name != "menu":
		_home_close()                                # (the list of modes, the objectives)
	_peek(false)
	_stop_over()
	if name == "settings" and state == "pause":
		in_run = true
	if name == "play":
		if not save["seenIntro"] and coop_start.is_empty() and race_start.is_empty():
			save["seenIntro"] = true
			SaveData.store(save)
			state = "intro"
			show_screen("intro")
			Audio.music("")
			return
		var co = coop_start
		coop_start = {}
		coop_last = not co.is_empty()
		var rs = race_start                           # (0.48: a race for four, the host's kit for all)
		race_start = {}
		var up = SaveData.loadout(save)                # only the three equipped upgrades come along
		if not rs.is_empty():
			up = {}
			for k in rs["up"]:
				up[str(k)] = int(rs["up"][k])
			run = Game.coop_run(up, int(rs["seed"]), int(rs["tier"]), false, "endless", bool(rs.get("sky", false)))
			run.race = true
			endless_biome = int(rs["biome"])
			if bool(rs.get("final", false)):             # (0.65) a treasure's last race: fast, three hearts, no coins
				Daily.apply(run, {"race": {"speed": FINAL_SPEED, "hearts": 3}, "kit": {}})
				run.no_coins = true
				run.daily = false
			elif str(rs.get("rule", "")) != "":          # (0.65) treasure, mystery: a rule of the Course du jour's
				var dd = Daily.of_day(str(rs["rule"]))
				Daily.apply(run, dd)
				run.daily = false
				if dd["race"].has("biome"):
					run.coop_biome_x = INF
			coop_owed = 0.0
			race_send_t = 0.0
		elif coop_last:                                  # for two: the same road (seed, scenery, tier) on both phones,
			var mode: String = co["mode"]              # and the host's items and powers on both (not added to the guest's)
			if mode == "story":                        # (0.49: Histoire, the host's pieces of the relic)
				up = Game.story_kit(int(save["relic"]))
			if coop.role == "guest":
				up = {}
				for k in co["up"]:
					up[str(k)] = int(co["up"][k])
			run = Game.coop_run(up, int(co["seed"]), int(co["tier"]), coop.role == "guest", mode)
			if mode == "endless":
				endless_biome = int(co["biome"])
			coop_owed = 0.0
			coop_send_t = 0.0
			coop.clear_states()
		else:
			if save["mode"] == "story":                # 0.49: Histoire's own kit (the relic's pieces), this attempt's talks
				up = Game.story_kit(int(save["relic"]))
				save["storyTry"] = int(save["storyTry"]) + 1
				Game.STORY_TRY = int(save["storyTry"])
				Game.STORY_CHAP = int(save["relic"])
			var day = Daily.of_day() if daily_on else {}
			if daily_on:                             # (0.57) the Course du jour: its seed, its items, its rule
				run = Game.new_run(day["kit"], "endless", int(day["seed"]))
			else:
				run = Game.new_run(up, save["mode"])
				if save["mode"] == "endless" and still != null:
					run.home_scene = still.home_scene    # (0.66) the scene the home screen showed goes on
			run.mounts = Game.MOUNT_KINDS.filter(func(k): return not k in save["mountsOff"])   # Montures: on / off
			if daily_on:
				run.biome = 0
				run.prev_biome = 0
				Daily.apply(run, day)
		run.view_w = render.view_w * Game.PIXEL
		run.signs = Game.signs_for(board_cache, run.mode, best_of(run.mode))   # (0.48: the records along the road)
		if run.daily:                                # (0.58) the day's tiers instead, as boards of their colours
			run.signs = Daily.tier_signs(Daily.of_day())
		if run.mode == "endless" and not run.daily:   # Jouer: in the scenery the home screen showed
			run.biome = endless_biome
			run.prev_biome = endless_biome
		levels_due.clear()
		over_info = {}
		Game.launch(run)                             # rumble, then the doorway blows out
		Debug.debug_run(run)                         # what the debug menu asks for, if anything
		dead_for = 0
		_fill_hud()
		photo = null
		photo_taken = false
		last_dist = 0
		for ch in w["toasts"].get_children():
			ch.queue_free()
		state = "play"
		show_screen("hud")
		run.knives = 0                               # (0.55: no knife in stock any more, the Couteau suisse is equipped)
		Progress.start_run(save)
		run_xp0 = save["xp"]                         # (the end counts the experience and moves the objectives from here)
		run_quests0 = save["quests"].map(func(q): return {"q": q, "p": float(q["p"])})
		progress({"runs": 1})
		hint(1 if save["loops"] < 2 else 0)          # the first escapes explain the one control
		Audio.music("")                              # silence for the rumble: the theme starts on the blast
		return
	if state == "pause" and not in_run:
		bank()
	hint(0)
	if name == "menu":
		refresh_menu()
		if not levels_due.is_empty():                # a run left from the pause: its levels, now
			show_levels.call_deferred()
		elif _update_ready() and not update_offered:  # 0.49.1: a newer version found while it was elsewhere
			get_tree().create_timer(0.4).timeout.connect(_offer_update)
	if name == "shop":
		refresh_shop()
	if name == "friends":
		refresh_friends()
		_load_friends()
	if name == "race":
		refresh_race()
	if name == "settings":
		_msg("")
		refresh_settings()
	Audio.music("" if name == "intro" else ("run" if in_run else "menu"))
	state = name
	if rebuild_due:
		_rebuild()
		return
	show_screen(name)

## The game as it is on screen now (the world only, without the HUD), once this frame is drawn.
func _take_photo() -> void:
	render.show_dead = true                          # he vanishes as he falls: in the photo he is still there
	await RenderingServer.frame_post_draw
	render.show_dead = false
	var im = game_vp.get_texture().get_image()
	if im != null:
		photo = ImageTexture.create_from_image(im)
		if w.has("over-pic"):
			w["over-pic"].texture = photo

## The photo of the fall over the whole screen; a touch anywhere puts it away.
func _show_photo() -> void:
	if photo == null:
		return
	var layer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var pic = TextureRect.new()
	pic.texture = photo
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = game_view.texture_filter
	pic.position = Vector2(W * 0.06, H * 0.06)
	pic.size = Vector2(W * 0.88, H * 0.88)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.pivot_offset = pic.size / 2
	pic.scale = Vector2(0.4, 0.4)
	layer.add_child(pic)
	create_tween().tween_property(pic, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var close = func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			layer.queue_free()
	shade.gui_input.connect(close)

func game_over() -> void:
	if run.race and race.role != "":                 # (even when the race was decided while he still ran)
		if race.running and not run.spectating and run.rivals.any(func(m): return not m.get("out", false)):
			_race_watch()                            # (0.55) the others still run: watch them
		elif not run.spectating:
			_race_over()
		return
	if run.coop:
		coop.send({"t": "end"})
	var record = not run.debug and floori(run.dist) > best_of(run.mode)
	bank()
	over_info = {"title": Game.pick(DEATHS), "record": record, "dist": floori(run.dist), "gold": run.gold, "debug": run.debug, "mode": run.mode}
	over_info["xp0"] = run_xp0
	over_info["xp1"] = save["xp"]
	hint(0)
	over_view(false)
	Audio.music("over")                              # the run's music winds down, the menu's comes in
	state = "tally"                                  # first the count, then (Suivant) the end screen
	show_screen("tally")
	tally_play()

## Fills the end screen from over_info: counting up the first time, at once when the screen is built
## again (the phone turned: the screens are made anew at the new size).
func over_view(count_up: bool) -> void:
	if over_info.is_empty():
		return
	var record: bool = over_info["record"]
	w["over-title"].text = over_info["title"]
	w["over-pic"].texture = photo
	w["over-shot"].visible = true
	_set_level(w["over-level"], true)
	_quest_cards(w["over-quests"])
	var dist: int = over_info["dist"]
	var gold: int = over_info["gold"]
	w["over-dist"].text = "%d m" % dist                # (counted on the tally just before)
	w["over-gold"].text = "+%d" % gold
	w["over-best"].text = "Debug : record non enregistré" if over_info["debug"] else ("★ Nouveau record ! ★" if record else "Record : %d m" % best_of(over_info["mode"]))
	_set_colour(w["over-best"], GOLD if record else DIM)
	w["over-best"].label_settings.font_size = ts("m") if record else ts("s")
	w["over-best"].set_meta("hop", record)

## « Rejouer »: after a run for two, the host starts the next one for both (the guest goes back home, where
## it will start); alone, again.
func _replay() -> void:
	if coop_last and coop.state == "ready":
		if coop.role == "host":
			_coop_go(str(over_info.get("mode", "endless")))
		else:
			go("menu")
			_coop_say("C'est %s qui relance." % _mate_name())
	else:
		go("play")

# ---------- Amis: the friend code, the week's board, and playing for two ----------

## A text field. On a phone (a browser on a touch screen), Godot's own field lies under the phone's keyboard,
## which hides it and sometimes types nothing at all: a touch opens the browser's own box instead (_ask_text,
## `ask` its question), and `done` runs as if OK had been pressed. Elsewhere, Entrée runs it too.
func _field(hint_: String, length: int, ask: String, done: Callable) -> LineEdit:
	var f = LineEdit.new()
	f.placeholder_text = hint_
	f.max_length = length
	f.custom_minimum_size = Vector2(a(140), a(24))
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_font_override("font", plain)             # read letter by letter: not the pixel typeface
	f.add_theme_font_size_override("font_size", tp("m"))
	f.add_theme_color_override("font_color", INK)
	f.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	var sb = _flat(Color("#141a30"), LINE)
	f.add_theme_stylebox_override("normal", sb)
	f.add_theme_stylebox_override("focus", _flat(Color("#141a30"), GOLD))
	f.add_theme_stylebox_override("read_only", sb)
	f.add_theme_color_override("font_uneditable_color", INK)
	var on_enter = func(_t: String) -> void:
		done.call()
	f.text_submitted.connect(on_enter)
	if _phone_web():
		f.editable = false
		f.virtual_keyboard_enabled = false
		var on_tap = func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				f.accept_event()
				var got = _ask_text(ask, f.text)
				if got is String and got.strip_edges() != "":
					f.text = got.strip_edges().left(length)
					done.call()
		f.gui_input.connect(on_tap)
	return f

## A browser on a touch screen (a phone, a tablet).
func _phone_web() -> bool:
	return OS.has_feature("web") and (DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios"))

## The browser's own box asks for a text (it stays readable above the phone's keyboard): null if cancelled.
func _ask_text(question: String, current: String):
	return JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(question), JSON.stringify(current)], true)

func _wrap(text: String, colour: Color) -> Label:
	var l = _label(text, ts("s"), colour, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = a(224)
	return l

## Amis (0.51), in three tabs along the top, one thing each: Liste d'amis (the list on the left, a friend's
## card or my own on the right: my code, QR, link, adding one), Groupe (the race group of up to four on the
## left, its races launched from the home screen, JOUER → AFFRONTEMENT, where the bets are made; playing for
## two on the right), Scores (the friends' ranking, Histoire or Sans fin, this week or ever; mine on the right).
const FR_TABS := [["list", "Liste d'amis"], ["group", "Groupe"], ["scores", "Scores"]]
var sc_mode := "endless"               # Amis > Scores: which records (endless, story)
var sc_week := true                    # ... this week's, or ever

func _build_friends() -> void:
	var s = _screen("friends", true)
	var back = _button("Retour", "", func() -> void: go("menu"))
	_place(back, M, 6, 152, 38)
	s.add_child(back)
	var tabs = _hbox(4)
	_place(tabs, 168, 7, 569 - M - 168, 36)
	for spec in FR_TABS:
		var key: String = spec[0]
		var on_tab = func() -> void:
			friends_tab = key
			fr_sel = ""
			refresh_friends()
		var b = _button(spec[1], "tab", on_tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		w["frtab-" + key] = b
	s.add_child(tabs)
	var left = _pane(s, false, 262)
	var col = _vbox(5)
	# Liste d'amis: each one a touch away from his card
	var fl = _vbox(4)
	var subs = _hbox(4)                                 # (0.57) Liste | Demandes
	for spec in [["list", "Liste"], ["req", "Demandes"]]:
		var key: String = spec[0]
		var sb = _button(spec[1], "tab", func() -> void:
			friends_sub = key
			refresh_friends())
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size.y = a(20)
		subs.add_child(sb)
		w["fl-" + key] = sb
	fl.add_child(subs)
	w["fr-count"] = _label("", ts("s"), RELIC, 0)
	fl.add_child(w["fr-count"])
	w["fr-list"] = _vbox(3)
	fl.add_child(w["fr-list"])
	var again = _button("Actualiser", "small", _load_friends)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fl.add_child(again)
	w["panel-list"] = fl
	col.add_child(fl)
	# Scores: the ranking
	var sc = _vbox(4)
	var modes = _hbox(4)
	for spec in [["story", "Histoire"], ["endless", "Sans fin"]]:
		var key: String = spec[0]
		var b = _button(spec[1], "tab", func() -> void:
			sc_mode = key
			refresh_friends())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(b)
		w["sc-" + key] = b
	sc.add_child(modes)
	var whens = _hbox(4)
	for spec in [["week", "Cette semaine"], ["ever", "Toujours"]]:
		var key: String = spec[0]
		var b = _button(spec[1], "tab", func() -> void:
			sc_week = key == "week"
			refresh_friends())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		whens.add_child(b)
		w["sc-" + key] = b
	sc.add_child(whens)
	w["sc-list"] = _vbox(2)
	sc.add_child(w["sc-list"])
	w["panel-scores"] = sc
	col.add_child(sc)
	left.add_child(_fixed(col))
	var right = _pane(s, true, 262)
	var rc = _vbox(5)
	var mine = _vbox(4)                                 # Liste: my card (code, QR, link, adding a friend)
	mine.add_child(_label("TON CODE AMI", ts("s"), RELIC, 0))
	w["fr-code"] = _plain(_label("…", ts("xl"), GOLD), "xl")
	mine.add_child(w["fr-code"])
	var share_row = _hbox(4)
	var qr_b = _button("Code QR", "small", _show_qr)
	qr_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_row.add_child(qr_b)
	var share_b = _button("Partager", "small", _share_link)
	share_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_row.add_child(share_b)
	mine.add_child(share_row)
	mine.add_child(_label("AJOUTER UN AMI", ts("s"), RELIC, 0))
	var add_row = _hbox(4)
	w["fr-add"] = _field("PEPI-XXXX", 9, "Le code de ton ami (PEPI-XXXX) :", _add_friend)
	add_row.add_child(w["fr-add"])
	add_row.add_child(_button("Ajouter", "small", _add_friend))
	mine.add_child(add_row)
	var scan_b = _button("Scanner son code QR", "small gold", _scan_qr)   # (0.57) the camera, in the game itself
	scan_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w["fr-scan"] = scan_b
	mine.add_child(scan_b)
	mine.add_child(_label("TON PSEUDO", ts("s"), RELIC, 0))
	var name_row = _hbox(4)
	w["fr-name"] = _field("Pépito", 16, "Ton pseudo (16 lettres au plus) :", _rename)
	name_row.add_child(w["fr-name"])
	name_row.add_child(_button("OK", "small", _rename))
	mine.add_child(name_row)
	w["fr-msg"] = _wrap("", DIM)
	mine.add_child(w["fr-msg"])
	w["fr-me"] = mine
	rc.add_child(mine)
	var card = _vbox(5)                                 # Liste: the friend chosen
	w["fr-big"] = _plain(_label("", ts("xl"), GOLD), "xl")
	card.add_child(w["fr-big"])
	w["fr-their-code"] = _plain(_label("", ts("s"), RELIC, 0), "s")
	card.add_child(w["fr-their-code"])
	w["fr-records"] = _wrap("", INK)
	card.add_child(w["fr-records"])
	w["fr-inv4"] = _button("Inviter dans le groupe", "small gold", func() -> void: _race_invite(fr_sel, _sel_name()))
	card.add_child(w["fr-inv4"])
	w["fr-inv2"] = _button("Inviter à deux", "small", func() -> void: _invite(fr_sel, _sel_name()))
	card.add_child(w["fr-inv2"])
	var low = _hbox(4)
	var back_me = _button("Ma fiche", "small plain", func() -> void:
		fr_sel = ""
		refresh_friends())
	back_me.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(back_me)
	var del = _button("Retirer", "small danger", func() -> void: _remove_friend(fr_sel, _sel_name()))
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(del)
	card.add_child(low)
	w["fr-card"] = card
	rc.add_child(card)
	var rq = _vbox(6)                                   # (0.57) Demandes: the one chosen, to accept or refuse
	w["rq-name"] = _plain(_label("", ts("xl"), GOLD), "xl")
	rq.add_child(w["rq-name"])
	w["rq-code"] = _plain(_label("", ts("s"), RELIC, 0), "s")
	rq.add_child(w["rq-code"])
	w["rq-text"] = _wrap("", INK)
	rq.add_child(w["rq-text"])
	var rq_row = _hbox(6)
	w["rq-yes"] = _button("Accepter", "small gold", func() -> void: _answer_request(req_sel, true))
	w["rq-yes"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rq_row.add_child(w["rq-yes"])
	w["rq-no"] = _button("Refuser", "small danger", func() -> void: _answer_request(req_sel, false))
	w["rq-no"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rq_row.add_child(w["rq-no"])
	rq.add_child(rq_row)
	w["rq-row"] = rq_row
	w["fr-reqcard"] = rq
	rc.add_child(rq)
	var co = _vbox(6)                                   # Groupe: playing for two (the same road, the bubble)
	co.add_child(_label("À DEUX", ts("s"), RELIC, 0))
	w["co-room"] = _plain(_label("", ts("huge"), GOLD), "huge")
	w["co-room"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	co.add_child(w["co-room"])
	w["co-text"] = _wrap("", INK)
	co.add_child(w["co-text"])
	w["co-host"] = _button("Créer un salon", "small", _coop_host)
	w["co-host"].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	co.add_child(w["co-host"])
	var join_row = _hbox(4)
	w["co-code"] = _field("ABCD", 4, "Les 4 lettres du salon :", _coop_join)
	join_row.add_child(w["co-code"])
	join_row.add_child(_button("Rejoindre", "small", _coop_join))
	w["co-join-row"] = join_row
	co.add_child(join_row)
	w["co-leave"] = _button("Quitter", "small plain", func() -> void: coop.leave())
	w["co-leave"].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	co.add_child(w["co-leave"])
	w["panel-duo"] = co
	rc.add_child(co)
	var me_sc = _vbox(6)                                # Scores: mine
	me_sc.add_child(_label("TOI", ts("s"), RELIC, 0))
	w["sc-mine"] = _vbox(6)
	me_sc.add_child(w["sc-mine"])
	me_sc.add_child(_wrap("Les records de tes amis t'attendent aussi sur des panneaux, le long de tes courses.", DIM))
	w["panel-myscores"] = me_sc
	rc.add_child(me_sc)
	right.add_child(_fixed(rc))
	w["fr-left"] = left
	w["fr-right"] = right
	_build_group_g1(s)

## (0.58) Amis → Groupe, the layout G1: four cards side by side (each one's look and name, HÔTE on the host's,
## how his link is: its delay, slow, linking again and how long his place still waits; « Expulser » on the
## guests' for the host), a free place shows « Inviter » (the friends to pick from); below, the group's code
## to give, « Créer un groupe », joining one by its letters, « Quitter le groupe ».
func _build_group_g1(s: Control) -> void:
	var g = Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(g, 0, 0, 569, 320)
	s.add_child(g)
	w["g1"] = g
	var row = _hbox(8)
	_place(row, 14, 52, 541, 136)
	for i in Race.SEATS:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", styles["box"])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var v = _vbox(3)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var tag = _label("", ts("s"), GOLD, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
		var av = TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		av.custom_minimum_size = Vector2(a(26), a(34))
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(av)
		var nm = _plain(_label("", ts("s"), INK, 0), "m")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.custom_minimum_size.x = a(110)
		v.add_child(nm)
		var cn = _hbox(4)
		cn.alignment = BoxContainer.ALIGNMENT_CENTER
		var bars = _hbox(1)
		bars.alignment = BoxContainer.ALIGNMENT_END
		for b in 3:
			var bar = ColorRect.new()
			bar.custom_minimum_size = Vector2(a(2), a(3 + 3 * b))
			bar.size_flags_vertical = Control.SIZE_SHRINK_END
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bars.add_child(bar)
		cn.add_child(bars)
		var ct = _label("", ts("s"), DIM, 0)
		cn.add_child(ct)
		v.add_child(cn)
		var k := i
		var kick = _button("Expulser", "small danger", func() -> void: _group_kick(k))
		kick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(kick)
		var inv = _button("Inviter", "small gold", _race_pick)
		inv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inv.visible = false
		kick.visible = false
		v.add_child(inv)
		card.add_child(v)
		row.add_child(card)
		w["g1-card-%d" % i] = {"box": card, "tag": tag, "av": av, "name": nm, "bars": bars, "conn": ct, "kick": kick, "inv": inv}
	g.add_child(row)
	var low = PanelContainer.new()
	low.add_theme_stylebox_override("panel", styles["box"])
	_place(low, 14, 196, 541, 116)
	var lh = _hbox(12)
	var lv = _vbox(3)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_label("LE GROUPE", ts("s"), RELIC, 0))
	w["g1-code"] = _plain(_label("", ts("xl"), GOLD, 0), "xl")
	lv.add_child(w["g1-code"])
	w["gr-text"] = _wrap("", DIM)
	w["gr-text"].custom_minimum_size.x = a(300)
	lv.add_child(w["gr-text"])
	lh.add_child(lv)
	var rv = _vbox(5)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	w["ra-host"] = _button("Créer un groupe", "small gold", func() -> void:
		quick_on = false
		_race_host(false))
	rv.add_child(w["ra-host"])
	w["ra-quick"] = _button("Partie rapide", "small gold", _race_quick)   # (0.66) strangers, in a race
	rv.add_child(w["ra-quick"])
	var rj = _hbox(4)
	w["ra-code"] = _field("ABCD", 4, "Les 4 lettres du groupe :", _race_join)
	rj.add_child(w["ra-code"])
	rj.add_child(_button("Rejoindre", "small", _race_join))
	w["ra-join-row"] = rj
	rv.add_child(rj)
	w["ra-leave"] = _button("Quitter le groupe", "small danger", func() -> void:
		race.leave()
		refresh_friends())
	rv.add_child(w["ra-leave"])
	lh.add_child(rv)
	low.add_child(lh)
	g.add_child(low)

## (0.58) « Expulser » (the host, before a race): after a yes, that guest is sent out of the group.
func _group_kick(k: int) -> void:
	var seat: Dictionary = race.seats.get(k, {})
	if seat.is_empty() or race.role != "host" or race.running:
		return
	_confirm("Retirer %s du groupe ? Il ne pourra revenir que si tu l'invites à nouveau." % str(seat.get("name", "ce joueur")), func() -> void:
		race.kick(k)
		refresh_friends(), "Expulser", "Annuler")

## (0.58) A link as the group's cards say it: its text and colour, and how many of its three bars are lit.
func _link_look(k: int) -> Dictionary:
	var l = race.link_of(k)
	if l.is_empty():
		return {"text": "", "colour": DIM, "lit": 0}
	match str(l["state"]):
		"away":
			var wait = int(l.get("wait", 0))
			return {"text": "reconnexion… %d:%02d" % [wait / 60, wait % 60] if wait > 0 else "reconnexion…", "colour": Color("#ff7a7a"), "lit": 1}
		"linking":
			return {"text": "connexion…", "colour": DIM, "lit": 0}
		"slow":
			return {"text": "lent · %d ms" % int(l["ms"]), "colour": GOLD, "lit": 2}
	var ms = int(l.get("ms", -1))
	return {"text": ("connecté · %d ms" % ms) if ms > 0 else "connecté", "colour": Color("#9dff7a"), "lit": 3}

## (0.58) The group's cards and the box below them, as things are (Amis → Groupe).
func _refresh_group_g1() -> void:
	if not w.has("g1-card-0"):
		return
	var can = Coop.supported()
	var rst = race.state
	var r_idle = rst in ["idle", "failed"]
	var host = race.role == "host"
	var may_invite = can and Net.enabled() and not race.running and race.role in ["", "host"]
	var pending = race.invited.values()
	for i in Race.SEATS:
		var c: Dictionary = w["g1-card-%d" % i]
		var seat: Dictionary = race.seats.get(i, {}) if not r_idle else {}
		var me_alone = r_idle and i == 0
		var there = not seat.is_empty() or me_alone
		var nm = ""
		var look = {"text": "", "colour": DIM, "lit": 0}
		var asked = false
		if me_alone:
			nm = "Toi"
			look["text"] = "pas encore de groupe"
		elif there:
			nm = "Toi" if i == race.me else str(seat.get("name", "?"))
			look = _link_look(i)
		elif not pending.is_empty() and host:
			nm = pending.pop_front()
			asked = true
			look["text"] = "invité…"
		c["tag"].text = "HÔTE" if there and i == 0 and not me_alone else ""
		c["av"].visible = there
		if there:
			var skin = str(seat.get("skin", "")) if not me_alone else str(save["skins"]["worn"].get("pepito", ""))
			c["av"].texture = _look(skin)
			c["av"].modulate = Color(1, 1, 1, 0.5) if look["lit"] == 1 else Color.WHITE
		c["name"].text = nm if (there or asked) else "PLACE LIBRE"
		_set_colour(c["name"], GOLD if nm == "Toi" else (INK if there or asked else DIM))
		c["conn"].text = look["text"]
		_set_colour(c["conn"], look["colour"])
		var bars: HBoxContainer = c["bars"]
		bars.visible = there and not me_alone
		for b in 3:
			(bars.get_child(b) as ColorRect).color = look["colour"] if b < int(look["lit"]) else Color(1, 1, 1, 0.18)
		c["kick"].visible = host and there and i != 0 and not race.running and not me_alone
		c["inv"].visible = not there and not asked and may_invite and i != 0
		c["box"].modulate = Color.WHITE if there or asked else Color(1, 1, 1, 0.7)
	w["g1-code"].text = race.room if not r_idle and race.room != "" else ""
	w["g1-code"].visible = w["g1-code"].text != ""
	w["ra-host"].visible = can and r_idle and Net.enabled()
	w["ra-quick"].visible = w["ra-host"].visible            # (0.66)
	w["ra-join-row"].visible = can and r_idle and Net.enabled()
	w["ra-leave"].visible = not r_idle
	var txt = ""
	if not can:
		txt = "Le groupe marche dans le navigateur, sur la page du jeu."
	elif not Net.enabled():
		txt = "Le serveur n'est pas encore en ligne."
	elif rst == "failed":
		txt = race.info
	elif r_idle:
		txt = "Touche une place libre pour inviter un ami, ou rejoins un groupe avec ses 4 lettres. Vos courses : accueil → JOUER → AFFRONTEMENT."
	elif rst in ["opening", "joining", "linking"]:
		txt = {"opening": "Ouverture du groupe…", "joining": "Recherche du groupe…", "linking": "Connexion avec l'hôte…"}[rst]
	elif host:
		txt = "Donne ces 4 lettres à un ami pour qu'il te rejoigne, ou touche une place libre. Vos courses : accueil → JOUER → AFFRONTEMENT."
	else:
		txt = "Vos courses : accueil → JOUER → AFFRONTEMENT."
	if group_note != "":
		txt = group_note
	w["gr-text"].text = txt

func refresh_friends() -> void:
	if not w.has("fr-code") or not is_instance_valid(w["fr-code"]):
		return
	if w.has("menu-friends") and is_instance_valid(w["menu-friends"]):
		w["menu-friends"].visible = Net.enabled()
	if friends_tab in ["friends"]:                   # (the tabs before 0.51)
		friends_tab = "list"
	elif friends_tab in ["coop", "race"]:
		friends_tab = "group"
	for spec in FR_TABS:
		_style_button(w["frtab-" + spec[0]], "tab sel" if spec[0] == friends_tab else "tab")
	w["frtab-group"].text = "Groupe · %d/%d" % [race.count(), Race.SEATS] if race.state == "lobby" else "Groupe"
	w["panel-list"].visible = friends_tab == "list"
	w["panel-scores"].visible = friends_tab == "scores"
	w["fr-left"].visible = friends_tab != "group"     # (0.58: Groupe has its own layout, G1)
	w["fr-right"].visible = friends_tab != "group"
	w["g1"].visible = friends_tab == "group"
	var on: Dictionary = save.get("online", {})
	w["fr-code"].text = on.get("code", "…")
	if w["fr-name"].text == "" and on.get("name", "") != "":
		w["fr-name"].text = on["name"]
	var sel = _friend(fr_sel)
	if sel.is_empty():
		fr_sel = ""
	var on_req = friends_sub == "req"
	if on_req and not requests["incoming"].any(func(e): return str(e.get("code", "")) == req_sel):
		req_sel = ""
	w["fr-me"].visible = friends_tab == "list" and ((not on_req and fr_sel == "") or (on_req and req_sel == ""))
	w["fr-card"].visible = friends_tab == "list" and not on_req and fr_sel != ""
	w["fr-reqcard"].visible = friends_tab == "list" and on_req and req_sel != ""
	_style_button(w["fl-list"], "tab sel" if not on_req else "tab")
	_style_button(w["fl-req"], "tab sel" if on_req else "tab")
	var n_in = requests["incoming"].size()
	w["fl-req"].text = ("Demandes · %d" % n_in) if n_in > 0 else "Demandes"
	if req_sel != "":
		var rqe: Dictionary = requests["incoming"].filter(func(e): return str(e.get("code", "")) == req_sel)[0]
		w["rq-name"].text = str(rqe.get("name", "?"))
		w["rq-code"].text = req_sel
		w["rq-text"].text = "veut être ton ami. Accepté, vous verrez vos records et pourrez vous inviter."
	w["panel-duo"].visible = false                   # (0.55) Groupe is the group only (for two: a friend's card)
	w["panel-myscores"].visible = friends_tab == "scores"
	coop.save = save
	race.save = save
	var st = coop.state
	var can = Coop.supported()
	var mate_name: String = coop.mate.get("name", "") if coop.mate.get("name", "") != "" else "ton ami"
	var idle = st in ["idle", "failed"]
	var dist = func(v) -> String: return ("%d m" % int(v)) if int(v) > 0 else "—"
	if fr_sel != "":
		w["fr-big"].text = str(sel.get("name", "?"))
		w["fr-their-code"].text = str(sel.get("code", ""))
		w["fr-records"].text = "Sans fin : %s (cette semaine %s)\nHistoire : %s (cette semaine %s)" % [dist.call(sel.get("endless", 0)), dist.call(sel.get("endless_week", 0)), dist.call(sel.get("best", 0)), dist.call(sel.get("week", 0))]
		w["fr-inv2"].visible = can and idle and Net.enabled()
		w["fr-inv4"].visible = can and Net.enabled() and not race.running and (race.role in ["", "host"])
	# Groupe, for two
	w["co-host"].visible = can and idle
	w["co-join-row"].visible = can and idle
	w["co-room"].text = coop.room if coop.role == "host" and st in ["waiting", "linking", "ready"] else ""
	w["co-room"].visible = w["co-room"].text != ""
	w["co-leave"].visible = not idle
	var txt = ""
	if not can:
		txt = "Jouer à deux marche dans le navigateur, sur la page du jeu."
	else:
		match st:
			"idle": txt = "La même route, l'équipement de celui qui invite ; si l'un tombe, l'autre le ramène de sa bulle. Invite un ami de ta liste (sa fiche), ou crée un salon et donne-lui ses 4 lettres."
			"opening": txt = "Ouverture du salon…"
			"waiting": txt = ("Invitation envoyée à %s. En attente de sa réponse… (ou donne-lui ces 4 lettres)" % coop.invited) if coop.invited != "" else "Donne ces 4 lettres à ton ami. En attente…"
			"joining": txt = "Recherche du salon…"
			"linking": txt = "Connexion avec %s…" % mate_name
			"ready": txt = ("Connecté avec %s ! Sur l'accueil, JOUER lance Histoire ou Sans fin pour vous deux." % mate_name) if coop.role == "host" else ("Connecté avec %s ! Il lance la course depuis l'accueil." % mate_name)
			"failed": txt = coop.info
	w["co-text"].text = txt
	_refresh_group_g1()
	# the list (0.57: each one's name and « Voir »), or the requests
	var holder: VBoxContainer = w["fr-list"]
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.queue_free()
	var n_friends = board.filter(func(e): return not e.get("me", false)).size()
	if on_req:
		w["fr-count"].text = "DEMANDES REÇUES · %d" % n_in
		if n_in == 0:
			holder.add_child(_wrap("Personne ne t'a demandé en ami pour l'instant." if Net.enabled() else "Le serveur n'est pas encore en ligne.", DIM))
		for e in requests["incoming"]:
			var code = str(e.get("code", ""))
			holder.add_child(_friend_row(str(e.get("name", "?")), "", code == req_sel, func() -> void:
				req_sel = code
				refresh_friends()))
		var outs: Array = requests["outgoing"]
		if not outs.is_empty():
			holder.add_child(_label("ENVOYÉES, EN ATTENTE", ts("s"), RELIC, 0))
			for e in outs:
				holder.add_child(_friend_row(str(e.get("name", "?")), "en attente", false, Callable()))
	else:
		w["fr-count"].text = "TES AMIS · %d" % n_friends
		if n_friends == 0:
			holder.add_child(_wrap("Ajoute un ami avec son code, son lien ou son code QR : vos records s'afficheront ici, et sur la route." if Net.enabled() else "Le serveur n'est pas encore en ligne.", DIM))
		for e in board:
			if e.get("me", false):
				continue
			var code = str(e.get("code", ""))
			holder.add_child(_friend_row(str(e.get("name", "?")), "", code == fr_sel, func() -> void:
				fr_sel = code
				refresh_friends()))
	# Scores
	for k in ["story", "endless"]:
		_style_button(w["sc-" + k], "tab sel" if sc_mode == k else "tab")
	_style_button(w["sc-week"], "tab sel" if sc_week else "tab")
	_style_button(w["sc-ever"], "tab sel" if not sc_week else "tab")
	var field = ("endless_week" if sc_week else "endless") if sc_mode == "endless" else ("week" if sc_week else "best")
	var ranked = board.duplicate()
	ranked.sort_custom(func(x, y): return int(x.get(field, 0)) > int(y.get(field, 0)))
	var sl: VBoxContainer = w["sc-list"]
	for ch in sl.get_children():
		sl.remove_child(ch)
		ch.queue_free()
	var my_place = 0
	var to_beat = ""
	for i in ranked.size():
		var e: Dictionary = ranked[i]
		var me = e.get("me", false)
		if me:
			my_place = i + 1
			if i > 0:
				to_beat = "%s · %s" % [ranked[i - 1].get("name", "?"), dist.call(ranked[i - 1].get(field, 0))]
		sl.add_child(_list_row("%d. %s" % [i + 1, "Toi" if me else str(e.get("name", "?"))], dist.call(e.get(field, 0)), me, Callable()))
	if ranked.is_empty():
		sl.add_child(_wrap("Pas encore de scores : ajoute des amis (Liste d'amis).", DIM))
	var mine_box: VBoxContainer = w["sc-mine"]
	for ch in mine_box.get_children():
		mine_box.remove_child(ch)
		ch.queue_free()
	var mode_name = "Sans fin" if sc_mode == "endless" else "Histoire"
	var my_best = int(save["bestEndless"]) if sc_mode == "endless" else int(save["best"])
	for pair in [["TON RECORD (%s)" % mode_name.to_upper(), dist.call(my_best), INK],
			["TA PLACE " + ("CETTE SEMAINE" if sc_week else "DE TOUJOURS"), ("%d / %d" % [my_place, ranked.size()]) if my_place > 0 else "—", GOLD],
			["À BATTRE", to_beat if to_beat != "" else ("personne : tu es devant !" if my_place == 1 else "—"), RELIC]]:
		mine_box.add_child(_label(pair[0], ts("s"), DIM, 0))
		mine_box.add_child(_label(pair[1], ts("m"), pair[2], 0))

## (0.57) A row of Amis's lists: the name, and « Voir » (or a word instead) on its right; the one chosen in gold.
func _friend_row(name: String, note: String, sel: bool, on_view: Callable) -> Control:
	var h = _hbox(6)
	var nm = _plain(_label(name, ts("s"), GOLD if sel else INK, 0), "m")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(nm)
	if on_view.is_valid():
		var v = _button("Voir", "tab sel" if sel else "tab", on_view)
		v.custom_minimum_size = Vector2(a(56), a(20))
		h.add_child(v)
	else:
		h.add_child(_label(note, ts("s"), DIM, 0))
	return h

## A row of a list (Amis): a name, a note on its right; the one chosen in gold. `fn` empty: not a button.
func _list_row(name: String, note: String, sel: bool, fn: Callable) -> Control:
	var row = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	_style_button(row, "tab sel" if sel else "tab")
	row.custom_minimum_size = Vector2(0, a(22))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h = _hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = a(6)
	h.offset_right = -a(6)
	var nm = _plain(_label(name, ts("s"), GOLD if sel else INK, 0), "m")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nm)
	var rec = _label(note, ts("s"), DIM, 0)
	rec.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rec)
	row.add_child(h)
	if fn.is_valid():
		row.pressed.connect(func() -> void:
			Audio.sfx("click")
			fn.call())
	else:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

## The friend of this code in the list as last heard ({} if none).
func _friend(code: String) -> Dictionary:
	if code == "":
		return {}
	for e in board:
		if str(e.get("code", "")) == code and not e.get("me", false):
			return e
	return {}

func _sel_name() -> String:
	return str(_friend(fr_sel).get("name", "ton ami"))

## « Retirer »: after a yes, both stop being friends (net.gd: friends/remove).
func _remove_friend(code: String, name: String) -> void:
	if code == "":
		return
	_confirm("Retirer %s de tes amis ? Vous ne verrez plus vos records et il ne pourra plus t'inviter. Tu pourras le rajouter avec son code." % name, func() -> void:
		var r = await net.remove_friend(save, code)
		fr_sel = ""
		w["fr-msg"].text = ("%s n'est plus dans tes amis." % name) if not r.has("error") else "Pas de réponse du serveur."
		await _load_friends())

## (0.57) « Scanner son code QR »: the phone's camera inside the game (a layer of the page over it, the
## browser's own reader, BarcodeDetector), never another page; what it reads (his link, or his code) asks
## him to be friends. 0.58: where the browser has no reader (iPhone, Firefox), jsQR does it (web/jsQR.js).
const SCAN_JS := """(function(){
if (window.jlScan) return 'busy';
window.jlScanResult = '';
var ov = document.createElement('div');
ov.style.cssText = 'position:fixed;left:0;top:0;right:0;bottom:0;z-index:99999;background:#0a0f14;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:sans-serif;color:#fff8e6;text-align:center';
var msg = document.createElement('div');
msg.textContent = 'Vise le code QR de ton ami';
msg.style.cssText = 'margin:10px 16px;font-size:18px';
var box = document.createElement('div');
box.style.cssText = 'position:relative;max-width:92vw;max-height:70vh';
var v = document.createElement('video');
v.setAttribute('playsinline', ''); v.setAttribute('muted', ''); v.muted = true;
v.style.cssText = 'display:block;max-width:92vw;max-height:70vh;border-radius:12px;background:#000';
var aim = document.createElement('div');
aim.style.cssText = 'position:absolute;left:20%;top:20%;width:60%;height:60%;border:3px solid #ffd35c;border-radius:12px;box-shadow:0 0 0 2000px rgba(0,0,0,0.25);pointer-events:none';
box.appendChild(v); box.appendChild(aim);
var b = document.createElement('button');
b.textContent = 'Annuler';
b.style.cssText = 'margin:14px;font-size:18px;padding:10px 28px;border-radius:10px;border:0;background:#ffd35c;color:#1a1024;font-weight:bold';
ov.appendChild(msg); ov.appendChild(box); ov.appendChild(b);
document.body.appendChild(ov);
var stream = null, timer = null, done = false;
function stop(res) {
  if (done) return; done = true;
  if (timer) clearInterval(timer);
  if (stream) stream.getTracks().forEach(function(t){ t.stop(); });
  ov.remove(); window.jlScan = null; window.jlScanResult = res;
}
window.jlScan = { stop: stop };
b.onclick = function(){ stop('cancel'); };
function fail(text, why) {
  msg.textContent = text;
  box.style.display = 'none'; b.textContent = 'Fermer'; b.onclick = function(){ stop(why); };
}
if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
  fail("Ce navigateur ne donne pas l'appareil photo à la page. Tape plutôt le code de ton ami (PEPI-XXXX).", 'unsupported');
  return 'unsupported';
}
var detect = null;
function camera() {
  navigator.mediaDevices.getUserMedia({video: {facingMode: 'environment'}, audio: false}).then(function(s){
    if (done) { s.getTracks().forEach(function(t){ t.stop(); }); return; }
    stream = s; v.srcObject = s; v.play().catch(function(){});
    timer = setInterval(function(){ if (v.readyState >= 2) detect(); }, 250);
  }).catch(function(){
    fail("Pas d'accès à l'appareil photo (autorise-le pour cette page), ou tape le code de ton ami.", 'denied');
  });
}
if ('BarcodeDetector' in window) {
  var det = new BarcodeDetector({formats: ['qr_code']});
  detect = function(){ det.detect(v).then(function(codes){ if (codes && codes.length) stop('ok:' + codes[0].rawValue); }).catch(function(){}); };
  camera();
} else {
  /* 0.58: where the browser has no reader of its own (iPhone, Firefox), jsQR (Apache 2.0, web/jsQR.js) reads
     the camera's pictures, fetched from beside the game the first time */
  var cv = document.createElement('canvas');
  var cx = cv.getContext('2d', {willReadFrequently: true});
  detect = function(){
    if (!window.jsQR || !v.videoWidth) return;
    var k = Math.min(1, 640 / Math.max(v.videoWidth, v.videoHeight));
    cv.width = Math.round(v.videoWidth * k); cv.height = Math.round(v.videoHeight * k);
    cx.drawImage(v, 0, 0, cv.width, cv.height);
    var px = cx.getImageData(0, 0, cv.width, cv.height);
    var r = window.jsQR(px.data, cv.width, cv.height, {inversionAttempts: 'dontInvert'});
    if (r && r.data) stop('ok:' + r.data);
  };
  if (window.jsQR) camera();
  else {
    msg.textContent = 'Préparation du lecteur…';
    var sc = document.createElement('script');
    sc.src = 'jsQR.js';
    sc.onload = function(){ if (!done) { msg.textContent = 'Vise le code QR de ton ami'; camera(); } };
    sc.onerror = function(){ fail("Le lecteur de codes QR n'a pas pu se charger (pas de réseau ?). Tape plutôt le code de ton ami.", 'unsupported'); };
    document.head.appendChild(sc);
  }
}
return 'started';
})()"""

func _scan_qr() -> void:
	if not OS.has_feature("web"):
		w["fr-msg"].text = "Le scanner marche dans le navigateur, sur la page du jeu."
		return
	_js("window.jlScan && window.jlScan.stop('cancel')")
	var r = _js(SCAN_JS)
	scanning = true
	if str(r) == "unsupported":
		w["fr-msg"].text = "Ce navigateur ne sait pas lire les codes QR : tape le code de ton ami."

## (0.57) What the scanner read, once it is closed (looked at every frame while it is open).
func _scan_tick() -> void:
	var got = str(_js("window.jlScanResult || ''"))
	if got == "" or got == "null":
		return
	scanning = false
	_js("window.jlScanResult = ''")
	if not got.begins_with("ok:"):
		if got == "denied" and w.has("fr-msg"):
			w["fr-msg"].text = "Pas d'accès à l'appareil photo : autorise-le pour cette page, ou tape le code."
		return
	var text = got.substr(3).strip_edges()
	var code = ""
	var at = text.to_upper().find("PEPI-")
	if at >= 0:
		code = text.to_upper().substr(at, 9)
	elif text.to_lower().find("ami=") >= 0:
		code = "PEPI-" + text.substr(text.to_lower().find("ami=") + 4, 4).to_upper()
	if code.length() != 9 or code == str(save.get("online", {}).get("code", "")):
		w["fr-msg"].text = "Ce code QR n'est pas celui d'un joueur de Jungle Loop."
		return
	Audio.sfx("quest")
	_confirm("Demander %s en ami ?" % code, func() -> void:
		go("friends")
		await _ask_friend(code))

## The friend link: the game's page with « ?ami=PEPI-XXXX »; opened (or scanned), it offers to add him.
func _friend_link() -> String:
	var code = str(save.get("online", {}).get("code", ""))
	var base = Net.page
	if OS.has_feature("web"):
		var here = JavaScriptBridge.eval("location.origin + location.pathname", true)
		if here is String and here.begins_with("https://"):
			base = here
	return "%s?ami=%s" % [base, code] if code != "" else ""

## « Partager »: the phone's share sheet (a browser that has one), or the link copied.
func _share_link() -> void:
	if not save.get("online", {}).has("code"):
		await net.identity(save)
		refresh_friends()
	var link = _friend_link()
	if link == "":
		w["fr-msg"].text = "Pas de réponse du serveur."
		return
	if OS.has_feature("web"):
		var how = JavaScriptBridge.eval("""(function(u){
			if (navigator.share) { navigator.share({title: 'Jungle Loop', text: 'Ajoute-moi dans Jungle Loop !', url: u}).catch(function(){}); return 1; }
			if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(u); return 2; }
			window.prompt('Ton lien pour tes amis :', u); return 3; })(%s)""" % JSON.stringify(link), true)
		w["fr-msg"].text = "Lien copié : envoie-le à ton ami." if int(how) == 2 else ""
		return
	DisplayServer.clipboard_set(link)
	w["fr-msg"].text = "Lien copié : envoie-le à ton ami."

## « Code QR »: the friend link as a QR code, big, for a friend's phone camera (qr.gd).
func _show_qr() -> void:
	if not save.get("online", {}).has("code"):
		await net.identity(save)
		refresh_friends()
	var link = _friend_link()
	if link == "":
		w["fr-msg"].text = "Pas de réponse du serveur."
		return
	var code = QR.encode(link)
	if code.is_empty():
		return
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.85)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var side = a(200)
	var pic = TextureRect.new()
	pic.texture = QR.texture(code, 1, 4)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.position = Vector2(W / 2 - side / 2, a(36))
	pic.size = Vector2(side, side)
	root.add_child(pic)
	var l = _plain(_label(str(save["online"].get("code", "")), ts("l"), GOLD), "l")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(l, 0, 8, 569, 24)
	root.add_child(l)
	var tip = _label("Fais-le lire par l'appareil photo de son téléphone.", ts("s"), INK, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(tip, 0, 244, 569, 14)
	root.add_child(tip)
	var close = _button("Fermer", "small", func() -> void: layer.queue_free())
	_place(close, 569 / 2.0 - 50, 264, 100, 30)
	root.add_child(close)

## The page was opened from a friend link (« ?ami=PEPI-XXXX »): add him? Asked once, the link then taken
## out of the address (a reload does not ask again).
func _check_friend_link() -> void:
	if not OS.has_feature("web") or not Net.enabled():
		return
	var got = JavaScriptBridge.eval("new URLSearchParams(location.search).get('ami') || ''", true)
	if not got is String or got == "":
		return
	JavaScriptBridge.eval("(function(){var u=new URL(location.href);u.searchParams.delete('ami');history.replaceState(null,'',u.pathname+u.search+u.hash);})()", true)
	var code = got.strip_edges().to_upper()
	if not code.begins_with("PEPI-"):
		code = "PEPI-" + code
	if code == str(save.get("online", {}).get("code", "")) or code.length() != 9:
		return
	_confirm("Demander %s en ami ?" % code, func() -> void:
		go("friends")
		await _ask_friend(code))

## The friends' records, for the boards along the road (quietly, at start: nothing is made on the server
## for a player who never went online).
func _refresh_board() -> void:
	if not Net.enabled() or not save.get("online", {}).has("id"):
		return
	var r = await net.friends(save)
	if r.has("me"):
		board = [r["me"]] + r.get("friends", [])
		board_cache = board

func _load_friends() -> void:
	if not Net.enabled():
		refresh_friends()
		return
	var r = await net.friends(save)
	if r.has("error"):
		w["fr-msg"].text = "Pas de réponse du serveur."
		refresh_friends()
		return
	board = [r["me"]] + r.get("friends", [])
	board_cache = board
	var q = await net.friend_requests(save)         # (0.57) and the requests
	if not q.has("error"):
		requests = {"incoming": q.get("incoming", []), "outgoing": q.get("outgoing", [])}
	refresh_friends()

## (0.57) « Accepter » / « Refuser » a request made to me.
func _answer_request(code: String, yes: bool) -> void:
	if code == "":
		return
	var r = await net.answer_friend(save, code, yes)
	req_sel = ""
	if w.has("fr-msg") and is_instance_valid(w["fr-msg"]):
		w["fr-msg"].text = ("Pas de réponse du serveur." if r.has("error") and r["error"] != "none" else
			(("%s est ton ami." if yes else "Demande de %s refusée.") % str(r.get("name", "ce joueur"))))
	Audio.sfx("buy" if yes else "click")
	await _load_friends()
	if yes:
		friends_sub = "list"
		refresh_friends()

## (0.57) A look for requests made to me (out of a run, every few seconds): a new one shows a window.
func _poll_requests() -> void:
	if invite_busy:
		return
	invite_busy = true
	var q = await net.friend_requests(save)
	invite_busy = false
	if q.has("error"):
		return
	requests = {"incoming": q.get("incoming", []), "outgoing": q.get("outgoing", [])}
	if state == "friends":
		refresh_friends()
	if req_box != null or invite_box != null or not state in INVITE_SCREENS:
		return
	for e in requests["incoming"]:
		var code = str(e.get("code", ""))
		if code == "" or req_seen.has(code):
			continue
		req_seen[code] = true
		_show_request(str(e.get("name", "")), code)
		return

## (0.57) « Léa veut être ton ami » : Voir (Amis → Liste d'amis → Demandes, her card) or Plus tard.
func _show_request(name: String, code: String) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	req_box = layer
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var col = _vbox(8)
	var who = _plain(_label(name if name != "" else "Un joueur", ts("l"), GOLD, 0), "l")
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(who)
	var what = _label("veut être ton ami !", ts("m"), INK, 0)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(what)
	var close = func() -> void:
		layer.queue_free()
		req_box = null
	var row = _hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var see = _button("Voir", "gold", func() -> void:
		close.call()
		friends_tab = "list"
		friends_sub = "req"
		req_sel = code
		go("friends"))
	see.custom_minimum_size = Vector2(a(110), a(30))
	row.add_child(see)
	var later = _button("Plus tard", "", close)
	later.custom_minimum_size = Vector2(a(110), a(30))
	row.add_child(later)
	col.add_child(row)
	p.add_child(col)
	_place(p, 569 / 2.0 - 130, 100, 260, 110)
	root.add_child(p)
	Audio.sfx("quest")

func _rename() -> void:
	var name = w["fr-name"].text.strip_edges()
	if name == "":
		return
	var r = await net.rename(save, name)
	w["fr-msg"].text = "Pseudo : %s." % r["name"] if r.has("name") else "Pas de réponse du serveur."
	_load_friends()

func _add_friend() -> void:
	var code = w["fr-add"].text.strip_edges().to_upper()
	if not code.begins_with("PEPI-"):
		code = "PEPI-" + code
	await _ask_friend(code)

## (0.57) Asks a player to be friends (his code): a request he accepts or refuses; friends at once if he had
## asked me. What happened is said under « Ajouter un ami ».
func _ask_friend(code: String) -> void:
	var r = await net.add_friend(save, code)
	if not w.has("fr-msg") or not is_instance_valid(w["fr-msg"]):
		return
	if r.has("error"):
		w["fr-msg"].text = {"unknown": "Aucun joueur n'a ce code.", "self": "C'est ton propre code !"}.get(r["error"], "Pas de réponse du serveur.")
		return
	w["fr-msg"].text = ("%s est ton ami." % r["name"]) if r.get("friends", false) else ("Demande envoyée à %s : il l'acceptera de son côté." % r["name"])
	w["fr-add"].text = ""
	_load_friends()

# ---------- the race for four (0.48, race.gd) ----------

## 0.55, the Affrontement (the races of the group): on top the four places (each one's look and name, ready
## or not, his bet); below, my bet (any number of coins, or one ready-made) and on whom, the items and powers
## of the races (the host's, for all) and the group's races so far (bets and distances); at the bottom « Prêt »
## for everyone and, once all are ready, « Lancer » for the host. My coins top right.
func _build_race() -> void:
	var s = _screen("race", true)
	var quit = _button("Quitter", "", _race_quit)
	_place(quit, M, 6, 120, 34)
	s.add_child(quit)
	_head(s, "Affrontement")
	w["rc-room"] = _plain(_label("", ts("s"), RELIC, 0), "s")
	w["rc-room"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(w["rc-room"], 569 - M - 160, 4, 160, 12)
	s.add_child(w["rc-room"])
	w["rc-coins"] = _coins_pill()
	w["rc-coins"].size_flags_horizontal = Control.SIZE_SHRINK_END
	var coins_row = _hbox(0)
	coins_row.alignment = BoxContainer.ALIGNMENT_END
	coins_row.add_child(w["rc-coins"])
	_place(coins_row, 569 - M - 160, 18, 160, 24)
	s.add_child(coins_row)
	var row = _hbox(8)                                   # (0.58, V1: places, then three equal panels apart)
	_place(row, 14, 46, 541, 76)
	w["rc-row"] = row
	for i in Race.SEATS:
		var box = PanelContainer.new()
		box.add_theme_stylebox_override("panel", styles["box"])
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var v = _vbox(1)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var av = TextureRect.new()
		av.texture = Art.tex.get("hero-body")
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		av.custom_minimum_size = Vector2(a(18), a(22))
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(av)
		var nm = _plain(_label("", ts("s"), INK, 0), "s")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.custom_minimum_size.x = a(110)
		v.add_child(nm)
		var sub = _label("", ts("s"), DIM, 0)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = a(110)
		v.add_child(sub)
		var bt = _label("", ts("s"), DIM, 0)             # (0.58) his bet, on its own line
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bt.custom_minimum_size.x = a(110)
		v.add_child(bt)
		w["rc-bt-%d" % i] = bt
		var inv = _button("Inviter", "small gold", _race_pick)
		inv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inv.visible = false                             # (shown on a free place only: all shown, the row would grow)
		v.add_child(inv)
		box.add_child(v)
		row.add_child(box)
		w["rc-box-%d" % i] = box
		w["rc-av-%d" % i] = av
		w["rc-nm-%d" % i] = nm
		w["rc-sub-%d" % i] = sub
		w["rc-inv-%d" % i] = inv
	s.add_child(row)
	var bet = PanelContainer.new()                      # my bet: how much, on whom
	bet.add_theme_stylebox_override("panel", styles["box"])
	_place(bet, 14, 128, 174, 108)
	var bv = _vbox(3)
	bv.add_child(_label("TA MISE", ts("s"), RELIC, 0))
	var amt = _hbox(4)
	w["rc-amount"] = _field("0", 8, "Ta mise, de 0 à 99 999 999 pièces :", _race_amount)
	w["rc-amount"].custom_minimum_size = Vector2(a(150), a(22))
	amt.add_child(w["rc-amount"])
	w["rc-amount"].text_changed.connect(func(_t) -> void: _race_amount(false))   # (0.64) applied as it is typed
	bv.add_child(amt)
	w["rc-stakes"] = _hbox(3)
	bv.add_child(w["rc-stakes"])
	bv.add_child(_label("SUR", ts("s"), RELIC, 0))
	w["rc-on"] = _hbox(3)
	bv.add_child(w["rc-on"])
	bet.add_child(bv)
	s.add_child(bet)
	w["rc-bet"] = bet
	var kitp = PanelContainer.new()                     # the race's items and powers (the host's, for all)
	kitp.add_theme_stylebox_override("panel", styles["box"])
	_place(kitp, 197.5, 128, 174, 108)
	var kv = _vbox(3)
	kv.add_child(_label("ÉQUIPEMENT DE LA COURSE", ts("s"), RELIC, 0))
	var grid = GridContainer.new()
	grid.columns = 8                                    # (0.64: smaller, more to a row: the rules stay inside)
	grid.add_theme_constant_override("h_separation", roundi(a(3)))
	grid.add_theme_constant_override("v_separation", roundi(a(2)))
	kv.add_child(grid)
	w["rc-kit"] = grid
	w["rc-kit-note"] = _label("", ts("s"), DIM, 0)
	w["rc-kit-note"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["rc-kit-note"].custom_minimum_size.x = a(150)
	kv.add_child(w["rc-kit-note"])
	var rr = _hbox(3)                                   # (0.61) the host's rules: the score, the end
	w["rc-score"] = _button("Distance", "tab", func() -> void:
		var ts_: Array = Race.TYPES                  # (0.65) Distance, Pièces, Trésor, Mystère
		race.set_rule("score", ts_[(ts_.find(str(race.rules.get("score", "dist"))) + 1) % ts_.size()]))
	w["rc-score"].custom_minimum_size = Vector2(a(60), a(20))
	rr.add_child(w["rc-score"])
	w["rc-end"] = _button("Dernier en vie", "tab", func() -> void:
		race.set_rule("end", "last" if race.rules.get("end", "last") == "open" else "open"))
	w["rc-end"].custom_minimum_size = Vector2(a(90), a(20))
	rr.add_child(w["rc-end"])
	kv.add_child(rr)
	w["rc-stake"] = _button("Mise individuelle", "tab", func() -> void:   # (0.63) individual or common stakes
		if race.rules.get("score", "") == "treasure":   # (0.65) a treasure: how many races
			var rr_: Array = Race.ROUNDS
			race.set_rule("rounds", rr_[(rr_.find(int(race.rules.get("rounds", 5))) + 1) % rr_.size()])
		else:
			race.set_rule("stake", "solo" if race.rules.get("stake", "solo") == "common" else "common"))
	w["rc-stake"].custom_minimum_size = Vector2(a(153), a(20))
	kv.add_child(w["rc-stake"])
	kitp.add_child(kv)
	s.add_child(kitp)
	w["rc-kitbox"] = kitp
	var hp = PanelContainer.new()                       # the group's races so far
	hp.add_theme_stylebox_override("panel", styles["box"])
	_place(hp, 381, 128, 174, 108)
	var hv = _vbox(2)
	hv.add_child(_label("HISTORIQUE", ts("s"), RELIC, 0))
	w["rc-hist"] = _vbox(1)
	var hsc = _fixed(w["rc-hist"])
	hsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsc.custom_minimum_size.y = a(84)
	hv.add_child(hsc)
	hp.add_child(hv)
	s.add_child(hp)
	w["rc-histbox"] = hp
	var res = PanelContainer.new()                      # (0.56) the race just run: everyone's distance, coins, bet
	res.add_theme_stylebox_override("panel", styles["box"])
	_place(res, 14, 128, 541, 108)
	var rv = _vbox(3)
	var rtop = _hbox(6)
	w["rc-res-title"] = _label("", ts("s"), GOLD, 0)
	w["rc-res-title"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtop.add_child(w["rc-res-title"])
	var rok = _button("Continuer", "small", func() -> void:
		race_seen = true
		refresh_race())
	rok.custom_minimum_size = Vector2(a(80), a(20))
	rtop.add_child(rok)
	rv.add_child(rtop)
	var rgrid = GridContainer.new()
	rgrid.columns = 6
	rgrid.add_theme_constant_override("h_separation", roundi(a(10)))
	rgrid.add_theme_constant_override("v_separation", roundi(a(3)))
	rv.add_child(rgrid)
	w["rc-res-grid"] = rgrid
	res.add_child(rv)
	s.add_child(res)
	w["rc-res"] = res
	w["rc-text"] = _label("", ts("m"), INK, 0)            # opening, linking, a race going on, what went wrong
	w["rc-text"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["rc-text"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(w["rc-text"], 18, 144, 166, 88)
	s.add_child(w["rc-text"])
	w["rc-ready"] = _button("Prêt", "go", _race_ready_toggle)
	w["rc-go"] = _button("Lancer", "play", _race_go)
	w["rc-go-note"] = _label("", roundi(ts("s") * 0.8), DIM, 0)   # (0.57) greyed: whom it waits for, very small
	w["rc-go-note"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["rc-go-note"].set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	w["rc-go-note"].offset_top = -a(11)
	w["rc-go-note"].offset_bottom = -a(2)
	w["rc-go-note"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	w["rc-go"].add_child(w["rc-go-note"])
	var acts = _hbox(14)                                 # (0.58) « Prêt ! » and « Lancer », under the panels, apart
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in [w["rc-ready"], w["rc-go"]]:
		b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, a(150))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		acts.add_child(b)
	_place(acts, 0, 320 - 8 - 58, 569, 58)
	s.add_child(acts)
	w["rc-wait"] = _label("", ts("s"), DIM, 0)
	w["rc-wait"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w["rc-wait"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(w["rc-wait"], 14, 240, 541, 12)
	s.add_child(w["rc-wait"])

## 0.55: Pépito in a skin (its id; "" the original), for the group's places and the home screen.
func _look(skin: String) -> Texture2D:
	if Skins.skin(skin).is_empty() or not Art.img.has("hero-body"):
		return Art.tex.get("hero-body") if not Skins.originals.has("hero-body") else Skins.originals["hero-body"]["tex"]
	if not look_cache.has(skin):
		look_cache[skin] = ImageTexture.create_from_image(Skins.recolour(Art.img["hero-body"], Skins.skin(skin)["rules"]))
	return look_cache[skin]

## The race screen as things are: the lobby (places, ready, bets, items, history), a race going on, the link.
func refresh_race() -> void:
	if not w.has("rc-wait") or not is_instance_valid(w["rc-wait"]):
		return
	var st = race.state
	var live = race.running
	var lobby = st == "lobby" and not live
	var host = race.role == "host"
	if host and not live:
		race.set_kit(SaveData.loadout(save))         # (the host's items and powers, for all: as they are now)
	w["rc-room"].text = ("Groupe %s" % race.room) if race.room != "" and host else ""
	var coins = int(save["coins"])
	_set_coins(w["rc-coins"], coins)
	var mine = race.my_seat()
	var pending = race.invited.values()
	var waiting: Array = []
	for i in Race.SEATS:
		var seat: Dictionary = race.seats.get(i, {})
		var there = not seat.is_empty()
		var av: TextureRect = w["rc-av-%d" % i]
		av.visible = there
		if there:
			av.texture = _look(str(seat.get("skin", "")))
		var nm = str(seat.get("name", "")) + (" (toi)" if i == race.me and there else "")
		var sub = ""
		var bt = ""
		var sub_c: Color = DIM
		var ready = there and seat.get("ready", false)
		if there:
			var d = int(seat.get("dist", 0))
			if seat.get("away", false):
				var look = _link_look(i)
				sub = look["text"]
				sub_c = look["colour"]
			elif live:
				sub = ("tombé à %d m" % d) if seat.get("done", false) else ("%d m" % d)
			else:
				var b = int(seat.get("bet", 0))
				var on = int(seat.get("on", i))
				var on_name = "lui" if on == i else ("toi" if on == race.me else str(race.seats.get(on, {}).get("name", "?")))
				sub = "PRÊT" if ready else "PAS PRÊT"
				sub_c = Color("#9dff7a") if ready else DIM
				bt = ("%d sur %s" % [b, on_name]) if b > 0 else "sans mise"
				if not ready:
					waiting.append("toi" if i == race.me else str(seat.get("name", "?")))
		elif not pending.is_empty() and host:
			nm = pending.pop_front()
			sub = "invité…"
		var free = not there and nm == ""
		w["rc-nm-%d" % i].text = "PLACE LIBRE" if free else nm
		w["rc-nm-%d" % i].set_meta("search", free and quick_on)   # (0.68) « Recherche… », moving (_process)
		if not (free and quick_on):
			w["rc-nm-%d" % i].modulate.a = 1.0
		_set_colour(w["rc-nm-%d" % i], Race.COLOURS[i] if there else DIM)
		w["rc-sub-%d" % i].text = sub
		_set_colour(w["rc-sub-%d" % i], sub_c)
		w["rc-bt-%d" % i].text = bt
		w["rc-bt-%d" % i].visible = bt != ""
		w["rc-inv-%d" % i].visible = free and host and lobby
		w["rc-box-%d" % i].modulate = Color.WHITE if there or not free else Color(1, 1, 1, 0.7)
	(w["rc-row"] as Control).size.y = a(76)             # (0.58: never taller than its place, over the panels)
	var recap = lobby and not race_seen and not race.history.is_empty()   # (0.56) the end screen of the race just run
	w["rc-res"].visible = recap
	w["rc-kitbox"].visible = not recap
	w["rc-histbox"].visible = not recap
	if recap:
		_race_recap(race.history[0])
	w["rc-bet"].visible = lobby and race.seats.has(race.me) and not recap
	if lobby:
		for holder in [w["rc-stakes"], w["rc-on"]]:
			for ch in holder.get_children():
				holder.remove_child(ch)
				ch.queue_free()
		var my_bet = int(mine.get("bet", 0))
		var my_on = int(mine.get("on", race.me))
		for n in Race.stakes:
			var nn = int(n)
			var sb = _button(str(nn), "tab sel" if nn == my_bet else "tab", func() -> void:
				race_seen = true
				race.bet(int(race.my_seat().get("on", race.me)), mini(nn, int(save["coins"])), false)
				w["rc-amount"].text = str(int(race.my_seat().get("bet", 0))))
			sb.custom_minimum_size = Vector2(a(38), a(20))
			sb.disabled = nn > coins or (race.rules.get("stake", "solo") == "common" and race.role != "host")
			w["rc-stakes"].add_child(sb)
		var all_in = mini(Race.BET_MAX, coins)          # (0.61) « Tout »: every coin he has
		var ab = _button("Tout", "tab sel" if my_bet > 0 and my_bet == all_in else "tab", func() -> void:
			race_seen = true
			race.bet(int(race.my_seat().get("on", race.me)), mini(Race.BET_MAX, int(save["coins"])), true)
			w["rc-amount"].text = str(int(race.my_seat().get("bet", 0))))
		ab.custom_minimum_size = Vector2(a(38), a(20))
		ab.disabled = coins <= 0
		w["rc-stakes"].add_child(ab)
		var order = race.seats.keys()
		order.sort()
		for k in order:
			var kk = int(k)
			var label = "Toi" if kk == race.me else str(race.seats[kk].get("name", "?")).left(6)
			var ob = _button(label, "tab sel" if kk == my_on else "tab", func() -> void:
				race_seen = true
				race.bet(kk, int(race.my_seat().get("bet", 0))))
			ob.custom_minimum_size = Vector2(a(40), a(20))
			ob.disabled = race.rules.get("stake", "solo") == "common" and kk != race.me
			w["rc-on"].add_child(ob)
		if not w["rc-amount"].has_focus():
			w["rc-amount"].text = str(my_bet)
	var rtype = str(race.rules.get("score", "dist"))
	w["rc-score"].text = Race.TYPE_NAMES.get(rtype, "Distance")   # (0.61, 0.65) the rules
	w["rc-end"].text = "Illimité" if race.rules.get("end", "last") == "open" else "Dernier en vie"
	w["rc-score"].disabled = not host or not lobby
	w["rc-end"].disabled = not host or not lobby
	var common = race.rules.get("stake", "solo") == "common"
	w["rc-stake"].text = ("Trésor : %d courses" % int(race.rules.get("rounds", 5))) if rtype == "treasure" else ("Mise commune" if common else "Mise individuelle")
	w["rc-stake"].disabled = not host or not lobby
	var locked = common and not host                   # (0.63) common: the host's bet for all, or « Tout »
	w["rc-amount"].editable = not locked
	var grid: GridContainer = w["rc-kit"]               # the race's items and powers
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()
	var kit: Dictionary = race.kit if not race.kit.is_empty() or not host else SaveData.loadout(save)
	var rpick = str(race.rules.get("pick", ""))       # (0.65) treasure, mystery: the rule's own kit (mystery: once revealed)
	var hidden = rtype == "mystery" and not race.all_ready()
	if race.treasure_final():
		kit = {}
	elif rpick != "" and not hidden:
		kit = Daily.of_day(rpick)["kit"]
	for u in SaveData.UPGRADES:
		var lv = int(kit.get(u["id"], 0))
		if lv <= 0:
			continue
		var cell = _icon_rect(icon("ico-" + u["icon"]), 15)
		cell.tooltip_text = "%s (niv. %d)" % [u["name"], lv]
		var lvl = _label(str(lv), ts("s"), GOLD, 0)
		lvl.position = Vector2(a(10), a(7))
		cell.add_child(lvl)
		grid.add_child(cell)
	var note = "Aucun." if grid.get_child_count() == 0 else ""   # (0.63: room for the rules)
	if rtype == "mystery":
		note = "Règle : ??? (révélée quand tous ont validé)" if hidden else "Règle : %s — %s" % [Daily.of_day(rpick)["rule"]["name"], Daily.of_day(rpick)["rule"]["desc"]]
	elif race.treasure_final():
		note = "Trésor, dernière course : vitesse, 3 cœurs, sans pièces. Cagnotte %d" % int(race.rules.get("pot", 0))
	elif rtype == "treasure" and rpick != "":
		note = "Trésor %d/%d : %s · cagnotte %d" % [int(race.rules.get("series", 0)) + 1, int(race.rules.get("rounds", 5)), Daily.of_day(rpick)["rule"]["name"], int(race.rules.get("pot", 0))]
	w["rc-kit-note"].text = note
	w["rc-kit-note"].visible = note != ""
	if rtype == "mystery" and not hidden and rpick != "" and mystery_shown != rpick and lobby and modal == null:
		mystery_shown = rpick                         # (0.65) everyone validated: the rule, revealed
		var rr = Daily.of_day(rpick)["rule"]
		_confirm("Règle révélée : %s\n\n%s" % [rr["name"], rr["desc"]], func() -> void: pass, "OK", "Fermer")
	var hist: VBoxContainer = w["rc-hist"]               # the group's races, the latest first
	for ch in hist.get_children():
		hist.remove_child(ch)
		ch.queue_free()
	if race.history.is_empty():
		hist.add_child(_wrap("Pas encore de course.", DIM))
	for e in race.history:                               # (0.58) a small table per race: who, how far, what the bet gave
		hist.add_child(_label("COURSE %d" % int(e["n"]), ts("s"), GOLD, 0))
		var tab = GridContainer.new()
		tab.columns = 3
		tab.add_theme_constant_override("h_separation", roundi(a(8)))
		tab.add_theme_constant_override("v_separation", roundi(a(1)))
		for r_ in e["rows"]:
			var k = int(r_["k"])
			var who = ("Toi" if k == race.me else str(r_["name"]).left(7)) + (" ★" if r_["win"] else "")
			var wl = _label(who, ts("s"), Race.COLOURS[k % Race.COLOURS.size()] if k != race.me else INK, 0)
			wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_child(wl)
			tab.add_child(_label("%d m" % int(r_["dist"]), ts("s"), DIM, 0))
			var b = int(r_["bet"])
			var gain = (int(r_["got"]) - b) if int(r_["got"]) > 0 else -b
			var gl = _label(("+%d" % gain if gain > 0 else "%d" % gain) if b > 0 else "—", ts("s"), (Color("#9dff7a") if gain > 0 else Color("#ff7a7a")) if b > 0 else DIM, 0)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tab.add_child(gl)
		hist.add_child(tab)
	var text = ""
	if st == "failed":
		text = race.info
	elif st in ["opening", "joining", "linking"]:
		text = {"opening": "Ouverture du groupe…", "joining": "Recherche du groupe…", "linking": "Connexion avec l'hôte…"}[st]
		if race.relink_t >= 0:
			text = "La connexion a sauté : on se reconnecte…"
	elif live:
		if not race_start.is_empty():
			text = "Départ dans %d…" % ceili(maxf(0.0, float(race_start["at"]) - time))
		elif mine.get("done", false):
			text = "Tu es tombé à %d m. En attente des autres…" % int(mine.get("dist", 0))
		else:
			text = "Course en cours…"
	if race_note != "":
		text = race_note + ("\n" + text if text != "" else "")
	w["rc-text"].text = text
	w["rc-text"].visible = text != "" and not (lobby and race.seats.has(race.me))
	var my_ready = bool(mine.get("ready", false))
	w["rc-ready"].visible = lobby and race.seats.has(race.me) and not recap
	var mystery = str(race.rules.get("score", "")) == "mystery"   # (0.65) « Valider »: no way back
	w["rc-ready"].text = ("Validé" if my_ready else "Valider") if mystery else ("Plus prêt" if my_ready else "Prêt !")
	w["rc-ready"].disabled = mystery and my_ready
	_style_button(w["rc-ready"], "" if my_ready else "go")
	w["rc-go"].visible = lobby and race.seats.has(race.me) and not recap   # (0.57: for all, greyed until it can go)
	w["rc-go"].disabled = not (host and race.all_ready())
	w["rc-go-note"].text = "" if not w["rc-go"].disabled else ("attente de l'hôte" if not host else "attente des joueurs")
	var wait = ""
	if not race_seen and not race.history.is_empty():   # the race just run: who won, what I get
		var last: Dictionary = race.history[0]
		var winners = last["rows"].filter(func(r_): return r_["win"]).map(func(r_): return "Toi" if int(r_["k"]) == race.me else str(r_["name"]))
		if winners == ["Toi"]:
			wait = "Course %d : tu gagnes !" % int(last["n"])
		else:
			wait = "Course %d : %s %s !" % [int(last["n"]), " et ".join(winners), "gagnent" if winners.size() > 1 else "gagne"]
		for r_ in last["rows"]:
			if int(r_["k"]) == race.me and int(r_["bet"]) > 0:
				wait += " Ta mise : %d, tu reçois %d." % [int(r_["bet"]), int(r_["got"])]
	elif lobby and host and race.count() < 2:
		wait = "Invite au moins un ami (ou donne-lui les 4 lettres du groupe)."
	elif lobby and not waiting.is_empty():
		wait = "Pas encore prêt : %s." % ", ".join(waiting)
	elif lobby and not host:
		wait = "Tout le monde est prêt : %s lance la course." % str(race.seats.get(0, {}).get("name", "l'hôte"))
	elif lobby:
		wait = "Tout le monde est prêt !"
	w["rc-wait"].text = wait
	w["rc-wait"].visible = wait != ""

## (0.56) The end screen of a race, for everyone: distance (the winner starred), coins picked up (kept), the
## bet and on whom, what the bet gave (twice it, or lost), and all of it together.
func _race_recap(e: Dictionary) -> void:
	w["rc-res-title"].text = "COURSE %d · RÉSULTAT" % int(e["n"])
	_fill_recap(w["rc-res-grid"], e["rows"])

## (0.57) The recap's table in `grid` (6 columns): rows of {k, name, bet, on, dist, gold, got (-1: not known
## yet), win, out}; the furthest first.
func _fill_recap(grid: GridContainer, rows_in: Array) -> void:
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()
	for head in ["JOUEUR", "DISTANCE", "PIÈCES", "MISE", "SUR LA MISE", "BILAN"]:
		grid.add_child(_label(head, ts("s"), RELIC, 0))
	var rows: Array = rows_in.duplicate()
	rows.sort_custom(func(p_, q_): return int(p_["dist"]) > int(q_["dist"]))
	for r_ in rows:
		var k = int(r_["k"])
		var col: Color = INK if k == race.me else Race.COLOURS[k % Race.COLOURS.size()]
		var b = int(r_["bet"])
		var got = int(r_["got"])
		var gold = int(r_.get("gold", 0))
		var on = int(r_["on"])
		var on_name = "lui" if on == k else ("toi" if on == race.me else str(race.seats.get(on, {}).get("name", "?")).left(8))
		var live = got < 0                           # (0.57: the race going on: the bets not known yet)
		var won = got - b if b > 0 and not live else 0
		var cells = [("Toi" if k == race.me else str(r_["name"]).left(10)) + (" ★" if r_["win"] else "") + (" (tombé)" if live and r_.get("out", false) else ""),
			"%d m" % int(r_["dist"]), "+%d" % gold, ("%d sur %s" % [b, on_name]) if b > 0 else "—",
			"…" if live and b > 0 else ((("+%d" % won) if won > 0 else ("%d" % won)) if b > 0 else "—"),
			"…" if live else (("+%d" % (gold + won)) if gold + won >= 0 else "%d" % (gold + won))]
		for i in cells.size():
			var c = cells[i]
			var tint = col if i == 0 else (Color("#9dff7a") if (i == 4 and won > 0) or (i == 5 and gold + won > 0) else (Color("#ff7a7a") if (i == 4 and won < 0) or (i == 5 and gold + won < 0) else INK))
			grid.add_child(_label(c, ts("s"), tint, 0))

## « Miser »: the number written, as my bet (0 to 99 999 999, never more than my coins).
func _race_amount(done: bool = true) -> void:
	var digits = ""
	for ch in str(w["rc-amount"].text):
		if ch >= "0" and ch <= "9":
			digits += ch
	var n = clampi(int(digits) if digits != "" else 0, 0, mini(Race.BET_MAX, int(save["coins"])))
	race_seen = true
	race.bet(int(race.my_seat().get("on", race.me)), n)
	if done or str(n) != w["rc-amount"].text:
		var at = w["rc-amount"].caret_column
		w["rc-amount"].text = str(n)
		w["rc-amount"].caret_column = mini(at, str(n).length())
	if done:
		w["rc-amount"].release_focus()

## « Prêt ! » / « Plus prêt » (0.55).
func _race_ready_toggle() -> void:
	race_seen = true
	race.set_ready(not bool(race.my_seat().get("ready", false)))
	Audio.sfx("click")

## « Inviter » on a free place (Affrontement, Amis → Groupe): the friends of my list, each with « Inviter » (or
## « invité… », « dans le groupe »); the group's code to give. (0.58) A group is opened by the first invitation.
func _race_pick() -> void:
	var friends = board_cache.filter(func(e): return not e.get("me", false))
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_panel("settings-right"))
	_place(p, 569 / 2.0 - 132, 30, 265, 262)
	var col = _vbox(4)
	col.add_child(_label("INVITER DANS LE GROUPE", ts("s"), RELIC, 0))
	var close = func() -> void: layer.queue_free()
	if friends.is_empty():
		col.add_child(_wrap("Ajoute d'abord des amis (Amis → Liste d'amis)." if Net.enabled() else "Le serveur n'est pas encore en ligne.", DIM))
	var list = _vbox(3)
	for e in friends.slice(0, 12):
		var code = str(e.get("code", ""))
		var nm = str(e.get("name", "?"))
		var h = _hbox(6)
		var l = _plain(_label(nm, ts("s"), INK, 0), "m")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		if race.seats.values().any(func(seat): return str(seat.get("code", "")) == code):
			h.add_child(_label("dans le groupe", ts("s"), Color("#9dff7a"), 0))
		elif race.invited.has(code):
			h.add_child(_label("invité…", ts("s"), DIM, 0))
		else:
			var ib = _button("Inviter", "tab sel", func() -> void:
				close.call()
				_race_invite(code, nm))
			ib.custom_minimum_size = Vector2(a(64), a(20))
			h.add_child(ib)
		list.add_child(h)
	var sc = _fixed(list)
	sc.custom_minimum_size.y = a(150)
	col.add_child(sc)
	if race.role == "host" and race.room != "":
		col.add_child(_wrap("Ou donne-lui le code du groupe : %s" % race.room, DIM))
	col.add_child(_button("Fermer", "small plain", close))
	p.add_child(col)
	root.add_child(p)

func _coop_toast(text: String) -> void:
	race_note = text
	refresh_race()

func _race_host(show: bool = true) -> void:
	race.save = save
	race_note = ""
	race_seen = true
	if show:                                         # (0.57: from Amis → Groupe, it stays there)
		go("race")
	await race.host()
	race.set_kit(SaveData.loadout(save))
	refresh_race()
	if state == "friends":
		refresh_friends()

## (0.66) « Partie rapide »: into a race room waiting for players, or my own opened and offered to them (renewed
## while it waits, until full or started). (0.68) It searches on its own: while I wait alone in mine, every few
## seconds it looks for another room waiting; of two players waiting alone each in his own, the one whose room
## has the later code goes to the other (so both never swap). The free places say « Recherche… », moving.
func _race_quick() -> void:
	if not Net.enabled():
		group_note = "Hors ligne : pas de partie rapide."
		refresh_friends()
		return
	race.save = save
	quick_on = true
	race_note = "Recherche d'adversaires…"
	race_seen = true
	var r = await net.quick_match(save)
	if str(r.get("room", "")) != "":
		race_note = ""
		go("race")
		race.join(str(r["room"]))
		return
	await _race_host(true)
	race_note = "Recherche d'adversaires…"
	refresh_race()
	var opened_at = -INF
	while quick_on and race.role == "host" and race.in_lobby() and race.count() < 4 and race.room != "":
		var now = Time.get_ticks_msec() / 1000.0
		if now - opened_at > 30.0:
			opened_at = now
			await net.match_open(save, race.room)
		if race.count() == 1 and race.role == "host" and race.room != "":
			var r2 = await net.quick_match(save)
			var other = str(r2.get("room", ""))
			if other != "" and race.count() == 1 and race.role == "host" and other < race.room:
				race.leave()
				race_note = ""
				go("race")
				race.join(other)
				return
		await get_tree().create_timer(QUICK_EVERY).timeout

func _race_join() -> void:
	quick_on = false
	var code = w["ra-code"].text.strip_edges().to_upper()
	if code.length() != 4:
		group_note = "Le code d'un groupe a 4 lettres."
		refresh_friends()
		return
	group_note = ""
	race.save = save
	race_note = ""
	race_seen = true
	go("race")
	race.join(code)

## « Inviter à la course »: a race is opened if there is none, and this friend is invited into it.
func _race_invite(code: String, name: String) -> void:
	if code == "":
		return
	race.save = save
	var stay = state == "friends"                    # (0.57: from Amis, the group's screen stays)
	if race.role == "":
		race_note = ""
		race_seen = true
		if not stay:
			go("race")
		await race.host()
		race.set_kit(SaveData.loadout(save))
	if race.role != "host" or race.state != "lobby":
		refresh_race()
		if stay:
			refresh_friends()
		return
	if not stay:
		go("race")
	var r = await race.invite(code, name)
	if r.has("error"):
		race_note = {"friend": "%s n'est pas dans ta liste d'amis." % name, "full": "La course est complète."}.get(r["error"], "L'invitation n'est pas partie : réessaie dans un moment.")
	refresh_race()

## « Lancer » (the host, once all are ready): the same road for all in three seconds, his kit for all.
func _race_go() -> void:
	if race.role != "host" or race.count() < 2 or race.running or not race.all_ready():
		return
	var up = SaveData.loadout(save)
	race_note = ""
	var type = str(race.rules.get("score", "dist"))  # (0.65) the kind of race: its rule, its kit, its scenery
	var pick = str(race.rules.get("pick", ""))
	var final = race.treasure_final()
	if final:
		up = {}
	elif pick != "":
		up = Daily.of_day(pick)["kit"]
	var biome = 0 if type == "gold" else endless_biome
	race.start({"seed": randi() % 2147483647, "biome": biome, "tier": Coop.tier_of(up), "up": up, "rule": "" if final else pick, "final": final, "sky": type == "gold"}, 3.0)

func _race_quit() -> void:
	if race.running and not race.my_seat().get("done", false):
		_confirm("Quitter la course ? Ta mise est perdue.", func() -> void:
			race.leave()
			go("menu"))
		return
	race_note = ""                                   # (0.55) back home; the group stays (Amis → Groupe to leave it)
	go("menu")

func _on_race_changed() -> void:
	if state == "race":
		refresh_race()
	elif state == "friends":
		refresh_friends()
	elif state == "menu":
		_fill_group()

## What the race says (race.gd): its start, its result, the host gone.
func _on_race(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"start":
			var delay = maxf(0.2, float(m.get("in", 3.0)))
			race_start = {"seed": int(m.get("seed", 0)), "biome": int(m.get("biome", 0)), "tier": int(m.get("tier", 0)), "up": m.get("up", {}), "at": time + delay,
				"rule": str(m.get("rule", "")), "final": bool(m.get("final", false)), "sky": bool(m.get("sky", false))}
			race_seen = false
			race_note = ""
			if state != "race":
				go("race")
			refresh_race()
		"result":
			if state == "play" and run != null and run.race and not run.dead:
				var win: Array = race.result.get("win", [])
				if race.rules.get("end", "last") == "last":   # (0.61) « Dernier en vie »: it ends here for him too
					banner("Tu gagnes la course !" if race.me in win else "La course est jouée.")
					game_over()
				else:
					banner("Tu gagnes la course ! Continue pour ton record." if win == [race.me] else "La course est jouée.")
			refresh_race()
		"gone":
			race_note = race.info
			if state == "play" and run != null and run.race:
				banner(race.info)
			refresh_race()

## 0.55: fallen in a race the others still run: my distance goes to them, my coins are banked, and I watch
## them (the camera follows one; a touch, the next one) until the result.
func _race_watch() -> void:
	if race.running and not race.my_seat().get("done", false):
		race.done(floori(run.dist), run.gold)
	bank()                                           # (my coins picked up are mine, whatever the race gives)
	run.spectating = true
	watch_k = -1
	watch_res = false
	watch_done = false
	hint(0)
	w["hud-watch"].visible = true
	w["hud-res-btn"].visible = true
	Audio.music("over")

## Where the one I watch is (world x), the one ahead if he fell (or none was chosen).
func _watch_x() -> float:
	var alive = run.rivals.filter(func(m): return not m.get("out", false))
	if alive.is_empty():
		return run.cam + run.home
	var pick = null
	for m in alive:
		if int(m.get("k", -1)) == watch_k:
			pick = m
	if pick == null:
		alive.sort_custom(func(a_, b_): return float(a_.get("x", 0.0)) > float(b_.get("x", 0.0)))
		pick = alive[0]
		watch_k = int(pick.get("k", -1))
	w["hud-watch"].text = "TU REGARDES %s · %d M — TOUCHE : UN AUTRE" % [str(pick.get("name", "?")).to_upper(), int(race.seats.get(watch_k, {}).get("dist", 0))]
	return float(pick.get("x", 0.0))

## (0.57) « Résultats » while watching: the race as it stands (or its result), over the view, or put away.
func _toggle_watch_res() -> void:
	watch_res = not watch_res
	_watch_res_fill()
	Audio.sfx("click")

func _watch_res_fill() -> void:
	if not w.has("hud-res") or not is_instance_valid(w["hud-res"]):
		return
	w["hud-res"].visible = run != null and run.spectating and watch_res
	w["hud-res-btn"].text = "Masquer" if watch_res else "Résultats"
	if not watch_res:
		return
	var done = not race.running and not race.history.is_empty()
	w["hud-res-title"].text = ("COURSE %d · RÉSULTAT" % int(race.history[0]["n"])) if done else "LA COURSE EN DIRECT"
	var rows: Array = []
	if done:
		rows = race.history[0]["rows"].duplicate()
	else:
		for k in race.seats:
			var st: Dictionary = race.seats[k]
			rows.append({"k": k, "name": str(st.get("name", "?")), "bet": int(st.get("bet", 0)), "on": int(st.get("on", k)),
				"dist": int(st.get("dist", 0)), "gold": int(st.get("gold", 0)), "got": -1, "win": false, "out": st.get("done", false) or st.get("gone", false)})
	_fill_recap(w["hud-res-grid"], rows)

## A touch while watching: the next one still running.
func _watch_next() -> void:
	var alive = run.rivals.filter(func(m): return not m.get("out", false)).map(func(m): return int(m.get("k", -1)))
	alive.sort()
	if alive.is_empty():
		return
	var i = alive.find(watch_k)
	watch_k = alive[(i + 1) % alive.size()]

## My race run is over: the coins and experience are banked as for any run, my distance goes to the
## others, and the race screen shows how it goes on.
func _race_over() -> void:
	if race.running and not race.my_seat().get("done", false):
		race.done(floori(run.dist), run.gold)
	bank()
	if w.has("hud-watch") and is_instance_valid(w["hud-watch"]):
		w["hud-watch"].visible = false
		w["hud-res-btn"].visible = false
		w["hud-res"].visible = false
	if race.running and run != null and run.spectating:
		race_seen = true                             # (0.57: left while it goes on: the lobby, no recap yet)
	race_seen = false
	Audio.music("over")
	state = "race"
	show_screen("race")
	refresh_race()

func _coop_host() -> void:
	coop.save = save
	coop.host(randi() % 2147483647)

func _coop_join() -> void:
	var code = w["co-code"].text.strip_edges().to_upper()
	if code.length() != 4:
		w["co-text"].text = "Le code d'un salon a 4 lettres."
		return
	coop.save = save
	coop.join(code)

## « Inviter »: a room for two is opened and this friend is invited into it (his game shows it to him).
func _invite(code: String, name: String) -> void:
	coop.save = save
	friends_tab = "coop"
	refresh_friends()
	await coop.host(randi() % 2147483647)
	if coop.role != "host" or coop.state != "waiting":
		return
	coop.invited = name
	refresh_friends()
	var r = await net.invite(save, code, coop.room)
	if r.has("error") and coop.state == "waiting":
		coop.leave()
		coop._fail({"friend": "%s n'est pas dans ta liste d'amis." % name, "full": "Quelqu'un a déjà rejoint ce salon."}.get(r["error"], "L'invitation n'est pas partie : réessaie dans un moment."))

## The host starts a run for two in `mode` (Jouer: "endless", Histoire: "story"): a new road, the scenery
## the home screen shows, and his items and powers for both, a moment from now.
func _coop_go(mode: String) -> void:
	if coop.state != "ready" or coop.role != "host":
		return
	var up = SaveData.loadout(save) if mode != "story" else Game.story_kit(int(save["relic"]))   # (0.49)
	var msg = {"t": "start", "mode": mode, "seed": randi() % 2147483647, "biome": endless_biome, "tier": Coop.tier_of(up), "up": up, "in": 0.8}
	coop.send(msg)
	_coop_begin(msg, 0.8)

func _coop_begin(m: Dictionary, delay: float) -> void:
	var mode = "story" if str(m.get("mode", "endless")) == "story" else "endless"
	coop_start = {"mode": mode, "seed": int(m["seed"]), "biome": int(m["biome"]), "tier": int(m["tier"]), "up": m.get("up", {}), "at": time + delay}
	save["mode"] = mode
	print("coop: %s in %.2f s, seed %d, tier %d" % [mode, delay, int(m["seed"]), int(m["tier"])])

## The link for two changed. Once linked, both go to the home screen: the host starts the run there.
func _on_coop_changed() -> void:
	var was = coop_was
	coop_was = coop.state
	if coop.state != "ready":
		kit_sent = ""                                # (a new link: the guest is sent the kit again)
	if was == "ready" and coop.state == "failed":
		coop_say_left()
	refresh_friends()
	if coop.state == "ready" and state == "friends":
		go("menu")
	elif state == "menu":
		refresh_menu()

## The partner left (or the link broke): the home screen's band says so a moment, then goes.
func coop_say_left() -> void:
	_coop_say(coop.info if coop.info != "" else "L'autre joueur est parti.")

func _coop_guest() -> bool:
	return coop.state == "ready" and coop.role == "guest"

func _mate_name() -> String:
	var n = str(coop.mate.get("name", ""))
	return n if n != "" else "ton ami"

## A word on the home screen's band for two, for a few seconds.
func _coop_say(text: String) -> void:
	coop_note = text
	coop_note_t = 3.0
	if state == "menu":
		_coop_band()

## The home screen's band for two: with whom (or a word for a moment); the guest's Jouer and Histoire dimmed.
func _coop_band() -> void:
	if not w.has("menu-coop") or not is_instance_valid(w["menu-coop"]):
		return
	var two = coop.state == "ready" or coop_note != ""
	w["menu-coop"].visible = two
	w["menu-coop-text"].text = coop_note if coop_note != "" else "À deux avec %s" % _mate_name()
	for mode in ["endless", "story"]:
		if w.has("menu-go-" + mode) and is_instance_valid(w["menu-go-" + mode]):
			w["menu-go-" + mode].modulate = Color(0.55, 0.55, 0.62) if _coop_guest() else Color.WHITE

## The host's items and powers, and the scenery Jouer starts in, sent to the guest's home screen when they
## change (the run's start carries them too: that is what both wear).
func _send_kit(force: bool = false) -> void:
	if coop.state != "ready" or coop.role != "host":
		kit_sent = ""
		return
	var up = SaveData.loadout(save)
	var eq = save["equipped"].slice(0, 3)
	var key = JSON.stringify([up, eq, endless_biome])
	if key == kit_sent and not force:
		return
	kit_sent = key
	coop.send({"t": "kit", "up": up, "eq": eq, "biome": endless_biome})

## A look for invitations (menus only, never during a run): one shown at a time, each only once.
func _poll_invites() -> void:
	if invite_busy:
		return
	invite_busy = true
	var r = await net.invites(save)
	invite_busy = false
	if r.has("error") or invite_box != null or not coop.state in ["idle", "failed"] or not race.state in ["idle", "failed"] or not state in INVITE_SCREENS:
		return
	for it in r.get("items", []):
		var room = str(it.get("room", ""))
		if room == "" or invite_seen.has(room):
			continue
		invite_seen[room] = true
		_show_invite(str(it.get("name", "")), room, str(it.get("kind", "coop")))
		return

## « Léa t'invite à jouer à deux ! » Rejoindre: into her room (the Amis screen shows the link being made,
## then both are on the home screen). Pas maintenant: she is told.
func _show_invite(name: String, room: String, kind: String = "coop") -> void:
	var layer = CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	invite_box = layer
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var col = _vbox(8)
	var who = _plain(_label(name if name != "" else "Un ami", ts("l"), GOLD, 0), "l")
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(who)
	var what = _label("t'invite à une course à 4 !" if kind == "race" else "t'invite à jouer à deux !", ts("m"), INK, 0)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(what)
	var close = func() -> void:
		layer.queue_free()
		invite_box = null
	var yes = func() -> void:
		close.call()
		if kind == "race":
			race.save = save
			race_note = ""
			race_seen = true
			go("race")
			race.join(room)
			return
		coop.save = save
		friends_tab = "coop"
		go("friends")
		coop.join(room)
	var no = func() -> void:
		close.call()
		net.invite_no(save, room)
	var row_b = _hbox(10)
	row_b.alignment = BoxContainer.ALIGNMENT_CENTER
	row_b.add_child(_button("Pas maintenant", "small plain", no))
	row_b.add_child(_button("Rejoindre", "small gold", yes))
	col.add_child(row_b)
	p.add_child(col)
	_place(p, 569 / 2.0 - 140, 70, 280, 100)
	root.add_child(p)
	Audio.sfx("level")

## What the partner says (coop.gd): where he is, his bubble, the run's start and end.
## (0.58) The emotes owned (Skins « Émotes à deux »): their ids.
func _emotes() -> Array:
	return save["skins"]["owned"].filter(func(id): return Skins.skin(id).get("target", "") == "emote")

## (0.58) « ! » for two: the emotes owned, to pick one; it shows over me and over me on my partner's screen.
func _emote_menu() -> void:
	var row: VBoxContainer = w["emote-row"]
	if row.visible:
		row.visible = false
		return
	for ch in row.get_children():
		row.remove_child(ch)
		ch.queue_free()
	for id in _emotes().slice(0, 6):
		var text = str(Skins.skin(id)["fx"]["text"])
		var b = _button(text, "tab", func() -> void:
			row.visible = false
			if run == null or not run.coop:
				return
			run.emote_me = {"text": text, "t": run.t}
			coop.send({"t": "emote", "e": id}))
		b.custom_minimum_size = Vector2(a(130), a(20))
		row.add_child(b)
	row.visible = true
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(row):
			row.visible = false)

func _on_coop(m: Dictionary) -> void:
	var t = str(m.get("t", ""))
	if t == "start" and coop.role == "guest":
		_coop_begin(m, maxf(0.1, float(m.get("in", 0.8)) - coop.rtt / 2))         # (he started RTT/2 later)
		return
	if run == null or not run.coop:
		return
	match t:
		"emote":                                         # (0.58) my partner's words, over him a moment
			var sk = Skins.skin(str(m.get("e", "")))
			if sk.get("target", "") == "emote":
				run.emote_mate = {"text": str(sk["fx"]["text"]), "t": run.t}
				Audio.sfx("click")
		"s":
			coop.push(m, run.t)                          # drawn from these, a few hundredths in the past
			if run.mate == null or float(m.get("at", 0.0)) >= float(run.mate.get("at", -1.0)):
				var was = run.mate != null and run.mate.get("b", false)
				run.mate = m
				if m.get("b", false) and not was:
					run.mate_bubble = Vector2(float(m["x"]), float(m["y"]) - 40)
			# the clock: his run time, as it is now, against this one; each side closes a little of the gap
			var drift = float(m.get("at", 0.0)) + coop.rtt / 2 - run.t
			coop_owed += clampf(drift * 0.05, -0.004, 0.004)
		"bubble":
			if run.mate == null:
				run.mate = {"x": run.cam + run.sx, "y": Game.GROUND}
			if not run.mate.get("b", false):
				run.mate_bubble = Vector2(float(run.mate["x"]), float(run.mate["y"]) - 40)
			run.mate["b"] = true
			print("coop: partner in a bubble")
		"rescue":
			Game.back(run)
			print("coop: rescued")
		"act":                                           # his Esquive, Sablier or RedMonster: mine too
			Game.remote_act(run, str(m.get("k", "")))
		"back":
			if run.mate != null:
				run.mate["b"] = false
		"end", "bye":
			run.mate = null                              # his run is over: alone now
			print("coop: partner ", t)

func pause() -> void:
	if run != null and run.coop:
		return                                       # for two the run cannot wait
	if state != "play" or run == null or run.dead:
		return
	touches.clear()
	input.hold = false
	pause_view()
	state = "pause"
	show_screen("pause")
	Audio.duck(true)                                 # the music goes on, quieter

func pause_view() -> void:
	w["pause-dist"].text = "%d m" % floori(run.dist)
	w["pause-gold"].text = "+%d" % run.gold
	w["pause-best"].text = "Debug : record non enregistré" if run.debug else "Record : %d m" % best_of(run.mode)
	_set_level(w["pause-level"], true)
	_quest_cards(w["pause-quests"])

## The pause's eye: the menu (and its shade) goes, the game is seen behind, still paused; again, it comes back.
func _peek(on: bool) -> void:
	peeking = on
	if not screens.has("pause"):
		return
	for ch in screens["pause"].get_children():
		if ch is CanvasItem and not (w.has("pause-eye") and ch == w["pause-eye"]):
			ch.visible = not on
	if w.has("pause-eye-icon") and is_instance_valid(w["pause-eye-icon"]):
		w["pause-eye-icon"].shut = on
		w["pause-eye-icon"].queue_redraw()

## An eye, drawn: open (the menu can be hidden) or shut (it is: a touch brings it back).
class Eye extends Control:
	var shut := false
	func _draw() -> void:
		var c = size / 2
		var r = minf(size.x, size.y) * 0.3
		var ink = Color("#fff8e6")
		if shut:                                     # a closed lid with lashes
			var pts = PackedVector2Array()
			for i in 13:
				var a = PI * i / 12.0
				pts.append(c + Vector2(-cos(a) * r * 1.2, sin(a) * r * 0.45))
			draw_polyline(pts, ink, maxf(2, r * 0.18))
			for k in [-0.6, 0.0, 0.6]:
				var base = c + Vector2(k * r, r * 0.45)
				draw_line(base, base + Vector2(k * r * 0.3, r * 0.4), ink, maxf(1.5, r * 0.14))
			return
		var top = PackedVector2Array()
		for i in 25:
			var a = TAU * i / 24.0
			top.append(c + Vector2(cos(a) * r * 1.25, sin(a) * r * (0.62 if sin(a) > 0 else 0.7)))
		draw_polyline(top, ink, maxf(2, r * 0.18))
		draw_circle(c, r * 0.42, Color("#7dfff0"))
		draw_circle(c, r * 0.2, Color("#1a1024"))
		draw_circle(c + Vector2(-r * 0.12, -r * 0.14), r * 0.08, Color.WHITE)

func resume() -> void:
	_peek(false)
	if state == "pause":
		state = "play"
		show_screen("hud")
		Audio.duck(false)

## Feeds the objectives and the level with what just happened. Experience: a point every
## Progress.cfg.mpp metres (reglages/progression.txt), plus what each completed objective pays. The levels
## gained wait for the end of the run (levels_due), where a panel shows them with what they bring.
func progress(stats: Dictionary) -> void:
	var done = Progress.feed(save, stats)
	var xp: float = stats.get("dist", 0.0) / float(Progress.cfg["mpp"])
	for q in done:
		toast("ico-target", "Défi réussi !", q["reward"], q["xp"])
		xp += q["xp"]
	var levels: Array = Progress.add_xp(save, xp) if xp > 0 else []
	levels_due.append_array(levels)
	if done.size() > 0:
		Audio.sfx("quest")
	if done.size() > 0 or levels.size() > 0:
		SaveData.store(save)

## The levels gained during the run, in a panel: the level reached, the coins it paid, and what can now
## be bought in the shop. Shown once the run is over (end screen, or back at the menu).
func show_levels(after: Callable = Callable()) -> void:
	if levels_due.is_empty():
		return
	var levels: Array = levels_due.duplicate()
	levels_due.clear()
	if modal != null:
		modal.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var col = _vbox(6)
	var last: int = levels[-1]
	var title = _label(("Niveau %d !" % last) if levels.size() == 1 else ("Niveaux %d à %d !" % [levels[0], last]), ts("l"), GOLD, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var coins = 0
	var unlocked: Array = []
	for l in levels:
		coins += Progress.level_reward(l)
		for u in SaveData.UPGRADES:
			if u["unlock"] == l:
				unlocked.append(u)
	var pay = _hbox(5)
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	pay.add_child(_label("Récompense : +%d" % coins, ts("m"), INK, 0))
	pay.add_child(_icon_rect(icon("coin-icon"), 13))
	pay.add_child(_label("  +%d" % levels.size(), ts("m"), INK, 0))   # 0.47: an urn per level
	pay.add_child(_icon_rect(icon("ico-urn"), 16))
	col.add_child(pay)
	if unlocked.is_empty():
		var none = _label("Rien de nouveau à débloquer cette fois.", ts("s"), DIM, 0)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
	else:
		var head = _label("Débloqué dans la boutique :", ts("s"), DIM, 0)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		for u in unlocked.slice(0, 4):
			var row = _hbox(6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(_icon_rect(icon("ico-" + u["icon"]), 16))
			row.add_child(_label(u["name"], ts("m"), INK, 0))
			col.add_child(row)
		if unlocked.size() > 4:
			var more = _label("et %d autre(s)" % (unlocked.size() - 4), ts("s"), DIM, 0)
			more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(more)
	var close = func() -> void:
		layer.queue_free()
		modal = null
		if after.is_valid():
			after.call()
	var row_b = _hbox(10)
	row_b.alignment = BoxContainer.ALIGNMENT_CENTER
	row_b.add_child(_button("Super !", "small gold", close))
	col.add_child(row_b)
	p.add_child(col)
	_place(p, 569 / 2.0 - 150, 40, 300, 110)
	root.add_child(p)
	modal = layer
	Audio.sfx("level")
	confetti(30)

## A short notice at the top of the screen: objective done, level gained.
## Caught: the Couteau suisse's offer (0.55: equipped only), then the escape, over the game (Game keeps the state).
## (0.68) Freed, the panel stays a moment, every rope cut (esc_hold).
func _esc_view() -> void:
	if not w.has("esc") or not is_instance_valid(w["esc"]):
		return
	var c = run.caught if run != null else null
	var ph: String = c.phase if c != null else ""
	var ev: EscapeView = w["esc-bar"]
	if esc_hold > 0:
		esc_hold -= get_process_delta_time()
		w["esc"].visible = esc_hold > 0
		w["esc"].modulate.a = clampf(esc_hold / 0.25, 0, 1)
		return
	w["esc"].modulate.a = 1.0
	w["esc"].visible = ph == "offer" or ph == "escape"
	var slime = c != null and c.get("by", "") == "slime"   # (0.59) Histoire, the dungeon
	if ph == "offer":
		if slime:
			w["esc-label"].text = "Avalé ! Une chance de t'extirper"
		elif Game.story_revive_ok(run):
			w["esc-label"].text = "Capturé ! Une chance de t'évader"
		else:
			w["esc-label"].text = "Capturé ! Couteau suisse : %d" % run.free_knives
		w["esc-hint"].text = "Touche le couteau !"
		ev.phase = "offer"
		ev.e = {}
		ev.left = maxf(0, c.timer)
		ev.full = Game.ESC_OFFER
	elif ph == "escape":
		var e: Dictionary = c.esc
		w["esc-label"].text = ("Extirpe-toi ! Encore %d" if slime else "Ronge les cordes ! Encore %d") % e.rope
		w["esc-hint"].text = "Touche quand le curseur est dans le vert"
		ev.phase = "escape"
		ev.e = e
		ev.left = maxf(0, e.time)
		ev.full = e.full

## The Couteau suisse taken from the stock (0.54: the one equipped first, it costs nothing): the escape begins.
func _use_knife() -> void:
	if run == null or run.caught == null or run.caught.phase != "offer":
		return
	if (run.free_knives > 0 or Game.story_revive_ok(run)) and Game.escape_start(run):   # (0.55: the one equipped only; 0.59: Histoire's one chance a level)
		Audio.sfx("buy")

func toast(ico: String, text: String, coins: int, xp: int) -> void:
	var box = _box()
	var row = _hbox(7)
	row.add_child(_icon_rect(icon(ico), 16))
	row.add_child(_label(text, ts("m"), INK, 0))
	if coins > 0:
		row.add_child(_label("+%d" % coins, ts("m"), GOLD, 0))
		row.add_child(_icon_rect(icon("coin-icon"), 14))
	if xp > 0:
		row.add_child(_label("+%d XP" % xp, ts("m"), GOLD, 0))
	box.add_child(row)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.modulate.a = 0
	w["toasts"].add_child(box)
	box.scale = Vector2(0.8, 0.8)
	var centre = func() -> void:
		box.pivot_offset = box.size / 2
	centre.call_deferred()
	var tw = create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.27)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)

func banner(text: String) -> void:
	var b: Label = w["banner"]
	b.text = text.to_upper()
	b.modulate.a = 0
	b.scale = Vector2(0.6, 0.6)
	b.rotation = -0.05
	var tw = create_tween().set_parallel()
	tw.tween_property(b, "modulate:a", 1.0, 0.35)
	tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "rotation", 0.0, 0.35)
	banner_timer = 2.4

func hint(step: int) -> void:
	hint_step = step
	w["hint"].visible = step > 0
	if step == 1:
		w["hint"].text = "Touche l'écran pour sauter !"
	if step == 2:
		w["hint"].text = "Reste appuyé : tu sautes plus haut"
		hint_timer = 3.5

func hud() -> void:
	if run != null and run.daily and w.has("hud-daily"):   # (0.57) the next tier of the day, or all won
		var st = Daily.state(save)
		var nxt = st["got"].slice(0, 4).find(false)
		var dd = Daily.of_day()
		w["hud-daily"].text = ("%s · %d M · %s" % [Daily.TIER_NAMES[nxt].to_upper(), int(dd["tiers"][nxt]), Daily.reward_text(nxt).to_upper()]) if nxt >= 0 else "TOUS LES PALIERS DU JOUR SONT GAGNÉS"
	_esc_view()
	if w.has("say") and is_instance_valid(w["say"]):  # the guards' line, typed out 40 letters a second
		var on = run.saying != ""
		w["say"].visible = on
		if on:
			if w["say-text"].text != run.saying:
				w["say-text"].text = run.saying
				var who_ = run.who.to_upper() if run.who != "" else "LES GARDES"
				w["say-who"].text = who_
				w["say-who"].label_settings.font_color = LEAF if who_.begins_with("PÉPITO") else RELIC
			w["say-text"].visible_characters = int(run.say_age * Game.SAY_RATE)
			var said = run.say_age * Game.SAY_RATE >= run.saying.length()
			w["say-more"].modulate.a = (0.6 + 0.4 * sin(time * 5)) if Game.say_by_touch(run) and said else 0.0
	var d = floori(run.dist)
	if d != hud_state["dist"]:
		hud_state["dist"] = d
		w["hud-dist"].text = "%d m" % d
	if run.gold != hud_state["gold"]:
		hud_state["gold"] = run.gold
		w["hud-coins"].text = str(run.gold)
		var c: Label = w["hud-coins"]
		c.pivot_offset = c.size / 2
		c.scale = Vector2(1.35, 1.35)                # the little bounce
		create_tween().tween_property(c, "scale", Vector2.ONE, 0.18)
	if run.hearts != hud_state["hearts"]:
		hud_state["hearts"] = run.hearts
		var i = 0
		for h in w["hud-hearts"].get_children():
			var lost = i >= run.hearts
			h.pivot_offset = h.size / 2
			create_tween().tween_property(h, "modulate", Color(0.35, 0.35, 0.35, 0.5) if lost else Color.WHITE, 0.2)
			create_tween().tween_property(h, "scale", Vector2(0.8, 0.8) if lost else Vector2.ONE, 0.2)
			i += 1
	w["btn-ball"].modulate = Color(1.0, 0.85, 0.35) if run.ball_on else (Color(0.5, 0.5, 0.55, 0.6) if run.sky else Color.WHITE)   # (0.65) lit while rolled up (0.68: greyed in the heights)
	for k in ACTS:
		var act = {"dash": run.dash, "slow": run.slow, "boots": run.boots, "tnt": run.tnt, "monster": run.monster}[k]
		var cool: Cooldown = w["cd-" + k]
		var v: float = act.cd / act.full if act.full > 0 else 0.0
		if absf(cool.k - v) > 0.005 or (v == 0 and cool.k != 0):
			cool.k = v
			cool.queue_redraw()
			w["btn-" + k].modulate = Color(0.7, 0.7, 0.7) if v > 0 else Color.WHITE

# ---------- input ----------

func press() -> void:
	if state == "play" and run != null and run.spectating:
		_watch_next()                                # (0.55) watching: the next one
		return
	if state == "play" and run != null and run.caught != null and run.caught.phase == "escape":
		Game.escape_tap(run)                         # the escape: a touch anywhere bites the rope
		return
	if state == "play":
		input.pressed = true
		input.hold = true

## Which of the HUD's buttons is under a spot, if any.
func _hud_button_at(pos: Vector2) -> String:
	for k in ["btn-pause", "btn-dash", "btn-slow", "btn-boots", "btn-tnt", "btn-monster"]:
		var b: Control = w.get(k)
		if b != null and is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return k
	return ""

## Before the buttons see anything. Godot's buttons only follow the first finger: a second finger on the
## HUD's buttons (the jump held with the other thumb) is handled here. A touch anywhere puts away the
## card of an equipped item, as on the web.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and event.index > 0 and state == "play":
		match _hud_button_at(event.position):
			"btn-pause":
				pause()
				get_viewport().set_input_as_handled()

			"btn-slow", "btn-boots", "btn-tnt", "btn-dash", "btn-monster":
				_act(_hud_button_at(event.position).substr(4))
				get_viewport().set_input_as_handled()
	var down = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION)
	if down and state == "menu" and w.has("menu-modes"):
		var on_mode = false                            # a touch elsewhere puts the panel, the list away
		for bb in w["menu-modes"].get_children():
			if bb.visible and bb.get_global_rect().has_point(event.position):
				on_mode = true
		if w["menu-tip"].visible and not on_mode:
			_menu_tip("")
		if w["menu-modes"].get_meta("open", false) and not on_mode and not w["menu-play"].get_global_rect().has_point(event.position):
			_home_modes(false)
		var qb: Control = w["menu-quests-box"]
		if qb.visible and not qb.get_global_rect().has_point(event.position) and not w["menu-quests-btn"].get_global_rect().has_point(event.position):
			_home_quests(false)
	if down and state == "menu" and w.has("menu-info") and w["menu-info"].visible:
		var on_slot = false
		for sl in w["menu-loadout"].get_children():
			if sl.get_global_rect().has_point(event.position):
				on_slot = true
		if not on_slot:
			w["menu-info"].visible = false
			_mark_slots("")
	if down and OS.has_feature("web") and _touch() and save["full"] and state != "loading":
		var win = Vector2(get_window().size)
		if win.x > win.y and not _is_full_web() and _can_full():   # a phone held sideways plays full screen (at a touch: turning is no gesture)
			_apply_fullscreen()

## While playing, a touch anywhere on the frame is a jump (the HUD's buttons keep their own job). Each
## finger counts: the jump is held while one of them stays down.
func _unhandled_input(event: InputEvent) -> void:
	if debug_panel != null or modal != null:
		return                                       # the debug menu or a question is open: its own fields take the keys
	if event is InputEventScreenTouch:
		if event.pressed:
			if state == "play" and _hud_button_at(event.position) == "":
				touches[event.index] = true
				press()
		else:
			touches.erase(event.index)
			if touches.is_empty():
				input.hold = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return                                   # a finger, already handled as a touch
		if event.pressed:
			press()
			if state != "play" and state != "pause" and state != "intro" and state != "loading":
				Audio.music("run" if in_run else "menu")
		else:
			input.hold = false
	elif event is InputEventKey:
		var k: InputEventKey = event
		var label = k.key_label if k.key_label != KEY_NONE else k.keycode
		var jump_key = k.keycode == KEY_SPACE or k.keycode == KEY_UP or label == KEY_Z or label == KEY_W
		if not k.pressed:
			if jump_key:
				input.hold = false
			return
		if k.echo:
			return
		if jump_key:
			if state == "play":
				press()
			elif state == "over":
				_replay()
			elif state == "tally":
				_tally_tap()
			elif state == "menu" or state == "intro":
				go("play")
			elif state == "pause":
				resume()
		elif k.keycode == KEY_SHIFT or label == KEY_E:
			input.dash = true
		elif label == KEY_A or label == KEY_Q:
			input.slow = true
		elif k.keycode == KEY_DOWN or label == KEY_S:
			input.stomp = true
		elif label == KEY_F or label == KEY_T:
			input.tnt = true
		elif label == KEY_R:
			input.monster = true
		elif label == KEY_B:
			input.ball = true                        # (0.65) the Sphère's mode
		elif k.keycode == KEY_ESCAPE or label == KEY_P:
			if state == "play":
				pause()
			elif state == "pause":
				resume()
			elif in_run:
				go("menu")
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:          # 0.48: a gamepad (Steam Deck, a pad on a PC or a phone)
		var j: InputEventJoypadButton = event
		if j.button_index == JOY_BUTTON_A:
			if not j.pressed:
				input.hold = false
			elif state == "play":
				press()
			elif state == "over":
				_replay()
			elif state == "tally":
				_tally_tap()
			elif state == "menu" or state == "intro":
				go("play")
			elif state == "pause":
				resume()
		elif not j.pressed:
			return
		elif j.button_index == JOY_BUTTON_B:
			input.dash = true
		elif j.button_index == JOY_BUTTON_X:
			input.slow = true
		elif j.button_index == JOY_BUTTON_Y:
			input.tnt = true
		elif j.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			input.monster = true
		elif j.button_index == JOY_BUTTON_LEFT_SHOULDER or j.button_index == JOY_BUTTON_DPAD_DOWN:
			input.stomp = true
		elif j.button_index == JOY_BUTTON_START:
			if state == "play":
				pause()
			elif state == "pause":
				resume()
		elif j.button_index == JOY_BUTTON_BACK:
			_go_back()
		get_viewport().set_input_as_handled()

## Android's Back (and a gamepad's Back): what is open closes, the run pauses, a screen goes back home;
## on the home screen the game is left (project.godot: quit_on_go_back is off, or Back would end a run).
func _go_back() -> void:
	if debug_panel != null:
		close_debug()
		return
	if modal != null:
		modal.queue_free()
		modal = null
		return
	if state == "menu" and w.has("menu-modes") and (w["menu-modes"].get_meta("open", false) or w["menu-quests-box"].visible):
		_home_close()                                # (0.50) the list of modes or the objectives first
		return
	if invite_box != null:
		invite_box.queue_free()
		invite_box = null
		return
	for ch in get_children():                        # (the QR code, the friends to invite: layer 40)
		if ch is CanvasLayer and ch.layer == 40:
			ch.queue_free()
			return
	match state:
		"play":
			pause()
		"pause":
			resume()
		"menu":
			get_tree().quit()
		"race":
			_race_quit()
		"loading", "intro":
			pass
		_:
			go("menu")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause()
		Audio.sleep(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		Audio.sleep(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:   # closing mid-run still keeps the coins picked up so far
		if state == "play" or state == "pause" or in_run:
			bank()

# ---------- loop ----------

## One step of the run, `h` seconds: the world moves, its events are heard and counted, the partner is
## told where he is.
func _step(h: float) -> void:
	var t0 = Time.get_ticks_usec()
	Game.update(run, h, input)
	if run.daily and not run.dead:                   # (0.57) a tier of the day passed: its reward, at once
		for g in Daily.claim(save, run.dist):
			toast(str(g["icon"]), str(g["text"]), 0, 0)
			Audio.sfx("record" if int(g["i"]) >= 3 else "quest")
			SaveData.store(save)
	if run.spectating:                               # (0.55) fallen in a race: the camera with the one I watch
		Game.spectate(run, h, _watch_x())
	perf["game"] += Time.get_ticks_usec() - t0
	var stats = {"dist": run.dist - last_dist, "coins": 0, "gems": 0, "jumps": 0, "plats": 0, "breaks": 0, "shrooms": 0, "monkeys": 0, "mounts": 0, "dodges": 0, "missiles": 0, "hurt": false}
	if run.mount != null:                           # the metres run on a mount, for its own objectives
		stats[run.mount.kind + "Dist"] = run.dist - last_dist
	last_dist = run.dist
	for ev in run.events:
		Audio.sfx(ev)
		match ev:
			"coin": stats["coins"] += 1
			"gem": stats["gems"] += 1
			"jump": stats["jumps"] += 1
			"land": stats["plats"] += 1
			"break", "crate": stats["breaks"] += 1
			"shroom": stats["shrooms"] += 1
			"monkey": stats["monkeys"] += 1
			"mount": stats["mounts"] += 1
			"dodge": stats["dodges"] += 1
			"missile": stats["missiles"] += 1
			"boom": Audio.music("run")
			"boss": banner("Vorace !")           # (text on screen only for the bosses)
			"timber": banner("Ça tombe !")
			"bossfall": banner("Écrasée !")
			"bossdown": banner("Vorace est vaincue !")
			"eagle": banner("L'Aigle !")             # (0.60) the heights' guardian
			"eaglefall": banner("Foudroyé !")
			"eaglewon": banner("La tête d'ambre !")
			"soar":                                 # (0.54) off the cliff, the crown's Vol takes him (Histoire)
				if run.mode == "story" and run.won == 0:
					banner("Le Vol !")
			"relic":                                # 0.49: a piece of the relic won (Histoire): kept, its power now
				if run.won >= 0:
					if int(save["relic"]) < run.won + 1:
						save["relic"] = run.won + 1
						save["storyTry"] = 0
						SaveData.store(save)
					toast("ico-relic", "%s · nouveau pouvoir : %s" % [Game.RELIC_PIECE_NAMES[run.won], Game.RELIC_POWER_NAMES[run.won]], 0, 0)
					_fill_hud()
			"hurt", "rewind", "hit": stats["hurt"] = true
			"urn":                                  # 0.47: an urn (on the road; 0.55: Vorace's too)
				toast("ico-urn", "Une urne !", 0, 0)
			"cut":                                  # (0.68) a rope cut: its dot pops
				if w.has("esc-bar") and run.caught != null:
					var ee: Dictionary = run.caught.esc
					w["esc-bar"].pop(int(ee.get("ropes", 3)) - int(ee.get("rope", 0)) - 1)
			"miss":
				if w.has("esc-bar"):
					w["esc-bar"].miss()
			"free":                                 # escaped: the next fall will have its own photo
				if w.has("esc-bar") and w["esc"].visible:   # (0.68) the panel a moment more, every rope cut
					w["esc-bar"].freed()
					w["esc-label"].text = "Libre !"
					w["esc-hint"].text = ""
					esc_hold = 0.9
				banner("Libre !")
				photo_taken = false
				photo = null
				_fill_hud()
			"held":
				banner("La corde a tenu…")
			"brake":                                # a floating brake: 4 m/s less, for good
				Audio.sfx("slow")
			"fatal":                                # the blow that ends the run: the photo, now (thrown ahead,
				if not photo_taken and run.leap == null:   # when his head lands in the ground)
					photo_taken = true
					_take_photo()
			"tomb":                                 # (0.59) the long fall of level 2: the photo with his tomb
				if not photo_taken:
					photo_taken = true
					_take_photo.call_deferred()
			"plant":
				if not photo_taken and run.caught == null and run.skyfall == null:   # (caught by the guards: the photo is of him on the spit)
					photo_taken = true
					_take_photo.call_deferred()
			"snap":
				if not photo_taken:
					photo_taken = true
					_take_photo.call_deferred()
			"bubble", "rescue", "back":               # coop: the partner is told
				print("coop: ", ev)
				coop.send({"t": ev})
	run.events.clear()
	for k in run.acts:                               # for two: Esquive, Sablier, RedMonster start for both
		coop.send({"t": "act", "k": k})
	run.acts.clear()
	if run.race and race.running and not run.dead:   # 0.48: where he is, for the others' screens
		race_send_t -= h
		if race_send_t <= 0:
			race_send_t = Race.SEND_EVERY
			race.send_state({"at": run.t, "x": run.cam + run.sx, "y": run.p.y, "vy": run.p.vy, "v": run.speed, "g": run.p.ground, "f": run.p.flying, "ph": run.p.phase, "d": floori(run.dist), "c": run.gold,
				"lp": (2 if run.leap.planted else 1) if run.leap != null else 0, "ro": run.p.roll})   # (0.57: his fall, for the others)
	if run.coop and coop.state == "ready" and not run.dead:   # where he is, for the partner's screen
		coop_send_t -= h
		if coop_send_t <= 0:
			coop_send_t = Coop.SEND_EVERY             # (t: his run time, the partner draws him by it)
			coop.send({"t": "s", "at": run.t, "x": run.cam + run.sx, "y": run.p.y, "vy": run.p.vy, "v": run.speed, "g": run.p.ground, "f": run.p.flying, "ph": run.p.phase, "b": run.bubble, "d": run.dist}, false)
	progress(stats)
	if hint_step == 1 and stats["jumps"] > 0:
		hint(2)

## The taps of this frame are used up (for two, by the first of its steps: a jump is one jump).
func _taps_done() -> void:
	input.pressed = false
	input.dash = false
	input.slow = false
	input.ball = false
	input.stomp = false
	input.tnt = false
	input.monster = false

func _process(delta: float) -> void:
	var dt = minf(0.034, delta)                  # (30 images a second, in Éco, still run at full speed)
	if quick_on and state == "race" and race.in_lobby():   # (0.68) the quick match searching: its free places say so
		var tq = Time.get_ticks_msec() / 1000.0
		for i in 4:
			var lq: Label = w.get("rc-nm-%d" % i)
			if lq != null and is_instance_valid(lq) and lq.get_meta("search", false):
				lq.text = "RECHERCHE" + ".".repeat(1 + floori(tq * 3.0) % 3)
				lq.modulate.a = 0.55 + 0.45 * absf(sin(tq * 2.6 + i * 0.7))
	elif quick_on and not race.in_lobby() and race.role == "" and state != "race":
		quick_on = false
	if rebuild_due and state != "play" and state != "loading" and state != "pause":
		rebuild_t -= delta
		if rebuild_t <= 0:
			_rebuild()
	time += delta
	if state == "loading":
		return
	if state == "tally":
		_tally_beat(delta)
	if state == "play" or state == "over" or state == "tally":
		run.view_w = render.view_w * Game.PIXEL
		if run.coop and state == "play":             # for two: real time, every bit of it, in steps of 34 ms at most
			coop_owed = minf(coop_owed + delta, 1.5)   # (0.57: 1.5 s owed at most: a slow phone does not spiral)   # (alone, a slow frame slows the game down; for two that
			for h in Coop.split(coop_owed):              # would leave him behind the other for good)
				coop_owed -= h
				_step(h)
				_taps_done()
			run.mate_view = coop.view(run.t) if not coop.buf.is_empty() else null
			if run.race:                                 # the others, as ghosts; my distance on the board of places
				race.message_time = run.t
				run.rivals = race.views(run.t)
				race.reach(race.me, run.dist)
				race.gained(run.gold)                    # (0.56) my coins so far, for everyone's end screen
				run.board = race.board() if race.running else []
		else:
			_step(dt)
		if hint_step == 2:
			hint_timer -= dt
			if hint_timer <= 0:
				hint(0)
		hud()
		if state == "play" and run.dead and not run.spectating:
			if not photo_taken:
				photo_taken = true
				if not run.race:                     # (0.57: not in a race: no end screen for it, and reading the
					_take_photo()                    # picture back is heavy on a slow phone)
			dead_for += dt
			if dead_for > 0.9:
				game_over()
		if state == "play" and run.spectating and not race.running and not watch_done:
			watch_done = true                        # (0.57) decided: its results over the view, which stays
			watch_res = true                         # (« Retour au salon » to leave)
			_watch_res_fill()
		elif state == "play" and run.spectating and watch_res and floori(time * 4) != floori((time - delta) * 4):
			_watch_res_fill()                        # (live: a few times a second)
	if not coop_start.is_empty() and time >= coop_start["at"] and state != "play":
		go("play")                                   # the coop run: both phones start together
	if not race_start.is_empty():
		if time >= race_start["at"] and state != "play":
			go("play")                               # the race: everybody starts together
		elif state == "race" and ceili(float(race_start["at"]) - time) != race_count:
			race_count = ceili(float(race_start["at"]) - time)
			refresh_race()                           # (the count before the start, once a second)
	if coop_note_t > 0:
		coop_note_t -= delta
		if coop_note_t <= 0:
			coop_note = ""
			_coop_band()
	if Net.enabled() and save.get("online", {}).has("id") and state in INVITE_SCREENS and coop.state in ["idle", "failed"] and race.state in ["idle", "failed"] and invite_box == null:
		invite_t -= delta
		if invite_t <= 0:
			invite_t = INVITE_POLL
			_poll_invites()
	if Net.enabled() and save.get("online", {}).has("id") and state in INVITE_SCREENS and req_box == null:
		req_t -= delta                               # (0.57) the friend requests, out of a run
		if req_t <= 0:
			req_t = 8.0
			_poll_requests()
	_taps_done()
	if scanning:
		_scan_tick()
	if held != null and is_instance_valid(held) and state == "menu" and not tip_held and time - held_t > 0.45:
		tip_held = true                             # held long enough: its panel, and no launch on release
		_menu_tip(held.get_meta("tip", ""), held)
	if banner_timer > 0:
		banner_timer -= dt
		if banner_timer <= 0:
			create_tween().tween_property(w["banner"], "modulate:a", 0.0, 0.35)
	if w.has("over-best") and is_instance_valid(w["over-best"]):
		var rb: Label = w["over-best"]
		if rb.get_meta("hop", false) and state in ["over", "tally"]:
			var ph = fposmod(time, 0.6) / 0.6
			var k = sin(ph / 0.6 * PI) if ph < 0.6 else 0.0
			rb.pivot_offset = rb.size / 2
			rb.rotation = -0.07 * k
			rb.scale = Vector2.ONE * (1 + 0.08 * k)
		elif rb.rotation != 0:
			rb.rotation = 0
			rb.scale = Vector2.ONE
	if w.has("hint") and w["hint"].visible:          # it pulses gently
		w["hint"].scale = Vector2.ONE * (1.0 + 0.025 * (1 - cos(time * TAU)))
	for i in title_letters.size():                   # the title's letters hop one after the other
		var ph = fposmod(time - i * 0.09, 1.6) / 1.6
		var hop = 0.0
		if ph < 0.6:
			hop = sin(ph / 0.6 * PI)
		var l: Label = title_letters[i]
		l.position.y = (a(63) - l.get_minimum_size().y) / 2 - hop * a(29 * fk) * 0.2
	if w.has("fps"):                                 # the frame rate in a corner (Réglages, Affichage)
		w["fps"].visible = save["showFps"] or fps_param
		if w["fps"].visible and Engine.get_process_frames() % 15 == 0:
			w["fps"].text = "%d i/s · x%d · %dx%d · %s · %s" % [Engine.get_frames_per_second(), q, game_vp.size.x, game_vp.size.y, quality(), perf["text"]]
	_measure()
	if w.has("info"):                                # the debug menu's « Mesures en jeu »
		w["info"].visible = Debug.dbg["info"] and run != null
		if w["info"].visible and Engine.get_process_frames() % 5 == 0:
			w["info"].text = "%.1f m/s (propre %.1f) · %d m · %d s · hauteur %.2f m · max %.2f m" % [run.speed / 40, run.own / 40, floori(run.dist), roundi(run.t), run.h, run.max_h]
	# Behind the menus: the temple, frozen. The hero only appears once the run starts.
	var shown: Game.Run = run if (state == "play" or state == "pause" or state == "over" or state == "tally" or in_run) and run != null else still
	render.show_run(shown, time, q)
	if state == "shop" and demo.run != null:         # the shop's preview: a tiny real run
		demo.step(dt)
		demo_render.position = Vector2(0, (Demo.H - 320) * q)   # the floor at the bottom
		demo_render.show_run(demo.run, time, q)

## Every 30 frames: the average time spent in the game's rules and in its drawing, in milliseconds.
func _measure() -> void:
	perf["n"] += 1
	if perf["n"] < 30:
		return
	perf["draw"] += Render.draw_us
	Render.draw_us = 0
	perf["text"] = "jeu %.1f ms · dessin %.1f ms" % [perf["game"] / 30000.0, perf["draw"] / 30000.0]
	perf["n"] = 0
	perf["game"] = 0
	perf["draw"] = 0

# ---------- the debug menu (debug.gd) ----------

## Five touches on the level badge, each within two seconds of the first, open it.
func _on_level_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now = Time.get_ticks_msec()
	taps = taps.filter(func(t): return now - t < 2000)
	taps.append(now)
	if taps.size() >= 5:
		taps = []
		if Lock.unlocked():
			open_debug()
		else:
			_debug_password()

## The debug menu is locked (lock.gd): its password, asked once on this device.
func _debug_password() -> void:
	if Lock.waiting() > 0:
		_menu_note("Trop d'essais : réessaie dans %d s." % ceili(Lock.waiting()))
		return
	if _phone_web():                                 # (the browser's own box: readable above the keyboard)
		var got = _ask_text("Mot de passe du menu de debug :", "")
		if got is String and got.strip_edges() != "":
			_debug_try(got, null)
		return
	if modal != null:
		modal.queue_free()
	var layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root = Control.new()
	root.size = Vector2(W, H)
	root.theme = ui.theme
	layer.add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.7)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 150, 60, 300, 130)
	var col = _vbox(8)
	var l = _label("Mot de passe du menu de debug", ts("m"), INK, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = a(258)
	col.add_child(l)
	var close = func() -> void:
		layer.queue_free()
		modal = null
	var field: LineEdit = null
	var go_ = func() -> void:
		if field.text.strip_edges() != "":
			_debug_try(field.text, layer)
	field = _field("", 32, "", go_)
	field.secret = true
	col.add_child(field)
	var msg = _label("", ts("s"), DIM, 0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)
	layer.set_meta("msg", msg)
	var row = _hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_button("Annuler", "small plain", close))
	row.add_child(_button("Ouvrir", "small gold", go_))
	col.add_child(row)
	p.add_child(col)
	root.add_child(p)
	modal = layer
	field.grab_focus.call_deferred()

## Checks it (a moment: the password is drawn out on purpose, see lock.gd) and opens the menu if it is the one.
func _debug_try(password: String, layer) -> void:
	var msg: Label = layer.get_meta("msg") if layer != null else null
	if msg != null:
		msg.text = "Vérification…"
	await get_tree().process_frame
	await get_tree().process_frame
	if Lock.attempt(password):
		if layer != null:
			layer.queue_free()
			modal = null
		open_debug()
		return
	var why = ("Trop d'essais : réessaie dans %d s." % ceili(Lock.waiting())) if Lock.waiting() > 0 else "Ce n'est pas le bon mot de passe."
	if msg != null:
		msg.text = why
	else:
		_menu_note(why)

func open_debug() -> void:
	if debug_panel != null:
		debug_panel.queue_free()
	debug_panel = Debug.panel(self)
	debug_layer.add_child(debug_panel)

func close_debug() -> void:
	if debug_panel != null:
		debug_panel.queue_free()
		debug_panel = null
	if state == "menu":
		refresh_menu()

func _debug_changed() -> void:
	render.hitbox = Debug.dbg["hitbox"]
