class_name Demo
extends RefCounted
## The animated preview of an upgrade, in the Améliorations screen (port of js/demo.js).
## Not a video: a real, tiny run of the game with only that upgrade on, a hand-placed stretch of
## jungle and a scripted player, restarted every five seconds. It always shows the real behaviour.
## For each upgrade: `build_<id>` places what the hero will meet (x is counted from where he starts),
## `play_<id>` decides the input from the distance to the next obstacle (`ahead`) and the time `t`.

const LOOP := 5.0                      # seconds
const START := 4000.0                  # far from the temple, which only stands at the origin
const W := 284.0                       # art pixels shown: the bottom of the play area
const H := 170.0

var run: Game.Run = null
var shown := ""
var level := 1
var clock := 0.0
var done := {}                         # the scripted presses already made (the gorilla's)

func has_scene(id: String) -> bool:
	return has_method("build_" + id.replace("-", "_"))

## Call when another upgrade is selected (or its level changes).
func show_demo(id: String, lvl: int) -> void:
	if not has_scene(id):
		return
	shown = id
	level = maxi(1, lvl)
	restart()

func restart() -> void:
	var ups = {}
	if not shown.begins_with("m-"):
		ups[shown] = level
	run = Game.new_run(ups)
	run.cam = START
	run.sx = Game.PX
	run.view_w = W * Game.PIXEL
	run.next_x = INF                   # nothing random: only what the scene places
	run.next_fm = INF
	run.next_mount = INF
	done = {}
	call("build_" + shown.replace("-", "_"), run, START + Game.PX)
	clock = 0.0

func step(dt: float) -> void:
	if run == null:
		return
	clock += dt
	if clock > LOOP:
		restart()
	var px = run.cam + run.sx
	var ahead = INF
	for o in run.obs:
		if o.x + o.w > px - 20:
			ahead = o.x - px
			break
	var inp = Game.Controls.new()
	var play = "play_" + shown.replace("-", "_")
	if has_method(play):
		call(play, run, ahead, clock, inp)
	Game.update(run, dt, inp)
	run.events.clear()                 # silent, and it earns nothing

# ---------- small helpers ----------

func _ride(r: Game.Run, x: float, kind: String) -> void:
	var it = Game.Item.new()
	it.x = x
	it.kind = kind
	it.y = Game.GROUND - Game.ZIG_LOW
	r.items.append(it)

func _no_ghosts(r: Game.Run) -> void:
	for o in r.obs:
		o.ghost = false

# ---------- the scenes ----------

func build_doubleJump(r: Game.Run, x: float) -> void:
	Game.add_hover(r, x + 760, Game.HEAD)
	Game.add_hover(r, x + 760, Game.LOW)
	Game.coin_line(r, x + 700, Game.GROUND - 215, 5)
	Game.add_hover(r, x + 1500, Game.HEAD)
	Game.add_hover(r, x + 1500, Game.LOW)

func play_doubleJump(r: Game.Run, ahead: float, _t: float, inp: Game.Controls) -> void:
	var p = r.p
	if p.ground and ahead < 200:                       # short hops, so it stays in frame
		inp.pressed = true
	elif not p.ground and p.jumps == 1 and p.vy > -120:
		inp.pressed = true

func build_magnet(r: Game.Run, x: float) -> void:
	Game.coin_line(r, x + 450, Game.GROUND - 125, 8)
	Game.coin_line(r, x + 950, Game.GROUND - 40, 6)
	Game.coin_line(r, x + 1350, Game.GROUND - 125, 8)

func build_breaker(r: Game.Run, x: float) -> void:
	Game.add_decor(r, x + 600)
	Game.add_decor(r, x + 950)
	Game.add_decor(r, x + 1400)

func build_dash(r: Game.Run, x: float) -> void:
	Game.add_spiky(r, x + 760)
	Game.add_spiky(r, x + 860)
	Game.add_spiky(r, x + 960)

func play_dash(_r: Game.Run, ahead: float, _t: float, inp: Game.Controls) -> void:
	if ahead < 130:
		inp.dash = true

func build_slow(r: Game.Run, x: float) -> void:
	Game.add_spiky(r, x + 800)
	Game.add_spiky(r, x + 1250)
	Game.add_hover(r, x + 1900, Game.HEAD)

func play_slow(r: Game.Run, _ahead: float, t: float, inp: Game.Controls) -> void:
	if t > 0.7 and t < 0.8:
		inp.slow = true
	for o in r.obs:
		if o.kind == "spiky" and o.x + o.w > r.cam + r.sx:
			if r.p.ground and o.x - r.cam - r.sx < 120:
				inp.pressed = true
			break

func build_flight(r: Game.Run, x: float) -> void:
	Game.add_hover(r, x + 900, Game.LOW)
	Game.add_hover(r, x + 900, Game.HEAD)
	Game.coin_line(r, x + 840, Game.GROUND - 215, 5)

func play_flight(r: Game.Run, ahead: float, _t: float, inp: Game.Controls) -> void:
	var p = r.p
	var near = ahead < 330 and ahead > -90
	if p.ground and near:                              # one press on foot: a jump
		inp.pressed = true
	elif not p.ground and near and not p.rotor and p.vy > -150 and p.y > Game.GROUND - 200:
		inp.pressed = true                             # one press in the air: up he goes
	inp.hold = near and p.y > Game.GROUND - 230        # let go above the wall: he drops

