extends SceneTree
# 0.54: the cliff between the forest and the heights (laid ahead, the leap, the fall, the Vol taking him, in
# Histoire the guards after him then on gliders, the crown's Vol given then), the mist that does no harm, the
# missiles' "!" still for its last second, the Couteau suisse to equip, no stone slab on the road any more,
# the heights' figures.
#   godot --headless --path . -s tests/cliff_054.gd   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func step(r: Game.Run, inp, n: int, seen: Dictionary) -> void:
	for k in n:
		Game.update(r, 1.0 / 60, inp)
		for e in r.events:
			seen[e] = seen.get(e, 0) + 1
		r.events.clear()

## A run out of the temple, in the forest, the heights coming next.
func ready_run(up: Dictionary, mode: String, seed_: int) -> Game.Run:
	var r = Game.new_run(up, mode, seed_)
	r.god = true
	Game.launch(r)
	var inp = Game.Controls.new()
	var k = 0
	while k < 60 * 60 and not (r.exploded and r.out == 2):   # (Histoire: the temple's talk first)
		step(r, inp, 1, {})
		k += 1
	step(r, inp, 60 * 3, {})
	r.biome = 0
	r.prev_biome = 0
	r.boss_at = INF
	r.next_biome_at = r.dist                         # the change of scenery: now
	return r

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))
	var inp = Game.Controls.new()

	# --- the Run illimitée with the Vol: the cliff, the leap, the fall, the Vol ---
	var r = ready_run({"flight": 1}, "endless", 7)
	var seen = {}
	var laid_at = -1.0
	for k in 60 * 6:                                 # laid at the next pattern, off the screen
		step(r, inp, 1, seen)
		if r.cliff_x > 0:
			laid_at = r.cam + r.view_w
			break
	check(r.cliff_x > 0 and r.biome == Game.SKY and r.biome_x == r.cliff_x, "la falaise posée devant, les pitons commencent à son bord")
	check(r.cliff_x > laid_at, "posée hors de l'écran (%.0f > %.0f)" % [r.cliff_x, laid_at])
	check(absf(Game.floor_at(r, r.cliff_x - 10) - (Game.GROUND - Game.CLIFF_H)) < 1, "le sol monte jusqu'en haut de la falaise")
	check(absf(Game.floor_at(r, r.cliff_x + Game.CLIFF_LIP + 20) - Game.GROUND) < 1, "et tombe jusqu'à la brume après son bord")
	var on_top = false
	var fell = 0.0
	var top_y = INF
	var t = 0.0
	r.p.cruise = 0
	while t < 12.0 and not seen.has("soar"):
		step(r, inp, 1, seen)
		t += 1.0 / 60
		var px = r.cam + r.sx
		if px > r.cliff_x - 200 and px < r.cliff_x - 20 and r.p.ground:
			on_top = true
		if r.soar > 0:
			top_y = minf(top_y, r.p.y)               # (from the top of his leap)
			fell = maxf(fell, r.p.y - top_y)
	check(on_top, "il court en haut de la falaise")
	check(seen.has("leap") and seen.has("soar"), "il saute dans le vide, puis le Vol le prend (%s)" % str(seen.keys()))
	check(fell > 60, "il tombe vraiment avant de voler (%.0f)" % fell)
	step(r, inp, 90, seen)
	check(r.p.y < Game.GROUND - 80 and not r.p.ground and r.sky, "il vole, au-dessus de la brume (%.0f)" % r.p.y)
	check(not seen.has("mist"), "il ne touche pas la brume en tombant")

	# --- the Run illimitée without the Vol: never the cliff ---
	var w = ready_run({}, "endless", 7)
	step(w, inp, 60 * 3, {})
	check(w.cliff_x < 0 and w.biome != Game.SKY, "sans le Vol : ni falaise ni pitons")

	# --- Histoire, alone: the guards after him, they talk, the cliff, the Vol given, the gliders ---
	Game.STORY_TRY = 1
	Game.STORY_CHAP = 0
	var s = ready_run({}, "story", 9)
	s.won = 0                                        # (Vorace beaten: her crown is his, its Vol not yet)
	s.guards_off = s.t
	seen = {}
	step(s, inp, 2, seen)
	check(s.cliff_due and s.cliff_x < 0, "Histoire : la falaise attend que les gardes aient parlé")
	check(s.guards.size() == 2 and s.guards.all(func(g): return g.on and not g.get("glide", false)) and s.guards_off < 0, "les gardes reprennent la poursuite")
	check(s.lvl("flight") == 0, "pas encore de Vol avant la falaise")
	t = 0.0
	var said = []
	var glided = false
	var gone = false
	while t < 40.0:
		Game.update(s, 1.0 / 60, inp)
		for e in s.events:
			seen[e] = seen.get(e, 0) + 1
			if e == "say":
				said.append(s.saying)
		s.events.clear()
		t += 1.0 / 60
		if s.guards.any(func(g): return g.get("glide", false) and not g.get("gone", false)):
			glided = true
		if glided and s.guards.all(func(g): return g.get("gone", false)):
			gone = true
			break
	check(said.size() >= 6 and "falaise" in " ".join(said), "leurs répliques : la falaise, puis l'envol (%d)" % said.size())
	check(seen.has("leap") and seen.has("soar"), "Histoire : le saut, puis le Vol")
	check(s.lvl("flight") >= 1 and s.up.get("flight", 0) >= 1, "la couronne donne le Vol pendant la chute")
	check(glided, "les gardes le suivent en deltaplane")
	check(gone, "puis ils restent derrière")

	# --- for two: the cliff where the scenery changes, on both phones the same ---
	var both = []
	for guest in [false, true]:                      # (each phone its own: the road's dice are the run's, one at a time)
		var cr = Game.coop_run({"flight": 1}, 21, 2, guest)
		both.append(cr)
		cr.sky_ok = true
		cr.biome = 0
		cr.prev_biome = 0
		cr.coop_biome_x = 6000.0
		while cr.next_x < 12000.0:
			Game.spawn_pattern(cr)
	var c1 = both[0]
	var c2 = both[1]
	check(c1.cliff_x > 0 and c1.cliff_x == c2.cliff_x and c1.biome == Game.SKY, "à deux : la même falaise sur les deux téléphones (%.0f, %.0f)" % [c1.cliff_x, c2.cliff_x])

	# --- the missiles: the "!" still for its last second ---
	var m = Game.new_run({}, "endless", 3)
	m.god = true
	Game.launch(m)
	step(m, inp, 60 * 4, {})
	m.obs.clear()
	var o = Game.add_dart(m, m.cam + m.view_w + 20, 46.0)
	o.aim = true                                     # (0.55: only an aimed one follows his height)
	var ys = []
	var k = 0
	while o.state != "go" and k < 600:
		if o.state == "warn" and o.t > Game.DART_WARN - Game.DART_FREEZE + 0.02:
			m.p.y = Game.GROUND - 300 + 200 * sin(k * 0.2)   # he moves up and down: it does not follow
			m.p.ground = false
			ys.append(o.y)
		Game.update(m, 1.0 / 60, inp)
		m.events.clear()
		k += 1
	check(ys.size() > 30 and ys.max() - ys.min() < 0.5, "le « ! » figé sa dernière seconde (%d images, écart %.1f)" % [ys.size(), (ys.max() - ys.min()) if ys.size() > 0 else -1.0])

	# --- the Couteau suisse to equip ---
	check(SaveData.upgrade("swiss").get("costs", []).size() == 3, "le Couteau suisse : trois niveaux")
	for lv in [[0, 0], [1, 1], [2, 1], [3, 2]]:
		var kr = Game.new_run({"swiss": lv[0]} if lv[0] > 0 else {}, "endless", 1)
		check(kr.free_knives == lv[1], "niveau %d : %d évasion(s) offerte(s)" % lv)
	check(Game.new_run({"swiss": 3}, "story", 1).free_knives == 0, "jamais en Histoire")
	var widths = []
	for lv in [1, 2]:
		var kr = Game.new_run({"swiss": lv}, "endless", 1)
		kr.caught = {"t": 3.0, "x": 0.0, "sx0": 0.0, "gx": [], "gx0": [], "phase": "offer", "timer": 1.0, "gone_t": 0.0, "esc": {}}
		kr.knives = 3
		check(Game.escape_start(kr) and kr.free_knives == 0 and kr.knives == 3, "niveau %d : l'évasion équipée d'abord, le stock gardé" % lv)
		widths.append([kr.caught.esc.w, absf(kr.caught.esc.cv)])
	check(widths[1][0] > widths[0][0] * 1.3 and widths[1][1] < widths[0][1], "niveau 2 : plus facile (zone %.2f → %.2f)" % [widths[0][0], widths[1][0]])

	# --- no stone slab any more; the heights' figures ---
	var f = Game.new_run({"flight": 1}, "endless", 4)
	f.next_x = 4000.0
	f.calm_until = 0
	f.easy_until = 0
	while f.next_x < 120000.0:
		f.cam = f.next_x - 900
		Game.spawn_pattern(f)
	check(not f.plats.any(func(pl): return pl.kind == "slab" or pl.t > 0), "plus de ponton en pierre (on ne peut pas sauter dessous)")
	var h = Game.new_run({"flight": 1}, "endless", 4)
	h.biome = Game.SKY
	h.prev_biome = Game.SKY
	h.biome_x = 0
	h.next_x = 2000.0
	h.calm_until = 0
	h.easy_until = 0
	while h.next_x < 60000.0:
		h.cam = h.next_x - 900
		Game.spawn_pattern(h)
	var pins = h.obs.filter(func(q): return q.kind == "pinnacle")
	pins.sort_custom(func(a, b): return a.x < b.x)
	var close = 0
	var same = 0
	for i in range(1, pins.size()):
		var dx = pins[i].x - pins[i - 1].x
		if dx < Game.PIN_GAP - 1:
			close += 1
		# (two in one row: the same step as the pair before them, or the first two of a row of three)
		var row = i >= 2 and absf(dx - (pins[i - 1].x - pins[i - 2].x)) < 1
		if row and absf(pins[i].y - pins[i - 1].y) < 1:
			same += 1
	check(pins.size() > 20 and close == 0, "les pitons d'une rangée jamais trop près (%d pitons, %d trop près)" % [pins.size(), close])
	check(same == 0, "dans une rangée, chaque piton change de hauteur (%d pareils)" % same)
	check(not h.obs.any(func(q): return q.kind == "spiky" or q.kind == "acid"), "rien au sol dans les pitons")
	print("BILAN falaise : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
