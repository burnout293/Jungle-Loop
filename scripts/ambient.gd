class_name Ambient
extends RefCounted
## Life in the scenery: birds, butterflies, small animals, falling leaves, gusts of wind, rain, pebbles
## dropping from the ruins (port of js/ambient.js). None of it touches the game rules — it is drawn,
## nothing more — and it runs behind the menus as well as during a run. Coordinates are art pixels.

const GN := 280.0
const VH := 320.0
const WINGS := ["#ff9d3c", "#5ce0f2", "#ff6fa8", "#f6e65a", "#c58cff"]
const LEAVES := ["#8fd14a", "#c9e86a", "#e8c84a", "#5fae3a"]
const INK := Color("#1a1024")

class Stone:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.0
	var hops := 0

# The little that has to be remembered from one frame to the next.
static var last_t := 0.0
static var wind := 0.0
static var stones: Array = []
static var next_stone := 4.0
static var floor_y := Callable()                                     # floor height at a screen x, given by the renderer
static var q := 1.0                                                  # drawing steps per art pixel, set by the renderer
static var lite := false                                             # the Éco quality: fewer little creatures, less weather

static func fy(x: float) -> float:
	return floor_y.call(x) if floor_y.is_valid() else GN

static func snap(v: float) -> float:
	return roundf(v * q) / q

static func h01(i: float, s: float) -> float:
	var x = sin(i * 127.1 + s * 311.7) * 43758.5453
	return x - floor(x)

static func ramp(x: float, a: float, b: float) -> float:
	return clampf((x - a) / (b - a), 0, 1)

## Weather, as plain functions of time. A gust rises about every 14 seconds; a shower lasts half a
## minute out of every minute and a half.
static func gust(t: float) -> float:
	return pow(maxf(0, sin(t * 0.45)), 8)

static func rain(t: float) -> float:
	var c = fposmod(t, 90.0)
	return ramp(c, 48, 54) * (1 - ramp(c, 74, 80))

static func rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), col)

static func tick(t: float, cam: float, w: float) -> void:
	var dt = clampf(t - last_t, 0, 0.1)
	last_t = t
	wind += dt * (14 + 80 * gust(t))                 # how far the air has travelled: leaves ride on it
	if t > next_stone:                               # a few pebbles come loose somewhere ahead
		next_stone = t + 7 + randf() * 8
		var x = cam + w * (0.25 + randf() * 0.7)
		var y: float = fy(x - cam) - 170 + randf() * 60
		for k in 3:
			var st = Stone.new()
			st.x = x + k * 5 - 5
			st.y = y - k * 7
			st.vx = (randf() - 0.5) * 16
			stones.append(st)
	for s in stones:
		s.life += dt
		s.vy += 420 * dt
		s.x += s.vx * dt
		s.y += s.vy * dt
		var f: float = fy(s.x - cam)
		if s.y > f - 3 and s.vy > 0:
			s.y = f - 3
			s.vy *= -0.35
			s.hops += 1
	stones = stones.filter(func(s): return s.hops < 3 and s.life < 4)

# ---------- far away: birds crossing the sky ----------
static func draw_sky(c: CanvasItem, t: float, w: float) -> void:
	var cols = [Color("#f2f8ff"), Color("#3a4a6e"), Color("#2a3350")]
	for f in 3:
		var span = w + 300 + f * 140
		var x0 = w + 40 - fposmod(t * (9 + f * 5) + f * 190, span)
		var y0 = 34 + f * 24 + sin(t * 0.3 + f) * 6
		var col: Color = cols[f]
		for j in 3 + f:
			var x = roundf(x0 + j * 9)
			var y = roundf(y0 + absf(j - 1) * 4 + sin(t * 2 + j))
			var up = -1 if floori(t * 5 + j * 0.7) % 2 == 1 else 1       # wings up, wings down
			rect(c, x, y, 2, 1, col)
			var wy = y + (-1 if up < 0 else 0)
			rect(c, x - 2, wy, 2, 1, col)
			rect(c, x + 2, wy, 2, 1, col)
			var ty = y + up * (2 if up < 0 else 1)
			rect(c, x - 3, ty, 1, 1, col)
			rect(c, x + 4, ty, 1, 1, col)

