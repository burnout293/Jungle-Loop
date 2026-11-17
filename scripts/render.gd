class_name Render
extends Node2D
## Everything drawn during a run (and the frozen temple behind the menus), from the pictures made by
## Art (the drawing half of js/render.js). Every coordinate here is in art pixels: logical units from
## game.gd divided by PIXEL. The node is scaled so that the 320 art pixels of the play area fill the
## 720 of the screen; positions are kept to 1/q of an art pixel, as the web version's canvas did.
##
## Four layers, drawn in this order: the world behind the hero, the hero (smoothed, his pieces are
## drawn four times finer), what passes in front of him, and the full-screen tints (never shaken).

const PIXEL := Game.PIXEL
const VH := 320.0                      # play area height, in art pixels
const GN := 280.0                      # floor line where the path is at its starting level
const TEMPLE_X := -64.0                # temple's left edge, at camera 0
const DOOR_X := 29.0                   # and its doorway
const PROP_CELL := Game.PROP_CELL / Game.PIXEL
const EARTH := 24.0
const SLICE := 4
const TILE := 16.0
const SPREAD := 120.0
const LOG_CUT := 12
const LOG_ROOF := 30.0
const LOG_FLOOR := 68.0 - 12.0
const LOG_WINDOW := 54.0
const LOG_RIB := 20.0
const VINE_CELL := 110.0
const VORACE_SINK := 4.0
const HI_K := 4.0
const SMASH := [-1, 1, 3, 1]           # in each scenery, the prop that is now the one to smash (never mere scenery)
const SWAYING := [Game.PROP_FERN, Game.PROP_FLOWER]
const INK := Color("#1a1024")
const RED := Color("#ff3b4e")
# Each role of danger looks different in each scenery (jungle, ruins, city, dungeon).
const ROLE := {
	"spiky": ["spiky", "thornball", "spikebot", "beartrap"],
	"dart": ["fly", "vulture", "missile", "arrow"],
	"hover": ["spider", "idol", "drone", "bat"],
	"swarm": ["mosquito", "wasp", "drone-big", "wisp"],
}
const DIGITS := {1: "010110010010111", 2: "111001111100111", 3: "111001111001111"}

class Layer extends Node2D:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

var run: Game.Run = null
var view_w := 569.0
var t := 0.0
var q := 4.0                           # drawing steps per art pixel
var shift := false                     # « Signalements décalés »: the fonceurs' warnings stand further in
var seat = null                        # where the hero sits on his mount this frame
var dirt: Array = []
var dirt_t := 0.0
var back: Layer
var hero_layer: Layer
var front: Layer
var over: Layer

func _ready() -> void:
	scale = Vector2(PIXEL, PIXEL)
	back = _layer(_draw_back, false)
	hero_layer = _layer(_draw_hero_layer, true)
	front = _layer(_draw_front, false)
	over = _layer(_draw_over, false)

func _layer(fn: Callable, smooth: bool) -> Layer:
	var l = Layer.new()
	l.paint = fn
	if smooth:
		l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(l)
	return l

## Called every frame with what to show.
func show_run(r: Game.Run, time: float, screen_scale: float) -> void:
	run = r
	t = time
	q = clampf(ceilf(PIXEL * screen_scale - 0.01), 1, 4)
	Ambient.q = q
	var off = Vector2.ZERO
	if r.shake > 0:
		off = Vector2(roundf((randf() - 0.5) * r.shake * 7), roundf((randf() - 0.5) * r.shake * 7))
	for l in [back, hero_layer, front]:
		l.position = off
	seat = _seat()
	# he steps out of the doorway: hidden while still inside
	var in_temple = TEMPLE_X - r.cam / PIXEL > -_w("temple")
	var rid = hero_layer.get_canvas_item()
	var clip = in_temple and r.cam == 0
	RenderingServer.canvas_item_set_custom_rect(rid, clip, Rect2(DOOR_X, -400, view_w + 400, 1200))
	RenderingServer.canvas_item_set_clip(rid, clip)
	for l in [back, hero_layer, front, over]:
		l.queue_redraw()

# ---------- small helpers ----------

func snap(v: float) -> float:
	return roundf(v * q) / q

func n(v: float) -> float:                     # from game units, to the nearest spot that can be shown
	return roundf(v / PIXEL * q) / q

func h01(i: float, s: float) -> float:
	var x = sin(i * 127.1 + s * 311.7) * 43758.5453
	return x - floor(x)

func _w(name: String) -> float:
	var tx: Texture2D = Art.tex.get(name)
	return tx.get_width() if tx != null else 0.0

func sx(wx: float) -> float:
	return snap(wx / PIXEL - run.cam / PIXEL)

func floor_px(x: float) -> float:              # floor height under a screen x
	return n(Game.floor_at(run, (run.cam / PIXEL + x) * PIXEL))

func rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), col)

func blit(c: CanvasItem, tx: Texture2D, x: float, y: float, flip: bool = false, mod: Color = Color.WHITE) -> void:
	if tx == null:
		return
	var w = tx.get_width()
	c.draw_texture_rect(tx, Rect2(x, y, -w if flip else w, tx.get_height()), false, mod)

func region(c: CanvasItem, tx: Texture2D, sx_: float, sy: float, sw: float, sh: float, dx: float, dy: float, dw: float, dh: float, mod: Color = Color.WHITE) -> void:
	if tx == null:
		return
	c.draw_texture_rect_region(tx, Rect2(dx, dy, dw, dh), Rect2(sx_, sy, sw, sh), mod)

## A rectangle of a picture, cut to what lies inside `clip`.
func region_clip(c: CanvasItem, tx: Texture2D, src: Rect2, dst: Rect2, clip: Rect2, flip: bool = false, mod: Color = Color.WHITE) -> void:
	var inter = dst.intersection(clip)
	if inter.size.x <= 0 or inter.size.y <= 0:
		return
	var kx = src.size.x / dst.size.x
	var ky = src.size.y / dst.size.y
	var s_y = src.position.y + (inter.position.y - dst.position.y) * ky
	var s_x = src.position.x + ((dst.end.x - inter.end.x) if flip else (inter.position.x - dst.position.x)) * kx
	c.draw_texture_rect_region(tx, Rect2(inter.position.x, inter.position.y, -inter.size.x if flip else inter.size.x, inter.size.y), Rect2(s_x, s_y, inter.size.x * kx, inter.size.y * ky), mod)

func sheet(c: CanvasItem, tx: Texture2D, frames: int, frame: int, x: float, y: float, mod: Color = Color.WHITE) -> float:
	var fw = tx.get_width() / float(frames)
	region(c, tx, fw * frame, 0, fw, tx.get_height(), x, y, fw, tx.get_height(), mod)
	return fw

## A soft round glow: the white disc of Art, tinted, stretched over the rectangle.
func glow(c: CanvasItem, cx: float, cy: float, r: float, col: Color) -> void:
	c.draw_texture_rect(Art.radial, Rect2(cx - r, cy - r, 2 * r, 2 * r), false, col)

## A colour fading along x, from col0 at x0 to col1 at x1.
func hgrad(c: CanvasItem, x0: float, x1: float, y: float, h: float, col0: Color, col1: Color) -> void:
	if x1 <= x0:
		return
	c.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + h), Vector2(x0, y + h)]), PackedColorArray([col0, col1, col1, col0]))

## A soft blob on the floor under whatever stands or flies above it.
func shadow(c: CanvasItem, cx: float, y: float, w: float) -> void:
	var x = snap(cx - w / 2.0)
	var col = Color(14 / 255.0, 8 / 255.0, 34 / 255.0, 0.34)
	rect(c, x + 2, y - 1, w - 4, 1, col)
	rect(c, x, y, w, 2, col)
	rect(c, x + 2, y + 2, w - 4, 1, col)

## A small arrow head whose tip is at (x, y), pointing up (dir -1) or down (dir 1), `size` rows tall.
func chevron(c: CanvasItem, x: float, y: float, dir: int, colour: Color, size: int = 4) -> void:
	for pass_ in [[INK, 1], [colour, 0]]:
		var g: int = pass_[1]
		for k in size:
			rect(c, x - k - 1 - g, y - dir * k - g, 2 * k + 2 + 2 * g, 1 + 2 * g, pass_[0])

func chevron_left(c: CanvasItem, x: float, y: float, size: int = 4) -> void:
	for pass_ in [[INK, 1], [RED, 0]]:
		var g: int = pass_[1]
		for k in size:
			rect(c, x + k - g, y - k - g, 1 + 2 * g, 2 * k + 1 + 2 * g, pass_[0])

## A digit in a 3 x 5 pixel font, `k` times larger, outlined, centred on x: the Sablier's last seconds.
func draw_digit(c: CanvasItem, d: int, x: float, y: float, k: float) -> void:
	if not DIGITS.has(d):
		return
	var bits: String = DIGITS[d]
	var x0 = roundf(x - 1.5 * k)
	var y0 = roundf(y)
	for pass_ in [[INK, 1.0], [Color("#d6f4ff"), 0.0]]:
		var g: float = pass_[1]
		for i in 15:
			if bits[i] == "1":
				rect(c, x0 + (i % 3) * k - g, y0 + floori(i / 3.0) * k - g, k + 2 * g, k + 2 * g, pass_[0])

