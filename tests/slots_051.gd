extends SceneTree
# 0.51: the three parties (SaveData slots): each its own file, the one played remembered, one erased leaving
# the others, and partie 1 the same file as before 0.51 (a player's game is not lost on updating).
#   godot --headless --path . -s tests/slots_051.gd -- --bac   (tests/ has a .gdignore: kept out of the game)

var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("ÉCHEC : ", what)

func _init() -> void:
	Progress.load_config(FileAccess.get_file_as_string("res://reglages/progression.txt"))
	check(SaveData._bac(), "lancé avec --bac (les vraies parties ne sont pas touchées)")
	if not SaveData._bac():
		print("BILAN parties : relancer avec -- --bac")
		quit(1)
		return
	var kept = SaveData.current_slot()
	check(SaveData.path(1) == "user://jungle-loop-save-v1-bac.json", "la partie 1 garde le fichier d'avant (%s)" % SaveData.path(1))
	check(SaveData.path(2).ends_with("-p2.json") and SaveData.path(3).ends_with("-p3.json"), "les parties 2 et 3 ont leur fichier")
	for n in [1, 2, 3]:
		SaveData.reset(n)
	check(not SaveData.slot_used(2), "une partie effacée est vide")
	var a = SaveData.load_save(1)
	a["coins"] = 111
	SaveData.store(a, 1)
	var b = SaveData.load_save(2)
	b["coins"] = 222
	SaveData.store(b, 2)
	check(int(SaveData.load_save(1)["coins"]) == 111 and int(SaveData.load_save(2)["coins"]) == 222, "chaque partie a ses pièces")
	check(not SaveData.slot_used(3) and int(SaveData.load_save(3)["coins"]) == 0, "la partie 3 est neuve")
	SaveData.set_slot(2)
	SaveData.slot = 0                                # as if the game started again: read from its file
	check(SaveData.current_slot() == 2, "la partie jouée est retenue")
	check(int(SaveData.load_save()["coins"]) == 222, "sans numéro, c'est la partie jouée qui se charge")
	SaveData.reset(2)
	check(not SaveData.slot_used(2) and int(SaveData.load_save(1)["coins"]) == 111, "en effacer une laisse les autres")
	var code = SaveData.export_code(SaveData.load_save(1))
	SaveData.store(SaveData.import_code(code), 3)
	check(int(SaveData.load_save(3)["coins"]) == 111, "un code exporté s'importe dans une autre partie")
	for n in [1, 2, 3]:
		SaveData.reset(n)
	SaveData.set_slot(kept)
	print("BILAN parties : %d vérifications, %d échecs" % [checks, fails])
	quit(1 if fails > 0 else 0)
