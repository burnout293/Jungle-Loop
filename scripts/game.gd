class_name Game
extends RefCounted
## Game rules: player physics, spawning, collisions. No drawing here (port of js/game.js, 0.26.0).
## World x grows to the right; the camera (run.cam) follows the player once he has left the temple.
## y grows downward: 0 is the top of the play area, GROUND the floor.
## All values are in "logical" units; the renderer divides them by PIXEL to get art pixels.

const VIEW_H := 720.0          # height of the play area shown on screen
const GROUND := 630.0          # floor line
const PX := 200.0              # player's screen x once the camera follows him
const CEIL := 24.0             # flight ceiling
const PPM := 40.0              # logical units per metre
const PIXEL := 2.25            # logical units per art pixel (720 units = 320 art pixels)
const BIOME_COUNT := 4
# The order of the sceneries (index in Render.BIOMES: jungle, ruins, city, dungeon): forest, ruins,
# dungeon, city, and back to the forest.
const NEXT_BIOME := [1, 3, 0, 2]
# The scenery changes after the boss (the ruins), then while there is no other boss every ZONE metres.
# Most of the numbers below are static vars, not consts: reglages/equilibrage.txt sets them at launch
# (tune.gd), in metres, seconds and m/s; these are the game's own when a line is missing there.
static var ZONE := 2000.0
static var ZONE_ENDLESS := 800.0    # Run illimitée: a new scenery every 800 m
# Histoire: each scenery starts from its own speed (forest 9, ruins 10, dungeon 11, city 12 m/s, Sprint
# added) and the speed grows by STORY_GAIN (0.18 m/s every second; the Run illimitée: SPEED_GAIN).
static var ZONE_SPEED := {1: 400.0, 3: 440.0, 2: 480.0}   # (the forest: SPEED_BASE)
static var STORY_GAIN := 7.2
# Vorace stands this far right of where she used to (part of her off the screen): her balls are seen
# sooner, and take their height within BALL_SETTLE of leaving her mouth.
static var BOSS_BACK := 140.0
static var BALL_SETTLE := 12.0
static var HEARTS := 1              # one life: the first blow ends the run (Vitalité adds up to three)
static var HURT_INV := 1.6          # invincible this long after a blow

const HERO_H := 80.0
const HERO_HALF := 14.0        # hitbox, smaller than the sprite: forgiving
const SPIKY_W := 68.0
const SPIKY_H := 54.0
const PLAT_W := 254.0

# Raised ways: a stone slab on pillars (a cave underneath) and a hollow log (a tunnel inside).
const SLAB_H := 100.0
const SLAB_T := 50.0
const LOG_H := 106.0
const LOG_T := 48.0
const LOG_W := 520.0
const TOUCH_H := 130.0         # scenery only reacts to a hero running past, not flying far above
const MONKEY_H := 230.0        # how high the hero must be to greet a monkey

# Esquive (the "dash" of old saves): DODGE_SPEED more for DODGE_TIME (200 m/s for 0.2 s: 40 m), breaking
# whatever can be broken on the way and passing through the rest; then DODGE_INV of safety.
static var DASH_CD := [0.0, 14.0, 10.0, 7.0]
static var DODGE_SPEED := 8000.0
static var DODGE_TIME := 0.2
static var DODGE_INV := 0.3
static var SLOW_TIME := [0.0, 3.0, 4.5]
static var MONSTER_TIME := [0.0, 5.0, 10.0, 20.0]   # RedMonster: seconds at twice his speed, by level
static var MONSTER_CD := [0.0, 30.0, 35.0, 45.0]    # seconds before the next can, from the first sip
static var MONSTER_MUL := 2.0                       # his speed while it lasts
const MONSTER_RAMP := 1800.0                        # units/s² to get there: a kick, not a slow climb
static var SLOW_CD := 20.0
static var SLOW_PACE := 0.45            # the Sablier: the world at 45 % of its pace
# The Sablier's end is announced: the last SLOW_WARN seconds tick and blink, then the world eases back.
const SLOW_WARN := 2.0
const SLOW_TICKS := [2.0, 1.5, 1.0, 0.65, 0.4, 0.2]
const SLOW_EASE := 0.35
static var MAGNET := [0.0, 110.0, 170.0, 240.0]
static var DRUNK := [0.0, 0.06, 0.1, 0.15]   # Relique altérée: share of the creatures that are harmless
# Relique altérée also stops the sceneries from changing: where one would begin, a strip of the next
# one RELIC_STRIP long goes by, and the scenery comes back.
static var RELIC_STRIP := 480.0
static var SPRING_K := 0.1              # Ressort: this much more push per level
# The Vol: how fast the leaf rotor climbs, by level (12, 13.5, 15 m/s); once released the climb stops
# (VOL_STOP: 1 at once, 0 not at all) and gravity is VOL_DROP times stronger until he lands.
static var FLAP_LV := [0.0, 480.0, 540.0, 600.0]
static var VOL_DROP := 1.2
static var VOL_STOP := 1.0
# Bottes de métal: he falls BOOTS_FALL times faster; the button dives him down at BOOTS_DIVE (on the
# floor: at once) and the quake breaks the crates and kills the creatures within BOOTS_RANGE of him.
static var BOOTS_FALL := 1.25
static var BOOTS_DIVE := 1500.0
static var BOOTS_RANGE := [0.0, 120.0, 180.0]
static var BOOTS_CD := [0.0, 8.0, 5.0]
# Fana de TNT: the button throws a stick that lands TNT_FLIGHT later and blows up everything ahead of him
# up to the right edge (not the bosses, nor their acid).
static var TNT_CD := [0.0, 25.0, 18.0, 12.0]
static var TNT_FLIGHT := 0.55
# (the debug menu may change these too, see debug.gd)
static var SPEED_BASE := 360.0
static var SPEED_GAIN := 5.0
static var SPEED_SPRINT := 160.0
const RAMP := 70.0
static var JUMP_V := 760.0
static var JUMP_DOUBLE := 700.0
static var JUMP_GRAVITY := 2400.0
static var JUMP_HELD := 1500.0
# The flyer: a "!" at the right edge shows its height DART_WARN seconds before it crosses the screen.
const DART_W := 64.0
const DART_H := 40.0
static var DART_WARN := 1.0
static var DART_SPEED := 800.0
const GAP_DIST := 420.0
const GAP_TIME := 0.72
const GAP_MARGIN := 110.0
const GAP_FILL := 640.0
const DECOR_RATE := 0.12
const HOVER_W := 60.0
const HOVER_H := 56.0
# Not before this many metres: the hanging dangers, low then at head height.
static var FROM_LOW := 150.0
static var FROM_MID := 1500.0

# Mounts. `half` and `tall`: the hitbox with the hero on its back; `base` and `gain`: its pace;
# `ahead`: how fast it moves on while waiting, as a share of the hero's speed.
static var MOUNTS := {
	"gorilla": {"name": "Gorille", "jump": -820.0, "half": 34.0, "tall": 118.0, "base": 300.0, "gain": 24.0, "ahead": 0.45},
	"rhino": {"name": "Rhino", "jump": -560.0, "half": 34.0, "tall": 104.0, "smash": true, "tough": true, "time": 8.0, "grab_w": 78.0, "grab_h": 150.0, "mul": 2.0, "ramp": 420.0, "ahead": 0.0},   # mul: twice the hero's own speed, reached within a second or two (ramp)
	"dragonfly": {"name": "Libellule", "fly": true, "half": 28.0, "tall": 92.0, "base": 320.0, "gain": 56.0, "ahead": 0.5},   # gain: twice the acceleration it had
}
const MOUNT_KINDS := ["gorilla", "rhino", "dragonfly"]
static var MOUNT_FIRST := [700.0, 1000.0]   # metres: the first one, then the next ones after the last
static var MOUNT_NEXT := [1300.0, 1800.0]
static var FRIEND_K := 0.25                 # Ami de la nature: that much sooner per level
# Each mount has its own two upgrades, "<kind>Tamed" and "<kind>Magnet" (bought and switched apart).
# Dompté: caught from TAME_REACH away, waiting TAME_SLOW less fast per level, the gorilla and the
# dragonfly TAME_UP further from their height per level, the rhino TAME_RHINO above it (even jumping).
static var TAME_REACH := [70.0, 115.0, 160.0]
static var TAME_SLOW := 0.3
static var TAME_UP := 40.0
static var TAME_RHINO := 70.0
static var MOUNT_MAGNET := [0.0, 170.0, 240.0]

# Vorace's end, slowed down to be seen: the run drops to DEATH_PACE of the fight's speed while she goes
# down (DEATH_TIME seconds), then DEATH_CALM units of coins only and DEATH_EASY of a gentle road.
const DEATH_PACE := 0.3
const DEATH_TIME := 2.9
const DEATH_CALM := 900.0
const DEATH_EASY := 2600.0
static var BOSS_AT := 2000.0
static var BOSS_SPEED := 560.0
static var BOSS_FIGHT := 26.0
const BOSS_W := 446.0
const BOSS_MOUTH_X := 50.0
const BOSS_MOUTH_Y := 223.0
const LANE := {"low": 28.0, "mid": 115.0, "high": 250.0, "vine": 470.0}
# The platforms: Vorace's flying lily pads bob (PAD_BOB units, PAD_SPEED radians a second).
const PAD_BOB := 8.0
const PAD_SPEED := 1.8
const ISLE_W := [170.0, 240.0, 330.0]
const CRUISE_H := 150.0
const CRUISE_TIME := 4.0
const DART_ALTS := [[46.0, 170.0], [46.0, 170.0, 290.0], [46.0, 170.0, 290.0, 400.0, 510.0]]
# With the Vol, no height is safe for long. The hanging spiders come at every height (CURTAIN: a column
# of them with one gap two places tall, at most CURTAIN_SHIFT places from the last column's gap, so it
# can be reached in time); a flyer aims at his height when its "!" shows; and staying within CAMP_BAND
# of one height for CAMP_TIME brings one (sooner again, CAMP_AGAIN, if he stays). On foot, without the
# Vol, the ground is where he belongs: fewer flyers there, more hedgehogs and low spiders.
const CURTAIN := [128.0, 232.0, 336.0, 440.0]   # red spiders moving together: from the floor to the ceiling
const CURTAIN_SHIFT := 2
const CURTAIN_LEAD := 360.0
const SKY_HOVERS := [272.0, 376.0, 466.0]
# Never more than SPIDER_COLUMN spiders one above the other (a column): a third is not laid.
static var SPIDER_COLUMN := 2
# The spiders: the yellow ones (low, LOW) keep still; the red ones (any higher) go up and down SPIDER_AMP
# each way of their height (5 m in all) in SPIDER_PERIOD seconds, never past the floor or the ceiling.
static var SPIDER_AMP := 100.0
static var SPIDER_PERIOD := 2.4
const SPIDER_TOP := 566.0       # the highest a spider's middle goes: its back under the ceiling
# Waves of flyers: 2 at 9 m/s up to 10 at 30 m/s, 0.9 s apart down to 0.3 s. On foot they come at head
# height (stay down) or just over his head (Double saut); a low one (jump it) only with WAVE_JUMP seconds
# before the next. With the Vol each one aims at his height. Nothing else on the road while they pass.
static var WAVE_N := [2, 10]
static var WAVE_GAP := [0.9, 0.3]
const WAVE_JUMP := 0.8
# Rare floating things, zigzagging a little within reach of a jump: a life, or an hourglass (a brake: 20 %
# of his speed off, for the rest of the run, or of the scenery in Histoire). The hourglass, once on the
# screen, goes on ahead at BRAKE_PACE of his speed: it stays in sight a long time.
static var BONUS_EVERY := [1400.0, 2400.0]   # metres between two
const BONUS_LOW := 110.0
const BONUS_HIGH := 180.0
static var BRAKE_SHARE := 0.2
static var BRAKE_PACE := 0.9
const DART_TOP := 560.0                  # the highest a flyer can come: the hero's middle just under the ceiling
const CAMP_BAND := 70.0
static var CAMP_TIME := 2.6
static var CAMP_AGAIN := 1.6
# The swarms: the first one between FM_FIRST metres, the next ones FM_NEXT after the last.
static var FM_FIRST := [150.0, 230.0]
static var FM_NEXT := [170.0, 300.0]
# Dernier élan: knocked out on the last heart, he is thrown ahead (LEAP_KICK x his speed, more per
# level) and up (more the faster he ran), slows down gently and bounces once per level.
const LEAP_KICK := 1.3
const LEAP_KICK_LVL := 0.15
const LEAP_UP := 820.0
const LEAP_UP_SPEED := 0.25
const LEAP_UP_MAX := 1150.0
const LEAP_DRAG := 0.12
const LEAP_BOUNCE := 0.8
const ACID_BALL := 36.0
const ACID_PUDDLE := 120.0
const ACID_CLOSING := 650.0
const PERCH := 400.0
const ZIG_LOW := 70.0
const ZIG_HIGH := 230.0
const ZIG_PERIOD := 1.6
const HANG_Y := 190.0

# Follower monsters: FM_LANES lanes of FM_STEP each above the floor.
const FM_W := 90.0
const FM_H := 64.0
const FM_RUSH := 1150.0
const FM_LANES := 5
const FM_STEP := 110.0
const LASER_ON := 0.25
const LASER_OFF := 0.7
const LASER_END := 0.95
const LASER_H := 40.0

static var GEMS := {"y": 5, "r": 10, "b": 20}
static var SCATTER := [0.0, 0.012, 0.022, 0.035]
const HEART_GOLD := 25
# Picking up: one box, COIN_HALF to each side of him, from just under his feet to COIN_TOP above his head
# (the leaves on his head reach well above his hitbox). Rolled into a ball, as high as the ball (BALL_REACH).
# (It used to be that box and a circle round his middle: the box now has the circle's width.)
const COIN_HALF := 44.0
const COIN_TOP := 30.0
const COIN_UNDER := 4.0
const BALL_REACH := 64.0
const BALL_UNDER := 20.0
const BLAST_COINS := 30
const CELL := 44.0
const REACH := [230.0, 400.0, 600.0]
const GALLERY := 58.0
const STEP := 135.0
const HOLLOW := 66.0
const PROP_CELL := 150.0 * PIXEL
const PROP_KINDS := 9
const PROP_FERN := 3
const PROP_FLOWER := 4
const PROP_SHROOM := 5
const PROP_LANTERN := 6
const LOW := 64.0
const HEAD := 165.0
const DECOR_W := 70.0
const PLAT_KIND := ["isle", "isle", "hover", "walk"]

# Groups of coins drawn as text in reglages/patterns.txt.
static var shapes: Array = []

# ---------- the things in a run ----------

class Player:
	var y := 630.0
	var vy := 0.0
	var ground := true
	var plat = null
	var cruise := 0.0
	var jumps := 0
	var buf := 0.0
	var phase := 0.0
	var flying := false
	var rotor := false
	var flew := false        # the rotor was used since he left the ground: he drops faster (VOL_DROP)
	var spin := 0.0
	var roll := 0.0
	var inv := 0.0
	var squash := 0.0
	var hang := false
	var vine_leap := false
	var ball = null
	var balled := 0.0
	var diving := false     # Bottes de métal: plunging down, the quake when he lands

class Obs:
	var own := false              # sent at him alone (anti-camping), not part of the road
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var kind := ""
	var fragile := false
	var ghost := false
	var gone := false
	var passed := false
	var ride := false
	var biome := 0
	var ph := 0.0
	var mid := false
	var state := ""
	var t := 0.0
	var ball := false
	var lob := false
	var land := 0.0          # a blob in the air: where it will land (Vorace's fairness check)
	var drop := false
	var aim := false         # a flyer that takes his height when its "!" shows (the Vol)
	var y0 := 0.0            # a red spider: the middle of its course, and how far it goes each way
	var amp := 0.0
	var puddle := false
	var lane := 0.0
	var vx := 0.0
	var vy := 0.0
	var g := 0.0

class Coin:
	var x := 0.0
	var y := 0.0
	var gem := ""
	var heart := false
	var tight := ""
	var toss := false
	var tvx := 0.0
	var tvy := 0.0
	var loot := -1.0
	var vx := 0.0
	var vy := 0.0
	var gone := false
	var blast := false       # thrown out of the temple: it follows the floor once it rests
	func _init(px: float, py: float) -> void:
		x = px
		y = py

class Plat:
	var x := 0.0
	var y := 0.0
	var w := 254.0
	var kind := ""
	var t := 0.0
	var bobbing := false
	var y0 := 0.0
	var ph := 0.0
	var bob := 0.0
	var size := 1

class Part:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.0
	var span := 1.0
	var c := Color.WHITE
	var s := 4.0
	var g := 0.0
	var shard := -1
	var biome := 0
	var rot := 0.0
	var vr := 0.0

class Item:
	var x := 0.0
	var kind := ""
	var ph := 0.0
	var y := 0.0
	var gone := false

