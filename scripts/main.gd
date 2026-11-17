extends Node
## Glue: screens, input, HUD and the frame loop (port of js/main.js, index.html and style.css).
## The screen is 1280 x 720 units, shown in 16:9 with bars around it (project settings); one art
## pixel is U units, and the interface is measured in art pixels like the web version's (--ui).

const VERSION := "0.29.0"
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
var cap := 4                           # the finest picture this device has proved it can keep up with
var watch := {"n": 0, "sum": 0.0, "bad": 0, "before": 0.0, "locked": false}
var CAP_FILE := "user://jungle-loop-cap" + ("-bac" if "--bac" in OS.get_cmdline_user_args() else "") + ".txt"
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
var touches := {}                     # fingers down on the game (not on a button): the jump is held while one stays
var confetti_layer: Control
var modal: CanvasLayer = null          # the in-game « Oui / Non » question, while one is asked
var web_cbs := []                      # the browser's callbacks, kept alive (web only)
var rebuild_due := false               # the window changed size: the pixel typeface's sizes are worked out again
var rebuild_t := 0.0
var fps_param := false                 # "?fps" in the address (web): the frame rate shown, as in the web version                   # (once it has stopped changing for a moment)
var perf := {"n": 0, "game": 0, "draw": 0, "text": ""}   # what a frame costs, averaged: the FPS corner shows it

# ---------- start ----------

func _ready() -> void:
	save = SaveData.load_save()
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
	cap = 3 if _touch() else 4                    # a phone's chip fills far fewer pixels than a PC's
	if FileAccess.file_exists(CAP_FILE):
		cap = clampi(int(FileAccess.get_file_as_string(CAP_FILE)), 1, 4)
	get_window().size_changed.connect(fit)
	fit()
	still = Game.new_run({})
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
	Game.set_shapes(FileAccess.get_file_as_string("res://assets/patterns.txt"))
	for n in ["ui-btn-slate-38", "ui-btn-slate-30", "ui-btn-green-50", "ui-btn-gold-38", "ui-btn-gold-30", "ui-gear", "ui-title", "coin-icon", "heart"]:
		icons[n] = _tex(n)
	_styles()
	_build()
	w["loading"].queue_free()
	await get_tree().process_frame               # every block has its size: each one is told where it flies from
	_aim_flyers()
	print("Jungle Loop %s : prêt en %d ms (dont images %d ms)" % [VERSION, Time.get_ticks_msec() - t0, t_art])
	go("menu")

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

## The game is always shown in 16:9 (569 x 320 art pixels). Its picture holds q x q real pixels per art
## pixel: `want` is what the screen can show (4 at most). Sprites then move by fractions of an art pixel
## and the picture is softened as it is fitted to the screen: "smooth". It costs: a phone has to fill up
## to sixteen times the pixels. So "auto" starts there and comes down as far as it takes to keep the
## frame rate (see _watch); "sharp" settles for 2 at most and shows hard squares, the lightest picture.
func fit() -> void:
	var win = Vector2(get_window().size)
	var real = U * minf(win.x / W, win.y / H)
	var want = clampi(ceili(real - 0.01), 1, 4)
	var mode = save["quality"] if save != null else "auto"
	if mode == "sharp":
		q = clampi(floori(real + 0.01), 1, 2)
	elif mode == "smooth":
		q = want
	else:
		q = mini(want, cap)
	game_vp.size = Vector2i(569 * q, 320 * q)
	demo_vp.size = Vector2i(roundi(Demo.W * q), roundi(Demo.H * q))
	# finer than the screen: fitted smoothly; coarser (2 or less): hard squares, smoothed it would only blur
	var smooth = mode != "sharp" and (q >= real - 0.01 or q > 2)
	game_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	if w.has("demo-view"):
		w["demo-view"].texture_filter = game_view.texture_filter

