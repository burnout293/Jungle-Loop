extends SceneTree
# 0.65: the kinds of race. « Pièces »: the road goes to the misty heights early and stays there, the same on
# both phones; a treasure's last race lays no coin; a mystery's « Valider » has no way back.

var fails := 0
var n := 0

func check(ok: bool, what: String) -> void:
	n += 1
	if not ok:
		fails += 1
	print(("ok   " if ok else "ÉCHEC ") + what)

func _init() -> void:
	var a = Game.coop_run({}, 4242, 0, false, "endless", true)
	var b = Game.coop_run({}, 4242, 0, true, "endless", true)
	Game.launch(a)
	Game.launch(b)
	var input = Game.Controls.new()
	var biomes := {}
	var t := 0.0
	while t < 120.0 and a.dist < 2500:
		Game.update(a, 1.0 / 60, input)
		Game.update(b, 1.0 / 60, input)
		biomes[a.biome] = true
		if a.dead or b.dead:
			a.dead = false
			b.dead = false
		t += 1.0 / 60
	check(a.sky_only and a.sky_ok, "Pièces: the heights allowed")
	check(a.biome == Game.SKY, "Pièces: in the misty heights by %d m (scenery %d)" % [a.dist, a.biome])
	check(a.biome == b.biome, "both phones in the same scenery")
	var c = Game.coop_run({}, 7, 0, false, "endless")
	c.no_coins = true
	var before = c.coins.size()
	Game.coin(c, 500, 300)
	check(c.coins.size() == before, "a treasure's last race: no coin laid")
	var r = Race.new()
	r.seats = {0: {"ready": true}}
	r.me = 0
	r.rules["score"] = "mystery"
	r.set_ready(false)
	check(r.seats[0]["ready"] == true, "mystery: « Valider » has no way back")
	print("BILAN types d'affrontement : %d vérifications, %d échecs" % [n, fails])
	quit()