class Hill:
	var x := 0.0
	var w := 0.0
	var h := 0.0
	var biome := 0
	var seed := 0

class Decor:
	var x := 0.0
	var biome := 0
	var broken := false

class Zone:
	var x := 0.0
	var w := 0.0
	var kind := ""
	var im = null          # the burrow's picture, made by the renderer
	var of := -1

class Monkey:
	var x := 0.0
	var ph := 0.0
	var seen := -1.0

class Pit:
	var x0 := 0.0
	var x1 := 0.0

class Gone:
	var kind := ""
	var hang := false
	var x := 0.0
	var y := 0.0
	var t := 0.0

class Mount:
	var kind := ""
	var t := 0.0

class Boss:
	var phase := "enter"
	var t := 0.0
	var sx := 0.0
	var next := 1.2
	var wind := 0.0
	var attack := ""
	var open := 0.0
	var wx := 0.0
	var crushed := false
	var last_step := -1
	var ahead := 0.0         # the next puddle's distance ahead of the hero, chosen with the attack
	var pair_lane := 0.0     # the second ball of the next "pair"
	var last_gap := -1       # the free lanes of the last fan (the next stays within reach)

class Swarm:
	var biome := 0
	var waves := 1
	var aim := 1.7
	var act: Array = []
	var level := 0
	var phase := "aim"
	var t := 0.0
	var sx := 0.0
	var hit := false
	var ghost := false

class Active:
	var t := 0.0
	var cd := 0.0
	var full := 0.0

class Leap:
	var n := 0
	var v := 0.0

## A stick of TNT in the air (Fana de TNT): it blows up when its time is out.
class Shot:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var t := 0.0
	var spin := 0.0

class Box:
	var l := 0.0
	var r := 0.0
	var t := 0.0
	var b := 0.0

## What the player does this frame (main.gd fills it).
class Controls:
	var pressed := false
	var hold := false
	var dash := false
	var slow := false
	var stomp := false       # Bottes de métal
	var tnt := false         # Fana de TNT
	var monster := false     # RedMonster

class Shape:
	var name := ""
	var base := 0
	var rows: Array = []
	var cols := 0
	var top := 0.0

class Run:
	var mode := "story"
	var up: Dictionary = {}
	var view_w := 960.0
	var t := 0.0
	var cam := 0.0
	var sx := 10.0
	var base := 280.0
	var speed := 280.0
	var road_speed := 280.0           # the speed without the hourglasses: the road's spacing (the same seed, the same road)
	var dist := 0.0
	var gold := 0
	var gems := 0
	var hearts := 1
	var max_hearts := 1
	var p := Player.new()
	var obs: Array = []
	var coins: Array = []
	var plats: Array = []
	var parts: Array = []
	var events: Array = []
	var next_x := 1500.0
	var biome := 0
	var prev_biome := 0
	var blend := 1.0
	var next_biome_at := INF       # the first change comes once Vorace is beaten
	var by_mark := false
	var glitch := 0.0
	var calm_until := 0.0          # after the boss: only coins, then a gentle road (world x)
	var easy_until := 0.0
	var dash := Active.new()
	var slow := Active.new()
	var boots := Active.new()
	var tnt := Active.new()
	var monster := Active.new()      # RedMonster: t = the seconds at twice the speed left
	var shots: Array = []          # the sticks of TNT in the air
	var rewind_left := 0
	var dead := false
	var shake := 0.0
	var flash := 0.0
	var wait := 0.0
	var exploded := false
	var boom := 0.0
	var biome_x := -1e9             # world x where the current scenery begins
	var coop_biome_x := INF         # for two: the road's next mark, where spawn_pattern changes the scenery
	var touched := {}              # scenery that reacted: cell -> when
	var monkeys: Array = []
	var terrain: Array = [Vector2(-1e9, 630.0)]   # the floor's outline, see floor_at
	var zones: Array = []
	var items: Array = []
	var mount = null
	var gone = null
	var vine := 0.0
	var next_mount := 0.0
	var fm = null
	var fm_due := false
	var next_fm := 0.0
	var block_end := 0.0
	var leap = null
	var decor: Array = []
	var hills: Array = []
	var boss = null
	var boss_done := false
	var pits: Array = []
	var boss_at := 2000.0
	var relic := 0.0
	var own := 0.0
	var h := 0.0
	var max_h := 0.0
	var god := false
	var banked := false
	var debug := false             # started with something changed in the debug menu: no record
	var seed := 0                  # the road's seed (the same seed, the same road)
	var rng := RandomNumberGenerator.new()
	var zone_t := 0.0              # Histoire: when the current scenery began (the speed starts again)
	var zone_k := 1.0              # (unused)
	var mounts: Array = ["gorilla", "rhino", "dragonfly"]   # the animals that may wait on the road (Montures: on / off)
	var brake := 0.0               # what the brakes picked up take off his speed, for good
	var bonuses: Array = []        # the rare floating things (Item: kind "life" or "brake")
	var next_bonus := 0.0          # metres
	var camp_y := 0.0              # the height he has kept (the Vol), and for how long
	var camp_t := 0.0
	var last_gap := -1             # the gap of the last column of spiders
	var fatal := false             # the blow that ends the run has been dealt ("fatal" event: the photo)
	var spider_xs: Array = []         # where the road laid its spiders (the columns, see add_hover)
	# Coop (coop.gd): two phones, two heroes, one road. No mount nor hourglass then (they change a
	# player's speed, so his road), and the road is laid for road_tier, the lesser of the two players'.
	var coop := false
	var home := 200.0                  # where on screen he runs (PX; in coop the guest a little behind the host)
	var road_tier := -1                # what the road may ask of him (-1: what his own upgrades allow)
	var mate = null                    # the partner's last state: {x, y, vy, g, f, ph, b, d}, world units
	var bubble := false                # fallen: he floats after the partner until rescued
	var bubble_pos := Vector2.ZERO     # where his bubble is (world)
	var mate_bubble := Vector2.ZERO    # where the partner's bubble is, following him (world)
	var strip_biome := -1          # Relique altérée: a short strip of another scenery, from strip_x0 to strip_x1
	var strip_x0 := 0.0
	var strip_x1 := 0.0

	func lvl(id: String) -> int:
		return int(up.get(id, 0))

# ---------- helpers ----------

# The world's own dice. What is laid on the road (patterns, floor, waiting animals, monsters, the boss's
# attacks, the temple's gold) draws only from these, never the sparks nor a player's own bonuses (Trèfle,
# Faune alcoolisée, Brouilleur...), which use rnd / pick. So a seed gives every player the same road:
# the coop, a friend's challenge. Each run keeps its own (run.rng, seeded by new_run); update() and
# new_run() make it the current one.
static var W := RandomNumberGenerator.new()

static func wrnd(a: float, b: float) -> float:
	return a + W.randf() * (b - a)

static func wpick(arr: Array):
	return arr[W.randi() % arr.size()]

static func wshuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = W.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

static func rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)

static func pick(arr: Array):
	return arr[randi() % arr.size()]

static func colour_of(names: Array) -> Color:
	return Color(pick(names))

static func h01(i: float, s: float) -> float:
	var x = sin(i * 127.1 + s * 311.7) * 43758.5453
	return x - floor(x)

## The speed the road is laid for at x (the gaps, a wave of flyers, spiders in a row). Alone: the speed now
## (the road is laid a screen ahead, about when he gets there). For two: the speed the Run illimitée's law
## gives at x, the same on both phones whatever their frame rate, screen width or place on the screen.
static func lay_speed(run: Run, x: float) -> float:
	if not run.coop:
		return run.road_speed
	return sqrt(SPEED_BASE * SPEED_BASE + 2.0 * SPEED_GAIN * maxf(0.0, x))

## Trèfle's level as the road sees it: for two, none (its extra gems would be laid for one player only).
static func road_luck(run: Run) -> int:
	return 0 if run.coop else run.lvl("lucky")

## A run for two (main.gd): the same road on both phones, whatever their frame rate, screen, loadout or
## place on the screen. Nothing that changes one player's pace (Esquive, Sablier, Sprint, a mount, the
## hourglass, RedMonster) nor bends the road for him alone (Relique altérée, Trèfle's gems, the swarms that
## follow him).
static func coop_run(upgrades: Dictionary, seed_: int, tier: int, guest: bool) -> Run:
	var up = upgrades.duplicate()
	for id in ["dash", "slow", "sprint", "drunk", "monster"]:
		up.erase(id)
	var run = new_run(up, "endless", seed_)
	run.coop = true
	run.road_tier = tier
	run.mounts = []
	run.next_mount = INF
	run.next_fm = INF
	run.coop_biome_x = ZONE_ENDLESS * PPM
	if guest:
		run.home = PX - 70                       # just behind the host, on both screens: both are seen
	return run

static func friend(run: Run) -> float:          # Ami de la nature: mounts come that much sooner
	return 1.0 + FRIEND_K * run.lvl("nature")

## The Vol's climb at the level owned.
static func flap(run: Run) -> float:
	return FLAP_LV[clampi(run.lvl("flight"), 1, FLAP_LV.size() - 1)]

static func gem_kind() -> String:
	return pick(["y", "y", "y", "y", "y", "y", "r", "r", "r", "b"])

# Gems only turn up for whoever wears Gemmes dispersées (and as the boss's prize): elsewhere, a coin.
static func gem(run: Run) -> String:
	return gem_kind() if run.lvl("scatter") > 0 else ""

static func part(run: Run, x: float, y: float, vx: float, vy: float, mx: float, c: Color, s: float, g: float) -> Part:
	var q = Part.new()
	q.x = x
	q.y = y
	q.vx = vx
	q.vy = vy
	q.span = mx
	q.c = c
	q.s = s
	q.g = g
	run.parts.append(q)
	return q

static func coin(run: Run, x: float, y: float, gem_: String = "") -> Coin:
	var c = Coin.new(x, y)
	c.gem = gem_
	run.coins.append(c)
	return c

# ---------- shapes of coins ----------

static func set_shapes(text: String) -> void:
	var found: Array = []
	var cur: Shape = null
	var base_re = RegEx.create_from_string("base\\s+(\\d+)")
	for raw in text.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if line.begins_with("#") or line.strip_edges() == "":
			continue
		if line.begins_with("="):
			var m = base_re.search(line)
			cur = Shape.new()
			cur.name = line.substr(1).split(",")[0].strip_edges()
			cur.base = mini(12, int(m.get_string(1))) if m != null else 0
			found.append(cur)
		elif cur != null and cur.rows.size() < 14:
			cur.rows.append(line.substr(0, 40))
	var any_re = RegEx.create_from_string("[^. ]")
	shapes = []
	for s in found:
		var ok = false
		for r in s.rows:
			if any_re.search(r) != null:
				ok = true
		if ok:
			shapes.append(s)
	for s in shapes:
		var cols = 0
		for r in s.rows:
			cols = maxi(cols, r.length())
		s.cols = cols
		s.top = 40.0 + (s.base + s.rows.size() - 1) * CELL

static func lay_shape(run: Run, s: Shape, x: float, lift: float = 0.0) -> float:
	var n: int = s.rows.size()
	for r in n:
		var row: String = s.rows[r]
		var h = 40.0 + lift + (s.base + n - 1 - r) * CELL
		for k in row.length():
			var ch = row[k]
			if ch == "." or ch == " ":
				continue
			var c = coin(run, x + k * CELL, floor_at(run, x + k * CELL) - h)
			if "yrb".contains(ch) and run.lvl("scatter") > 0:
				c.gem = ch
	return s.cols * CELL

# ---------- a run ----------

## mode: "story" (Histoire: the bosses, then the sceneries every ZONE metres) or "endless" (Run
## illimitée: no boss, a new scenery every ZONE metres from the start).
static func new_run(upgrades: Dictionary, mode: String = "story", seed_: int = -1) -> Run:
	var run = Run.new()
	run.seed = seed_ if seed_ >= 0 else W.randi()
	run.rng.seed = run.seed
	W = run.rng
	run.mode = mode
	run.up = upgrades
	run.base = SPEED_BASE + (SPEED_SPRINT if run.lvl("sprint") > 0 else 0.0)
	run.speed = SPEED_BASE
	run.road_speed = SPEED_BASE
	run.hearts = HEARTS + run.lvl("heart")          # Vitalité: a heart more per level
	run.max_hearts = run.hearts
	run.dash.full = DASH_CD[mini(run.lvl("dash"), DASH_CD.size() - 1)]
	run.slow.full = SLOW_CD
	run.boots.full = BOOTS_CD[mini(run.lvl("boots"), BOOTS_CD.size() - 1)]
	run.tnt.full = TNT_CD[mini(run.lvl("tnt"), TNT_CD.size() - 1)]
	run.monster.full = MONSTER_CD[mini(run.lvl("monster"), MONSTER_CD.size() - 1)]
	run.rewind_left = 1 if run.lvl("rewind") > 0 else 0
	run.next_mount = wrnd(MOUNT_FIRST[0], MOUNT_FIRST[1]) / friend(run)
	run.next_fm = wrnd(FM_FIRST[0], FM_FIRST[1])
	run.boss_at = BOSS_AT + wrnd(-100, 100)
	run.next_bonus = wrnd(BONUS_EVERY[0], BONUS_EVERY[1]) * 0.5
	if mode == "endless":                    # no boss: the sceneries come with the marks
		run.boss_at = INF
		run.next_biome_at = ZONE_ENDLESS
		run.by_mark = true
	return run

# ---------- the floor ----------
# The floor is a line through run.terrain's points. It stays at GROUND almost everywhere: now and then
# it rises one level onto a ledge or sinks one level into a hollow, and always comes back.

static func floor_at(run: Run, x: float) -> float:
	var T: Array = run.terrain
	var i = T.size() - 1
	while i > 0 and T[i].x > x:
		i -= 1
	var a: Vector2 = T[i]
	if i + 1 >= T.size() or x <= a.x:
		return a.y
	var b: Vector2 = T[i + 1]
	return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)

static func relief(run: Run, x: float, pts: Array) -> void:
	for pt in pts:
		run.terrain.append(Vector2(x + pt[0], GROUND - pt[1]))

static func flat_at(run: Run, x: float, w: float) -> bool:
	return absf(floor_at(run, x) - floor_at(run, x + w)) < 1 and absf(floor_at(run, x) - floor_at(run, x + w / 2)) < 1

## Which scenery a spot belongs to: the new one begins at run.biome_x and scrolls in.
static func biome_at(run: Run, x: float) -> int:
	if run.strip_biome >= 0 and x >= run.strip_x0 and x < run.strip_x1:
		return run.strip_biome                   # Relique altérée: the scenery that nearly came
	return run.biome if x >= run.biome_x else run.prev_biome

## The hero starts shut inside the temple: a short rumble, then the doorway blows out and he runs.
static func launch(run: Run) -> void:
	run.wait = 0.75
	run.events.append("rumble")

# ---------- scenery the hero can brush past ----------
# Which prop stands in which cell is a pure function of the cell number, so the rules (here) and the
# drawing (render.gd) always agree without sharing any state.

static func prop_at(i: int):
	if i < 2 or h01(i, 21) < 0.42:
		return null
	return {"kind": floori(h01(i, 33) * PROP_KINDS), "x": i * PROP_CELL + h01(i, 47) * 60 * PIXEL, "flip": h01(i, 59) > 0.5}

const REACTS := {3: ["#7bd13c", 5], 4: ["#d98cff", 7], 5: ["#7dfff0", 12], 6: ["#7dfff0", 8]}

# ---------- building the road ----------

static func add_obs(run: Run, x: float, y: float, w: float, h: float, kind: String, fragile: bool) -> Obs:
	var o = Obs.new()
	o.x = x
	o.y = y
	o.w = w
	o.h = h
	o.kind = kind
	o.fragile = fragile
	# Faune alcoolisée: some creatures are tipsy ghosts of themselves and hurt nobody
	if not fragile and run.lvl("drunk") > 0 and randf() < DRUNK[run.lvl("drunk")]:
		o.ghost = true
	run.obs.append(o)
	return o

## A platform where the road needs one: during Vorace one of her flying lily pads; otherwise the
## scenery's own: a block of floating ground with a dark hill behind it (forest, ruins), a walkway
## hanging from chains (dungeon), a platform levitating on its thrusters (city).
static func add_platform(run: Run, x: float, y: float, bob: float = PAD_BOB) -> Plat:
	if run.boss != null:
		return add_pad(run, x, y, bob)
	var kind: String = PLAT_KIND[biome_at(run, x)]
	if kind == "isle":
		var behind = false
		for hl in run.hills:
			if x > hl.x + 40 and x + PLAT_W < hl.x + hl.w - 40:
				behind = true
				break
		if not behind:
			add_hill(run, x - wrnd(120, 300), wrnd(700, 1200), GROUND - y + wrnd(60, 160))
		return add_isle(run, x, y, 1)
	var pl = Plat.new()
	pl.x = x
	pl.y = y
	pl.kind = kind
	if kind == "hover":                      # it floats: a slow sway
		pl.bobbing = true
		pl.y0 = y
		pl.ph = wrnd(0, 6)
		pl.bob = 4
	run.plats.append(pl)
	return pl