# ---------- on and above the floor, behind the action ----------
static func butterflies(c: CanvasItem, cam: float, t: float, w: float) -> void:
	var span = w + 60
	for i in 6:
		var x = snap(fposmod(h01(i, 13) * span - cam * 0.9 + t * (h01(i, 17) - 0.5) * 12 + sin(t * 0.9 + i * 2) * 14, span)) - 30
		var y = roundf(fy(x) - 26 - h01(i, 19) * 70 + sin(t * 1.3 + i) * 9 + sin(t * 3.1 + i * 4) * 3)
		var col = Color(WINGS[i % WINGS.size()])
		if floori(t * 9 + i) % 2 == 1:
			rect(c, x - 2, y - 1, 2, 3, col)
			rect(c, x + 1, y - 1, 2, 3, col)
		else:
			rect(c, x - 1, y - 2, 1, 3, col)
			rect(c, x + 1, y - 2, 1, 3, col)
		rect(c, x, y - 1, 1, 3, INK)

## Small animals pottering about on the moss. Each has a home spot in the world and strolls around it.
static func critters(c: CanvasItem, cam: float, t: float, w: float) -> void:
	var CELL = 230.0
	var first = floori(cam / CELL) - 1
	var last = floori((cam + w) / CELL) + 1
	for i in range(maxi(1, first), last + 1):
		if h01(i, 71) < 0.4:
			continue
		var walk = sin(t * 0.4 + i * 3) * 36
		var dir = 1 if cos(t * 0.4 + i * 3) > 0 else -1
		var x = snap(i * CELL + 60 + walk - cam)
		var step = floori(t * 8 + i) % 2
		if h01(i, 73) < 0.5:                         # a scarab with a shiny shell
			var y: float = fy(x) - 6
			rect(c, x - 1, y, 8, 4, INK)
			rect(c, x, y, 5, 3, Color("#23b39a"))
			rect(c, x + 1, y, 2, 1, Color("#a8fff0"))
			rect(c, x + 5 if dir > 0 else x - 1, y + 1, 2, 2, INK)
			rect(c, x + step, y + 4, 1, 1, INK)
			rect(c, x + 2 + step, y + 4, 1, 1, INK)
			rect(c, x + 4 + step, y + 4, 1, 1, INK)
		else:                                        # a small bird hopping along
			var y: float = fy(x) - 9 - (1 if step == 1 else 0)
			rect(c, x - 1, y - 1, 8, 7, INK)
			rect(c, x, y, 6, 5, Color("#ffb347"))
			rect(c, x + 1, y + 3, 4, 2, Color("#fff3c4"))
			rect(c, x + 4 if dir > 0 else x + 1, y + 1, 1, 1, INK)
			rect(c, x + 6 if dir > 0 else x - 2, y + 2, 2, 1, Color("#e0456b"))
			rect(c, x + 1 + step, y + 6, 1, 2, INK)
			rect(c, x + 4 - step, y + 6, 1, 2, INK)

static func fireflies(c: CanvasItem, cam: float, t: float, w: float) -> void:
	var span = w + 40
	for i in 14:
		var x = snap(fposmod(h01(i, 3) * span - cam * 0.7 + t * (3 + h01(i, 5) * 6), span)) - 20
		var y = roundf(50 + h01(i, 7) * 190 + sin(t * 0.8 + i * 2.1) * 9)
		var glow = pow(sin(t * 1.7 + i * 1.3), 2)
		rect(c, x - 1, y - 1, 3, 3, Color(0.85, 1, 0.48, glow * 0.22))
		rect(c, x, y, 1, 1, Color(0.965, 1, 0.77, 0.35 + glow * 0.65))

