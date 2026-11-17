extends Node
## Glue: screens, input, HUD and the frame loop (port of js/main.js, index.html and style.css).
## The screen is 1280 x 720 units, shown in 16:9 with bars around it (project settings); one art
## pixel is U units, and the interface is measured in art pixels like the web version's (--ui).

const VERSION := "0.27.0"
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

# ---------- start ----------

func _ready() -> void:
	save = SaveData.load_save()
	Audio.set_volumes(save["musicVol"], save["sfxVol"])
	render = Render.new()
	add_child(render)
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
	if "--test" in OS.get_cmdline_user_args():      # the bench: a bot plays (see bench.gd)
		var bench = load("res://scripts/bench.gd").new()
		bench.main = self
		add_child(bench)
	_load.call_deferred()

func _load() -> void:
	await get_tree().process_frame                # the "loading" text is on screen first
	Art.load_all()
	Art.set_danger_rim(save["dangerRim"])
	render.shift = save["alertShift"]
	Game.set_shapes(FileAccess.get_file_as_string("res://assets/patterns.txt"))
	for n in ["ui-btn-slate-38", "ui-btn-slate-30", "ui-btn-green-50", "ui-btn-gold-38", "ui-btn-gold-30", "ui-gear", "ui-title", "coin-icon", "heart"]:
		icons[n] = _tex(n)
	_styles()
	_build()
	w["loading"].queue_free()
	go("menu")

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
	var th = Theme.new()
	th.default_font = font
	th.default_font_size = ts("m")
	ui.theme = th

## Text sizes, in units: small, middle, large, extra large (style.css --t-s ... --t-xl).
func ts(k: String) -> int:
	return roundi({"s": 11, "m": 14, "l": 19, "xl": 26, "huge": 52}[k] * fk * U)

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

