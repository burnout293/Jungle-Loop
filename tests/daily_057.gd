extends SceneTree
# 0.57: the Course du jour. The same run for everyone on a day (seed, rule, items), another the next day; each
# rule does what it says; the tiers: reaching one gives it and those below, each once a day, again the next
# day; the save keeps it. Also: the group kept on the phone (to join it again after a crash).
#   godot --headless --path . -s tests/daily_057.gd -- --bac   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func road(seed_: int, kit: Dictionary) -> Array:
	var r = Game.new_run(kit, "endless", seed_)
	r.next_x = 3000.0
	r.calm_until = 0
	r.easy_until = 0
	while r.next_x < 40000.0:
		r.cam = r.next_x - 900
		Game.spawn_pattern(r)
	return r.obs.map(func(o): return "%s %d %d" % [o.kind, roundi(o.x), roundi(o.y)])

func _init() -> void:
	Tune.load_file()
	Game.set_shapes(FileAccess.get_file_as_string("res://reglages/patterns.txt"))
	Daily.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))
	var a = Daily.of_day("2026-11-24")
	var b = Daily.of_day("2026-11-24")
	var c = Daily.of_day("2026-11-25")
	check(a == b, "le même jour : la même course pour tous (graine, règle, objets)")
	check(a["seed"] != c["seed"], "le lendemain : une autre")
	check(a["kit"].size() >= 2 and Daily.RULES.has(a["rule"]), "deux objets imposés au moins, une règle connue")
	var rules = {}
	for k in 60:
		rules[Daily.of_day("2026-%02d-%02d" % [1 + k / 28, 1 + k % 28])["rule"]["id"]] = true
	check(rules.size() >= 4, "les règles changent d'un jour à l'autre (%d sur 60 jours)" % rules.size())
	check(road(a["seed"], a["kit"]) == road(a["seed"], a["kit"]), "la même graine : la même route")

	for rule in Daily.RULES:                          # each rule does what it says
		var r = Game.new_run({}, "endless", 5)
		Daily.apply(r, {"rule": rule, "kit": {}})
		var ok = r.daily
		if rule.has("speed"):
			ok = ok and r.gain_mul > 1.0 and r.base > Game.SPEED_BASE
		if rule.has("biome"):
			ok = ok and r.biome == rule["biome"] and r.next_biome_at == INF
		if rule.has("hearts"):
			ok = ok and r.hearts == rule["hearts"] and r.max_hearts == rule["hearts"]
		if rule.get("mounts", true) == false:
			ok = ok and r.mounts.is_empty()
		check(ok, "la règle « %s » s'applique" % rule["name"])

	var s = SaveData.blank()
	s["coins"] = 0
	var n = Daily.tiers.size()
	check(n >= 3 and Daily.tiers[0]["m"] < Daily.tiers[1]["m"], "des paliers, dans l'ordre (%d)" % n)
	var got = Daily.claim(s, Daily.tiers[1]["m"] + 5)
	var coins_1_2 = 0
	for i in [0, 1]:
		if Daily.tiers[i]["what"] == "coins":
			coins_1_2 += int(Daily.tiers[i]["n"])
	check(got == [0, 1] and int(s["coins"]) == coins_1_2, "le 2e palier atteint : le 1er et le 2e gagnés (%s, %d pièces)" % [str(got), int(s["coins"])])
	check(Daily.claim(s, Daily.tiers[1]["m"] + 50).is_empty() and int(s["coins"]) == coins_1_2, "rejouée : un palier déjà gagné ne se gagne plus")
	var urns0 = int(s["urns"])
	got = Daily.claim(s, Daily.tiers[2]["m"] + 1)
	check(got == [2], "plus loin : le palier suivant seulement (%s)" % str(got))
	if Daily.tiers[2]["what"] == "urn":
		check(int(s["urns"]) == urns0 + int(Daily.tiers[2]["n"]), "sa récompense : une urne")
	check(Daily.won(s) == 3 and int(s["daily"]["best"]) >= Daily.tiers[2]["m"], "3 paliers gagnés aujourd'hui, le meilleur du jour gardé")
	s["daily"]["day"] = "2000-01-01"                 # (yesterday's)
	check(Daily.won(s) == 0 and Daily.claim(s, Daily.tiers[0]["m"]) == [0], "un nouveau jour : tout est à regagner")
	var kept = SaveData.sanitize(JSON.parse_string(JSON.stringify(s)))
	check(kept["daily"]["day"] == Daily.today() and kept["daily"]["got"][0] == true, "la sauvegarde garde la course du jour")

	# --- the group kept on the phone (0.57) ---
	var race = Race.new()
	race.save = {"coins": 0, "online": {"name": "Pépito", "code": "PEPI-TEST"}, "skins": {"worn": {}}}
	race.role = "guest"
	race.room = "ABCD"
	race.me = 2
	race._state("lobby", "")
	var k = Race.kept()
	check(k.get("room", "") == "ABCD" and k.get("role", "") == "guest" and int(k.get("me", -1)) == 2, "le groupe gardé sur le téléphone (salle, rôle, place)")
	race.role = ""
	race.room = ""
	race._state("idle", "")
	check(Race.kept().is_empty(), "quitté : plus rien de gardé")
	race.free()
	print("BILAN course du jour : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