## "auto" quality: while playing, frames are timed. Two slow spells in a row (under 54 frames a second)
## and the picture goes down one step. If that changed nothing, the device is simply capped (battery
## saver, 30 Hz screen): the step is given back and nothing more is tried. What was found is kept.
func _watch(ms: float) -> void:
	if state != "play" or ms > 100 or run == null or run.t < 2:
		return
	watch["n"] += 1
	watch["sum"] += ms
	if watch["n"] < 90:
		return
	var avg = watch["sum"] / watch["n"]
	watch["n"] = 0
	watch["sum"] = 0.0
	if save["quality"] != "auto" or watch["locked"]:
		return
	if watch["before"] > 0:                          # just came down a step: was it worth it?
		if avg > watch["before"] * 0.9:
			cap = q + 1
			watch["locked"] = true
		watch["before"] = 0.0
		watch["bad"] = 0
	elif avg > 18.5 and q > 1:
		watch["bad"] += 1
		if watch["bad"] < 2:
			return
		cap = q - 1
		watch["before"] = avg
	else:
		watch["bad"] = 0
		return
	var f = FileAccess.open(CAP_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(str(cap))
	fit()

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
	for spec in [["", "ui-btn-slate-38", 38, 41], ["big", "ui-btn-green-50", 50, 54], ["small", "ui-btn-slate-30", 30, 33], ["gold", "ui-btn-gold-38", 38, 41], ["small gold", "ui-btn-gold-30", 30, 33]]:
		var inset = 0.6 if spec[2] == 50 else 0.85
		styles[spec[0]] = {
			"normal": _plaque(spec[1], spec[2], spec[3], Color.WHITE, inset),
			"hover": _plaque(spec[1], spec[2], spec[3], Color(1.12, 1.12, 1.12), inset),
			"pressed": _down(_plaque(spec[1], spec[2], spec[3], Color(0.9, 0.9, 0.9), inset)),
			"disabled": _plaque(spec[1], spec[2], spec[3], Color(0.55, 0.55, 0.6), inset),
			"h": spec[2],
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
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, styles[key][st])
	b.custom_minimum_size = Vector2(a(30 + 2 * (54 if size == "big" else 41)), a(styles[key]["h"]))
	if size == "small":
		b.custom_minimum_size.x = a(96)
	var colour = Color("#fff3d6")
	if gold:
		colour = Color("#4a3200")
	elif "plain" in parts:
		colour = DIM
	elif "danger" in parts:
		colour = Color("#ff8ea6")
	elif size == "big":
		colour = Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, colour)
	b.add_theme_color_override("font_disabled_color", colour.darkened(0.4))
	b.add_theme_color_override("font_outline_color", Color(1, 244 / 255.0, 190 / 255.0, 0.8) if gold else Color(10 / 255.0, 14 / 255.0, 34 / 255.0, 0.85))
	b.add_theme_constant_override("outline_size", roundi(a(1.5)))
	b.add_theme_font_size_override("font_size", ts("l") if size == "big" else (ts("s") if size == "small" else ts("m")))

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
func _bar(width: float, height: float, colour: Color) -> Panel:
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", _flat(Color("#0d1020")))
	p.custom_minimum_size = Vector2(a(width), a(height))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f = ColorRect.new()
	f.color = colour
	f.anchor_bottom = 1
	f.offset_left = a(1.5)
	f.offset_top = a(1.5)
	f.offset_bottom = -a(1.5)
	f.offset_right = a(1.5)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.name = "fill"
	p.add_child(f)
	return p

func set_bar(bar: Panel, k: float) -> void:
	var f: ColorRect = bar.get_node("fill")
	k = clampf(k, 0, 1)
	f.anchor_right = k
	f.offset_right = a(1.5) - k * a(3)

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

