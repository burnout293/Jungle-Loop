class_name Skins
extends RefCounted
## Skins (0.47): another look for Pépito, each mount and the pygmies. A standard skin is the same picture in
## other colours, made here from the original images (no new image): each rule takes the pixels whose hue is
## in a range (and colourful enough) and turns them to another hue, more or less saturated and bright. Rare and
## legendary skins (an accessory, a shine) will come later; RARITIES already holds their names.
## Worn skins replace the textures in Art.tex / Art.hi (apply), so every drawing (the run, the shop's preview,
## the capture) shows them without knowing.

const TARGETS := {
	"pepito": {"name": "Pépito", "tex": ["hero-body", "hero-rotor", "hero-fist", "hero-shoe", "hero-ball"]},
	"gorilla": {"name": "Gorille", "tex": ["mount-gorilla", "mount-gorilla-hang"]},
	"rhino": {"name": "Rhino", "tex": ["mount-rhino"]},
	"dragonfly": {"name": "Libellule", "tex": ["mount-dragonfly"]},
	"pygmies": {"name": "Pygmées", "tex": ["guard-spear", "guard-club"]},
}
const ORDER := ["pepito", "gorilla", "rhino", "dragonfly", "pygmies"]
const RARITIES := {"standard": {"name": "Standard", "colour": "#c9d6c3"}, "rare": {"name": "Rare", "colour": "#5cb8ff"}, "legendary": {"name": "Légendaire", "colour": "#ffd35c"}}

# rule: h = the hue range (degrees), s_min = how colourful a pixel must be, to = the new hue (absent: kept),
# s / v = saturation and brightness multiplied.
const CATALOG := [
	{"id": "pepito-autumn", "target": "pepito", "rarity": "standard", "name": "Automne", "rules": [{"h": [50, 140], "to": 30, "s": 1.05, "v": 1.0}]},
	{"id": "pepito-frost", "target": "pepito", "rarity": "standard", "name": "Givre", "rules": [{"h": [50, 140], "to": 190, "s": 0.55, "v": 1.12}]},
	{"id": "pepito-ember", "target": "pepito", "rarity": "standard", "name": "Braise", "rules": [{"h": [50, 140], "to": 6, "s": 1.1, "v": 0.95}]},
	{"id": "pepito-amethyst", "target": "pepito", "rarity": "standard", "name": "Améthyste", "rules": [{"h": [50, 140], "to": 285, "s": 0.9, "v": 1.0}]},
	{"id": "pepito-gold", "target": "pepito", "rarity": "standard", "name": "Or", "rules": [{"h": [50, 140], "to": 46, "s": 1.1, "v": 1.12}]},
	{"id": "gorilla-silver", "target": "gorilla", "rarity": "standard", "name": "Argenté", "rules": [{"h": [185, 255], "s_min": 0.1, "s": 0.2, "v": 1.3}]},
	{"id": "gorilla-brown", "target": "gorilla", "rarity": "standard", "name": "Brun", "rules": [{"h": [185, 255], "s_min": 0.1, "to": 24, "s": 1.1, "v": 1.0}]},
	{"id": "gorilla-yeti", "target": "gorilla", "rarity": "standard", "name": "Yéti", "rules": [{"h": [185, 255], "s_min": 0.1, "s": 0.12, "v": 1.75}]},
	{"id": "rhino-sand", "target": "rhino", "rarity": "standard", "name": "Sable", "rules": [{"h": [180, 255], "s_min": 0.1, "to": 36, "s": 1.0, "v": 1.1}]},
	{"id": "rhino-rose", "target": "rhino", "rarity": "standard", "name": "Rose", "rules": [{"h": [180, 255], "s_min": 0.1, "to": 340, "s": 1.0, "v": 1.08}]},
	{"id": "rhino-slate", "target": "rhino", "rarity": "standard", "name": "Ardoise", "rules": [{"h": [180, 255], "s_min": 0.1, "s": 0.3, "v": 0.78}]},
	{"id": "dragonfly-emerald", "target": "dragonfly", "rarity": "standard", "name": "Émeraude", "rules": [{"h": [165, 235], "to": 135, "s": 1.0, "v": 1.0}]},
	{"id": "dragonfly-ruby", "target": "dragonfly", "rarity": "standard", "name": "Rubis", "rules": [{"h": [165, 235], "to": 352, "s": 1.0, "v": 1.0}]},
	{"id": "dragonfly-gold", "target": "dragonfly", "rarity": "standard", "name": "Or", "rules": [{"h": [165, 235], "to": 44, "s": 1.05, "v": 1.1}]},
	{"id": "pygmies-autumn", "target": "pygmies", "rarity": "standard", "name": "Feuilles d'automne", "rules": [{"h": [95, 180], "s_min": 0.15, "to": 32, "s": 1.6, "v": 1.45}]},
	{"id": "pygmies-night", "target": "pygmies", "rarity": "standard", "name": "Nuit", "rules": [{"h": [95, 180], "s_min": 0.15, "to": 270, "s": 1.5, "v": 1.2}]},
	{"id": "pygmies-fire", "target": "pygmies", "rarity": "standard", "name": "Feu", "rules": [{"h": [95, 180], "s_min": 0.15, "to": 4, "s": 1.7, "v": 1.45}]},
]