static func add_pad(run: Run, x: float, y: float, bob: float = PAD_BOB) -> Plat:
	var pl = Plat.new()
	pl.x = x
	pl.y = y
	pl.y0 = y
	pl.kind = "pad"
	pl.bobbing = true
	pl.ph = wrnd(0, 6)
	pl.bob = bob
	run.plats.append(pl)
	return pl

static func add_hill(run: Run, x: float, w: float, h: float) -> void:
	var hl = Hill.new()
	hl.x = x
	hl.w = w
	hl.h = h
	hl.biome = biome_at(run, x)
	hl.seed = floori(wrnd(0, 1e6))
	run.hills.append(hl)

static func add_isle(run: Run, x: float, y: float, size: int) -> Plat:
	var pl = Plat.new()
	pl.x = x
	pl.y = y
	pl.w = ISLE_W[size]
	pl.kind = "isle"
	pl.size = size
	run.plats.append(pl)
	return pl

static func add_decor(run: Run, x: float) -> void:
	var dc = Decor.new()
	dc.x = x
	dc.biome = biome_at(run, x)
	run.decor.append(dc)

static func add_spiky(run: Run, x: float) -> void:
	add_obs(run, x, floor_at(run, x) - SPIKY_H, SPIKY_W, SPIKY_H, "spiky", false).biome = biome_at(run, x)

## A hanging danger, still in mid-air: low (`h` above the floor of its middle: jump it) or at head height.
## A hanging spider whose middle is `h` above the floor. A red one (higher than LOW) goes up and down
## round that height; spiders of one column share `ph` so its opening moves as a whole.
static func add_hover(run: Run, x: float, h: float, ph: float = -1.0) -> Obs:
	var above = 0                                # never a third spider in one column (counted on what the road
	for qx in run.spider_xs:                     # laid, never on what the player broke: the same seed, the same road)
		if absf(qx - x) < HOVER_W:
			above += 1
	if above >= SPIDER_COLUMN:
		return null
	run.spider_xs.append(x)
	if run.spider_xs.size() > 64:
		run.spider_xs = run.spider_xs.filter(func(q): return q > x - 3000)
	var o = add_obs(run, x, floor_at(run, x) - h - HOVER_H / 2, HOVER_W, HOVER_H, "hover", false)
	o.biome = biome_at(run, x)
	o.ph = ph if ph >= 0 else wrnd(0, TAU)
	o.mid = h > 100
	o.y0 = o.y
	if o.mid:
		o.amp = clampf(minf(h - HOVER_H / 2, SPIDER_TOP - h), 0, SPIDER_AMP)
	return o

## A wave of flyers from x: their number and spacing follow the speed (WAVE_*). On foot, at head height
## (stay down) or, with Double saut, just over a jump; a low one (jump it) only first, with WAVE_JUMP
## seconds before the next: a jump lasts 0.63 s, a flyer at head height must find him back on the floor.
## With the Vol, each takes his height when its "!" shows. Returns the stretch of road it takes.
static func _wave(run: Run, x: float, tier: int) -> float:
	var k = clampf((lay_speed(run, x) - SPEED_BASE) / (1200.0 - SPEED_BASE), 0, 1)
	var n = clampi(roundi(lerpf(WAVE_N[0], WAVE_N[1], k) * wrnd(0.6, 1.0)), WAVE_N[0], WAVE_N[1])
	var dt_ = lerpf(WAVE_GAP[0], WAVE_GAP[1], k)
	var v = maxf(lay_speed(run, x), 1.0)
	var at = 0.0
	for i in n:
		var alt = 170.0
		if tier >= 2:
			alt = wpick(DART_ALTS[2])
		elif i == 0 and W.randf() < 0.5:
			alt = 46.0                               # first: a low one, then room to land
		elif tier == 1 and W.randf() < 0.4:
			alt = 290.0                              # passes over a short jump, under nothing: never in the way
		var o = add_dart(run, x + at * v, alt)
		o.aim = tier >= 2
		at += maxf(dt_, WAVE_JUMP) if alt == 46.0 else dt_
	return at * v + DART_W + 200

## A rare floating thing: a life or a brake, zigzagging a little within reach of a jump.
static func add_bonus(run: Run, x: float) -> void:
	var it = Item.new()
	it.x = x
	var roll = W.randf()
	it.kind = "life" if roll < 0.5 or run.coop else "brake"   # (no hourglass in coop: it would change his speed)
	it.ph = wrnd(0, 2)
	it.y = floor_at(run, x) - BONUS_LOW
	run.bonuses.append(it)

## A flyer: it waits beyond the right edge until the screen reaches it, shows a "!" at its height, then crosses.
static func add_dart(run: Run, x: float, alt: float, own: bool = false) -> Obs:
	var o = add_obs(run, x, floor_at(run, x) - alt - DART_H / 2, DART_W, DART_H, "dart", false)
	o.biome = biome_at(run, x)
	o.state = "wait"
	o.t = 0
	o.ph = rnd(0, 6) if own else wrnd(0, 6)      # (own: sent at him, at a moment of his: not the road's dice)
	o.own = own
	return o

static func coin_line(run: Run, x: float, y: float, n: int) -> void:
	for i in n:
		coin(run, x + i * 44, y)

static func coin_arc(run: Run, x: float, peak: float, n: int, span: float) -> void:
	for i in n:
		var k = float(i) / (n - 1)
		coin(run, x + span * k, floor_at(run, x + span * k) - 40 - peak * 4 * k * (1 - k))

static func burst(run: Run, x: float, y: float, color: Color, n: int, spd: float = 220.0) -> void:
	for i in n:
		var a = rnd(0, TAU)
		var v = rnd(spd * 0.3, spd)
		part(run, x, y, cos(a) * v, sin(a) * v - 80, rnd(0.3, 0.7), color, rnd(4, 9), 700)

# A tight place and what it holds: coins all along, a few gems, once in a blue moon a heart.
static func tight(run: Run, kind: String, x: float, w: float, y: float) -> void:
	var z = Zone.new()
	z.x = x
	z.w = w
	z.kind = kind
	run.zones.append(z)
	var count = floori((w - 160) / 40)
	for i in count:
		var c = coin(run, x + 80 + i * 40, y)
		c.tight = kind
		if i % 6 == 3:
			c.gem = gem(run)
	if W.randf() < 0.03:
		var c = coin(run, x + w - 70, y)
		c.tight = kind
		c.heart = true

# Gemmes dispersées: among the coins just laid, a few turn into gems.
static func scatter(run: Run, start: int) -> void:
	var rate: float = SCATTER[run.lvl("scatter")]
	if rate <= 0:
		return
	for i in range(start, run.coins.size()):
		var c: Coin = run.coins[i]
		if c.gem == "" and not c.heart and randf() < rate:
			c.gem = gem_kind()

# ---------- spawning ----------
# One pattern at run.next_x, then a gap sized on the current speed so it stays fair. What can appear
# depends on what the player owns: nothing asks for a skill not bought yet.

static func spawn_pattern(run: Run) -> void:
	var laid = run.coins.size()
	if run.mount != null and run.fm == null and not run.fm_due and run.boss == null:
		spawn_ride(run)
		scatter(run, laid)
		return
	var x = run.next_x
	if x >= run.coop_biome_x:                        # for two: the next scenery begins at the first pattern past
		run.prev_biome = run.biome                   # the mark, the same on both phones (alone: update(), when
		run.biome = NEXT_BIOME[run.biome]            # he reaches the mark, just off screen)
		run.biome_x = x
		run.coop_biome_x = (floorf(x / (ZONE_ENDLESS * PPM)) + 1) * ZONE_ENDLESS * PPM
	var G = GROUND
	var tier = tier_of(run)
	var riding = run.mount != null or run.items.size() > 0
	# The first metres are a warm-up: one obstacle at a time, nothing in the air.
	var opts: Array
	if x < 70 * PPM:
		opts = ["spiky", "spiky", "coins", "plat", "ledge", "hollow"]
	else:
		opts = ["spiky", "spiky", "double", "perch", "hop", "fly", "coins", "plat", "plat", "cave", "log", "gallery", "stairs", "ledge", "ledge", "hollow",
			"hills", "hills", "hills", "padchain", "padchain", "padchain", "padzig", "padzig"]
	if x / PPM >= FROM_LOW:                          # many spiders: dangers at every height
		opts.append_array(["hover", "hover", "hover", "hover", "hover", "spiders", "spiders", "spiders"])
	if x / PPM >= 150:                               # flyers come in waves too
		opts.append("wave")
	if tier < 2 and x >= 70 * PPM:                   # on foot: fewer flyers, more hedgehogs and low spiders
		opts.erase("fly")
		opts.append_array(["spiky", "lowhover", "lowhover"] if x / PPM >= FROM_LOW else ["spiky"])
	if tier >= 2 and x >= 70 * PPM:                  # the Vol: dangers at every height
		opts.append_array(["fly", "wave", "wave", "skyhover", "skyhover", "skyhover", "curtain", "curtain", "curtain", "curtain"])
	var fit: Array = shapes.filter(func(s): return s.top <= REACH[tier])
	if fit.size() > 0 and x >= 70 * PPM:
		opts.append_array(["shape", "shape"])
	if tier < 2 and shapes.size() > 0 and x >= 70 * PPM:
		opts.append("skyshape")
	if riding:
		opts = opts.filter(func(k): return k != "cave")
	if x < run.calm_until:
		opts = ["coins"]
	elif x < run.easy_until:
		opts = ["spiky", "coins", "coins", "plat", "ledge", "hollow"]
	if run.fm != null or run.fm_due:
		opts = ["coins"]
	elif run.boss != null:
		opts = ["plat", "plat", "steps", "padchain", "coins"]
	elif not riding and x > 70 * PPM and x / PPM >= run.next_mount and run.mounts.size() > 0:
		opts = ["mount"]
	var kind: String = wpick(opts)
	var extent = 0.0

	match kind:
		"spiky":
			add_spiky(run, x)
			extent = SPIKY_W
		"shape":
			extent = lay_shape(run, wpick(fit), x)
		"hover":
			if tier >= 2 and x / PPM >= FROM_LOW and W.randf() < 0.5:   # the Vol: any height
				add_hover(run, x + 88, wpick([LOW, HEAD] + SKY_HOVERS))
			elif x / PPM < FROM_MID or W.randf() < 0.6:
				add_hover(run, x, LOW)
			else:                                  # at head height: coins underneath, for whoever stays down
				add_hover(run, x + 88, HEAD)
				coin_line(run, x, floor_at(run, x) - 40, 5)
			extent = 220
		"spiders":                                 # two or three spiders in a row: a still yellow one (jump it), red ones moving
			var n = 2 + W.randi() % 2
			for i in n:
				var h = LOW if i % 2 == 0 else (wpick([HEAD] + SKY_HOVERS) if tier >= 2 else HEAD)
				add_hover(run, x + i * maxf(320, lay_speed(run, x) * 0.9), h)
			extent = (n - 1) * maxf(320, lay_speed(run, x) * 0.9) + HOVER_W
		"lowhover":                                # a low spider: jump it
			add_hover(run, x, LOW)
			coin_arc(run, x - 40, 150, 5, 160)
			extent = 220
		"skyhover":                                # a spider high up, coins just under it
			var h: float = wpick(SKY_HOVERS)
			add_hover(run, x + 120, h)
			coin_line(run, x, floor_at(run, x) - (h - 110), 7)
			extent = 400
		"curtain":                                 # a column of two red spiders moving together, two places empty: through there
			var g = W.randi() % (CURTAIN.size() - 1)   # the lower of the two free places
			if run.last_gap >= 0:
				g = clampi(g, run.last_gap - CURTAIN_SHIFT, run.last_gap + CURTAIN_SHIFT)
			run.last_gap = g
			var cx = x + CURTAIN_LEAD
			var ph = wrnd(0, TAU)
			for k in CURTAIN.size():
				if k != g and k != g + 1:
					add_hover(run, cx, CURTAIN[k], ph)
			for i in 5:                            # coins where the gap is in the middle of its course
				coin(run, cx - 140 + i * 70, floor_at(run, cx) - (CURTAIN[g] + CURTAIN[g + 1]) / 2)
			extent = CURTAIN_LEAD + HOVER_W + 120
		"double":
			var d = lay_speed(run, x) + 90
			add_spiky(run, x)
			add_spiky(run, x + d)
			extent = d + SPIKY_W
		"fly":
			add_dart(run, x, wpick(DART_ALTS[tier])).aim = tier >= 2
			extent = 120
		"wave":                                      # a wave of flyers, more and closer together the faster he goes
			extent = _wave(run, x, tier)
		"swarm":                                     # two flyers, one after the other, at different heights
			var alts: Array = DART_ALTS[2].duplicate()
			wshuffle(alts)
			add_dart(run, x, alts[0]).aim = true
			add_dart(run, x + 520, alts[1])
			extent = 520
		"perch":                                     # a platform over a hedgehog: jump over it, or onto it
			var y = G - 135
			add_platform(run, x, y)
			coin_line(run, x + 40, y - 40, 4)
			add_spiky(run, x + PLAT_W / 2 - SPIKY_W / 2)
			extent = PLAT_W
		"hop":                                       # a hedgehog under an arch of coins
			add_spiky(run, x + 140)
			coin_arc(run, x + 40, 150, 7, 260)
			extent = 320
		"steps":                                     # two ledges climbing (the boss fight)
			for k in 2:
				var px = x + k * 300
				var py = G - 120 - k * 112
				add_platform(run, px, py)
				coin_line(run, px + 60, py - 40, 3)
			extent = 300 + PLAT_W
		"plat":                                      # a platform to hop on, with a reward
			var y = G - 135
			add_platform(run, x, y)
			coin_line(run, x + 40, y - 40, 4)
			if W.randf() < 0.35 + 0.2 * road_luck(run):   # (the road's dice, always rolled: only the odds are his)
				coin(run, x + PLAT_W / 2, y - 110, gem(run))
			extent = PLAT_W
		"cave":                                      # two ways: down through the hollow, or over its roof
			var R = 70.0
			var w = roundf(wrnd(800, 1200))
			var y = G - SLAB_H
			relief(run, x, [[0, 0], [R, -HOLLOW], [R + w, -HOLLOW], [2 * R + w, 0]])
			var pl = Plat.new()
			pl.x = x + R
			pl.y = y
			pl.w = w
			pl.t = SLAB_T
			pl.kind = "slab"
			run.plats.append(pl)
			coin_line(run, x + R + w * 0.25, G + HOLLOW - 40, floori(w * 0.5 / 44))
			coin_line(run, x + R + 70, y - 40, mini(16, floori((w - 140) / 60)))
			coin(run, x + R + w - 60, y - 110, gem(run))
			var mk = Monkey.new()
			mk.x = x + R + w * wrnd(0.3, 0.7)
			mk.ph = wrnd(0, 6)
			run.monkeys.append(mk)
			extent = 2 * R + w
		"hollow":                                    # one level down for a while, coins at the bottom
			var R = 70.0
			var w = roundf(wrnd(600, 950))
			relief(run, x, [[0, 0], [R, -HOLLOW], [R + w, -HOLLOW], [2 * R + w, 0]])
			coin_line(run, x + R + 30, G + HOLLOW - 40, floori((w * 0.4) / 44))
			if x > 70 * PPM:
				add_spiky(run, x + R + w * 0.7)
			extent = 2 * R + w
		"ledge":                                     # one level up for a while
			var R = 150.0
			var w = roundf(wrnd(700, 1100))
			relief(run, x, [[0, 0], [R, STEP], [R + w, STEP], [2 * R + w, 0]])
			if x > 70 * PPM and W.randf() < 0.6:
				add_spiky(run, x + R + w * 0.55)
			else:
				coin_line(run, x + R + 60, G - STEP - 40, 6)
			extent = 2 * R + w
		"log":                                       # a hollow trunk behind the path: only a ball gets in
			tight(run, "log", x, LOG_W, G - 24)
			extent = LOG_W
		"gallery":                                   # a gallery under the path: the same
			var w = roundf(wrnd(800, 1200))
			tight(run, "gallery", x, w, G + GALLERY - 22)
			extent = w
		"stairs":                                    # three ledges climbing to the canopy
			for k in 3:
				var px = x + k * 300
				var py = G - 120 - k * 112
				add_platform(run, px, py)
				coin_line(run, px + 60, py - 40, 3)
			coin(run, x + 600 + PLAT_W / 2, G - 344 - 110, gem(run))
			var mk = Monkey.new()
			mk.x = x + 600 + PLAT_W * 0.6
			mk.ph = wrnd(0, 6)
			run.monkeys.append(mk)
			add_spiky(run, x + 420)
			extent = 600 + PLAT_W
		"hills":                                     # a dark hill, and its scenery's platforms in front of it
			var w = roundf(wrnd(700, 1500))
			var h = roundf(wrnd(160, 520))
			add_hill(run, x, w, h)
			var n: int = wpick([2, 3, 3]) if tier >= 1 else wpick([2, 2, 3])
			var rise = 125.0 if tier >= 1 else 105.0     # a plain jump reaches 120
			var ix = x + wrnd(20, 80)
			for k in n:
				var size: int = wpick([0, 1, 1, 2])
				var lvl_k = 1 if (k == n - 1 and n > 2) else k
				var iy = G - 130 - lvl_k * rise - (k % 2) * 20
				var pl: Plat
				if PLAT_KIND[biome_at(run, ix)] == "isle":
					pl = add_isle(run, ix, iy, size)
				else:
					pl = add_platform(run, ix, iy)
				coin_line(run, ix + 30, iy - 40, maxi(2, floori((pl.w - 60) / 44)))
				ix += pl.w + wrnd(70, 150)
			if W.randf() < 0.3 + 0.2 * road_luck(run):
				coin(run, ix - 120, G - 130 - (n - 1) * rise - 110, gem(run))
			if x > 70 * PPM and W.randf() < 0.65:     # below, a hedgehog: up there is the safe way
				add_spiky(run, x + wrnd(0.3, 0.6) * (ix - x))
			extent = maxf(w, ix - x)
		"padchain":                                  # pads one after the other, up and down, bobbing out of step
			var hs: Array = wpick([[135, 220, 135, 250], [135, 200, 265, 200], [180, 135, 220, 135], [135, 235, 135]])
			for k in hs.size():
				var px = x + k * 320
				add_platform(run, px, G - hs[k], PAD_BOB + k * 3)
				coin_line(run, px + 60, G - hs[k] - 40, 3)
			if x > 70 * PPM and run.boss == null and W.randf() < 0.5:
				add_spiky(run, x + 320 + PLAT_W / 2)
			extent = hs.size() * 320
		"padzig":                                    # a climb from pad to pad, a gem at the top
			var n = 4 if tier >= 1 else 3
			for k in n:
				var px = x + k * 260
				var py = G - 130 - k * 105
				add_platform(run, px, py, 5)
				coin_line(run, px + 70, py - 40, 2)
			coin(run, x + (n - 1) * 260 + PLAT_W / 2, G - 130 - (n - 1) * 105 - 110, gem(run))
			extent = (n - 1) * 260 + PLAT_W
		"skyshape":                                  # a drawing of coins up in the sky: only the Vol gets there
			var s: Shape = wpick(shapes)
			var lift = maxf(0, REACH[tier] + 60 - (40 + s.base * CELL))
			extent = lay_shape(run, s, x, minf(lift, REACH[2] - 40 - s.top))
		"mount":                                     # an animal waiting: a trail of coins leads to it
			coin_line(run, x, G - 40, 5)
			var it = Item.new()
			it.x = x + 330
			it.kind = wpick(run.mounts)
			it.ph = wrnd(0, ZIG_PERIOD * 2)
			it.y = G - ZIG_LOW
			run.items.append(it)
			run.next_mount = x / PPM + wrnd(MOUNT_NEXT[0], MOUNT_NEXT[1]) / friend(run)
			extent = 460
	# Under a roof nobody can jump, so nothing there may have to be jumped over.
	for pl in run.plats:
		if pl.t > 0:
			for o in run.obs:
				if o.x + o.w > pl.x - 30 and o.x < pl.x + pl.w + 30 and o.y + o.h > pl.y + pl.t:
					o.gone = true
	if kind != "coins" and kind != "mount":
		run.block_end = x + extent

	# The gap to the next pattern is set in distance (GAP_DIST), so the road keeps its density as the
	# speed grows; only where a jump would no longer have room to land does it widen with the speed.
	var gap = maxf(GAP_DIST, lay_speed(run, x) * GAP_TIME + GAP_MARGIN) * wrnd(0.85, 1.3) * (1.3 if kind == "coins" else 1.0)
	var clear = run.fm == null and not run.fm_due and run.boss == null and kind != "wave"
	if clear and x / PPM >= run.next_bonus and x / PPM > 300:   # a life or a brake, floating in the gap
		add_bonus(run, x + extent + gap * 0.5)
		run.next_bonus = x / PPM + wrnd(BONUS_EVERY[0], BONUS_EVERY[1])
		clear = false
	# A wide gap gets something that asks no jump: a danger at head height, or a fonceur.
	if gap > GAP_FILL and x / PPM >= FROM_MID and clear and W.randf() < 0.5:
		add_hover(run, x + extent + gap * 0.5, HEAD)
	elif gap > GAP_FILL and x / PPM > 150 and clear and W.randf() < (0.35 if tier >= 2 else 0.15):
		add_dart(run, x + extent + gap * 0.5, 170).aim = tier >= 2
	if x / PPM > 70 and run.boss == null and W.randf() < DECOR_RATE:
		add_decor(run, x + extent + gap * wrnd(0.3, 0.6))     # something to smash
	if x / PPM > 40 and kind != "hills" and W.randf() < 0.22:
		add_hill(run, x + extent + gap * wrnd(-0.2, 0.3), wrnd(500, 1400), wrnd(100, 480))   # scenery only
	if kind == "coins" or W.randf() < 0.55:
		var n = mini(8, floori((gap - 200) / 44))
		var cx = x + extent + 100
		if n >= 3:
			var calm = run.fm == null and not run.fm_due
			var styles: Array
			if tier == 2 and calm:
				styles = ["line", "arc", "wave", "wave", "zig", "steps", "double"]
			else:
				styles = ["line", "line", "arc", "zig", "steps", "double"]
				if calm and x > 300 * PPM:
					styles.append("sky")
			var style: String = wpick(styles)
			if style == "arc":
				coin_arc(run, cx, 200.0 if tier > 0 else 110.0, n, (n - 1) * 44)
			else:
				for i in n:
					var wx = cx + i * 44
					var f = floor_at(run, wx)
					var h = 40.0
					match style:
						"wave": h = 320 - sin(i * 0.7) * 130
						"zig": h = 120.0 if i % 2 == 1 else 50.0       # up and down: hops
						"steps": h = 40 + mini(i, n - 1 - i) * 30         # a little hill of coins
						"sky": h = 400 + sin(i * 0.9) * 30               # out of reach without the Vol
					coin(run, wx, f - h)
					if style == "double":
						coin(run, wx, f - 84)                           # two rows, both caught at a run (the top one by the leaves on his head)
			if W.randf() < 0.12 * road_luck(run) and run.lvl("scatter") > 0:
				coin(run, cx + n * 44 + 30, floor_at(run, cx + n * 44 + 30) - 110, gem(run))
	run.next_x = x + extent + gap
	scatter(run, laid)