func _pane(s: Control, right: bool, height: float = 204) -> PanelContainer:
	var p = _box("pane")
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
	w["btn-dash"].visible = run.lvl("dash") > 0
	w["btn-slow"].visible = run.lvl("slow") > 0

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
	pause_b.custom_minimum_size = Vector2(a(36), a(36))
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
	for k in ["slow", "dash"]:
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
			if k == "dash":
				input.dash = true
			else:
				input.slow = true
		b.button_down.connect(on_down)
		acts.add_child(b)
		w["btn-" + k] = b
		w["cd-" + k] = cool
	_place(acts, 569 - 12 - 114, 320 - 12 - 52, 114, 52)
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
	gear.flat = true
	gear.icon = icon("ui-gear")
	gear.expand_icon = true
	gear.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_place(gear, M, M, 40, 40)
	var on_gear = func() -> void:
		Audio.sfx("click")
		go("settings")
	gear.pressed.connect(on_gear)
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
	_place(buttons, M, 106, 236, 160)
	for spec in [["Histoire", "big", "story"], ["Run illimitée", "big", "endless"], ["Améliorations", "", ""]]:
		var mode: String = spec[2]
		var on_menu = func() -> void:
			if mode != "":
				save["mode"] = mode                  # Histoire or Run illimitée: « Rejouer » keeps it
				SaveData.store(save)
				go("play")
			else:
				tab = "up"
				go("shop")
		var b = _button(spec[0], spec[1], on_menu)
		b.size_flags_horizontal = Control.SIZE_FILL
		buttons.add_child(b)
	s.add_child(buttons)
	var quests = _vbox(4)
	_place(quests, 569 - M - 218, 80, 218, 150)
	quests.add_child(_label("DÉFIS", ts("s"), INK, 1.5))
	w["menu-quests"] = _vbox(4)
	quests.add_child(w["menu-quests"])
	s.add_child(quests)
	w["menu-info"] = _box("pane")
	_place(w["menu-info"], 569 / 2.0 - 150, 320 - M - 50 - 60, 300, 56)
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
		var r1 = _label("+%d ◈" % q["reward"], ts("s"), GOLD, 0)
		r1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	var p = _box("pane")
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