# ---------- three depths of scenery ----------

func strip(c: CanvasItem, tx: Texture2D, offset: float, y: float, clip: Rect2) -> void:
	var w = float(tx.get_width())
	var h = float(tx.get_height())
	var i = floori((offset + clip.position.x) / w)
	while i * w - offset < clip.end.x:
		region_clip(c, tx, Rect2(0, 0, w, h), Rect2(snap(i * w - offset), y, w, h), clip, (i & 1) == 1)
		i += 1

func paint(c: CanvasItem, S: Dictionary, clip: Rect2, sky: bool) -> void:
	var cam = run.cam / PIXEL
	if sky:
		c.draw_rect(clip, S["sky"])
	if S["bg"] != null:
		strip(c, S["bg"], cam * 0.18, VH - S["bg"].get_height(), clip)
	if S["mid"] == null:
		return
	var y: float = GN + 20 - S["mid"].get_height()
	strip(c, S["mid"], cam * 0.5, y, clip)
	var base = Rect2(0, y + S["mid"].get_height(), view_w, VH).intersection(clip)   # seen only where the path dips
	if base.has_area():
		c.draw_rect(base, S["base"])

## Two sceneries meet at `edge` (screen x). The far scenery changes tile by tile, like a picture loading:
## each tile has its own moment, up to SPREAD pixels before or after the edge, and flashes as it turns.
func mosaic(c: CanvasItem, edge: float) -> void:
	var A: Dictionary = Art.scene[run.prev_biome]
	var B: Dictionary = Art.scene[run.biome]
	var whole = Rect2(0, -8, view_w, VH + 16)
	if run.prev_biome == run.biome or edge <= -SPREAD:
		paint(c, B, whole, false)
		return
	if edge - SPREAD >= view_w:
		paint(c, A, whole, false)
		return
	paint(c, A, whole, false)
	var left = maxf(0, floorf((edge - SPREAD) / TILE) * TILE)
	var right = minf(ceilf(view_w / TILE) * TILE, ceilf((edge + SPREAD) / TILE) * TILE)
	if right < view_w:
		paint(c, B, Rect2(right, 0, view_w - right, VH), true)
	var lit: Array = []
	var x = left
	while x < right:
		var y = 0.0
		while y < VH:
			var at = edge + (h01(x / TILE + 31 * (y / TILE), 2) - 0.5) * 2 * SPREAD
			if x > at:
				paint(c, B, Rect2(x, y, TILE, TILE), true)
			elif x > at - 14:
				lit.append(Vector2(x, y))
			y += TILE
		x += TILE
	for p in lit:
		rect(c, p.x, p.y, TILE, TILE, Color(210 / 255.0, 1, 250 / 255.0, 0.8))

# ---------- Vorace ----------
# The queen flower in three layers cut from one picture (tools/import_vorace.py), drawn back to front:
# legs, head, body. Her end: a trunk drops flat onto her crown (0.9 s), the urn cracks, the legs give
# way and she slumps onto them, then everything goes down behind the floor, the trunk with her.

func vorace_frame() -> Dictionary:
	var b = run.boss
	var fall: bool = b.phase == "fall"
	var bt: float = b.t
	var step = floori(t * 7) % 4
	var L = 4 if (fall and bt >= 1.15) else step
	var H = 0
	if fall:
		H = 1 if bt < 0.9 else (4 if bt < 1.5 else 5)
	elif b.open > 0:
		H = 3
	elif b.wind > 0:
		H = 1 if b.wind > 0.22 else 2
	var B = 1 if (fall and bt >= 1.0) else 0
	var drop = 40.0
	if Art.meta.has("vorace"):
		drop = float(Art.meta["vorace"]["legs"]["drop"][4])
	var bob = 0.0
	if fall:
		bob = roundf(drop * pow(minf(1, (bt - 1.15) / 0.22), 2)) if bt >= 1.15 else 0.0
	else:
		bob = -1.0 if step % 2 == 1 else 0.0
	var breathe = roundf(sin(t * 2.4)) if (not fall and H == 0) else 0.0
	var lunge = -2.0 if H == 3 else 0.0
	var sink = pow(bt - 1.6, 2) * 320 if (fall and bt > 1.6) else 0.0
	return {"L": L, "H": H, "B": B, "step": step, "bob": bob, "breathe": breathe, "lunge": lunge, "sink": sink}

func draw_vorace(c: CanvasItem) -> void:
	var b = run.boss
	if not Art.meta.has("vorace"):
		return
	var V: Dictionary = Art.meta["vorace"]
	var legs: Texture2D = Art.tex.get("vorace-legs")
	var head: Texture2D = Art.tex.get("vorace-head")
	var body: Texture2D = Art.tex.get("vorace-body")
	if legs == null or head == null or body == null:
		return
	var f = vorace_frame()
	var fall: bool = b.phase == "fall"
	var left = snap(n(b.sx))
	var top = roundf(GN + VORACE_SINK - float(V["ground"]) + f["sink"])
	if not fall and b.last_step != f["step"] and (f["step"] == 0 or f["step"] == 2):   # a foot comes down: earth flies
		for fx in V["feet"][0 if f["step"] == 0 else 1]:
			for k in 4:
				dirt.append({"x": left + fx + randf() * 8 - 4 + run.cam / PIXEL, "y": GN - 2, "vx": (randf() - 0.5) * 60, "vy": -40 - randf() * 60, "life": 0.5})
	b.last_step = f["step"]
	_layer_of(c, legs, V["legs"], f["L"], left, top, 0, 0.0 if f["L"] == 4 else maxf(0, f["bob"]))
	if b.wind > 0 or b.open > 0:                      # the acid glowing in its throat: something is coming
		var mx: float = left + V["mouth"][0] + f["lunge"]
		var my: float = top + V["mouth"][1] + f["bob"]
		var r = 30.0 + (10.0 if b.open > 0 else 0.0)
		glow(c, mx, my, r, Color(168 / 255.0, 1, 60 / 255.0, 0.5 + 0.3 * sin(t * 30)))
	_layer_of(c, head, V["head"], f["H"], left, top, f["lunge"], f["bob"] + f["breathe"])
	_layer_of(c, body, V["body"], f["B"], left, top, 0, f["bob"])
	var log_tex: Texture2D = Art.tex.get("vorace-log")
	if fall and log_tex != null:                      # the trunk drops flat onto the crown, then goes down with her
		var rest: float = float(V["body"]["y"]) + 6 if f["H"] == 5 else float(V["head"]["tops"][f["H"]]) + 4
		var land: float = top + rest + f["bob"]
		var lh = float(log_tex.get_height())
		var k = minf(1, pow(b.t / 0.9, 2))
		var y = roundf(-lh + (land + lh) * k) - lh
		blit(c, log_tex, left + float(V["crown"][0]) - (log_tex.get_width() >> 1), land - lh if b.t >= 0.9 else y)

func _layer_of(c: CanvasItem, tx: Texture2D, P: Dictionary, frame: int, left: float, top: float, dx: float, dy: float) -> void:
	var w = float(P["w"])
	var h = float(P["h"])
	region(c, tx, frame * w, 0, w, h, left + float(P["x"]) + dx, top + float(P["y"]) + dy, w, h)

## The earth thrown up by Vorace's legs: in front of the floor.
func draw_dirt(c: CanvasItem) -> void:
	var cam = run.cam / PIXEL
	var dt = clampf(t - dirt_t, 0, 0.05)
	dirt_t = t
	for d in dirt:
		d["life"] -= dt
		d["vy"] += 300 * dt
		d["x"] += d["vx"] * dt
		d["y"] += d["vy"] * dt
	dirt = dirt.filter(func(d): return d["life"] > 0)
	for d in dirt:
		rect(c, snap(d["x"] - cam), snap(d["y"]), 2, 2, Color("#5a3a24") if d["life"] > 0.25 else Color("#7a5236"))

# ---------- the warning of a flyer ----------
# A big danger sign at the right edge, at the height it will come at, pulsing between two sizes in a red
# glow, an arrow pointing in and a dashed trail along its path. Never blinked away.
func warn_mark(c: CanvasItem, x: float, y: float, age: float) -> void:
	var big = floori(t * 7) % 2 == 0
	var im = Art.warn_sign(30 if big else 26)
	var h = float(im.get_height())
	var w = float(im.get_width())
	y = maxf(h / 2 + 2, minf(VH - 34, y))
	glow(c, x, y, 30, Color(1, 59 / 255.0, 78 / 255.0, 0.55 if big else 0.4))
	for k in 6:                                      # its path, fading towards the hero
		var dx = x - 26 - k * 14 - fmod(t * 40, 14)
		rect(c, snap(dx), roundf(y), 8, 2, Color(1, 96 / 255.0, 96 / 255.0, 0.7 * (1 - k / 6.0) * minf(1, age * 4)))
	blit(c, im, roundf(x - w / 2), roundf(y - h / 2))
	chevron_left(c, roundf(x - w / 2) - 7, roundf(y), 6)

# ---------- the scenery behind the path ----------

func draw_hills(c: CanvasItem) -> void:
	var cam = run.cam / PIXEL
	for hl in run.hills:
		var x = snap(hl.x / PIXEL - cam)
		var w = roundi(hl.w / PIXEL)
		var h = roundi(hl.h / PIXEL)
		if x > view_w or x + w < 0:
			continue
		blit(c, Art.hill(hl.biome, w, h, hl.seed % 997), x, GN + 6 - h)

