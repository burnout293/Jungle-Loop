class_name Art
extends RefCounted
## The pictures: loaded from assets/img, and everything made from them once (the loading half of
## js/render.js). Every size here is in art pixels. The work is done on Image objects with Godot's own
## operations (blit, blend, fill, adjust_bcs), the few per-pixel loops only on small sprites.

const DIR := "res://assets/img/"
const EARTH := 24                    # rows of a ground piece reused as plain earth below it
const FORE_W := 640
const LOG_CUT := 12
const DARK := Color("#0d0614")
const RED := Color("#ff3b4e")
const OUTLINE := Color("#1a1024")

# Each scenery has its own far background, middle distance, floor, props, and its own version of
# everything that is built in it. `shade`: the colour of the leaves along the frame's edges ("" : the
# jungle's own); `hollow`: the colours inside a pipe (rim, far wall, floor, shade under the roof).
const BIOMES := [
	{"id": "jungle", "name": "Jungle mystique", "bg": "bg-far", "mid": "mid", "grounds": ["ground-0", "ground-1", "ground-2"], "prop": "prop-", "props": 9, "shade": "",
		"platform": "platform", "pillar": "pillar", "crate": "crate", "slab": "slab", "tunnel": "log", "plat_top": 13, "slab_top": 5, "hollow": ["#3b2014", "#24120f", "#4d2d1a", "#160b0c"]},
	{"id": "ruins", "name": "Ruines oubliées", "bg": "ruins-bg", "mid": "ruins-mid", "grounds": ["ruins-ground"], "prop": "ruins-prop-", "props": 4, "shade": "#3b2331",
		"platform": "ruins-platform", "pillar": "ruins-pillar", "crate": "ruins-crate", "slab": "ruins-slab", "tunnel": "ruins-tunnel", "plat_top": 2, "slab_top": 5, "hollow": ["#6b3a22", "#2c1611", "#8a5632", "#1c0e0b"]},
	{"id": "city", "name": "Cité du futur", "bg": "city-bg", "mid": "city-mid", "grounds": ["city-ground"], "prop": "city-prop-", "props": 4, "shade": "#120c2c",
		"platform": "city-platform", "pillar": "city-pillar", "crate": "city-crate", "slab": "city-slab", "tunnel": "city-tunnel", "plat_top": 2, "slab_top": 2, "hollow": ["#2c2152", "#0f0a22", "#3fd9e6", "#080514"]},
	{"id": "dungeon", "name": "Donjon sans fin", "bg": "dungeon-bg", "mid": "dungeon-mid", "grounds": ["dungeon-ground"], "prop": "dungeon-prop-", "props": 4, "shade": "#0b0b1c",
		"platform": "dungeon-platform", "pillar": "dungeon-pillar", "crate": "dungeon-crate", "slab": "dungeon-slab", "tunnel": "dungeon-tunnel", "plat_top": 2, "slab_top": 2, "hollow": ["#4a3026", "#140d0d", "#5c4636", "#0a0707"]},
]

const NAMES := ["temple", "temple-mid", "temple-front", "temple-rubble", "vorace-legs", "vorace-head", "vorace-body", "vorace-log", "crate-big", "lilypad", "walkway", "hover-plat", "vine-garland", "vine-hang",
	"spikebot", "spider-low", "spider-mid", "bat", "thornball", "beartrap", "vulture", "arrow", "missile", "idol", "drone", "wasp", "drone-big",
	"hero-body", "hero-ball", "hero-rotor", "hero-fist", "hero-shoe", "mount-gorilla", "mount-gorilla-hang", "mount-rhino", "mount-dragonfly",
	"mosquito", "fly", "spiky", "coin", "gem", "gem-y", "gem-r", "gem-b", "heart", "monkey", "coin-icon",
	"guard-spear", "guard-club", "pick-feather", "pick-urn", "pick-shield", "pick-knife", "isle-forest-1", "isle-forest-2"]

