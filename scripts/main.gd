extends Node
## Glue: screens, input, HUD and the frame loop (port of js/main.js, index.html and style.css).
## The screen is 1280 x 720 units, shown in 16:9 with bars around it (project settings); one art
## pixel is U units, and the interface is measured in art pixels like the web version's (--ui).

const VERSION := "0.36.0"
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

const DEATHS := ["La boucle se referme…", "Aïe. On rembobine.", "Retour au temple !", "Presque. Enfin… non.",
	"La jungle : 1 — Toi : 0", "Ça piquait, hein ?", "Encore ! Encore !", "Le temps te rattrape."]
const TABS := {"up": "Équipements", "power": "Pouvoirs", "mount": "Montures", "skin": "Skins"}
# The home screen's three buttons: what each one is about, in a panel while hovered or held.
const MENU_TIPS := {
	"endless": "Essayez autant que vous souhaitez de vous échapper de cette forêt, mais il y a peu de chances que vous vous en sortiez vivant.",
	"story": "Peut-être qu'il y a un scénario dans ce jeu… ou pas. À vous de voir.",
	"shop": "Parce que tout aventurier a le droit à sa panoplie de gadgets.",
}
const ACTS := ["tnt", "boots", "slow", "dash"]   # the HUD's buttons, right to left as shown
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
var set_tab := "main"
var fk := 0.95                         # evens out the sizes of the typefaces
var font: Font
var bold: Font                         # buttons, the HUD and titles: the bold cut
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
var held_t := 0.0
var tip_held := false                  # its panel came from a long press: that press launches nothing
var coop: Coop                         # two phones in one run (coop.gd)
var coop_start := {}                   # a coop run about to start: {seed, biome, tier, at}
var coop_send_t := 0.0
var coop_last := false                 # the last run was for two: « Rejouer » goes back to the room
var friends_tab := "friends"
var board: Array = []                  # the friends' board, as the server sent it

# ---------- start ----------

func _ready() -> void:
	Progress.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))   # prices, levels, objectives
	Tune.load_file()                              # reglages/equilibrage.txt: the game's numbers (before Debug takes its origin)
	save = SaveData.load_save()
	Net.load_config(FileAccess.get_file_as_string("res://reglages/reseau.txt"))   # the server's address, empty for now
	Net.set_from_args()
	net = Net.new()
	add_child(net)
	coop = Coop.new()
	coop.net = net
	coop.save = save
	add_child(coop)
	coop.changed.connect(func() -> void: refresh_friends())
	coop.message.connect(_on_coop)
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
	if "--test" in OS.get_cmdline_user_args() or web_test:
		var bench = load("res://scripts/bench.gd").new()
		bench.main = self
		add_child(bench)
	_load.call_deferred()

func _load() -> void:
	await get_tree().process_frame                # the "loading" text is on screen first
	var t0 = Time.get_ticks_msec()
	Art.load_all()
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
const KIT_FRAME := [16, 15, 21, 13]                          # panels: the stone frame left, right, top, bottom
const KIT_BAR := {8: [12, 13, 2, 6, 8, 9], 12: [15, 17, 4, 8, 12, 10]}   # ends l/r, trough rows, fill insets l/r

