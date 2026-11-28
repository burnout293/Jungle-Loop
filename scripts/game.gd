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
# The order of the sceneries (index in Render.BIOMES: jungle, heights, city, dungeon): forest, heights,
# dungeon, city, and back to the forest.
const NEXT_BIOME := [1, 3, 0, 2]
# 0.53: the misty heights (« Les pitons brumeux ») took the ruins' place: no floor, only mist. The Vol is
# always on there; falling into the mist costs a heart and he is lifted back up. In Histoire they come after
# Vorace (her crown gives the Vol); in the Run illimitée only if the Vol is worn (Run.sky_ok), never first.
const SKY := 1
static var MIST_SINK := 18.0         # (0.54) how far under the floor line he sinks into the mist before it bounces him
static var MIST_BOUNCE := 620.0      # ... and how fast it sends him back up (no harm: the mist holds him)
static var PIN_HS := [150.0, 230.0, 310.0]   # a pinnacle's top over the floor line
# 0.54: the heights' figures. Pinnacles in a row PIN_TIME s apart (PIN_GAP units at least); a glider over a
# pinnacle THREAD_GAP above its top (bobbing THREAD_AMP); gliders in a slant at STAIR_HS, GLIDE_STEP apart at
# least; the first SKY_EASY metres of the heights only pinnacles.
static var PIN_TIME := 0.95
const PIN_GAP := 560.0
static var THREAD_GAP := 250.0
const THREAD_AMP := 22.0
const STAIR_HS := [190.0, 300.0, 410.0]
const GLIDE_STEP := 300.0
static var SKY_EASY := 150.0
static var SKY_SERIES := 3           # (0.59) the heights in waves: this many figures, then a breath (coins only)
static var SKY_BREATH := 700.0       # ... this much more room
# 0.54: the cliff between the forest and the heights. The forest's floor climbs CLIFF_H over CLIFF_RISE, runs
# flat CLIFF_TOP (its edge, where the heights begin: render.gd draws the cliff there), then drops into the mist
# CLIFF_LIP further on (the moss hanging over). Off it he leaps (CLIFF_LEAP) and falls CLIFF_FALL s before the
# Vol takes him (the relic's power: in Histoire, his new one); CLIFF_CALM after it, nothing but coins. Histoire,
# alone: the guards are after him again before it (« falaise » in dialogues.txt), then follow him on leaf gliders
# (« envol ») GLIDE_ESCORT s once they are done talking, and fall behind.
const CLIFF_H := 198.0
const CLIFF_RISE := 560.0
const CLIFF_TOP := 560.0
const CLIFF_LIP := 58.0
const CLIFF_LEAP := 330.0
static var CLIFF_FALL := 0.5
const CLIFF_CALM := 1700.0
static var GLIDE_ESCORT := 4.0
const GLIDE_SHIFT := 0.24          # (meanwhile he is this much of the screen further right, eased at GLIDE_PAN a second)
const GLIDE_PAN := 170.0
const CLIFF_TALK := -2.0           # (the talks' places in TALKS: -1 the temple, -2 the cliff, -3 the flight)
const FLIGHT_TALK := -3.0
const PIN_W := 56.0 * 2.25           # its rock, as wide as 56 art pixels (its picture: render.gd)
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
# 0.49: Histoire gives its own kit, whatever was bought or worn: STORY_HEARTS hearts, and the powers of the
# relic's pieces won from the bosses (RELIC_POWERS, in the order the bosses come: Vorace's jade first). The
# piece Pépito stole in the temple gives none (0.53: the jaw; Vorace's crown, the jade, gives the Vol). main.gd sets STORY_TRY (the attempt, counted from
# the last piece won) and STORY_CHAP (the pieces held) before a run alone: what the guards say depends on them.
static var STORY_HEARTS := 2
const RELIC_PIECES := ["jade", "ambre", "braise"]           # (0.53: the jaw, "lune", is the piece stolen)
const RELIC_POWERS := ["flight", "sphere", "slow"]        # (0.60: the amber head, the eagle's, gives the Sphère)
const RELIC_POWER_NAMES := ["Vol", "Sphère", "Sablier"]
const RELIC_PIECE_NAMES := ["La couronne de Vorace", "La tête d'ambre", "La tête de braise"]
static var STORY_TRY := 1
static var STORY_CHAP := 0
static var HURT_INV := 1.6          # invincible this long after a blow

# 0.49: the hero, the dangers, the coins and the things to pick up are SIZE bigger, drawn (render.gd) and
# touched alike (their boxes below). The scenery, the mounts and the bosses keep their size.
const SIZE := 1.15
const HERO_H := 80.0 * SIZE
const HERO_HALF := 14.0 * SIZE # hitbox, smaller than the sprite: forgiving
const SPIKY_W := 68.0 * SIZE
const SPIKY_H := 54.0 * SIZE
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
# (0.67) The dungeon in two: a deck of stone slabs DECK_H over the floor runs all along it (the lower part's roof,
# the upper part's floor), each part two lines high (the floor or the deck, and a jump). Every SPLIT_CYCLE metres
# a pipe of the floor throws whoever takes it up through a shaft in the deck (SPLIT_LAUNCH); from the deck, the
# shaft drops him to the floor (or he jumps over it). Each part has its own dangers, never more than it can pass.
static var SPLIT_ON := true
static var DECK_H := 350.0
static var SPLIT_CYCLE := 80.0
static var SPLIT_LAUNCH := 1420.0
static var SKY_RACE_AT := 150.0   # (0.65) Affrontement « Pièces »: the cliff to the heights this many metres in
static var BALL_PLUS := 4.0      # (0.65) m/s more while rolled up (the Sphère's mode)
static var GRAV_UP := 1.2        # (0.65) Gravité augmentée: gravity times this (jumps 1/1.2 as high, back down sooner)
static var GRAV_DOWN := 0.82     # (0.65) Gravité réduite: gravity times this (jumps higher, floats down)
# The flyer: a "!" at the right edge shows its height DART_WARN seconds before it crosses the screen; while it
# shows, it drifts lazily towards his height (late: DART_LAG, never faster than DART_TRACK units a second), and
# (0.54) stops following him DART_FREEZE seconds before it goes: the height it will cross at is known by then.
# 0.55: only those aimed at him (the Vol) follow his height; on foot each keeps the height it was laid at, never
# the one the flyer before it had (dart_alt). An aimed one that would cross where the last one did (within
# DART_SPREAD) is moved 1.6 DART_SPREAD up or down as it stops: never twice in a row at the same height.
# On foot, the flyers of a wave are DART_FOOT_GAP seconds apart at least: each one can be jumped.
const DART_W := 64.0 * SIZE
const DART_H := 40.0 * SIZE
static var DART_WARN := 2.0
static var DART_TRACK := 160.0
static var DART_FREEZE := 1.0
const DART_SPREAD := 80.0
const DART_FAIR := 300.0          # (0.55) on foot: what is checked round where a flyer meets him (_dart_lane)
const DART_LOW_MAX := 100.0       # ... a flyer lower than this is jumped; up to DART_HIGH_MAX, stayed under
const DART_HIGH_MAX := 230.0
const JUMP_TOP := 200.0           # ... the height a jump reaches (held), over the floor
const DART_LAG := 1.6
const DART_FOOT_GAP := 0.85
static var DART_SPEED := 800.0
const GAP_DIST := 420.0
const GAP_TIME := 0.72
const GAP_MARGIN := 110.0
# Spiders in a row: SPIDER_GAP_TIME seconds apart at the speed the road is laid for, never closer than
# SPIDER_GAP_MIN (and as much room after the row). How often a row of spiders, a wave of flyers (the
# missiles in the city) come: their weights among the patterns.
static var SPIDER_GAP_TIME := 1.15
static var SPIDER_GAP_MIN := 440.0
static var CHAIN_SPIDERS := 5
static var CHAIN_WAVES := 3
# A nest of spiders (0.44): 4 or 5 at once, 200 units apart, as many as in the dragonfly's sky. One low (jump
# it); over his jump only spiders out of reach; elsewhere spiders above his head, maybe one at head height.
static var CHAIN_NESTS := 6
const NEST_STEP := 200.0
# The swarm: its creatures and their red band take this share of a lane's height (the lanes stay where
# they are): more room in the free one.
static var FM_THICK := 0.65
# A crate broken: its coins burst out ahead of him, fall, bounce and wait on the floor.
static var CRATE_COINS := 50
# The last heart lost (alone): thrown ahead, he lands head first in the ground, legs kicking, PLANT_TIME
# seconds; then the end.
const PLANT_KICK := 1.5
const PLANT_UP := 760.0
const PLANT_TIME := 1.4
# Histoire: out of the temple he runs on, the camera still, to EXIT_LEAD of the screen past his place; then it
# catches him up in EXIT_CATCH seconds (eased in and out), and the run starts. The guards come out of the
# doorway GUARD_OUT s after the blast (the second GUARD_NEXT s later), keep his pace while the camera has not
# caught him up, then close in fast (GUARD_CLOSE of the gap a second, at most GUARD_RUSH more than him) to
# GUARD_GAP behind him (the second GUARD_STEP further), never touching him. Only to be looked at.
const EXIT_LEAD := 0.24
const EXIT_CATCH := 1.0
const DOOR_X := 108.0              # the temple's doorway, in the world (render: TEMPLE_X + 233 art pixels)
const TEMPLE_PAN := 416.0          # 0.52: how far left the camera stands at the start, on the whole temple (render
                                   # TEMPLE_X, in world pixels); it slides to the doorway while the temple rumbles
const GUARD_OUT := 0.7
const GUARD_NEXT := 0.4
const GUARD_GAP := 117.0
const GUARD_STEP := 76.0
const GUARD_CLOSE := 3.0
const GUARD_RUSH := 900.0
const GUARD_FLEE := 420.0          # turned back: off to the left at this pace (world), soon
# ... planted with them at his heels (alone): they leap on him (CATCH_LEAP s), a cloud of dust and blows until
# CATCH_FIGHT, then he is carried off on a spit back to the temple (CATCH_WALK units a second); the run ends
# once they are off the screen (CATCH_END at most).
const CATCH_LEAP := 0.6
const CATCH_FIGHT := 2.5
const CATCH_WALK := 240.0
const CATCH_END := 7.5
const CATCH_SHIFT := 0.2           # (meanwhile the camera steps back this much of the screen: the scene in the middle)
# 0.47: the pygmies come back for him wherever he falls (alone, no boss): from off the screen they run in first
# (CATCH_COME). Tied to the spit, the Couteau suisse is offered ESC_OFFER s (the spit going on slowly, CATCH_SLOW);
# used: the escape, a cursor and a zone going to and fro on a bar; a touch with the cursor in the zone cuts a
# rope (ESC_ROPE, one more per escape already made this run), out of it costs ESC_MISS s of ESC_TIME. The zone:
# ESC_ZONE of the bar, ESC_LANTERN more per lantern lit (ESC_ZONE_MAX at most), 15 % less per escape made; the
# cursor ESC_CURSOR bars a second, the zone drifting ESC_DRIFT, both ESC_HARDER faster per escape made.
const CATCH_COME := 0.8
const CATCH_SLOW := 40.0
static var ESC_OFFER := 5.0
static var ESC_TIME := 6.0
static var ESC_MISS := 1.2
static var ESC_ROPE := 3
static var ESC_ZONE := 0.16
static var ESC_LANTERN := 0.01
static var ESC_ZONE_MAX := 0.4
static var ESC_CURSOR := 1.1
static var ESC_DRIFT := 0.3
static var ESC_HARDER := 0.25
# 0.54: the Couteau suisse to equip (« swiss »): SWISS_FREE[level] escapes a run without taking one from the
# stock (level 1: one, level 3: two); from level 2, every escape is easier: its zone SWISS_ZONE times wider,
# the cursor and the zone SWISS_SLOW times as fast.
const SWISS_FREE := [0, 1, 1, 2]
static var SWISS_ZONE := 1.4
static var SWISS_SLOW := 0.75
const GAP_FILL := 640.0
const DECOR_RATE := 0.12
const HOVER_W := 60.0 * SIZE
const HOVER_H := 56.0 * SIZE
# Not before this many metres: the hanging dangers, low then at head height.
static var FROM_LOW := 150.0
static var FROM_MID := 1500.0
# 0.49: the dangers come one kind at a time: the spiders from FROM_LOW, the swarms from FM_FIRST (300 m), the
# flyers (fonceurs, their waves) from FROM_DARTS, the nests of spiders from FROM_NESTS.
static var FROM_DARTS := 400.0
static var FROM_NESTS := 900.0
# 0.49: the speed stops growing at SPEED_CAP (Run illimitée) or STORY_CAP (Histoire); the road gets harder by
# its layout instead, more and more from PRESS_FROM metres to PRESS_FULL (Histoire: PRESS_STORY of it at
# most): the gaps between patterns up to PRESS_GAP shorter (never shorter than what a jump needs to land),
# the rows of spiders, the nests and the waves up to PRESS_CHAINS more often, rows of spiders up to four.
static var SPEED_CAP := 1200.0
static var STORY_CAP := 1040.0
static var PRESS_FROM := 300.0
static var PRESS_FULL := 3300.0
static var PRESS_STORY := 0.6
static var PRESS_GAP := 0.25
static var PRESS_CHAINS := 1.0
static var PRESS_NEED := 0.12       # (the time a landing is given, this much shorter at full pressure: the benches say how far)
static var PRESS_FILL := 0.0        # (a wide gap gets a flyer that much more often at full pressure: 0, a flyer
                                    # more there made a spot no one gets through for two, fair_bfs_coop, seed 701)

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
static var BOSS_AT := 1500.0
static var BOSS_SPEED := 560.0
static var BOSS_FIGHT := 26.0
const BOSS_ENTER := 1.6        # seconds she takes to slide in before the fight
# Histoire for two: Vorace is laid on the road, not on the screen (coop_run). She shows when the heroes
# reach coop_xb, falls once they reach coop_xf; the road is laid as if seen on a COOP_VIEW screen: coins
# from COOP_CALM before her until a screen past coop_xb, then her lily pads until a screen past coop_xf,
# then her blue gems at coop_xg (COOP_GEMS past coop_xf), then nothing until COOP_GAP past the pads' end.
const COOP_VIEW := 1280.0
const COOP_CALM := 400.0
const COOP_GEMS := 1770.0
const COOP_GAP := 2400.0
const COOP_AHEAD := 1480.0     # a new scenery is laid this far past the mark where the speed starts again
const BOSS_W := 446.0
const BOSS_MOUTH_X := 50.0
const BOSS_MOUTH_Y := 223.0
const LANE := {"low": 28.0, "mid": 115.0, "high": 250.0, "vine": 470.0}
# The platforms: Vorace's flying lily pads bob (PAD_BOB units, PAD_SPEED radians a second).
const PAD_BOB := 8.0
const PAD_SPEED := 1.8
const ISLE_W := [240.0, 240.0, 300.0]       # (0.49: the forest's two drawn platforms: 107 and 133 art pixels to walk on)
# 0.50 (reglages/equilibrage.txt [plateformes]): the forest's platforms of the "hills" stretch may slope (fixed).
# ISLE_FLAT of them stay flat; the others' right end stands higher by one of ISLE_UP. Only the last one of the
# stretch may go down (ISLE_DOWN): one going down, the next would be out of reach of a jump.
static var ISLE_FLAT := 0.5
static var ISLE_UP := [27.0, 45.0]
static var ISLE_DOWN := [27.0, 45.0]
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
static var SPIDER_STILL_M := 10.0  # (0.63) a red spider is still at its height this many metres before him
static var SPIDER_RUN_M := 12.0    # (0.63) ... after going there, one way, over this many metres
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
# 0.47: what floats there, alone (for two: nothing, their bubble is their second chance). BONUS_SHARE: the
# hourglass's share, then what was the feather's (0.55: an hourglass too); the rest an urn, once a run at most,
# from URN_FROM metres.
static var BONUS_SHARE := [0.4, 0.45]
static var URN_FROM := 600.0          # (unused since 0.65)
static var URN_EVERY := 25000.0       # (0.65) a flying urn: extremely rare, one every this many metres, never in Histoire
# 0.55, equipped (Run illimitée only): the Idole dorée adds IDOL_MUL[level] to every coin picked up; the Corne
# de brousse: out of the temple on the rhino, for HORN_M[level] metres.
const IDOL_MUL := [0.0, 0.25, 0.5, 0.75]
const HORN_M := [0.0, 300.0, 500.0, 800.0]
const BONUS_LOW := 60.0                 # (0.44: a much wider zigzag, BONUS_ZIG seconds each way)
const BONUS_HIGH := 290.0
const BONUS_ZIG := 0.7
static var BRAKE_SHARE := 0.2
static var BRAKE_PACE := 0.75
const DART_TOP := 560.0                  # the highest a flyer can come: the hero's middle just under the ceiling
const CAMP_BAND := 70.0
static var CAMP_TIME := 2.6
static var CAMP_AGAIN := 1.6
# The swarms: the first one between FM_FIRST metres, the next ones FM_NEXT after the last.
static var FM_FIRST := [300.0, 380.0]
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