# Frames of each danger's sheet.
const HAZ_FRAMES := {"spiky": 1, "thornball": 1, "beartrap": 2, "spikebot": 1, "fly": 4, "vulture": 2, "arrow": 1, "missile": 1, "spider-low": 2, "spider-mid": 2,
	"idol": 1, "bat": 3, "drone": 1, "mosquito": 4, "wasp": 1, "drone-big": 1}

static var img := {}          # name -> Image, as loaded (RGBA8)
static var tex := {}          # name -> Texture2D
static var hi := {}           # the hero's pieces, four times finer with their stair-steps rounded off
static var meta := {}
static var scene: Array = []  # per scenery, what is ready to draw (see build_scene)
static var haz := {}          # what hurts, outlined so it stands out, and its harmless ghost
static var decor: Array = []  # per scenery, the picture of what can be smashed
static var hangs: Texture2D   # the hanging lianas of the scenery, a little darker
static var radial: Texture2D  # a white disc fading out: every glow is this, tinted
static var signs := {}
static var hills := {}
# What stands behind the path, per scenery (0.43, PixelLab, tools/prep_hills.py): the forest's mossy rocks
# and arched roots, the ruins' broken walls of square stones, the dungeon's walls with a wooden door or iron
# bars, the city's buildings and containers. A little darker than what can be touched.
const HILL_SETS := [["hill-forest-1", "hill-forest-2", "hill-forest-3", "hill-forest-4", "hill-forest-5", "hill-forest-6"], ["hill-ruins-1", "hill-ruins-2"], ["hill-city-1", "hill-city-2"], []]   # (the dungeon: none since 0.44)
static var hill_sets: Array = []
static var hill_order: Array = []
static var ready := false
static var look := 5          # how the dangers stand out: 5 = lit edge in a dark outline, scenery darker
static var rim_on := false    # the red outline around everything that hurts (a setting)

static func h01(i: float, s: float) -> float:
	var x = sin(i * 127.1 + s * 311.7) * 43758.5453
	return x - floor(x)

static func make(im: Image) -> ImageTexture:
	return ImageTexture.create_from_image(im)

static func blank(w: int, h: int) -> Image:
	return Image.create_empty(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)

static func solid(w: int, h: int, c: Color) -> Image:
	var im = blank(w, h)
	im.fill(c)
	return im

static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

# ---------- loading ----------

static func load_one(name: String) -> void:
	var path = DIR + name + ".png"
	if not ResourceLoader.exists(path):
		return                                       # a missing image is skipped, not fatal
	var t: Texture2D = load(path)
	if t == null:
		return
	var im = t.get_image()
	if im == null:
		return
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	img[name] = im
	tex[name] = t

static func load_all() -> void:
	var raw = FileAccess.get_file_as_string(DIR + "meta.json")
	var parsed = JSON.parse_string(raw) if raw != "" else null
	meta = parsed if parsed is Dictionary else {}
	if not meta.has("coin"):
		meta["coin"] = {"frames": 1}
	if not meta.has("fly"):
		meta["fly"] = {"frames": 1}
	if not meta.has("mosquito"):
		meta["mosquito"] = {"frames": 4}
	var names: Array = NAMES.duplicate()
	for b in BIOMES:
		names.append_array([b["bg"], b["mid"], b["platform"], b["pillar"], b["crate"], b["slab"], b["tunnel"]])
		names.append_array(b["grounds"])
		for i in b["props"]:
			names.append(b["prop"] + str(i))
	for set_ in HILL_SETS:
		names.append_array(set_)
	for n in names:
		load_one(n)
	hill_sets = []
	for set_ in HILL_SETS:
		var pics: Array = []
		for n in set_:
			if img.has(n):
				pics.append(make(tinted(img[n], rgba(14, 8, 26, 0.38))))
		hill_sets.append(pics)
	radial = make(disc_image(64))
	scene = []
	for b in BIOMES:
		scene.append(build_scene(b))
	build_haz()
	# the forest's big crate, the ruins' jar, the city's crates, the dungeon's barrel: a little darker
	decor = []
	for n in ["crate-big", "ruins-prop-1", "city-prop-3", "dungeon-prop-1"]:
		decor.append(make(tinted(img[n], rgba(14, 8, 26, 0.26))) if img.has(n) else null)
	# the hero's pieces, redrawn four times finer with their stair-steps rounded off
	var dim = rgba(16, 12, 40, 0.38)
	for k in ["hero-body", "hero-rotor", "hero-fist", "hero-shoe", "hero-ball"]:
		if img.has(k):
			hi[k] = make(rounded(rounded(img[k])))
	for k in ["fist", "shoe"]:                       # the far fist and shoe, in the shade of his body
		if img.has("hero-" + k):
			tex["far-" + k] = make(tinted(img["hero-" + k], dim))
			hi["far-" + k] = make(tinted(rounded(rounded(img["hero-" + k])), dim))
	if img.has("vine-hang"):
		hangs = make(tinted(img["vine-hang"], rgba(12, 10, 30, 0.32)))
	ready = true

