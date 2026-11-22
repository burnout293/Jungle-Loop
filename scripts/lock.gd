class_name Lock
extends RefCounted
## The debug menu's lock (0.48). Five touches on the level badge ask for a password, and the password itself
## is nowhere in the game: only a salt and the SHA-256 of the key that PBKDF2-HMAC-SHA256 draws from it
## (ROUNDS rounds). Reading the game's files (a decompiler, a dataminer) does not give it away, and every
## password tried costs ROUNDS hashes. Once the right one is typed on a device, its key (never the password)
## is kept there (KEPT) and the menu opens straight away; « Verrouiller cet appareil » in the menu forgets it.
## Letters only count: case, spaces and dashes are ignored (abcd-efgh = ABCD EFGH).
## A new password: python tools/debug_password.py (it rewrites SALT, ROUNDS and CHECK below).
## Debug builds (the editor, the benches, an export made with --export-debug) are not locked.

const SALT := "a389c5db8b317c07261b880172cc2bd1"
const ROUNDS := 300000
const CHECK := "b769cafa26e11907135e00249cdbab79816b9771c33ad2688c31523d9e88b760"
const KEPT := "user://jungle-loop-key.txt"
const TRIES := 5                         # wrong passwords in a row before a pause
const PAUSE := 30.0                      # seconds

static var _open := -1                   # -1 not looked at yet, 0 locked, 1 open
static var wrong := 0
static var wait_until := 0.0             # (ticks, seconds) no try before then

static func unlocked() -> bool:
	if OS.is_debug_build():
		return true
	if _open < 0:
		_open = 0
		if FileAccess.file_exists(KEPT):
			var k = FileAccess.get_file_as_string(KEPT).strip_edges()
			if k.length() == 64 and fits(k.hex_decode()):
				_open = 1
	return _open == 1

## Seconds before the next try is taken (after TRIES wrong ones in a row), 0 if it can be tried now.
static func waiting() -> float:
	return maxf(0.0, wait_until - Time.get_ticks_msec() / 1000.0)

## A password typed: true (and the device remembers it) if it is the one.
static func attempt(password: String) -> bool:
	if waiting() > 0:
		return false
	var key = derive(password)
	if not fits(key):
		wrong += 1
		if wrong >= TRIES:
			wrong = 0
			wait_until = Time.get_ticks_msec() / 1000.0 + PAUSE
		return false
	wrong = 0
	var f = FileAccess.open(KEPT, FileAccess.WRITE)
	if f != null:
		f.store_string(key.hex_encode())
		f.close()
	_open = 1
	return true

## This device asks for the password again.
static func forget() -> void:
	_open = 0
	if FileAccess.file_exists(KEPT):
		DirAccess.remove_absolute(KEPT)

static func normal(password: String) -> String:
	return password.strip_edges().to_upper().replace(" ", "").replace("-", "")

## PBKDF2-HMAC-SHA256, one block of 32 bytes (the same as Python's hashlib.pbkdf2_hmac).
static func derive(password: String, salt_hex: String = SALT, rounds: int = ROUNDS) -> PackedByteArray:
	var c = Crypto.new()
	var p = normal(password).to_utf8_buffer()
	var s = salt_hex.hex_decode()
	s.append_array(PackedByteArray([0, 0, 0, 1]))
	var u: PackedByteArray = c.hmac_digest(HashingContext.HASH_SHA256, p, s)
	var t0 = u.decode_u64(0)
	var t1 = u.decode_u64(8)
	var t2 = u.decode_u64(16)
	var t3 = u.decode_u64(24)
	for i in rounds - 1:
		u = c.hmac_digest(HashingContext.HASH_SHA256, p, u)
		t0 ^= u.decode_u64(0)
		t1 ^= u.decode_u64(8)
		t2 ^= u.decode_u64(16)
		t3 ^= u.decode_u64(24)
	var out = PackedByteArray()
	out.resize(32)
	out.encode_u64(0, t0)
	out.encode_u64(8, t1)
	out.encode_u64(16, t2)
	out.encode_u64(24, t3)
	return out

## Whether a key is the password's: its SHA-256 is CHECK.
static func fits(key: PackedByteArray) -> bool:
	if key.size() != 32:
		return false
	var h = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(key)
	return h.finish().hex_encode() == CHECK
