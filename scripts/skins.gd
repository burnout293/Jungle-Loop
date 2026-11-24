class_name Skins
extends RefCounted
## Skins (0.47): another look for Pépito, each mount and the pygmies. 0.58 (reglages/decisions-economie.md): the
## urns hold cosmetics only, in three families: Pépito's look piece by piece (leaves, shoes, bag, scarf), effects
## (the Vol's rotor, a trail as he runs, a burst as he jumps, his fall staged: a tomb, a flower, a cloud) and
## social ones (his record's board as his friends see it, his ghost's colour in the Affrontement, words to say
## to a partner). Each is a « skin » of a target: worn one per target (the emotes: all those owned), bought
## with coins at its rarity's price too. Those without a picture to recolour carry `fx`, read by render.gd. A standard skin is the same picture in
## other colours, made here from the original images (no new image): each rule takes the pixels whose hue is
## in a range (and colourful enough) and turns them to another hue, more or less saturated and bright. Rare and
## legendary skins (an accessory, a shine) will come later; RARITIES already holds their names.
## Worn skins replace the textures in Art.tex / Art.hi (apply), so every drawing (the run, the shop's preview,
## the capture) shows them without knowing.

const TARGETS := {
	"pepito": {"name": "Feuilles", "tex": ["hero-body", "hero-fist", "hero-ball"], "family": "look", "none": "Les feuilles de toujours."},
	"shoes": {"name": "Chaussures", "tex": ["hero-shoe"], "family": "look", "none": "Ses baskets vertes."},
	"bag": {"name": "Sac à dos", "tex": ["hero-body"], "family": "look", "none": "Son sac de cuir."},
	"scarf": {"name": "Écharpe", "tex": [], "family": "look", "none": "Pas d'écharpe."},
	"rotor": {"name": "Hélice du Vol", "tex": ["hero-rotor"], "family": "fx", "none": "Les feuilles qui le portent."},
	"trail": {"name": "Traînée de course", "tex": [], "family": "fx", "none": "Rien derrière lui."},
	"jump": {"name": "Éclat du saut", "tex": [], "family": "fx", "none": "Un saut tout simple."},
	"fall": {"name": "Chute", "tex": [], "family": "fx", "none": "La tête plantée, sans plus."},
	"sign": {"name": "Panneau de record", "tex": [], "family": "social", "none": "Le panneau de bois."},
	"ghost": {"name": "Fantôme (Affrontement)", "tex": [], "family": "social", "none": "La couleur de sa place."},
	"emote": {"name": "Émotes à deux", "tex": [], "family": "social", "many": true, "none": ""},
	"gorilla": {"name": "Gorille", "tex": ["mount-gorilla", "mount-gorilla-hang"]},
	"rhino": {"name": "Rhino", "tex": ["mount-rhino"]},
	"dragonfly": {"name": "Libellule", "tex": ["mount-dragonfly"]},
	"pygmies": {"name": "Pygmées", "tex": ["guard-spear", "guard-club"]},
	"buttons": {"name": "Boutons", "tex": []},      # 0.50: the interface's buttons (main.gd _wood_ui), no texture of Art
}
const ORDER := ["pepito", "shoes", "bag", "scarf", "rotor", "trail", "jump", "fall", "sign", "ghost", "emote", "gorilla", "rhino", "dragonfly", "pygmies", "buttons"]
const FAMILIES := [["look", "APPARENCE DE PÉPITO"], ["fx", "EFFETS"], ["social", "SOCIAL"], ["", "MONTURES ET RESTE"]]
const BAG_RECT := [3, 26, 10, 40]       # (0.58) where his backpack is in hero-body (x0, y0, x1, y1, included)
const BLADE_RECT := [0, 0, 46, 10]      # ... and the rotor's leaves in hero-rotor (meta.json: rig.rotor.blade 11)
const RARITIES := {"standard": {"name": "Commun", "colour": "#c9d6c3"}, "rare": {"name": "Rare", "colour": "#5cb8ff"}, "legendary": {"name": "Légendaire", "colour": "#ffd35c"}}

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
	# 0.50: the stone buttons the game had until 0.49, to win now (urns, coins); no colour rule: main.gd
	# swaps the kit's pictures (assets/img/ui-v2 instead of ui-v2/wood)
	{"id": "buttons-stone", "target": "buttons", "rarity": "standard", "name": "Pierre du temple", "rules": []},
	# ---- 0.58, the urns' cosmetics ----
	{"id": "pepito-night", "target": "pepito", "rarity": "rare", "name": "Nuit étoilée", "rules": [{"h": [50, 140], "to": 235, "s": 0.85, "v": 0.85}]},
	{"id": "pepito-sakura", "target": "pepito", "rarity": "legendary", "name": "Cerisier", "rules": [{"h": [50, 140], "to": 330, "s": 0.55, "v": 1.18}]},
	{"id": "shoes-red", "target": "shoes", "rarity": "standard", "name": "Rouges", "rules": [{"h": [50, 140], "to": 356, "s": 1.05, "v": 1.0}]},
	{"id": "shoes-blue", "target": "shoes", "rarity": "standard", "name": "Bleues", "rules": [{"h": [50, 140], "to": 212, "s": 1.0, "v": 1.05}]},
	{"id": "shoes-gold", "target": "shoes", "rarity": "rare", "name": "Dorées", "rules": [{"h": [50, 140], "to": 46, "s": 1.05, "v": 1.2}]},
	{"id": "shoes-neon", "target": "shoes", "rarity": "legendary", "name": "Néon", "rules": [{"h": [50, 140], "to": 178, "s": 1.2, "v": 1.35}, {"h": [0, 49], "s_min": 0.2, "to": 300, "s": 1.2, "v": 1.3}]},
	{"id": "bag-red", "target": "bag", "rarity": "standard", "name": "Rouge", "rules": [{"h": [0, 50], "s_min": 0.2, "rect": BAG_RECT, "to": 356, "s": 1.05, "v": 1.0}]},
	{"id": "bag-blue", "target": "bag", "rarity": "standard", "name": "Bleu", "rules": [{"h": [0, 50], "s_min": 0.2, "rect": BAG_RECT, "to": 214, "s": 0.95, "v": 1.05}]},
	{"id": "bag-black", "target": "bag", "rarity": "rare", "name": "Noir", "rules": [{"h": [0, 50], "s_min": 0.2, "rect": BAG_RECT, "s": 0.15, "v": 0.55}]},
	{"id": "bag-gold", "target": "bag", "rarity": "legendary", "name": "Doré", "rules": [{"h": [0, 50], "s_min": 0.2, "rect": BAG_RECT, "to": 46, "s": 1.1, "v": 1.3}]},
	{"id": "scarf-red", "target": "scarf", "rarity": "standard", "name": "Rouge", "fx": {"col": "#e0383e", "col2": "#a01e2e"}},
	{"id": "scarf-blue", "target": "scarf", "rarity": "standard", "name": "Bleue", "fx": {"col": "#3e8ee0", "col2": "#24589e"}},
	{"id": "scarf-striped", "target": "scarf", "rarity": "rare", "name": "Rayée", "fx": {"col": "#fff3d6", "col2": "#e0383e", "stripes": true}},
	{"id": "scarf-gold", "target": "scarf", "rarity": "legendary", "name": "Dorée", "fx": {"col": "#ffd35c", "col2": "#c08a1e", "shine": true}},
	{"id": "rotor-autumn", "target": "rotor", "rarity": "standard", "name": "Automne", "rules": [{"h": [50, 140], "rect": BLADE_RECT, "to": 26, "s": 1.05, "v": 1.0}]},
	{"id": "rotor-ice", "target": "rotor", "rarity": "standard", "name": "Glace", "rules": [{"h": [50, 140], "rect": BLADE_RECT, "to": 190, "s": 0.55, "v": 1.15}]},
	{"id": "rotor-fire", "target": "rotor", "rarity": "rare", "name": "Feu", "rules": [{"h": [50, 140], "rect": BLADE_RECT, "to": 6, "s": 1.2, "v": 1.05}]},
	{"id": "rotor-gold", "target": "rotor", "rarity": "legendary", "name": "Or", "rules": [{"h": [50, 140], "rect": BLADE_RECT, "to": 46, "s": 1.1, "v": 1.25}]},
	{"id": "trail-leaves", "target": "trail", "rarity": "standard", "name": "Feuilles", "fx": {"cols": ["#8ee111", "#4ea715", "#baf823"], "shape": "leaf"}},
	{"id": "trail-sparks", "target": "trail", "rarity": "standard", "name": "Étincelles", "fx": {"cols": ["#ffd35c", "#fff3a0", "#ffb020"], "shape": "dot"}},
	{"id": "trail-embers", "target": "trail", "rarity": "rare", "name": "Braises", "fx": {"cols": ["#ff5a1e", "#ffb020", "#c01e1e"], "shape": "dot", "rise": true}},
	{"id": "trail-rainbow", "target": "trail", "rarity": "legendary", "name": "Arc-en-ciel", "fx": {"cols": ["#ff4a4a", "#ffb020", "#ffe14a", "#5ce05c", "#4ab0ff", "#a06aff"], "shape": "star"}},
	{"id": "jump-dust", "target": "jump", "rarity": "standard", "name": "Poussière", "fx": {"cols": ["#e8d4a8", "#c9b080"], "shape": "puff"}},
	{"id": "jump-bubbles", "target": "jump", "rarity": "standard", "name": "Bulles", "fx": {"cols": ["#bff4ff", "#7ee8ff"], "shape": "ring"}},
	{"id": "jump-stars", "target": "jump", "rarity": "rare", "name": "Étoiles", "fx": {"cols": ["#ffd35c", "#fff3a0"], "shape": "star"}},
	{"id": "jump-petals", "target": "jump", "rarity": "legendary", "name": "Pétales", "fx": {"cols": ["#ffb0d8", "#ff7ab8", "#fff0f6"], "shape": "leaf"}},
	{"id": "fall-tomb", "target": "fall", "rarity": "standard", "name": "Pierre tombale", "fx": {"pic": "fall-tomb"}},
	{"id": "fall-flower", "target": "fall", "rarity": "rare", "name": "Fleur", "fx": {"pic": "fall-flower"}},
	{"id": "fall-cloud", "target": "fall", "rarity": "legendary", "name": "Petit nuage", "fx": {"pic": "fall-cloud"}},
	{"id": "sign-stone", "target": "sign", "rarity": "standard", "name": "Pierre", "fx": {"wood": "#8d93a8", "dark": "#2a2a3a", "lite": "#b8bdd0", "ink": "#fff8e6"}},
	{"id": "sign-jade", "target": "sign", "rarity": "standard", "name": "Jade", "fx": {"wood": "#3e9a6a", "dark": "#123a26", "lite": "#6ad89a", "ink": "#eaffef"}},
	{"id": "sign-neon", "target": "sign", "rarity": "rare", "name": "Néon", "fx": {"wood": "#1a1a3a", "dark": "#05050f", "lite": "#5cf2e0", "ink": "#5cf2e0"}},
	{"id": "sign-gold", "target": "sign", "rarity": "legendary", "name": "Or massif", "fx": {"wood": "#e0a82e", "dark": "#5a3a0a", "lite": "#ffe9a0", "ink": "#fff8e6"}},
	{"id": "ghost-red", "target": "ghost", "rarity": "standard", "name": "Rouge", "fx": {"col": "#ff6a6a"}},
	{"id": "ghost-green", "target": "ghost", "rarity": "standard", "name": "Vert", "fx": {"col": "#7aff8a"}},
	{"id": "ghost-gold", "target": "ghost", "rarity": "rare", "name": "Doré", "fx": {"col": "#ffd35c"}},
	{"id": "ghost-shadow", "target": "ghost", "rarity": "legendary", "name": "Ombre", "fx": {"col": "#5a4a8a"}},
	{"id": "emote-gg", "target": "emote", "rarity": "standard", "name": "« GG ! »", "fx": {"text": "GG !"}},
	{"id": "emote-bravo", "target": "emote", "rarity": "standard", "name": "« Bravo ! »", "fx": {"text": "Bravo !"}},
	{"id": "emote-oops", "target": "emote", "rarity": "standard", "name": "« Oups ! »", "fx": {"text": "Oups !"}},
	{"id": "emote-hurry", "target": "emote", "rarity": "standard", "name": "« Vite ! »", "fx": {"text": "Vite !"}},
	{"id": "emote-hehe", "target": "emote", "rarity": "rare", "name": "« Hé hé ! »", "fx": {"text": "Hé hé !"}},
	{"id": "emote-wow", "target": "emote", "rarity": "rare", "name": "« Waouh ! »", "fx": {"text": "Waouh !"}},
	{"id": "emote-king", "target": "emote", "rarity": "legendary", "name": "« Le roi, c'est moi ! »", "fx": {"text": "Le roi, c'est moi !"}},
]

