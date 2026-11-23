extends Node
## Music and sound effects (port of js/audio.js), loaded as the autoload "Audio".
## Two pieces of music, each looping: one behind the menus, one for the run, named in
## assets/music/tracks.json. The effects are the web version's own little synthesiser (tones and bursts
## of filtered hiss), rendered into sound samples a few at a time while the game starts.

const MUSIC_DIR := "res://assets/music/"
const RATE := 32000
# A fonceur's warning is a klaxon (no voice in the game), never twice within DANGER_GAP seconds.
const DANGER_GAP := 1.6
const DUCK := 0.3                              # how much of the music is left on the pause screen

var music_vol := 7
var sfx_vol := 7
var ducked := false
var wanted := ""                               # "" (silence), "menu" or "run"
var tracks := {}
var player: AudioStreamPlayer
var winding: AudioStreamPlayer = null          # the run's music winding down at the end of a run
var wind_t := 0.0
var wind_v0 := 0.0
var pending := ""                              # music to start once the wind-down has had its moment
var pending_t := 0.0
var pool: Array = []
var sounds := {}                               # name -> AudioStreamWAV
var todo: Array = []                           # effects still to render
var recipes := {}
var last_danger := -9.0
var hiss := PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	add_child(player)
	for i in 12:
		var p = AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	var raw = FileAccess.get_file_as_string(MUSIC_DIR + "tracks.json")
	var parsed = JSON.parse_string(raw) if raw != "" else null
	tracks = parsed if parsed is Dictionary else {}
	seed(1234)
	hiss.resize(RATE / 2)
	for i in hiss.size():
		hiss[i] = randf() * 2 - 1
	randomize()
	recipes = _recipes()
	todo = recipes.keys()

func _process(delta: float) -> void:
	for i in 3:                                  # a few effects rendered each frame until all are ready
		if todo.is_empty():
			break
		var name: String = todo.pop_front()
		sounds[name] = _render(recipes[name])
	if winding != null:                          # the record under a thumb: speed and pitch drop together, it fades out
		wind_t += delta
		var k = minf(1, wind_t / 0.85)
		winding.pitch_scale = maxf(0.25, pow(0.12, k))
		winding.volume_db = linear_to_db(maxf(0.0001, wind_v0 * clampf(2 - 2 * k, 0, 1)))
		if k >= 1:
			winding.queue_free()
			winding = null
	if pending != "":
		pending_t -= delta
		if pending_t <= 0:
			var which = pending
			pending = ""
			_play_file(which)

# ---------- volumes ----------

## Volumes go from 0 (off) to 10. 7, where a new game starts, is the level the sounds were made for.
func gain_of(v: int) -> float:
	return 0.5 * v / 7.0

func _level() -> void:
	var g = gain_of(music_vol) * (DUCK if ducked else 1.0)
	player.volume_db = linear_to_db(maxf(0.0001, g))

func set_volumes(music_v: int, sfx_v: int) -> void:
	music_vol = music_v
	sfx_vol = sfx_v
	_level()

## On the pause screen the music keeps playing, turned down.
func duck(on: bool) -> void:
	if ducked != on:
		ducked = on
		_level()

## The game is hidden (another window, the phone locked): everything stops, and picks up where it was.
func sleep(on: bool) -> void:
	player.stream_paused = on

# ---------- music ----------

func _play_file(which: String) -> void:
	if not tracks.has(which):
		return
	var path: String = MUSIC_DIR + str(tracks[which]["file"])
	if not ResourceLoader.exists(path):
		return                                   # missing: nothing (the web version had a built-in theme)
	var stream = load(path)
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	player.stream = stream
	player.pitch_scale = 1
	_level()
	player.play()

## Plays "menu" or "run" music, or nothing (""). Asking again for what already plays changes nothing.
## "over" (the end of a run) winds the run's music down, and the menu's comes in over its last breath.
func music(which: String) -> void:
	if music_vol <= 0:
		which = ""
	var delay = 0.0
	if which == "over":
		which = "menu"
		if wanted == "run" and player.playing:
			winding = AudioStreamPlayer.new()
			add_child(winding)
			winding.stream = player.stream
			winding.volume_db = player.volume_db
			winding.play(player.get_playback_position())
			wind_t = 0
			wind_v0 = db_to_linear(player.volume_db)
			player.stop()
			delay = 0.6
			wanted = ""
	if which == wanted and (player.playing or which == "" or pending != ""):
		return
	wanted = which
	player.stop()
	pending = ""
	if which == "":
		return
	if delay > 0:
		pending = which
		pending_t = delay
	else:
		_play_file(which)