# (0.59) The dungeon's pipes: thrown up this fast out of a « pipeup » (its coins at PIPE_PEAK), down a mouth's
# slope over PIPE_SLOPE; a swarm of will-o'-the-wisps is a wall over a pipe WISP_WALL of the time (past 450 m).
const PIPE_LAUNCH := 1150.0
const PIPE_PEAK := 380.0
const PIPE_SLOPE := 170.0
static var WISP_WALL := 0.35
# ---------- 0.60: the eagle, the heights' guardian (Histoire, alone) ----------
# In the heights (EAGLE_AT metres in), alone, the scenery held until it is beaten. Three lines (low, middle,
# high: EAGLE_LANES, their middles over the floor; EAGLE_BAND tall, the hero is 92: in another line, he is
# clear). Phase 1, a clear sky: it flies off and rushes along one line from the right, the line flashing
# EAGLE_WARN s before (EAGLE_RUSHES times, never the same line twice in a row). Phase 2, dark clouds: it hovers
# by him and slams its wings shut over two lines, the middle and one more, raised EAGLE_RAISE s first
# (EAGLE_SLAMS times). Phase 3, the storm: it roars and does not attack; hail falls slowly, to slip between
# (EAGLE_STORM s). The end: lightning roasts it, it crashes into a column; he lands on the column, where the
# yellow piece of the relic (the amber head: the Sphère) waits; then on to the dungeon.
class Eagle:
	var phase := "enter"     # enter, rush, wings, storm, strike, crash, relic, land
	var t := 0.0             # time in the phase
	var step := ""           # rush: out, warn, go, pause; wings: raise, slam, rest
	var st := 0.0            # time in the step
	var sx := 0.0            # where it is on the screen (game units from the camera's left)
	var y := 0.0             # its middle (world y)
	var n := 0               # attacks done in this phase
	var lane := -1           # rush: its line; wings: the line left free
	var last := -1
	var obs: Array = []      # the boxes that hurt now
	var hail_t := 0.0
	var hail_hi := false
	var pillar_x := 0.0      # the end: the column (world x)
	var fall_x := 0.0
	var fall_y := 0.0
	var vmax := -1.0         # the end: how fast he may still go (he stops on the column); -1 no limit
	var dark := 0.0          # 0 a clear sky, 1 dark clouds, 2 the storm (render.gd eases to it)
	var bolt := -1.0         # a flash of lightning: how long ago (-1 none)

static var EAGLE_AT := 700.0
const EAGLE_LANES := [150.0, 300.0, 450.0]
const EAGLE_BAND := 116.0
const EAGLE_RUSHES := 6
const EAGLE_WARN := 1.1
const EAGLE_RUSH := 1500.0
const EAGLE_W := 230.0
const EAGLE_SLAMS := 6
const EAGLE_RAISE := 1.0
const EAGLE_SLAM := 0.35
const EAGLE_REST := 0.7
const EAGLE_STORM := 14.0
const EAGLE_HAIL := 0.42
const HAIL_V := 170.0
const HAIL_R := 30.0
const PILLAR_TOP := 330.0

## The eagle's turn: it comes, then its phases, then the end (see above). Alone, in Histoire only.
static func eagle(run: Run, d: float) -> void:
	if run.eagle == null:
		if run.eagle_done or run.mode != "story" or run.coop or run.dead or run.leap != null or run.boss != null:
			return
		if not run.sky or biome_at(run, run.cam + run.sx) != SKY:
			return
		if run.sky_dist0 < 0:
			run.sky_dist0 = run.dist
		if run.dist < run.sky_dist0 + EAGLE_AT:
			return
		var ne = Eagle.new()
		ne.sx = run.view_w + 260
		ne.y = GROUND - EAGLE_LANES[2]
		run.eagle = ne
		run.next_biome_at = INF                      # (the dungeon waits until it is beaten)
		run.fm = null
		run.fm_due = false
		run.next_fm = INF
		run.cues.clear()
		for o in run.obs:                            # the heights' road ahead: gone, the eagle alone
			if not o.gone and o.x + o.w > run.cam + run.sx + 40:
				o.gone = true
		run.relic = 1
		run.events.append("eagle")
		return
	var e: Eagle = run.eagle
	var p = run.p
	var px = run.cam + run.sx
	e.t += d
	e.st += d
	if e.bolt >= 0:
		e.bolt += d
	e.vmax = -1.0
	match e.phase:
		"enter":                                     # it flies in and hovers, high on the right
			e.sx += (run.view_w * 0.74 - e.sx) * minf(1, d * 2.2)
			e.y += (GROUND - EAGLE_LANES[1] - e.y) * minf(1, d * 2.0)
			if e.t > 2.0:
				_eagle_phase(run, e, "rush")
				e.step = "out"
		"rush":
			match e.step:
				"out":                               # up and off the screen
					e.sx += 700 * d
					e.y -= 600 * d
					if e.st > 0.5:
						_eagle_lane(e, W.randi() % 3)
						e.step = "warn"
						e.st = 0
						run.events.append("screech")
				"warn":                              # its line flashes at the right edge
					e.sx = run.view_w + 200
					e.y = GROUND - EAGLE_LANES[e.lane]
					if e.st >= EAGLE_WARN:
						var o = add_obs(run, px + run.view_w - run.sx + 40, e.y - EAGLE_BAND / 2, EAGLE_W, EAGLE_BAND, "eagle", false)
						o.ghost = false
						o.vx = run.speed - EAGLE_RUSH
						e.obs = [o]
						e.step = "go"
						e.st = 0
						run.events.append("rush")
				"go":                                # across the screen along its line
					e.sx -= EAGLE_RUSH * d                # (with its box: the same pace across the screen)
					if e.sx < -EAGLE_W:
						for o in e.obs:
							o.gone = true
						e.obs = []
						e.n += 1
						e.step = "pause"
						e.st = 0
				"pause":
					if e.st > 0.35:
						if e.n >= EAGLE_RUSHES:
							_eagle_phase(run, e, "wings")
							e.sx = run.view_w + 200
						else:
							_eagle_lane(e, W.randi() % 3)
							e.step = "warn"
							e.st = 0
							run.events.append("screech")
		"wings":                                     # dark clouds: by him, its wings over two lines
			e.dark = 1.0
			e.sx += (run.sx + 230 - e.sx) * minf(1, d * 3)
			e.y += (GROUND - EAGLE_LANES[1] - e.y) * minf(1, d * 3)
			match e.step:
				"", "rest":
					if e.st >= (0.8 if e.step == "" else EAGLE_REST):
						for o in e.obs:
							o.gone = true
						e.obs = []
						if e.n >= EAGLE_SLAMS:
							_eagle_phase(run, e, "storm")
						else:
							e.lane = 0 if W.randf() < 0.5 else 2   # the line left free: low or high
							if e.lane == e.last and W.randf() < 0.6:
								e.lane = 2 - e.lane
							e.last = e.lane
							e.step = "raise"
							e.st = 0
							run.events.append("screech")
				"raise":
					if e.st >= EAGLE_RAISE:            # they slam shut: the middle line and the other one
						var x0 = px - 140
						var w_ = 140 + run.speed * EAGLE_SLAM + 260
						for k in 3:
							if k == e.lane:
								continue
							var o = add_obs(run, x0, GROUND - EAGLE_LANES[k] - EAGLE_BAND / 2, w_, EAGLE_BAND, "eagle", false)
							o.ghost = false
							e.obs.append(o)
						e.step = "slam"
						e.st = 0
						run.shake = maxf(run.shake, 0.35)
						run.events.append("slam")
				"slam":
					if e.st >= EAGLE_SLAM:
						for o in e.obs:
							o.gone = true
						e.obs = []
						e.n += 1
						e.step = "rest"
						e.st = 0
		"storm":                                     # the storm: it roars, the hail falls
			e.dark = 2.0
			e.sx += (run.view_w * 0.8 - e.sx) * minf(1, d * 2)
			e.y += (GROUND - EAGLE_LANES[2] - 40 - e.y) * minf(1, d * 2)
			if floori(e.t / 2.6) > floori((e.t - d) / 2.6):
				run.events.append("roar")
			e.hail_t -= d
			if e.hail_t <= 0 and e.t < EAGLE_STORM - 1.5:
				e.hail_t = EAGLE_HAIL
				e.hail_hi = not e.hail_hi            # (one high, one low: never two in one column)
				var hy = rnd(60, 300) if e.hail_hi else rnd(300, GROUND - 160)
				var o = add_obs(run, px - run.sx + run.view_w + rnd(40, 260), hy, HAIL_R, HAIL_R, "hail", false)
				o.ghost = false
				o.vy = HAIL_V * rnd(0.8, 1.2)
			if e.t >= EAGLE_STORM:
				_eagle_phase(run, e, "strike")
				e.bolt = 0.0
				e.pillar_x = px + run.view_w * 0.95
				run.events.append("thunder")
				run.flash = 1.0
				run.shake = 1.0
		"strike":                                    # roasted by the lightning
			if e.t >= 0.7:
				_eagle_phase(run, e, "crash")
				e.fall_x = run.cam + e.sx
				e.fall_y = e.y
		"crash":                                     # it falls into the column, then down into the mist
			var k = clampf(e.t / 0.9, 0, 1)
			var wx = lerpf(e.fall_x, e.pillar_x, k)
			var wy = lerpf(e.fall_y, GROUND - PILLAR_TOP + 40, k * k)
			if e.t > 0.9:
				wx = e.pillar_x + 30
				wy = GROUND - PILLAR_TOP + 40 + 900 * (e.t - 0.9) * (e.t - 0.9)
			if e.t - d < 0.9 and e.t >= 0.9:
				run.events.append("eaglefall")
				run.shake = 1.0
			e.sx = wx - run.cam
			e.y = wy
			if e.t > 1.8:
				_eagle_phase(run, e, "relic")
		"relic":                                     # to the column's top, where the piece waits
			var r = e.pillar_x - px
			e.vmax = sqrt(2 * 700 * maxf(0, r))      # (he slows down to stop on it)
			var top = GROUND - PILLAR_TOP
			p.y = move_toward(p.y, top, 700 * d)
			p.vy = 0
			p.flying = false
			p.rotor = false
			if r <= 4:
				p.y = top
				p.ground = true
				_eagle_phase(run, e, "land")
				if run.chap < 2:                     # Histoire: the amber head, its power at once (the Sphère)
					run.won = 1
					grant(run, RELIC_POWERS[1])
				run.events.append("relic")
				run.events.append("eaglewon")
		"land":                                      # on the column, the piece held up
			e.vmax = 0.0
			p.y = GROUND - PILLAR_TOP
			p.vy = 0
			p.ground = true
			if e.t > 2.2:
				for o in e.obs:
					o.gone = true
				run.eagle = null
				run.eagle_done = true
				run.urns += 1                        # (an urn for it, as for Vorace)
				run.events.append("urn")
				run.next_biome_at = run.dist         # on to the dungeon
				p.ground = false
				p.vy = -300

static func _eagle_phase(run: Run, e: Eagle, ph: String) -> void:
	e.phase = ph
	e.t = 0.0
	e.step = ""
	e.st = 0.0
	e.n = 0
	for o in e.obs:
		o.gone = true
	e.obs = []

## A line for the next rush: never the same twice in a row.
static func _eagle_lane(e: Eagle, k: int) -> void:
	if k == e.last:
		k = (k + 1 + W.randi() % 2) % 3
	e.lane = k
	e.last = k

# Follower monsters: FM_LANES lanes of FM_STEP each above the floor.
const FM_W := 90.0 * SIZE
const FM_H := 64.0 * SIZE
const FM_RUSH := 1150.0
const FM_LANES := 5
const FM_STEP := 110.0
# The city's drones (0.56): once there they charge LASER_ON s, then the beam burns LASER_LIVE s only (it was
# 0.45 s) and fades by LASER_END. Before it, a beep LASER_TICKS seconds before it burns (a ring closing on each
# drone, render.gd), and « SAUTE ! » over him from the third one when a lane aimed at crosses him standing: a
# jump from then to 0.1 s before the beam gets him over it.
const LASER_ON := 0.3
const LASER_LIVE := 0.15
const LASER_OFF := LASER_ON + LASER_LIVE
const LASER_END := LASER_OFF + 0.15
const LASER_TICKS := [0.9, 0.6, 0.3]
const LASER_H := 40.0

static var GEMS := {"y": 5, "r": 10, "b": 20}
static var SCATTER := [0.0, 0.012, 0.022, 0.035]
const HEART_GOLD := 25
# Picking up: one box, COIN_HALF to each side of him, from just under his feet to COIN_TOP above his head
# (the leaves on his head reach well above his hitbox). Rolled into a ball, as high as the ball (BALL_REACH).
# (It used to be that box and a circle round his middle: the box now has the circle's width.)
const COIN_HALF := 44.0 * SIZE
const COIN_TOP := 30.0 * SIZE
const COIN_UNDER := 4.0
const BALL_REACH := 64.0 * SIZE
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
const PROP_GONE := [0, 2]                # the forest's big tree and its signpost: no longer stood behind the path
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
	var dodged := false         # a missile gone past him untouched (counted once, for the objectives)
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
	var alt := 0.0           # a flyer gone across: its height over the floor, kept all the way
	var meet := 0.0          # (0.55) on foot: where it will meet him (worked out as it stops)
	var y0 := 0.0            # a red spider: the middle of its course, and how far it goes each way
	var amp := 0.0
	var lane_y := -1.0       # (0.61) a red spider: the line it stops on before he gets there, and how fast it goes
	var lane_v := 0.0
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
	var y := 0.0                   # its top at its left end
	var w := 254.0
	var slope := 0.0               # 0.50: how much lower its right end stands (negative: higher), fixed: top_at
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
	var isles := false             # 0.49: platforms stand in front of it (the forest: the mound they come from)

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
	var open := false      # (0.59) a pipe of the dungeon: anyone gets in (curled up), not only with the Sphère
	var launch := false    # ... out of it thrown up high
	var launch_v := 0.0    # (0.67) ... this fast (0: PIPE_LAUNCH)
	var mouth := -1.0      # ... its mouth in the air, this high over the floor (in as he passes it), out by the floor
	var wall := false      # ... the way under a wall of will-o'-the-wisps: in anywhere along it

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
	var until := 0.0         # (0.55) the Corne de brousse's rhino: the distance it goes to (0: its own time)

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
	var wall := false          # (0.59) the dungeon: its first wave fills every lane, a pipe under it (Zone.wall)
	var walled := false
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
	var planted := false      # head first in the ground: legs kicking until the end
	var pt := 0.0

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
	var ball := false        # (0.65) the Sphère's button: Normal / Sphère

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
	var wait_max := 0.0                # (0.52) the longest the wait has been: how far the camera has slid
	var exploded := false
	var boom := 0.0
	var biome_x := -1e9             # world x where the current scenery begins
	var coop_biome_x := INF         # for two: the road's next mark, where spawn_pattern changes the scenery
	var coop_xb := INF              # Histoire for two: where Vorace shows (the hero's x), see COOP_VIEW
	var coop_xf := INF              # ... where she falls
	var coop_xg := INF              # ... where her blue gems are laid
	var coop_gems := false          # ... laid already
	var coop_zone_at := INF         # ... where the next place's speed starts (the hero's x)
	var boss_rng := RandomNumberGenerator.new()   # for two: Vorace's own dice (she aims at each hero apart)
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
	var zone_t := 0.0              # Histoire: when the current scenery began (pace_t; the speed starts again)
	var pace_t := 0.0              # 0.49: the speed's clock: t, except while the guards talk (alone)
	var talks: Array = []          # 0.49: what the guards say on this run (talks_for)
	var chap := 0                  # 0.49: Histoire: the relic's pieces held at the start
	var won := -1                  # 0.49: the piece won on this run (its index), -1: none
	var zone_k := 1.0              # (unused)
	var mounts: Array = ["gorilla", "rhino", "dragonfly"]   # the animals that may wait on the road (Montures: on / off)
	var brake := 0.0               # what the brakes picked up take off his speed, for good
	var bonuses: Array = []        # the rare floating things (Item: kind "brake" or "urn")
	var urn_laid := false          # an urn floated this run
	var home_scene := -1           # (0.66) the temple's little scene (render.gd draw_home_scene): 0 the campfire, 1 the
	                               # ledges, 2 the rhino; -1 none (Histoire, races, for two)
	var no_coins := false          # (0.65) Affrontement « Trésor », its last race: no coins
	var sky_only := false          # (0.65) Affrontement « Pièces »: the misty heights, early and for good
	var ball_on := false           # (0.65) the Sphère's mode: rolled up for good, until pressed again
	var urn_n := 0                 # (0.65) urns laid so far (one every URN_EVERY m)
	var urns := 0                  # picked up this run
	var lanterns := 0              # the forest's lanterns lit as he ran past (0.47: the escape's zone grows)
	var idol := 0.0                # the Idole dorée equipped: the share it adds (and what it has added so far)
	var idol_acc := 0.0
	var knives := 0                # (0.47-0.54: the Couteaux suisses in stock; none since), the escapes made this run
	var free_knives := 0           # (0.54) the escapes the Couteau suisse equipped still gives this run
	var escapes := 0
	var next_bonus := 0.0          # metres
	var camp_y := 0.0              # the height he has kept (the Vol), and for how long
	var camp_t := 0.0
	var last_gap := -1             # the gap of the last column of spiders
	var last_alt := -1.0           # (0.55) the height of the last flyer laid on foot, and of the last aimed one gone
	var last_aim := -999.0
	var fatal := false             # the blow that ends the run has been dealt ("fatal" event: the photo)
	var spider_xs: Array = []         # where the road laid its spiders (the columns, see add_hover)
	# Coop (coop.gd): two phones, two heroes, one road. No mount nor hourglass then (they change a
	# player's speed, so his road), and the road is laid for road_tier, the lesser of the two players'.
	var coop := false
	var home := 200.0                  # where on screen he runs (PX; in coop the guest a little behind the host)
	var road_tier := -1                # what the road may ask of him (-1: what his own upgrades allow)
	var mate = null                    # the partner's last state: {at, x, y, vy, v, g, f, ph, b, d}, world units
	var mate_view = null               # where he is drawn: his state a few hundredths ago, smoothed (Coop.view)
	var acts: Array = []               # for two: the actives he started this step (dash, slow, monster), told to the partner
	var act_in: Array = []             # for two: those the partner started, to start here next step (remote_act)
	var bubble := false                # fallen: he floats after the partner until rescued
	# The race for four (0.48, race.gd): the road as for two (coop is true), but whoever falls is out.
	var race := false
	var rivals: Array = []             # the others where they are drawn: [{k, name, x, y, ph, g, f, out}] (render.gd)
	var signs: Array = []              # boards along the road at friends' records: [{d (metres), name, own, x}]
	var board: Array = []              # the race's places, as main.gd last had them (Race.board)
	var saying := ""                   # Histoire: a line of the guards being said (main.gd shows it)
	var say_age := 0.0                 # ... since when (typed out SAY_RATE letters a second)
	var held := 0.0                    # ... how far he ran while they talked: not counted in the distance
	var blast_t := -1.0                # ... when the doorway blew out: the guards come out after him (render)
	var guards_off := -1.0             # ... when they turned back (their first line on the way: « DEMI-TOUR !! »)
	var cliff_due := false             # (0.54) the heights next after the forest: their cliff at the next pattern
	var cliff_x := -INF                # ... the cliff's edge (where the heights begin)
	var soar := 0.0                    # ... off it: falling, whatever is pressed, until the Vol takes him
	var escort := 0.0                  # ... Histoire: the guards on their gliders behind him (seconds left)
	var spectating := false            # (0.55) fallen in an Affrontement: he watches the others (spectate)
	var daily := false                 # (0.57) the Course du jour (daily.gd): its rule, its tiers
	var gain_mul := 1.0                # (0.57) ... how much faster the speed grows (its rule « Pressé »)
	var drop_kinds: Array = []         # (0.58) ... the dangers it leaves out (« obstacles | araignees »)
	var emote_me := {}                 # (0.58) for two: the words I just said ({text, t: the run's time then})
	var revives := {}                  # (0.59) Histoire: the levels whose one way back is used (level -> true)
	var skyfall = null                 # (0.59) Histoire, the heights: his long fall to the forest's floor ({t, ph, cut, at, x})
	var slimes: Array = []             # (0.59) Histoire, the dungeon: the slimes after him ({x, ph})
	var sky_n := 0                     # (0.59) the heights: figures laid since the last breath
	var cues: Array = []               # ... where the way through the next figure is ({x, y}: render.gd's arrows)
	var eagle = null                   # (0.60) Histoire, the heights: the eagle (Eagle), fighting
	var eagle_done := false
	var sky_dist0 := -1.0              # ... where the heights began (its distance)
	var emote_mate := {}               # ... and those my partner said
	var glide_go := false              # ... and off the cliff they have jumped (a line said « deltaplanes »)
	var say_queue: Array = []          # ... the lines still to say
	var talk_zones: Array = []         # ... where they talk: {at, x0, x1, lines, on, wait, done}
	var intro := false                 # ... the temple's scene: the camera still while they talk, then the blast
	var intro_len := 0.0               # ... how long it lasts (a touch skips it, once it has run a moment)
	var who := ""                      # ... who says the line being said (« Pépito », « Chef Massue »...)
	var out := 0                       # out of the temple: 0 running out (Histoire: the camera still), 1 the camera
	var catch_from := 0.0              #   catching him up (from where he was on screen, since when), 2 following
	var catch_t := 0.0
	var guards: Array = []             # Histoire: the guards after him, [{x (world), v, on}] (render draws them)
	var caught = null                  # ... alone, planted with them at his heels: {t, x (the spit, world), gx}
	var bubble_pos := Vector2.ZERO     # where his bubble is (world)
	var mate_bubble := Vector2.ZERO    # where the partner's bubble is, following him (world)
	var strip_biome := -1          # Relique altérée: a short strip of another scenery, from strip_x0 to strip_x1
	var strip_x0 := 0.0
	var strip_x1 := 0.0
	var sky := false               # 0.53: he is in the misty heights now (the Vol on, the mist under him)
	var sky_ok := false            # ... and the heights may come on this run (Histoire, or the Vol worn: new_run)

	## (0.65) The gravity powers: Gravité augmentée (lower, quicker jumps), Gravité réduite (higher, slower).
	func grav() -> float:
		return (Game.GRAV_UP if int(up.get("gravUp", 0)) > 0 else 1.0) * (Game.GRAV_DOWN if int(up.get("gravDown", 0)) > 0 else 1.0)

	func lvl(id: String) -> int:
		if sky and id == "flight":               # (0.53) the heights: the Vol always on
			return maxi(1, int(up.get(id, 0)))
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
	if run.mode != "story":                          # (run.base: Sprint included, worn by both: the host's kit)
		return minf(SPEED_CAP, sqrt(run.base * run.base + 2.0 * SPEED_GAIN * maxf(0.0, x)))
	if x < run.coop_xb:                              # Histoire: the forest's speed, then Vorace's, then each place's
		return minf(STORY_CAP, sqrt(run.base * run.base + 2.0 * STORY_GAIN * maxf(0.0, x)))
	if x < run.coop_xf + COOP_VIEW:
		return BOSS_SPEED
	var m = run.coop_xg + 16 * 48                    # the first new place (never coop_zone_at: it moves on
	if x < m:                                        # with the hero) / (the speed coming back after her fall)
		var v0 = BOSS_SPEED * DEATH_PACE
		return sqrt(v0 * v0 + 2.0 * RAMP * (x - run.coop_xf))
	var biome = next_biome(run, 0)
	for i in 64:
		var nm = coop_next_mark(m)
		if x < nm:
			break
		m = nm
		biome = next_biome(run, biome)
	var z = ZONE_SPEED.get(biome, SPEED_BASE) + run.base - SPEED_BASE
	return minf(STORY_CAP, sqrt(z * z + 2.0 * STORY_GAIN * (x - m)))