## (0.58) What the urns may give: the cosmetics of the three families (the mounts', the pygmies' and the
## buttons' skins stay in the shop, for coins).
static var URN_LOOKS: Array = CATALOG.filter(func(sk): return TARGETS[sk["target"]].get("family", "") != "").map(func(sk): return sk["id"])

## (0.58) The `fx` of the skin worn for a target ({} none): render.gd draws trails, bursts, falls, scarves,
## boards and ghosts from it.
static func fx(target: String) -> Dictionary:
	return skin(str(current.get(target, ""))).get("fx", {})

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

## The worn skin of each target, as Art should draw it (only the pictures whose skins change are made again;
## 0.58: a picture several targets touch, like hero-body for the leaves and the bag, gets all their rules).
static func apply(worn: Dictionary) -> void:
	if not Art.ready:
		return
	var touched := {}
	for target in ORDER:
		var id = str(worn.get(target, ""))
		if skin(id).is_empty() or skin(id)["target"] != target:
			id = ""
		if current.get(target, "") == id and current.has(target):
			continue
		current[target] = id
		for name in TARGETS[target]["tex"]:
			touched[name] = true
	for name in touched:
		if not Art.img.has(name):
			continue
		if not originals.has(name):
			originals[name] = {"img": Art.img[name], "tex": Art.tex[name], "hi": Art.hi.get(name)}
		var ids: Array = []
		for target in ORDER:
			if name in TARGETS[target]["tex"] and str(current.get(target, "")) != "":
				ids.append(current[target])
		var o: Dictionary = originals[name]
		var made: Dictionary = o if ids.is_empty() else _made(ids, name)
		Art.tex[name] = made["tex"]
		if made["hi"] != null:
			Art.hi[name] = made["hi"]
		if name in ["hero-fist", "hero-shoe"]:          # the far fist and shoe, in the shade of his body
			var dim = Art.rgba(16, 12, 40, 0.38)
			var base: Image = _rules_of(ids, o["img"])
			var k = name.trim_prefix("hero-")
			Art.tex["far-" + k] = Art.make(Art.tinted(base, dim))
			Art.hi["far-" + k] = Art.make(Art.tinted(Art.rounded(Art.rounded(base)), dim))