func set_biome(_i: int) -> void:
	pass                                         # the built-in theme changed key with the scenery: not needed with the files

# ---------- effects ----------

func sfx(name: String, pitch: float = 1.0) -> void:
	if sfx_vol <= 0 or not sounds.has(name):
		return
	if name == "warn":
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_danger < DANGER_GAP:
			return                               # two fonceurs in a row get one warning
		last_danger = now
	var free_p: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			free_p = p
			break
	if free_p == null:
		free_p = pool[0]
		pool.push_back(pool.pop_front())
	free_p.stream = sounds[name]
	free_p.pitch_scale = pitch
	free_p.volume_db = linear_to_db(maxf(0.0001, gain_of(sfx_vol)))
	free_p.play()

static func hz(semi: float) -> float:
	return 220.0 * pow(2.0, semi / 12.0)

# A tone: frequency (sliding exponentially to `slide` if given), length, wave, volume, start.
static func T(freq: float, dur: float, wave: String, vol: float, when: float = 0.0, slide: float = 0.0) -> Array:
	return ["t", freq, dur, wave, vol, when, slide]

# A burst of hiss around `freq`: the grain of wood breaking, which no plain tone can give.
static func N(dur: float, vol: float, freq: float, when: float = 0.0) -> Array:
	return ["n", freq, dur, "", vol, when, 0.0]

static func arp(semis: Array, dur: float, wave: String, vol: float, gap: float) -> Array:
	var out: Array = []
	for k in semis.size():
		out.append(T(hz(semis[k] + 12), dur, wave, vol, k * gap))
	return out