## Scenery props stand on the floor behind the action. Which one stands where comes from the cell number
## alone, so the same stretch always looks the same within a run.
func draw_props(c: CanvasItem) -> void:
	var cam = run.cam / PIXEL
	var first = floori(cam / PROP_CELL) - 1
	var last = floori((cam + view_w) / PROP_CELL) + 1
	for i in range(first, last + 1):
		var pr = Game.prop_at(i)
		if pr == null or not Game.flat_at(run, pr["x"], Game.PROP_CELL * 0.6):
			continue                                 # nothing grows on a slope
		var biome = Game.biome_at(run, pr["x"])
		var set_: Array = Art.scene[biome]["props"]
		var k: int = pr["kind"] % set_.size()
		var im: Texture2D = set_[k]
		if im == null or k == SMASH[biome]:
			continue
		if run.boss != null and Art.meta.has("vorace"):   # nothing stands in front of Vorace
			var bx = n(run.boss.sx)
			var px: float = pr["x"] / PIXEL - cam
			if px + im.get_width() > bx and px < bx + float(Art.meta["vorace"]["w"]):
				continue
		var x = snap(pr["x"] / PIXEL - cam)
		var y = n(Game.floor_at(run, pr["x"])) - im.get_height() + 3
		if biome != 0:
			blit(c, im, x, y, pr["flip"])
			continue
		# brushed by the hero a moment ago: it shakes hard, then settles
		var since: float = run.t - run.touched[i] if run.touched.has(i) else 9.0
		var shiver = 1.0 - since if since < 1 else 0.0
		if shiver > 0 and pr["kind"] != Game.PROP_LANTERN:   # a lantern lights up, it does not shake
			Ambient.sway_blit(c, im, x, y, pr["flip"], t * 7, i, 5 * shiver)
		elif pr["kind"] in SWAYING:
			Ambient.sway_blit(c, im, x, y, pr["flip"], t, i, 2)
		else:
			blit(c, im, x, y, pr["flip"])
		if pr["kind"] == Game.PROP_LANTERN or (pr["kind"] == Game.PROP_SHROOM and shiver > 0):   # the flame breathes, the caps light up
			var shroom: bool = pr["kind"] == Game.PROP_SHROOM
			var a = 0.35 * shiver if shroom else 0.16 + 0.12 * pow(sin(t * 5 + i), 2) + 0.3 * shiver
			rect(c, x + (im.get_width() >> 1) - 12, y + im.get_height() - (66 if shroom else 34), 24, 40 if shroom else 20, Color("#7dfff0", a))

## Hanging lianas as scenery, in the forest and the ruins: here and there along the way, from the top of
## the screen, a little darker than what can be touched.
func draw_hanging_vines(c: CanvasItem) -> void:
	if Art.hangs == null or not Art.meta.has("vines"):
		return
	var H: Dictionary = Art.meta["vines"]["hang"]
	var cam = run.cam / PIXEL
	var first = floori(cam / VINE_CELL) - 1
	var last = floori((cam + view_w) / VINE_CELL) + 1
	for i in range(first, last + 1):
		if h01(i, 17) > 0.42:
			continue
		var wx = i * VINE_CELL + roundf(h01(i, 19) * 70)
		if Game.biome_at(run, wx * PIXEL) > 1:
			continue
		hang(c, Art.hangs, H, floori(h01(i, 23) * int(H["n"])), snap(wx - cam), -2, i)

## One of the hanging lianas, swaying a little from its top (drawn in slices).
func hang(c: CanvasItem, im: Texture2D, H: Dictionary, which: int, x: float, y: float, seed: float) -> void:
	var ln = float(H["len"][which])
	var w = float(H["w"])
	var s_x = which * w
	var r = 0.0
	while r < ln:
		var sway = roundf(sin(t * 1.4 + seed) * 2.2 * r / ln)
		var hh = minf(4, ln - r)
		region(c, im, s_x, r, w, hh, x - floorf(w / 2) + sway, y + r, w, hh)
		r += 4

## The vines the gorilla travels along: a braided liana across the top of the frame, short lianas
## hanging from it. `k` slides them in from above (0 hidden, 1 down).
func draw_vines(c: CanvasItem, k: float) -> void:
	var G: Texture2D = Art.tex.get("vine-garland")
	var Hn: Texture2D = Art.tex.get("vine-hang")
	if G == null or not Art.meta.has("vines"):
		return
	var cam = run.cam / PIXEL
	var dy = roundf((k - 1) * 50)
	var gw = float(G.get_width())
	var i = floori(cam / gw) - 1
	while i * gw - cam < view_w:
		var x0 = snap(i * gw - cam)
		blit(c, G, x0, dy + 4, i % 2 != 0)
		if Hn != null:
			for qq in 2:
				var which = floori(h01(i * 2 + qq, 81) * 2)
				var hx = x0 + roundf(gw * (0.2 + 0.55 * h01(i * 2 + qq, 83)))
				hang(c, Hn, Art.meta["vines"]["hang"], which, hx, dy + 14, i * 2 + qq)
		i += 1

## An iron chain from (x, y) up to the top of the screen: links seen flat and edge-on in turn.
func chain(c: CanvasItem, x: float, y: float) -> void:
	var yy = y
	var k = 0
	while yy > -8:
		if k % 2 == 1:
			rect(c, x - 1, yy - 6, 3, 7, INK)
			rect(c, x, yy - 5, 1, 5, Color("#7c7a8c"))
		else:
			rect(c, x - 3, yy - 6, 7, 7, INK)
			rect(c, x - 2, yy - 5, 5, 5, Color("#5c5a6c"))
			rect(c, x - 1, yy - 4, 3, 3, INK)
			rect(c, x - 2, yy - 5, 2, 1, Color("#9a98aa"))
		yy -= 5
		k += 1

## What is left of the doorway once it has blown out: a ragged hole and rubble on the steps.
func draw_blast(c: CanvasItem, x: float) -> void:
	var hole = Color("#0d0a18")
	rect(c, x + 84, GN - 100, 42, 84, hole)
	rect(c, x + 80, GN - 88, 4, 60, hole)
	rect(c, x + 126, GN - 92, 5, 66, hole)
	rect(c, x + 90, GN - 106, 28, 6, hole)
	rect(c, x + 76, GN - 60, 4, 22, hole)
	rect(c, x + 131, GN - 70, 3, 30, hole)
	for s in [[70, 14, 12, 8, "#6a6f8c"], [96, 10, 9, 7, "#8a8fa8"], [118, 15, 14, 9, "#4a4f6c"], [140, 8, 8, 6, "#6a6f8c"], [154, 12, 11, 8, "#8a8fa8"], [108, 20, 7, 5, "#7bd13c"]]:
		rect(c, x + s[0] - 1, GN - s[1] - 1, s[2] + 2, s[3] + 2, INK)
		rect(c, x + s[0], GN - s[1], s[2], s[3], Color(s[4]))

## The floor follows the path's relief: every column of every piece sits at the height floor_at gives,
## with plain earth underneath down to the bottom of the picture. Only x0..x1 is drawn.
func draw_ground(c: CanvasItem, G: Dictionary, x0: float, x1: float, bottom: float) -> void:
	var L: float = G["len"]
	if L <= 0 or x1 <= x0:
		return
	var cam = run.cam / PIXEL
	var clip = Rect2(x0, -400, x1 - x0, 1200)
	var top: float = G["top"]
	var soil: Color = G["soil"]
	var base = -fposmod(cam, L)
	while base < x1:
		for g in G["pieces"]:
			var px = snap(base + g["x"])
			var w: int = g["w"]
			var h: float = g["h"]
			if px >= x1 or px + w <= x0:
				continue
			# Columns standing at the same height are drawn as one block: on the flat, which is nearly
			# everywhere, a whole piece goes down in a single call instead of one per column.
			var a = maxi(0, floori((x0 - px) / SLICE) * SLICE)
			var ya = 0.0
			var has_ya = false
			var k = a
			while true:
				var out = k >= w or px + k >= x1
				var y = 0.0
				if not out:
					y = n(Game.floor_at(run, (cam + px + k + mini(SLICE, w - k) / 2.0) * PIXEL)) - top
					if has_ya and y == ya:
						k += SLICE
						continue
				if has_ya:
					var cw = float(mini(k, w) - a)
					var x = px + a
					region_clip(c, g["tex"], Rect2(a, 0, cw, h), Rect2(x, ya, cw, h), clip)
					# under a raised stretch: the earth of the piece's lower half again, as often as needed
					var yy = ya + h - 1
					while yy < VH:
						region_clip(c, g["tex"], Rect2(a, h - EARTH - 2, cw, EARTH), Rect2(x, yy, cw, EARTH), clip)
						yy += EARTH
					if ya + h < bottom and ya + h >= VH:
						var fill = Rect2(x, ya + h, cw, bottom - ya - h).intersection(clip)
						if fill.has_area():
							c.draw_rect(fill, soil)
				if out:
					break
				a = k
				ya = y
				has_ya = true
				k += SLICE
		base += L

# ---------- the hero ----------
# He is not a sheet of poses but loose pieces: a body, two fists, two shoes. Where each one is comes from
# a formula, so he moves as smoothly as the screen refreshes, at any speed.