func _kit(name: String) -> Texture2D:
	var key = "kit:" + name
	if icons.has(key):
		return icons[key]
	var path = "res://assets/img/ui-v2/" + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var im = (load(path) as Texture2D).get_image()
		im.resize(roundi(im.get_width() * U), roundi(im.get_height() * U), Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(im)
	icons[key] = tex
	return tex

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
		var cap: int = KIT_CAP[h]
		var chosen: bool = (spec[0] as String).contains("gold")
		var pad = [cap * 0.8, cap * 0.8, 0, 0]
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
	styles["slot"] = _flat(Color(16 / 255.0, 20 / 255.0, 40 / 255.0, 0.5), Color(0, 0, 0, 0))   # its dashed edge is drawn by the slot itself
	styles["slot-full"] = _flat(Color("#2b3358"), GOLD, 2)

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
	_build_friends()
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
	var name = "hud" if state == "play" else state
	if screens.has(name):
		show_screen(name)
	if state == "pause":
		pause_view()
	if state == "over":
		over_view(false)

func _on_resized() -> void:
	_check_turn()
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
		ch.queue_free()
	for i in run.max_hearts:
		hearts.add_child(_icon_rect(icon("heart"), 20))
	hearts.visible = run.max_hearts > 1          # a single life needs no counter
	for k in ACTS:
		w["btn-" + k].visible = run.lvl(k) > 0

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
	s.add_child(top)
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
	_place(acts, 569 - 12 - 238, 320 - 12 - 52, 238, 52)
	s.add_child(acts)

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
	var s = _screen("menu", false)
	var gear = Button.new()
	gear.focus_mode = Control.FOCUS_NONE
	_kit_square(gear, "gear", 36)
	_place(gear, M, M, 36, 36)
	var on_gear = func() -> void:
		Audio.sfx("click")
		go("settings")
	gear.pressed.connect(on_gear)
	var pals = Button.new()                          # Amis: only once a server is set (reglages/reseau.txt)
	pals.focus_mode = Control.FOCUS_NONE
	_kit_square(pals, "blank", 36)
	pals.icon = icon("ico-friends")
	pals.expand_icon = true
	pals.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pals.add_theme_constant_override("icon_max_width", roundi(a(26)))
	_place(pals, M + 42, M, 36, 36)
	var on_pals = func() -> void:
		Audio.sfx("click")
		go("friends")
	pals.pressed.connect(on_pals)
	pals.visible = Net.enabled()
	w["menu-friends"] = pals
	s.add_child(pals)
	s.add_child(gear)
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
	_place(status, 569 - M - 200, M, 200, 60)
	w["menu-level"] = _level_box(false)
	w["menu-level"].mouse_filter = Control.MOUSE_FILTER_STOP
	w["menu-level"].gui_input.connect(_on_level_input)
	w["menu-level"].size_flags_horizontal = Control.SIZE_SHRINK_END
	status.add_child(w["menu-level"])
	w["menu-coins"] = _coins_pill()
	w["menu-coins"].size_flags_horizontal = Control.SIZE_SHRINK_END
	status.add_child(w["menu-coins"])
	s.add_child(status)
	var buttons = _vbox(M)
	_place(buttons, M, 98, 236, 170)
	for spec in [["Jouer", "play", "endless"], ["Histoire", "dark", "story"], ["Améliorations", "", ""]]:
		var mode: String = spec[2]
		var on_menu = func() -> void:
			if tip_held:
				tip_held = false                             # (it was held to read its panel)
				return
			if mode != "":
				save["mode"] = mode                  # Histoire or Run illimitée: « Rejouer » keeps it
				SaveData.store(save)
				go("play")
			else:
				tab = "up"
				go("shop")
		var b = _button(spec[0], spec[1], on_menu)
		b.size_flags_horizontal = Control.SIZE_FILL
		_menu_tip_on(b, mode if mode != "" else "shop")
		buttons.add_child(b)
	s.add_child(buttons)
	w["menu-tip"] = PanelContainer.new()            # what a button is about: hovered, or held down
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
	_place(w["menu-tip"], M + 236 + 6, 98, 300, 60)
	s.add_child(w["menu-tip"])
	var quests = _vbox(4)
	_place(quests, 569 - M - 218, 80, 218, 150)
	quests.add_child(_label("DÉFIS", ts("s"), INK, 1.5))
	w["menu-quests"] = _vbox(4)
	quests.add_child(w["menu-quests"])
	s.add_child(quests)
	w["menu-info"] = PanelContainer.new()
	w["menu-info"].add_theme_stylebox_override("panel", _kit_tall("menu-info"))
	w["menu-info"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(w["menu-info"], 569 / 2.0 - 150, 320 - M - 50 - 110, 300, 110)
	w["menu-info"].visible = false
	w["menu-info"].set_meta("still", true)
	w["menu-info"].z_index = 4
	s.add_child(w["menu-info"])
	w["menu-loadout"] = _hbox(M)
	_place(w["menu-loadout"], 212.5, 320 - M - 42, 150, 42)
	s.add_child(w["menu-loadout"])
	var version = _label("v" + VERSION + " · Godot", roundi(7 * U), DIM, 1)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.modulate.a = 0.75
	_place(version, 569 - M - 120, 320 - 5 - 9, 120, 10)
	s.add_child(version)

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
	if b != null:                                    # beside the button, its top level with the button's
		tip.position = Vector2(a(M + 236 + 6), b.get_global_rect().position.y)

## Where the next Run illimitée starts: any of the four sceneries. The home screen shows it already,
## the temple standing in it.
func _roll_biome() -> void:
	endless_biome = randi() % Game.BIOME_COUNT
	if still != null:
		still.biome = endless_biome
		still.prev_biome = endless_biome

## A HUD button pressed: tnt, boots, slow or dash.
func _act(k: String) -> void:
	match k:
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
	row.add_child(bar)
	if full:
		var pts = _label("", ts("s"), DIM, 0)
		pts.name = "pts"
		row.add_child(pts)
	p.add_child(row)
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
	for q in save["quests"]:
		var card = _box()
		var col = _vbox(3)
		var row = _hbox(6)
		var txt = _label("%s (%d/%d)" % [Progress.quest_text(q), floori(q["p"]), q["goal"]], ts("s"), INK, 0)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.custom_minimum_size.x = a(130)
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
		holder.add_child(card)
		set_bar(bar, float(q["p"]) / q["goal"])

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
	for text in ["Pépito a dérobé la relique du temple et l'a glissée dans son sac à dos. Il ne reste qu'à sortir de la jungle.",
			"Mais la relique plie le temps : à chaque chute, tout recommence devant le temple."]:
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

func _build_settings() -> void:
	var s = _screen("settings", true)
	var back = _button("Retour", "", func() -> void: go("menu"))
	_place(back, M, 6, 152, 38)
	s.add_child(back)
	_head(s, "Réglages")
	var left = _pane(s, false, 262)
	w["set-left"] = left
	var col = _vbox(6)
	var tabs = _hbox(4)
	for spec in [["main", "Général"], ["access", "Accessibilité"]]:
		var key: String = spec[0]
		var on_set_tab = func() -> void:
			set_tab = key
			refresh_settings()
		var b = _button(spec[1], "tab", on_set_tab)
		b.custom_minimum_size = Vector2(a(117), a(22))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		w["settab-" + key] = b
	col.add_child(tabs)
	var main = _vbox(6)
	main.add_child(_label("SON", ts("s"), RELIC, 0))
	for spec in [["Musique", "musicVol"], ["Effets", "sfxVol"]]:
		var key: String = spec[1]
		var row = _toggle_row(spec[0])
		var vol = _hbox(4)
		vol.add_child(_small_square("−", func() -> void: _volume(key, -1)))
		var bar = _bar(66, 12, GOLD)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vol.add_child(bar)
		w["vol-" + key] = bar
		vol.add_child(_small_square("+", func() -> void: _volume(key, 1)))
		row.add_child(vol)
		main.add_child(row)
	main.add_child(_label("AFFICHAGE", ts("s"), RELIC, 0))
	for spec in [["Police pixel", "tg-font"], ["Qualité", "tg-quality"], ["Plein écran", "tg-full"], ["Images par seconde", "tg-fps"]]:
		var row = _toggle_row(spec[0])
		var id: String = spec[1]
		var b = _button("", "small on", func() -> void: _toggle(id))
		b.custom_minimum_size.x = a(130)
		row.add_child(b)
		w[id] = b
		main.add_child(row)
		if id == "tg-full":
			row.visible = _can_full()
		if id == "tg-quality":
			var sub = _label("", ts("s"), DIM, 0)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.custom_minimum_size.x = a(240)
			w["q-sub"] = sub
			main.add_child(sub)
	w["panel-main"] = main
	col.add_child(main)
	var access = _vbox(6)
	for spec in [["Contour rouge des dangers", "tg-rim", "Un liseré rouge autour de tout ce qui fait mal."],
			["Signalements décalés", "tg-shift", "Les alertes des Fonceurs apparaissent plus à gauche, loin du pouce."]]:
		var row = _toggle_row(spec[0])
		var id: String = spec[1]
		var b = _button("", "small on", func() -> void: _toggle(id))
		b.custom_minimum_size.x = a(100)
		row.add_child(b)
		w[id] = b
		access.add_child(row)
		var sub = _label(spec[2], ts("s"), DIM, 0)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = a(240)
		access.add_child(sub)
	w["panel-access"] = access
	col.add_child(access)
	var scroll = ScrollContainer.new()                # more than the pane holds: it scrolls, as in the web version
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	left.add_child(scroll)
	var right = _pane(s, true, 262)
	w["set-right"] = right
	var rc = _vbox(6)
	rc.add_child(_label("SAUVEGARDE", ts("s"), RELIC, 0))
	var sub = _label("Elle se fait toute seule. Pour changer d'appareil, exporte le code puis importe-le (il marche aussi avec la version web).", ts("s"), DIM, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = a(240)
	rc.add_child(sub)
	w["save-code"] = TextEdit.new()
	w["save-code"].placeholder_text = "Code de sauvegarde"
	w["save-code"].custom_minimum_size = Vector2(a(240), a(26))
	w["save-code"].add_theme_font_size_override("font_size", roundi(7 * U))
	w["save-code"].wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rc.add_child(w["save-code"])
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", roundi(a(4)))
	grid.add_theme_constant_override("v_separation", roundi(a(4)))
	var on_export = func() -> void:
		var code = SaveData.export_code(save)
		w["save-code"].text = code
		DisplayServer.clipboard_set(code)
		_msg("Code copié.")
	grid.add_child(_button("Exporter", "small", on_export))
	grid.add_child(_button("Importer", "small", _import_field))
	grid.add_child(_button("Fichier", "small", _save_file))
	grid.add_child(_button("Ouvrir", "small", _open_file))
	rc.add_child(grid)
	w["save-msg"] = _label("", ts("s"), DIM, 0)
	rc.add_child(w["save-msg"])
	var do_reset = func() -> void:
		save = SaveData.reset()
		SaveData.store(save)
		_after_load()
		_msg("Progression effacée.")
	var ask_reset = func() -> void:
		_confirm("Effacer toute la progression ? C'est définitif.", do_reset)
	var reset = _button("Tout effacer", "small danger", ask_reset)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rc.add_child(reset)
	right.add_child(_fixed(rc))

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
			sc.remove_meta("closing")
			sc.visible = true
			sc.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
			for ch in sc.get_children():
				if ch.has_meta("rest"):
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

func refresh_menu() -> void:
	_set_level(w["menu-level"], false)
	_set_coins(w["menu-coins"], save["coins"])
	_quest_cards(w["menu-quests"])
	for ch in w["menu-loadout"].get_children():
		ch.queue_free()
	for i in 3:                                  # the three slots: what goes on the next run
		var id: String = save["equipped"][i] if i < save["equipped"].size() else ""
		var slot = Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(a(42), a(42))
		if id != "":                                 # filled: the kit's stone square, the picture inside its frame
			slot.add_theme_stylebox_override("normal", _kit_box("sq-blank-42", [0, 0, 0, 0], [7, 7, 7, 7]))
			slot.add_theme_stylebox_override("hover", _kit_box("sq-blank-42", [0, 0, 0, 0], [7, 7, 7, 7], Color(1.12, 1.12, 1.12)))
			slot.add_theme_stylebox_override("pressed", _down(_kit_box("sq-blank-42", [0, 0, 0, 0], [7, 7, 7, 7], Color(0.85, 0.85, 0.85))))
		else:
			for k in ["normal", "hover", "pressed"]:
				slot.add_theme_stylebox_override(k, styles["slot"])
		slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if id != "":
			slot.icon = icon("ico-" + SaveData.upgrade(id)["icon"])
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			slot.text = "+"
			slot.add_theme_font_size_override("font_size", ts("l"))
			slot.add_theme_color_override("font_color", Color(1, 248 / 255.0, 230 / 255.0, 0.6))
		var on_slot = func() -> void:          # an empty slot leads to the shop; a filled one says what it holds
			Audio.sfx("click")
			if id == "":
				tab = "up"
				go("shop")
			else:
				_slot_info(id)
		slot.pressed.connect(on_slot)
		var outline = func() -> void:
			if id == "":                         # empty: a dashed place on the scenery
				var col = Color(1, 248 / 255.0, 230 / 255.0, 0.4)
				var r = Rect2(Vector2.ZERO, slot.size).grow(-a(0.75))
				var dash = a(4)
				var x = r.position.x
				while x < r.end.x:
					var x2 = minf(x + dash, r.end.x)
					slot.draw_line(Vector2(x, r.position.y), Vector2(x2, r.position.y), col, a(1.5))
					slot.draw_line(Vector2(x, r.end.y), Vector2(x2, r.end.y), col, a(1.5))
					x += dash * 2
				var y = r.position.y
				while y < r.end.y:
					var y2 = minf(y + dash, r.end.y)
					slot.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y2), col, a(1.5))
					slot.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y2), col, a(1.5))
					y += dash * 2
			if slot.get_meta("sel", false):
				slot.draw_rect(Rect2(Vector2(-a(3), -a(3)), slot.size + Vector2(a(6), a(6))), INK, false, a(1.5))
		slot.draw.connect(outline)
		slot.set_meta("id", id)
		w["menu-loadout"].add_child(slot)