# Coins along the sides of a regular shape: 4 sides is a diamond (or a square, turned), 12 a circle.
static func shape(run: Run, cx: float, cy: float, r: float, sides: int, each: int, turn: float) -> void:
	for k in sides:
		var a = turn + k * TAU / sides
		var b = turn + (k + 1) * TAU / sides
		for i in each:
			var t = float(i) / each
			coin(run, cx + r * (sin(a) + (sin(b) - sin(a)) * t), cy - r * (cos(a) + (cos(b) - cos(a)) * t))

# What comes while a mount is ridden. The gorilla plays on the floor and under the vines; the rhino on
# the floor only; the dragonfly everywhere. Flat ground throughout, and creatures that keep their place.
static func spawn_ride(run: Run) -> void:
	var x = run.next_x
	var G = GROUND
	var v = run.speed
	var kind: String = run.mount.kind
	var extent = 0.0
	var first = run.obs.size()

	if kind == "gorilla":
		var top = HANG_Y - 50
		var vines = G - HANG_Y + 62                    # coins and creatures along the vines
		var reach = v * 0.9 + 280                       # room to get from the floor to the vines, or back
		match wpick(["low", "high", "both", "both", "gauntlet", "gauntlet", "darts", "darts", "double", "swing", "diag", "line"]):
			"gauntlet":                                  # the floor, then the vines, then the floor again
				var k0 = W.randf() < 0.5
				for k in 3:
					var at = x + k * reach
					if (k % 2 == 0) == k0:
						add_spiky(run, at)
					else:
						add_hover(run, at, vines)
				extent = 2 * reach + 70
			"darts":                                     # fonceurs along the vines and along the floor
				var order = [vines - 30, 46.0] if W.randf() < 0.5 else [46.0, vines - 30]
				add_dart(run, x, order[0])
				add_dart(run, x + reach + 200, order[1])
				extent = reach + 320
			"double":                                    # two on the floor: up you go
				add_spiky(run, x)
				add_spiky(run, x + v * 0.5 + 120)
				coin_line(run, x, top, 10)
				extent = v * 0.5 + 200
			"swing":                                     # coins swinging from the floor to the vines over a hedgehog
				for i in 12:
					coin(run, x + i * 44, G - 40 + (top - G + 40) * sin(i / 11.0 * PI))
				add_spiky(run, x + 5.5 * 44 - SPIKY_W / 2)
				extent = 520
			"low":
				add_spiky(run, x + 120)
				coin_line(run, x, top, 8)
				extent = 320
			"high":
				add_hover(run, x + 120, vines)
				coin_line(run, x, G - 40, 8)
				extent = 320
			"both":
				if W.randf() < 0.5:
					add_spiky(run, x)
					add_hover(run, x + reach, vines)
				else:
					add_hover(run, x, vines)
					add_spiky(run, x + reach)
				extent = reach + 70
			"diag":
				var rising = W.randf() < 0.5
				for i in 10:
					var k = i / 9.0
					coin(run, x + i * 44, G - 40 + (top - G + 40) * (k if rising else 1.0 - k))
				extent = 400
			"line":
				coin_line(run, x, top if W.randf() < 0.5 else G - 40, 10)
				extent = 400
	elif kind == "rhino":
		match wpick(["crates", "crates", "spiky", "spiky", "mix", "line", "heap", "heap"]):
			"crates":                                    # scenery to charge through, coins along it
				var count = 1 + W.randi() % 3
				for k in count:
					add_decor(run, x + k * 170)
				coin_line(run, x + 30, G - 40, count * 4 - 1)
				extent = count * 170
			"spiky":
				add_spiky(run, x)
				extent = SPIKY_W
			"mix":
				add_decor(run, x)
				add_spiky(run, x + v * 0.7 + 260)
				extent = v * 0.7 + 260 + SPIKY_W
			"line":
				coin_line(run, x, G - 40, 12)
				extent = 500
			"heap":                                      # two rows at a run, the third for a hop
				coin_line(run, x, G - 40, 5)
				coin_line(run, x + 22, G - 78, 4)
				coin_line(run, x + 44, G - 116, 3)
				extent = 200
	else:
		var lanes = [70.0, 180.0, 290.0, 400.0, 510.0]   # heights above the floor
		match wpick(["flyers", "flyers", "flyers", "gate", "gate", "gate", "tower", "zigzag", "shape"]):
			"flyers":                                # (three times what it was: the dragonfly's sky is full)
				var mixed: Array = lanes.duplicate()
				wshuffle(mixed)
				mixed = mixed.slice(0, 5 if W.randf() < 0.4 else 4)
				for k in mixed.size():
					add_hover(run, x + k * 200, mixed[k])
				extent = mixed.size() * 200
			"gate":                                      # two creatures in a column, a wide opening next to them
				var open = W.randi() % 4
				var gph = wrnd(0, TAU)
				var closed: Array = []
				for k in lanes.size():
					if k != open and k != open + 1:
						closed.append(k)
				wshuffle(closed)
				for k in closed.slice(0, SPIDER_COLUMN):
					add_hover(run, x + 200, lanes[k], gph)
				coin_line(run, x, G - (lanes[open] + lanes[open + 1]) / 2, 8)
				extent = 360
			"tower":                                     # a column of creatures from the floor up: over the top
				var count = SPIDER_COLUMN
				var tph = wrnd(0, TAU)
				for k in count:
					add_hover(run, x + 110, 60 + k * 110, tph)
				coin_line(run, x, G - 60 - count * 110 - 30, 6)
				extent = 260
			"zigzag":                                    # each slope lasts over a second, whatever the speed
				var half = maxi(7, ceili(v * 1.2 / 44))
				var count = half * 3
				for i in count:
					var k = i % (2 * half)
					var f = float(k) / half if k < half else float(2 * half - k) / half
					coin(run, x + i * 44, 150 + (G - 250) * f)
				extent = count * 44
			"shape":
				var drawn: Array = shapes.filter(func(s): return s.top <= REACH[2] - 80)
				if drawn.size() > 0 and W.randf() < 0.6:
					var s: Shape = wpick(drawn)
					extent = lay_shape(run, s, x, wrnd(0, REACH[2] - 80 - s.top))
				else:
					var fig: Array = wpick([[4, 3, 0.0], [4, 3, PI / 4], [3, 4, 0.0], [12, 1, 0.0]])
					shape(run, x + 100, wrnd(210, G - 190), 96, fig[0], fig[1], fig[2])
					extent = 200
	# laid for the ride: if the animal is lost, what was laid for it goes too (see dismount)
	for i in range(first, run.obs.size()):
		run.obs[i].ride = true
	run.block_end = x + extent
	run.next_x = x + extent + (v * 0.7 + 220) * wrnd(0.9, 1.3) * (0.4 if kind == "dragonfly" else 1.0)

# ---------- the boss ----------

static func _boss_ball(run: Run, mouth: Vector2, h: float) -> void:      # a ball along a lane, h above the floor
	var o = add_obs(run, mouth.x, mouth.y, ACID_BALL, ACID_BALL, "acid", false)
	o.ghost = false
	o.ball = true
	o.lane = GROUND - h - ACID_BALL / 2
	o.vx = run.speed - ACID_CLOSING

static func _boss_lob(run: Run, mouth: Vector2, ahead: float, T: float = 0.9) -> void:   # a blob that lands `ahead` of the hero
	var land = run.cam + run.sx + ahead + run.speed * T
	var g = 1600.0
	var o = add_obs(run, mouth.x, mouth.y, ACID_BALL, ACID_BALL, "acid", false)
	o.ghost = false
	o.lob = true
	o.land = land
	o.vx = (land - mouth.x) / T
	o.vy = (GROUND - ACID_BALL - mouth.y - 0.5 * g * T * T) / T
	o.g = g

# ---------- Vorace's fairness ----------
# Every danger she sends is met by the hero over a span of time, and asks him either to be off the ground
# then ("air": a puddle, a low ball) or to stay on it ("ground": a ball at middle height, which a jump
# runs into). A ball up high passes over a short jump: it never decides anything. A new attack is only
# thrown if, with the dangers already on their way, a short jump (TAP_AIR in the air) still gets him
# through everything, with REACT seconds to spare between two moves.
static var TAP_AIR := 0.6333          # JUMP_V up, JUMP_GRAVITY down (tune.gd works it out again)
const REACT := 0.2
const WIND := 0.45                   # her jaws open this long before she fires
const FAN_LANES := [64.0, 168.0, 272.0, 376.0, 480.0, 560.0]   # up to the ceiling
const FLY_PACE := 1.3                # against a flyer she fires 1.3 times as often
const SLACK := 0.06

## When the hero will meet what lies from x0 to x1 (world units), closing in at `rel`, `delay` seconds from now.
static func _span(run: Run, x0: float, x1: float, rel: float, delay: float, need: String) -> Array:
	var hx = run.cam + run.sx
	return [delay + (x0 - hx - HERO_HALF) / rel, delay + (x1 - hx + HERO_HALF) / rel, need]

static func _ball_need(h: float) -> String:
	if h < 60:
		return "air"                             # at his feet: jump it
	if h < 200:
		return "ground"                          # at his head: a jump runs into it
	return ""

## What is already on its way.
static func _threats(run: Run) -> Array:
	var v = maxf(run.speed, BOSS_SPEED)          # the speed he settles at in the fight: the tightest timing
	var out: Array = []
	for o in run.obs:
		if o.kind != "acid" or o.gone:
			continue
		if o.puddle:
			out.append(_span(run, o.x, o.x + o.w, v, 0, "air"))
		elif o.lob:
			out.append(_span(run, o.land - (ACID_PUDDLE - ACID_BALL) / 2, o.land + (ACID_PUDDLE + ACID_BALL) / 2, v, 0, "air"))
		elif o.drop:
			out.append(_span(run, o.x - 27, o.x + 63, v, 0, "air"))
		elif o.ball:
			var need = _ball_need(GROUND - o.lane - ACID_BALL / 2)
			if need != "":
				out.append(_span(run, o.x, o.x + o.w, ACID_CLOSING, 0, need))
	return out.filter(func(t): return t[1] > 0)