static func draw_life(c: CanvasItem, cam: float, t: float, w: float, floor_fn: Callable) -> void:
	floor_y = floor_fn
	tick(t, cam, w)
	if not lite:
		fireflies(c, cam, t, w)
	for s in stones:
		var x = snap(s.x - cam)
		var y = roundf(s.y)
		rect(c, x - 1, y - 1, 4, 4, INK)
		rect(c, x, y, 2, 2, Color("#9aa0b8"))
		if s.hops > 0 and s.life < 4:
			var dust = Color(0.91, 0.894, 0.83, 0.5)
			rect(c, x - 3, y + 1, 2, 1, dust)
			rect(c, x + 3, y, 2, 1, dust)
	if not lite:
		critters(c, cam, t, w)
		butterflies(c, cam, t, w)

# ---------- in front of everything: leaves on the wind, gusts, rain ----------
static func draw_weather(c: CanvasItem, cam: float, t: float, w: float) -> void:
	var g = gust(t)
	var r = rain(t)
	var span = w + 40
	for i in (6 if lite else 18):
		var x = snap(fposmod(h01(i, 23) * span - wind * (0.6 + h01(i, 29)) - cam * 1.1, span) + sin(t * 2 + i) * 4) - 20
		var y = roundf(fposmod(h01(i, 31) * (GN + 10) + t * (9 + h01(i, 37) * 9), GN + 10))
		var col = Color(LEAVES[i % LEAVES.size()])
		if floori(t * 4 + i) % 2 == 1:
			rect(c, x, y, 2, 1, col)
		else:
			rect(c, x, y, 1, 2, col)
	if g > 0.04:                                     # the gust itself: a few pale streaks racing by
		var col = Color(1, 1, 1, g * 0.4)
		for i in 7:
			var ln = 14 + roundf(h01(i, 41) * 24)
			var x = roundf(fposmod(h01(i, 43) * (span + 200) - wind * 5, span + 200)) - 60
			var y = roundf(40 + h01(i, 47) * 210 + sin(x * 0.03 + i) * 4)
			rect(c, x, y, ln, 1, col)
			rect(c, x - 3, y + 1, 4, 1, col)
	if r > 0:
		rect(c, 0, 0, w, VH, Color(22 / 255.0, 36 / 255.0, 78 / 255.0, 0.26 * r))   # the light drops under the clouds
		var col = Color(205 / 255.0, 228 / 255.0, 1, 0.6)
		var H = VH + 20
		var n = roundi((40 if lite else 110) * r)
		for i in n:
			var qy = fposmod(h01(i, 53) * H + t * (380 + h01(i, 59) * 140), H)
			var x = roundf(fposmod(h01(i, 61) * (w + 90) - qy * 0.28 - cam * 0.4, w + 90)) - 10
			if qy > GN - 5 and h01(i, 67) > 0.4:
				rect(c, x - 1, GN - 4, 1, 1, col)
				rect(c, x + 1, GN - 5, 1, 1, col)
				rect(c, x + 3, GN - 4, 1, 1, col)
			else:
				rect(c, x, roundf(qy), 1, 3, col)
				rect(c, x - 1, roundf(qy) + 3, 1, 2, col)

## Draws a picture in thin horizontal bands, the top ones pushed sideways by the wind: the plant bends
## from its foot instead of sliding as a block.
static func sway_blit(c: CanvasItem, im: Texture2D, x: float, y: float, flip: bool, t: float, seed: float, amp: float, band: int = 4, mod: Color = Color.WHITE) -> void:
	var k = amp * (1 + 2.5 * gust(t))
	var w = im.get_width()
	var h = im.get_height()
	# bands pushed alike are drawn together: near the foot, where the push is nil, in one go
	var b = 0
	var top = 0
	var push = INF
	while b <= h:
		var dx = roundf(sin(t * 1.7 + seed + b * 0.06) * k * pow(1.0 - float(b) / h, 1.5)) if b < h else INF
		if dx != push:
			if b > top:
				c.draw_texture_rect_region(im, Rect2(x + push, y + top, -w if flip else w, b - top), Rect2(0, top, w, b - top), mod)
			top = b
			push = dx
		if b == h:
			break
		b = mini(b + band, h)