func build_spring(r: Game.Run, x: float) -> void:
	Game.add_spiky(r, x + 760)
	Game.coin_line(r, x + 700, Game.GROUND - 235, 5)
	Game.add_spiky(r, x + 1500)

func play_spring(r: Game.Run, ahead: float, _t: float, inp: Game.Controls) -> void:
	if r.p.ground and ahead < 190:
		inp.pressed = true
	inp.hold = true

func build_sprint(r: Game.Run, x: float) -> void:
	for k in 3:
		Game.coin_line(r, x + 450 + k * 750, Game.GROUND - 40, 10)

func build_sphere(r: Game.Run, x: float) -> void:
	var z = Game.Zone.new()
	z.x = x + 520
	z.w = Game.LOG_W
	z.kind = "log"
	r.zones.append(z)
	for i in 9:
		var c = Game.coin(r, x + 600 + i * 40, Game.GROUND - 24, "r" if i % 6 == 3 else "")
		c.tight = "log"

func build_scatter(r: Game.Run, x: float) -> void:
	for k in 4:
		Game.coin_line(r, x + 400 + k * 480, Game.GROUND - 40, 8)
		r.coins[r.coins.size() - 3 - k].gem = "yrby"[k]

func build_lucky(r: Game.Run, x: float) -> void:
	for k in 5:
		Game.coin_line(r, x + 400 + k * 380, Game.GROUND - 40, 4)
		Game.coin(r, x + 620 + k * 380, Game.GROUND - 60, "b")   # (the web version's plain gem: the blue one)

func build_heart(r: Game.Run, x: float) -> void:
	Game.add_spiky(r, x + 600)
	Game.add_spiky(r, x + 1500)

func build_drunk(r: Game.Run, x: float) -> void:
	Game.add_spiky(r, x + 600)
	Game.add_spiky(r, x + 1000)
	Game.add_hover(r, x + 1700, Game.LOW)
	for o in r.obs:
		o.ghost = true

func build_nature(r: Game.Run, x: float) -> void:
	_ride(r, x + 520, "rhino")
	Game.add_decor(r, x + 1000)
	Game.add_decor(r, x + 1500)
	Game.coin_line(r, x + 1000, Game.GROUND - 40, 14)
	_no_ghosts(r)

func build_lastLeap(r: Game.Run, x: float) -> void:
	r.hearts = 1
	Game.add_spiky(r, x + 600)
	_no_ghosts(r)

# the mounts, shown from the Montures family: the animal waits a few steps ahead

func build_m_gorilla(r: Game.Run, x: float) -> void:
	_ride(r, x + 300, "gorilla")
	Game.coin_line(r, x + 900, Game.HANG_Y - 50, 12)
	Game.add_spiky(r, x + 1100)

func play_m_gorilla(_r: Game.Run, _ahead: float, t: float, inp: Game.Controls) -> void:
	for pair in [["a", 1.3], ["b", 1.55], ["c", 3.9]]:   # up to the vines in two jumps, along them, then down
		if t > pair[1] and not done.has(pair[0]):
			done[pair[0]] = true
			inp.pressed = true

func build_m_rhino(r: Game.Run, x: float) -> void:
	_ride(r, x + 300, "rhino")
	Game.add_decor(r, x + 900)
	Game.add_decor(r, x + 1400)
	Game.coin_line(r, x + 800, Game.GROUND - 40, 18)
	_no_ghosts(r)

func build_m_dragonfly(r: Game.Run, x: float) -> void:
	_ride(r, x + 300, "dragonfly")
	for i in 24:
		Game.coin(r, x + 700 + i * 44, Game.GROUND - 160 - sin(i * 0.45) * 90)

func play_m_dragonfly(_r: Game.Run, _ahead: float, t: float, inp: Game.Controls) -> void:
	inp.hold = sin(t * 3.2 - 1.4) > 0

func build_mountMagnet(r: Game.Run, x: float) -> void:   # on the rhino, the coins above come down to him
	_ride(r, x + 300, "rhino")
	Game.coin_line(r, x + 800, Game.GROUND - 170, 10)
	Game.coin_line(r, x + 1350, Game.GROUND - 40, 8)
	_no_ghosts(r)

func build_tamed(r: Game.Run, x: float) -> void:         # the rhino caught though he jumps over it
	_ride(r, x + 300, "rhino")
	Game.add_decor(r, x + 1100)
	Game.coin_line(r, x + 800, Game.GROUND - 40, 14)
	_no_ghosts(r)

func play_tamed(r: Game.Run, _ahead: float, t: float, inp: Game.Controls) -> void:
	if r.mount == null and t > 0.3 and not done.has("hop"):
		done["hop"] = true
		inp.pressed = true

func build_jammer(r: Game.Run, x: float) -> void:        # the one change of scenery, the relic flickering
	r.next_biome_at = START / Game.PPM + 1
	Game.coin_line(r, x + 450, Game.GROUND - 40, 10)
	Game.coin_line(r, x + 1300, Game.GROUND - 40, 10)

func build_rewind(r: Game.Run, x: float) -> void:
	r.hearts = 1
	Game.add_spiky(r, x + 760)
	Game.add_spiky(r, x + 1500)

func play_rewind(r: Game.Run, ahead: float, _t: float, inp: Game.Controls) -> void:
	if r.p.ground and r.rewind_left == 0 and ahead < 120:
		inp.pressed = true