## What an attack would add, thrown WIND seconds from now (b.ahead and b.pair_lane already chosen).
static func _attack_threats(run: Run, b: Boss, move: String) -> Array:
	var v = maxf(run.speed, BOSS_SPEED)          # the speed he settles at in the fight: the tightest timing
	var at = run.cam + run.sx + run.speed * WIND     # where he will be when she fires
	var rel_mouth = run.cam + b.sx + BOSS_MOUTH_X     # the balls leave from her mouth
	var out: Array = []
	var puddle_at = func(ahead: float, w: float, left: float) -> void:
		var land = at + ahead + v * 0.9
		out.append(_span(run, land - left, land - left + w, v, 0, "air"))
	var ball = func(h: float) -> void:
		var need = _ball_need(h)
		if need != "":
			out.append(_span(run, rel_mouth, rel_mouth + ACID_BALL, ACID_CLOSING, WIND, need))
	match move:
		"puddle": puddle_at.call(b.ahead, ACID_PUDDLE, (ACID_PUDDLE - ACID_BALL) / 2)
		"spray":
			puddle_at.call(320.0, ACID_PUDDLE, (ACID_PUDDLE - ACID_BALL) / 2)
			puddle_at.call(760.0, ACID_PUDDLE, (ACID_PUDDLE - ACID_BALL) / 2)
		"rain":
			puddle_at.call(420.0, 90.0, 27.0)
			puddle_at.call(860.0, 90.0, 27.0)
		"low", "mid", "high": ball.call(LANE[move])
		"pair":
			ball.call(LANE["high"])
			ball.call(b.pair_lane)
	return out

## Whether one short jump, or staying down, gets him through both. `slack` widens the room asked for:
## an attack is only thrown with some to spare (where it lands is a prediction).
static func _fits(a: Array, c: Array, slack: float = 0.0) -> bool:
	var first = a if a[0] <= c[0] else c
	var second = c if a[0] <= c[0] else a
	var gap = REACT + slack
	if first[2] == "ground" and second[2] == "ground":
		return true                              # stay down for both
	if first[2] == "air" and second[2] == "air":  # room to land between them, or both under one easy jump
		return second[0] >= first[1] + gap or second[1] - first[0] <= TAP_AIR - 2 * gap
	var air = first if first[2] == "air" else second
	var low = second if first[2] == "air" else first
	if low[1] <= air[0]:
		return low[1] + gap <= air[0]            # the head-high ball goes by, then the jump
	if low[0] >= air[1]:
		return air[1] + gap <= low[0]            # the jump lands, then the ball goes by
	return false

static func _attack_fits(run: Run, b: Boss, move: String, now: Array) -> bool:
	var adds = _attack_threats(run, b, move)
	for i in adds.size():
		for t in now:
			if not _fits(adds[i], t, SLACK):
				return false
		for j in range(i + 1, adds.size()):
			if not _fits(adds[i], adds[j], SLACK):
				return false
	return true

## The Vol: whoever keeps one height (within CAMP_BAND) for CAMP_TIME gets a flyer aimed at it, unless
## a flyer is already on its way or something near that height is coming anyway (he must move for it).
static func camp(run: Run, dt: float) -> void:
	var p = run.p
	if run.lvl("flight") == 0 or run.mount != null or run.boss != null or run.fm != null or run.fm_due or run.leap != null or run.dead or run.sx < run.home:
		run.camp_t = 0
		return
	if absf(p.y - run.camp_y) > CAMP_BAND:
		run.camp_y = p.y
		run.camp_t = 0
		return
	run.camp_t += dt
	if run.camp_t < CAMP_TIME:
		return
	var px = run.cam + run.sx
	var alt = floor_at(run, px) - (p.y - HERO_H / 2)
	var window = px + run.speed * (DART_WARN + 1.0)   # where he will be when it reaches him
	for o in run.obs:
		if o.gone:
			continue
		if o.kind == "dart" and o.x < run.cam + run.view_w + 900:
			return                                   # one flyer at a time
		if o.kind != "dart" and o.x + o.w > px and o.x < window:
			var oa = floor_at(run, o.x) - (o.y + o.h / 2)
			if absf(oa - alt) < 160:
				return                               # something at his height is coming: that will move him
	var dt_ = add_dart(run, run.cam + run.view_w + 80, clampf(alt, DART_ALTS[0][0], DART_TOP), true)
	dt_.aim = true
	run.camp_t = CAMP_TIME - CAMP_AGAIN

static func boss(run: Run, d: float) -> void:
	var p = run.p
	if run.boss == null:
		if run.boss_done or run.dist < run.boss_at or run.biome != 0 or run.prev_biome != 0:
			return                                   # only ever in the forest
		var nb = Boss.new()
		nb.sx = run.view_w + 60
		run.boss = nb
		run.items.clear()                            # no mount waiting during the fight
		for o in run.obs:                            # nor any other danger: Vorace alone
			if not o.gone and o.x + o.w > run.cam + run.sx + 40:
				o.gone = true
				for i in 6:
					part(run, o.x + rnd(0, o.w), o.y + rnd(0, o.h), rnd(-80, 80), rnd(-160, -20), rnd(0.3, 0.6), colour_of(["#f4f0e0", "#cfd3e6"]), rnd(6, 14), -60)
		run.relic = 1
		run.shake = maxf(run.shake, 0.6)
		run.events.append("boss")
		return
	var b: Boss = run.boss
	var mouth = Vector2(run.cam + b.sx + BOSS_MOUTH_X, BOSS_MOUTH_Y)
	b.t += d
	b.open = maxf(0, b.open - d)
	if b.phase == "enter":                           # it slides in from the right edge
		b.sx += (run.view_w - BOSS_W + BOSS_BACK - b.sx) * minf(1, d * 2.5)
		if b.t > 1.6:
			b.phase = "fight"
			b.t = 0
		return
	if b.phase == "fight":
		if b.wind > 0:                               # its jaws open, acid glows: then it fires
			b.wind -= d
			if b.wind <= 0:
				b.open = 0.35
				match b.attack:
					"puddle":
						_boss_lob(run, mouth, b.ahead)
						run.events.append("spit")
					"spray":                         # two puddles, room to land between them
						_boss_lob(run, mouth, 320)
						_boss_lob(run, mouth, 760)
						run.events.append("spit")
					"low", "mid", "high", "vine":
						_boss_ball(run, mouth, LANE[b.attack])
						run.events.append("acid")
					"pair":                          # a short jump or staying down gets through
						_boss_ball(run, mouth, LANE["high"])
						_boss_ball(run, mouth, b.pair_lane)
						run.events.append("acid")
					"fan":                           # in the air (dragonfly, Vol): every lane up to the ceiling but two neighbours
						var hs = FAN_LANES
						var gap_k = W.randi() % (hs.size() - 2)   # three lanes free
						if b.last_gap >= 0:              # within reach of the last opening
							gap_k = clampi(gap_k, b.last_gap - 1, b.last_gap + 1)
						b.last_gap = gap_k
						for k in hs.size():
							if k < gap_k or k > gap_k + 2:
								_boss_ball(run, mouth, hs[k])
						run.events.append("acid")
					"rain":                          # drops from the sky, their shadows on the floor first
						for ahead in [420.0, 860.0]:
							var x: float = run.cam + run.sx + ahead + run.speed * 0.9
							var o = add_obs(run, x, -60, ACID_BALL, ACID_BALL, "acid", false)
							o.ghost = false
							o.drop = true
							o.vx = 0
							o.vy = 0
							o.g = 2 * (GROUND - ACID_BALL + 60) / (0.9 * 0.9)
						run.events.append("spit")
		else:
			b.next -= d
			if b.next <= 0:
				# what it throws depends on how he gets about
				var M: String = run.mount.kind if run.mount != null else ""
				var moves: Array
				var flying = M == "dragonfly" or (M == "" and run.lvl("flight") > 0)
				if flying:                               # up there nothing was safe from her: balls across the whole height
					moves = ["fan", "fan", "fan", "rain", "low", "high", "mid"]
				elif M == "rhino":
					moves = ["puddle", "spray", "low", "low", "high", "rain"]
				else:
					moves = ["puddle", "spray", "low", "low", "mid", "high", "pair", "rain"]
					if p.hang:
						moves.append_array(["vine", "vine"])
				# the first one, in a shuffled list, that leaves a way through (on foot: see _fits)
				b.ahead = wrnd(380, 640)
				b.pair_lane = wpick([LANE["low"], LANE["mid"]])
				wshuffle(moves)
				var now = _threats(run)
				var chosen = ""
				for mv in moves:
					if M != "" or flying or _attack_fits(run, b, mv, now):
						chosen = mv
						break
				if chosen == "":
					b.next = 0.2                         # nothing fair right now: she waits a moment
				else:
					b.attack = chosen
					b.wind = WIND
					b.next = maxf(0.7, 1.2 - b.t * 0.025) / (FLY_PACE if flying else 1.0)    # more and more often
		if b.t > BOSS_FIGHT and b.wind <= 0:           # a tree comes down on it
			b.phase = "fall"
			b.t = 0
			b.wx = run.cam + b.sx
			b.crushed = false
			run.next_x = maxf(run.next_x, run.cam + run.view_w + 2600)   # nothing else on the road while she goes down
			run.events.append("timber")
		return
	# falling: it stays where it stood; the tree lands at 0.9 s and drives it into the ground
	b.sx = b.wx - run.cam
	if not b.crushed and b.t >= 0.9:
		b.crushed = true
		run.shake = 1
		run.events.append("bossfall")
	if b.t > DEATH_TIME:                             # gone under the ground: the fight is won
		run.boss = null
		run.boss_done = true
		# the rewards, further on, while the speed comes back: coins thrown from where she sank, then a
		# line of blue gems at running height off the right edge, then the scenery changes
		for i in 24:
			loot(run, run.cam + run.sx + wrnd(40, 400), GROUND - wrnd(80, 300))
		for g in ["y", "r", "b"]:
			loot(run, run.cam + run.sx + wrnd(100, 300), GROUND - 200)
			run.coins[run.coins.size() - 1].gem = g
		var g0 = run.cam + run.view_w + 200
		for k in 16:
			coin(run, g0 + k * 48, floor_at(run, g0 + k * 48) - 40, "b")
		run.calm_until = g0 + 16 * 48 + DEATH_CALM
		run.easy_until = run.calm_until + DEATH_EASY
		run.next_x = maxf(run.next_x, g0)
		# the world moves on after the gems (with the Relique altérée, another scenery only goes by)
		run.next_biome_at = run.dist + (g0 + 16 * 48 - run.cam - run.sx) / PPM
		run.by_mark = false
		run.events.append("bossdown")

# ---------- blows, breaks, mounts ----------

# A coin thrown out of something broken: it pops up ahead of the hero, then flies to him (see update).
static func loot(run: Run, x: float, y: float) -> void:
	var c = coin(run, x + rnd(-10, 10), y)
	c.vx = rnd(40, 360)
	c.vy = rnd(-560, -260)
	c.loot = 0

# Breaking a creature (Esquive, boots, TNT): a burst, and a coin.
static func destroy(run: Run, o: Obs) -> void:
	o.gone = true
	var cx = o.x + o.w / 2
	burst(run, cx, o.y + o.h / 2, Color("#b04a8f"), 14, 320)
	loot(run, cx, o.y + o.h / 2)
	run.shake = maxf(run.shake, 0.25)
	run.events.append("break")

# Smashing scenery: four spinning pieces of its own picture (render.gd cuts them out), dust, four coins.
static func smash(run: Run, dc: Decor) -> void:
	dc.broken = true
	var cx = dc.x + DECOR_W / 2
	var cy = floor_at(run, cx) - 50
	for q in 4:
		var s = part(run, cx + (16 if q % 2 == 1 else -16), cy + (-16 if q < 2 else 16), run.speed * rnd(0.45, 1.25), rnd(-560, -140), rnd(0.6, 0.95), Color.WHITE, 4, 1700)
		s.shard = q
		s.biome = dc.biome
		s.vr = rnd(-13, 13)
	for i in 6:                                      # dust
		part(run, cx + rnd(-24, 24), cy + rnd(-20, 20), run.speed * rnd(0.3, 0.9), rnd(-90, 30), rnd(0.3, 0.55), colour_of(["#e9dcc0", "#cbb894", "#fff6dc"]), rnd(10, 20), -80)
	for i in 4:
		loot(run, cx, cy)
	burst(run, cx, cy, Color("#e8c890"), 12, 420)    # splinters
	run.shake = maxf(run.shake, 0.3)
	run.events.append("crate")

# Bottes de métal: the quake where the boots hit the floor. Crates within BOOTS_RANGE break; creatures
# down there (on the floor or low above it) are crushed. Nothing up high, nor a boss, nor her acid.
static func quake(run: Run, x: float, fy: float) -> void:
	var R: float = BOOTS_RANGE[mini(run.lvl("boots"), BOOTS_RANGE.size() - 1)]
	for o in run.obs:
		if o.gone or o.kind == "acid" or absf(o.x + o.w / 2 - x) > R + o.w / 2:
			continue
		if o.kind == "spiky" or o.y + o.h > fy - 150:
			destroy(run, o)
	for dc in run.decor:
		if not dc.broken and absf(dc.x + DECOR_W / 2 - x) < R + 40:
			smash(run, dc)
	for i in 22:                                     # stones and dust thrown along the floor both ways
		var side = -1.0 if i % 2 == 0 else 1.0
		part(run, x + side * rnd(0, R), fy - rnd(2, 14), side * rnd(80, 420), rnd(-420, -120), rnd(0.35, 0.7), colour_of(["#8a8fa8", "#cfd3e6", "#e9dcc0", "#6a6f8c"]), rnd(5, 12), 1600)
	run.shake = maxf(run.shake, 0.7)
	run.events.append("quake")

# Fana de TNT: a stick thrown ahead in an arc; it lands TNT_FLIGHT later, a few metres ahead of him.
static func throw_tnt(run: Run) -> void:
	var sh = Shot.new()
	sh.x = run.cam + run.sx + 10
	sh.y = run.p.y - 60
	var land = sh.x + run.speed * TNT_FLIGHT + 320
	var g = 2000.0
	sh.vx = (land - sh.x) / TNT_FLIGHT
	sh.vy = (floor_at(run, land) - 24 - sh.y - 0.5 * g * TNT_FLIGHT * TNT_FLIGHT) / TNT_FLIGHT
	run.shots.append(sh)
	run.events.append("throw")

static func shots(run: Run, d: float) -> void:
	for sh in run.shots:
		sh.t += d
		sh.vy += 2000 * d
		sh.x += sh.vx * d
		sh.y += sh.vy * d
		sh.spin += d * 14
		if randf() < 0.7:                            # the fuse sparks
			part(run, sh.x, sh.y - 12, rnd(-60, 60), rnd(-120, -20), 0.25, colour_of(["#ffd35c", "#fff3a8", "#ff7a2a"]), rnd(3, 6), 300)
		if sh.t >= TNT_FLIGHT:
			blast(run, sh.x, sh.y)
	run.shots = run.shots.filter(func(q): return q.t < TNT_FLIGHT)

## The stick blows up: every creature and obstacle ahead of him, up to past the right edge, goes (a swarm
## too); the bosses and their acid stand.
static func blast(run: Run, x: float, y: float) -> void:
	var px = run.cam + run.sx
	var far = run.cam + run.view_w + 160
	for o in run.obs:
		if not o.gone and o.kind != "acid" and o.x + o.w > px + 20 and o.x < far:
			destroy(run, o)
	for dc in run.decor:
		if not dc.broken and dc.x + DECOR_W > px + 20 and dc.x < far:
			smash(run, dc)
	var f = run.fm
	if f != null and not f.hit and f.sx < run.view_w + 120:
		f.hit = true
		f.waves = 1
		f.phase = "rush"                             # gone at once, whatever it was doing
		f.t = 1.0
		f.sx = -999
		for k in FM_LANES:
			if f.act[k]:
				burst(run, run.cam + run.view_w - 110, GROUND - (k + 0.5) * FM_STEP, Color("#7fe0c8"), 10, 300)
	for i in 40:                                     # the fireball
		var a = rnd(0, TAU)
		var v = rnd(120, 640)
		part(run, x, y, cos(a) * v, sin(a) * v - 120, rnd(0.35, 0.8), colour_of(["#ff2e1f", "#ff7a1a", "#ffd23c", "#fff3a0", "#4a4f6c"]), rnd(8, 20), 500)
	run.boom = maxf(run.boom, 0.55)
	run.shake = 1
	run.events.append("tnt")