## drawImage for the hero's pieces, which have a finer version: in the original's own pixels.
func put(c: CanvasItem, name: String, x: float, y: float, mod: Color = Color.WHITE) -> void:
	var base: Texture2D = Art.tex.get(name)
	if base == null:
		return
	var fine: Texture2D = Art.hi.get(name, base)
	c.draw_texture_rect(fine, Rect2(x, y, base.get_width(), base.get_height()), false, mod)

func put_region(c: CanvasItem, name: String, s_x: float, s_y: float, sw: float, sh: float, dx: float, dy: float, dw: float, dh: float) -> void:
	var base: Texture2D = Art.tex.get(name)
	if base == null:
		return
	var fine: Texture2D = Art.hi.get(name)
	var k = HI_K if fine != null else 1.0
	c.draw_texture_rect_region(fine if fine != null else base, Rect2(dx, dy, dw, dh), Rect2(s_x * k, s_y * k, sw * k, sh * k))

## An image centred on a point, turned by `rot` (radians, clockwise), inside the transform `xf`.
func part(c: CanvasItem, xf: Transform2D, name: String, cx: float, cy: float, rot: float, mod: Color = Color.WHITE) -> void:
	var base: Texture2D = Art.tex.get(name)
	if base == null:
		return
	var w = float(base.get_width())
	var h = float(base.get_height())
	if rot == 0:
		c.draw_set_transform_matrix(xf)
		put(c, name, snap(cx - w / 2), snap(cy - h / 2), mod)
	else:
		c.draw_set_transform_matrix(xf.translated_local(Vector2(cx, cy)).rotated_local(rot))
		put(c, name, -w / 2, -h / 2, mod)

## One shoe of the run: half a turn in the air swinging forward, half a turn on the floor going back.
func stride(th: float) -> Dictionary:
	var up = maxf(0, sin(th))
	return {"x": -1 - 8 * cos(th), "y": -4.5 - 6 * up, "r": 0.5 * sin(2 * th) if up > 0 else 0.0}

func _draw_hero_layer(c: CanvasItem) -> void:
	if run == null or not Art.ready or run.dead:
		return
	draw_hero(c, seat)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## `seat`: where he sits when he rides, {x, y, k} with k going 0 -> 1 while he hops into the saddle.
func draw_hero(c: CanvasItem, st) -> void:
	var p = run.p
	var R: Dictionary = Art.meta["rig"]
	var dashing = run.dash.t > 0
	var ox = n(run.sx)
	var oy = n(p.y)
	if dashing:                                      # the relic's aura
		glow(c, ox, oy - 18, 30 + sin(t * 30) * 2, Color(1, 211 / 255.0, 92 / 255.0, 0.6))
	if p.inv > 0 and run.leap == null and not (st != null and st["k"] < 1) and floori(t * 14) % 2 == 1:
		return                                       # blinking while invincible
	if p.ball != null:                               # the Sphère: a ball of leaves, rolling, swelling out of a puff
		var base: Texture2D = Art.tex.get("hero-ball")
		if base == null:
			return
		var k = minf(1, p.balled / 0.18)
		var s = 0.55 + 0.45 * k + 0.18 * sin(PI * k)
		var h = float(base.get_height())
		c.draw_set_transform_matrix(Transform2D(0, Vector2(ox, oy - h / 2 + 1)).rotated_local(p.roll).scaled_local(Vector2(s, s)))
		put(c, "hero-ball", -base.get_width() / 2.0, -h / 2)
		return

	# The pose: body (bx, by = where the bottom of his trunk is, tilt), shoes and fists, far then near.
	var body = "hero-body"
	var B: Dictionary = R["body"]
	var bx = -1.0
	var by = -11.0
	var tilt = 0.0
	var spin = false
	var shoes: Array
	var fists: Array
	if st != null:                                   # riding: sitting, one leg over, both hands on the reins
		var hop = sin(PI * st["k"]) * 14
		ox = lerpf(ox, st["x"], st["k"])
		oy = lerpf(oy, st["y"] + 11, st["k"]) - hop
		shoes = [null, {"x": 4.0, "y": -5.0, "r": 0.25}]
		fists = [{"x": 8.0, "y": -19.0}, {"x": 10.0, "y": -18.0}]
	elif p.flying and run.leap == null:              # the leaf rotor: he hangs under it, feet dangling
		var sway = sin(t * 9) * 1.5
		body = "hero-rotor"
		B = R["rotor"]
		spin = true
		shoes = [{"x": -5 - sway, "y": -4.0, "r": 0.15}, {"x": 3 - sway, "y": -5.0, "r": -0.1}]
		fists = [{"x": -9.0, "y": -17 + sway * 0.5}, {"x": 9.0, "y": -17 - sway * 0.5}]
	elif not p.ground:                               # jumping (k = 1) then falling (k = 0)
		var k = clampf(0.5 - p.vy / 900, 0, 1)
		shoes = [{"x": lerpf(-4, -9, k), "y": lerpf(-4, -7, k), "r": lerpf(-0.2, 0.6, k)}, {"x": lerpf(5, 1, k), "y": lerpf(-5, -3, k), "r": lerpf(-0.35, 0.45, k)}]
		fists = [{"x": lerpf(-9, -8, k), "y": lerpf(-33, -19, k)}, {"x": lerpf(10, 9, k), "y": lerpf(-34, -30, k)}]
		tilt = lerpf(0.1, -0.12, k)
	else:                                            # running
		var th = p.phase
		var sq = p.squash * 2
		shoes = [stride(th + PI), stride(th)]
		fists = [{"x": 2 - 7 * cos(th), "y": -21 - 2 * absf(cos(th))}, {"x": 2 + 7 * cos(th), "y": -21 - 2 * absf(cos(th))}]
		by += 1.5 * absf(sin(th)) + sq
		shoes[0]["x"] -= sq
		shoes[1]["x"] += sq
		if run.lvl("sprint") > 0:
			shoes = [null, null]                     # Sprint: no strides any more, a wheel of legs (below)

	var xf = Transform2D(0, Vector2(ox, oy))
	if run.leap != null:                             # knocked out: he tumbles
		xf = xf.translated_local(Vector2(0, -20)).rotated_local(p.roll).translated_local(Vector2(0, 20))
	if shoes[0] != null:
		part(c, xf, "far-shoe", shoes[0]["x"], shoes[0]["y"], shoes[0]["r"])
	part(c, xf, "far-fist", fists[0]["x"], fists[0]["y"], 0)
	var xb = xf.translated_local(Vector2(snap(bx), snap(by)))
	if tilt != 0:
		xb = xb.rotated_local(tilt)
	c.draw_set_transform_matrix(xb)
	var bw_: float = B["w"]
	var bh_: float = B["h"]
	var tx_: float = B["tx"]
	if spin:                                         # the blades are squeezed sideways, back and forth: they spin
		var blade: float = B["blade"]
		var hx: float = B["hx"]
		var w = 0.25 + 0.75 * absf(cos(t * 26))
		put_region(c, body, 0, 0, bw_, blade, snap(hx - tx_ - hx * w), -bh_, snap(bw_ * w), blade)
		put_region(c, body, 0, blade, bw_, bh_ - blade, -tx_, -bh_ + blade, bw_, bh_ - blade)
	else:
		# His leaves live: the picture is cut in thin rows that the wind moves, more and more towards the
		# tips, pulled back harder the faster he goes. His head, his trunk and the backpack stay still.
		var x0 = snap(-tx_)
		var y0 = -bh_
		var base: Texture2D = Art.tex.get(body)
		var w = float(base.get_width())
		var h = float(base.get_height())
		var hair = roundf(float(B["hy"]) - 6)
		var pack = roundf(float(B.get("gx", 0.0)) + 5)
		var pull = minf(1, run.speed / 700)
		var air = 0.0 if p.ground else clampf(p.vy / 700, -1, 1)
		put_region(c, body, 0, hair, w, h - hair, x0, y0 + hair, w, h - hair)
		put_region(c, body, 0, 0, pack, hair, x0, y0, pack, hair)
		var r = 0.0
		while r < hair:
			var up = 1 - r / hair
			var dx = (sin(t * 8 + r * 0.4) * 1.3 - 1.6 * pull) * up * up
			var dy = -air * 2.5 * up
			put_region(c, body, pack, r, w - pack, 2, x0 + pack + snap(dx), y0 + r + snap(dy), w - pack, 2)
			r += 2
	# the relic in his backpack: a soft glow, which flares when it moves the world
	if B.has("gx"):
		var gx = -tx_ + float(B["gx"])
		var gy = -bh_ + float(B["gy"])
		var k = run.relic
		var rr = 7 + 16 * k
		glow(c, gx, gy, rr, Color(160 / 255.0, 250 / 255.0, 1, minf(1, 0.3 + 0.12 * sin(t * 3) + 0.6 * k)))
		if k > 0.2:
			for i in 5:
				var a = t * 3 + i * 1.26
				var d = 6 + 10 * k + 3 * sin(t * 9 + i)
				rect(c, snap(gx + cos(a) * d), snap(gy + sin(a) * d), 1, 1, Color("#eaffff"))
	if shoes[1] != null:
		part(c, xf, "hero-shoe", shoes[1]["x"], shoes[1]["y"], shoes[1]["r"])
	elif shoes[0] == null:                           # the cartoon whirl: shoes chasing each other round a blur
		var a = t * 34
		c.draw_set_transform_matrix(xf.translated_local(Vector2(-1, -7)).scaled_local(Vector2(1, 8 / 11.0)))
		c.draw_circle(Vector2.ZERO, 11, Color(1, 1, 1, 0.28))
		for k in 3:
			var rx = 11 - k * 3.0
			var ry = 8 - k * 2.2
			c.draw_set_transform_matrix(xf.translated_local(Vector2(-1, -7)).scaled_local(Vector2(1, ry / rx)))
			var a0 = a * (1 + k * 0.3) + k * 2
			c.draw_arc(Vector2.ZERO, rx, a0, a0 + 1.9, 10, Color(1, 1, 1, 0.8), 1.5)
		for k in 4:
			var bb = a + k * PI / 2
			part(c, xf, "hero-shoe", -1 + cos(bb) * 8, -7 + sin(bb) * 5.5, bb + PI / 2, Color(1, 1, 1, 0.85))
	part(c, xf, "hero-fist", fists[1]["x"], fists[1]["y"], 0)

