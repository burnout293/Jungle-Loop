extends SceneTree
# 0.60: the eagle, the heights' guardian (Histoire, alone). Its whole fight is played (the hero untouchable,
# so that it goes on to its end) and every frame the dangers over his column are written down; then every way
# of flying is tried (his height may climb FLAP_LV[1] u/s and drop 900 u/s, as in the fairness bench): a frame
# where no height is reachable untouched would be a spot no one gets through. Then: its phases in order
# (rushes along a line, wings slammed over two lines, the storm's hail, the lightning, the column), the amber
# head won (the Sphère, at once), he stands on the column, and the dungeon comes next.
#   godot --headless --path . -s tests/eagle_060.gd -- --bac   (tests/ has a .gdignore: kept out of the game)

const DT := 1.0 / 60
const TALL := Game.HERO_H

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func fly_check(frames: Array) -> Array:
	var top = Game.GROUND - Game.CEIL - TALL - 10
	var R = [[0.0, top]]
	var bad = []
	for i in frames.size():
		var blocked = []
		for c in frames[i]:
			blocked.append([c[0] - TALL + 6, c[1] - 2])
		blocked.sort_custom(func(a, b): return a[0] < b[0])
		var free = []
		var lo = 0.0
		for b in blocked:
			if b[0] > lo:
				free.append([lo, minf(b[0], top)])
			lo = maxf(lo, b[1])
		if lo < top:
			free.append([lo, top])
		var out = []
		for r in R:
			for fr in free:
				var a = maxf(r[0] - 900.0 * DT, fr[0])
				var b = minf(r[1] + Game.FLAP_LV[1] * DT, fr[1])
				if b >= a:
					out.append([a, b])
		out.sort_custom(func(p, q): return p[0] < q[0])
		var merged = []
		for iv in out:
			if merged.size() > 0 and iv[0] <= merged[-1][1]:
				merged[-1][1] = maxf(merged[-1][1], iv[1])
			else:
				merged.append(iv)
		if merged.is_empty():
			bad.append(i)
			merged = free if not free.is_empty() else [[0.0, top]]
		R = merged
	return bad

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Game.set_talks(FileAccess.get_file_as_string("res://reglages/dialogues.txt"))
	for seed_ in [3, 4, 5]:
		var r = Game.new_run(Game.story_kit(1), "story", seed_)
		r.god = true
		Game.launch(r)
		var inp = Game.Controls.new()
		var k = 0
		while k < 60 * 60 and not (r.exploded and r.out == 2):
			Game.update(r, DT, inp)
			r.events.clear()
			k += 1
		r.biome = Game.SKY
		r.prev_biome = Game.SKY
		r.biome_x = -INF
		r.next_biome_at = INF
		r.boss_at = INF
		r.boss_done = true
		r.guards_off = 0
		r.talk_zones = []
		Game.EAGLE_AT = 0.0                       # (the eagle: now)
		r.sky_dist0 = r.dist
		r.obs = []
		var frames = []
		var seen = {}
		var phases = []
		var landed = false
		var stood_speed = 9999.0
		k = 0
		while k < 60 * 90:
			Game.update(r, DT, inp)
			for e in r.events:
				seen[e] = seen.get(e, 0) + 1
			r.events.clear()
			if r.eagle != null:
				if phases.is_empty() or phases[-1] != r.eagle.phase:
					phases.append(r.eagle.phase)
				if r.eagle.phase == "land":
					landed = absf(r.p.y - (Game.GROUND - Game.PILLAR_TOP)) < 1.0
					stood_speed = minf(stood_speed, r.speed)
			var px = r.cam + r.sx
			var col = []
			for b in Game.hitboxes(r)["boxes"]:
				if b["kind"] != "danger" or b["R"] < px - Game.HERO_HALF or b["L"] > px + Game.HERO_HALF:
					continue
				col.append([Game.GROUND - b["B"], Game.GROUND - b["T"]])
			if r.eagle != null and r.eagle.phase in ["enter", "rush", "wings", "storm"]:
				frames.append(col)
			if r.eagle_done and r.biome == 3:
				break
			k += 1
		var bad = fly_check(frames)
		check(bad.is_empty(), "graine %d : un passage à chaque image du combat (%d images, %d sans passage%s)" % [seed_, frames.size(), bad.size(), (", la 1re : %d %s" % [bad[0], str(frames[bad[0]])]) if not bad.is_empty() else ""])
		check(phases == ["enter", "rush", "wings", "storm", "strike", "crash", "relic", "land"], "graine %d : ses phases dans l'ordre (%s)" % [seed_, str(phases)])
		check(int(seen.get("rush", 0)) >= Game.EAGLE_RUSHES and int(seen.get("slam", 0)) == Game.EAGLE_SLAMS and seen.has("thunder") and seen.has("eaglefall"), "graine %d : %d ruées, %d coups d'ailes, l'éclair, la colonne" % [seed_, int(seen.get("rush", 0)), int(seen.get("slam", 0))])
		check(landed and stood_speed < 5.0, "graine %d : posé sur la colonne, arrêté (%.1f)" % [seed_, stood_speed])
		check(r.lvl("sphere") > 0 and r.won == 1 and seen.has("relic"), "graine %d : la tête d'ambre gagnée, la Sphère aussitôt" % seed_)
		check(r.eagle_done and r.biome == 3, "graine %d : puis le donjon" % seed_)
	print("BILAN aigle : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
