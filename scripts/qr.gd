class_name QR
extends RefCounted
## QR codes (0.48): the friend link (https://…/?ami=PEPI-XXXX) shown as a square of modules that any phone's
## camera reads. Byte mode, error correction level M (a quarter of the code can be lost), the smallest version
## that holds the text, the mask with the lowest penalty: ISO/IEC 18004. No library: the game draws it itself.
##   var m = QR.encode("https://…")   -> {"size": n, "dark": PackedByteArray (n * n, 1 = dark)}
##   var tex = QR.texture(m, 4)        -> an ImageTexture, 4 pixels a module, a quiet zone of 4 modules

const ECL_M := 0                        # the levels in the format bits' order: M 00, L 01, H 10, Q 11
const ECL_L := 1
const ECL_H := 2
const ECL_Q := 3

# Per version (index 1..40; index 0 unused), per level in the order L, M, Q, H: error correction codewords in each
# block, and the number of blocks (ISO 18004 table 9).
const ECC_PER_BLOCK := [
	[-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
	[-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
]
const BLOCKS := [
	[-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
	[-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
	[-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
	[-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
]
const ORDER := {ECL_L: 0, ECL_M: 1, ECL_Q: 2, ECL_H: 3}   # a level's row in the two tables above

## The code for `text` (UTF-8). {} if it does not fit even in version 40.
static func encode(text: String, ecl: int = ECL_M) -> Dictionary:
	var data = text.to_utf8_buffer()
	var ver = 0
	for v in range(1, 41):
		var cap = _data_codewords(v, ecl) * 8
		var need = 4 + (8 if v < 10 else 16) + data.size() * 8
		if need <= cap:
			ver = v
			break
	if ver == 0:
		return {}
	# the bit stream: mode 0100 (bytes), the count, the bytes, a terminator, padding to whole codewords
	var bits: Array = []
	_put(bits, 4, 4)
	_put(bits, data.size(), 8 if ver < 10 else 16)
	for b in data:
		_put(bits, b, 8)
	var cap_bits = _data_codewords(ver, ecl) * 8
	_put(bits, 0, mini(4, cap_bits - bits.size()))
	_put(bits, 0, (8 - bits.size() % 8) % 8)
	var words = PackedByteArray()
	for i in range(0, bits.size(), 8):
		var v = 0
		for j in 8:
			v = (v << 1) | bits[i + j]
		words.append(v)
	var pad = [0xEC, 0x11]
	var k = 0
	while words.size() < _data_codewords(ver, ecl):
		words.append(pad[k % 2])
		k += 1
	var all = _with_ecc(words, ver, ecl)
	var size = ver * 4 + 17
	var dark = PackedByteArray()
	dark.resize(size * size)
	var fixed = PackedByteArray()                 # the function patterns: never data, never masked
	fixed.resize(size * size)
	_patterns(dark, fixed, size, ver)
	_place(dark, fixed, size, all)
	var best = -1
	var best_pen = 1 << 30
	for mask in 8:
		var trial = dark.duplicate()
		_mask(trial, fixed, size, mask)
		_format(trial, size, ecl, mask)
		var pen = _penalty(trial, size)
		if pen < best_pen:
			best_pen = pen
			best = mask
	_mask(dark, fixed, size, best)
	_format(dark, size, ecl, best)
	return {"size": size, "dark": dark, "version": ver, "mask": best}

## A picture of the code: `px` pixels a module, `quiet` modules of light all round (4: what readers expect).
static func image(code: Dictionary, px: int = 4, quiet: int = 4, ink: Color = Color.BLACK, paper: Color = Color.WHITE) -> Image:
	var n: int = code["size"]
	var side = (n + 2 * quiet) * px
	var im = Image.create(side, side, false, Image.FORMAT_RGBA8)
	im.fill(paper)
	var dark: PackedByteArray = code["dark"]
	for y in n:
		for x in n:
			if dark[y * n + x] == 1:
				im.fill_rect(Rect2i((x + quiet) * px, (y + quiet) * px, px, px), ink)
	return im

static func texture(code: Dictionary, px: int = 4, quiet: int = 4) -> ImageTexture:
	return ImageTexture.create_from_image(image(code, px, quiet))

# ---------- inside ----------

static func _put(bits: Array, v: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append((v >> i) & 1)

## The modules left for data and error correction in version `v` (all of them but the function patterns), in codewords.
static func _raw_codewords(v: int) -> int:
	var r = (16 * v + 128) * v + 64
	if v >= 2:
		var na = v / 7 + 2
		r -= (25 * na - 10) * na - 55
		if v >= 7:
			r -= 36
	return r / 8

static func _data_codewords(v: int, ecl: int) -> int:
	var row = ORDER[ecl]
	return _raw_codewords(v) - ECC_PER_BLOCK[row][v] * BLOCKS[row][v]

## The data codewords cut in blocks, each followed by its Reed-Solomon codewords, then read across the
## blocks (interleaved): the order they are placed in.
static func _with_ecc(words: PackedByteArray, v: int, ecl: int) -> PackedByteArray:
	var row = ORDER[ecl]
	var nb: int = BLOCKS[row][v]
	var ecc_len: int = ECC_PER_BLOCK[row][v]
	var raw = _raw_codewords(v)
	var short_n = nb - raw % nb                   # blocks one data codeword shorter than the rest
	var short_len = raw / nb
	var gen = _rs_generator(ecc_len)
	var blocks: Array = []
	var k = 0
	for i in nb:
		var dlen = short_len - ecc_len + (0 if i < short_n else 1)
		var dat = words.slice(k, k + dlen)
		k += dlen
		blocks.append([dat, _rs_remainder(dat, gen)])
	var out = PackedByteArray()
	var most = short_len - ecc_len + 1
	for i in most:
		for b in blocks:
			if i < b[0].size():
				out.append(b[0][i])
	for i in ecc_len:
		for b in blocks:
			out.append(b[1][i])
	return out

static func _gf_mul(x: int, y: int) -> int:
	var z = 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF

## The generator polynomial of degree n (its coefficients after the leading 1, highest first).
static func _rs_generator(n: int) -> PackedByteArray:
	var g = PackedByteArray()
	g.resize(n)
	g[n - 1] = 1
	var root = 1
	for i in n:
		for j in n:
			g[j] = _gf_mul(g[j], root)
			if j + 1 < n:
				g[j] ^= g[j + 1]
		root = _gf_mul(root, 0x02)
	return g

static func _rs_remainder(data: PackedByteArray, gen: PackedByteArray) -> PackedByteArray:
	var n = gen.size()
	var r = PackedByteArray()
	r.resize(n)
	for b in data:
		var f = b ^ r[0]
		for i in n - 1:
			r[i] = r[i + 1]
		r[n - 1] = 0
		for i in n:
			r[i] ^= _gf_mul(gen[i], f)
	return r

static func _mod(dark: PackedByteArray, fixed: PackedByteArray, n: int, x: int, y: int, on: bool) -> void:
	dark[y * n + x] = 1 if on else 0
	fixed[y * n + x] = 1

## The finders, their separators, the timing lines, the alignment squares, the dark module, and room kept
## for the format (and version) bits.
static func _patterns(dark: PackedByteArray, fixed: PackedByteArray, n: int, v: int) -> void:
	for i in n:
		_mod(dark, fixed, n, 6, i, i % 2 == 0)
		_mod(dark, fixed, n, i, 6, i % 2 == 0)
	for c in [[3, 3], [n - 4, 3], [3, n - 4]]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x = c[0] + dx
				var y = c[1] + dy
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var d = maxi(absi(dx), absi(dy))
				_mod(dark, fixed, n, x, y, d != 2 and d != 4)
	var pos = _align_positions(v)
	var na = pos.size()
	for i in na:
		for j in na:
			if (i == 0 and j == 0) or (i == 0 and j == na - 1) or (i == na - 1 and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_mod(dark, fixed, n, pos[i] + dx, pos[j] + dy, maxi(absi(dx), absi(dy)) != 1)
	# the format's room (filled by _format), and the dark module
	for i in 9:
		if i != 6:
			fixed[8 * n + i] = 1
			fixed[i * n + 8] = 1
	for i in 8:
		fixed[8 * n + (n - 1 - i)] = 1
		fixed[(n - 1 - i) * n + 8] = 1
	_mod(dark, fixed, n, 8, n - 8, true)
	if v >= 7:                                    # the version, twice (6 x 3 blocks)
		var rem = v
		for i in 12:
			rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
		var bits = (v << 12) | rem
		for i in 18:
			var on = ((bits >> i) & 1) == 1
			var a = n - 11 + i % 3
			var b = i / 3
			_mod(dark, fixed, n, a, b, on)
			_mod(dark, fixed, n, b, a, on)

static func _align_positions(v: int) -> Array:
	if v == 1:
		return []
	var na = v / 7 + 2
	var step = 26 if v == 32 else ceili((v * 4 + 4) / float(na * 2 - 2)) * 2
	var out = [6]
	var p = v * 4 + 17 - 7
	var rest = []
	for i in na - 1:
		rest.push_front(p)
		p -= step
	out.append_array(rest)
	return out

## The codewords, bit by bit, up and down two columns at a time from the bottom right (skipping column 6).
static func _place(dark: PackedByteArray, fixed: PackedByteArray, n: int, words: PackedByteArray) -> void:
	var i = 0
	var total = words.size() * 8
	var right = n - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in n:
			for j in 2:
				var x = right - j
				var upward = ((right + 1) & 2) == 0
				var y = (n - 1 - vert) if upward else vert
				if fixed[y * n + x] == 0 and i < total:
					dark[y * n + x] = (words[i >> 3] >> (7 - (i & 7))) & 1
					i += 1
		right -= 2

static func _mask(dark: PackedByteArray, fixed: PackedByteArray, n: int, m: int) -> void:
	for y in n:
		for x in n:
			if fixed[y * n + x] == 1:
				continue
			var flip = false
			match m:
				0: flip = (x + y) % 2 == 0
				1: flip = y % 2 == 0
				2: flip = x % 3 == 0
				3: flip = (x + y) % 3 == 0
				4: flip = (x / 3 + y / 2) % 2 == 0
				5: flip = x * y % 2 + x * y % 3 == 0
				6: flip = (x * y % 2 + x * y % 3) % 2 == 0
				7: flip = ((x + y) % 2 + x * y % 3) % 2 == 0
			if flip:
				dark[y * n + x] ^= 1

## The level and the mask, with their BCH error correction, around the top left finder and split between the
## other two.
static func _format(dark: PackedByteArray, n: int, ecl: int, m: int) -> void:
	var d = (ecl << 3) | m
	var rem = d
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits = ((d << 10) | rem) ^ 0x5412
	var at = func(i: int) -> int: return (bits >> i) & 1
	for i in 6:
		dark[i * n + 8] = at.call(i)
	dark[7 * n + 8] = at.call(6)
	dark[8 * n + 8] = at.call(7)
	dark[8 * n + 7] = at.call(8)
	for i in range(9, 15):
		dark[8 * n + (14 - i)] = at.call(i)
	for i in 8:
		dark[8 * n + (n - 1 - i)] = at.call(i)
	for i in range(8, 15):
		dark[(n - 15 + i) * n + 8] = at.call(i)
	dark[(n - 8) * n + 8] = 1

## How hard the code is to read (lower is better): long runs, 2x2 blocks, finder-like rows, too much dark.
static func _penalty(dark: PackedByteArray, n: int) -> int:
	var pen = 0
	for pass_ in 2:
		for a in n:
			var run = 0
			var last = -1
			var line = PackedByteArray()
			line.resize(n)
			for b in n:
				var c = dark[a * n + b] if pass_ == 0 else dark[b * n + a]
				line[b] = c
				if c == last:
					run += 1
					if run == 5:
						pen += 3
					elif run > 5:
						pen += 1
				else:
					last = c
					run = 1
			for b in n - 6:                       # 1 0 1 1 1 0 1 with four light ones on a side
				if line[b] == 1 and line[b + 1] == 0 and line[b + 2] == 1 and line[b + 3] == 1 and line[b + 4] == 1 and line[b + 5] == 0 and line[b + 6] == 1:
					var before = true
					var after = true
					for k in range(1, 5):
						if b - k >= 0 and line[b - k] == 1:
							before = false
						if b + 6 + k < n and line[b + 6 + k] == 1:
							after = false
					if before or after:
						pen += 40
	for y in n - 1:
		for x in n - 1:
			var c = dark[y * n + x]
			if c == dark[y * n + x + 1] and c == dark[(y + 1) * n + x] and c == dark[(y + 1) * n + x + 1]:
				pen += 3
	var count = 0
	for c in dark:
		count += c
	var total = n * n
	var k_ = int(absf(count * 20.0 - total * 10.0) / total)   # (each 5 % away from half: 10)
	pen += k_ * 10
	return pen