func _recipes() -> Dictionary:
	var warn: Array = []
	for at in [0.0, 0.42]:                       # a two-tone klaxon, twice ("dan-ger, dan-ger")
		warn.append_array([T(988, 0.16, "square", 0.11, at), T(988, 0.16, "sawtooth", 0.05, at), T(740, 0.21, "square", 0.11, at + 0.17), T(740, 0.21, "sawtooth", 0.05, at + 0.17)])
	return {
		"jump": [T(320, 0.14, "square", 0.12, 0, 620)],
		"coin": [T(1320, 0.07, "square", 0.10), T(1760, 0.12, "square", 0.10, 0.06)],
		"bounce": [T(200, 0.25, "sine", 0.3, 0, 800)],
		"flap": [T(520, 0.07, "triangle", 0.09, 0, 900)],
		# 0.54: off the cliff (a whistle going down), the Vol taking him (rising), the mist bouncing him (a puff)
		"leap": [T(900, 0.55, "triangle", 0.09, 0, 260)],
		"soar": arp([0, 4, 7, 12, 16, 19], 0.22, "square", 0.11, 0.06),
		"mist": [N(0.25, 0.08, 500), T(300, 0.18, "sine", 0.08, 0, 520)],
		"mount": arp([0, 7, 12, 19], 0.2, "square", 0.14, 0.07),
		"unmount": [T(420, 0.3, "square", 0.2, 0, 110)],
		"bye": [T(700, 0.12, "triangle", 0.14, 0, 500), T(500, 0.16, "triangle", 0.14, 0.12, 350)],
		"spider": [T(1500, 0.16, "sawtooth", 0.07, 0, 320)],
		"timber": [T(160, 0.9, "sawtooth", 0.22, 0, 60), N(0.8, 0.35, 700)],
		"slither": [N(0.5, 0.25, 1800)],
		"boss": [T(60, 1.2, "sawtooth", 0.4, 0, 30), T(220, 0.9, "square", 0.18, 0.1, 70), N(1, 0.4, 300)],
		"spit": [T(300, 0.2, "triangle", 0.2, 0, 900), N(0.15, 0.25, 2000)],
		"acid": [T(180, 0.25, "sawtooth", 0.16, 0, 600)],
		"splash": [N(0.3, 0.35, 900)],
		"bossfall": [T(400, 1.4, "sawtooth", 0.3, 0, 40), N(1.2, 0.5, 250, 0.2)],
		"bossdown": arp([0, 4, 7, 12, 16, 19], 0.3, "triangle", 0.2, 0.09),
		"thud": [T(110, 0.22, "sine", 0.4, 0, 40), N(0.2, 0.4, 500)],
		"warn": warn,
		"slowtick": [T(1900, 0.04, "square", 0.09), T(1250, 0.05, "square", 0.07, 0.07)],   # tick-tock: time running out
		"slowend": [T(150, 0.45, "sine", 0.24, 0, 900), N(0.3, 0.14, 2600, 0.05)],          # the world rushing back
		"dart": [T(700, 0.3, "sawtooth", 0.1, 0, 200), N(0.25, 0.25, 3000)],
		"laser": [T(1800, 0.25, "sawtooth", 0.14, 0, 400)],
		# 0.56: the city's drones counting down to their beam (three of them, higher the last)
		"lasertick": [T(1320, 0.06, "square", 0.09)],
		"roll": [T(240, 0.22, "triangle", 0.16, 0, 520)],
		"unroll": [T(520, 0.18, "triangle", 0.14, 0, 260)],
		"heart": arp([12, 16, 19, 24], 0.22, "triangle", 0.2, 0.07),
		"grab": [T(620, 0.08, "triangle", 0.14, 0, 880)],
		"drop": [T(520, 0.1, "triangle", 0.12, 0, 300)],
		"fm": [T(880, 0.1, "square", 0.13), T(880, 0.1, "square", 0.13, 0.18), T(880, 0.1, "square", 0.13, 0.36)],
		"rush": [T(300, 0.5, "sawtooth", 0.12, 0, 1400)],
		"dodge": [T(990, 0.08, "triangle", 0.14), T(1320, 0.14, "triangle", 0.14, 0.07)],
		"break": [T(180, 0.18, "sawtooth", 0.25, 0, 50)],
		# a crate: the crack, the planks giving way, the thud
		"crate": [T(640, 0.04, "square", 0.14, 0, 210), N(0.17, 0.55, 1300, 0.01), N(0.11, 0.3, 3400, 0.04), T(170, 0.17, "sine", 0.38, 0.01, 52)],
		"dash": [T(200, 0.35, "sawtooth", 0.18, 0, 1200)],
		"throw": [T(500, 0.12, "triangle", 0.12, 0, 900), N(0.3, 0.12, 4200, 0.05)],              # a stick thrown, its fuse hissing
		"tnt": [T(120, 0.8, "sawtooth", 0.42, 0, 26), N(0.7, 0.6, 700), N(0.4, 0.35, 2600, 0.02)],   # the blast
		"dive": [T(900, 0.22, "sawtooth", 0.1, 0, 220)],
		"bubble": [T(700, 0.5, "sine", 0.16, 0, 300), N(0.25, 0.1, 5000, 0.05)],                    # coop: into a bubble
		"rescue": arp([0, 7, 12, 19], 0.18, "triangle", 0.2, 0.06),                                 # the partner brought back
		"back": [T(500, 0.3, "triangle", 0.16, 0, 1000)],                                          # the boots plunging
		"quake": [T(70, 0.5, "sine", 0.5, 0, 30), N(0.45, 0.5, 380), T(140, 0.2, "square", 0.15, 0, 60)],   # metal on stone
		"slow": [T(900, 0.6, "sine", 0.2, 0, 150)],
		# the last heart: a slide whistle as he flies off, then his head in the ground (thud) and a boing
		"fling": [T(1500, 0.55, "sine", 0.16, 0.0, 420), T(1520, 0.55, "sine", 0.06, 0.0, 430)],
		"plant": [T(95, 0.38, "sine", 0.6, 0.0, 36), N(0.3, 0.55, 520), N(0.14, 0.4, 2600, 0.02), T(180, 0.5, "triangle", 0.26, 0.14, 640), T(640, 0.32, "triangle", 0.16, 0.46, 230), T(900, 0.08, "square", 0.07, 0.78, 1300), T(1300, 0.08, "square", 0.07, 0.88, 900)],
		"pounce": [N(0.3, 0.5, 600), T(85, 0.35, "sine", 0.6, 0, 38), T(400, 0.18, "triangle", 0.12, 0.02, 160)],   # the guards leap on him
		"scuffle": [N(0.07, 0.4, 900), T(180, 0.08, "square", 0.1, 0, 90)],                       # a blow in the cloud of dust
		"bonk": [T(620, 0.1, "square", 0.1, 0, 300), N(0.03, 0.25, 3200)],                         # ... a head knocked
		"skewer": [T(70, 0.14, "sine", 0.55), T(70, 0.14, "sine", 0.5, 0.18), T(90, 0.22, "sine", 0.55, 0.36), T(hz(12), 0.14, "triangle", 0.16, 0.5), T(hz(15), 0.14, "triangle", 0.16, 0.59), T(hz(19), 0.14, "triangle", 0.16, 0.68), T(hz(24), 0.32, "triangle", 0.16, 0.77)],   # tied to the spit: drums, a little tune
		"wriggle": [N(0.08, 0.22, 1300), T(300, 0.07, "square", 0.07, 0.0, 450)],                # his legs kicking, earth crumbling
		"say": [T(520, 0.05, "square", 0.05, 0.0, 600), T(660, 0.05, "square", 0.04, 0.06, 700)],
		# RedMonster: the can hissing open, two gulps, then he revs up; and the fizz running out
		"monster": [N(0.35, 0.16, 6000), T(240, 0.1, "sine", 0.24, 0.2, 150), T(240, 0.1, "sine", 0.24, 0.33, 150), T(160, 0.6, "sawtooth", 0.14, 0.45, 1400)],
		"monsterend": [T(1300, 0.4, "sawtooth", 0.09, 0, 260)],
		"hit": [T(240, 0.5, "sawtooth", 0.3, 0, 40)],
		"hurt": [T(300, 0.22, "square", 0.2, 0, 90)],
		"gem": arp([12, 19, 24], 0.18, "triangle", 0.18, 0.06),
		"rewind": [T(150, 0.7, "triangle", 0.3, 0, 1400)],
		"biome": [T(660, 0.5, "sine", 0.2, 0, 1320), T(990, 0.6, "sine", 0.12, 0.1, 1980)],
		"buy": [T(660, 0.1, "triangle", 0.25), T(990, 0.2, "triangle", 0.25, 0.1), T(1320, 0.3, "triangle", 0.2, 0.2)],
		"no": [T(160, 0.15, "square", 0.15)],
		"click": [T(520, 0.05, "square", 0.08, 0, 780)],
		"record": arp([0, 4, 7, 12], 0.25, "triangle", 0.2, 0.09),
		"rumble": [T(55, 0.8, "sawtooth", 0.18, 0, 70)],
		"boom": [T(140, 0.9, "sawtooth", 0.45, 0, 28), T(70, 1.1, "square", 0.3, 0, 22), T(900, 0.25, "sawtooth", 0.12, 0, 120)],
		"shroom": arp([19, 24, 31], 0.25, "sine", 0.12, 0.05),
		"rustle": [T(2400, 0.06, "sawtooth", 0.03, 0, 900)],
		"monkey": [T(700, 0.09, "square", 0.1, 0, 1100), T(800, 0.09, "square", 0.1, 0.12, 1250), T(950, 0.12, "square", 0.1, 0.24, 1400)],
		"tick": [T(1500, 0.03, "square", 0.05)],
		"fill": [T(880, 0.045, "square", 0.06, 0, 1040)],                                          # a bar filling (pitched up as it fills)
		"impact": [T(110, 0.42, "sine", 0.55, 0, 44), N(0.24, 0.38, 900), T(660, 0.3, "triangle", 0.15, 0.03, 990)],   # the count's punch
		"quest": arp([7, 12, 16], 0.2, "triangle", 0.2, 0.08),
		"level": arp([0, 4, 7, 12, 16], 0.3, "triangle", 0.2, 0.08),
		# 0.47: a toucan's feather (a soft whoosh up), an urn (a clay knock, then a glint), the wooden shield
		# breaking, the bush horn calling, a lantern lit (a faint chime)
		"feather": [T(900, 0.22, "sine", 0.14, 0, 1800), N(0.18, 0.08, 5200, 0.02)],
		"urn": [T(220, 0.12, "triangle", 0.3, 0, 160), N(0.1, 0.2, 1400), T(hz(19), 0.18, "triangle", 0.14, 0.12), T(hz(24), 0.3, "triangle", 0.14, 0.2)],
		"shield": [N(0.25, 0.5, 700), T(160, 0.2, "square", 0.16, 0, 70), N(0.12, 0.3, 2400, 0.08)],
		"horn": [T(196, 0.7, "sawtooth", 0.16, 0, 233), T(294, 0.5, "sawtooth", 0.1, 0.1, 330)],
		"lantern": [T(hz(24), 0.25, "sine", 0.06), T(hz(31), 0.3, "sine", 0.04, 0.05)],
		# the escape: the knife out (a metal flick), a rope bitten through, a miss, free, the rope that held
		"knife": [T(1800, 0.06, "square", 0.08, 0, 2600), T(2400, 0.12, "triangle", 0.1, 0.05, 1600)],
		"cut": [N(0.08, 0.35, 2600), T(700, 0.08, "square", 0.1, 0, 1400)],
		"miss": [T(200, 0.18, "square", 0.14, 0, 120)],
		"free": arp([0, 4, 7, 12, 19], 0.22, "triangle", 0.2, 0.06),
		"held": [T(300, 0.5, "triangle", 0.18, 0, 110)],
		# the pygmies' drums: the low one, the high one, the shaker keeping time
		"drumlo": [T(90, 0.32, "sine", 0.7, 0, 48), N(0.05, 0.3, 280)],
		"drumhi": [T(300, 0.14, "triangle", 0.32, 0, 190), N(0.05, 0.35, 2600)],
		"shaker": [N(0.035, 0.07, 7000)],
	}