func _styles() -> void:
	for spec in [["", "ui-btn-slate-38", 38, 41], ["big", "ui-btn-green-50", 50, 54], ["small", "ui-btn-slate-30", 30, 33], ["gold", "ui-btn-gold-38", 38, 41], ["small gold", "ui-btn-gold-30", 30, 33]]:
		var inset = 0.6 if spec[2] == 50 else 0.85
		styles[spec[0]] = {
			"normal": _plaque(spec[1], spec[2], spec[3], Color.WHITE, inset),
			"hover": _plaque(spec[1], spec[2], spec[3], Color(1.12, 1.12, 1.12), inset),
			"pressed": _plaque(spec[1], spec[2], spec[3], Color(0.9, 0.9, 0.9), inset),
			"disabled": _plaque(spec[1], spec[2], spec[3], Color(0.55, 0.55, 0.6), inset),
			"h": spec[2],
		}
	styles["box"] = _flat(BOX)
	styles["box-sel"] = _flat(Color("#2c3558"), GOLD)
	styles["pane"] = _flat(Color(24 / 255.0, 30 / 255.0, 54 / 255.0, 0.96))
	styles["pane"].set_content_margin_all(a(9))
	styles["slot"] = _flat(Color(16 / 255.0, 20 / 255.0, 40 / 255.0, 0.5), Color(1, 248 / 255.0, 230 / 255.0, 0.4))
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
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, styles["box-sel"] if sel else styles["box"])
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
		bg.color = Color(8 / 255.0, 10 / 255.0, 24 / 255.0, 0.6)
		bg.size = Vector2(W, H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	w["fps"] = _label("", roundi(8 * U), Color.WHITE, 0)
	w["fps"].z_index = 10
	_place(w["fps"], 4, 320 - 4 - 12, 300, 12)
	ui.add_child(w["fps"])
	_build_hud()
	_build_menu()
	_build_intro()
	_build_shop()
	_build_settings()
	_build_score("over")
	_build_score("pause")

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
	var pause_b = _button("II", "square", pause)
	pause_b.custom_minimum_size = Vector2(a(36), a(36))
	top.add_child(pause_b)
	s.add_child(top)
	w["toasts"] = _vbox(4)
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
	s.add_child(w["banner"])
	w["hint"] = _label("", ts("l"))
	w["hint"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(w["hint"], 0, 320 * 0.76 - 20, 569, 24)
	w["hint"].pivot_offset = Vector2(W / 2, a(12))
	w["hint"].visible = false
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
	var prev = _box("pane")
	_place(prev, 569 - M - 227, 30, 227, 282)
	var pc = _vbox(6)
	w["demo-icon"] = TextureRect.new()
	w["demo-icon"].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w["demo-icon"].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w["demo-icon"].custom_minimum_size = Vector2(a(210), a(120))
	pc.add_child(w["demo-icon"])
	w["demo-desc"] = _label("", ts("s"), DIM, 0)
	w["demo-desc"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w["demo-desc"].custom_minimum_size.x = a(210)
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
	grid.add_child(_button("Importer", "small", func() -> void: _import(w["save-code"].text)))
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

func show_screen(name: String) -> void:
	for k in screens:
		screens[k].visible = k == name

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
		w["menu-loadout"].add_child(slot)

func _slot_info(id: String) -> void:
	var box: PanelContainer = w["menu-info"]
	if box.visible and box.get_meta("id", "") == id:
		box.visible = false
		return
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
	w["set-left"].position.x = a(153.5) if in_run else a(14)

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
		"tg-smooth":
			save["quality"] = SaveData.QUALITIES[(SaveData.QUALITIES.find(save["quality"]) + 1) % SaveData.QUALITIES.size()]
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

func _is_full() -> bool:
	var m = DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _apply_fullscreen() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
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

func _confirm(text: String, fn: Callable) -> void:
	var d = ConfirmationDialog.new()
	d.dialog_text = text
	d.ok_button_text = "Oui"
	d.cancel_button_text = "Non"
	d.confirmed.connect(fn)
	var on_hidden = func() -> void:
		if not d.visible:
			d.queue_free()
	d.visibility_changed.connect(on_hidden)
	add_child(d)
	d.popup_centered()

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
		_card(Game.MOUNTS[picked_mount]["name"], "Rare. Elle attend sur le chemin : touche-la pour monter. Au premier coup, elle s'en va à ta place.", MOUNT_TEXT[picked_mount], icon("mount-" + picked_mount))
		return
	if tab == "skin":
		var l = _label("Bientôt : la tenue, les cheveux, la cape et les baskets du héros, à changer séparément.", ts("s"), DIM, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = a(250)
		list.add_child(l)
		_card("Skins", "À venir.", "", null)
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
	_card(u["name"] + pips, status, u["desc"], icon("ico-" + u["icon"]))
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

func _card(name: String, status: String, desc: String, tex: Texture2D) -> void:
	w["card-name"].text = name
	w["card-status"].text = status
	w["demo-desc"].text = desc
	w["demo-icon"].texture = tex

func _buy(u: Dictionary) -> void:
	var ok = SaveData.buy(save, u)
	Audio.sfx("buy" if ok else "no")
	if ok:
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
	if run.mode == "endless":
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
		dead_for = 0
		hud_state = {"dist": -1, "gold": -1, "hearts": -1}
		var hearts: HBoxContainer = w["hud-hearts"]
		for ch in hearts.get_children():
			ch.queue_free()
		for i in run.hearts:
			hearts.add_child(_icon_rect(icon("heart"), 20))
		hearts.visible = run.max_hearts > 1          # a single life needs no counter
		last_dist = 0
		for ch in w["toasts"].get_children():
			ch.queue_free()
		state = "play"
		show_screen("hud")
		Progress.start_run(save)
		progress({"runs": 1})
		hint(1 if save["loops"] < 2 else 0)          # the first escapes explain the one control
		w["btn-dash"].visible = run.lvl("dash") > 0
		w["btn-slow"].visible = run.lvl("slow") > 0
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
	show_screen(name)

func game_over() -> void:
	var record = floori(run.dist) > best_of(run.mode)
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
	w["over-best"].text = "★ Nouveau record ! ★" if record else "Record : %d m" % best_of(run.mode)
	_set_colour(w["over-best"], GOLD if record else DIM)
	if record:
		Audio.sfx("record")
	Audio.music("over")                              # the run's music winds down, the menu's comes in
	state = "over"
	show_screen("over")

func pause() -> void:
	if state != "play" or run == null or run.dead:
		return
	w["pause-dist"].text = "%d m" % floori(run.dist)
	w["pause-gold"].text = "+%d ◈" % run.gold
	w["pause-best"].text = "Record : %d m" % best_of(run.mode)
	_set_level(w["pause-level"], true)
	_quest_cards(w["pause-quests"])
	state = "pause"
	show_screen("pause")
	Audio.duck(true)                                 # the music goes on, quieter

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
	var tw = create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.27)
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
			h.modulate = Color(0.5, 0.5, 0.5, 0.5) if i >= run.hearts else Color.WHITE
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

## While playing, a touch anywhere on the frame is a jump (the HUD's buttons keep their own job).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
	time += delta
	if state == "loading":
		return
	if state == "play" or state == "over":
		run.view_w = render.view_w * Game.PIXEL
		Game.update(run, dt, input)
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
		w["fps"].visible = save["showFps"]
		if save["showFps"] and Engine.get_process_frames() % 15 == 0:
			w["fps"].text = "%d i/s · x%d" % [Engine.get_frames_per_second(), render.q]
	# Behind the menus: the temple, frozen. The hero only appears once the run starts.
	var shown: Game.Run = run if (state == "play" or state == "pause" or state == "over" or in_run) and run != null else still
	var win = get_window().size
	render.show_run(shown, time, minf(win.x / W, win.y / H))