## Histoire for two: the mark after `m` where a new place begins (its speed starts again there).
static func coop_next_mark(m: float) -> float:
	return maxf(2.0 * ZONE * PPM, (floorf(m / (ZONE * PPM)) + 1) * ZONE * PPM)

## Whether the road laid at x is Vorace's (her lily pads, nothing else). Alone: while she is there. For two:
## from a screen past where she shows to a screen past where she falls, the same on both phones.
static func boss_road(run: Run, x: float) -> bool:
	if run.coop:
		return x >= run.coop_xb + COOP_VIEW and x < run.coop_xf + COOP_VIEW
	return run.boss != null

## Trèfle's level as the road sees it: for two, none (its extra gems would be laid for one player only).
static func road_luck(run: Run) -> int:
	return 0 if run.coop else run.lvl("lucky")

## A run for two (main.gd): the same road on both phones, whatever their frame rate, screen or place on the
## screen; both wear the host's items and powers. What changes the pace is shared: Sprint (worn by both),
## Esquive, Sablier and RedMonster (started by one, they start for both: remote_act). Left out: what would
## change one player's pace alone (a mount, the hourglass picked up) or bend the road for him alone
## (Relique altérée, Trèfle's gems, the swarms that follow him). `mode`: "endless" or "story" (Vorace then
## laid on the road: see COOP_VIEW).
static func coop_run(upgrades: Dictionary, seed_: int, tier: int, guest: bool, mode: String = "endless", sky_only: bool = false) -> Run:
	var up = upgrades.duplicate()
	up.erase("drunk")
	var keep = [STORY_TRY, STORY_CHAP]               # (for two: the first talks, the same on both phones)
	STORY_TRY = 1
	STORY_CHAP = 0
	var run = new_run(up, mode, seed_)
	STORY_TRY = keep[0]
	STORY_CHAP = keep[1]
	run.coop = true
	run.road_tier = tier
	run.mounts = []
	run.next_mount = INF
	run.next_fm = INF
	run.boss_rng.seed = seed_ * 7919 + 13
	if mode == "story":
		run.coop_xb = run.boss_at * PPM + PX
		run.coop_xf = run.coop_xb + BOSS_SPEED * (BOSS_ENTER + BOSS_FIGHT) + 200
		run.coop_xg = run.coop_xf + COOP_GEMS
		run.coop_zone_at = run.coop_xg + 16 * 48     # past her gems: the first new place
		run.coop_biome_x = run.coop_zone_at + COOP_AHEAD
	else:
		run.coop_biome_x = ZONE_ENDLESS * PPM
	if sky_only:                                     # (0.65) Affrontement « Pièces »: off the forest's cliff early, then
		run.sky_only = true                          # the misty heights for good
		run.sky_ok = true
		run.coop_biome_x = SKY_RACE_AT * PPM
	if guest:
		run.home = PX - 70                       # just behind the host, on both screens: both are seen
	return run

## For two: the partner started an active that changes the pace (Esquive, Sablier, RedMonster). It starts
## here too at the next step, at the very point of the step where his own started, for its full length:
## both cover the same extra ground (a few hundredths apart, the time his word took), and both wait for
## the same recharge. (Already going here, both pressed at once: one only.)
static func remote_act(run: Run, k: String) -> void:
	if not run.dead and k in ["dash", "slow", "monster"]:
		run.act_in.append(k)

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
	if run.no_coins:
		return c                                     # (0.65) a treasure's last race: no coin on the road
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
	run.sky_ok = mode == "story" or int(upgrades.get("flight", 0)) > 0   # (0.53) the heights: Histoire, or the Vol worn
	run.base = SPEED_BASE + (SPEED_SPRINT if run.lvl("sprint") > 0 else 0.0)
	if mode == "story":                              # the guards' talks along the way: the road is empty there
		run.talks = talks_for(STORY_TRY, STORY_CHAP)
		run.chap = STORY_CHAP
		for tk in run.talks:
			if tk["at"] < 0:
				continue
			var x0: float = tk["at"] * PPM + PX
			var dur = 0.0
			for l in tk["lines"]:
				dur += line_time(l)
			var v = minf(STORY_CAP, sqrt(run.base * run.base + 2.0 * STORY_GAIN * x0))   # (the forest's speed there)
			run.talk_zones.append({"at": tk["at"], "x0": x0, "x1": x0 + v * dur * 1.15 + 200, "lines": tk["lines"], "on": false, "wait": false, "done": false})
	run.speed = SPEED_BASE
	run.road_speed = SPEED_BASE
	run.hearts = (STORY_HEARTS if mode == "story" else HEARTS) + run.lvl("heart")   # Vitalité: a heart more per level
	run.max_hearts = run.hearts
	run.dash.full = DASH_CD[mini(run.lvl("dash"), DASH_CD.size() - 1)]
	run.slow.full = SLOW_CD
	run.boots.full = BOOTS_CD[mini(run.lvl("boots"), BOOTS_CD.size() - 1)]
	run.tnt.full = TNT_CD[mini(run.lvl("tnt"), TNT_CD.size() - 1)]
	run.monster.full = MONSTER_CD[mini(run.lvl("monster"), MONSTER_CD.size() - 1)]
	run.rewind_left = 1 if run.lvl("rewind") > 0 else 0
	run.free_knives = SWISS_FREE[mini(run.lvl("swiss"), SWISS_FREE.size() - 1)] if mode != "story" else 0
	run.idol = IDOL_MUL[mini(run.lvl("idol"), IDOL_MUL.size() - 1)] if mode == "endless" else 0.0   # (0.55)
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

## The scenery after `b` on this run (0.53: the heights skipped when they may not come).
static func next_biome(run: Run, b: int) -> int:
	if run.sky_only:
		return SKY                                   # (0.65) Affrontement « Pièces »
	var nb: int = NEXT_BIOME[b]
	if nb == SKY and not run.sky_ok:
		nb = NEXT_BIOME[nb]
	return nb

## Which scenery a spot belongs to: the new one begins at run.biome_x and scrolls in.
static func biome_at(run: Run, x: float) -> int:
	if run.strip_biome >= 0 and x >= run.strip_x0 and x < run.strip_x1:
		return run.strip_biome                   # Relique altérée: the scenery that nearly came
	return run.biome if x >= run.biome_x else run.prev_biome

## The hero starts shut inside the temple: a short rumble, then the doorway blows out and he runs.
static func launch(run: Run) -> void:
	run.sky_ok = run.mode == "story" or int(run.up.get("flight", 0)) > 0 or run.sky_only   # (0.53) the heights: Histoire, or the Vol worn
	run.wait = 1.2
	run.cam = -TEMPLE_PAN                            # (0.52) on the temple first; he is where he was, inside
	run.sx += TEMPLE_PAN
	var lines: Array = []
	if run.mode == "story":                          # Histoire: the guards outside talk first, the camera still
		for tk in run.talks:
			if tk["at"] == -1.0:
				lines.append_array(tk["lines"])
	if lines.is_empty():
		run.events.append("rumble")
		return
	var total = 0.0
	for l in lines:
		total += line_time(l)
	run.intro = true
	run.say_queue = lines.duplicate()
	run.wait = maxf(0.8, total - 0.5)                # the doorway blows out as the last line ends
	run.intro_len = run.wait

# ---------- Histoire: what the guards say (reglages/dialogues.txt) ----------

## [{at: metres along the way (-1: at the temple, before the blast), lines: [String]}]
static var TALKS: Array = []

static var TURN_CUE := false        # a line says « DEMI-TOUR »: the guards turn back there (else at the first line on the way)

## Reads reglages/dialogues.txt: « départ | who | a line » or « 1000 | who | a line » (who may be left out),
## one line said per row, in order; rows with the same place make one talk. A line is kept as « who|text ».
## 0.49: the place may be followed by the attempt (« départ 3 ») and a piece of the relic held (« départ jade 2 »):
## TALKS = [{at, try (0: any), chap (pieces held), lines}], talks_for picks one talk per place.
static func set_talks(text: String) -> void:
	TALKS = []
	TURN_CUE = false
	for raw in text.split("\n"):
		var line: String = raw.split("#")[0].strip_edges()
		var cols = line.split("|")
		if cols.size() < 2:
			continue
		var where = cols[0].strip_edges().to_lower()
		var who = cols[1].strip_edges() if cols.size() >= 3 else ""
		var said = "|".join(cols.slice(2 if cols.size() >= 3 else 1)).strip_edges()
		if said == "":
			continue
		if "DEMI-TOUR" in said.to_upper():
			TURN_CUE = true
		said = who + "|" + said
		var words = where.split(" ", false)
		if words.is_empty():
			continue
		var place: String = words[0]
		var at = -1.0 if place in ["depart", "départ", "temple"] else (float(place) if place.is_valid_float() else NAN)
		if place == "falaise":                       # (0.54) before the cliff, after Vorace
			at = CLIFF_TALK
		elif place == "envol":                       # (0.54) off the cliff, in the air
			at = FLIGHT_TALK
		if is_nan(at):
			continue
		var try_n = 0
		var chap = 0
		for wd in words.slice(1):
			if wd.is_valid_int():
				try_n = int(wd)
			elif wd in RELIC_PIECES:
				chap = RELIC_PIECES.find(wd) + 1
		var last = TALKS[-1] if not TALKS.is_empty() else {}
		if last.is_empty() or last["at"] != at or last["try"] != try_n or last["chap"] != chap:
			TALKS.append({"at": at, "try": try_n, "chap": chap, "lines": []})
		TALKS[-1]["lines"].append(said)

## The talks of one attempt: for each place, the talk of this attempt (counted since the last piece won) in
## this chapter (the pieces held; the nearest chapter below that has some). An attempt with no talk of its own
## takes, in turn, the ones written for the second attempt on (the first is the first meeting).
static func talks_for(try_n: int, chap: int) -> Array:
	var c = chap
	while c > 0 and not TALKS.any(func(tk): return tk["chap"] == c):
		c -= 1
	var mine = TALKS.filter(func(tk): return tk["chap"] == c)
	var places: Array = []
	for tk in mine:
		if not tk["at"] in places:
			places.append(tk["at"])
	var out: Array = []
	for at in places:
		var sets = mine.filter(func(tk): return tk["at"] == at)
		var tries: Array = []
		for tk in sets:
			tries.append(maxi(1, tk["try"]))
		var want = maxi(1, try_n)
		if not want in tries:
			var later = tries.filter(func(k): return k >= 2)
			if later.is_empty():
				later = tries.duplicate()
			later.sort()
			want = later[(want - 2) % later.size()]
		for tk in sets:
			if maxi(1, tk["try"]) == want:
				out.append({"at": at, "lines": tk["lines"]})
				break
	return out

## Histoire's kit: the powers of the relic's pieces held (nothing bought or worn counts there).
static func story_kit(pieces: int) -> Dictionary:
	var up := {}
	for i in clampi(pieces, 0, RELIC_POWERS.size()):
		up[RELIC_POWERS[i]] = 1
	return up

## A piece of the relic won on the way: its power at once (main.gd shows its button and saves the piece).
static func grant(run: Run, id: String) -> void:
	run.up[id] = maxi(1, run.lvl(id))
	if id == "dash":
		run.dash.full = DASH_CD[1]
	elif id == "slow":
		run.slow.full = SLOW_CD

## The speed's ceiling (0.49).
static func speed_cap(run: Run) -> float:
	return STORY_CAP if run.mode == "story" else SPEED_CAP

## 0.49: how hard the layout is at x, 0 to 1 (from x alone: the same road on both phones for two).
static func pressure(run: Run, x: float) -> float:
	var k = clampf((x / PPM - PRESS_FROM) / maxf(1.0, PRESS_FULL - PRESS_FROM), 0, 1)
	return k * (PRESS_STORY if run.mode == "story" else 1.0)

## How long a line stays on screen for two (alone, it stays until a touch): long enough to read it.
static func line_time(text: String) -> float:
	return clampf(1.3 + 0.045 * text.substr(text.find("|") + 1).length(), 2.2, 4.8)

const SAY_RATE := 40.0
const SIGN_AHEAD := 70.0         # metres ahead where a record's board is planted (0.48)
const SIGN_GAP := 25.0           # two boards never closer than this (metres)
const MAX_SIGNS := 12

## Whether the lines wait for a touch: alone, yes; for two (the same road on both phones) or in a test, each
## line has its time.
static func say_by_touch(run: Run) -> bool:
	return not run.coop and not run.god

## Whether the hero is where the guards talk (nothing comes at him there: no swarm, no flyer). Alone, from a
## screen before their place until they are done; for two, the stretch of road kept for them.
static func talking(run: Run) -> bool:
	if run.saying != "" or not run.say_queue.is_empty():
		return true
	var px = run.cam + run.sx
	for z in run.talk_zones:
		if run.coop:
			if px >= z["x0"] - 900 and px < z["x1"]:
				return true
		elif not z["done"] and (z["on"] or px >= z["x0"] + run.held - 900):
			return true
	return false

## Alone: between their place and the end of their talk, the distance does not count.
static func talk_hold(run: Run) -> bool:
	if run.coop:
		return false
	for z in run.talk_zones:
		if z["on"] and not z["done"]:
			return true
	return false

## Alone: the road waits (nothing more is laid) from a screen before their place until they are done.
static func road_held(run: Run) -> bool:
	if run.coop or run.mode != "story":
		return false
	for z in run.talk_zones:
		if not z["done"] and (z["on"] or run.next_x >= z["x0"] + run.held - 900):
			return true
	return false