## Renders a list of voices into one sound, as Web Audio played them: each voice's volume falls
## exponentially to nothing over its length, its pitch slides exponentially when asked.
func _render(voices: Array) -> AudioStreamWAV:
	var total = 0.0
	for v in voices:
		total = maxf(total, v[5] + v[2] + 0.02)
	var count = ceili(total * RATE)
	var mix = PackedFloat32Array()
	mix.resize(count)
	for v in voices:
		var freq: float = v[1]
		var dur: float = v[2]
		var wave: String = v[3]
		var vol: float = v[4]
		var start = int(v[5] * RATE)
		var slide: float = v[6]
		var length = mini(count - start, int((dur + 0.02) * RATE))
		var fall = 0.0001 / vol
		if v[0] == "t":
			var phase = 0.0
			for i in length:
				var k = minf(1, i / (dur * RATE))
				var f = freq * pow(slide / freq, k) if slide > 0 else freq
				phase += f / RATE
				var fr = phase - floorf(phase)
				var s = 0.0
				match wave:
					"sine": s = sin(TAU * phase)
					"square": s = 1.0 if fr < 0.5 else -1.0
					"sawtooth": s = 2.0 * fr - 1.0
					"triangle": s = 1.0 - 4.0 * absf(fr - 0.5)
				mix[start + i] += s * vol * pow(fall, k)
		else:
			# white noise through a band-pass filter around `freq` (Q 0.8), as a Web Audio biquad
			var w0 = TAU * freq / RATE
			var alpha = sin(w0) / (2 * 0.8)
			var a0 = 1 + alpha
			var b0 = alpha / a0
			var b2 = -alpha / a0
			var a1 = -2 * cos(w0) / a0
			var a2 = (1 - alpha) / a0
			var x1 = 0.0
			var x2 = 0.0
			var y1 = 0.0
			var y2 = 0.0
			var off = randi() % int(RATE * 0.3)
			for i in length:
				var k = minf(1, i / (dur * RATE))
				var x = hiss[(off + i) % hiss.size()]
				var y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
				x2 = x1
				x1 = x
				y2 = y1
				y1 = y
				mix[start + i] += y * vol * pow(fall, k)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		bytes.encode_s16(i * 2, int(clampf(mix[i], -1, 1) * 32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
