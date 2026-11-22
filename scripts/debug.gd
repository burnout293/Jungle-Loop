class_name Debug
extends RefCounted
## The debug menu (port of js/debug.js): opened by touching the level badge of the home screen five times
## in a row. Plain on purpose. It changes the save (coins, level, purchases), what the next runs start with,
## and a few of the game's numbers; its own settings are kept on this device (user://jungle-loop-debug.json).
## As soon as anything here differs from the game's own state, the game is "in debug": a thin red strip
## along the top of the screen says so, above everything, and no record is kept. Whatever was tuned is
## shown in red; « Stopper le débogage » puts every field back.

const PATH := "user://jungle-loop-debug.json"
const SETTINGS := ["info", "hitbox", "god", "start", "biome", "mount", "fm"]
const RED := Color("#ff5a6a")
const PALE := Color("#e8ecf4")

static var ORIGIN := {}           # the game's own numbers, before anything here changes them
static var BLANK := {}
static var dbg := {}
static var tuned := {}            # the game numbers changed by hand (only those are kept and applied)
static var marks: Array = []      # [label, test]: the rows to show in red while tuned
static var strip: Control = null  # the red strip, made by main.gd
static var on_change := Callable()
static var say: Label = null
static var host = null            # main.gd

static func setup() -> void:
	ORIGIN = {"base": Game.SPEED_BASE, "gain": Game.SPEED_GAIN, "sprint": Game.SPEED_SPRINT, "boss": Game.BOSS_AT, "from_low": Game.FROM_LOW, "from_mid": Game.FROM_MID}
	BLANK = {"info": false, "hitbox": false, "god": false, "start": 0.0, "biome": 0, "mount": "", "fm": false, "edits": []}
	BLANK.merge(ORIGIN)
	dbg = BLANK.duplicate(true)
	if FileAccess.file_exists(PATH) and Lock.unlocked():   # (a locked device keeps no debug settings, even edited by hand)
		var kept = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if kept is Dictionary:
			if kept.get("changed") is Array:
				for k in kept["changed"]:
					if ORIGIN.has(k):
						tuned[k] = true
			for k in kept:
				if not BLANK.has(k) or (ORIGIN.has(k) and not tuned.has(k)):
					continue
				var v = kept[k]
				var want = BLANK[k]
				if want is bool and v is bool:
					dbg[k] = v
				elif (want is int or want is float) and (v is int or v is float):
					dbg[k] = int(v) if want is int else float(v)
				elif want is String and v is String:
					dbg[k] = v
				elif want is Array and v is Array:
					dbg[k] = v.duplicate()
	apply(false)

## Is a field away from the game's own value?
static func differs(k: String) -> bool:
	return tuned.has(k) if ORIGIN.has(k) else dbg[k] != BLANK[k]

static func debug_on() -> bool:
	return dbg["edits"].size() > 0 or tuned.size() > 0 or SETTINGS.any(func(k): return differs(k))

static func apply(store: bool = true) -> void:
	Game.SPEED_BASE = dbg["base"]
	Game.SPEED_GAIN = dbg["gain"]
	Game.SPEED_SPRINT = dbg["sprint"]
	Game.BOSS_AT = dbg["boss"]
	Game.FROM_LOW = dbg["from_low"]
	Game.FROM_MID = dbg["from_mid"]
	if store:
		var out = dbg.duplicate(true)
		out["changed"] = tuned.keys()
		var f = FileAccess.open(PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out))
	if strip != null:
		strip.visible = debug_on()
	for m in marks:
		if is_instance_valid(m[0]):
			m[0].add_theme_color_override("font_color", RED if m[1].call() else PALE)
	if on_change.is_valid():
		on_change.call()

## What the next run starts with: called by main.gd right after the run is made.
static func debug_run(run: Game.Run) -> void:
	run.god = dbg["god"]
	run.debug = debug_on()                           # no record for this run
	if dbg["biome"] > 0:
		run.biome = dbg["biome"]
		run.prev_biome = dbg["biome"]
	if tuned.has("boss") and run.mode != "endless":
		run.boss_at = Game.BOSS_AT                   # a boss set by hand comes exactly there (never in the Run illimitée)
	if dbg["start"] > 0:                             # as if the first metres had already been run
		var D = dbg["start"] * Game.PPM
		var g = Game.SPEED_GAIN
		run.t = (-run.base + sqrt(run.base * run.base + 2 * g * D)) / g if g > 0 else D / run.base
		run.pace_t = run.t                         # (0.49: the speed's own clock)
		run.cam = D
		run.dist = dbg["start"]
		run.next_x = D + 1500
		run.terrain = [Vector2(-1e9, Game.GROUND)]
		run.next_mount += dbg["start"]
		run.next_fm += dbg["start"]
	if dbg["mount"] != "":
		var it = Game.Item.new()
		it.x = run.cam + Game.PX + 700
		it.kind = dbg["mount"]
		it.y = Game.GROUND - Game.ZIG_LOW
		run.items.append(it)
	if dbg["fm"]:
		run.next_fm = run.dist + 40