## Alone: nothing left on the road in front of him (no creature, flyer, swarm, floating thing or animal).
static func road_clear(run: Run) -> bool:
	if run.fm != null or run.fm_due or run.boss != null:
		return false
	var px = run.cam + run.sx
	for o in run.obs:
		if not o.gone and o.x + o.w > px - HERO_HALF - 20:
			return false
	for it in run.bonuses:
		if not it.gone and it.x > px - 40:
			return false
	for it in run.items:
		if it.x > px - 40:
			return false
	return true

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
	if boss_road(run, x):
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
			run.hills[-1].isles = true
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

## A platform's top under x (0.50: a sloped one rises or falls evenly from one end to the other).
static func top_at(pl: Plat, x: float) -> float:
	return pl.y + pl.slope * clampf((x - pl.x) / pl.w, 0.0, 1.0)

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

## (0.53) A rock pinnacle out of the heights' mist, its top `h` over the floor line: a wall from there down.
static func add_pinnacle(run: Run, x: float, h: float) -> Obs:
	var o = add_obs(run, x, floor_at(run, x) - h, PIN_W, h + 260, "pinnacle", false)
	o.biome = SKY
	o.ghost = false                              # (rock: never one of the tipsy creatures)
	return o

static func add_spiky(run: Run, x: float) -> void:
	if "spiky" in run.drop_kinds:                    # (0.58) a Course du jour without hedgehogs: none at all
		return
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
		else:                                        # (0.55) on foot: a low one (jump), a high one (stay down)...
			alt = dart_alt(run, tier)                # never twice the same in a row
		var o = add_dart(run, x + at * v, alt)
		o.aim = tier >= 2
		at += dt_ if tier >= 2 else maxf(dt_, DART_FOOT_GAP)   # (on foot: each one can be jumped, they follow him)
	return at * v + DART_W + 200

## A nest of spiders from x: 4 or 5 of them NEST_STEP apart, all on screen at once. The low one (yellow, still)
## is jumped; around it, where he is in the air, only spiders out of his reach; elsewhere spiders over his head
## (their lowest still above him), and at most one at head height (pass it when it is up), far from the jump.
static func _nest(run: Run, x: float) -> float:
	var v = maxf(lay_speed(run, x), 1.0)
	var n = 5 if W.randf() < 0.4 else 4
	var low_k = W.randi() % 2
	var xl = x + low_k * NEST_STEP
	var in_air = v * 0.45 + HOVER_W                  # around the low one: he is in the air there
	var head_left = x / PPM >= FROM_MID
	for k in n:
		var at = x + k * NEST_STEP
		var h: float
		if k == low_k:
			h = LOW
		elif absf(at - xl) < in_air:
			h = SKY_HOVERS[2]                        # over his jump: out of reach
		elif head_left and absf(at - xl) >= spider_gap(run, x) and W.randf() < 0.35:
			h = HEAD
			head_left = false
		else:
			h = wpick(SKY_HOVERS)
		add_hover(run, at, h)
	return (n - 1) * NEST_STEP + HOVER_W

## (0.67) Whether x is in the dungeon laid in two parts.
static func split_at(run: Run, x: float) -> bool:
	return SPLIT_ON and biome_at(run, x) == 3

## (0.67) One cycle of the dungeon in two, from x: the deck all along (a shaft in it over the pipe's way out), the
## pipe of the floor that throws up through the shaft, then the dangers: below, those of the floor (a hedgehog or
## a low bat to jump, a bat at head height to stay under); above, on the deck, a low bat to jump or a bat at
## head height. One part's danger never stands over the other's: they come one after the other.
static func lay_split(run: Run, x: float) -> void:
	var L = SPLIT_CYCLE * PPM
	var v = lay_speed(run, x)
	var deck_y = floor_at(run, x) - DECK_H
	var pipe_x = x + 260.0
	var pipe_w = roundf(wrnd(620, 760))
	var out_x = pipe_x + pipe_w                     # where the pipe throws him up
	var hole0 = out_x - 60.0
	var hole1 = out_x + maxf(220.0, v * 0.45)       # the shaft: long enough to land beyond it, short enough to jump
	_deck(run, x, hole0, deck_y)
	_deck(run, hole1, x + L, deck_y)
	var z = tight(run, "gallery", pipe_x, pipe_w, GROUND + GALLERY - 22)
	z.launch = true
	z.launch_v = SPLIT_LAUNCH
	z.open = true
	coin_line(run, pipe_x - 160, floor_at(run, pipe_x) - 40, 3)
	coin_arc(run, hole1 + 60, DECK_H + 60, 5, 260)
	# the dangers, from after the shaft to the end of the cycle; below and above in turn
	var gap = maxf(spider_gap(run, x) * 1.6, v * 1.1)
	var at = hole1 + maxf(320.0, v * 0.7)
	var lower = W.randf() < 0.5
	while at < x + L - 260:
		var k = W.randf()
		var o: Obs = null
		if lower:
			if k < 0.4:
				add_spiky(run, at)
			else:
				o = add_hover(run, at, LOW if k < 0.7 else HEAD)
				if o != null:                        # (a mobile one never goes up into the deck)
					o.amp = minf(o.amp, maxf(0.0, DECK_H - SLAB_T - 20 - ((LOW if k < 0.7 else HEAD) + HOVER_H / 2)))
			coin_line(run, at + gap * 0.45, floor_at(run, at) - 40, 2)
		else:
			var h = DECK_H + (LOW if k < 0.55 else HEAD)
			o = add_hover(run, at, h)
			if o != null:                            # (nor down through it)
				o.amp = minf(o.amp, maxf(0.0, h - HOVER_H / 2 - DECK_H - 20))
			coin_line(run, at + gap * 0.45, deck_y - 40, 2)
		lower = not lower
		at += gap * wrnd(0.95, 1.25)
	run.next_x = x + L

## (0.67) The deck of the dungeon in two, from x0 to x1: slabs end to end (their pillars down to the floor).
static func _deck(run: Run, x0: float, x1: float, y: float) -> void:
	var at = x0
	while at < x1 - 40:
		var w = minf(1100.0, x1 - at)
		var pl = Plat.new()
		pl.x = at
		pl.y = y
		pl.w = w
		pl.kind = "slab"
		pl.t = SLAB_T
		run.plats.append(pl)
		at += w

## A rare floating thing: an hourglass (a brake) or, once a run, an urn (0.55: no feather), zigzagging up and
## down within reach of a jump. For two: nothing (the hourglass would change one player's speed; the bubble is
## their second chance).
static func add_bonus(run: Run, x: float) -> void:
	var roll = W.randf()
	var ph = wrnd(0, 2)
	if run.coop and not run.race:                    # (0.65: a race of the Affrontement has them: each his own)
		return
	var it = Item.new()
	it.x = x
	if roll < 0.0:
		it.kind = "brake"
	elif run.mode != "story" and x / PPM >= URN_EVERY * (run.urn_n + 1):
		it.kind = "urn"                              # (0.65) Run illimitée and Affrontement only: one every URN_EVERY m
		run.urn_n += 1
		run.urn_laid = true
	else:
		it.kind = "brake"                            # (0.55: where a feather was; the road's dice unchanged)
	it.ph = ph
	it.y = floor_at(run, x) - BONUS_LOW
	run.bonuses.append(it)

## A flyer: it waits beyond the right edge until the screen reaches it, shows a "!" at its height, then crosses.
## Two spiders of a row: this far apart (SPIDER_GAP_*).
static func spider_gap(run: Run, x: float) -> float:
	return maxf(SPIDER_GAP_MIN, lay_speed(run, x) * SPIDER_GAP_TIME)

static func add_dart(run: Run, x: float, alt: float, own: bool = false) -> Obs:
	var o = add_obs(run, x, floor_at(run, x) - alt - DART_H / 2, DART_W, DART_H, "dart", false)
	o.biome = biome_at(run, x)
	o.state = "wait"
	o.t = 0
	o.ph = rnd(0, 6) if own else wrnd(0, 6)      # (own: sent at him, at a moment of his: not the road's dice)
	o.own = own
	o.alt = alt                                  # (0.55: on foot, the height it crosses at)
	return o

## 0.55, on foot: a flyer crosses where he will be some way on (DART_FREEZE + its crossing), whatever is there.
## Laid low (to be jumped) or high (to stay under), it must not meet what asks the other: a high one where a
## jump is needed (something standing in his way, a hole), a low one where a jump is barred (something at the
## height of the jump). As it stops, it takes the other height if that one fits, or goes if none does.
static func _dart_lane(run: Run, o: Obs, px: float) -> void:
	var v = maxf(run.speed, 1.0)
	var cross = (run.cam + run.view_w + 60 - px) / (DART_SPEED + v)
	var meet = px + v * (DART_FREEZE + cross)
	o.meet = meet
	var asks = _asks(run, run.obs, run.pits, meet - DART_FAIR, meet + DART_FAIR)
	var jump_needed: bool = asks[0]
	var jump_barred: bool = asks[1]
	var low = o.alt < DART_LOW_MAX
	if low and jump_barred:
		if jump_needed:
			o.gone = true                                # (neither height leaves a way: it does not come)
		else:
			o.alt = DART_ALTS[0][1]
	elif not low and o.alt < DART_HIGH_MAX and jump_needed:
		if jump_barred:
			o.gone = true
		else:
			o.alt = DART_ALTS[0][0]

## 0.55: what the road between x0 and x1 asks of him on foot: [a jump is needed (something standing in his
## way, a hole), a jump is barred (something at the height of the jump)].
static func _asks(run: Run, obs: Array, pits: Array, x0: float, x1: float) -> Array:
	var jump_needed = false
	var jump_barred = false
	for q in obs:
		if q.gone or q.kind == "dart" or q.x + q.w < x0 or q.x > x1:
			continue
		var f = floor_at(run, q.x + q.w / 2)
		var top = f - (q.y - q.amp)                      # its highest point over the floor, and its lowest
		var bottom = f - (q.y + q.h + q.amp)
		if bottom < HERO_H - 6:
			jump_needed = true
		if top > HERO_H - 6 and bottom < JUMP_TOP:
			jump_barred = true
	for hp in pits:
		if hp.x1 > x0 and hp.x0 < x1:
			jump_needed = true
	return [jump_needed, jump_barred]

## 0.55: road laid after a flyer on foot stopped (its height known): if what is laid where it meets him asks
## the other way (a jump under a high one, no jump over a low one), it does not come.
static func _darts_vs_new(run: Run, obs0: int, pits0: int) -> void:
	if obs0 >= run.obs.size() and pits0 >= run.pits.size():
		return
	var fresh = run.obs.slice(obs0)
	var holes = run.pits.slice(pits0)
	for o in run.obs:
		if o.kind != "dart" or o.gone or o.aim or o.meet <= 0:
			continue
		var asks = _asks(run, fresh, holes, o.meet - DART_FAIR, o.meet + DART_FAIR)
		if (o.alt < DART_LOW_MAX and asks[1]) or (o.alt >= DART_LOW_MAX and o.alt < DART_HIGH_MAX and asks[0]):
			o.gone = true

## 0.55: a flyer's height on foot (not aimed at him): one of the tier's, never the last flyer's again.
static func dart_alt(run: Run, tier: int) -> float:
	var alts: Array = DART_ALTS[mini(tier, 1)].filter(func(h): return absf(h - run.last_alt) > 1)
	var a: float = wpick(alts)
	run.last_alt = a
	return a

static func coin_line(run: Run, x: float, y: float, n: int) -> void:
	for i in n:
		coin(run, x + i * 44, y)

## (0.54) The heights: an arc of coins from `base` over the floor line, rising `peak` in its middle.
static func sky_arc(run: Run, x: float, base: float, peak: float, n: int, span: float) -> void:
	for i in n:
		var k = float(i) / (n - 1)
		coin(run, x + span * k, floor_at(run, x + span * k) - base - peak * 4 * k * (1 - k))

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
static func tight(run: Run, kind: String, x: float, w: float, y: float) -> Zone:
	var z = Zone.new()
	z.x = x
	z.w = w
	z.kind = kind
	z.open = biome_at(run, x) == 3                   # (0.59) the dungeon's pipes: for anyone
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
	return z

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

## 0.55, the Affrontement: fallen, he watches another runner. The camera follows `x` (where that one is,
## world), the road goes on being laid ahead of it (the same seed: the same road as theirs), the hanging
## dangers move; nothing touches anybody.
static func spectate(run: Run, dt: float, x: float) -> void:
	W = run.rng
	run.t += dt
	var want = x - run.home
	run.cam = want if absf(want - run.cam) > 1500 else lerpf(run.cam, want, minf(1.0, dt * 5.0))
	for o in run.obs:
		if o.kind == "hover" and o.amp > 0:
			o.y = o.y0 - sin(run.t * TAU / SPIDER_PERIOD + o.ph) * o.amp
	run.obs = run.obs.filter(func(o): return not o.gone and o.x + o.w > run.cam - 120)
	run.plats = run.plats.filter(func(pl): return pl.x + pl.w > run.cam - 120)
	run.coins = run.coins.filter(func(c): return c.x > run.cam - 200)
	while run.terrain.size() > 2 and run.terrain[1].x < run.cam - 1500:   # (0.65: was 300: the scenery behind him lost its floor and vanished)
		run.terrain.pop_front()
	var edge = run.cam + run.view_w + 200
	var n = 0
	while run.next_x < edge and n < 80:
		spawn_pattern(run)
		n += 1

## (0.54) The forest ends at a cliff over the heights' mist: the floor climbs to it, runs flat to its edge
## and drops; the heights begin at its edge. A few coins along its top, nothing else.
static func lay_cliff(run: Run, x: float) -> void:
	run.cliff_due = false
	var edge = x + CLIFF_RISE + CLIFF_TOP
	relief(run, x, [[0, 0], [CLIFF_RISE, CLIFF_H], [CLIFF_RISE + CLIFF_TOP + CLIFF_LIP, CLIFF_H], [CLIFF_RISE + CLIFF_TOP + CLIFF_LIP + 1, 0]])
	coin_line(run, x + CLIFF_RISE + 60, GROUND - CLIFF_H - 40, floori((CLIFF_TOP - 120) / 44))
	run.prev_biome = run.biome
	run.biome = SKY
	run.biome_x = edge
	run.cliff_x = edge
	run.next_x = edge + CLIFF_CALM
	run.calm_until = maxf(run.calm_until, run.next_x + 700)   # (coins only, his first moments in the air)
	run.block_end = edge

## (0.54) The heights come next: their cliff will be laid at the next pattern. Histoire, alone: the guards are
## after him again first (they come back running), and say so (« falaise »).
static func _cliff_begin(run: Run) -> void:
	run.cliff_due = true
	if run.mode != "story" or run.coop:
		return
	run.guards_off = -1.0
	if run.guards.is_empty():
		for i in 2:
			run.guards.append({"x": DOOR_X, "v": 0.0, "on": false})
	for i in run.guards.size():
		var g = run.guards[i]
		g.on = true
		g.glide = false
		g.gone = false
		g.x = run.cam - 260 - 140 * i
		g.v = run.speed
	var lines = _talk_lines(run, CLIFF_TALK)
	if not lines.is_empty():
		var px = run.cam + run.sx
		run.talk_zones.append({"at": run.dist + 0.5, "x0": px - run.held + 20, "x1": px + 4000, "lines": lines, "on": false, "wait": false, "done": false})

## (0.54) The lines of this attempt's talk at a place (CLIFF_TALK, FLIGHT_TALK), none if there is none.
static func _talk_lines(run: Run, at: float) -> Array:
	for tk in run.talks:
		if tk["at"] == at:
			return tk["lines"]
	return []

## (0.54) Off the cliff, the Vol has taken him: Histoire, alone, the guards jump after him on leaf gliders and
## shout (« envol »); they follow him a while, then fall behind.
static func _cliff_flight(run: Run) -> void:
	if run.mode != "story" or run.coop or run.guards.is_empty():
		return
	run.escort = GLIDE_ESCORT
	for i in run.guards.size():
		var g = run.guards[i]
		g.on = true
		g.glide = true
		g.gone = false
		g.x = minf(g.x, run.cliff_x - 30 - 60 * i)
		g.y = GROUND - CLIFF_H - 50
		g.v = 0.0
	var lines = _talk_lines(run, FLIGHT_TALK)
	if not lines.is_empty():
		var px = run.cam + run.sx
		run.talk_zones.append({"at": run.dist, "x0": px - run.held, "x1": px + 4000, "lines": lines, "on": false, "wait": false, "done": false})

## (0.58) The road's kinds of danger a Course du jour may keep or leave out (Daily.FAMILIES).
const DAILY_DANGERS := ["spiky", "double", "hover", "spiders", "nest", "lowhover", "skyhover", "curtain", "fly", "wave", "log"]