static func _rules_of(ids: Array, src: Image) -> Image:
	var im = src
	for id in ids:
		im = recolour(im, skin(id).get("rules", []))
	return im

static func _made(ids: Array, name: String) -> Dictionary:
	var key = "+".join(ids)
	if not cache.has(key):
		cache[key] = {}
	if not cache[key].has(name):
		var o: Dictionary = originals[name]
		var im = _rules_of(ids, o["img"])
		cache[key][name] = {"tex": Art.make(im), "hi": Art.make(Art.rounded(Art.rounded(im))) if o["hi"] != null else null}
	return cache[key][name]

## A copy of `src` with the rules' colours turned (each colour worked out once: pixel art has few).
static func recolour(src: Image, rules: Array) -> Image:
	var im: Image = src.duplicate()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = im.get_data()
	var map := {}
	var i = 0
	var n = data.size()
	var wd = im.get_width()
	var boxed = rules.any(func(r): return r.has("rect"))   # (0.58: some rules only inside a rectangle)
	var open_rules = rules.filter(func(r): return not r.has("rect"))
	while i < n:
		var a = data[i + 3]
		if a > 12:
			var key = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			var use = rules
			var mk = key
			if boxed:
				var px = (i / 4) % wd
				var py = (i / 4) / wd
				use = rules.filter(func(r): return not r.has("rect") or (px >= r["rect"][0] and px <= r["rect"][2] and py >= r["rect"][1] and py <= r["rect"][3]))
				mk = key | ((use.size() - open_rules.size()) << 24)
			var to = map.get(mk, -1)
			if to < 0:
				to = _turn(key, use)
				map[mk] = to
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