# ---------- mounts ----------

## Draws one frame of a mount standing on `floor` (its saddle above x) and returns where a rider's trunk rests.
func draw_mount(c: CanvasItem, kind: String, frame: int, x: float, floor_y: float, bob: float, mod: Color = Color.WHITE):
	var im: Texture2D = Art.tex.get("mount-" + kind)
	if im == null:
		return null
	var M: Dictionary = Art.meta["mounts"][kind]
	var cw = im.get_width() / float(M["frames"])
	var top = floor_y + 1 - im.get_height() + bob
	if c != null:
		region(c, im, cw * frame, 0, cw, im.get_height(), snap(x - float(M["seatX"])), snap(top), cw, im.get_height(), mod)
	return {"x": x, "y": top + float(M["seatY"]) - 3}

## A flying mount is placed by its saddle: the floor to give draw_mount so that the saddle is at `seat_y`.
func seat_floor(kind: String, seat_y: float) -> float:
	var im: Texture2D = Art.tex.get("mount-" + kind)
	if im == null:
		return seat_y
	return seat_y - float(Art.meta["mounts"][kind]["seatY"]) + 2 + im.get_height()

## The gorilla hanging from the vines: its gripping fist stays put at the top, the body swings under it.
func draw_hang(c: CanvasItem, frame: int, x: float):
	var im: Texture2D = Art.tex.get("mount-gorilla-hang")
	if im == null:
		return null
	var M: Dictionary = Art.meta["mounts"]["gorilla-hang"]
	var cw = im.get_width() / float(M["frames"])
	var left = snap(x + 12 - float(M["seatX"]))
	if c != null:
		region(c, im, cw * frame, 0, cw, im.get_height(), left, 5, cw, im.get_height())
	return {"x": left + float(M["seats"][frame][0]), "y": float(M["seats"][frame][1]) + 2}

## The pose of the ridden mount this frame, and so where the hero sits (`c` null: only worked out).
func _mount(c: CanvasItem):
	var M = run.mount
	if M == null or run.dead or not Art.ready:
		return null
	var p = run.p
	var hx = n(run.sx)
	var s = null
	if p.hang:                                       # hand over hand under the vines
		s = draw_hang(c, floori(p.phase / TAU * 4) % 4, hx)
	elif Game.MOUNTS[M.kind].get("fly", false):
		s = draw_mount(c, M.kind, floori(t * 18) % 4, hx, seat_floor(M.kind, n(p.y) - 34), 0)
	else:                                            # it gallops under him; in the air it stretches out
		var frame = (3 if M.kind == "gorilla" else 0) if not p.ground else floori(p.phase / TAU * 4) % 4
		var time: float = Game.MOUNTS[M.kind].get("time", 0.0)
		var left: float = time - M.t if time > 0 else 9.0     # the rhino's time running out: it blinks
		var mod = Color(1, 1, 1, 0.45) if (left < 1.5 and floori(t * 10) % 2 == 1) else Color.WHITE
		s = draw_mount(c, M.kind, frame, hx, n(p.y), -absf(sin(p.phase * 2)) * 1.5 if p.ground else 0.0, mod)
	if s == null:
		return null
	s["k"] = minf(1, M.t / 0.32)
	return s

func _seat():
	return _mount(null)

# ---------- the world behind the hero ----------

func _draw_back(c: CanvasItem) -> void:
	if run == null or not Art.ready:
		rect(c, 0, 0, view_w, VH, Color("#0b2530"))
		return
	var cam = run.cam / PIXEL
	var now: Dictionary = Art.scene[run.biome]
	var edge = snap(run.biome_x / PIXEL - cam)

	rect(c, 0, -8, view_w, VH + 16, now["sky"])
	mosaic(c, edge)
	Ambient.draw_sky(c, t, view_w)

	draw_hills(c)                                    # dark hills behind the path
	if run.boss != null:
		draw_vorace(c)                               # behind the floor: its legs plunge into it
	draw_props(c)
	draw_hanging_vines(c)
	for dc in run.decor:                             # the scenery that can be smashed; with Brise-tout it glints
		var im: Texture2D = Art.decor[dc.biome]
		if dc.broken or im == null:
			continue
		var x = snap(sx(dc.x + Game.DECOR_W / 2) - im.get_width() / 2.0)
		var y = floor_px(x + im.get_width() / 2.0) - im.get_height() + 3
		if x > view_w or x + im.get_width() < 0:
			continue
		blit(c, im, x, y)
		if run.lvl("breaker") > 0 and sin(t * 4 + dc.x) > 0.7:
			var gx = snap(x + im.get_width() * 0.7)
			var gy = y + 4
			rect(c, gx, gy - 2, 1, 5, Color("#fff8d8"))
			rect(c, gx - 2, gy, 5, 1, Color("#fff8d8"))
	var cut = clampf(edge, 0, view_w)               # the floor changes exactly where the new place begins
	var changing = run.prev_biome != run.biome
	if changing:
		draw_ground(c, Art.scene[run.prev_biome]["ground"], 0, cut, VH + 8)
	draw_ground(c, now["ground"], cut if changing else 0.0, view_w, VH + 8)
	Ambient.draw_life(c, cam, t, view_w, floor_px)
	draw_dirt(c)

	var temple: Texture2D = Art.tex.get("temple")
	var templeX = snap(TEMPLE_X - cam)
	var in_temple = temple != null and templeX > -temple.get_width()
	if in_temple:
		blit(c, temple, templeX, GN - temple.get_height() + 3)
		if run.exploded:
			draw_blast(c, templeX)
		elif Art.tex.has("temple-rubble"):           # the jungle has closed the way out, until the blast
			var rb: Texture2D = Art.tex["temple-rubble"]
			blit(c, rb, templeX + 105 - (rb.get_width() >> 1), GN - 14 - rb.get_height())

	_draw_zones(c)
	_draw_plats(c)
	for co in run.coins:
		if co.tight != "log":
			coin_at(c, co)
	if run.vine > 0:
		draw_vines(c, run.vine)
	_draw_items(c)
	_draw_obstacles(c)

	if not run.dead:
		var p = run.p
		var hx = n(run.sx)
		var floor_y = n(p.plat.y) if p.plat != null else floor_px(hx)
		var M = run.mount
		var aloft: bool = M != null and (p.hang or Game.MOUNTS[M.kind].get("fly", false))
		if not in_temple or hx > DOOR_X + 8:
			var w = 26.0 if aloft else (62.0 if M != null else maxf(8, 20 - (int(floor_y - n(p.y)) >> 3)))
			shadow(c, hx - 2 + (8 if M != null and not aloft else 0), floor_y - 1, w)
		if run.gone != null:                         # the mount that just took a blow: it tumbles back, shrinks and fades
			var g = run.gone
			var k = minf(1, g.t / 0.7)
			var key: String = g.kind + ("-hang" if g.hang else "")
			var im: Texture2D = Art.tex.get("mount-" + key)
			if im != null:
				var cw = im.get_width() / float(Art.meta["mounts"][key]["frames"])
				var xf = Transform2D(0, Vector2(sx(g.x), n(g.y) - im.get_height() / 2.0 - 46 * sin(k * PI * 0.6))).rotated_local(-k * 1.4).scaled_local(Vector2(1 - 0.55 * k, 1 - 0.55 * k))
				c.draw_set_transform_matrix(xf)
				region(c, im, 0, 0, cw, im.get_height(), -cw / 2, -im.get_height() / 2.0, cw, im.get_height(), Color(1, 1, 1, 1 - k * k))
				c.draw_set_transform_matrix(Transform2D.IDENTITY)
		_mount(c)

## Tight places, for the ball only. The hollow trunk stands behind the path: its openings show what rolls
## inside. The gallery is a burrow cut into the earth under the path.
func log_windows(z, x0: float) -> Array:
	var out: Array = []
	var x = x0 + 34
	while x + LOG_WINDOW < x0 + n(z.w) - 30:
		out.append(x)
		x += LOG_WINDOW + LOG_RIB
	return out