static func spawn_pattern(run: Run) -> void:
	var laid = run.coins.size()
	if run.cliff_due and not run.coop and not road_held(run):
		lay_cliff(run, run.next_x)                   # (0.54) the forest ends: its cliff, then the heights
		return
	if run.mount != null and not run.coop and road_held(run):
		return
	if run.mount != null and run.fm == null and not run.fm_due and run.boss == null and (biome_at(run, run.next_x) != SKY or MOUNTS[run.mount.kind].get("fly", false)):
		spawn_ride(run)
		scatter(run, laid)
		return
	var x = run.next_x
	if run.coop:
		for z in run.talk_zones:                     # Histoire for two: nothing on the road while the guards talk
			if x >= z["x0"] - 900 and x < z["x1"]:   # (from a screen before, so that nothing is left in sight)
				run.next_x = z["x1"]
				return
	elif road_held(run):                             # alone: nothing more until they are done
		return
	if run.coop and run.mode == "story" and x >= run.coop_xf + COOP_VIEW and not run.coop_gems:
		run.coop_gems = true                         # for two: Vorace's blue gems, at a place on the road
		var g0 = run.coop_xg
		for k in 16:
			coin(run, g0 + k * 48, floor_at(run, g0 + k * 48) - 40, "b")
		run.calm_until = g0 + 16 * 48 + DEATH_CALM
		run.easy_until = run.calm_until + DEATH_EASY
		run.next_x = maxf(x, run.coop_xf + COOP_VIEW + COOP_GAP)
		return
	if x >= run.coop_biome_x:                        # for two: the next scenery begins at the first pattern past
		var cliff = run.biome == 0 and next_biome(run, run.biome) == SKY   # (0.54: the heights' cliff there)
		if not cliff:                                # the mark, the same on both phones (alone: update(), when
			run.prev_biome = run.biome               # he reaches the mark, just off screen)
			run.biome = next_biome(run, run.biome)
			run.biome_x = x
		if run.mode == "story":
			run.coop_biome_x = coop_next_mark(run.coop_biome_x - COOP_AHEAD) + COOP_AHEAD
		else:
			run.coop_biome_x = (floorf(x / (ZONE_ENDLESS * PPM)) + 1) * ZONE_ENDLESS * PPM
		if cliff:
			lay_cliff(run, x)
			return
	if split_at(run, x) and (run.coop or (run.mount == null and run.boss == null and x >= run.calm_until)):   # (for two: the road alone decides)
		lay_split(run, x)                            # (0.67) the dungeon in two
		scatter(run, laid)
		return
	var G = GROUND
	var tier = tier_of(run)
	var sky = biome_at(run, x) == SKY                # (0.53) the heights: laid for the Vol, only what flies
	if sky:
		tier = 2
	var riding = run.mount != null or run.items.size() > 0
	var press = pressure(run, x)
	var more = 1.0 + PRESS_CHAINS * press
	# The first metres are a warm-up: one obstacle at a time, nothing in the air.
	var opts: Array
	if x < 70 * PPM:
		opts = ["spiky", "spiky", "coins", "plat", "ledge", "hollow"]
	else:
		opts = ["spiky", "spiky", "double", "perch", "hop", "fly", "coins", "plat", "plat", "log", "gallery", "stairs", "ledge", "ledge", "hollow",
			"hills", "hills", "hills", "padchain", "padchain", "padchain", "padzig", "padzig"]
	if x / PPM >= FROM_LOW:                          # many spiders: dangers at every height
		opts.append_array(["hover", "hover", "hover", "hover", "hover"])
		for i in roundi(CHAIN_SPIDERS * more):
			opts.append("spiders")
	if x / PPM >= FROM_NESTS:                        # 0.49: the nests later (900 m)
		for i in roundi(CHAIN_NESTS * more):
			opts.append("nest")
	if x / PPM >= FROM_DARTS:                        # flyers come in waves too (0.49: from 400 m)
		for i in roundi(CHAIN_WAVES * more):
			opts.append("wave")
	if tier < 2 and x >= 70 * PPM:                   # on foot: fewer flyers, more hedgehogs and low spiders
		opts.erase("fly")
		opts.append_array(["spiky", "lowhover", "lowhover"] if x / PPM >= FROM_LOW else ["spiky"])
	if tier >= 2 and x >= 70 * PPM:                  # the Vol: dangers at every height
		opts.append_array(["fly", "wave", "wave", "skyhover", "skyhover", "skyhover", "curtain", "curtain", "curtain", "curtain"])
	if x / PPM < FROM_DARTS:                         # 0.49: no flyer before 400 m
		opts = opts.filter(func(k): return k != "fly" and k != "wave")
	var fit: Array = shapes.filter(func(s): return s.top <= REACH[tier])
	if fit.size() > 0 and x >= 70 * PPM:
		opts.append_array(["shape", "shape"])
	if tier < 2 and shapes.size() > 0 and x >= 70 * PPM:
		opts.append("skyshape")
	if riding:
		opts = opts.filter(func(k): return k != "cave")
	if biome_at(run, x) == 3 and x >= 70 * PPM:      # (0.59) the dungeon: pipes for anyone, of three kinds
		opts.append_array(["pipeup", "pipedrop", "log"])
	if run.mode == "story" and biome_at(run, x) == 0:   # (0.59) Histoire, level 1: no pipes in the forest
		opts = opts.filter(func(k): return k != "log" and k != "gallery")
	if x < run.calm_until:
		opts = ["coins"]
	elif x < run.easy_until:
		opts = ["spiky", "coins", "coins", "plat", "ledge", "hollow"]
	if run.coop and x >= run.coop_xb - COOP_CALM and x < run.coop_xb + COOP_VIEW:
		opts = ["coins"]                             # for two: nothing but coins as Vorace comes
	if run.fm != null or run.fm_due:
		opts = ["coins"]
	elif boss_road(run, x):
		opts = ["plat", "plat", "steps", "padchain", "coins"]
	elif not riding and x > 70 * PPM and x / PPM >= run.next_mount and run.mounts.size() > 0:
		opts = ["mount"]
	if sky:                                          # (0.53) the heights: in the air only, pinnacles out of the mist
		# (0.54) laid in figures that read at a glance, the coins showing the way through: rows of pinnacles
		# rising and falling, a gap between a pinnacle and a glider, gliders in a slant, a moving curtain, a
		# fonceur now and then; never a danger dropped anywhere (the first SKY_EASY metres: pinnacles only)
		var into = (x - run.biome_x) / PPM
		if x < run.calm_until or run.fm != null or run.fm_due:
			opts = ["skycoins"]
		elif into < SKY_EASY:
			opts = ["pinrow", "pinrow", "pinrow", "pinthread", "skycoins"]
		else:
			opts = ["pinrow", "pinrow", "pinrow", "pinthread", "pinthread", "glidestair", "glidestair", "curtain", "curtain", "fly", "wave", "skycoins"]
		if run.sky_n >= SKY_SERIES and opts.size() > 1:   # (0.59) a series laid: a breath of coins
			opts = ["skybreath"]
		if run.eagle != null:                        # (0.60) the eagle's fight: coins only
			opts = ["skycoins"]
	if not run.drop_kinds.is_empty() and not sky:     # (0.58) a Course du jour keeping only some dangers
		var kept = opts.filter(func(k): return not k in run.drop_kinds)
		var dangers = kept.filter(func(k): return k in DAILY_DANGERS)   # (the dangers kept come more often:
		for i in 2:                                                    # the road is not left empty)
			kept.append_array(dangers)
		opts = kept if not kept.is_empty() else ["coins"]
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
			var n = 2 + W.randi() % (3 if press >= 0.5 else 2)   # (0.49: up to four once the layout presses)
			for i in n:
				var h = LOW if i % 2 == 0 else (wpick([HEAD] + SKY_HOVERS) if tier >= 2 else HEAD)
				add_hover(run, x + i * spider_gap(run, x), h)
			extent = (n - 1) * spider_gap(run, x) + HOVER_W
		"nest":                                    # a nest: many spiders at once (as the dragonfly sees them)
			extent = _nest(run, x)
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
			add_dart(run, x, wpick(DART_ALTS[tier]) if tier >= 2 else dart_alt(run, tier)).aim = tier >= 2
			extent = 120
		"skybreath":                                 # (0.59) the heights: after a series, a breath (coins, room)
			run.sky_n = 0
			for i in 12:
				coin(run, x + i * 44, floor_at(run, x) - 250 - 60 * sin(i * 0.5))
			extent = 12 * 44 + SKY_BREATH
		"skycoins":                                  # (0.53) the heights: coins in the air (0.54: a gentle wave)
			var h0: float = wpick([170.0, 250.0, 330.0])
			for i in 9:
				coin(run, x + i * 44, floor_at(run, x) - h0 - 40 * sin(i * 0.7))
			extent = 9 * 44
		"pinrow":                                    # (0.54) a row of pinnacles, each a step higher or lower than the last
			var n = 3 + (1 if press >= 0.5 else 0) + W.randi() % 2
			var step = maxf(PIN_GAP, lay_speed(run, x) * PIN_TIME)
			var i = W.randi() % PIN_HS.size()
			for k in n:
				var h: float = PIN_HS[i]
				var at = x + 80 + k * step
				add_pinnacle(run, at, h)
				sky_arc(run, at - 50, h + 60, 60, 5, PIN_W + 100)   # over its top
				if k == 0:                             # (0.59) over the first one's top
					run.cues.append({"x": at, "y": floor_at(run, at) - h - 70})
				var dir = (1 if W.randf() < 0.5 else -1) if i > 0 and i < PIN_HS.size() - 1 else (1 if i == 0 else -1)
				i += dir                               # (at the bottom or the top, it turns back: never twice the same)
			extent = (n - 1) * step + PIN_W + 240
			run.sky_n += 1
		"pinthread":                                 # (0.54) a pinnacle, a glider over it: through the gap between
			var h: float = PIN_HS[W.randi() % 2]
			add_pinnacle(run, x + 80, h)
			var gl = add_hover(run, x + 80 + PIN_W / 2 - HOVER_W / 2, h + THREAD_GAP + HOVER_H / 2)
			if gl != null:
				gl.amp = THREAD_AMP
			coin_line(run, x, floor_at(run, x) - h - THREAD_GAP / 2 + 20, floori((PIN_W + 160) / 44))
			extent = PIN_W + 300
			run.sky_n += 1
			run.cues.append({"x": x + 80, "y": floor_at(run, x) - h - THREAD_GAP / 2})   # (0.59) through the gap
		"glidestair":                                # (0.54) three gliders in a slant: under the rising ones, over
			var rising = W.randf() < 0.5               # the falling ones (the coins show which)
			var step = maxf(GLIDE_STEP, lay_speed(run, x) * 0.42)
			for k in 3:
				var h: float = STAIR_HS[k if rising else 2 - k]
				var gl = add_hover(run, x + 120 + k * step, h)
				if gl != null:
					gl.amp = THREAD_AMP
				var cy = h - 130 if rising else h + 130
				coin_line(run, x + 120 + k * step - 30, floor_at(run, x) - cy, 3)
				if k == 0:                             # (0.59) under the rising ones, over the falling ones
					run.cues.append({"x": x + 120, "y": floor_at(run, x) - cy})
			extent = 2 * step + HOVER_W + 240
			run.sky_n += 1
		"wave":                                      # a wave of flyers, more and closer together the faster he goes
			extent = _wave(run, x, tier)
		"swarm":                                     # two flyers, one after the other, at different heights
			var alts: Array = DART_ALTS[2].duplicate()
			wshuffle(alts)
			add_dart(run, x, alts[0]).aim = true
			var gap2 = maxf(520.0, lay_speed(run, x) * DART_FOOT_GAP)
			add_dart(run, x + gap2, alts[1])
			extent = gap2
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
		"pipeup":                                    # (0.59) the dungeon: in by the floor, out by the floor thrown up high
			var w = roundf(wrnd(700, 1000))
			tight(run, "gallery", x, w, G + GALLERY - 22).launch = true
			coin_arc(run, x + w + 60, PIPE_PEAK - 40, 7, 420)
			extent = w + 520
		"pipedrop":                                  # (0.59) the dungeon: a mouth half way up or high, out by the floor
			var hs: Array = [[150.0], [150.0, 250.0], [150.0, 250.0, 330.0]][tier]
			var h: float = wpick(hs)
			var w = roundf(wrnd(650, 900))
			var z = tight(run, "chute", x, w, G - 24)
			z.mouth = h
			coin_arc(run, x - 260, h + 10, 5, 240)
			extent = w + 120
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
			run.hills[-1].isles = true
			var n: int = wpick([2, 3, 3]) if tier >= 1 else wpick([2, 2, 3])
			var rise = 125.0 if tier >= 1 else 105.0     # a plain jump reaches 120
			var ix = x + wrnd(20, 80)
			var last: Plat = null
			for k in n:
				var size: int = wpick([0, 1, 1, 2])
				var lvl_k = 1 if (k == n - 1 and n > 2) else k
				var iy = G - 130 - lvl_k * rise - (k % 2) * 20
				var pl: Plat
				if PLAT_KIND[biome_at(run, ix)] == "isle":
					pl = add_isle(run, ix, iy, size)
					if biome_at(run, ix) == 0 and W.randf() >= ISLE_FLAT:   # 0.50: the forest's may slope, fixed
						var tilts: Array = ISLE_UP.map(func(v): return -float(v))   # (up; the last one down too)
						if k == n - 1:
							tilts.append_array(ISLE_DOWN)
						pl.slope = wpick(tilts)
				else:
					pl = add_platform(run, ix, iy)
				for c in maxi(2, floori((pl.w - 60) / 44)):   # its coins follow its top
					coin(run, ix + 30 + c * 44, top_at(pl, ix + 30 + c * 44) - 40)
				ix += pl.w + wrnd(70, 150)
				last = pl
			if W.randf() < 0.3 + 0.2 * road_luck(run):    # (0.50: 110 above the last one's top under it, slope or not)
				var gy = G - 130 - (n - 1) * rise - 110
				if last != null and ix - 120 > last.x and ix - 120 < last.x + last.w:
					gy = minf(gy, top_at(last, ix - 120) - 110)
				coin(run, ix - 120, gy, gem(run))
			if x > 70 * PPM and W.randf() < 0.65:     # below, a hedgehog: up there is the safe way
				add_spiky(run, x + wrnd(0.3, 0.6) * (ix - x))
			extent = maxf(w, ix - x)
		"padchain":                                  # pads one after the other, up and down, bobbing out of step
			var hs: Array = wpick([[135, 220, 135, 250], [135, 200, 265, 200], [180, 135, 220, 135], [135, 235, 135]])
			for k in hs.size():
				var px = x + k * 320
				add_platform(run, px, G - hs[k], PAD_BOB + k * 3)
				coin_line(run, px + 60, G - hs[k] - 40, 3)
			if x > 70 * PPM and not boss_road(run, x) and W.randf() < 0.5:
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
	# 0.49: with the pressure, shorter gaps (never shorter than what a landing needs, `need`).
	var need = lay_speed(run, x) * GAP_TIME * (1 - PRESS_NEED * press) + GAP_MARGIN
	var gap = maxf(GAP_DIST * (1 - PRESS_GAP * press), need) * wrnd(0.85, 1.3 - 0.3 * press) * (1.3 if kind == "coins" else 1.0)
	if kind == "spiders":
		gap = maxf(gap, spider_gap(run, x))           # as much room after the row as within it
	var clear = run.fm == null and not run.fm_due and not boss_road(run, x) and kind != "wave"
	if clear and x / PPM >= run.next_bonus and x / PPM > 300:   # a life or a brake, floating in the gap
		add_bonus(run, x + extent + gap * 0.5)
		run.next_bonus = x / PPM + wrnd(BONUS_EVERY[0], BONUS_EVERY[1])
		clear = false
	# A wide gap gets something that asks no jump: a danger at head height, or a fonceur.
	if sky:
		clear = false                                # (0.54) the heights: nothing dropped between their figures
	if gap > GAP_FILL and x / PPM >= FROM_MID and clear and W.randf() < 0.5:
		add_hover(run, x + extent + gap * 0.5, HEAD)
	elif gap > GAP_FILL and x / PPM >= FROM_DARTS and clear and W.randf() < (0.35 if tier >= 2 else 0.15) + PRESS_FILL * press:
		add_dart(run, x + extent + gap * 0.5, 170.0 if tier >= 2 else dart_alt(run, tier)).aim = tier >= 2
	if x / PPM > 70 and not boss_road(run, x) and W.randf() < DECOR_RATE and not sky:
		add_decor(run, x + extent + gap * wrnd(0.3, 0.6))     # something to smash
	if x / PPM > 40 and kind != "hills" and W.randf() < 0.22 and not sky:
		add_hill(run, x + extent + gap * wrnd(-0.2, 0.3), wrnd(500, 1400), wrnd(100, 480))   # scenery only
	if (kind == "coins" or W.randf() < 0.55) and not sky:
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
	if run.lvl("flight") == 0 or run.mount != null or run.boss != null or run.eagle != null or run.fm != null or run.fm_due or run.leap != null or run.dead or run.out < 2 or talking(run):
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

## Vorace. For two, she rolls her own dice (she aims at each hero apart, so each phone throws its own
## attacks) and comes and goes at places on the road (coop_xb, coop_xf), which is laid for her already.
static func boss(run: Run, d: float) -> void:
	if not run.coop:
		_boss_step(run, d)
		return
	var keep = W
	W = run.boss_rng
	_boss_step(run, d)
	W = keep

static func _boss_step(run: Run, d: float) -> void:
	var p = run.p
	if run.boss == null:
		if run.boss_done or run.biome != 0 or run.prev_biome != 0:
			return                                   # only ever in the forest
		if (run.cam + run.sx < run.coop_xb) if run.coop else (run.dist < run.boss_at):
			return
		var nb = Boss.new()
		nb.sx = run.view_w + 60
		run.boss = nb
		run.items.clear()                            # no mount waiting during the fight
		for o in run.obs:                            # nor any other danger: Vorace alone (for two the road
			if run.coop:                             # left her room already)
				break
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
		if b.t > BOSS_ENTER:
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
		var over = (run.cam + run.sx >= run.coop_xf) if run.coop else (b.t > BOSS_FIGHT)
		if over and b.wind <= 0:                       # a tree comes down on it
			b.phase = "fall"
			b.t = 0
			b.wx = run.cam + b.sx
			b.crushed = false
			if not run.coop:                         # nothing else on the road while she goes down (for two: laid so)
				run.next_x = maxf(run.next_x, run.cam + run.view_w + 2600)
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
		run.events.append("bossdown")
		run.urns += 1                                # (0.55) an urn for her (the urns are won, never bought)
		run.events.append("urn")
		if run.mode == "story" and run.chap < 1:     # 0.49: her piece of the relic (0.53: the crown, the Vol), at once
			run.won = 0
			if run.coop or not run.sky_ok:           # (0.54) alone, its Vol comes as he falls off the cliff
				grant(run, RELIC_POWERS[0])
			run.events.append("relic")
		if run.coop:
			return                                   # (for two the road laid her gems and what follows)
		var g0 = run.cam + run.view_w + 200
		for k in 16:
			coin(run, g0 + k * 48, floor_at(run, g0 + k * 48) - 40, "b")
		run.calm_until = g0 + 16 * 48 + DEATH_CALM
		run.easy_until = run.calm_until + DEATH_EASY
		run.next_x = maxf(run.next_x, g0)
		# the world moves on after the gems (with the Relique altérée, another scenery only goes by)
		run.next_biome_at = run.dist + (g0 + 16 * 48 - run.cam - run.sx) / PPM
		run.by_mark = false

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
	for i in CRATE_COINS:                            # its coins burst out ahead of him: they fall, bounce and wait
		var c = coin(run, cx + rnd(-14, 14), cy - rnd(0, 30))
		c.toss = true
		c.blast = true
		c.tvx = maxf(run.speed, 320.0) * rnd(0.9, 2.2)
		c.tvy = rnd(-900, -240)
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
		if not run.coop:                             # (for two no laser drone: it would bend his road)
			run.next_fm = run.dist + rnd(170, 300)
		run.events.append("rewind")
		return
	if run.coop and not run.race:                    # two players: he floats after the other, who can bring him back
		to_bubble(run)
		return
	_fatal(run)
	if run.mode == "story" and not run.coop and biome_at(run, run.cam + run.sx) == SKY:   # (0.59) level 2: no way back,
		_skyfall_start(run)                                                                    # the long fall
		return
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
	var p2 = run.p                                   # thrown ahead: he lands head first (see update), then the end
	var lp2 = Leap.new()
	lp2.n = 0
	lp2.v = maxf(360, run.speed) * PLANT_KICK
	run.leap = lp2
	p2.vy = -PLANT_UP
	p2.ground = false
	p2.plat = null
	p2.rotor = false
	p2.flew = false
	burst(run, run.cam + run.sx, p2.y - 40, Color("#ff4d6d"), 14, 320)
	run.events.append_array(["hurt", "fling"])

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
	var mx = px                                      # after the partner where he is drawn (smoothed)
	if run.mate_view != null and not run.mate_view.is_empty():
		mx = float(run.mate_view.get("x", px))
	elif run.mate != null:
		mx = float(run.mate.get("x", px))
	var target = _bubble_target(run, mx, run.t)
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