# Hit on a mount: the animal takes the blow in the hero's place and vanishes in a puff. `ended`: its
# time is up (the rhino), it trots off and nothing is lost.
static func dismount(run: Run, ended: bool = false) -> void:
	var p = run.p
	var px = run.cam + run.sx
	for i in (10 if ended else 24):
		part(run, px + rnd(-60, 60), p.y - rnd(0, 110), rnd(-160, 160), rnd(-220, -20), rnd(0.4, 0.9), colour_of(["#f4f0e0", "#cfd3e6", "#9aa0b8"]), rnd(9, 20), -120)
	var gn = Gone.new()
	gn.kind = run.mount.kind
	gn.hang = p.hang
	gn.x = px
	gn.y = p.y
	run.gone = gn
	# What was laid ahead for the ride may be out of reach on foot: it vanishes in a puff. The coins stay.
	for o in run.obs:
		if o.ride and not o.gone and o.x + o.w > px:
			o.gone = true
			for i in 8:
				part(run, o.x + rnd(0, o.w), o.y + rnd(0, o.h), rnd(-80, 80), rnd(-160, -20), rnd(0.3, 0.6), colour_of(["#f4f0e0", "#cfd3e6"]), rnd(6, 14), -60)
	run.mount = null
	p.hang = false
	p.vine_leap = false
	p.jumps = 1
	if ended:
		p.inv = 0.8
		run.events.append("bye")
	else:
		p.inv = 1.5
		run.shake = 0.5
		run.flash = 0.6
		run.events.append("unmount")
	run.next_mount = maxf(run.next_mount, run.dist + wrnd(900, 1200) / friend(run))

# Losing a heart leaves a moment of invincibility; the last one ends the run (or triggers the rewind).
# On a mount nothing is lost: the animal vanishes instead. `o` may be null (a swarm, a fall).
static func hit(run: Run, o: Obs) -> void:
	if run.mount != null and MOUNTS[run.mount.kind].get("tough", false):   # the rhino: what would hurt is smashed, or bounces off
		if o != null and o.kind != "acid" and not o.gone:
			destroy(run, o)
		elif o != null:
			o.gone = true
		run.shake = maxf(run.shake, 0.3)
		return
	if o != null:
		o.gone = true
	if run.mount != null:
		dismount(run)
		return
	if not run.god:                                  # the debug menu's invincibility
		run.hearts -= 1
	run.shake = 0.6
	run.flash = 1
	if run.hearts > 0 or run.god:
		run.p.inv = HURT_INV
		burst(run, run.cam + run.sx, run.p.y - 40, Color("#ff4d6d"), 12, 300)
		run.events.append("hurt")
		return
	if run.rewind_left > 0:
		run.rewind_left -= 1
		run.hearts = run.max_hearts
		run.p.inv = 2
		run.glitch = 1
		run.obs = run.obs.filter(func(q): return q.x > run.cam + run.view_w)
		run.fm = null
		run.fm_due = false
		run.next_fm = run.dist + rnd(170, 300)
		run.events.append("rewind")
		return
	if run.coop:                                     # two players: he floats after the other, who can bring him back
		to_bubble(run)
		return
	_fatal(run)
	if run.lvl("lastLeap") > 0:                      # Dernier élan: knocked out, he still bounces a few metres further
		var p = run.p
		var lp = Leap.new()
		lp.n = run.lvl("lastLeap")
		lp.v = maxf(420, run.speed) * (LEAP_KICK + LEAP_KICK_LVL * lp.n)   # thrown ahead faster than he ran
		run.leap = lp
		p.vy = -minf(LEAP_UP_MAX, LEAP_UP + LEAP_UP_SPEED * run.speed)     # and higher the faster he went
		p.ground = false
		p.plat = null
		p.rotor = false
		p.flew = false
		burst(run, run.cam + run.sx, p.y - 40, Color("#ff4d6d"), 14, 320)
		run.events.append_array(["hurt", "bounce"])
		return
	die(run)

## What the road may ask of him: 2 with the Vol, 1 with Double saut, 0 on foot (in coop: road_tier).
static func tier_of(run: Run) -> int:
	if run.road_tier >= 0:
		return run.road_tier
	return 2 if run.lvl("flight") > 0 else (1 if run.lvl("doubleJump") > 0 else 0)

# ---------- coop: the bubble ----------
# Whoever loses his last heart floats in a bubble just above the other, a little behind; the other jumps
# into it and he is back (BUBBLE_BACK seconds safe, one heart). Each phone moves the partner's bubble after
# its own hero, and its own bubble after the partner: the two pictures agree closely enough.
const BUBBLE_UP := 150.0                 # the bubble's middle above the floor under the one it follows
const BUBBLE_BEHIND := 20.0
const BUBBLE_R := 50.0                 # (big enough to hold him: his leaves too)
const BUBBLE_BACK := 1.0

static func _bubble_target(run: Run, x: float, t: float) -> Vector2:
	return Vector2(x - BUBBLE_BEHIND, floor_at(run, x) - BUBBLE_UP + sin(t * 2.4) * 10)

static func to_bubble(run: Run) -> void:
	var p = run.p
	run.bubble = true
	run.bubble_pos = Vector2(run.cam + run.sx, p.y - 40)
	p.rotor = false
	p.flew = false
	p.diving = false
	p.ball = null
	p.inv = 0
	run.shake = 0.6
	run.flash = 0.6
	burst(run, run.cam + run.sx, p.y - 40, Color("#c9f3ff"), 18, 300)
	run.events.append("bubble")

## Floating: the bubble eases after the partner. With nobody left to save him, the run is over.
static func _float(run: Run, d: float, move: float) -> void:
	var p = run.p
	var px = run.cam + run.sx
	var target = _bubble_target(run, float(run.mate.get("x", px)) if run.mate != null else px, run.t)
	run.bubble_pos.x += move                         # carried along at the run's pace, then eased into place
	run.bubble_pos += (target - run.bubble_pos) * minf(1, d * 2.5)
	p.y = run.bubble_pos.y + 40
	p.vy = 0
	p.ground = false
	p.flying = false
	if run.mate == null or run.mate.get("b", false):
		die(run)                                     # both in bubbles, or the partner gone: the run ends

## The partner's bubble follows this hero; touching it brings him back (his phone is told: "rescue").
static func _rescue_check(run: Run, px: float, box: Box, d: float, move: float) -> void:
	run.mate_bubble.x += move                        # carried along at the run's pace, then eased into place
	run.mate_bubble += (_bubble_target(run, px, run.t) - run.mate_bubble) * minf(1, d * 2.5)
	if run.p.ground:
		return                                       # he has to jump into it
	var c = run.mate_bubble
	var nx = clampf(c.x, box.l, box.r)
	var ny = clampf(c.y, box.t, box.b)
	if Vector2(nx, ny).distance_to(c) > BUBBLE_R:
		return
	run.mate["b"] = false
	burst(run, c.x, c.y, Color("#c9f3ff"), 20, 320)
	run.events.append("rescue")

## Brought back by the partner: on his feet where he is, a moment safe, one heart.
static func back(run: Run) -> void:
	if not run.bubble or run.dead:
		return
	var p = run.p
	var px = run.cam + run.sx
	run.bubble = false
	run.hearts = maxi(run.hearts, 1)
	p.y = floor_at(run, px)
	p.vy = 0
	p.ground = true
	p.plat = null
	p.jumps = 0
	p.inv = BUBBLE_BACK
	burst(run, px, p.y - 40, Color("#c9f3ff"), 20, 320)
	run.events.append("back")

## The blow that ends the run, the moment it lands (before Dernier élan's bounces, while he sinks into a
## hole): main.gd takes the photo of the fall then.
static func _fatal(run: Run) -> void:
	if not run.fatal:
		run.fatal = true
		run.events.append("fatal")

static func die(run: Run) -> void:
	_fatal(run)
	run.dead = true
	run.shake = 1
	burst(run, run.cam + run.sx, run.p.y - 40, Color("#5cf2e0"), 26, 420)
	run.events.append("hit")

static func jump(run: Run, v: float) -> void:
	var p = run.p
	p.vy = v
	p.ground = false
	p.plat = null
	p.jumps += 1
	p.buf = 0
	run.events.append("jump")

# ---------- follower monsters ----------

# A new line-up of mosquitoes. How many lanes they take grows with the distance run; a lane the hero
# can reach with what he owns is always left free.
static func wave(run: Run) -> void:
	var f: Swarm = run.fm
	var N = FM_LANES
	var tr = tier_of(run)
	var reach = N if tr == 2 else (3 if tr == 1 else 2)
	var level = clampi(floori(run.dist / 450 + wrnd(-0.6, 0.6)), 0, 3)
	var safe = W.randi() % reach
	f.act = []
	f.act.resize(N)
	f.act.fill(false)
	if level < 2:                                    # one or two lanes, among those he is likely to be in
		var low: Array = [0, 1, 2].filter(func(k): return k != safe)
		wshuffle(low)
		for k in low.slice(0, level + 1):
			f.act[k] = true
	else:
		var twin = -1
		if level != 3:
			twin = safe + 1 if (safe + 1 < N and (safe == 0 or W.randf() < 0.5)) else safe - 1
		for k in N:
			f.act[k] = k != safe and k != twin
	f.level = level
	f.phase = "aim"
	f.t = 0
	f.sx = run.view_w + 90
	f.hit = false
	f.ghost = run.lvl("drunk") > 0 and randf() < DRUNK[run.lvl("drunk")]
	run.events.append("fm")

static func followers(run: Run, d: float, box: Box, dashing: bool) -> void:
	var p = run.p
	var px = run.cam + run.sx
	if run.fm == null and run.boss != null:
		run.fm_due = false
		run.next_fm = maxf(run.next_fm, run.dist + 150)
		return
	if run.fm == null:
		if run.mount != null:                        # never on top of a ride
			run.fm_due = false
			run.next_fm = maxf(run.next_fm, run.dist + 100)
			return
		if not run.fm_due and run.dist >= run.next_fm:
			run.fm_due = true                        # from now on only coins are laid ahead
		if not run.fm_due or px < run.block_end + 60:
			return                                   # waits until the road is clear
		var nf = Swarm.new()
		nf.biome = biome_at(run, px)
		nf.waves = 1 + (1 if run.dist > 450 and W.randf() < 0.6 else 0) + (1 if run.dist > 900 and W.randf() < 0.5 else 0)
		nf.aim = 1.7
		run.fm = nf
		wave(run)
	var f: Swarm = run.fm
	f.t += d
	if f.phase == "aim":                             # they follow the hero from the right edge
		f.sx += (run.view_w - 110 - f.sx) * minf(1, d * 5)
		if f.t >= f.aim:
			f.phase = "fire" if f.biome == 2 else "rush"
			f.t = 0
			run.events.append("laser" if f.phase == "fire" else "rush")
		return
	if f.phase == "fire":                            # the city's drones stay put and fire along their lanes
		if not f.hit and not f.ghost and f.t > LASER_ON and f.t < LASER_OFF:
			for k in FM_LANES:
				var y0 = GROUND - (k + 0.5) * FM_STEP - LASER_H / 2
				if not f.act[k] or y0 + 4 > box.b or y0 + LASER_H - 4 < box.t:
					continue
				if dashing:
					break
				if p.inv == 0:
					f.hit = true
					hit(run, null)
					if run.dead or run.leap != null or run.fm == null:
						return
				break
		if f.t < LASER_END:
			return
		f.sx = -999                                  # gone: the wave is over
	else:
		f.sx += (260.0 if f.t < 0.14 else -FM_RUSH) * d   # a short recoil, then the charge
	var x0 = run.cam + f.sx - FM_W / 2
	if not f.hit and not f.ghost and x0 + 8 < box.r and x0 + FM_W - 8 > box.l:
		for k in FM_LANES:
			var y0 = GROUND - (k + 0.5) * FM_STEP - FM_H / 2
			if not f.act[k] or y0 + 6 > box.b or y0 + FM_H - 6 < box.t:
				continue
			if dashing:
				f.hit = true
				f.sx = -999
				run.gold += 3
				burst(run, px + 40, y0 + FM_H / 2, Color("#7fe0c8"), 18, 340)
				run.shake = maxf(run.shake, 0.3)
				run.events.append("break")
			elif p.inv == 0:
				f.hit = true
				hit(run, null)
				if run.dead or run.leap != null or run.fm == null:
					return
			break
	if f.sx > -FM_W:
		return
	if not f.hit:
		run.events.append("dodge")
	f.aim = 1.15
	f.waves -= 1
	if f.waves > 0:
		wave(run)
		return
	run.fm = null
	run.fm_due = false
	run.next_fm = run.dist + wrnd(FM_NEXT[0], FM_NEXT[1])
	run.next_x = maxf(run.next_x, run.cam + run.view_w + 150)   # obstacles come back from beyond the screen

# ---------- update ----------

static func _puff(run: Run, px: float, y: float) -> void:     # curling up and uncurling: a puff of leaves
	for i in 12:
		part(run, px + rnd(-22, 22), y - rnd(8, 60), rnd(-180, 120), rnd(-200, 40), rnd(0.3, 0.6), colour_of(["#8fd14a", "#c9e86a", "#5fae3a", "#f4f0e0"]), rnd(5, 11), 300)

static func _leaves(run: Run, px: float, y: float) -> void:   # leaves shaken off his rotor
	part(run, px + rnd(-40, 40), y - 105, rnd(-160, -40), rnd(-40, 60), 0.6, colour_of(["#8fd14a", "#c9e86a", "#5fae3a"]), rnd(4, 8), 300)

## For the debug menu: the boxes the rules test, in world units. kind: hero, danger, ghost (harmless),
## waiting (not dangerous yet), coins (what he picks up), ledge (where a falling hero lands). "coin": the
## circle that also picks up coins.
static func hitboxes(run: Run) -> Dictionary:
	var p = run.p
	var px = run.cam + run.sx
	var M: Dictionary = MOUNTS[run.mount.kind] if run.mount != null else {}
	var half: float = M["half"] if run.mount != null else HERO_HALF
	var tall: float = M["tall"] if run.mount != null else HERO_H
	var out: Array = []
	var box = func(L: float, R: float, T: float, B: float, kind: String) -> void:
		out.append({"L": L, "R": R, "T": T, "B": B, "kind": kind})
	box.call(px - half, px + half, p.y - tall + 6, p.y - 2, "hero")
	for o in run.obs:
		if not o.gone:
			box.call(o.x + 6, o.x + o.w - 6, o.y + 6, o.y + o.h - 6, "ghost" if o.ghost else ("waiting" if o.kind == "dart" and o.state != "go" else "danger"))
	var grab = M.has("grab_w")
	if grab:
		box.call(px - M["grab_w"], px + M["grab_w"], p.y - M["grab_h"], p.y + 10, "coins")
	elif p.ball != null:
		box.call(px - COIN_HALF, px + COIN_HALF, p.y - BALL_REACH, p.y + BALL_UNDER, "coins")
	else:
		box.call(px - COIN_HALF, px + COIN_HALF, p.y - tall - COIN_TOP, p.y + COIN_UNDER, "coins")
	for pl in run.plats:
		box.call(pl.x - HERO_HALF, pl.x + pl.w + HERO_HALF, pl.y, pl.y, "ledge")
	var f = run.fm
	if f != null and not f.ghost and not f.hit:
		for k in FM_LANES:
			if not f.act[k]:
				continue
			if f.phase == "fire":
				var y0 = GROUND - (k + 0.5) * FM_STEP - LASER_H / 2
				box.call(run.cam - 200, run.cam + f.sx, y0 + 4, y0 + LASER_H - 4, "danger" if f.t > LASER_ON and f.t < LASER_OFF else "waiting")
			else:
				var x0 = run.cam + f.sx - FM_W / 2
				var y1 = GROUND - (k + 0.5) * FM_STEP - FM_H / 2
				box.call(x0 + 8, x0 + FM_W - 8, y1 + 6, y1 + FM_H - 6, "danger" if f.phase == "rush" else "waiting")
	return {"boxes": out, "coin": null}

static func _ease_speed(v: float, pace: float, ramp: float, dt: float) -> float:
	if pace > v:
		return minf(pace, v + ramp * dt)
	return v + (pace - v) * minf(1, dt * 3)

