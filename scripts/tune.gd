class_name Tune
extends RefCounted
## reglages/equilibrage.txt: the game's numbers, written in metres, seconds, m/s and percents, read over
## game.gd's own at launch (main.gd, before the debug menu takes its "origin"). A line is « name | value »,
## several values (one per level of an upgrade, or « from / to ») separated by /; what follows # is a
## comment; a missing or wrong line keeps the game's own number. Names are compared without accents or
## capitals. KEYS says, for each, which static var of Game it sets, how, and the factor to game units.

const M := 40.0                        # game units per metre (Game.PPM)
const PC := 0.01                       # a percent

# kind: "n" a number; "i" a whole number; "lv" one per level (the level 0 value is kept); "pair" two
# numbers; "ipair" two whole numbers; "inv3" a time to settle (BALL_SETTLE = 3 / t); "zone:<biome>" one
# scenery's speed; "mount:<kind>:<field>" a mount's number; "gems" the three gems' worth.
const KEYS := {
	"course": {
		"vitesse au depart": ["SPEED_BASE", "n", M],
		"acceleration run illimitee": ["SPEED_GAIN", "n", M],
		"acceleration histoire": ["STORY_GAIN", "n", M],
		"vitesse des ruines": ["ZONE_SPEED", "zone:1", M],
		"vitesse du donjon": ["ZONE_SPEED", "zone:3", M],
		"vitesse de la cite": ["ZONE_SPEED", "zone:2", M],
		"sprint": ["SPEED_SPRINT", "n", M],
		"nouveau decor run illimitee": ["ZONE_ENDLESS", "n", 1.0],
		"nouveau decor histoire": ["ZONE", "n", 1.0],
		"vitesse maximale run illimitee": ["SPEED_CAP", "n", M],
		"vitesse maximale histoire": ["STORY_CAP", "n", M],
	},
	"saut": {
		"gravite": ["JUMP_GRAVITY", "n", M],
		"elan du saut": ["JUMP_V", "n", M],
		"elan du double saut": ["JUMP_DOUBLE", "n", M],
		"gravite en montee bouton tenu": ["JUMP_HELD", "n", M],
		"ressort": ["SPRING_K", "n", PC],
	},
	"vol": {
		"montee": ["FLAP_LV", "lv", M],
		"arret au relache": ["VOL_STOP", "n", 1.0],
		"chute apres le vol": ["VOL_DROP", "n", 1.0],
	},
	"vies": {
		"coeurs au depart": ["HEARTS", "i", 1.0],
		"coeurs en histoire": ["STORY_HEARTS", "i", 1.0],
		"invincible apres un coup": ["HURT_INV", "n", 1.0],
	},
	"objets": {
		"aimant": ["MAGNET", "lv", M],
		"gemmes dispersees": ["SCATTER", "lv", PC],
		"valeur des gemmes": ["GEMS", "gems", 1.0],
		"relique alteree creatures etherees": ["DRUNK", "lv", PC],
		"relique alteree decor fantome": ["RELIC_STRIP", "n", M],
		"ami de la nature": ["FRIEND_K", "n", PC],
		"esquive vitesse en plus": ["DODGE_SPEED", "n", M],
		"esquive duree": ["DODGE_TIME", "n", 1.0],
		"esquive recharge": ["DASH_CD", "lv", 1.0],
		"esquive invincible apres": ["DODGE_INV", "n", 1.0],
		"sablier duree": ["SLOW_TIME", "lv", 1.0],
		"sablier recharge": ["SLOW_CD", "n", 1.0],
		"sablier vitesse du monde": ["SLOW_PACE", "n", PC],
		"bottes chute": ["BOOTS_FALL", "n", 1.0],
		"bottes plongeon": ["BOOTS_DIVE", "n", M],
		"bottes portee de la secousse": ["BOOTS_RANGE", "lv", M],
		"bottes recharge": ["BOOTS_CD", "lv", 1.0],
		"tnt recharge": ["TNT_CD", "lv", 1.0],
		"tnt temps de vol": ["TNT_FLIGHT", "n", 1.0],
		"redmonster duree": ["MONSTER_TIME", "lv", 1.0],
		"redmonster recharge": ["MONSTER_CD", "lv", 1.0],
		"redmonster vitesse": ["MONSTER_MUL", "n", PC],
	},
	"objets rares": {
		"un tous les": ["BONUS_EVERY", "pair", 1.0],
		"sablier ralentissement": ["BRAKE_SHARE", "n", PC],
		"sablier vitesse": ["BRAKE_PACE", "n", PC],
		"caisse pieces": ["CRATE_COINS", "i", 1.0],
	},
	"montures": {
		"premiere": ["MOUNT_FIRST", "pair", 1.0],
		"suivantes": ["MOUNT_NEXT", "pair", 1.0],
		"duree du rhino": ["MOUNTS", "mount:rhino:time", 1.0],
		"dompte portee": ["TAME_REACH", "lv", M],
		"dompte ralentit": ["TAME_SLOW", "n", PC],
		"dompte gorille et libellule": ["TAME_UP", "n", M],
		"dompte rhino": ["TAME_RHINO", "n", M],
		"aimant de monture": ["MOUNT_MAGNET", "lv", M],
	},
	"araignees": {
		"des": ["FROM_LOW", "n", 1.0],
		"a hauteur de tete des": ["FROM_MID", "n", 1.0],
		"par colonne au plus": ["SPIDER_COLUMN", "i", 1.0],
		"montee et descente": ["SPIDER_AMP", "n", M],
		"aller retour": ["SPIDER_PERIOD", "n", 1.0],
		"ecart dans une file": ["SPIDER_GAP_TIME", "n", 1.0],
		"ecart mini dans une file": ["SPIDER_GAP_MIN", "n", M],
		"files poids": ["CHAIN_SPIDERS", "i", 1.0],
		"nids poids": ["CHAIN_NESTS", "i", 1.0],
		"nids des": ["FROM_NESTS", "n", 1.0],
	},
	"volants": {
		"des": ["FROM_DARTS", "n", 1.0],
		"avertissement": ["DART_WARN", "n", 1.0],
		"suivi": ["DART_TRACK", "n", M],
		"vitesse": ["DART_SPEED", "n", M],
		"vagues": ["WAVE_N", "ipair", 1.0],
		"vagues poids": ["CHAIN_WAVES", "i", 1.0],
		"ecart dans les vagues": ["WAVE_GAP", "pair", 1.0],
		"campement": ["CAMP_TIME", "n", 1.0],
		"campement encore": ["CAMP_AGAIN", "n", 1.0],
	},
	"nuees": {
		"premiere": ["FM_FIRST", "pair", 1.0],
		"suivantes": ["FM_NEXT", "pair", 1.0],
		"epaisseur": ["FM_THICK", "n", PC],
	},
	"agencement": {
		"plus dur des": ["PRESS_FROM", "n", 1.0],
		"au plus dur a": ["PRESS_FULL", "n", 1.0],
		"en histoire au plus": ["PRESS_STORY", "n", PC],
		"ecarts en moins": ["PRESS_GAP", "n", PC],
		"enchainements en plus": ["PRESS_CHAINS", "n", PC],
		"temps pour retomber en moins": ["PRESS_NEED", "n", PC],
		"volants dans les grands ecarts en plus": ["PRESS_FILL", "n", PC],
	},
	"vorace": {
		"arrivee": ["BOSS_AT", "n", 1.0],
		"vitesse": ["BOSS_SPEED", "n", M],
		"duree": ["BOSS_FIGHT", "n", 1.0],
		"recul": ["BOSS_BACK", "n", M],
		"hauteur des boules prise en": ["BALL_SETTLE", "inv3", 1.0],
	},
}