func _build_shop() -> void:
	var s = _screen("shop", true)
	var side = _vbox(4)
	_place(side, 6, 6, 50, 308)
	var back = _button("Retour", "tab", func() -> void: go("menu"))
	back.custom_minimum_size = Vector2(a(50), a(36))
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
		b.add_theme_font_size_override("font_size", roundi(6.5 * U))
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(b)
		w["tab-" + key] = b
	s.add_child(side)
	w["shop-title"] = _label("", ts("s"), RELIC, 1.5)
	_place(w["shop-title"], 64, 11, 250, 14)
	s.add_child(w["shop-title"])
	w["shop-coins"] = _coins_pill()
	_place(w["shop-coins"], 569 - M - 80, 4, 80, 22)
	s.add_child(w["shop-coins"])
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, 62, 30, 262, 196)
	w["shop-list"] = GridContainer.new()
	w["shop-list"].columns = 4
	w["shop-list"].add_theme_constant_override("h_separation", roundi(a(4)))
	w["shop-list"].add_theme_constant_override("v_separation", roundi(a(4)))
	scroll.add_child(w["shop-list"])
	s.add_child(scroll)
	var card = _box("pane")
	_place(card, 62, 230, 262, 82)
	var col = _vbox(3)
	w["card-name"] = _label("", ts("m"), GOLD, 0)
	w["card-status"] = _label("", ts("s"), DIM, 0)
	w["card-status"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["card-status"].custom_minimum_size.x = a(240)
	w["card-actions"] = _hbox(4)
	w["card-actions"].alignment = BoxContainer.ALIGNMENT_END
	w["card-actions"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(w["card-name"])
	col.add_child(w["card-status"])
	col.add_child(w["card-actions"])
	card.add_child(col)
	s.add_child(card)
	var prev = PanelContainer.new()
	var ps: StyleBoxFlat = styles["pane"].duplicate()
	ps.set_content_margin_all(a(6))
	prev.add_theme_stylebox_override("panel", ps)
	_place(prev, 569 - M - 227, 30, 227, 282)
	var pc = _vbox(6)
	pc.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.custom_minimum_size = Vector2(a(212), a(212 * Demo.H / Demo.W))
	view.texture_filter = game_view.texture_filter
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(view)
	pc.add_child(frame)
	w["demo-view"] = view
	w["demo-desc"] = _label("", ts("s"), DIM, 0)
	w["demo-desc"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["demo-desc"].custom_minimum_size.x = a(212)
	pc.add_child(w["demo-desc"])
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
	for spec in [["Police pixel", "tg-font"], ["Lissage", "tg-smooth"], ["Plein écran", "tg-full"], ["Images par seconde", "tg-fps"]]:
		var row = _toggle_row(spec[0])
		var id: String = spec[1]
		var b = _button("", "small on", func() -> void: _toggle(id))
		b.custom_minimum_size.x = a(130)
		row.add_child(b)
		w[id] = b
		main.add_child(row)
		if id == "tg-full":
			row.visible = _can_full()
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
	right.add_child(rc)

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
	b.custom_minimum_size = Vector2(a(28), a(28))
	b.add_theme_font_size_override("font_size", ts("l"))
	return b

func _build_score(name: String) -> void:
	var s = _screen(name, true)
	w[name + "-title"] = _head(s, "Pause" if name == "pause" else DEATHS[0])
	var left = _pane(s, false)
	var col = _vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	w[name + "-dist"] = _label("0 m", ts("huge"), INK, 3)
	w[name + "-gold"] = _label("", ts("xl"), GOLD)
	w[name + "-best"] = _label("", ts("s"), DIM, 0)
	for k in ["dist", "gold", "best"]:
		w[name + "-" + k].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(w[name + "-" + k])
	left.add_child(col)
	var right = _pane(s, true)
	var rc = _vbox(6)
	w[name + "-level"] = _level_box(true)
	rc.add_child(w[name + "-level"])
	w[name + "-quests"] = _vbox(4)
	rc.add_child(w[name + "-quests"])
	right.add_child(rc)
	if name == "over":
		_actions(s, [_button("Menu", "", func() -> void: go("menu")), _button("Rejouer", "big", func() -> void: go("play"))])
	else:
		_actions(s, [_button("Abandonner", "", func() -> void: go("menu")), _button("Réglages", "", func() -> void: go("settings")), _button("Reprendre", "big", resume)], 150)

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
		var st: StyleBox = styles["slot-full"] if id != "" else styles["slot"]
		for k in ["normal", "hover", "pressed"]:
			slot.add_theme_stylebox_override(k, st)
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
	w["tg-smooth"].text = {"auto": "Auto", "smooth": "Maximum", "sharp": "Net"}[save["quality"]]
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
		"tg-smooth":                                 # choosing again also forgets what "auto" had settled for
			save["quality"] = SaveData.QUALITIES[(SaveData.QUALITIES.find(save["quality"]) + 1) % SaveData.QUALITIES.size()]
			cap = 3 if _touch() else 4
			watch = {"n": 0, "sum": 0.0, "bad": 0, "before": 0.0, "locked": false}
			DirAccess.remove_absolute(CAP_FILE)
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
	_confirm("Remplacer la partie actuelle par celle-ci ?\n◈ %d · record %d m · %d courses" % [s["coins"], s["best"], s["loops"]], do_import)

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
	var p = _box("pane")
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, 569 / 2.0 - 140, 90, 280, 0)
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
		_style_button(w["tab-" + k], "tab sel" if k == tab else "tab")
		w["tab-" + k].add_theme_font_size_override("font_size", roundi(6.5 * U))
	w["shop-title"].text = (TABS[tab] + (" · %d / %d" % [save["equipped"].size(), SaveData.MAX_EQUIPPED] if tab == "up" else "")).to_upper()
	var list: GridContainer = w["shop-list"]
	for ch in list.get_children():
		ch.queue_free()
	for ch in w["card-actions"].get_children():
		ch.queue_free()
	if tab == "mount":                               # nothing to buy here yet: what each animal does
		for k in Game.MOUNT_KINDS:
			var mk: String = k
			var on_mount = func() -> void:
				picked_mount = mk
				refresh_shop()
			list.add_child(_tile(icon("mount-" + k), Game.MOUNTS[k]["name"], k == picked_mount, DIM, on_mount, 4))
		_card(Game.MOUNTS[picked_mount]["name"], "Rare. Elle attend sur le chemin : touche-la pour monter. Au premier coup, elle s'en va à ta place.", MOUNT_TEXT[picked_mount])
		_show_demo("m-" + picked_mount, 1)
		return
	if tab == "skin":
		var l = _label("Bientôt : la tenue, les cheveux, la cape et les baskets du héros, à changer séparément.", ts("s"), DIM, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = a(250)
		list.add_child(l)
		_card("Skins", "À venir.", "")
		_show_demo("sprint", 1)
		return
	var full: bool = save["equipped"].size() >= SaveData.MAX_EQUIPPED
	var shown: Array = SaveData.UPGRADES.filter(func(u): return u.get("power", false) == (tab == "power"))
	if not shown.any(func(u): return u["id"] == picked):
		picked = shown[0]["id"]
	for u in shown:
		var st = _state_of(u)
		var label = ""
		if not SaveData.unlocked(save, u):
			label = "Niv. %d" % u["unlock"]
		elif st["lvl"] == 0:
			label = "◈ %d" % st["cost"]
		elif u.get("power", false):
			label = "Coupé" if st["off"] else "Actif"
		elif st["on"]:
			label = "Équipé"
		else:
			label = "Niv. %d" % st["lvl"] if u["costs"].size() > 1 else "Possédé"
		var colour = GOLD if st["lvl"] == 0 else (RELIC if st["active"] else DIM)
		var id: String = u["id"]
		var on_pick = func() -> void:
			picked = id
			refresh_shop()
		var t = _tile(icon("ico-" + u["icon"]), label, id == picked, colour, on_pick)
		if st["locked"]:
			t.modulate = Color(0.6, 0.6, 0.6)
		if id == just_bought:
			t.modulate = GOLD
			create_tween().tween_property(t, "modulate", Color.WHITE, 0.5)
		list.add_child(t)
	var u = SaveData.upgrade(picked)
	var st = _state_of(u)
	var pips = "  " + "●".repeat(st["lvl"]) + "○".repeat(u["costs"].size() - st["lvl"]) if u["costs"].size() > 1 else ""
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
	_card(u["name"] + pips, status, u["desc"])
	_show_demo(u["id"], st["lvl"])
	var acts: HBoxContainer = w["card-actions"]
	if st["lvl"] > 0 and st["cost"] >= 0:
		var b = _button("Niv. %d · ◈ %d" % [st["lvl"] + 1, st["cost"]], "small gold", func() -> void: _buy(u))
		b.disabled = save["coins"] < st["cost"]
		acts.add_child(b)
	if st["lvl"] == 0:
		var b = _button("◈ %d" % st["cost"], "small gold", func() -> void: _buy(u))
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

func _state_of(u: Dictionary) -> Dictionary:
	var lvl = SaveData.level(save, u["id"])
	var on: bool = u["id"] in save["equipped"]
	var off: bool = u["id"] in save["powersOff"]
	var locked: bool = (u.has("needs") and SaveData.level(save, u["needs"]) == 0) or not SaveData.unlocked(save, u)
	return {"lvl": lvl, "on": on, "off": off, "cost": SaveData.next_cost(save, u), "locked": locked, "active": on or (u.get("power", false) and lvl > 0 and not off)}

func _tile(tex: Texture2D, text: String, sel: bool, colour: Color, fn: Callable, frames: int = 1) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(a(62), a(62))
	_style_button(b, "tab sel" if sel else "tab")
	var col = _vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var r = TextureRect.new()
	if tex != null and frames > 1:                     # a mount: the first picture of its sheet
		var at = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / float(frames), tex.get_height())
		tex = at
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(a(52), a(34))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(r)
	var l = _label(text, roundi(6.5 * U), colour, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	b.add_child(col)
	var on_tile = func() -> void:
		Audio.sfx("click")
		fn.call()
	b.pressed.connect(on_tile)
	return b

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
	save["coins"] += run.gold
	save["loops"] += 1
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
	if name == "settings" and state == "pause":
		in_run = true
	if name == "play":
		if not save["seenIntro"]:
			save["seenIntro"] = true
			SaveData.store(save)
			state = "intro"
			show_screen("intro")
			Audio.music("")
			return
		run = Game.new_run(SaveData.loadout(save), save["mode"])   # only the three equipped upgrades come along
		run.view_w = render.view_w * Game.PIXEL
		Game.launch(run)                             # rumble, then the doorway blows out
		Debug.debug_run(run)                         # what the debug menu asks for, if anything
		dead_for = 0
		_fill_hud()
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
	if name == "shop":
		refresh_shop()
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

func game_over() -> void:
	var record = not run.debug and floori(run.dist) > best_of(run.mode)
	bank()
	w["over-title"].text = Game.pick(DEATHS)
	hint(0)
	_set_level(w["over-level"], true)
	_quest_cards(w["over-quests"])
	var dist = floori(run.dist)
	var gold = run.gold
	var dur = minf(1.1, 0.25 + dist * 0.012)
	var tw = create_tween()
	var count = func(v: float) -> void:            # counts up on screen, with a tick
		var shown = roundi(v)
		if w["over-dist"].text != "%d m" % shown and shown % 3 == 0:
			Audio.sfx("tick")
		w["over-dist"].text = "%d m" % shown
		w["over-gold"].text = "+%d ◈" % roundi(gold * (v / dist if dist > 0 else 1.0))
	tw.tween_method(count, 0.0, float(dist), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	w["over-best"].text = "Debug : record non enregistré" if run.debug else ("★ Nouveau record ! ★" if record else "Record : %d m" % best_of(run.mode))
	_set_colour(w["over-best"], GOLD if record else DIM)
	w["over-best"].label_settings.font_size = ts("m") if record else ts("s")
	w["over-best"].set_meta("hop", record)
	if record:
		confetti(60)
		Audio.sfx("record")
	Audio.music("over")                              # the run's music winds down, the menu's comes in
	state = "over"
	show_screen("over")

func pause() -> void:
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
	w["pause-gold"].text = "+%d ◈" % run.gold
	w["pause-best"].text = "Debug : record non enregistré" if run.debug else "Record : %d m" % best_of(run.mode)
	_set_level(w["pause-level"], true)
	_quest_cards(w["pause-quests"])

func resume() -> void:
	if state == "pause":
		state = "play"
		show_screen("hud")
		Audio.duck(false)

## Feeds the objectives and the level with what just happened, and announces what it unlocked.
## Experience: one point per metre, plus what each completed objective pays.
func progress(stats: Dictionary) -> void:
	var done = Progress.feed(save, stats)
	var xp: float = stats.get("dist", 0.0)
	for q in done:
		toast("ico-target", "Défi réussi !", q["reward"], q["xp"])
		xp += q["xp"]
	var levels: Array = Progress.add_xp(save, xp) if xp > 0 else []
	for l in levels:
		toast("ico-star", "Niveau %d !" % l, Progress.level_reward(l), 0)
		for u in SaveData.UPGRADES:
			if u["unlock"] == l:
				toast("ico-" + u["icon"], "Débloqué : " + u["name"], 0, 0)   # now for sale in the shop
	if done.size() > 0 or levels.size() > 0:
		Audio.sfx("level" if levels.size() > 0 else "quest")
		SaveData.store(save)

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
	for k in ["dash", "slow"]:
		var act = run.dash if k == "dash" else run.slow
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
	for k in ["btn-pause", "btn-dash", "btn-slow"]:
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
			"btn-dash":
				input.dash = true
				get_viewport().set_input_as_handled()
			"btn-slow":
				input.slow = true
				get_viewport().set_input_as_handled()
	var down = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION)
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
			elif state == "menu" or state == "over" or state == "intro":
				go("play")
			elif state == "pause":
				resume()
		elif k.keycode == KEY_SHIFT or label == KEY_E:
			input.dash = true
		elif label == KEY_A or label == KEY_Q:
			input.slow = true
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
	var dt = minf(0.033, delta)
	_watch(delta * 1000.0)
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
		run.events.clear()
		progress(stats)
		if hint_step == 1 and stats["jumps"] > 0:
			hint(2)
		elif hint_step == 2:
			hint_timer -= dt
			if hint_timer <= 0:
				hint(0)
		hud()
		if state == "play" and run.dead:
			dead_for += dt
			if dead_for > 0.9:
				game_over()
	input.pressed = false
	input.dash = false
	input.slow = false
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
			w["fps"].text = "%d i/s · x%d · %dx%d · %s · %s" % [Engine.get_frames_per_second(), q, game_vp.size.x, game_vp.size.y, save["quality"], perf["text"]]
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