## The trunk again, over what is inside: between the openings, and its roof.
func ribs(c: CanvasItem, z, roof: bool) -> void:
	var im: Texture2D = Art.scene[Game.biome_at(run, z.x)]["tunnel"]
	if im == null:
		return
	var x = sx(z.x)
	var y = n(Game.GROUND - Game.LOG_H) - 8
	var w = float(im.get_width())
	var h = float(im.get_height())
	if roof:
		region(c, im, 0, 0, w, LOG_ROOF, x, y, w, LOG_ROOF)
	var from_x = x
	var stops = log_windows(z, x)
	stops.append(x + w)
	for wx in stops:
		region(c, im, from_x - x, LOG_ROOF, wx - from_x, h - LOG_ROOF, from_x, y + LOG_ROOF, wx - from_x, h - LOG_ROOF)
		from_x = wx + LOG_WINDOW

func _draw_zones(c: CanvasItem) -> void:
	for z in run.zones:
		var x = sx(z.x)
		var w = n(z.w)
		var bi = Game.biome_at(run, z.x)
		var S: Dictionary = Art.scene[bi]
		if x > view_w or x + w < -10:
			continue
		if z.kind == "log":
			var y = n(Game.GROUND - Game.LOG_H)
			blit(c, S["tunnel"], x, y - 8)
			var top = y - 8 + LOG_ROOF
			var h = LOG_FLOOR - LOG_ROOF
			var hol: Array = S["hollow"]
			for wx in log_windows(z, x):             # each opening: a rounded hole with a dark rim, the far wall, the floor
				for pass_ in [[0, INK], [1, hol[0]], [2, hol[1]]]:
					var inset: float = pass_[0]
					var col: Color = pass_[1]
					rect(c, wx + inset + 3, top + inset, LOG_WINDOW - 2 * inset - 6, h - 2 * inset, col)
					rect(c, wx + inset + 1, top + inset + 1, LOG_WINDOW - 2 * inset - 2, h - 2 * inset - 2, col)
					rect(c, wx + inset, top + inset + 3, LOG_WINDOW - 2 * inset, h - 2 * inset - 6, col)
				rect(c, wx + 5, top + 2, LOG_WINDOW - 10, 5, hol[3])      # shade under the roof
				rect(c, wx + 5, top + h - 5, LOG_WINDOW - 10, 3, hol[2])  # the worn floor inside
			for co in run.coins:
				if co.tight == "log" and co.x >= z.x and co.x < z.x + z.w:
					coin_at(c, co)
			ribs(c, z, false)
		else:
			if z.im == null or z.of != bi:          # the burrow is drawn once, then kept with its zone
				var deep = roundi(Game.GALLERY / PIXEL)
				var rampw = roundi(70 / PIXEL)
				var hol: Array = S["hollow"]
				var W = ceili(w)
				var im = Art.blank(W, deep + 4)
				var k = 0
				while k < W:
					var kk = clampf(minf(float(k) / rampw, float(W - k) / rampw), 0, 1)
					var bottom = 2 + roundi(deep * kk)
					var top = maxi(1, bottom - 23)
					im.fill_rect(Rect2i(k, top - 1, 2, bottom - top + 2), INK)
					im.fill_rect(Rect2i(k, top, 2, bottom - top), hol[1])
					im.fill_rect(Rect2i(k, top, 2, 2), hol[0])
					im.fill_rect(Rect2i(k, bottom - 2, 2, 2), hol[2])
					k += 2
				z.im = Art.make(im)
				z.of = bi
			blit(c, z.im, x, GN)

func _draw_plats(c: CanvasItem) -> void:
	for pl in run.plats:
		var x = sx(pl.x)
		var y = n(pl.y)
		var w = n(pl.w)
		var S: Dictionary = Art.scene[Game.biome_at(run, pl.x)]
		var kind: String = pl.kind if pl.kind != "" else Game.PLAT_KIND[Game.biome_at(run, pl.x)]
		if x > view_w + 20 or x + w < -20:
			continue
		if kind == "slab":                           # a bridge over the hollow, the cave below in its shade
			var k = 0.0
			while k < w:
				var f = floor_px(x + k + 2)
				if f > y + 18:
					rect(c, x + k, y + 18, minf(SLICE, w - k), f - y - 18, Color(12 / 255.0, 8 / 255.0, 30 / 255.0, 0.4))
				k += SLICE
			var pillar: Texture2D = S["pillar"]
			if pillar != null:
				for px in [x + 2, x + w - pillar.get_width() - 2]:   # a pillar under each end, down to the floor
					var h = minf(pillar.get_height(), floor_px(px + pillar.get_width() / 2.0) - y - 12)
					if h > 0:
						region(c, pillar, 0, 0, pillar.get_width(), h, px, y + 14, pillar.get_width(), h)
			# both ends of the drawing are kept whole, its middle is repeated in between
			var im: Texture2D = S["slab"]
			if im == null:
				continue
			var cap = 26.0
			var mid = im.get_width() - 2 * cap
			var top: float = y - S["slab_top"]
			var ih = float(im.get_height())
			region(c, im, 0, 0, cap, ih, x, top, cap, ih)
			var kk = cap
			while kk < w - cap:
				var part_w = minf(mid, w - cap - kk)
				region(c, im, cap, 0, part_w, ih, x + kk, top, part_w, ih)
				kk += mid
			region(c, im, im.get_width() - cap, 0, cap, ih, x + w - cap, top, cap, ih)
		elif kind == "isle":
			if S["isles"].size() > 0:
				blit(c, S["isles"][pl.size], x, y - S["gtop"])
		elif kind == "walk" and Art.tex.has("walkway"):  # the dungeon: planks hanging from two chains
			var M: Dictionary = Art.meta["walkway"]
			var x0 = snap(x + w / 2 - float(M["w"]) / 2)
			var top = y - float(M["top"])
			for ch in M["chains"]:
				chain(c, x0 + ch, top + 1)
			blit(c, Art.tex["walkway"], x0, top)
		elif kind == "hover" and Art.tex.has("hover-plat"):   # the city: levitating on its thrusters
			var M: Dictionary = Art.meta["hoverplat"]
			var x0 = snap(x + w / 2 - float(M["w"]) / 2)
			var top = y - float(M["top"]) - 1
			var last = -99.0
			for j in M["jets"]:
				if j - last < 10:
					continue
				last = j
				var gx: float = x0 + j
				var gy: float = top + float(M["h"]) + 2
				glow(c, gx, gy + 3, 12, Color(90 / 255.0, 240 / 255.0, 1, 0.35 + 0.2 * sin(t * 9 + j)))
			blit(c, Art.tex["hover-plat"], x0, top)
		else:                                        # a giant lily pad flying on its own: wings beating, a blink now and then
			var im: Texture2D = Art.tex.get("lilypad")
			if im == null or not Art.meta.has("lilypad"):
				blit(c, S["platform"], x, y - S["plat_top"])
				continue
			var L: Dictionary = Art.meta["lilypad"]
			var ph: float = pl.ph
			var blink = fmod(t * 0.9 + ph, 3.4) < 0.13
			var frame = 2 if blink else floori(t * 9 + ph * 3) % 2
			var cx = x + w / 2
			var f = floor_px(cx)
			if f - y > 14:
				shadow(c, cx, f - 1, roundf(w * 0.55))
			var lw = float(L["w"])
			region(c, im, frame * lw, 0, lw, float(L["h"]), snap(cx - lw / 2), y - float(L["top"]), lw, float(L["h"]))

func coin_at(c: CanvasItem, co) -> void:
	var bob = roundf(sin(t * 5 + co.x * 0.02) * 1.5)
	var im: Texture2D = null
	if co.heart:
		im = Art.tex.get("heart")
	elif co.gem != "":
		im = Art.tex.get("gem-" + co.gem, Art.tex.get("gem"))
	if im != null:
		blit(c, im, sx(co.x) - (im.get_width() >> 1), n(co.y) - (im.get_height() >> 1) + bob)
		return
	var ct: Texture2D = Art.tex.get("coin")
	if ct == null:
		return
	var f = int(Art.meta["coin"]["frames"])
	var fw = ct.get_width() / f
	sheet(c, ct, f, floori(t * 10 + co.x * 0.01) % f, sx(co.x) - (fw >> 1), n(co.y) - (ct.get_height() >> 1) + (0.0 if f > 1 else bob))

