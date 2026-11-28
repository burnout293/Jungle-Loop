class_name Lock
extends RefCounted
## The debug menu's lock (0.48, 0.64). Five touches on the level badge ask for the password of the day: the
## day's planet (Monday Lune, Tuesday Mars, Wednesday Mercure, Thursday Jupiter, Friday Vénus, Saturday
## Saturne, Sunday Soleil) then the day of the month plus the month, by the device's own date: Wednesday
## 26 November gives Mercure37. Case, accents, spaces and dashes are ignored. Once typed, the device keeps
## the day's code (KEPT) and the menu opens straight away until the day changes; « Verrouiller cet
## appareil » forgets it. Debug builds (the editor, the benches, --export-debug) are not locked.

const PLANETS := ["Soleil", "Lune", "Mars", "Mercure", "Jupiter", "Vénus", "Saturne"]   # Time's weekday: 0 is Sunday
const KEPT := "user://jungle-loop-key.txt"
const TRIES := 5                         # wrong passwords in a row before a pause
const PAUSE := 30.0                      # seconds

static var _open := -1                   # -1 not looked at yet, 0 locked, 1 open
static var wrong := 0
static var wait_until := 0.0             # (ticks, seconds) no try before then

## The password of a day ({weekday, day, month} as Time gives it; today's by default): « Mercure37 ».
static func of_day(d: Dictionary = {}) -> String:
	if d.is_empty():
		d = Time.get_date_dict_from_system()
	return "%s%d" % [PLANETS[int(d["weekday"]) % 7], int(d["day"]) + int(d["month"])]

## (0.66) The builds for the stores (Play: feature « play », Steam: « steam »): no debug menu at all (the
## password of the day can be worked out from the game's code).
static func store_build() -> bool:
	return OS.has_feature("play") or OS.has_feature("steam")

static func unlocked() -> bool:
	if OS.is_debug_build():
		return true
	if store_build():
		return false
	if _open < 0:
		_open = 0
		if FileAccess.file_exists(KEPT):
			if FileAccess.get_file_as_string(KEPT).strip_edges() == normal(of_day()):
				_open = 1
	return _open == 1

## Seconds before the next try is taken (after TRIES wrong ones in a row), 0 if it can be tried now.
static func waiting() -> float:
	return maxf(0.0, wait_until - Time.get_ticks_msec() / 1000.0)

## A password typed: true (and the device remembers it) if it is the one.
static func attempt(password: String) -> bool:
	if waiting() > 0:
		return false
	if store_build() or normal(password) != normal(of_day()):
		wrong += 1
		if wrong >= TRIES:
			wrong = 0
			wait_until = Time.get_ticks_msec() / 1000.0 + PAUSE
		return false
	wrong = 0
	var f = FileAccess.open(KEPT, FileAccess.WRITE)
	if f != null:
		f.store_string(normal(of_day()))
		f.close()
	_open = 1
	return true

## This device asks for the password again.
static func forget() -> void:
	_open = 0
	if FileAccess.file_exists(KEPT):
		DirAccess.remove_absolute(KEPT)

static func normal(password: String) -> String:
	var t = password.strip_edges().to_upper().replace(" ", "").replace("-", "")
	for pair in [["É", "E"], ["È", "E"], ["Ê", "E"], ["Ë", "E"]]:
		t = t.replace(pair[0], pair[1])
	return t