## Histoire: whether the guards are at his heels (out of the doorway, not turned back yet, no boss).
static func guards_after(run: Run) -> bool:
	if run.coop or run.mode != "story" or run.blast_t < 0 or run.guards_off >= 0 or run.boss != null or run.dead or run.sky:
		return false
	for g in run.guards:
		if g.on and not g.get("gone", false) and not g.get("glide", false):
			return true
	return false

## Histoire: the guards after him. Out of the doorway one after the other, at his pace (hv: how fast he goes,
## world) while the camera has not caught him up, then in fast to their place behind him; turned back, they
## run off to the left. Caught: _capture moves them.
static func _guards(run: Run, d: float, hv: float) -> void:
	if run.caught != null:
		return
	if run.mode != "story" or run.blast_t < 0:       # (0.47: after an escape, they run off, whatever the mode)
		for g in run.guards:
			g.v = move_toward(g.v, -GUARD_FLEE, 1600 * d)
			g.x += g.v * d
		return
	if run.guards.is_empty():
		for i in 2:
			run.guards.append({"x": DOOR_X, "v": 0.0, "on": false})
	var px = run.cam + run.sx
	var since = run.t - run.blast_t
	if run.escort > 0 and run.saying == "" and run.say_queue.is_empty() and not talk_hold(run):
		run.escort -= d                              # (0.54) the gliders' time counts once they are done shouting
	for i in run.guards.size():
		var g = run.guards[i]
		if g.get("gone", false):
			continue
		if g.get("glide", false):                    # (0.54) on their leaf gliders, behind him in the air
			if not run.glide_go and (talk_hold(run) or run.saying != "" or not run.say_queue.is_empty()):
				continue                             # (on the cliff's edge until a line calls for the gliders)
			if run.escort > 0:
				var want_x = px - 170 - 150 * i
				var want_y = run.p.y - HERO_H / 2 + (-80.0 if i == 0 else 70.0) + 16 * sin(run.t * 2.2 + i * 1.9)
				g.v = hv + clampf((want_x - g.x) * 1.6, -300.0, 700.0)
				g.x += g.v * d
				g.y += (clampf(want_y, CEIL + 60, GROUND - 60) - g.y) * minf(1.0, d * 2.0)
			else:                                    # tired: slower and lower, out of sight, gone
				g.v = move_toward(g.v, hv * 0.45, 500 * d)
				g.x += g.v * d
				g.y += 70 * d
				if g.x < run.cam - 220:
					g.gone = true
			continue
		if not g.on:
			if since < GUARD_OUT + GUARD_NEXT * i:
				continue
			g.on = true
			g.x = DOOR_X
			g.v = hv
		if run.guards_off >= 0:                      # turned back: off to the left, faster and faster
			g.v = move_toward(g.v, -GUARD_FLEE, 1600 * d)
			g.x += g.v * d
			continue
		var want = px - GUARD_GAP - GUARD_STEP * i
		if run.out < 2:
			g.v = hv
		else:
			g.v = hv + clampf((want - g.x) * GUARD_CLOSE, -0.5 * hv, GUARD_RUSH)
		g.x = minf(g.x + g.v * d, want + 8)

## Caught (Histoire, alone): they leap on him, a cloud of dust and blows, then he goes off tied to a spit,
## carried back to the temple. True once it is over (the end).
static func _capture(run: Run, d: float, px: float, fl: float) -> bool:
	var c = run.caught
	var t0: float = c.t
	c.t += d
	var k = clampf(c.t / (CATCH_LEAP + 0.6), 0, 1)  # the camera steps back a little (the distance waits)
	var sx2 = lerpf(c.sx0, c.sx0 + CATCH_SHIFT * run.view_w, k * k * (3 - 2 * k))
	run.cam -= sx2 - run.sx
	run.held -= sx2 - run.sx
	run.sx = sx2
	run.dist = (run.cam - run.held) / PPM
	if c.t < 0:                                      # from far behind: they run in (0.47)
		if floori(c.t / 0.28) > floori(t0 / 0.28):
			run.events.append("wriggle")
		return false
	if c.t < CATCH_LEAP:                             # his legs still kicking; they come
		if floori(c.t / 0.28) > floori(t0 / 0.28):
			run.events.append("wriggle")
		return false
	if t0 < CATCH_LEAP:                              # on him: the cloud bursts
		run.shake = maxf(run.shake, 0.7)
		run.events.append("pounce")
		for i in 22:
			part(run, px + rnd(-30, 30), fl - rnd(0, 50), rnd(-420, 420), rnd(-420, -60), rnd(0.4, 0.8), colour_of(["#e8dcc0", "#c9b89a", "#a8926e"]), rnd(6, 12), 900)
	if c.t < CATCH_FIGHT:                            # the fight: blows, dust, things flying out
		if floori(c.t / 0.17) > floori(t0 / 0.17):
			run.events.append("scuffle" if randf() < 0.6 else "bonk")
			run.shake = maxf(run.shake, 0.25)
		if randf() < 0.5:
			part(run, px + rnd(-50, 50), fl - rnd(0, 60), rnd(-260, 260), rnd(-300, -40), rnd(0.3, 0.6), colour_of(["#e8dcc0", "#c9b89a", "#a8926e"]), rnd(4, 9), 700)
		return false
	if t0 < CATCH_FIGHT:                             # the dust settles: tied to a spit, off he goes
		c.x = px
		run.events.append("skewer")
		for i in 16:
			part(run, px + rnd(-60, 60), fl - rnd(0, 40), rnd(-200, 200), rnd(-200, -40), rnd(0.4, 0.7), colour_of(["#e8dcc0", "#c9b89a"]), rnd(6, 11), 500)
		c.phase = "offer" if run.knives + run.free_knives > 0 or story_revive_ok(run) else "gone"   # a Couteau suisse (or 0.59: Histoire's one chance a level): offered (main.gd)
		c.timer = ESC_OFFER
	if t0 < CATCH_FIGHT + 0.6 and c.t >= CATCH_FIGHT + 0.6:
		run.events.append("snap")                    # (the photo: him on the spit)
	match c.phase:
		"offer":                                     # the knife offered: slowly on, staying in sight
			c.timer -= d
			c.x = maxf(c.x - CATCH_SLOW * d, run.cam + run.view_w * 0.3)
			if c.timer <= 0:
				c.phase = "gone"
		"escape":
			c.x = maxf(c.x - CATCH_SLOW * d, run.cam + run.view_w * 0.3)
			_escape_step(run, d)
		_:                                           # carried off to the temple: the end
			c.gone_t += d
			c.x -= CATCH_WALK * d
			if c.x < run.cam - 160 or c.gone_t > CATCH_END - CATCH_FIGHT:
				die(run)
				return true
	return false

## (0.59) Histoire, level 3 (the dungeon): slimes hop after him, SLIME_N of them, their gaps behind him. Into
## the dungeon they come from the left edge; out of it (or a boss) they fall behind and go.
const SLIME_N := 3
const SLIME_GAP := 110.0
const SLIME_STEP := 70.0
const SLIME_HOP := 0.55              # seconds for the first one to hop on him, once he is knocked out
const SLIME_GONE := 1.6              # ... swallowed for good: this long, then the end

static func _slimes(run: Run, d: float, hv: float) -> void:
	if run.caught != null:
		return
	var px = run.cam + run.sx
	var on = run.mode == "story" and not run.coop and run.boss == null and not run.dead and run.leap == null and story_level(run) == 3
	if on and run.slimes.is_empty():
		for i in SLIME_N:
			run.slimes.append({"x": run.cam - 80.0 - i * 90.0, "ph": i * 1.7})
	for i in run.slimes.size():
		var sl: Dictionary = run.slimes[i]
		sl.ph += d * 7.0
		if on:
			var want = px - SLIME_GAP - SLIME_STEP * i
			sl.x += (hv + clampf((want - sl.x) * 1.5, -0.4 * hv, 520.0)) * d
		else:
			sl.x += hv * 0.5 * d                     # (left behind)
	if not on:
		run.slimes = run.slimes.filter(func(sl): return sl.x > run.cam - 300)

## (0.59) The slime got him: it hops on him and swallows him; his one chance on this level offered (main.gd:
## the same escape as from the pygmies, « Extirpe-toi ! »), else swallowed for good. True once it is over.
static func _slime_capture(run: Run, d: float, px: float) -> bool:
	var c = run.caught
	var t0: float = c.t
	c.t += d
	match c.phase:
		"hop":
			if c.t >= SLIME_HOP:
				run.events.append("slurp")
				run.shake = maxf(run.shake, 0.5)
				c.phase = "offer" if story_revive_ok(run) else "gone"
				c.timer = ESC_OFFER
				if c.t - d < SLIME_HOP + 0.5:
					run.events.append("snap")        # (the photo: him in the slime)
		"offer":
			c.timer -= d
			if c.timer <= 0:
				c.phase = "gone"
		"escape":
			_escape_step(run, d)
		_:
			c.gone_t += d
			if c.gone_t > SLIME_GONE:
				die(run)
				return true
	return false

## (0.59) Histoire's levels: 1 the forest, 2 the heights, 3 the dungeon, 4 the city (where he is now).
static func story_level(run: Run) -> int:
	return {0: 1, SKY: 2, 3: 3, 2: 4}.get(biome_at(run, run.cam + run.sx), 1)

## (0.59) Histoire: his one way back on this level is still there (level 1: out of the pygmies' hands; level 3:
## out of a slime). Level 2 has none.
static func story_revive_ok(run: Run) -> bool:
	if run.mode != "story" or run.coop:
		return false
	var lv = story_level(run)
	return lv in [1, 3] and not run.revives.has(lv)

## Alone, any mode, no boss: whether the pygmies come for him when he falls (0.47: wherever he is).
static func capture_ok(run: Run) -> bool:
	return not run.coop and not run.dead and run.boss == null and run.exploded

## The Couteau suisse used (main.gd took it from the stock): the escape begins. False if not offered now.
static func escape_start(run: Run) -> bool:
	var c = run.caught
	if c == null or c.phase != "offer":
		return false
	if story_revive_ok(run):                     # (0.59) Histoire: the level's one chance, no knife needed
		run.revives[story_level(run)] = true
	elif run.free_knives > 0:                    # (0.54) the one equipped first, then the stock
		run.free_knives -= 1
	else:
		run.knives = maxi(0, run.knives - 1)
	var n = run.escapes
	var harder = 1.0 + ESC_HARDER * n
	var zw = clampf(ESC_ZONE + ESC_LANTERN * run.lanterns, 0.05, ESC_ZONE_MAX) * pow(0.85, n)
	if run.lvl("swiss") >= 2:                    # (0.54) the Couteau suisse, level 2: easier
		zw = minf(zw * SWISS_ZONE, 0.6)
		harder *= SWISS_SLOW
	c.phase = "escape"
	c.esc = {"time": ESC_TIME, "full": ESC_TIME, "rope": ESC_ROPE + n, "ropes": ESC_ROPE + n, "cur": 0.0, "cv": ESC_CURSOR * harder,
		"zone": 0.5, "zv": ESC_DRIFT * harder * (1.0 if rnd(0, 1) < 0.5 else -1.0), "w": zw}
	run.events.append("knife")
	return true

## The escape going on: the cursor and the zone to and fro, the time running out.
static func _escape_step(run: Run, d: float) -> void:
	var e: Dictionary = run.caught.esc
	e.time -= d
	e.cur += e.cv * d
	if e.cur > 1.0 or e.cur < 0.0:
		e.cur = clampf(e.cur, 0.0, 1.0)
		e.cv = -e.cv
	var half = e.w / 2
	e.zone += e.zv * d
	if e.zone > 1.0 - half or e.zone < half:
		e.zone = clampf(e.zone, half, 1.0 - half)
		e.zv = -e.zv
	if e.time <= 0:
		run.caught.phase = "gone"                    # the rope held: carried off
		run.events.append("held")

## A touch during the escape: the cursor in the zone cuts a rope (the last one: free), out of it costs time.
static func escape_tap(run: Run) -> void:
	var c = run.caught
	if c == null or c.phase != "escape":
		return
	var e: Dictionary = c.esc
	if absf(e.cur - e.zone) <= e.w / 2:
		e.rope -= 1
		run.events.append("cut")
		if e.rope <= 0:
			_release(run)
	else:
		e.time -= ESC_MISS
		run.events.append("miss")

## Free: he drops from the spit where it is, the pygmies dazed run off, the road ahead is cleared and the
## camera catches him up; one heart, a moment untouchable.
static func _release(run: Run) -> void:
	var c = run.caught
	var x: float = c.x
	run.escapes += 1
	if c.get("by", "") == "slime":                   # (0.59) out of the slime: it is thrown back, dazed
		run.events.append("pop")
		for sl in run.slimes:
			sl.x -= 500.0
	run.caught = null
	run.leap = null
	run.fatal = false
	run.hearts = maxi(1, run.hearts)
	var p = run.p
	p.roll = 0
	p.vy = -520
	p.ground = false
	p.plat = null
	p.jumps = 1
	p.y = floor_at(run, x) - 30
	p.inv = 2.5
	run.sx = x - run.cam
	run.out = 1                                      # the camera catches him up (as out of the temple)
	run.catch_from = run.sx
	run.catch_t = 0
	for o in run.obs:
		if o.x < run.cam + run.view_w + 700:
			o.gone = true
	run.fm = null
	run.guards = [{"x": x - 40, "v": -GUARD_FLEE * 0.4, "on": true}, {"x": x + 40, "v": -GUARD_FLEE * 0.3, "on": true}]
	if run.guards_off < 0:
		run.guards_off = run.t
	for i in 18:
		part(run, x + rnd(-40, 40), p.y - rnd(0, 40), rnd(-260, 260), rnd(-320, -60), rnd(0.4, 0.8), colour_of(["#e0c98e", "#8a5a2b", "#fff3a8"]), rnd(4, 9), 700)
	run.events.append("free")

## Coins picked up: with the Idole dorée, IDOL_MUL[level] more (its fractions kept until they make a coin).
static func add_gold(run: Run, v: int) -> void:
	var extra = 0
	if run.idol > 0:
		run.idol_acc += v * run.idol
		extra = floori(run.idol_acc)
		run.idol_acc -= extra
	run.gold += v + extra

## 0.55, the Corne de brousse equipped (Run illimitée, alone): out of the temple on the rhino's back, for
## HORN_M[level] metres (then it goes, as when its time is up).
static func call_mount(run: Run) -> void:
	var mt = Mount.new()
	mt.kind = "rhino"
	mt.until = run.dist + HORN_M[mini(run.lvl("horn"), HORN_M.size() - 1)]
	run.mount = mt
	run.p.inv = maxf(run.p.inv, 0.5)
	burst(run, run.cam + run.sx, run.p.y - 60, Color("#ffd35c"), 16, 260)
	run.events.append("horn")

## (0.59) Histoire, level 2: knocked out in the heights there is no way back. He drops off the bottom of the
## screen; then, seen from the forest's floor far below, he comes down from very high, head first, sinks into
## the ground all of him, and a tomb comes out of it at once. Then the end.
const SKYFALL_DROP := 1.0            # seconds he falls out of sight
const SKYFALL_V := 2600.0            # how fast he comes down to the forest's floor (units/s)
const SKYFALL_SINK := 0.5            # seconds to sink all of him
const SKYFALL_HOLD := 2.4            # the tomb, before the end

static func _skyfall_start(run: Run) -> void:
	var p = run.p
	var lp = Leap.new()
	lp.v = 0.0
	run.leap = lp
	run.skyfall = {"t": 0.0, "ph": "drop", "cut": 0.0, "at": 0.0}
	p.vy = -260.0
	p.ground = false
	p.plat = null
	p.rotor = false
	p.flew = false
	p.flying = false
	burst(run, run.cam + run.sx, p.y - 40, Color("#ff4d6d"), 14, 320)
	run.events.append_array(["hurt", "fling"])