func _mark_slots(id: String) -> void:
	for sl in w["menu-loadout"].get_children():
		sl.set_meta("sel", id != "" and sl.get_meta("id", "") == id)
		sl.queue_redraw()

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
	var lvl = SaveData.level(save, id)
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
	for pair in [["tg-font", save["pixelFont"]], ["tg-full", _is_full()], ["tg-rim", save["dangerRim"]], ["tg-shift", save["alertShift"]], ["tg-fps", save["showFps"]]]:
		var b: Button = w[pair[0]]
		b.text = "Oui" if pair[1] else "Non"
		_style_button(b, "small on" if pair[1] else "small plain")
	w["tg-quality"].text = {"max": "Max", "perf": "Perf", "eco": "Éco"}[quality()]
	w["q-sub"].text = {"max": "L'image la plus fine, autant d'images par seconde que l'écran.",
		"perf": "Une image plus légère, tenue à 60 images par seconde : plus fluide.",
		"eco": "30 images par seconde et moins de petits détails : la batterie dure plus."}[quality()]
	for key in ["musicVol", "sfxVol"]:
		set_bar(w["vol-" + key], save[key] / 10.0)
	for key in ["main", "access"]:
		w["panel-" + key].visible = set_tab == key
		_style_button(w["settab-" + key], "tab sel" if set_tab == key else "tab")
	w["set-right"].visible = not in_run         # opened from the pause: the save waits for the end of the run
	var rest = Vector2(a(153.5) if in_run else a(14), w["set-left"].get_meta("rest", w["set-left"].position).y)
	if w["set-left"].get_meta("rest", Vector2.ZERO) != rest:
		_set_rest(w["set-left"], rest)

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