static var problems: Array = []         # the lines that could not be read (the bench prints them)

## Lower case, no accents, every run of spaces, commas, hyphens or apostrophes made one space.
static func key(text: String) -> String:
	var out = text.to_lower()
	for pair in [["éèêë", "e"], ["àâä", "a"], ["îï", "i"], ["ôö", "o"], ["ùûü", "u"], ["ç", "c"]]:
		for ch in pair[0]:
			out = out.replace(ch, pair[1])
	for ch in [",", "-", "'", "’", "(", ")", ":"]:
		out = out.replace(ch, " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()

static func _numbers(text: String) -> Array:
	var out: Array = []
	for part in text.split("/"):
		var t = part.strip_edges().replace(",", ".").replace("%", "").strip_edges()
		if not t.is_valid_float():
			return []
		out.append(float(t))
	return out

static func load_file(path: String = "res://reglages/equilibrage.txt") -> void:
	if FileAccess.file_exists(path):
		read(FileAccess.get_file_as_string(path))

static func read(text: String) -> void:
	problems = []
	var game: GDScript = load("res://scripts/game.gd")
	var section = ""
	var n = 0
	for raw in text.split("\n"):
		n += 1
		var line: String = raw.split("#")[0].strip_edges()
		if line == "":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = key(line.substr(1, line.length() - 2))
			continue
		var cols = line.split("|")
		if cols.size() < 2 or not KEYS.has(section) or not KEYS[section].has(key(cols[0])):
			problems.append("ligne %d : %s" % [n, line])
			continue
		var spec: Array = KEYS[section][key(cols[0])]
		var vals = _numbers(cols[1])
		if vals.is_empty() or not _apply(game, spec, vals):
			problems.append("ligne %d : %s" % [n, line])
	# what follows from the jump: the time a short jump stays in the air (Vorace's fairness)
	Game.TAP_AIR = 2.0 * Game.JUMP_V / Game.JUMP_GRAVITY

static func _apply(game: GDScript, spec: Array, vals: Array) -> bool:
	var name: String = spec[0]
	var kind: String = spec[1]
	var k: float = spec[2]
	var cur = game.get(name)
	if kind == "n":
		game.set(name, vals[0] * k)
	elif kind == "i":
		game.set(name, roundi(vals[0]))
	elif kind == "lv":
		var arr: Array = [cur[0]]
		for v in vals:
			arr.append(v * k)
		game.set(name, arr)
	elif kind == "pair" or kind == "ipair":
		if vals.size() < 2:
			return false
		game.set(name, [roundi(vals[0]), roundi(vals[1])] if kind == "ipair" else [vals[0] * k, vals[1] * k])
	elif kind == "inv3":
		if vals[0] <= 0:
			return false
		game.set(name, 3.0 / vals[0])
	elif kind == "gems":
		if vals.size() < 3:
			return false
		cur["y"] = roundi(vals[0])
		cur["r"] = roundi(vals[1])
		cur["b"] = roundi(vals[2])
	elif kind.begins_with("zone:"):
		cur[int(kind.split(":")[1])] = vals[0] * k
	elif kind.begins_with("mount:"):
		var bits = kind.split(":")
		cur[bits[1]][bits[2]] = vals[0] * k
	else:
		return false
	return true
