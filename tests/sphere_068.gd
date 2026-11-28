extends SceneTree
# 0.68: the Sphère's mode. Rolled up he jumps but has neither the Vol nor the double jump, his box is the ball's,
# and in the heights (all flight) it cannot be on.

var fails := 0
var n := 0

func check(ok: bool, what: String) -> void:
	n += 1
	if not ok:
		fails += 1
	print(("ok   " if ok else "ÉCHEC ") + what)

func step(r: Game.Run, input: Game.Controls, k: int = 1) -> void:
	for i in k:
		Game.update(r, 1.0 / 60, input)
		input.pressed = false
		input.ball = false

func _init() -> void:
	var r = Game.new_run({"sphere": 1, "doubleJump": 1, "flight": 1}, "endless", 5)
	r.biome = 0
	r.prev_biome = 0
	r.next_biome_at = INF
	r.god = true
	Game.launch(r)
	var input = Game.Controls.new()
	step(r, input, 300)                              # out of the temple, running
	r.p.cruise = 0
	step(r, input, 60)
	input.ball = true
	step(r, input)
	check(r.ball_on, "le bouton met en boule")
	var hb: Dictionary = Game.hitboxes(r)
	var hero = hb["boxes"].filter(func(b): return b["kind"] == "hero")[0]
	check(absf((hero["B"] - hero["T"]) - (Game.BALL_TALL - 8)) < 0.01 and absf((hero["R"] - hero["L"]) - 2 * Game.BALL_HALF) < 0.01, "sa boîte est celle de la boule (%.0f × %.0f)" % [hero["R"] - hero["L"], hero["B"] - hero["T"]])
	var waited = 0
	while not r.p.ground and waited < 120:
		step(r, input)
		waited += 1
	input.pressed = true
	input.hold = true
	step(r, input)
	check(not r.p.ground and r.p.jumps == 1, "il saute")
	step(r, input, 12)
	var vy0 = r.p.vy
	input.pressed = true
	step(r, input)
	check(r.p.jumps == 1 and not r.p.rotor and r.p.vy >= vy0, "en l'air : ni double saut ni Vol (sauts %d, vitesse %.0f puis %.0f)" % [r.p.jumps, vy0, r.p.vy])
	input.hold = false
	step(r, input, 90)
	input.ball = true
	step(r, input)
	check(not r.ball_on, "le bouton le déroule")
	input.pressed = true
	input.hold = true
	step(r, input)
	step(r, input, 12)
	input.pressed = true
	step(r, input)
	check(r.p.jumps == 2, "déroulé : le double saut revient")
	input.hold = false
	step(r, input, 90)
	# the heights: rolled up, he unrolls there; the button does nothing
	input.ball = true
	step(r, input)
	r.sky = true
	r.biome = Game.SKY
	r.prev_biome = Game.SKY
	r.biome_x = -INF
	step(r, input, 2)
	check(not r.ball_on, "dans les pitons il se déroule")
	input.ball = true
	step(r, input)
	check(not r.ball_on, "dans les pitons le bouton ne fait rien")
	print("BILAN sphère : %d vérifications, %d échecs" % [n, fails])
	quit()