func _import(code: String) -> void:
	var s = SaveData.import_code(code)
	if s == null:
		_msg("Code invalide : rien n'a été changé.")
		return
	var do_import = func() -> void:
		save = s
		SaveData.store(save)
		_after_load()
		_msg("Partie importée.")
	_confirm("Remplacer la partie actuelle par celle-ci ?\n%d pièces · record %d m · %d courses" % [s["coins"], s["best"], s["loops"]], do_import)

func _after_load() -> void:
	Audio.set_volumes(save["musicVol"], save["sfxVol"])
	Art.set_danger_rim(save["dangerRim"])
	render.shift = save["alertShift"]
	refresh_settings()

## A question in the game's own look (the web version's confirm()): a pane, « Non » and « Oui ».
func _confirm(text: String, fn: Callable) -> void:
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
	row.add_child(_button("Non", "small plain", close))
	row.add_child(_button("Oui", "small gold", yes))
	col.add_child(row)
	p.add_child(col)
	root.add_child(p)
	modal = layer

func _import_field() -> void:
	var code: String = w["save-code"].text.strip_edges()
	if code == "" and OS.has_feature("web"):         # on a phone the field cannot be typed in: the browser asks
		var got = JavaScriptBridge.eval("window.prompt('Colle ici ton code de sauvegarde :') || ''", true)
		code = str(got) if got != null else ""
		w["save-code"].text = code
	if code == "":
		_msg("Colle d'abord un code dans le champ.")
		return
	_import(code)