## Every field back to the game's own: the strip goes, records count again. (What was done to the save,
## coins or purchases, stays: it is the save.)
static func stop() -> void:
	dbg = BLANK.duplicate(true)
	tuned.clear()
	apply()

# ---------- the panel ----------

static func _label(text: String, size: int = 22, colour: Color = PALE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

static func _row(box: VBoxContainer, label: String, test, parts: Array) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l = _label(label)
	l.custom_minimum_size.x = 300
	row.add_child(l)
	for p in parts:
		if p is Label:                               # a note: it wraps in what is left of the line
			p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.custom_minimum_size.x = 300
		row.add_child(p)
	box.add_child(row)
	if test != null:
		marks.append([l, test])
		l.add_theme_color_override("font_color", RED if test.call() else PALE)

static func _button(text: String, fn: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(fn)
	return b

static func _number(value: float, step: float, fn: Callable) -> SpinBox:
	var s = SpinBox.new()
	s.min_value = 0
	s.max_value = 100000
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 160
	s.value_changed.connect(fn)
	return s

## A yes/no field: a button that says which.
static func _check(key: String, after: Callable = Callable()) -> Button:
	var c = Button.new()
	c.toggle_mode = true
	c.button_pressed = dbg[key]
	c.text = "Oui" if dbg[key] else "Non"
	c.custom_minimum_size.x = 90
	c.add_theme_font_size_override("font_size", 22)
	var on_toggle = func(v: bool) -> void:
		dbg[key] = v
		c.text = "Oui" if v else "Non"
		apply()
		if after.is_valid():
			after.call()
	c.toggled.connect(on_toggle)
	return c

static func _pick(key: String, options: Array) -> OptionButton:
	var o = OptionButton.new()
	o.add_theme_font_size_override("font_size", 22)
	for i in options.size():
		o.add_item(options[i][1], i)
		if options[i][0] == dbg[key]:
			o.select(i)
	var on_pick = func(i: int) -> void:
		dbg[key] = options[i][0]
		apply()
	o.item_selected.connect(on_pick)
	return o

## A number of the game: typed in the unit shown, kept in the game's own (`k` units per shown unit).
static func _tune(box: VBoxContainer, label: String, key: String, unit: String, k: float = 1.0, step: float = 1.0) -> void:
	var on_value = func(v: float) -> void:
		dbg[key] = v * k
		if ORIGIN.has(key):
			tuned[key] = true
		apply()
	var s = _number(snappedf(dbg[key] / k, 0.001), step, on_value)
	var note = unit + (" (origine %s)" % str(snappedf(ORIGIN[key] / k, 0.001)) if ORIGIN.has(key) else "")
	_row(box, label, func() -> bool: return differs(key), [s, _label(note, 18, Color("#9fb0c4"))])

static func _head(box: VBoxContainer, text: String) -> void:
	box.add_child(_label(text, 24, Color("#5cf2e0")))

## A change made to the save: kept, said, and remembered as a debug change.
static func _done(what: String, text: String) -> void:
	if not what in dbg["edits"]:
		dbg["edits"] = dbg["edits"] + [what]
	SaveData.store(host.save)
	apply()
	say.text = text

static func panel(main) -> Control:
	host = main
	marks = []
	var root = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(6 / 255.0, 8 / 255.0, 16 / 255.0, 0.95)
	sb.set_content_margin_all(24)
	sb.content_margin_top = 36
	root.add_theme_stylebox_override("panel", sb)
	root.size = Vector2(1280, 720)
	var th = Theme.new()
	th.default_font = ThemeDB.fallback_font
	th.default_font_size = 22
	root.theme = th
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_button("Fermer", func() -> void: main.close_debug()))
	var on_stop = func() -> void:
		stop()
		main.open_debug()
		say.text = "Débogage arrêté : tous les champs sont revenus à l'origine."
	head.add_child(_button("Stopper le débogage", on_stop))
	if not OS.is_debug_build():                      # (the lock, lock.gd: this device asks for the password again)
		var on_lock = func() -> void:
			Lock.forget()
			main.close_debug()
		head.add_child(_button("Verrouiller cet appareil", on_lock))
	var title = _label("Debug", 26, Color("#ffd35c"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(title)
	box.add_child(head)
	say = _label("", 22, Color("#7bd13c"))
	box.add_child(say)

	_head(box, "Partie")
	var s: Dictionary = main.save
	var coins = _number(s["coins"], 1, func(_v: float) -> void: pass)
	var apply_coins = func() -> void:
		s["coins"] = int(coins.value)
		_done("coins", "Pièces changées.")
	_row(box, "Pièces", func() -> bool: return "coins" in dbg["edits"], [coins, _button("Appliquer", apply_coins)])
	var level = _number(Progress.level_info(s["xp"])["level"], 1, func(_v: float) -> void: pass)
	var apply_level = func() -> void:
		var want = maxi(1, int(level.value))
		var xp = 0.0
		while Progress.level_info(xp)["level"] < want:
			var i = Progress.level_info(xp)
			xp += i["need"] - i["into"]
		s["xp"] = xp
		_done("level", "Niveau %d." % want)
	_row(box, "Niveau", func() -> bool: return "level" in dbg["edits"], [level, _button("Appliquer", apply_level)])
	var all_in = func() -> void:
		for u in SaveData.UPGRADES:
			s["upgrades"][u["id"]] = u["costs"].size()
		_done("buys", "Tout est acheté, au niveau maximum.")
	var none = func() -> void:
		s["upgrades"] = {}
		s["equipped"] = []
		s["powersOff"] = []
		_done("buys", "Plus aucun achat.")
	_row(box, "Achats", func() -> bool: return "buys" in dbg["edits"], [_button("Tout débloquer", all_in), _button("Tout remettre à zéro", none)])
	var quests = func() -> void:
		s["quests"] = []
		Progress.fill(s)
		_done("quests", "Trois nouveaux défis.")
	_row(box, "Défis", func() -> bool: return "quests" in dbg["edits"], [_button("Nouveaux défis", quests)])

	_head(box, "Affichage")
	_row(box, "Mesures en jeu", func() -> bool: return differs("info"), [_check("info"), _label("vitesse, vitesse propre, distance, hauteur, hauteur max", 18, Color("#9fb0c4"))])
	_row(box, "Hitbox", func() -> bool: return differs("hitbox"), [_check("hitbox"), _label("rouge : Pépito ; orange : dangers (pâle : pas encore) ; bleu : inoffensifs ; jaune : pièces ; vert : plateformes ; cyan : sol", 18, Color("#9fb0c4"))])
	box.add_child(_label("Les images par seconde sont dans les Réglages (Affichage).", 18, Color("#9fb0c4")))

	_head(box, "Calculs")
	var out = _label("", 18, Color("#9fb0c4"))
	var show = func(v: float) -> void:
		var D = v * Game.PPM
		var g = Game.SPEED_GAIN
		var line = func(b: float) -> String:
			var t = (-b + sqrt(b * b + 2 * g * D)) / g if g > 0 else D / b
			return "%.1f m/s après %d min %d s" % [(b + g * t) / Game.PPM, floori(t / 60), roundi(fmod(t, 60))]
		out.text = "à pied : %s · avec Sprint : %s" % [line.call(Game.SPEED_BASE), line.call(Game.SPEED_BASE + Game.SPEED_SPRINT)]
	_row(box, "Vitesse à (m)", null, [_number(1000, 100, show), out])
	show.call(1000.0)
	var h = func(v: float, gr: float) -> float: return v * v / (2 * gr) / Game.PPM
	box.add_child(_label("Hauteurs de saut", 22))
	for lvl in 3:
		var kk = 1 + 0.1 * lvl
		var v = Game.JUMP_V * kk
		var dd = Game.JUMP_DOUBLE * kk
		box.add_child(_label("%s : bref %.2f m, maintenu %.2f m, avec double saut jusqu'à %.2f m" % ["Ressort %d" % lvl if lvl > 0 else "Sans Ressort", h.call(v, Game.JUMP_GRAVITY), h.call(v, Game.JUMP_HELD), h.call(v, Game.JUMP_HELD) + h.call(dd, Game.JUMP_HELD)], 18, Color("#9fb0c4")))

	_head(box, "Prochaines courses")
	_row(box, "Invincible", func() -> bool: return differs("god"), [_check("god")])
	_tune(box, "Départ à", "start", "m")
	var biomes = []
	for i in Art.BIOMES.size():
		biomes.append([i, Art.BIOMES[i]["name"]])
	_row(box, "Décor de départ", func() -> bool: return differs("biome"), [_pick("biome", biomes)])
	var mounts = [["", "Aucune"]]
	for k in Game.MOUNT_KINDS:
		mounts.append([k, Game.MOUNTS[k]["name"]])
	_row(box, "Monture au départ", func() -> bool: return differs("mount"), [_pick("mount", mounts)])
	_row(box, "Moustiques dès le départ", func() -> bool: return differs("fm"), [_check("fm")])

	_head(box, "Valeurs du jeu")
	_tune(box, "Vitesse de départ", "base", "m/s", Game.PPM, 0.5)
	_tune(box, "Accélération", "gain", "m/s par seconde", Game.PPM, 0.025)
	_tune(box, "Bonus du Sprint", "sprint", "m/s", Game.PPM, 0.5)
	_tune(box, "Suspendus bas dès", "from_low", "m")
	_tune(box, "Suspendus hauts dès", "from_mid", "m")
	_tune(box, "Boss à", "boss", "m")
	var origin = func() -> void:
		dbg.merge(ORIGIN, true)
		tuned.clear()
		apply()
		main.open_debug()
		say.text = "Valeurs d'origine remises."
	_row(box, "", null, [_button("Valeurs d'origine", origin)])
	return root