## Mounts waiting on the path: a warm glow and a bouncing arrow say "come here", not "watch out".
func _draw_items(c: CanvasItem) -> void:
	for it in run.items:
		var x = sx(it.x)
		var f = floor_px(x)
		var im: Texture2D = Art.tex.get("mount-" + it.kind)
		if x > view_w + 80 or x < -100 or im == null:
			continue
		var bounce = roundf(absf(sin(t * 5)) * 6)
		var warm = Color(1, 224 / 255.0, 120 / 255.0, 0.42 + 0.14 * sin(t * 5))
		if it.kind == "gorilla":
			var H: Texture2D = Art.tex.get("mount-gorilla-hang")
			if H == null:
				continue
			var M: Dictionary = Art.meta["mounts"]["gorilla-hang"]
			var cw = H.get_width() / float(M["frames"])
			var top = f - n(Game.PERCH) - H.get_height()
			var left = snap(x + 12 - float(M["seatX"]))
			glow(c, x + 12, top + H.get_height() * 0.6, 60, warm)
			rect(c, snap(x + 11), -8, 4, top + 14, INK)                 # the vine it hangs from
			rect(c, snap(x + 12), -8, 2, top + 14, Color("#5d8a2c"))
			region(c, H, cw * (floori(t * 6 + it.ph) % 4), 0, cw, H.get_height(), left, top, cw, H.get_height())
			chevron(c, x + 12, top + H.get_height() + 8 + bounce, -1, Color("#ffd35c"), 6)   # an arrow under it: up there
			continue
		if it.kind == "rhino":                       # head down in the grass, nibbling
			glow(c, x + 6, f - 28, 60, warm)
			shadow(c, x + 12, f - 1, 64)
			c.draw_set_transform_matrix(Transform2D(0.06 + 0.03 * sin(t * 6 + it.ph), Vector2(x - 30, f)))
			draw_mount(c, "rhino", 1, 30, 0, 0)
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
			for k in 3:
				var up = fmod(t * 9 + k * 2.3 + it.ph, 3)
				rect(c, snap(x + 30 + k * 3), f - 3 - roundf(up * 2), 1, 3, Color("#7bd13c"))
			chevron(c, x + 6, f - im.get_height() - 6 - bounce, 1, Color("#ffd35c"), 6)
			continue
		var foot = seat_floor(it.kind, n(it.y) - 10)   # the dragonfly, zigzagging on ahead
		glow(c, x + 6, n(it.y) - 14, 60, warm)
		shadow(c, x + 6, f - 1, 30)
		draw_mount(c, it.kind, floori(t * 16) % 4, x, foot, 0)
		chevron(c, x + 6, n(it.y) - 52 - bounce, 1, Color("#ffd35c"), 6)

func _draw_obstacles(c: CanvasItem) -> void:
	for o in run.obs:
		var x = sx(o.x)
		var y = n(o.y)
		var foot = n(o.y + o.h)
		if (x > view_w + 10 and not (o.kind == "dart" and o.state == "warn")) or x < -80:
			continue                                 # a fonceur waiting off screen still shows its warning
		if o.kind == "acid":                         # the plant's acid: a glowing ball in the air, a bubbling puddle on the floor
			var w = n(o.w)
			var cx = x + w / 2
			if o.drop:                               # its shadow on the floor shows where it will land
				var f = floor_px(cx)
				var k = clampf((y + 60) / (f + 20), 0, 1)
				rect(c, snap(cx - 4 - 10 * k), f - 2, snap(8 + 20 * k), 3, Color(20 / 255.0, 40 / 255.0, 6 / 255.0, 0.25 + 0.4 * k))
				rect(c, snap(cx - 2 - 6 * k), f - 1, snap(4 + 12 * k), 1, Color(168 / 255.0, 1, 60 / 255.0, 0.2 + 0.4 * k))
			if o.puddle:
				c.draw_texture_rect(Art.radial, Rect2(x - w * 0.2, foot - 30, w * 1.4, 34), false, Color(168 / 255.0, 1, 60 / 255.0, 0.35 + 0.15 * sin(t * 6 + o.x)))
				rect(c, x + 4, foot - 11, w - 8, 12, INK)
				rect(c, x, foot - 8, w, 9, INK)
				rect(c, x + 5, foot - 10, w - 10, 10, Color("#5cd23c"))
				rect(c, x + 1, foot - 7, w - 2, 7, Color("#5cd23c"))
				rect(c, x + 7, foot - 10, w - 14, 3, Color("#a8ff3c"))
				rect(c, x + 10, foot - 10, w - 20, 1, Color("#e8ffb0"))
				for k in 4:
					var up = fmod(t * 2.5 + k * 0.29 + o.x * 0.01, 1.0)
					rect(c, snap(x + 8 + k * (w - 16) / 3), foot - 12 - roundf(up * 12), 3, 3, Color("#e8ffb0", 1 - up))
			else:
				var r = w / 2
				var cy = y + r
				glow(c, cx, cy, r + 6, Color("#8cf03c", 0.6))
				c.draw_circle(Vector2(cx, cy), r + 1, INK)
				c.draw_circle(Vector2(cx, cy), r, Color("#2f9a2a"))
				c.draw_circle(Vector2(cx - 1, cy - 1), r * 0.72, Color("#8cf03c"))
				c.draw_circle(Vector2(cx - 2, cy - 2), r * 0.32, Color("#f4ffc8"))
				for k in range(1, 4):                # dripping trail
					rect(c, snap(cx + k * 6), snap(cy - 1 + sin(t * 20 + k) * 2), 3, 3, Color(168 / 255.0, 1, 60 / 255.0, 0.5))
			continue
		if not ROLE.has(o.kind):
			continue
		var name: String = ROLE[o.kind][o.biome]
		if o.kind == "hover" and o.biome == 0:
			name = "spider-mid" if o.mid else "spider-low"
		if not Art.haz.has(name):
			continue
		var H: Dictionary = Art.haz[name]
		var im: Texture2D = H["ghost"] if o.ghost else H["tex"]
		var pad = 1 if o.ghost else int(H["pad"])
		var frames = int(H["frames"])
		var fw = im.get_width() / float(frames)
		var cx = x + n(o.w) / 2
		var cy = y + n(o.h) / 2
		var mod = Color(1, 1, 1, 0.78 + 0.1 * sin(t * 6 + o.x)) if o.ghost else Color.WHITE
		if o.kind == "spiky":                        # on the floor
			var shut = name == "beartrap" and absf(cx - n(run.sx)) < 30    # the trap snaps as he goes over it
			var hop = -1.0 if (name == "spiky" and sin(t * 6 + o.x) > 0.6) else 0.0
			shadow(c, cx, foot - 1, fw - 2 * pad)
			sheet(c, im, frames, 1 if shut else 0, snap(cx - fw / 2), foot - im.get_height() + pad + hop, mod)
			if name == "spikebot" and sin(t * 8 + o.x) > 0:   # its eye, blinking
				glow(c, cx, foot - im.get_height() + 3, 9, Color(90 / 255.0, 240 / 255.0, 1, 0.8))
		elif o.kind == "dart":                       # a "!" at the edge, at its height; then across in one go
			if o.state == "warn":
				warn_mark(c, roundf(view_w * 0.64) if shift else view_w - 20, cy, o.t)
			elif o.state == "go":
				var frame = floori(t * (14 if name == "fly" else 9) + o.ph) % frames if frames > 1 else 0
				var x0 = snap(cx - fw / 2)
				for k in 3:                          # the wind it leaves behind
					rect(c, x0 + fw - 4 + k * 6, snap(cy - 6 + k * 6), 14 + k * 4, 1, Color(1, 1, 1, 0.45))
				if name == "missile":
					rect(c, x0 + fw - 2, snap(cy - 2), 4 + roundf(randf() * 4), 4, Color("#ffd35c") if floori(t * 30) % 2 == 1 else Color("#ff7a2a"))
				sheet(c, im, frames, frame, x0, snap(cy - im.get_height() / 2.0), mod)
		else:                                        # hanging still in mid-air, alive all the same
			var bob = sin(t * 3 + o.ph) * 2
			var top = snap(cy - im.get_height() / 2.0 + bob)
			var frame = 0
			if name.begins_with("spider"):
				rect(c, snap(cx), -8, 1, top + 10, Color(235 / 255.0, 240 / 255.0, 1, 0.8))
				frame = floori(t * 3 + o.ph) % 2
			if name == "bat":
				frame = 1 + (floori(t * 12 + o.ph) & 1)
			if name == "idol":                       # the glow of its eyes and runes
				glow(c, cx, top + im.get_height() * 0.4, 20, Color(1, 150 / 255.0, 40 / 255.0, 0.35 + 0.15 * sin(t * 4 + o.ph)))
			var fl = floor_px(cx)
			shadow(c, cx, fl - 1, maxf(8, 20 - (int(fl - top) >> 4)))
			sheet(c, im, frames, frame, snap(cx - fw / 2), top, mod)
			if name == "drone":
				var w = 6 + roundf(absf(sin(t * 40)) * 5)
				rect(c, snap(cx - fw / 2 + 2), top + 1, w, 1, Color(220 / 255.0, 240 / 255.0, 1, 0.5))
				rect(c, snap(cx + fw / 2 - 2 - w), top + 1, w, 1, Color(220 / 255.0, 240 / 255.0, 1, 0.5))
		if o.ghost:                                  # tipsy and harmless: hiccuping bubbles
			for k in 3:
				var up = fmod(t * 14 + k * 9 + o.x, 22)
				rect(c, snap(cx - 8 + k * 7 + sin(up * 0.6 + k) * 2), y - 2 - up, 2, 2, Color("#eafcff", 0.7 * (1 - up / 22)))

# ---------- in front of the hero ----------