## The code in a file: downloaded in a browser, saved where the player chooses elsewhere.
func _save_file() -> void:
	var code = SaveData.export_code(save)
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

func _open_file() -> void:
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
		_import(FileAccess.get_file_as_string(path))
	d.file_selected.connect(on_file)
	add_child(d)
	d.popup_centered_ratio(0.6)

func _on_opened(args: Array) -> void:
	_import(str(args[0]) if args.size() > 0 else "")

# ---------- the browser (web only) ----------

func _js(code: String):
	return JavaScriptBridge.eval(code, true) if OS.has_feature("web") else null

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
		stage.tex = icon("mount-" + open_k)
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
		var l = _label("Bientôt : la tenue, les cheveux, la cape et les baskets du héros, à changer séparément.", ts("s"), DIM, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = a(226)
		list.add_child(l)
		_card("Skins", "À venir.", "")
		_show_demo("sprint", 1)
		return
	var full: bool = save["equipped"].size() >= SaveData.MAX_EQUIPPED
	var shown: Array = SaveData.UPGRADES.filter(func(u): return SaveData.family(u) == tab)
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
	if not run.debug and Net.enabled():              # the friends' board (once the server is up)
		net.send_score(save, run.mode, floori(run.dist))
	if run.debug:
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
	Audio.duck(false)
	_menu_tip("")
	if name == "settings" and state == "pause":
		in_run = true
	if name == "play":
		if not save["seenIntro"] and coop_start.is_empty():
			save["seenIntro"] = true
			SaveData.store(save)
			state = "intro"
			show_screen("intro")
			Audio.music("")
			return
		var co = coop_start
		coop_start = {}
		coop_last = not co.is_empty()
		var up = SaveData.loadout(save)                # only the three equipped upgrades come along
		if coop_last:                                  # for two: the same road (seed, scenery, tier), and nothing
			up.erase("dash")                           # that changes one player's pace: no Esquive, Sablier nor mount
			up.erase("slow")
			run = Game.new_run(up, "endless", int(co["seed"]))
			run.coop = true
			run.road_tier = int(co["tier"])
			if coop.role == "guest":
				run.home = Game.PX - 70                 # just behind the host, on both screens: both are seen
			run.mounts = []
			run.next_mount = INF
			endless_biome = int(co["biome"])
		else:
			run = Game.new_run(up, save["mode"])
			run.mounts = Game.MOUNT_KINDS.filter(func(k): return not k in save["mountsOff"])   # Montures: on / off
		run.view_w = render.view_w * Game.PIXEL
		if run.mode == "endless":                   # Jouer: in the scenery the home screen showed
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
		Progress.start_run(save)
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
	if name == "shop":
		refresh_shop()
	if name == "friends":
		refresh_friends()
		_load_friends()
	if name == "settings":
		w["save-code"].text = ""
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
	if run.coop:
		coop.send({"t": "end"})
	var record = not run.debug and floori(run.dist) > best_of(run.mode)
	bank()
	over_info = {"title": Game.pick(DEATHS), "record": record, "dist": floori(run.dist), "gold": run.gold, "debug": run.debug, "mode": run.mode}
	hint(0)
	over_view(true)
	if record:
		confetti(60)
		Audio.sfx("record")
	Audio.music("over")                              # the run's music winds down, the menu's comes in
	state = "over"
	show_screen("over")
	if not levels_due.is_empty():                    # the levels gained, once the end screen is up
		get_tree().create_timer(1.3).timeout.connect(show_levels)

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
	if count_up:
		var dur = minf(1.1, 0.25 + dist * 0.012)
		var tw = create_tween()
		var count = func(v: float) -> void:        # counts up on screen, with a tick
			var shown = roundi(v)
			if w["over-dist"].text != "%d m" % shown and shown % 3 == 0:
				Audio.sfx("tick")
			w["over-dist"].text = "%d m" % shown
			w["over-gold"].text = "+%d" % roundi(gold * (v / dist if dist > 0 else 1.0))
		tw.tween_method(count, 0.0, float(dist), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		w["over-dist"].text = "%d m" % dist
		w["over-gold"].text = "+%d" % gold
	w["over-best"].text = "Debug : record non enregistré" if over_info["debug"] else ("★ Nouveau record ! ★" if record else "Record : %d m" % best_of(over_info["mode"]))
	_set_colour(w["over-best"], GOLD if record else DIM)
	w["over-best"].label_settings.font_size = ts("m") if record else ts("s")
	w["over-best"].set_meta("hop", record)

## « Rejouer »: after a run for two, back to the room (the host starts the next one); alone, again.
func _replay() -> void:
	if coop_last and coop.state == "ready":
		friends_tab = "coop"
		go("friends")
	else:
		go("play")

# ---------- Amis: the friend code, the week's board, and playing for two ----------

func _field(hint_: String, length: int) -> LineEdit:
	var f = LineEdit.new()
	f.placeholder_text = hint_
	f.max_length = length
	f.custom_minimum_size = Vector2(a(140), a(24))
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_font_override("font", bold)
	f.add_theme_font_size_override("font_size", ts("m"))
	f.add_theme_color_override("font_color", INK)
	f.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	var sb = _flat(Color("#141a30"), LINE)
	f.add_theme_stylebox_override("normal", sb)
	f.add_theme_stylebox_override("focus", _flat(Color("#141a30"), GOLD))
	return f

func _wrap(text: String, colour: Color) -> Label:
	var l = _label(text, ts("s"), colour, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = a(224)
	return l

func _build_friends() -> void:
	var s = _screen("friends", true)
	var back = _button("Retour", "", func() -> void: go("menu"))
	_place(back, M, 6, 152, 38)
	s.add_child(back)
	_head(s, "Amis")
	var left = _pane(s, false, 262)
	var col = _vbox(6)
	var tabs = _hbox(4)
	for spec in [["friends", "Amis"], ["coop", "Jouer à deux"]]:
		var key: String = spec[0]
		var on_tab = func() -> void:
			friends_tab = key
			refresh_friends()
		var b = _button(spec[1], "tab", on_tab)
		b.custom_minimum_size = Vector2(a(110), a(22))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		w["frtab-" + key] = b
	col.add_child(tabs)
	var fr = _vbox(5)                                   # the friend code, the pseudonym, adding a friend
	fr.add_child(_label("TON CODE AMI", ts("s"), RELIC, 0))
	w["fr-code"] = _label("…", ts("xl"), GOLD)
	fr.add_child(w["fr-code"])
	fr.add_child(_label("TON PSEUDO", ts("s"), RELIC, 0))
	var name_row = _hbox(4)
	w["fr-name"] = _field("Pépito", 16)
	name_row.add_child(w["fr-name"])
	name_row.add_child(_button("OK", "small", _rename))
	fr.add_child(name_row)
	fr.add_child(_label("AJOUTER UN AMI", ts("s"), RELIC, 0))
	var add_row = _hbox(4)
	w["fr-add"] = _field("PEPI-XXXX", 9)
	add_row.add_child(w["fr-add"])
	add_row.add_child(_button("Ajouter", "small", _add_friend))
	fr.add_child(add_row)
	w["fr-msg"] = _wrap("", DIM)
	fr.add_child(w["fr-msg"])
	w["panel-friends"] = fr
	col.add_child(fr)
	var co = _vbox(6)                                   # playing for two: a room, its four letters
	w["co-room"] = _label("", ts("huge"), GOLD)
	w["co-room"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	co.add_child(w["co-room"])
	w["co-text"] = _wrap("", INK)
	co.add_child(w["co-text"])
	w["co-host"] = _button("Créer un salon", "small", _coop_host)
	w["co-host"].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	co.add_child(w["co-host"])
	var join_row = _hbox(4)
	w["co-code"] = _field("ABCD", 4)
	join_row.add_child(w["co-code"])
	join_row.add_child(_button("Rejoindre", "small", _coop_join))
	w["co-join-row"] = join_row
	co.add_child(join_row)
	var go_row = _hbox(6)
	w["co-go"] = _button("Partir !", "go", _coop_go)
	go_row.add_child(w["co-go"])
	w["co-leave"] = _button("Quitter", "small plain", func() -> void: coop.leave())
	w["co-leave"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(w["co-leave"])
	co.add_child(go_row)
	w["panel-coop"] = co
	col.add_child(co)
	left.add_child(_fixed(col))
	var right = _pane(s, true, 262)                       # the week's board
	var rc = _vbox(4)
	rc.add_child(_label("CETTE SEMAINE", ts("s"), RELIC, 0))
	w["fr-board"] = _vbox(3)
	rc.add_child(w["fr-board"])
	var again = _button("Actualiser", "small", _load_friends)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rc.add_child(again)
	right.add_child(_fixed(rc))

func refresh_friends() -> void:
	if not w.has("fr-code") or not is_instance_valid(w["fr-code"]):
		return
	if w.has("menu-friends") and is_instance_valid(w["menu-friends"]):
		w["menu-friends"].visible = Net.enabled()
	for key in ["friends", "coop"]:
		_style_button(w["frtab-" + key], "tab sel" if key == friends_tab else "tab")
		w["frtab-" + key].custom_minimum_size = Vector2(a(110), a(22))
	w["panel-friends"].visible = friends_tab == "friends"
	w["panel-coop"].visible = friends_tab == "coop"
	var on: Dictionary = save.get("online", {})
	w["fr-code"].text = on.get("code", "…")
	if w["fr-name"].text == "" and on.get("name", "") != "":
		w["fr-name"].text = on["name"]
	coop.save = save
	var st = coop.state
	var can = Coop.supported()
	var mate_name: String = coop.mate.get("name", "") if coop.mate.get("name", "") != "" else "ton ami"
	var idle = st in ["idle", "failed"]
	w["co-host"].visible = can and idle
	w["co-join-row"].visible = can and idle
	w["co-room"].text = coop.room if coop.role == "host" and st in ["waiting", "linking", "ready"] else ""
	w["co-room"].visible = w["co-room"].text != ""
	w["co-go"].visible = st == "ready" and coop.role == "host"
	w["co-leave"].visible = not idle
	var txt = ""
	if not can:
		txt = "Jouer à deux marche dans le navigateur, sur la page du jeu."
	else:
		match st:
			"idle": txt = "Crée un salon et donne ses 4 lettres à ton ami, ou rejoins le sien. Vous courez la même route ; si l'un tombe, il flotte dans une bulle : l'autre saute dedans pour le ramener."
			"opening": txt = "Ouverture du salon…"
			"waiting": txt = "Donne ces 4 lettres à ton ami. En attente…"
			"joining": txt = "Recherche du salon…"
			"linking": txt = "Connexion avec %s…" % mate_name
			"ready": txt = ("Connecté avec %s ! Lance la course quand vous êtes prêts." % mate_name) if coop.role == "host" else ("Connecté avec %s ! La course part quand il la lance." % mate_name)
			"failed": txt = coop.info
	w["co-text"].text = txt
	var holder: VBoxContainer = w["fr-board"]
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.queue_free()
	if board.size() <= 1:
		holder.add_child(_wrap("Ajoute un ami avec son code : vos meilleures distances de la semaine s'afficheront ici." if Net.enabled() else "Le serveur n'est pas encore en ligne.", DIM))
	for e in board:
		var row = _box()
		var h = _hbox(6)
		var me = e.get("me", false)
		var nm = _label(str(e.get("name", "?")), ts("s"), GOLD if me else INK, 0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		h.add_child(nm)
		var dist = func(v) -> String: return ("%d m" % int(v)) if int(v) > 0 else "—"
		h.add_child(_label("Jouer " + dist.call(e.get("endless_week", 0)), ts("s"), RELIC, 0))
		h.add_child(_label("Hist. " + dist.call(e.get("week", 0)), ts("s"), DIM, 0))
		row.add_child(h)
		holder.add_child(row)

func _load_friends() -> void:
	if not Net.enabled():
		refresh_friends()
		return
	w["fr-msg"].text = ""
	var r = await net.friends(save)
	if r.has("error"):
		w["fr-msg"].text = "Pas de réponse du serveur."
		refresh_friends()
		return
	board = [r["me"]] + r.get("friends", [])
	refresh_friends()

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
	var r = await net.add_friend(save, code)
	if r.has("error"):
		w["fr-msg"].text = {"unknown": "Aucun joueur n'a ce code.", "self": "C'est ton propre code !"}.get(r["error"], "Pas de réponse du serveur.")
		return
	w["fr-msg"].text = "%s est ton ami." % r["name"]
	w["fr-add"].text = ""
	_load_friends()

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

## The host starts the run for two: the same seed, scenery and road for both, a moment from now.
func _coop_go() -> void:
	if coop.state != "ready" or coop.role != "host":
		return
	var msg = {"t": "start", "seed": coop.seed, "biome": endless_biome, "tier": mini(Coop.tier(save), int(coop.mate.get("tier", 0))), "in": 0.8}
	coop.send(msg)
	_coop_begin(msg, 0.8)

func _coop_begin(m: Dictionary, delay: float) -> void:
	coop_start = {"seed": int(m["seed"]), "biome": int(m["biome"]), "tier": int(m["tier"]), "at": time + delay}
	save["mode"] = "endless"
	print("coop: start in %.2f s, seed %d, tier %d" % [delay, int(m["seed"]), int(m["tier"])])

## What the partner says (coop.gd): where he is, his bubble, the run's start and end.
func _on_coop(m: Dictionary) -> void:
	var t = str(m.get("t", ""))
	if t == "start" and coop.role == "guest":
		_coop_begin(m, maxf(0.1, float(m.get("in", 0.8)) - coop.rtt / 2))         # (he started RTT/2 later)
		return
	if run == null or not run.coop:
		return
	match t:
		"s":
			var was = run.mate != null and run.mate.get("b", false)
			run.mate = m
			if m.get("b", false) and not was:
				run.mate_bubble = Vector2(float(m["x"]), float(m["y"]) - 40)
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

func resume() -> void:
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
func show_levels() -> void:
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
	for k in ACTS:
		var act = {"dash": run.dash, "slow": run.slow, "boots": run.boots, "tnt": run.tnt}[k]
		var cool: Cooldown = w["cd-" + k]
		var v: float = act.cd / act.full if act.full > 0 else 0.0
		if absf(cool.k - v) > 0.005 or (v == 0 and cool.k != 0):
			cool.k = v
			cool.queue_redraw()
			w["btn-" + k].modulate = Color(0.7, 0.7, 0.7) if v > 0 else Color.WHITE

# ---------- input ----------

func press() -> void:
	if state == "play":
		input.pressed = true
		input.hold = true

## Which of the HUD's buttons is under a spot, if any.
func _hud_button_at(pos: Vector2) -> String:
	for k in ["btn-pause", "btn-dash", "btn-slow", "btn-boots", "btn-tnt"]:
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

			"btn-slow", "btn-boots", "btn-tnt", "btn-dash":
				_act(_hud_button_at(event.position).substr(4))
				get_viewport().set_input_as_handled()
	var down = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION)
	if down and state == "menu" and w.has("menu-tip") and w["menu-tip"].visible:
		var on_button = false                          # a touch elsewhere puts the panel away
		for b in w["menu-tip"].get_parent().get_children():
			if b is VBoxContainer:
				for bb in b.get_children():
					if bb is Button and bb.get_global_rect().has_point(event.position):
						on_button = true
		if not on_button:
			_menu_tip("")
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
		elif k.keycode == KEY_ESCAPE or label == KEY_P:
			if state == "play":
				pause()
			elif state == "pause":
				resume()
			elif in_run:
				go("menu")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause()
		Audio.sleep(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		Audio.sleep(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:   # closing mid-run still keeps the coins picked up so far
		if state == "play" or state == "pause" or in_run:
			bank()

# ---------- loop ----------

func _process(delta: float) -> void:
	var dt = minf(0.034, delta)                  # (30 images a second, in Éco, still run at full speed)
	if rebuild_due and state != "play" and state != "loading" and state != "pause":
		rebuild_t -= delta
		if rebuild_t <= 0:
			_rebuild()
	time += delta
	if state == "loading":
		return
	if state == "play" or state == "over":
		run.view_w = render.view_w * Game.PIXEL
		var t0 = Time.get_ticks_usec()
		Game.update(run, dt, input)
		perf["game"] += Time.get_ticks_usec() - t0
		var stats = {"dist": run.dist - last_dist, "coins": 0, "gems": 0, "jumps": 0, "plats": 0, "breaks": 0, "shrooms": 0, "monkeys": 0, "mounts": 0, "dodges": 0, "hurt": false}
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
				"boom": Audio.music("run")
				"boss": banner("Vorace !")           # (text on screen only for the bosses)
				"timber": banner("Ça tombe !")
				"bossfall": banner("Écrasée !")
				"bossdown": banner("Vorace est vaincue !")
				"hurt", "rewind", "hit": stats["hurt"] = true
				"life":                                 # a floating life picked up: one more heart
					Audio.sfx("level")
					_fill_hud()
				"brake":                                # a floating brake: 4 m/s less, for good
					Audio.sfx("slow")
				"fatal":                                # the blow that ends the run: the photo, now
					if not photo_taken:
						photo_taken = true
						_take_photo()
				"bubble", "rescue", "back":               # coop: the partner is told
					print("coop: ", ev)
					coop.send({"t": ev})
		run.events.clear()
		if run.coop and coop.state == "ready" and not run.dead:   # where he is, for the partner's screen
			coop_send_t -= dt
			if coop_send_t <= 0:
				coop_send_t = 1.0 / 15
				coop.send({"t": "s", "x": run.cam + run.sx, "y": run.p.y, "vy": run.p.vy, "g": run.p.ground, "f": run.p.flying, "ph": run.p.phase, "b": run.bubble, "d": run.dist}, false)
		progress(stats)
		if hint_step == 1 and stats["jumps"] > 0:
			hint(2)
		elif hint_step == 2:
			hint_timer -= dt
			if hint_timer <= 0:
				hint(0)
		hud()
		if state == "play" and run.dead:
			if not photo_taken:
				photo_taken = true
				_take_photo()
			dead_for += dt
			if dead_for > 0.9:
				game_over()
	if not coop_start.is_empty() and time >= coop_start["at"] and state != "play":
		go("play")                                   # the coop run: both phones start together
	input.pressed = false
	input.dash = false
	input.slow = false
	input.stomp = false
	input.tnt = false
	if held != null and is_instance_valid(held) and state == "menu" and not tip_held and time - held_t > 0.45:
		tip_held = true                             # held long enough: its panel, and no launch on release
		_menu_tip(held.get_meta("tip", ""), held)
	if banner_timer > 0:
		banner_timer -= dt
		if banner_timer <= 0:
			create_tween().tween_property(w["banner"], "modulate:a", 0.0, 0.35)
	if w.has("over-best") and is_instance_valid(w["over-best"]):
		var rb: Label = w["over-best"]
		if rb.get_meta("hop", false) and state == "over":
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
	var shown: Game.Run = run if (state == "play" or state == "pause" or state == "over" or in_run) and run != null else still
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
		open_debug()

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