static func update(run: Run, dt: float, input: Controls) -> void:
	W = run.rng                                      # this run's road dice (the shop's preview has its own)
	# Particles and screen effects keep living after death.
	run.shake = maxf(0, run.shake - dt * 2.5)
	run.glitch = maxf(0, run.glitch - dt * 1.6)
	run.flash = maxf(0, run.flash - dt * 4)
	run.p.squash = maxf(0, run.p.squash - dt * 7)
	run.boom = maxf(0, run.boom - dt * 2.2)
	run.blend = minf(1, run.blend + dt / 1.2)
	var ts = 1.0
	if run.slow.t > 0:                               # the Sablier slows the world, not the timers
		ts = SLOW_PACE + (1 - SLOW_PACE) * maxf(0, 1 - run.slow.t / SLOW_EASE)
	var d = dt * ts
	if run.gone != null:
		run.gone.t += dt
		if run.gone.t > 0.7:
			run.gone = null
	for q in run.parts:
		q.life += d
		q.vy += q.g * d
		q.x += q.vx * d
		q.y += q.vy * d
		if q.shard < 0:
			continue
		q.rot += q.vr * d                            # a piece of crate tumbles and bounces
		var f = floor_at(run, q.x) - 8
		if q.y > f and q.vy > 0:
			q.y = f
			q.vy *= -0.5
			q.vx *= 0.7
			q.vr *= 0.6
	run.parts = run.parts.filter(func(q): return q.life < q.span)
	if run.dead:
		return

	if run.wait > 0:                                 # still inside: the temple shakes, dust falls from the lintel
		run.wait -= dt
		run.shake = maxf(run.shake, 0.22)
		if randf() < 0.6:
			part(run, rnd(60, 125), GROUND - rnd(195, 225), rnd(-20, 40), rnd(20, 120), 0.5, Color("#cfd3e6"), rnd(4, 8), 500)
		if run.wait > 0:
			return
		run.exploded = true
		run.shake = 1
		run.boom = 1
		if run.lvl("flight") > 0:
			run.p.cruise = CRUISE_TIME               # with the Vol, he flies out of the doorway
		for i in 46:                                 # the doorway bursts outward in blocks of stone and moss
			part(run, rnd(60, 130), GROUND - rnd(40, 220), rnd(80, 900), rnd(-760, -40), rnd(0.8, 1.7), colour_of(["#8a8fa8", "#6a6f8c", "#4a4f6c", "#7bd13c", "#cfd3e6"]), rnd(8, 22), 1500)
		for i in BLAST_COINS:                        # the temple's gold flies out: real coins, which bounce and wait
			var c = coin(run, rnd(70, 130), GROUND - rnd(50, 200))   # (its own dice: the road is already being laid,
			c.toss = true                            # more or less far depending on the screen's width)
			c.blast = true
			c.tvx = rnd(420, 1500)
			c.tvy = rnd(-820, -120)
		run.events.append("boom")

	var p = run.p
	for pl in run.plats:                             # the pads bob
		if pl.bobbing:
			pl.y = pl.y0 + sin(run.t * PAD_SPEED + pl.ph) * pl.bob

	# --- actives ---
	var was_dashing = run.dash.t > 0
	run.dash.t = maxf(0, run.dash.t - dt)
	run.dash.cd = maxf(0, run.dash.cd - dt)
	run.boots.cd = maxf(0, run.boots.cd - dt)
	run.tnt.cd = maxf(0, run.tnt.cd - dt)
	if was_dashing and run.dash.t == 0:
		p.inv = maxf(p.inv, DODGE_INV)              # out of the Esquive: a moment to find his feet
	var slow_was = run.slow.t
	run.slow.t = maxf(0, run.slow.t - dt)
	run.slow.cd = maxf(0, run.slow.cd - dt)
	if slow_was > 0:                                 # the Sablier running out: ticks, then the world catching up
		for at in SLOW_TICKS:
			if slow_was > at and run.slow.t <= at:
				run.events.append("slowtick")
		if run.slow.t == 0:
			run.events.append("slowend")
	if run.leap == null and input.tnt and run.lvl("tnt") > 0 and run.tnt.cd == 0:
		run.tnt.cd = run.tnt.full
		throw_tnt(run)
	if run.leap == null and input.dash and run.lvl("dash") > 0 and run.dash.cd == 0:
		run.dash.t = DODGE_TIME
		run.dash.cd = run.dash.full
		run.events.append("dash")
	var monster_was = run.monster.t                  # RedMonster: twice his speed for a few seconds
	run.monster.t = maxf(0, run.monster.t - dt)
	run.monster.cd = maxf(0, run.monster.cd - dt)
	if monster_was > 0 and run.monster.t == 0:
		run.events.append("monsterend")
	if run.leap == null and input.monster and run.lvl("monster") > 0 and run.monster.cd == 0 and run.mount == null and run.boss == null:
		run.monster.t = MONSTER_TIME[mini(run.lvl("monster"), MONSTER_TIME.size() - 1)]
		run.monster.cd = run.monster.full
		run.events.append("monster")
	if run.monster.t > 0 and randf() < 0.6:          # red fizz flying off behind him
		part(run, run.cam + run.sx - rnd(10, 40), run.p.y - rnd(10, 70), -rnd(160, 420), rnd(-60, 40), rnd(0.2, 0.45), colour_of(["#ff3b3b", "#ff6b4a", "#ffd35c"]), rnd(4, 9), 0)
	if run.leap == null and input.slow and run.lvl("slow") > 0 and run.slow.cd == 0:
		run.slow.t = SLOW_TIME[run.lvl("slow")]
		run.slow.cd = SLOW_CD
		run.events.append("slow")
	var dashing = run.dash.t > 0

	# --- scrolling: the hero first runs out of the temple, then the camera follows him ---
	run.t += d
	# The hero's own speed grows for ever; a mount, then the boss, impose theirs while they last.
	var own: float
	if run.mode == "story":                          # each scenery from its own speed, gaining 0.25 m/s a second
		own = run.base + ZONE_SPEED.get(run.biome, SPEED_BASE) - SPEED_BASE + (run.t - run.zone_t) * STORY_GAIN
	else:
		own = run.base + run.t * SPEED_GAIN
	var raw = maxf(SPEED_BASE * 0.6, own)           # without the hourglasses picked up: what the road is laid for
	own = maxf(SPEED_BASE * 0.6, own - run.brake)
	var pace = own
	var road_pace = raw
	if run.monster.t > 0:                            # RedMonster: twice his speed; the road stays laid for his own
		pace *= MONSTER_MUL
	if run.boss != null:
		pace = BOSS_SPEED * (DEATH_PACE if run.boss.phase == "fall" else 1.0)
		road_pace = pace
	elif run.mount != null:
		var R: Dictionary = MOUNTS[run.mount.kind]
		pace = own * R["mul"] if R.has("mul") else R["base"] + R["gain"] * run.mount.t
		road_pace = raw * R["mul"] if R.has("mul") else pace
	# Slowing down is quick; speeding back up (after a mount or the boss) is gradual.
	var ramp = MOUNTS[run.mount.kind].get("ramp", RAMP) if run.mount != null and run.boss == null else RAMP
	if run.monster.t > 0 and run.mount == null and run.boss == null:
		ramp = MONSTER_RAMP
	run.speed = _ease_speed(run.speed, pace, ramp, dt)
	run.road_speed = _ease_speed(run.road_speed, road_pace, ramp, dt)
	run.own = own
	run.relic = maxf(0, run.relic - dt * 0.6)
	var gorilla_on = run.mount != null and run.mount.kind == "gorilla"
	run.vine = clampf(run.vine + (1.0 if gorilla_on else -1.0) * dt * 2.5, 0, 1)
	if run.leap != null:
		run.leap.v = maxf(160, run.leap.v * (1 - LEAP_DRAG * d))   # knocked out: he only slows down, slowly
	# he is thrown out of the temple faster than he runs
	var move: float
	if run.leap != null:
		move = run.leap.v * d
	else:
		move = (run.speed + (DODGE_SPEED if dashing else 0.0)) * (1.8 if run.exploded and run.sx < run.home else 1.0) * d
	var px0 = run.cam + run.sx                      # where he was: the Esquive sweeps everything between
	if run.sx < run.home:
		run.sx = minf(run.home, run.sx + move)
	else:
		run.cam += move
	run.dist = run.cam / PPM
	var px = run.cam + run.sx
	var fl = floor_at(run, px)                      # the floor right under him

	if run.leap != null:                             # --- Dernier élan: a rag doll bouncing along ---
		p.vy += 2000 * d
		p.y += p.vy * d
		p.roll += d * 11
		p.flying = false
		if p.y >= fl:
			p.y = fl
			for i in 8:
				part(run, px + rnd(-20, 20), fl - 2, rnd(-160, 160), rnd(-110, -20), 0.35, Color("#f4f0e0"), rnd(4, 9), 0)
			run.leap.n -= 1
			if run.leap.n >= 0:
				p.vy = minf(-420, p.vy * -LEAP_BOUNCE)     # each bounce a little lower than the last
				run.shake = maxf(run.shake, 0.3)
				run.events.append("bounce")
			else:
				die(run)
				return
	elif run.bubble:                                 # --- coop: fallen, he floats after the partner ---
		_float(run, d, move)
	else:
		# --- player ---
		var M: Dictionary = MOUNTS[run.mount.kind] if run.mount != null else {}
		var mounted = run.mount != null
		var gorilla = gorilla_on
		var spring = 1.0 + SPRING_K * run.lvl("spring")
		p.inv = maxf(0, p.inv - dt)
		p.buf = maxf(0, p.buf - dt)
		p.spin = maxf(0, p.spin - dt)
		p.flying = false
		var half: float = M["half"] if mounted else HERO_HALF
		var tall: float = M["tall"] if mounted else HERO_H
		if p.ball != null and px > p.ball.x + p.ball.w:   # out at the far end, back on his feet
			p.ball = null
			p.y = fl
			_puff(run, px, p.y)
			run.events.append("unroll")
		if p.ball == null and run.lvl("sphere") > 0 and not mounted and p.ground and p.plat == null:   # the Sphère: in he rolls
			for z in run.zones:
				if px >= z.x and px < z.x + 110:
					p.ball = z
					break
			if p.ball != null:
				p.balled = 0
				_puff(run, px, p.y)
				run.events.append("roll")
		if p.ball != null:
			var z: Zone = p.ball
			var k = minf(1, minf((px - z.x) / 70, (z.x + z.w - px) / 70))
			p.ground = true
			p.flew = false
			p.plat = null
			p.vy = 0
			p.rotor = false
			p.flew = false
			p.jumps = 0
			p.y = fl + (GALLERY * maxf(0, k) if z.kind == "gallery" else 0.0)
			p.roll += run.speed * d / 26
			p.balled += dt
		elif mounted and M.get("fly", false):
			# the dragonfly: held, it climbs; let go, it sinks. It turns round at once.
			p.ground = false
			p.plat = null
			p.rotor = false
			p.flew = false
			p.vy += ((-480.0 if input.hold else 440.0) - p.vy) * minf(1, d * 16)
			p.y += p.vy * d
			if p.y > fl - 12:
				p.y = fl - 12
				p.vy = minf(p.vy, 0)
			if p.y - tall < CEIL:
				p.y = CEIL + tall
				p.vy = maxf(p.vy, 0)
		elif p.cruise > 0 and not mounted:
			# with the Vol, out of the temple: he flies on his own at cruising height until the first press
			p.cruise -= dt
			p.ground = false
			p.plat = null
			p.jumps = 2
			p.rotor = true
			p.spin = 0.22
			p.flying = true
			var target = fl - CRUISE_H
			p.vy += ((target - p.y) * 5 - p.vy) * minf(1, d * 5)
			p.y += p.vy * d
			if randf() < 0.25:
				_leaves(run, px, p.y)
			if input.pressed or input.hold or p.cruise <= 0:   # taken in hand: a press is a flap, as in flight
				p.cruise = 0
				p.rotor = input.pressed or input.hold
				if input.pressed:
					p.vy = minf(p.vy, -flap(run))
					run.events.append("flap")
		elif p.hang:
			# the gorilla under the vines: it swings from one to the next until a press lets go
			p.y = HANG_Y
			p.vy = 0
			p.phase += 1.5 * TAU * d
			if input.pressed:
				p.hang = false
				p.vy = 160
				p.jumps = 1
				run.events.append("drop")
		else:
			if input.stomp and run.lvl("boots") > 0 and run.boots.cd == 0 and not mounted and run.boss == null:
				run.boots.cd = run.boots.full        # Bottes de métal: on the floor the quake comes at once,
				if p.ground:                         # in the air he plunges down and it comes as he lands
					quake(run, px, p.y)
				else:
					p.diving = true
					p.rotor = false
					p.vy = maxf(p.vy, BOOTS_DIVE)
					run.events.append("dive")
			if input.pressed:
				if p.ground:                         # on foot, a press is a plain jump
					jump(run, (M["jump"] if mounted else -JUMP_V) * spring)
				elif gorilla and p.jumps < 2:        # the gorilla's second jump goes as high as it takes to reach the vines
					jump(run, -sqrt(2 * 2400 * maxf(80, p.y - HANG_Y + 40)))
					p.vine_leap = true
					burst(run, px, p.y, Color.WHITE, 8, 160)
				elif not mounted and run.lvl("doubleJump") > 0 and p.jumps < 2:
					jump(run, -JUMP_DOUBLE * spring)
					burst(run, px, p.y, Color.WHITE, 6, 120)
					p.rotor = run.lvl("flight") > 0
				elif not mounted and run.lvl("flight") > 0 and not p.diving:   # in the air, every press lifts him at once
					p.rotor = true
					p.spin = 0.22
					p.vy = minf(p.vy, -flap(run))
					run.events.append("flap")
				else:
					p.buf = 0.12                     # pressed just before landing: remembered
			if not input.hold:
				if p.rotor and p.vy < 0:
					p.vy *= 1.0 - VOL_STOP           # the climb stops (at once with VOL_STOP 1)
				p.rotor = false                      # released: he drops straight away
			if p.ground and p.plat != null and (px < p.plat.x - HERO_HALF or px > p.plat.x + p.plat.w + HERO_HALF):
				p.ground = false                     # ran off the end of a ledge
				p.plat = null
				p.jumps = 1
			if p.ground and p.plat != null:
				p.y = p.plat.y                       # a pad carries him up and down
			if p.ground and p.plat == null:          # on a slope he follows it; where the floor gives way, he falls
				if fl - p.y > 40:
					p.ground = false
					p.jumps = maxi(p.jumps, 1)
				else:
					p.y = fl
			if not p.ground:
				var before = p.y
				var heavy = BOOTS_FALL if run.lvl("boots") > 0 and p.vy > 0 and not mounted else 1.0   # Bottes de métal: he falls faster
				if p.diving:
					p.vy = maxf(p.vy, BOOTS_DIVE)
				elif p.rotor:
					p.flew = true
					p.vy = minf(-flap(run), p.vy + JUMP_GRAVITY * d)   # the leaf rotor: a steady climb while held
				elif p.flew:
					p.vy += JUMP_GRAVITY * VOL_DROP * heavy * d    # released after flying: down quickly
				else:
					p.vy += (JUMP_HELD if (input.hold and p.vy < 0 and not p.vine_leap) else JUMP_GRAVITY * heavy) * d
				p.flying = p.rotor or p.spin > 0
				if p.flying and randf() < 0.25:
					_leaves(run, px, p.y)
				p.y += p.vy * d
				if p.vine_leap and p.y <= HANG_Y:    # the vines: caught
					p.y = HANG_Y
					p.vy = 0
					p.hang = true
					p.vine_leap = false
					p.jumps = 0
					run.events.append("grab")
				if p.y - tall < CEIL:
					p.y = CEIL + tall
					if p.vy < 0:
						p.vy = 0
				for pl in run.plats:                 # under a cave roof: he bumps his head
					var under: float = pl.y + pl.t
					if pl.t > 0 and px > pl.x and px < pl.x + pl.w and p.y > under + HERO_H * 0.6 and p.y - HERO_H < under:
						p.y = under + HERO_H
						if p.vy < 0:
							p.vy = 0
				var land = fl if p.y >= fl else NAN
				var on = null
				if p.vy > 0:                         # ledges only catch a falling hero
					for pl in run.plats:
						if before <= pl.y and p.y >= pl.y and px > pl.x - HERO_HALF and px < pl.x + pl.w + HERO_HALF:
							land = pl.y
							on = pl
							break
				if not is_nan(land):
					p.y = land
					p.vy = 0
					p.ground = true
					p.flew = false
					p.plat = on
					p.jumps = 0
					p.squash = 1
					p.rotor = false
					p.flew = false
					p.spin = 0
					p.vine_leap = false
					if p.diving:                         # the boots hit the floor: the quake
						p.diving = false
						quake(run, px, land)
					for i in 5:
						part(run, px + rnd(-16, 16), land - 2, rnd(-140, 140), rnd(-70, -20), 0.3, Color("#f4f0e0"), rnd(4, 8), 0)
					if on != null:
						run.events.append("land")
					if p.buf > 0:
						jump(run, (M["jump"] if mounted else -JUMP_V) * spring)
			else:
				# strides per second: quicker as he speeds up, but never a blur
				p.phase += (1.75 + (minf(900, run.speed) - 360) / 600) * TAU * d * (1.4 if dashing else 1.0)
				if randf() < 0.25:
					part(run, px - 30, p.y - 2, rnd(-90, -30), rnd(-50, -10), 0.35, Color("#f4f0e0"), rnd(4, 8), 0)
		if dashing and randf() < 0.8:
			part(run, px - 20, p.y - rnd(5, 75), -300, 0, 0.25, Color("#ffd35c"), rnd(4, 8), 0)

		# --- the red spiders go up and down ---
		for o in run.obs:
			if o.kind == "hover" and o.amp > 0:
				o.y = o.y0 - sin(run.t * TAU / SPIDER_PERIOD + o.ph) * o.amp
		# --- the rare floating things: they zigzag a little; touched, they are his ---
		for it in run.bonuses:
			if it.kind == "brake" and it.x < run.cam + run.view_w - 30:
				it.x += run.speed * BRAKE_PACE * d          # the hourglass, once in sight, keeps ahead of him
			var fb = floor_at(run, it.x)
			var zk = fmod(run.t / 1.6 + it.ph, 2.0)
			it.y = fb - BONUS_LOW - (BONUS_HIGH - BONUS_LOW) * (zk if zk < 1 else 2 - zk)
			if it.gone or absf(px - it.x) > (52.0 if it.kind == "brake" else 40.0):
				continue
			var tall_b: float = MOUNTS[run.mount.kind]["tall"] if run.mount != null else HERO_H
			if it.y < p.y - tall_b - 30 or it.y > p.y + 10:
				continue
			it.gone = true
			if it.kind == "life":
				run.hearts += 1
				run.max_hearts = maxi(run.max_hearts, run.hearts)
				burst(run, it.x, it.y, Color("#ff4d6d"), 16, 260)
			else:
				run.brake += run.own * BRAKE_SHARE              # 20 % of his speed, now
				burst(run, it.x, it.y, Color("#7fd8ff"), 16, 260)
			run.events.append(it.kind)
		run.bonuses = run.bonuses.filter(func(b_): return not b_.gone and b_.x > run.cam - 200)

		# --- mounts: the ones ahead wait to be touched, and may be missed ---
		if run.mount != null:
			run.mount.t += dt
			var time: float = MOUNTS[run.mount.kind].get("time", 0.0)
			if time > 0 and run.mount.t >= time:
				dismount(run, true)
		for it in run.items:
			var tame = run.lvl(it.kind + "Tamed")           # Dompté (each animal its own): it waits for him, and reaches out
			it.x += run.speed * MOUNTS[it.kind]["ahead"] * maxf(0, 1.0 - TAME_SLOW * tame) * d
			var f = floor_at(run, it.x)
			if it.kind == "dragonfly":
				var k = fmod((run.t + it.ph) / ZIG_PERIOD, 2.0)
				it.y = f - ZIG_LOW - (ZIG_HIGH - ZIG_LOW) * (k if k < 1 else 2 - k)
			if run.mount != null or absf(px - it.x) > TAME_REACH[mini(tame, TAME_REACH.size() - 1)]:
				continue
			var reach = false
			if it.kind == "gorilla":
				reach = p.y - HERO_H < f - PERCH + 24 + TAME_UP * tame  # up to the gorilla: a high jump
			elif it.kind == "rhino":
				reach = p.y > f - 50 - TAME_RHINO * tame           # the rhino: at its level, not over it
			else:
				reach = absf(p.y - HERO_H / 2 - it.y) < 64 + TAME_UP * tame   # the dragonfly: where it flies
			if not reach:
				continue
			var mt = Mount.new()
			mt.kind = it.kind
			run.mount = mt
			it.gone = true
			p.rotor = false
			p.flew = false
			p.hang = false
			p.vine_leap = false
			p.diving = false
			p.inv = maxf(p.inv, 0.5)
			if MOUNTS[it.kind].get("fly", false):
				p.ground = false
				p.plat = null
				p.vy = -200
				p.y = minf(p.y, floor_at(run, it.x) - 60)
			elif not p.ground:                       # caught in the air: they come down together
				p.vy = maxf(p.vy, 0)
				p.jumps = 1
			burst(run, it.x, p.y - 70, Color("#ffd35c"), 16, 260)
			run.events.append("mount")

		run.h = maxf(0, (floor_at(run, px) - p.y) / PPM)
		run.max_h = maxf(run.max_h, run.h)

		# --- obstacles ---
		var box = Box.new()
		box.l = (minf(px0, px) if dashing else px) - half   # the Esquive: all the way he went
		box.r = px + half
		box.t = p.y - tall + 6
		box.b = p.y - 2
		for o in run.obs:
			if p.ball != null:
				break                                # nothing reaches him in there
			if o.kind == "dart":                     # waiting beyond the edge, then the warning, then across in one go
				if o.state == "wait" and (run.fm != null or run.fm_due):
					o.gone = true                    # never a fonceur (or a missile) during a swarm
					continue
				if o.state == "wait" and o.x <= run.cam + run.view_w + 40:
					o.state = "warn"
					o.t = 0
					run.events.append("warn")
					if o.aim:                        # it takes his height now: the "!" shows where it will pass
						var alt = clampf(floor_at(run, px) - (p.y - tall / 2), DART_ALTS[0][0], DART_TOP)
						o.y = floor_at(run, px) - alt - DART_H / 2
				if o.state == "warn":
					o.x = run.cam + run.view_w + 60
					o.t += d
					if o.t >= DART_WARN:
						o.state = "go"
						run.events.append("dart")
				if o.state == "go":
					o.x -= DART_SPEED * d
			if o.kind == "acid":
				o.x += o.vx * d
				if o.lob:                            # a blob in the air: where it lands, a puddle of acid stays
					o.vy += o.g * d
					o.y += o.vy * d
					var f = floor_at(run, o.x + o.w / 2)
					if o.y + o.h >= f:
						o.lob = false
						o.vx = 0
						o.x -= (ACID_PUDDLE - o.w) / 2
						o.w = ACID_PUDDLE
						o.h = 22
						o.y = f - o.h
						o.puddle = true
						for i in 10:
							part(run, o.x + rnd(10, o.w - 10), f - 6, rnd(-160, 160), rnd(-320, -80), rnd(0.3, 0.6), colour_of(["#a8ff3c", "#5cf25c", "#e8ffb0"]), rnd(5, 10), 1200)
						run.events.append("splash")
				elif o.ball:
					o.y += (o.lane - o.y) * minf(1, d * BALL_SETTLE)
				elif o.drop:                         # a drop from the sky: a small puddle where it lands
					o.vy += o.g * d
					o.y += o.vy * d
					var f = floor_at(run, o.x + o.w / 2)
					if o.y + o.h >= f:
						o.drop = false
						o.x -= 27
						o.w = 90
						o.h = 22
						o.y = f - o.h
						o.puddle = true
						run.events.append("splash")
			if o.gone or o.x + 6 > box.r or o.x + o.w - 6 < box.l or o.y + 6 > box.b or o.y + o.h - 6 < box.t:
				continue
			if dashing and o.kind == "acid":
				continue                             # the Esquive passes through what cannot be broken
			if dashing or (p.diving and o.kind != "acid"):
				destroy(run, o)                      # broken by the Esquive, or crushed by the boots
			elif o.ghost:
				if not o.passed:
					o.passed = true
					burst(run, o.x + o.w / 2, o.y + o.h / 2, Color("#c9f3ff"), 6, 120)
			elif p.inv == 0:
				hit(run, o)
				if run.dead:
					return
				break
		# scenery that can be smashed, run past with Brise-tout, on the rhino, or in an Esquive
		if run.lvl("breaker") > 0 or dashing or M.get("smash", false):
			var from_x = (minf(px0, px) if dashing else px) - 50
			for dc in run.decor:
				var dcx = dc.x + DECOR_W / 2
				if not dc.broken and dcx > from_x and dcx < px + 50 and p.y > floor_at(run, dc.x) - 160:
					smash(run, dc)
		shots(run, d)                            # Fana de TNT: the sticks in the air
		if run.leap == null:
			followers(run, d, box, dashing)
		if run.dead:
			return
		if run.leap == null:
			boss(run, d)
			camp(run, d)
		if run.coop and run.mate != null and run.mate.get("b", false):
			_rescue_check(run, px, box, d, move)        # the partner's bubble: jump into it to bring him back
		# sinking into a hole on his last heart, with nothing to save him: that is the fatal moment
		if p.y > GROUND + 24 and not p.ground and run.hearts == 1 and not run.god and run.rewind_left == 0 and run.mount == null and not run.coop:
			for hp in run.pits:
				if px > hp.x0 - 60 and px < hp.x1 + 60:
					_fatal(run)
					break
		# fallen into a hole: a heart goes, and he is put back on the far side
		if p.y > GROUND + 150:
			var pit = null
			for hp in run.pits:
				if px > hp.x0 - 60 and px < hp.x1 + 60:
					pit = hp
					break
			if pit != null:
				run.cam = pit.x1 + 40 - run.sx
				p.y = GROUND
				p.vy = 0
				p.ground = true
				p.flew = false
				p.jumps = 0
			else:
				p.y = floor_at(run, run.cam + run.sx)
			p.inv = 0
			hit(run, null)
			if run.god:
				p.inv = 0.5
			if run.dead:
				return
	run.items = run.items.filter(func(it): return not it.gone and it.x > run.cam - 200)
	run.decor = run.decor.filter(func(dc): return dc.x > run.cam - 200)
	run.hills = run.hills.filter(func(hl): return hl.x + hl.w > run.cam - 200)
	run.zones = run.zones.filter(func(z): return z.x + z.w > run.cam - 200 or z == run.p.ball)
	run.obs = run.obs.filter(func(o): return not o.gone and o.x + o.w > run.cam - 120)
	run.plats = run.plats.filter(func(pl): return pl.x + pl.w > run.cam - 120)

	while run.terrain.size() > 2 and run.terrain[1].x < run.cam - 300:
		run.terrain.pop_front()

	# --- spawning ---
	var edge = run.cam + run.view_w + 200
	while run.next_x < edge:
		spawn_pattern(run)

	# --- scenery change ---
	var Z = ZONE_ENDLESS if run.mode == "endless" else ZONE
	if run.dist >= run.next_biome_at:
		run.by_mark = true                           # from now on the changes come with the distance marks
		run.next_biome_at = maxf(2 * Z, (floorf(run.dist / Z) + 1) * Z) if run.mode != "endless" else (floorf(run.dist / Z) + 1) * Z
		var at = run.cam + run.view_w + 400          # the new scenery starts ahead, off screen, and scrolls in
		if run.coop:
			pass                                     # (for two, spawn_pattern changed it already, at a place on the road)
		elif run.lvl("drunk") > 0:                   # Relique altérée: the next scenery only goes by, and this one comes back
			run.strip_biome = NEXT_BIOME[run.biome]
			run.strip_x0 = at
			run.strip_x1 = at + RELIC_STRIP
		else:
			run.prev_biome = run.biome
			run.biome = NEXT_BIOME[run.biome]
			run.biome_x = at
		if run.mode == "story":                      # a new place: its own speed (ZONE_SPEED), gaining STORY_GAIN
			run.zone_t = run.t
			run.brake = 0.0                          # (the hourglasses picked up count for one place)
		run.relic = 1
		run.glitch = maxf(run.glitch, 0.5)           # the relic flares: it is what moves the world
		run.events.append("biome")
	if run.strip_biome >= 0:
		if run.strip_x1 < run.cam + run.view_w and run.strip_x1 > run.cam + run.view_w - run.speed * dt * 1.5:
			run.relic = 1                            # the way back comes into sight: the relic flickers again
			run.glitch = maxf(run.glitch, 0.4)
		if run.strip_x1 < run.cam - 400:
			run.strip_biome = -1

	if run.leap == null:
		# --- scenery reacting as he runs past: it shivers and lets something go ---
		var cell = floori(px / PROP_CELL)
		for i in [cell - 1, cell]:
			var pr = prop_at(i)
			if pr == null or not REACTS.has(pr["kind"]):
				continue
			var react: Array = REACTS[pr["kind"]]
			if run.touched.has(i) or p.y < fl - TOUCH_H or biome_at(run, pr["x"]) != 0 or not flat_at(run, pr["x"], PROP_CELL * 0.6):
				continue
			var cx: float = pr["x"] + 34 * PIXEL
			if px < cx - 20 or px > cx + 90:
				continue
			run.touched[i] = run.t
			for k in react[1]:
				part(run, cx + rnd(-40, 40), fl - rnd(60, 150), rnd(-50, 90), rnd(-150, -30), rnd(0.7, 1.4), Color(react[0]), rnd(4, 8), 90)
			run.events.append("shroom" if pr["kind"] == PROP_SHROOM else "rustle")
		for i in run.touched.keys():
			if run.t - run.touched[i] > 6:
				run.touched.erase(i)

		# --- monkeys in the vines: climb high enough under one and it waves back ---
		for m in run.monkeys:
			if m.seen < 0 and absf(px - m.x) < 70 and p.y < GROUND - MONKEY_H:
				m.seen = run.t
				run.events.append("monkey")
				burst(run, m.x, 150, Color("#ffd35c"), 10, 200)
	run.monkeys = run.monkeys.filter(func(m): return m.x > run.cam - 200)

	# --- coins and gems ---
	var reach: float = MAGNET[run.lvl("magnet")]
	var mm = run.lvl(run.mount.kind + "Magnet") if run.mount != null else 0   # the mount's own Aimant
	if mm > 0:
		reach = maxf(reach, MOUNT_MAGNET[mini(mm, MOUNT_MAGNET.size() - 1)])
	var cy = p.y - (20.0 if p.ball != null else 40.0)
	var grab_w = 0.0
	var grab_h = 0.0
	if run.mount != null and MOUNTS[run.mount.kind].has("grab_w"):
		grab_w = MOUNTS[run.mount.kind]["grab_w"]
		grab_h = MOUNTS[run.mount.kind]["grab_h"]
	var tall_now = MOUNTS[run.mount.kind]["tall"] if run.mount != null else HERO_H
	for c in run.coins:
		if run.bubble:
			break                                    # floating: he picks up nothing
		if c.tight != "" and p.ball == null:
			continue                                 # inside a tight place: for the ball only
		if c.blast and not c.toss:                   # it landed before the road under it was laid: it follows the floor
			var under = floor_at(run, c.x) - 40
			if under < c.y - 1:
				c.y = under                          # a ledge was built there: up on it
			elif under > c.y + 1:
				c.toss = true                        # a hollow: it drops in
				c.tvx = 0
				c.tvy = 0
		if c.toss:                                   # thrown by the blast: it falls, bounces lower each time, then stays
			c.tvy += 1000 * d
			c.x += c.tvx * d
			c.y += c.tvy * d
			var f = floor_at(run, c.x) - 40
			if c.y > f and c.tvy > 0:
				c.y = f
				c.tvy *= -0.45
				c.tvx *= 0.55
				if c.tvy > -70:
					c.toss = false
		var dx = px - c.x
		var dy = cy - c.y
		var dist = sqrt(dx * dx + dy * dy)
		if c.loot >= 0:                              # out of a crate: thrown up and ahead, then drawn to the hero
			c.loot += d
			if c.loot < 0.32:
				c.vy += 1500 * d
				c.x += (c.vx + run.speed) * d
				c.y += c.vy * d
				continue
			if dist >= 44:
				c.x += dx / dist * 1000 * d + run.speed * d
				c.y += dy / dist * 1000 * d
				continue
		var caught = false
		if dashing and c.x > minf(px0, px) - COIN_HALF and c.x < px + COIN_HALF and c.y < p.y + COIN_UNDER and c.y > p.y - tall_now - COIN_TOP:
			caught = true                            # the Esquive went through it
		elif grab_w > 0:                             # a mount's own reach
			caught = absf(dx) < grab_w and c.y > p.y - grab_h and c.y < p.y + 10
		elif p.ball != null:
			caught = absf(dx) < COIN_HALF and c.y < p.y + BALL_UNDER and c.y > p.y - BALL_REACH
		else:
			caught = absf(dx) < COIN_HALF and c.y < p.y + COIN_UNDER and c.y > p.y - tall_now - COIN_TOP
		if caught:
			c.gone = true
			if c.heart:                              # a life back, or its worth in gold when none is missing
				if run.hearts < run.max_hearts:
					run.hearts += 1
				else:
					run.gold += HEART_GOLD
				run.events.append("heart")
				burst(run, c.x, c.y, Color("#ff6b8a"), 14, 260)
			elif c.gem != "":
				run.gold += GEMS.get(c.gem, 10)
				run.gems += 1
				run.events.append("gem")
				burst(run, c.x, c.y, Color({"y": "#ffe36a", "r": "#ff6b6b"}.get(c.gem, "#5cc8ff")), 10, 220)
			else:
				run.gold += 1
				run.events.append("coin")
				burst(run, c.x, c.y, Color("#fff3a8"), 4, 150)
			continue
		if dist < reach:
			c.x += dx / dist * 700 * d + run.speed * d
			c.y += dy / dist * 700 * d
	run.coins = run.coins.filter(func(c): return not c.gone and c.x > run.cam - 60)