static func _skyfall(run: Run, d: float, px: float) -> void:
	var s: Dictionary = run.skyfall
	var p = run.p
	s.t += d
	match s.ph:
		"drop":                                      # off the bottom of the screen
			p.vy += 2200 * d
			p.y += p.vy * d
			p.roll += d * 9
			if s.t > SKYFALL_DROP:
				_skyfall_cut(run, px)
		"fall":                                      # from very high, head first
			p.y += SKYFALL_V * d
			p.roll = PI
			var fl = floor_at(run, px)
			if p.y >= fl:
				p.y = fl
				s.ph = "sink"
				s.at = s.t
				run.leap.planted = true
				run.leap.pt = 0.0
				run.shake = 1.0
				run.events.append("plant")
				for i in 26:                         # a spray of earth
					part(run, px + rnd(-24, 24), fl - 2, rnd(-300, 300), rnd(-520, -140), rnd(0.5, 0.9), colour_of(["#8a6a42", "#6a4f30", "#b08a58", "#f4f0e0"]), rnd(6, 13), 1400)
		"sink":                                      # into the ground, all of him
			var k = clampf((s.t - s.at) / SKYFALL_SINK, 0, 1)
			p.y = floor_at(run, px) + k * (HERO_H + 30)
			if k >= 1:
				s.ph = "tomb"
				s.at = s.t
				run.shake = 0.5
				run.events.append("tomb")
				for i in 14:
					part(run, px + rnd(-30, 30), floor_at(run, px) - 2, rnd(-160, 160), rnd(-260, -60), rnd(0.4, 0.7), colour_of(["#8a6a42", "#b08a58"]), rnd(5, 9), 900)
		"tomb":
			if s.t - s.at > SKYFALL_HOLD and not run.dead:
				die(run)

## The cut: far below, the forest's floor (the heights' road and mist gone), and he comes down from very high.
static func _skyfall_cut(run: Run, px: float) -> void:
	var s: Dictionary = run.skyfall
	s.ph = "fall"
	s.cut = s.t
	run.biome = 0
	run.prev_biome = 0
	run.biome_x = -INF
	run.next_biome_at = INF
	run.strip_biome = -1
	run.sky = false
	run.terrain = [Vector2(px - 6000, GROUND), Vector2(px + 9000, GROUND)]
	run.pits = []
	run.obs = []
	run.coins = []
	run.zones = []
	run.plats = []
	run.p.y = GROUND - 1500
	run.p.roll = PI
	run.flash = 1.0
	run.events.append("whoosh")

static func die(run: Run) -> void:
	_fatal(run)
	run.dead = true
	if run.leap != null and run.leap.planted:
		return                                       # (stuck head first: he stays there, quietly)
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
	if f.wall and not f.walled:                      # (0.59) a wall of will-o'-the-wisps: every lane, and a pipe
		f.walled = true                              # under it, laid where he will be as it charges
		f.act.fill(true)
		f.level = 3
		var sp = maxf(run.speed, 300.0)
		var gx = run.cam + run.sx + sp * 1.0
		var z = tight(run, "gallery", gx, sp * 2.8, GROUND + GALLERY - 22)
		z.open = true
		z.wall = true
		f.phase = "aim"
		f.t = 0
		f.sx = run.view_w + 90
		f.hit = false
		return
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

## (0.56) The city's drones: seconds before their beam burns (negative: burning or done), -9 when none.
static func laser_in(f) -> float:
	if f == null or f.biome != 2:
		return -9.0
	if f.phase == "aim":
		return f.aim - f.t + LASER_ON
	if f.phase == "fire":
		return LASER_ON - f.t
	return -9.0

## (0.56) A city drone's beam would catch him standing where he is (one of the lanes aimed at crosses him on
## his floor): render.gd shows « SAUTE ! » as it comes.
static func laser_jump(run: Run) -> bool:
	var f = run.fm
	if f == null or f.biome != 2 or f.ghost:
		return false
	var fl = floor_at(run, run.cam + run.sx)
	for k in mini(f.act.size(), FM_LANES):
		var y0 = GROUND - (k + 0.5) * FM_STEP - LASER_H / 2
		if f.act[k] and y0 + 4 < fl - 2 and y0 + LASER_H - 4 > fl - HERO_H + 6:
			return true
	return false

static func followers(run: Run, d: float, box: Box, dashing: bool) -> void:
	var p = run.p
	var px = run.cam + run.sx
	if run.fm == null and (run.boss != null or run.eagle != null):
		run.fm_due = false
		run.next_fm = maxf(run.next_fm, run.dist + 150)
		return
	if run.fm == null:
		if split_at(run, px) or split_at(run, px + run.view_w):   # (0.67) not in the dungeon in two
			run.fm_due = false
			run.next_fm = maxf(run.next_fm, run.dist + 100)
			return
		if run.mount != null:                        # never on top of a ride
			run.fm_due = false
			run.next_fm = maxf(run.next_fm, run.dist + 100)
			return
		if not run.fm_due and run.dist >= run.next_fm and not talking(run):
			run.fm_due = true                        # from now on only coins are laid ahead
		if not run.fm_due or px < run.block_end + 60:
			return                                   # waits until the road is clear
		var nf = Swarm.new()
		nf.biome = biome_at(run, px)
		nf.waves = 1 + (1 if run.dist > 450 and W.randf() < 0.6 else 0) + (1 if run.dist > 900 and W.randf() < 0.5 else 0)
		nf.aim = 1.7
		nf.wall = nf.biome == 3 and run.dist > 450 and not run.coop and W.randf() < WISP_WALL   # (0.59)
		run.fm = nf
		wave(run)
	var f: Swarm = run.fm
	var before = laser_in(f)
	f.t += d
	if f.biome == 2 and not f.ghost and before > -1.0:   # (0.56) the beeps before the beam, then its burst
		var now = laser_in(f)
		for tk in LASER_TICKS:
			if before > tk and now <= tk:
				run.events.append("lasertick")
		if before > 0 and now <= 0:
			run.events.append("laser")
	if f.phase == "aim":                             # they follow the hero from the right edge
		f.sx += (run.view_w - 110 - f.sx) * minf(1, d * 5)
		if f.t >= f.aim:
			f.phase = "fire" if f.biome == 2 else "rush"
			f.t = maxf(0.0, f.t - f.aim)             # (0.56: carried on, the countdown stays even)
			if f.phase == "rush":
				run.events.append("rush")
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
	var under = p.ball != null and p.ball.kind == "gallery"   # (0.59) in a pipe under the floor: out of their reach
	if not f.hit and not f.ghost and not under and x0 + 8 < box.r and x0 + FM_W - 8 > box.l:
		for k in FM_LANES:
			var y0 = GROUND - (k + 0.5) * FM_STEP - FM_H * FM_THICK / 2
			if not f.act[k] or y0 + 6 > box.b or y0 + FM_H * FM_THICK - 6 < box.t:
				continue
			if dashing:
				f.hit = true
				f.sx = -999
				add_gold(run, 3)
				burst(run, px + 40, y0 + FM_H * FM_THICK / 2, Color("#7fe0c8"), 18, 340)
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
		box.call(pl.x - HERO_HALF, pl.x + pl.w + HERO_HALF, minf(pl.y, pl.y + pl.slope), maxf(pl.y, pl.y + pl.slope), "ledge")
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
				var y1 = GROUND - (k + 0.5) * FM_STEP - FM_H * FM_THICK / 2
				box.call(x0 + 8, x0 + FM_W - 8, y1 + 6, y1 + FM_H * FM_THICK - 6, "danger" if f.phase == "rush" else "waiting")
	return {"boxes": out, "coin": null}

static func _ease_speed(v: float, pace: float, ramp: float, dt: float) -> float:
	if pace > v:
		return minf(pace, v + ramp * dt)
	return v + (pace - v) * minf(1, dt * 3)

## 0.48: the boards at friends' records (and his own) are planted on the road once they are near, where he
## will be at that distance (the distance can stand still a while in Histoire: placed early it would drift).
static func place_signs(run: Run) -> void:
	for sg in run.signs:
		if sg["x"] == INF and float(sg["d"]) > run.dist and float(sg["d"]) - run.dist < SIGN_AHEAD:
			sg["x"] = run.cam + run.sx + (float(sg["d"]) - run.dist) * PPM