static var originals := {}     # texture name -> its original {img, tex, hi} (taken from Art the first time)
static var cache := {}         # skin id -> {texture name -> {tex, hi}}: each skin is made once
static var current := {}       # target -> the skin id Art shows now ("" the original)

static func skin(id: String) -> Dictionary:
	for s in CATALOG:
		if s["id"] == id:
			return s
	return {}

static func of_target(target: String) -> Array:
	return CATALOG.filter(func(s): return s["target"] == target)

## The worn skin of each target, as Art should draw it (only the targets that change are made again).
static func apply(worn: Dictionary) -> void:
	if not Art.ready:
		return
	for target in ORDER:
		var id = str(worn.get(target, ""))
		if skin(id).is_empty():
			id = ""
		if current.get(target, "") == id and current.has(target):
			continue
		current[target] = id
		for name in TARGETS[target]["tex"]:
			if not Art.img.has(name):
				continue
			if not originals.has(name):
				originals[name] = {"img": Art.img[name], "tex": Art.tex[name], "hi": Art.hi.get(name)}
			var o: Dictionary = originals[name]
			var made: Dictionary = o if id == "" else _made(id, name)
			Art.tex[name] = made["tex"]
			if made["hi"] != null:
				Art.hi[name] = made["hi"]
		if target == "pepito":                       # the far fist and shoe, in the shade of his body
			var dim = Art.rgba(16, 12, 40, 0.38)
			for k in ["fist", "shoe"]:
				if not originals.has("hero-" + k):
					continue
				var base: Image = originals["hero-" + k]["img"] if id == "" else recolour(originals["hero-" + k]["img"], skin(id)["rules"])
				Art.tex["far-" + k] = Art.make(Art.tinted(base, dim))
				Art.hi["far-" + k] = Art.make(Art.tinted(Art.rounded(Art.rounded(base)), dim))

static func _made(id: String, name: String) -> Dictionary:
	if not cache.has(id):
		cache[id] = {}
	if not cache[id].has(name):
		var o: Dictionary = originals[name]
		var im = recolour(o["img"], skin(id)["rules"])
		cache[id][name] = {"tex": Art.make(im), "hi": Art.make(Art.rounded(Art.rounded(im))) if o["hi"] != null else null}
	return cache[id][name]

## A copy of `src` with the rules' colours turned (each colour worked out once: pixel art has few).
static func recolour(src: Image, rules: Array) -> Image:
	var im: Image = src.duplicate()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = im.get_data()
	var map := {}
	var i = 0
	var n = data.size()
	while i < n:
		var a = data[i + 3]
		if a > 12:
			var key = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			var to = map.get(key, -1)
			if to < 0:
				to = _turn(key, rules)
				map[key] = to
			data[i] = (to >> 16) & 255
			data[i + 1] = (to >> 8) & 255
			data[i + 2] = to & 255
		i += 4
	return Image.create_from_data(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8, data)

static func _turn(key: int, rules: Array) -> int:
	var c = Color8((key >> 16) & 255, (key >> 8) & 255, key & 255)
	for r in rules:
		var hue = c.h * 360.0
		var lo: float = r["h"][0]
		var hi: float = r["h"][1]
		if hue < lo or hue > hi or c.s < float(r.get("s_min", 0.22)) or c.v < 0.08:
			continue
		var nh = (float(r["to"]) / 360.0) + (c.h - (lo + hi) / 720.0) * 0.5 if r.has("to") else c.h
		c = Color.from_hsv(fposmod(nh, 1.0), clampf(c.s * float(r.get("s", 1.0)), 0, 1), clampf(c.v * float(r.get("v", 1.0)), 0, 1))
		break
	return (c.r8 << 16) | (c.g8 << 8) | c.b8