## A white disc whose alpha fades from 1 at the centre to 0 at the rim: glows are this, tinted.
static func disc_image(size: int) -> Image:
	var im = blank(size, size)
	var r = size / 2.0
	for y in size:
		for x in size:
			var d = Vector2(x + 0.5 - r, y + 0.5 - r).length() / r
			if d < 1:
				im.set_pixel(x, y, Color(1, 1, 1, 1.0 - d))
	return im

# ---------- what is made from the pictures ----------

static func mirrored(im: Image) -> Image:
	var c = im.duplicate()
	c.flip_x()
	return c

## A copy of an image with a veil of colour over its own pixels (canvas "source-atop"). A dark veil
## pushes scenery back, a pale one makes the ghost of a creature.
static func tinted(im: Image, colour: Color) -> Image:
	if im == null:
		return null
	var w = im.get_width()
	var h = im.get_height()
	var out: Image = im.duplicate()
	out.blend_rect_mask(solid(w, h, colour), im, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out

## A copy of a sprite sheet with a line all around each frame (frames become 2 pixels larger).
static func rim(im: Image, frames: int, colour: Color) -> Image:
	if im == null:
		return null
	var fw = im.get_width() / frames
	var h = im.get_height()
	var out = blank((fw + 2) * frames, h + 2)
	var fill = solid(fw + 2, h + 2, colour)
	for f in frames:
		var src = Rect2i(f * fw, 0, fw, h)
		var spread = blank(fw + 2, h + 2)
		for o in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
			spread.blend_rect(im, src, o)
		var one = blank(fw + 2, h + 2)
		one.blend_rect_mask(fill, spread, Rect2i(0, 0, fw + 2, h + 2), Vector2i.ZERO)
		one.blend_rect(im, src, Vector2i(1, 1))
		out.blit_rect(one, Rect2i(0, 0, fw + 2, h + 2), Vector2i(f * (fw + 2), 0))
	return out

## A sprite sheet with its top-left edges lit and a dark outline round it (frames 2 pixels larger).
static func lit_edge(im: Image, frames: int) -> Image:
	var out = rim(im, frames, DARK)
	var w = im.get_width()
	var h = im.get_height()
	var fw = w / frames
	var data = im.get_data()
	var e = blank(w, h)
	for y in h:
		for x in w:
			var a = data[(y * w + x) * 4 + 3] / 255.0
			if a <= 0:
				continue
			var a2 = 0.0
			if x > 0 and y > 0:
				a2 = data[((y - 1) * w + x - 1) * 4 + 3] / 255.0
			var k = a * (1.0 - a2)
			if k > 0:
				e.set_pixel(x, y, Color(1.0, 246 / 255.0, 216 / 255.0, 0.9 * k))
	for f in frames:
		out.blend_rect(e, Rect2i(f * fw, 0, fw, h), Vector2i(f * (fw + 2) + 1, 1))
	return out

## The far scenery pushed back: less colour, a little darker, so that what is in play stands out.
static func recede(im: Image, grey: float, dark: float) -> Image:
	if im == null:
		return null
	var out: Image = im.duplicate()
	out.adjust_bcs(dark, 1.0, 1.0 - grey)
	return out

## `cut` rows taken out around row `at`, top and bottom whole.
static func lowered(im: Image, cut: int, at: int) -> Image:
	if im == null:
		return null
	var w = im.get_width()
	var h = im.get_height()
	var c = blank(w, h - cut)
	var a = at - (cut >> 1)
	c.blit_rect(im, Rect2i(0, 0, w, a), Vector2i.ZERO)
	c.blit_rect(im, Rect2i(0, a + cut, w, h - a - cut), Vector2i(0, a))
	return c

## A long drawing made shorter by taking out its middle: both ends stay whole.
static func shortened(im: Image, w: int) -> Image:
	if im == null or im.get_width() <= w:
		return im
	var h = im.get_height()
	var c = blank(w, h)
	var half = w >> 1
	c.blit_rect(im, Rect2i(0, 0, half, h), Vector2i.ZERO)
	c.blit_rect(im, Rect2i(im.get_width() - (w - half), 0, w - half, h), Vector2i(half, 0))
	return c

## A drawing twice as fine, its diagonals smoothed the way pixel artists do it by hand (Scale2x): a
## pixel's corner takes the colour of its two neighbours on that side when they agree and the opposite
## ones do not. No new colour appears, nothing gets blurry.
static func rounded(im: Image) -> Image:
	var w = im.get_width()
	var h = im.get_height()
	var d = im.get_data()
	var key = PackedInt64Array()
	key.resize(w * h)
	for i in w * h:
		var a = d[i * 4 + 3]
		key[i] = 0 if a < 128 else (d[i * 4] | (d[i * 4 + 1] << 8) | (d[i * 4 + 2] << 16) | (a << 24))
	var out = PackedByteArray()
	out.resize(w * h * 16)
	var W = w * 2
	for y in h:
		for x in w:
			var P = key[y * w + x]
			var A = key[(y - 1) * w + x] if y > 0 else 0
			var B = key[y * w + x + 1] if x < w - 1 else 0
			var C = key[y * w + x - 1] if x > 0 else 0
			var D = key[(y + 1) * w + x] if y < h - 1 else 0
			var q = [
				A if (C == A and C != D and A != B) else P,
				B if (A == B and A != C and B != D) else P,
				C if (D == C and D != B and C != A) else P,
				D if (B == D and B != A and D != C) else P,
			]
			var at = [(y * 2) * W + x * 2, (y * 2) * W + x * 2 + 1, (y * 2 + 1) * W + x * 2, (y * 2 + 1) * W + x * 2 + 1]
			for k in 4:
				var v: int = q[k]
				var o: int = at[k] * 4
				out[o] = v & 255
				out[o + 1] = (v >> 8) & 255
				out[o + 2] = (v >> 16) & 255
				out[o + 3] = (v >> 24) & 255
	return Image.create_from_data(W, h * 2, false, Image.FORMAT_RGBA8, out)

## The first row of an image that is solid nearly all the way across: where a floor piece really begins.
static func surface(im: Image) -> int:
	if im == null:
		return 3
	var w = im.get_width()
	for y in mini(16, im.get_height()):
		var n = 0
		for x in w:
			if im.get_pixel(x, y).a > 0.5:
				n += 1
		if n > w * 0.8:
			return y
	return 3

## The colour of the first solid pixel found on a row of an image (row < 0 counts from the bottom).
static func row_colour(im: Image, row: int, fallback: Color) -> Color:
	if im == null:
		return fallback
	var y = im.get_height() + row if row < 0 else row
	for x in range(im.get_width() >> 1, im.get_width()):
		var c = im.get_pixel(x, y)
		if c.a > 200 / 255.0:
			return Color(c.r, c.g, c.b, 1)
	return fallback

## A block of the scenery's ground floating in the air: the top rows of a ground piece, and below them
## the earth narrowing to a ragged point, darker the deeper it goes, outlined, a few roots hanging.
static func isle(g: Image, top: int, w: int) -> Image:
	var gw = g.get_width()
	var gh = g.get_height()
	var deck = mini(gh, top + 10)
	var depth = roundi(w * 0.42) + 14
	var H = deck + depth + 8
	var c = blank(w, H)
	var ey = gh - EARTH - 2
	var soil = row_colour(g, -2, Color("#2a1c2c"))
	var k = 0
	while k < w:
		c.blit_rect(g, Rect2i(0, 0, mini(gw, w - k), deck), Vector2i(k, 0))
		k += gw
	var prof: Array = []
	for u in w:
		var e = (u + 0.5 - w / 2.0) / (w / 2.0)
		var d = roundi(depth * pow(maxf(0, 1 - absf(e)), 1.15) * (0.7 + 0.3 * h01(u >> 2, 7)))
		prof.append(d)
		c.fill_rect(Rect2i(u, deck - 2, 1, d + 2), soil)          # solid first: the ground's own holes never show
		var y = 0
		while y < d:
			c.blend_rect(g, Rect2i(u % gw, ey, 1, mini(EARTH, d - y)), Vector2i(u, deck + y))
			y += EARTH
	var sh = blank(w, H)                                      # the shade, deeper and deeper
	for y in depth:
		sh.fill_rect(Rect2i(0, deck + y, w, 1), rgba(12, 8, 26, lerpf(0.15, 0.7, float(y) / depth)))
	c.blend_rect_mask(sh, c.duplicate(), Rect2i(0, 0, w, H), Vector2i.ZERO)
	for u in w:
		if prof[u] > 0:
			c.set_pixel(u, deck + prof[u], OUTLINE)
	for r in floori(w / 18.0):                                 # roots hanging from the bottom
		var u = roundi(w * (0.2 + 0.6 * h01(r, 3)))
		var d: int = prof[u] if u < prof.size() else 0
		var ln = 3 + roundi(6 * h01(r, 5))
		c.fill_rect(Rect2i(u, deck + d, 1, ln), Color("#2a1a22"))
	return c

## A dark hill rising behind the path: scenery only, kept dark so it never draws the eye. The earth of
## the scenery's ground under a heavy veil, a rounded crest with a few bumps and tufts. Kept for later.
static func hill(biome: int, w: int, h: int, seed: int) -> Texture2D:
	var key = "%d-%d-%d-%d" % [biome, w, h, seed]
	if hills.has(key):
		return hills[key]
	var g: Image = scene[biome]["ground"]["pieces"][0]["img"]
	var gw = g.get_width()
	var ey = g.get_height() - EARTH - 2
	var c = blank(w, h + 2)
	var soil = row_colour(g, -2, Color("#2a1c2c"))
	var tops: Array = []
	for u in w:
		var e = (u + 0.5 - w / 2.0) / (w / 2.0)
		var n1 = h01((u >> 3) + seed, 9)
		var k: float
		if biome == 2:      # the city: blocks of scrap and buildings
			k = pow(maxf(0, 1 - absf(e) * 1.05), 0.4) * (0.55 + 0.45 * h01(floori(u / 14.0) + seed, 4))
		elif biome == 3:    # the dungeon: rough rock
			k = pow(maxf(0, 1 - pow(absf(e), 1.6)), 0.7) * (0.86 + 0.1 * absf(sin(u * 0.055 + seed)) + 0.06 * h01(floori(u / 9.0) + seed, 5))
		else:
			k = pow(maxf(0, 1 - pow(absf(e), 2.2)), 0.55) * (0.9 + 0.1 * sin(u * 0.09 + seed) + 0.05 * n1)
		var t = roundi(h - h * minf(1, k))
		tops.append(t)
		c.fill_rect(Rect2i(u, t, 1, h + 2 - t), soil)            # solid first: no hole can show
		var y = t
		while y < h + 2:
			c.blend_rect(g, Rect2i((u + seed) % gw, ey, 1, mini(EARTH, h + 2 - y)), Vector2i(u, y))
			y += EARTH
	c.blend_rect_mask(solid(w, h + 2, rgba(10, 8, 28, 0.76)), c.duplicate(), Rect2i(0, 0, w, h + 2), Vector2i.ZERO)
	var crest = solid(1, 2, rgba(8, 6, 20, 0.85))
	for u in w:                                              # its crest, tufts in the green places
		var t: int = tops[u]
		if t < h:
			c.blend_rect(crest, Rect2i(0, 0, 1, 2), Vector2i(u, t))
			if biome < 2 and h01(u + seed, 11) > 0.86:
				c.blend_rect(crest, Rect2i(0, 0, 1, 2), Vector2i(u, t - 2))
	if biome == 1:                                           # the ruins: stumps of broken columns on the crest
		for k in floori(w / 90.0):
			var u = roundi(w * (0.15 + 0.7 * h01(k + seed, 2)))
			var ch = 8 + roundi(16 * h01(k + seed, 6))
			var t: int = tops[mini(u, w - 1)]
			var col = solid(9, ch + 2, rgba(8, 6, 20, 0.85))
			c.blend_rect(col, Rect2i(0, 0, 7, ch + 2), Vector2i(u - 3, t - ch))
			c.blend_rect(col, Rect2i(0, 0, 9, 2), Vector2i(u - 4, t - ch))
			c.fill_rect(Rect2i(u + 1 + (k % 3), t - ch, 3, 2), Color(0, 0, 0, 0))
	if biome == 2:                                           # a few dim windows
		var win = solid(2, 1, rgba(120, 200, 255, 0.18))
		for k in floori(w / 12.0):
			var u = mini(w - 1, roundi(w * h01(k + seed, 8)))
			var y: int = tops[u] + 6 + roundi((h - tops[u]) * h01(k + seed, 3) * 0.6)
			if y < h - 4:
				c.blend_rect(win, Rect2i(0, 0, 2, 1), Vector2i(u, y))
	var t2 = make(c)
	hills[key] = t2
	hill_order.append(key)
	if hill_order.size() > 40:
		hills.erase(hill_order.pop_front())
	return t2

# What passes in front of the picture, along its bottom and top edges: plain shadows in two depths.
static func low_row(colour: Color, seed: int, count: int, scale: float, peak: int) -> Image:
	var c = blank(FORE_W, peak)
	var plants: Array = []
	for k in [3, 4, 5, 3]:
		if img.has("prop-%d" % k):
			plants.append(img["prop-%d" % k])
	if plants.is_empty():
		return c
	for i in count:
		var im: Image = plants[floori(h01(i, seed) * plants.size())]
		var k = scale * (0.7 + 0.5 * h01(i, seed + 1))
		var w = maxi(1, roundi(im.get_width() * k))
		var h = maxi(1, roundi(im.get_height() * k))
		var px = roundi(i * FORE_W / float(count) + h01(i, seed + 2) * 24)
		var top = peak - mini(peak, roundi(h * (0.45 + 0.3 * h01(i, seed + 3))))
		var sc: Image = im.duplicate()
		sc.resize(w, h, Image.INTERPOLATE_BILINEAR)
		for dx in [0, -FORE_W]:
			c.blend_rect(sc, Rect2i(0, 0, w, h), Vector2i(px + dx, top))
	return tinted(c, colour)

static func high_row(colour: Color, seed: int, peak: int) -> Image:
	var c = blank(FORE_W, peak)
	var disc = func(cx: int, cy: int, r: int) -> void:
		for dy in range(-r, r + 1):
			var half = roundi(sqrt(r * r - dy * dy))
			for dx in [0, -FORE_W, FORE_W]:
				c.fill_rect(Rect2i(cx - half + dx, cy + dy, half * 2, 1), colour)
	for i in 46:                                             # the canopy's underside
		disc.call(roundi(h01(i, seed) * FORE_W), roundi(h01(i, seed + 1) * 5) - 2, 5 + roundi(h01(i, seed + 2) * 7))
	for i in 15:                                             # creepers hanging from it, a leaf every few pixels
		var cx = roundi((i + h01(i, seed + 3)) * FORE_W / 15.0)
		var ln = 8 + roundi(h01(i, seed + 4) * (peak - 10))
		for y in ln:
			var wx = cx + roundi(sin(y * 0.35 + i) * 1.2)
			c.fill_rect(Rect2i(wx, y, 2, 1), colour)
			if y % 5 == 3:
				c.fill_rect(Rect2i(wx + (-3 if y % 10 == 3 else 2), y, 3, 2), colour)
		disc.call(cx + 1, ln, 2)
	return c

static func silhouettes(shade: Color) -> Dictionary:
	var black = Color("#0b0916")
	return {
		"low": [make(low_row(shade, 11, 13, 0.55, 22)), make(low_row(black, 31, 8, 0.8, 30))],
		"high": [make(high_row(shade, 51, 24)), make(high_row(black, 71, 30))],
	}

## The warning of a flyer about to cross: a red triangle, light rim, white "!", dark outline.
static func warn_sign(h: int) -> Texture2D:
	if signs.has(h):
		return signs[h]
	var w = roundi(h * 1.16)
	var c = blank(w + 2, h + 2)
	var mid = (w + 2) / 2.0
	for layer in [[0.0, OUTLINE], [1.0, Color("#ffd35c")], [2.5, RED]]:
		var inset: float = layer[0]
		var y = ceili(inset * 1.9)
		while y < h - inset:
			var half = (y - inset * 1.9) / (h - inset * 2.9) * (w / 2.0 - inset * 1.2)
			if half > 0:
				c.fill_rect(Rect2i(roundi(mid - maxf(0.5, half)), y + 1, maxi(1, roundi(2 * maxf(0.5, half))), 1), layer[1])
			y += 1
	var bw = maxi(2, roundi(h / 8.0))
	var top = roundi(h * 0.34)
	var bar = roundi(h * 0.36)
	var bx = roundi(mid - bw / 2.0)
	c.fill_rect(Rect2i(bx - 1, top - 1, bw + 2, bar + 2), OUTLINE)
	c.fill_rect(Rect2i(bx - 1, top + bar + 2, bw + 2, bw + 2), OUTLINE)
	c.fill_rect(Rect2i(bx, top, bw, bar), Color.WHITE)
	c.fill_rect(Rect2i(bx, top + bar + 3, bw, bw), Color.WHITE)
	signs[h] = make(c)
	return signs[h]

# ---------- per scenery ----------

static func build_scene(b: Dictionary) -> Dictionary:
	# The floor is a long fixed sequence of the ground pieces, some mirrored, repeated only every few
	# thousand pixels: far too long for the eye to catch the pattern at running speed.
	var kinds: Array = []
	for g in b["grounds"]:
		if img.has(g):
			kinds.append(img[g])
	var made = {}
	var pieces: Array = []
	var ln = 0
	var last = -1
	for i in (24 if kinds.size() > 0 else 0):
		var k = floori(h01(i, 5) * kinds.size())
		if k == last and kinds.size() > 1:
			k = (k + 1) % kinds.size()
		last = k
		# a single strip is mirrored every other time (its ends then always match)
		var flip: bool = h01(i, 9) > 0.5 if kinds.size() > 1 else (i & 1) == 1
		var key = "%d-%s" % [k, flip]
		if not made.has(key):
			var im: Image = mirrored(kinds[k]) if flip else kinds[k]
			made[key] = {"img": im, "tex": make(im), "w": im.get_width(), "h": im.get_height()}
		var pc: Dictionary = made[key].duplicate()
		pc["x"] = ln
		pieces.append(pc)
		ln += kinds[k].get_width() - (3 if kinds.size() > 1 else 0)
	var top = (4 if kinds.size() > 1 else surface(kinds[0]) + 1) if kinds.size() > 0 else 3
	var shade: Color = Color(b["shade"]) if b["shade"] != "" else Color("#16224a")
	# Props stand on the path, right where crates and creatures do, but are only there to be looked at:
	# they are darkened so the eye does not take them for something to dodge.
	var veil = rgba(10, 8, 30, 0.55) if look >= 4 else rgba(16, 12, 40, 0.38)
	var props: Array = []
	for i in b["props"]:
		var n: String = b["prop"] + str(i)
		props.append(make(tinted(img[n], veil)) if img.has(n) else null)
	var glows = {}                               # the forest's lantern and mushrooms: their own lit pixels
	if b["id"] == "jungle":
		for k in [Game.PROP_SHROOM, Game.PROP_LANTERN]:
			var pn: String = b["prop"] + str(k)
			if img.has(pn):
				glows[k] = lit_parts(img[pn], k == Game.PROP_LANTERN)
	var isles: Array = []
	if kinds.size() > 0:
		for w in Game.ISLE_W:
			isles.append(make(isle(kinds[0], top, roundi(w / Game.PIXEL))))
	var dim = rgba(16, 12, 40, 0.38)
	var tunnel: Image = img.get(b["tunnel"])
	if tunnel != null:
		tunnel = tinted(lowered(shortened(tunnel, roundi(Game.LOG_W / Game.PIXEL)), LOG_CUT, 49), dim)
	var bg: Image = recede(img.get(b["bg"]), 0.6 if look >= 4 else 0.35, 0.58 if look >= 4 else 0.82)
	var mid: Image = recede(img.get(b["mid"]), 0.55 if look >= 4 else 0.3, 0.62 if look >= 4 else 0.86)
	var hollow: Array = []
	for h in b["hollow"]:
		hollow.append(Color(h))
	return {
		"platform": tex.get(b["platform"]), "plat_top": b["plat_top"],
		"pillar": make(tinted(img[b["pillar"]], dim)) if img.has(b["pillar"]) else null,
		"slab": tex.get(b["slab"]), "slab_top": b["slab_top"],
		"tunnel": make(tunnel) if tunnel != null else null,
		"hollow": hollow,
		"isles": isles, "gtop": top,
		"bg": make(bg) if bg != null else null,
		"mid": make(mid) if mid != null else null,
		"ground": {"pieces": pieces, "len": ln, "soil": row_colour(kinds[0] if kinds.size() > 0 else null, -2, Color("#2a1c2c")), "top": top},
		"props": props,
		"glows": glows,
		"fore": silhouettes(shade),
		"sky": row_colour(img.get(b["bg"]), 0, Color("#7fb9ec")),
		"base": row_colour(img.get(b["mid"]), -1, Color("#1c2c3a")),
	}

## What lights up in a prop, pixel for pixel over it: its cyan glass and flame (a lantern's window), or its
## caps (the mushrooms), a little paler; where their middle is. Drawn over the darkened prop, they light it
## without a single pixel outside its own shape.
static func lit_parts(im: Image, window: bool) -> Dictionary:
	var w = im.get_width()
	var h = im.get_height()
	var out = blank(w, h)
	var at = Vector2.ZERO
	var count = 0
	for y in h:
		for x in w:
			var c = im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if window and (x < w * 0.2 or x > w * 0.75 or y < h * 0.44 or y > h * 0.88):
				continue
			if not window and y > h * 0.62:
				continue                             # (the stems and the grass stay as they are)
			if c.h > 0.45 and c.h < 0.62 and c.s > 0.35 and c.v > 0.45:
				out.set_pixel(x, y, c.lerp(Color.WHITE, 0.3))
				at += Vector2(x, y)
				count += 1
	return {"tex": make(out), "c": at / maxi(1, count)}

## The dangers as drawn: with a lit edge in a dark outline, maybe outlined in red as well (then one pixel
## larger all round: `pad`). Their harmless ghost (Faune alcoolisée) keeps a pale outline.
static func build_haz() -> void:
	haz = {}
	for k in HAZ_FRAMES:
		if not img.has(k):
			continue
		var frames: int = HAZ_FRAMES[k]
		if k == "fly":
			frames = int(meta["fly"]["frames"])
		elif k == "mosquito":
			frames = int(meta["mosquito"]["frames"])
		var im: Image = img[k]
		var pad = 0
		if look == 2 or look == 5:
			im = lit_edge(im, frames)
			pad = 1
		if rim_on:
			im = rim(im, frames, RED)
			pad += 1
		var ghost = rim(tinted(img[k], rgba(110, 215, 255, 0.55)), frames, Color("#d8f6ff"))
		haz[k] = {"tex": make(im), "ghost": make(ghost), "frames": frames, "pad": pad, "w": im.get_width(), "h": im.get_height(), "gw": ghost.get_width(), "gh": ghost.get_height()}

static func set_danger_rim(on: bool) -> void:
	rim_on = on
	if ready:
		build_haz()