func _draw_front(c: CanvasItem) -> void:
	if run == null or not Art.ready:
		return
	var cam = run.cam / PIXEL
	if run.p.ball != null and run.p.ball.kind == "log" and not run.dead:
		ribs(c, run.p.ball, true)                    # he rolls inside the trunk, not in front of it
	_draw_swarm(c)
	for qp in run.parts:
		if qp.shard >= 0:                            # a quarter of the smashed scenery's own picture, spinning
			var im: Texture2D = Art.decor[qp.biome]
			if im == null:
				continue
			var hw = im.get_width() / 2.0
			var hh = im.get_height() / 2.0
			c.draw_set_transform_matrix(Transform2D(qp.rot, Vector2(sx(qp.x), n(qp.y))))
			region(c, im, (qp.shard % 2) * hw, (qp.shard >> 1) * hh, hw, hh, -hw / 2, -hh / 2, hw, hh, Color(1, 1, 1, minf(1, 3 * (1 - qp.life / qp.span))))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
			continue
		var col: Color = qp.c
		col.a = clampf(1 - qp.life / qp.span, 0, 1)
		var s = maxf(1, roundf(qp.s / PIXEL))
		rect(c, sx(qp.x), n(qp.y), s, s, col)
	var mk: Texture2D = Art.tex.get("monkey")
	if mk != null:
		for m in run.monkeys:                        # up in the vines at the top of the frame; they wave once greeted
			var fw = mk.get_width() / 2.0
			var greeted: bool = m.seen >= 0 and run.t - m.seen < 2.5
			var frame = floori(t * (7 if greeted else 1.6) + m.ph) % 2
			region(c, mk, frame * fw, 0, fw, mk.get_height(), sx(m.x) - floorf(fw / 2), (-2 + (3 if frame == 1 else 0)) if greeted else -2.0, fw, mk.get_height())
	# closest layer: weather, then the leaves along the bottom and top edges. The faster the run, the
	# fainter these leaves: they race past the eye and would hide what is coming.
	Ambient.draw_weather(c, cam, t, view_w)
	var fast = clampf((run.speed - 480) / 380, 0, 1)
	var mod = Color(1, 1, 1, 1 - 0.7 * fast)
	var edge = snap(run.biome_x / PIXEL - cam)
	if run.prev_biome != run.biome and edge > 0 and edge < view_w:
		edges(c, Art.scene[run.prev_biome]["fore"], Rect2(0, -8, edge, VH + 16), mod)
		edges(c, Art.scene[run.biome]["fore"], Rect2(edge, -8, view_w - edge, VH + 16), mod)
	else:
		var S: Dictionary = Art.scene[run.prev_biome] if edge >= view_w else Art.scene[run.biome]
		edges(c, S["fore"], Rect2(0, -8, view_w, VH + 16), mod)

func edges(c: CanvasItem, F: Dictionary, clip: Rect2, mod: Color) -> void:
	var cam = run.cam / PIXEL
	var lay = func(im: Texture2D, par: float, y: float) -> void:
		var off = cam * par
		var w = float(im.get_width())
		var i = floori((off + clip.position.x) / w)
		while i * w - off < clip.end.x:
			region_clip(c, im, Rect2(0, 0, w, im.get_height()), Rect2(snap(i * w - off), y, w, im.get_height()), clip, false, mod)
			i += 1
	lay.call(F["high"][0], 1.1, -3)
	lay.call(F["low"][0], 1.15, VH - F["low"][0].get_height() + 2)
	lay.call(F["high"][1], 1.45, -5)
	lay.call(F["low"][1], 1.6, VH - F["low"][1].get_height() + 3)

## The follower monsters: one per lane taken, a flashing band along each of those lanes, then the rush;
## in the city, drones that stay put and fire a laser along their lanes.
func _draw_swarm(c: CanvasItem) -> void:
	var f = run.fm
	if f == null:
		return
	var name: String = ROLE["swarm"][f.biome]
	var H = Art.haz.get(name)
	var cx = n(f.sx)
	var aiming: bool = f.phase == "aim"
	var step = n(Game.FM_STEP)
	var pulse = pow(sin(t * 12), 2)
	for k in f.act.size():
		if not f.act[k] or cx < -60:
			continue
		var top = GN - (k + 1) * step
		var cy = top + step / 2
		if aiming and f.t > 0.3 and not f.ghost:     # a band that fades in from the left, runs under them, and fades out behind
			var end = cx + 40
			var a = 0.12 + 0.1 * pulse
			var red0 = Color(1, 70 / 255.0, 70 / 255.0, 0)
			var red = Color(1, 70 / 255.0, 70 / 255.0, a)
			var s2 = maxf(0.5, 1 - 60 / end) * end
			hgrad(c, 0, end * 0.5, top + 3, step - 6, red0, red)
			hgrad(c, end * 0.5, s2, top + 3, step - 6, red, red)
			hgrad(c, s2, end, top + 3, step - 6, red, red0)
			var x = -fmod(t * 60, 16)
			while x < end:
				var fade = clampf(minf(x / (end * 0.5), (end - x) / 60), 0, 1)
				var col = Color(1, 96 / 255.0, 96 / 255.0, (0.55 + 0.35 * pulse) * fade)
				rect(c, snap(x), top + 3, 9, 2, col)
				rect(c, snap(x), top + step - 5, 9, 2, col)
				x += 16
		if f.phase == "fire" and not f.ghost:        # the laser: a flicker while it charges, then the beam
			var h = n(Game.LASER_H)
			var x1 = cx - 18
			if f.t < Game.LASER_ON:
				if floori(t * 40) % 2 == 1:
					rect(c, 0, snap(cy), x1, 1, Color(1, 90 / 255.0, 120 / 255.0, 0.8))
			elif f.t < Game.LASER_END:
				var k2: float = 1.0 if f.t < Game.LASER_OFF else 1 - (f.t - Game.LASER_OFF) / (Game.LASER_END - Game.LASER_OFF)
				var hh = h * k2
				rect(c, 0, snap(cy - hh / 2 - 2), x1, hh + 4, Color(1, 40 / 255.0, 90 / 255.0, 0.45 * k2))
				rect(c, 0, snap(cy - hh / 4), x1, hh / 2, Color(1, 140 / 255.0, 170 / 255.0, 0.9 * k2))
				rect(c, 0, snap(cy - 1), x1, 2, Color(1, 1, 1, k2))
		var alpha = 0.78 if f.ghost else 1.0
		var jx = sin(t * 9 + k * 2.1) * 2.5
		var jy = cos(t * 11 + k * 1.7) * 2.5
		if name == "wisp" or H == null:              # a will-o'-the-wisp: a flame of pale light
			var r = 9 + sin(t * 9 + k) * 1.5
			glow(c, cx + jx, cy + jy, r * 2, Color(120 / 255.0, 1, 220 / 255.0, 0.85 * alpha))
			glow(c, cx + jx, cy + jy, r, Color(230 / 255.0, 1, 250 / 255.0, 0.95 * alpha))
			rect(c, snap(cx + jx - 4), snap(cy + jy - 2), 2, 3, INK)    # two dark eyes
			rect(c, snap(cx + jx + 2), snap(cy + jy - 2), 2, 3, INK)
		else:
			var im: Texture2D = H["ghost"] if f.ghost else H["tex"]
			var frames = int(H["frames"])
			var fw = im.get_width() / float(frames)
			var frame = 0
			if frames > 1:
				frame = [0, 1, 2, 1][floori(t * 22 + k) % 4] if aiming else (3 if floori(t * 24 + k) % 2 == 1 else 1)
			var still = 0.4 if name == "drone-big" else 1.0
			sheet(c, im, frames, frame, snap(cx + jx * still - fw / 2), snap(cy + jy * still - im.get_height() / 2.0), Color(1, 1, 1, alpha))
			if name == "wasp":
				rect(c, snap(cx + jx - 4), snap(cy + jy - im.get_height() / 2.0 - 2 + (floori(t * 30) % 2) * 2), 10, 2, Color(235 / 255.0, 245 / 255.0, 1, 0.55 * alpha))

# ---------- full screen, never shaken ----------

func _draw_over(c: CanvasItem) -> void:
	if run == null:
		return
	if run.boom > 0:
		rect(c, 0, 0, view_w, VH, Color(1, 244 / 255.0, 214 / 255.0, run.boom * 0.8))
	if run.flash > 0:
		rect(c, 0, 0, view_w, VH, Color(1, 70 / 255.0, 90 / 255.0, run.flash * 0.3))
	if run.slow.t > 0:                               # the Sablier: the world tinted blue; in its last seconds the tint
		var left = run.slow.t                       # blinks faster and faster, the edges flash and a count rises over him
		var u = Game.SLOW_WARN - left
		var on = left > Game.SLOW_WARN or floori(2 * (3 * u + 3 * u * u)) % 2 == 0
		rect(c, 0, 0, view_w, VH, Color(120 / 255.0, 200 / 255.0, 1, 0.16 if on else 0.05))
		if left <= Game.SLOW_WARN:
			if on:
				var pale = Color(214 / 255.0, 244 / 255.0, 1, 0.85)
				rect(c, 0, 0, view_w, 3, pale)
				rect(c, 0, VH - 3, view_w, 3, pale)
				rect(c, 0, 0, 3, VH, pale)
				rect(c, view_w - 3, 0, 3, VH, pale)
			draw_digit(c, ceili(left), n(run.sx), n(run.p.y) - 64, 3)
	if run.glitch > 0:                               # time tear
		var g = run.glitch
		rect(c, 0, 0, view_w, VH, Color(1, 1, 1, g * 0.45))
		for k in 6:
			rect(c, 0, roundf(randf() * VH), view_w, 1 + roundf(randf() * 6), Color(92 / 255.0, 242 / 255.0, 224 / 255.0, g * 0.5))