## The signs for a run: `board` the friends' list (net.gd: friends), `mode` story or endless, `mine` his best.
## Only records ahead of the start, the nearest first, MAX_SIGNS at most, two boards never closer than
## SIGN_GAP metres (the better one stays).
static func signs_for(board: Array, mode: String, mine: int) -> Array:
	var out = []
	for e in board:
		var d = int(e.get("best" if mode == "story" else "endless", 0))
		if d >= 50 and not e.get("me", false):
			out.append({"d": d, "name": str(e.get("name", "?")), "own": false, "x": INF, "look": str(e.get("sign", ""))})   # (0.58: his board's style)
	if mine >= 50:
		out.append({"d": mine, "name": "", "own": true, "x": INF})
	out.sort_custom(func(a, b): return a["d"] < b["d"])
	var kept = []
	for sg in out:
		if not kept.is_empty() and sg["d"] - kept[-1]["d"] < SIGN_GAP:
			if sg["own"]:                            # (his own record wins over a friend's next to it)
				kept[-1] = sg
			continue
		kept.append(sg)
	return kept.slice(0, MAX_SIGNS)

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
			if q.shard == -2:
				q.rot += q.vr * d                    # (a stick of TNT spins)
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

	if run.saying != "" or not run.say_queue.is_empty():   # Histoire: the guards' lines, one after the other
		run.say_age += dt
		var next = run.saying == ""
		if run.saying != "" and not say_by_touch(run):
			next = run.say_age >= line_time(run.saying)
		elif run.saying != "" and input.pressed:     # alone: a touch shows the whole line, the next touch goes on
			input.pressed = false                    # (the touch is for the words: no jump)
			if run.say_age * SAY_RATE >= run.saying.length():
				next = true
			else:
				run.say_age = run.saying.length() / SAY_RATE
		if next:
			run.say_age = 0
			if run.say_queue.is_empty():
				run.saying = ""
				run.who = ""
			else:
				var l: String = run.say_queue.pop_front()
				var cut = l.find("|")
				run.who = l.substr(0, cut) if cut >= 0 else ""
				run.saying = l.substr(cut + 1)
				run.events.append("say")
				if run.escort > 0 and "DELTAPLANE" in run.saying.to_upper():
					run.glide_go = true              # (0.54) « Aux deltaplanes ! »: off the cliff they jump
				if run.exploded and run.guards_off < 0 and (not TURN_CUE or "DEMI-TOUR" in run.saying.to_upper()):
					run.guards_off = run.t               # (on the way: the guards chasing him turn back)
	if run.wait > 0:                                 # still inside: the temple shakes, dust falls from the lintel
		var was_wait = run.wait
		if run.intro and say_by_touch(run):          # alone: the doorway waits for the last line to be read
			if run.saying != "" or not run.say_queue.is_empty():
				run.wait = maxf(run.wait, 1.05 + dt)
			else:
				run.wait = minf(run.wait, 1.05)
		run.wait -= dt
		run.wait_max = maxf(run.wait_max, run.wait + dt)
		if run.cam < 0:                              # (0.52) the camera slides from the temple to the doorway,
			var k = clampf(1.0 - maxf(run.wait, 0.0) / maxf(run.wait_max, 0.01), 0.0, 1.0)   # eased in and out
			var wx = run.cam + run.sx
			run.cam = 0.0 if run.wait <= 0 else -TEMPLE_PAN * (1.0 - k * k * (3.0 - 2.0 * k))
			run.sx = wx - run.cam
		if run.intro and was_wait >= 0.75 and run.wait < 0.75:
			run.events.append("rumble")
		if not run.intro or run.wait < 0.75:
			run.shake = maxf(run.shake, 0.22)
			if randf() < 0.6:
				part(run, rnd(60, 125), GROUND - rnd(195, 225), rnd(-20, 40), rnd(20, 120), 0.5, Color("#cfd3e6"), rnd(4, 8), 500)
		if run.wait > 0:
			return
		run.exploded = true
		run.blast_t = run.t
		run.shake = 1
		run.boom = 1
		if run.lvl("flight") > 0:
			run.p.cruise = CRUISE_TIME               # with the Vol, he flies out of the doorway
		if run.lvl("horn") > 0 and run.mode == "endless" and not run.coop and run.mount == null:
			call_mount(run)                          # (0.55) the Corne de brousse: out on the rhino
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
	var mate_acts: Array = run.act_in                # for two: what the partner started (remote_act)
	run.act_in = []
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
		if run.coop:
			run.acts.append("dash")                  # (for two: the partner's Esquive too, remote_act)
	elif "dash" in mate_acts and run.dash.t == 0:
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
		if run.coop:
			run.acts.append("monster")
	elif "monster" in mate_acts and run.monster.t == 0:
		run.monster.t = MONSTER_TIME[clampi(run.lvl("monster"), 1, MONSTER_TIME.size() - 1)]
		run.monster.cd = run.monster.full
		run.events.append("monster")
	if run.monster.t > 0 and randf() < 0.6:          # red fizz flying off behind him
		part(run, run.cam + run.sx - rnd(10, 40), run.p.y - rnd(10, 70), -rnd(160, 420), rnd(-60, 40), rnd(0.2, 0.45), colour_of(["#ff3b3b", "#ff6b4a", "#ffd35c"]), rnd(4, 9), 0)
	if input.ball and run.lvl("sphere") > 0 and not run.dead:   # (0.65) Normal / Sphère, no wait
		run.ball_on = not run.ball_on
		run.p.balled = 0
		run.events.append("roll" if run.ball_on else "unroll")
	if run.ball_on and run.p.ball == null:
		run.p.roll += run.speed * dt / 26
		run.p.balled += dt
	if run.leap == null and input.slow and run.lvl("slow") > 0 and run.slow.cd == 0:
		run.slow.t = SLOW_TIME[run.lvl("slow")]
		run.slow.cd = SLOW_CD
		run.events.append("slow")
		if run.coop:
			run.acts.append("slow")
	elif "slow" in mate_acts and run.slow.t == 0:
		run.slow.t = SLOW_TIME[clampi(run.lvl("slow"), 1, SLOW_TIME.size() - 1)]
		run.slow.cd = SLOW_CD
		run.events.append("slow")
	var dashing = run.dash.t > 0

	# --- scrolling: the hero first runs out of the temple, then the camera follows him ---
	run.t += d
	if run.coop or not (run.wait > 0 or talking(run)):   # 0.49: alone, the speed stops growing while they talk
		run.pace_t += d
	# The hero's own speed grows up to its cap; a mount, then the boss, impose theirs while they last.
	var own: float
	if run.mode == "story":                          # each scenery from its own speed, gaining 0.18 m/s a second
		own = run.base + ZONE_SPEED.get(run.biome, SPEED_BASE) - SPEED_BASE + (run.pace_t - run.zone_t) * STORY_GAIN
	else:
		own = run.base + run.pace_t * SPEED_GAIN * run.gain_mul
	own = minf(own, speed_cap(run))
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
		pace = own * R["mul"] if R.has("mul") else minf(speed_cap(run), R["base"] + R["gain"] * run.mount.t)
		road_pace = raw * R["mul"] if R.has("mul") else pace
	# Slowing down is quick; speeding back up (after a mount or the boss) is gradual.
	var ramp = MOUNTS[run.mount.kind].get("ramp", RAMP) if run.mount != null and run.boss == null else RAMP
	if run.monster.t > 0 and run.mount == null and run.boss == null:
		ramp = MONSTER_RAMP
	if run.ball_on:                                  # (0.65) the Sphère's mode: faster
		pace += BALL_PLUS * PPM
	run.speed = _ease_speed(run.speed, pace, ramp, dt)
	run.road_speed = _ease_speed(run.road_speed, road_pace, ramp, dt)
	if run.eagle != null and run.eagle.vmax >= 0:    # (0.60) the eagle beaten: he slows down onto the column
		run.speed = minf(run.speed, run.eagle.vmax)
		run.road_speed = minf(run.road_speed, run.eagle.vmax)
	run.own = own
	run.relic = maxf(0, run.relic - dt * 0.6)
	var gorilla_on = run.mount != null and run.mount.kind == "gorilla"
	run.vine = clampf(run.vine + (1.0 if gorilla_on else -1.0) * dt * 2.5, 0, 1)
	if run.leap != null:
		run.leap.v = 0.0 if run.leap.planted else maxf(160, run.leap.v * (1 - LEAP_DRAG * d))   # knocked out: he only slows down, slowly
		if run.skyfall != null:
			run.leap.v = 0.0                         # (0.59: the long fall: straight down)
	# he is thrown out of the temple faster than he runs
	var move: float
	if run.leap != null:
		move = run.leap.v * d
	else:
		move = (run.speed + (DODGE_SPEED if dashing else 0.0)) * (1.8 if run.exploded and run.sx < run.home else 1.0) * d
	var px0 = run.cam + run.sx                      # where he was: the Esquive sweeps everything between
	var lead = run.home + (EXIT_LEAD * run.view_w if run.intro and run.mode == "story" else 0.0)
	if run.out == 0:                                 # out of the temple, the camera still
		run.sx = minf(lead, run.sx + move)
		if run.sx >= lead:
			run.out = 1 if lead > run.home else 2
			run.catch_from = run.sx
			run.catch_t = 0
	else:
		var back = 0.0
		if run.out == 1:                             # Histoire: the camera catches him up, eased in and out
			run.catch_t += d
			var k = clampf(run.catch_t / EXIT_CATCH, 0, 1)
			var sx2 = lerpf(run.catch_from, run.home, k * k * (3 - 2 * k))
			back = run.sx - sx2
			run.sx = sx2
			if k >= 1:
				run.out = 2
		elif run.out == 2 and run.caught == null:    # (0.54) the gliders after him: the camera steps back a little,
			var want = run.home + (GLIDE_SHIFT * run.view_w if run.escort > 0 else 0.0)   # room behind him for them
			if absf(run.sx - want) > 0.01:
				var sx2 = move_toward(run.sx, want, GLIDE_PAN * d)
				back = run.sx - sx2
				run.sx = sx2
		run.cam += move + back
		if talk_hold(run):
			run.held += move + back                  # (alone, while the guards talk: the distance waits)
	var nd = (run.cam - run.held) / PPM
	if nd < run.dist and not run.coop:               # (after an escape the camera may go back a little: the
		run.held = run.cam - run.dist * PPM          # distance waits instead)
	else:
		run.dist = nd
	var px = run.cam + run.sx
	_guards(run, d, (px - px0) / d if d > 0 else 0.0)
	_slimes(run, d, (px - px0) / d if d > 0 else 0.0)
	var fl = floor_at(run, px)                      # the floor right under him
	var sky_now = biome_at(run, px) == SKY and run.leap == null
	if sky_now and not run.sky and run.sky_dist0 < 0:   # (0.60) where the heights began (the eagle comes from there)
		run.sky_dist0 = run.dist
	if sky_now and not run.sky:                      # (0.53) into the heights: no floor any more, he takes off
		if run.mount != null and not MOUNTS[run.mount.kind].get("fly", false):
			dismount(run, true)
		if run.mount == null:
			p.ground = false
			p.plat = null
			if absf(px - run.cliff_x) < 300:         # (0.54) off the cliff: a leap into the void, then he falls
				p.vy = minf(p.vy, -CLIFF_LEAP)       # until the Vol takes him
				p.cruise = 0
				p.rotor = false
				run.soar = CLIFF_FALL
				run.events.append("leap")
			else:
				p.cruise = maxf(p.cruise, CRUISE_TIME * 0.5)   # at cruising height on his own until the first press
				run.events.append("takeoff")
	run.sky = sky_now

	if run.skyfall != null:                          # (0.59) Histoire, the heights: the long fall to the forest's floor
		_skyfall(run, d, px)
		return
	if run.leap != null and run.leap.planted:        # --- head first in the ground, legs kicking ---
		var kicks = floori(run.leap.pt / 0.28)
		run.leap.pt += d
		if run.caught != null and run.caught.get("by", "") == "slime":   # (0.59) a slime got him
			if _slime_capture(run, d, px):
				return
		elif run.caught != null:                     # (Histoire: the guards were at his heels)
			if _capture(run, d, px, fl):
				return
		elif floori(run.leap.pt / 0.28) > kicks and run.leap.pt < PLANT_TIME:
			run.events.append("wriggle")             # his legs kicking, the earth crumbling round his head
			for i in 3:
				part(run, px + rnd(-14, 14), fl - 2, rnd(-120, 120), rnd(-220, -80), rnd(0.3, 0.5), colour_of(["#8a6a42", "#6a4f30", "#b08a58"]), rnd(4, 7), 1400)
		if run.caught == null and run.leap.pt > PLANT_TIME and not run.dead:
			die(run)
			return
	elif run.leap != null:                           # --- thrown (Dernier élan: bouncing along) ---
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
			else:                                    # the last landing: head first, stuck
				run.leap.planted = true
				run.leap.v = 0
				p.vy = 0
				p.roll = PI
				for i in 14:                         # a spray of earth
					part(run, px + rnd(-16, 16), fl - 2, rnd(-220, 220), rnd(-380, -120), rnd(0.4, 0.7), colour_of(["#8a6a42", "#6a4f30", "#b08a58", "#f4f0e0"]), rnd(5, 11), 1400)
				run.shake = maxf(run.shake, 0.6)
				if capture_ok(run) and run.mode == "story" and story_level(run) == 3 and not run.slimes.is_empty():
					var sl: Dictionary = run.slimes[0]   # (0.59) Histoire, the dungeon: the first slime swallows him
					run.caught = {"by": "slime", "t": 0.0, "x": px, "sx0": run.sx, "gx": [sl.x], "gx0": [sl.x], "phase": "hop", "timer": 0.0, "gone_t": 0.0, "esc": {}}
				elif capture_ok(run):
					var near = guards_after(run)     # at his heels (Histoire, before their turn), or from far behind
					var gx: Array = run.guards.map(func(g): return g.x) if near else [px - GUARD_GAP, px - GUARD_GAP - GUARD_STEP]
					var gx0: Array = gx.duplicate() if near else [run.cam - 120.0, run.cam - 220.0]
					run.caught = {"t": 0.0 if near else -CATCH_COME, "x": px, "sx0": run.sx, "gx": gx, "gx0": gx0, "phase": "fight", "timer": 0.0, "gone_t": 0.0, "esc": {}}
					for o in run.obs:                # (what he left behind him: gone)
						if o.x + o.w < px:
							o.gone = true
				run.events.append("plant")
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
			var out_of: Zone = p.ball
			p.ball = null
			p.y = fl
			_puff(run, px, p.y)
			run.events.append("unroll")
			if out_of.launch:                        # (0.59) thrown up high out of it
				p.ground = false
				p.plat = null
				p.vy = -(out_of.launch_v if out_of.launch_v > 0 else PIPE_LAUNCH)
				p.jumps = 1
				run.events.append("bounce")
		if p.ball == null and not mounted and p.plat == null:   # the Sphère (0.59: or a pipe of the dungeon): in he rolls
			for z in run.zones:
				if not run.ball_on and not (z.open and not SPLIT_ON and run.lvl("sphere") <= 0):
					continue                         # (0.65, 0.67) in the Sphère's mode only (before the dungeon in two: its open pipes for all)
				if z.mouth > 0:                      # (0.59) a mouth in the air: in as he passes it
					var my = floor_at(run, z.x) - z.mouth
					if not p.ground and px >= z.x and px < z.x + 130 and absf(p.y - HERO_H * 0.5 - my) < 64:
						p.ball = z
						break
				elif (p.ground or (z.wall and p.y > fl - 50)) and px >= z.x and px < z.x + (maxf(110.0, z.w - 140) if z.wall else 110.0):
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
			if z.mouth > 0:                          # (0.59) down from the mouth to the floor, then along it
				var u = clampf((px - z.x) / PIPE_SLOPE, 0, 1)
				p.y = lerpf(fl - z.mouth + HERO_H * 0.5, fl, u * u * (3 - 2 * u))
			p.roll += run.speed * d / 26
			p.balled += dt
		elif run.soar > 0 and not mounted:
			# (0.54) off the cliff: he falls, whatever is pressed, until the relic's Vol takes him
			run.soar -= dt
			p.ground = false
			p.plat = null
			p.rotor = false
			p.flying = false
			p.vy += JUMP_GRAVITY * run.grav() * d
			p.y += p.vy * d
			if run.soar <= 0 or p.y > GROUND - 40:     # (never down into the mist)
				run.soar = 0
				p.vy = -140
				p.cruise = CRUISE_TIME * 0.6         # at cruising height on his own until the first press
				p.jumps = 2
				burst(run, px, p.y - HERO_H / 2, Color("#9cff7a"), 24, 320)
				burst(run, px, p.y - HERO_H / 2, Color("#fff3a8"), 12, 200)
				run.relic = 1
				run.glitch = maxf(run.glitch, 0.4)
				run.events.append("soar")
				if run.mode == "story" and run.won == 0:
					grant(run, RELIC_POWERS[0])      # (Histoire: the crown's Vol, his new power, comes now)
				_cliff_flight(run)
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
				p.y = top_at(p.plat, px)             # a pad carries him up and down, a slope up or down
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
					p.vy += JUMP_GRAVITY * VOL_DROP * heavy * run.grav() * d    # released after flying: down quickly
				else:
					p.vy += (JUMP_HELD if (input.hold and p.vy < 0 and not p.vine_leap) else JUMP_GRAVITY * heavy) * run.grav() * d
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
				var land = fl if p.y >= fl and not run.sky else NAN   # (0.53: no one stands on the heights' mist)
				if run.sky and p.y >= fl + MIST_SINK and p.vy > 0 and not mounted:
					p.y = fl + MIST_SINK                  # (0.54) it does him no harm: it holds him up, he bounces
					p.vy = -MIST_BOUNCE                   # off it softly and the Vol takes him on from there
					p.rotor = false
					p.flew = false
					p.diving = false
					p.jumps = 1
					for i in 8:
						part(run, px + rnd(-34, 34), fl + rnd(-4, 14), rnd(-160, 160), rnd(-140, -30), rnd(0.4, 0.7), colour_of(["#e8f4f0", "#cfe3df", "#ffffff"]), rnd(8, 14), -60)
					run.events.append("mist")
				var on = null
				if p.vy > 0:                         # ledges only catch a falling hero
					for pl in run.plats:
						var top = top_at(pl, px)
						if before <= top + absf(pl.slope) * 0.05 and p.y >= top and px > pl.x - HERO_HALF and px < pl.x + pl.w + HERO_HALF:
							land = top
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
				var gap = o.x - (px + HERO_HALF)         # (0.63) one way only, up or down, from y0 +- amp to y0 (the
				var k = clampf((gap - SPIDER_STILL_M * PPM) / (SPIDER_RUN_M * PPM), 0.0, 1.0)   # height the road laid,
				o.y = o.y0 + (1.0 if sin(o.ph) >= 0 else -1.0) * o.amp * k   # fair), reached SPIDER_STILL_M m before him
		# --- the rare floating things: they zigzag up and down; touched, they are his ---
		for it in run.bonuses:
			if it.x < run.cam + run.view_w - 30:
				it.x += run.speed * BRAKE_PACE * d          # once in sight, they fly on ahead of him at 75 % of his speed
			var fb = floor_at(run, it.x)
			var zk = fmod(run.t / BONUS_ZIG + it.ph, 2.0)
			it.y = fb - BONUS_LOW - (BONUS_HIGH - BONUS_LOW) * (zk if zk < 1 else 2 - zk)
			if it.gone or absf(px - it.x) > (52.0 if it.kind == "brake" else 40.0) * SIZE:
				continue
			var tall_b: float = MOUNTS[run.mount.kind]["tall"] if run.mount != null else HERO_H
			if it.y < p.y - tall_b - 30 or it.y > p.y + 10:
				continue
			it.gone = true
			if it.kind == "urn":
				run.urns += 1
				burst(run, it.x, it.y, Color("#ffd35c"), 22, 300)
			else:
				run.brake += run.own * BRAKE_SHARE              # 20 % of his speed, now
				burst(run, it.x, it.y, Color("#7fd8ff"), 16, 260)
			run.events.append(it.kind)
		run.bonuses = run.bonuses.filter(func(b_): return not b_.gone and b_.x > run.cam - 200)

		# --- mounts: the ones ahead wait to be touched, and may be missed ---
		if run.mount != null:
			run.mount.t += dt
			var time: float = MOUNTS[run.mount.kind].get("time", 0.0)
			if run.mount.until > 0:                  # (0.55) the Corne's rhino: as far as it said
				if run.dist >= run.mount.until:
					dismount(run, true)
			elif time > 0 and run.mount.t >= time:
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
				if o.state == "warn":
					o.x = run.cam + run.view_w + 60
					var was_t = o.t
					o.t += d
					var still = DART_WARN - DART_FREEZE
					if not o.aim:                    # (0.55) on foot: the height it was laid at, over his floor
						if was_t < still and o.t >= still and run.mount == null and not o.own:
							_dart_lane(run, o, px)   # (as it stops: a height that leaves him a way through)
						o.y = floor_at(run, px) - o.alt - DART_H / 2
					elif o.t < still:                # its "!" follows his height, then (0.54) stays still its last
						var alt = clampf(floor_at(run, px) - (p.y - tall / 2), DART_ALTS[0][0], DART_TOP)   # seconds
						var want = floor_at(run, px) - alt - DART_H / 2   # (lazily: it lags behind him, slowly)
						o.y = move_toward(o.y, want, minf(DART_TRACK * d, absf(want - o.y) * (1.0 - exp(-DART_LAG * d))))
					elif was_t < still and not o.own:   # (0.55) as it stops: never where the last one crossed
						var fl_ = floor_at(run, px)
						var a = fl_ - (o.y + DART_H / 2)
						if absf(a - run.last_aim) < DART_SPREAD:   # (the nearer to him of the two, off the last one's)
							var up = run.last_aim + DART_SPREAD * 1.6
							var down = run.last_aim - DART_SPREAD * 1.6
							var up_ok = up <= DART_TOP
							var down_ok = down >= DART_ALTS[0][0]
							a = up if up_ok and (not down_ok or absf(up - a) <= absf(down - a)) else down
							o.y = fl_ - clampf(a, DART_ALTS[0][0], DART_TOP) - DART_H / 2
					if o.t >= DART_WARN:
						o.state = "go"
						o.alt = floor_at(run, px) - (o.y + DART_H / 2)   # (over the floor: a dip on the way changes nothing)
						if o.aim and not o.own:
							run.last_aim = o.alt
						run.events.append("dart")
				if o.state == "go":
					o.x -= DART_SPEED * d            # (0.61: at its own height, never along the ground's)
					if not o.gone and not o.dodged and o.x + o.w < px - HERO_HALF - 10:
						o.dodged = true              # gone past him: one missile dodged (not the ghosts)
						if not o.ghost:
							run.events.append("missile")
			if o.kind == "eagle":                    # (0.60) the eagle rushing along its line
				o.x += o.vx * d
			elif o.kind == "hail":                   # ... the storm's hail, falling slowly into the mist
				o.y += o.vy * d
				if o.y > GROUND + 40:
					o.gone = true
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
			eagle(run, d)                        # (0.60) Histoire, the heights' guardian
			camp(run, d)
		if run.coop and run.mate != null and run.mate.get("b", false):
			_rescue_check(run, px, box, d, move)        # the partner's bubble: jump into it to bring him back
		# sinking into a hole on his last heart, with nothing to save him: that is the fatal moment
		if p.y > GROUND + 24 and not p.ground and run.hearts == 1 and not run.god and run.rewind_left == 0 and run.mount == null and (not run.coop or run.race):
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
	run.decor = run.decor.filter(func(dc): return dc.x > run.cam - 900)   # (0.65: wide pictures, kept until well off screen)
	run.hills = run.hills.filter(func(hl): return hl.x + hl.w > run.cam - 200)
	run.zones = run.zones.filter(func(z): return z.x + z.w > run.cam - 200 or z == run.p.ball)
	run.obs = run.obs.filter(func(o): return not o.gone and o.x + o.w > run.cam - 120)
	run.plats = run.plats.filter(func(pl): return pl.x + pl.w > run.cam - 120)

	while run.terrain.size() > 2 and run.terrain[1].x < run.cam - 1500:   # (0.65: was 300: the scenery behind him lost its floor and vanished)
		run.terrain.pop_front()

	place_signs(run)
	# --- spawning ---
	var edge = run.cam + run.view_w + 200
	var obs0 = run.obs.size()
	var pits0 = run.pits.size()
	while run.next_x < edge and not road_held(run):
		spawn_pattern(run)
	_darts_vs_new(run, obs0, pits0)                  # (0.55) a flyer stopped where the new road asks otherwise

	for z in run.talk_zones:                         # Histoire: the guards start talking here
		if run.coop:
			if not z["on"] and run.cam + run.sx >= z["x0"]:
				z["on"] = true
				run.say_queue.append_array(z["lines"])
			continue
		# Alone: at their place the distance stops; they wait until nothing is left on the road, talk (a touch
		# for each line), and once they are done the road comes again from the right edge.
		if not z["on"] and run.dist >= z["at"]:
			z["on"] = true
			z["wait"] = true
		elif z["wait"] and road_clear(run):
			z["wait"] = false
			run.say_queue.append_array(z["lines"])
		elif z["on"] and not z["wait"] and not z["done"] and run.saying == "" and run.say_queue.is_empty():
			z["done"] = true
			run.next_x = maxf(run.next_x, run.cam + run.view_w + 60)
	# --- scenery change ---
	if run.coop and run.mode == "story" and run.cam + run.sx >= run.coop_zone_at:
		run.coop_zone_at = coop_next_mark(run.coop_zone_at)   # for two: a new place, its speed from here (the
		run.zone_t = run.pace_t                               # road laid it at this mark, see lay_speed)
		run.relic = 1
		run.glitch = maxf(run.glitch, 0.5)
		run.events.append("biome")
	var Z = ZONE_ENDLESS if run.mode == "endless" else ZONE
	if run.dist >= run.next_biome_at:
		run.by_mark = true                           # from now on the changes come with the distance marks
		run.next_biome_at = maxf(2 * Z, (floorf(run.dist / Z) + 1) * Z) if run.mode != "endless" else (floorf(run.dist / Z) + 1) * Z
		var at = run.cam + run.view_w + 400          # the new scenery starts ahead, off screen, and scrolls in
		if run.coop:
			pass                                     # (for two, spawn_pattern changed it already, at a place on the road)
		elif run.lvl("drunk") > 0:                   # Relique altérée: the next scenery only goes by, and this one comes back
			var sb = next_biome(run, run.biome)
			run.strip_biome = NEXT_BIOME[sb] if sb == SKY else sb   # (never the heights: no floor to run on)
			run.strip_x0 = at
			run.strip_x1 = at + RELIC_STRIP
		elif run.biome == 0 and next_biome(run, run.biome) == SKY:
			_cliff_begin(run)                        # (0.54) from the forest to the heights: a cliff, laid ahead
		else:
			run.prev_biome = run.biome
			run.biome = next_biome(run, run.biome)
			run.biome_x = at
		if run.mode == "story":                      # a new place: its own speed (ZONE_SPEED), gaining STORY_GAIN
			run.zone_t = run.pace_t
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
			if pr == null or not REACTS.has(pr["kind"]) or pr["kind"] in PROP_GONE:
				continue
			var react: Array = REACTS[pr["kind"]]
			if run.touched.has(i) or p.y < fl - TOUCH_H or biome_at(run, pr["x"]) != 0 or not flat_at(run, pr["x"], PROP_CELL * 0.6):
				continue
			var cx: float = pr["x"] + 34 * PIXEL
			if px < cx - 20 or px > cx + 90:
				continue
			run.touched[i] = run.t
			if pr["kind"] == PROP_LANTERN:
				run.lanterns += 1                    # lit: counted (the escape's zone grows with them)
				run.events.append("lantern")
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
					add_gold(run, HEART_GOLD)
				run.events.append("heart")
				burst(run, c.x, c.y, Color("#ff6b8a"), 14, 260)
			elif c.gem != "":
				add_gold(run, GEMS.get(c.gem, 10))
				run.gems += 1
				run.events.append("gem")
				burst(run, c.x, c.y, Color({"y": "#ffe36a", "r": "#ff6b6b"}.get(c.gem, "#5cc8ff")), 10, 220)
			else:
				add_gold(run, 1)
				run.events.append("coin")
				burst(run, c.x, c.y, Color("#fff3a8"), 4, 150)
			continue
		if dist < reach:
			c.x += dx / dist * 700 * d + run.speed * d
			c.y += dy / dist * 700 * d
	run.coins = run.coins.filter(func(c): return not c.gone and c.x > run.cam - 60)
