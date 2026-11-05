extends RefCounted
## Voltline art: a 5x7 pixel font and generated room textures. No image files are used.

const GLYPHS := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], " ": [0, 0, 0, 0, 0, 0, 0], ".": [0, 0, 0, 0, 0, 12, 12],
	",": [0, 0, 0, 0, 12, 4, 8], ":": [0, 12, 12, 0, 12, 12, 0], "!": [4, 4, 4, 4, 4, 0, 4],
	"?": [14, 17, 1, 2, 4, 0, 4], "-": [0, 0, 0, 31, 0, 0, 0], "+": [0, 4, 4, 31, 4, 4, 0],
	"/": [1, 1, 2, 4, 8, 16, 16], "'": [4, 4, 8, 0, 0, 0, 0], "(": [2, 4, 8, 8, 8, 4, 2],
	")": [8, 4, 2, 2, 2, 4, 8], ">": [8, 4, 2, 1, 2, 4, 8], "<": [2, 4, 8, 16, 8, 4, 2],
	"%": [24, 25, 2, 4, 8, 19, 3], "*": [0, 4, 21, 14, 21, 4, 0], "=": [0, 0, 31, 0, 31, 0, 0],
	"#": [10, 10, 31, 10, 31, 10, 10], "_": [0, 0, 0, 0, 0, 0, 31], "|": [4, 4, 4, 4, 4, 4, 4],
	"^": [4, 14, 21, 4, 4, 4, 4], "~": [4, 4, 4, 4, 21, 14, 4], "{": [0, 4, 8, 31, 8, 4, 0],
	"}": [0, 4, 2, 31, 2, 4, 0], "@": [0, 10, 31, 31, 14, 4, 0], "&": [12, 18, 20, 8, 21, 18, 13],
}

# theme palettes: bg top, bg bottom, wall, wall dark, wall light, accent, pipe, glow
const PAL := [
	[Color("#0b1f2a"), Color("#06121a"), Color("#2b4a57"), Color("#162a33"), Color("#6fb7c4"), Color("#4fe3d6"), Color("#1c3540"), Color("#4fe3d6")],
	[Color("#21160e"), Color("#110b07"), Color("#4a3a2c"), Color("#271d15"), Color("#c99a5b"), Color("#ffb347"), Color("#33261b"), Color("#ffb347")],
	[Color("#0f1d10"), Color("#070e08"), Color("#33452e"), Color("#18231a"), Color("#8fc27a"), Color("#a6ff5e"), Color("#1d2c1d"), Color("#a6ff5e")],
	[Color("#1d0b1f"), Color("#0d050f"), Color("#4a2a4f"), Color("#231327"), Color("#d38bd6"), Color("#ff4fa3"), Color("#2c1730"), Color("#ff4fa3")],
]

static var _font: ImageTexture = null
static var _index := {}

static func font() -> ImageTexture:
	if _font != null:
		return _font
	var keys := GLYPHS.keys()
	var img := Image.create(keys.size() * 6, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in keys.size():
		var rows: Array = GLYPHS[keys[i]]
		_index[keys[i]] = i
		for y in 7:
			var bits: int = rows[y]
			for x in 5:
				if bits & (1 << (4 - x)):
					img.set_pixel(i * 6 + x, y, Color.WHITE)
	_font = ImageTexture.create_from_image(img)
	return _font

static func text_w(s: String, sc: int = 1) -> int:
	return maxi(0, s.length() * 6 * sc - sc)

static func text(ci: CanvasItem, s: String, p: Vector2, col: Color, sc: int = 1, shadow: bool = true) -> void:
	var tex := font()
	var up := s.to_upper()
	var x := floorf(p.x)
	var y := floorf(p.y)
	for pass_i in (2 if shadow else 1):
		var c := col
		var off := Vector2.ZERO
		if shadow and pass_i == 0:
			c = Color(0, 0, 0, col.a * 0.75)
			off = Vector2(sc, sc)
		for i in up.length():
			var ch := up[i]
			if ch == " ":
				continue
			var gi: int = _index.get(ch, _index["?"])
			ci.draw_texture_rect_region(tex, Rect2(Vector2(x + i * 6 * sc, y) + off, Vector2(5 * sc, 7 * sc)), Rect2(gi * 6, 0, 5, 7), c)

static func text_c(ci: CanvasItem, s: String, cx: float, y: float, col: Color, sc: int = 1, shadow: bool = true) -> void:
	text(ci, s, Vector2(floorf(cx - text_w(s, sc) / 2.0), y), col, sc, shadow)

static func _noise_tile(base: Color, dark: Color, light: Color, rng: RandomNumberGenerator, variant: int) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for i in 26:
		var x := rng.randi_range(0, 15)
		var y := rng.randi_range(0, 15)
		img.set_pixel(x, y, base.lerp(dark if rng.randf() < 0.6 else light, 0.25))
	# panel seams
	img.fill_rect(Rect2i(0, 15, 16, 1), dark)
	img.fill_rect(Rect2i(15, 0, 1, 16), dark)
	if variant == 1:
		img.fill_rect(Rect2i(0, 7, 15, 1), base.darkened(0.25))
		img.set_pixel(3, 3, light.darkened(0.3))
		img.set_pixel(11, 11, light.darkened(0.3))
	elif variant == 2:
		img.fill_rect(Rect2i(4, 4, 7, 7), base.darkened(0.18))
		img.fill_rect(Rect2i(5, 5, 5, 1), dark)
		img.fill_rect(Rect2i(5, 7, 5, 1), dark)
		img.fill_rect(Rect2i(5, 9, 5, 1), dark)
	else:
		img.set_pixel(2, 2, light.darkened(0.2))
		img.set_pixel(13, 2, light.darkened(0.2))
		img.set_pixel(2, 13, light.darkened(0.2))
		img.set_pixel(13, 13, light.darkened(0.2))
	return img

static func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var hw := int(sqrt(float(r * r - dy * dy)))
		var yy := cy + dy
		if yy < 0 or yy >= img.get_height():
			continue
		var x0 := clampi(cx - hw, 0, img.get_width())
		var x1 := clampi(cx + hw, 0, img.get_width())
		if x1 > x0:
			img.fill_rect(Rect2i(x0, yy, x1 - x0, 1), col)

## Builds the static layer of a room (background, walls, catwalks, spikes) as one texture.
static func build_room(grid: PackedByteArray, w: int, h: int, theme: int, seed_v: int) -> ImageTexture:
	var P: Array = PAL[theme]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(w * 16, h * 16, false, Image.FORMAT_RGBA8)
	var bt: Color = P[0]
	var bb: Color = P[1]
	for y in h * 16:
		var c := bt.lerp(bb, float(y) / (h * 16))
		if (y / 2) % 2 == 0:
			c = c.lightened(0.012)
		img.fill_rect(Rect2i(0, y, w * 16, 1), c)
	var pipe: Color = P[6]
	var glow: Color = P[7]
	# distant machinery silhouettes
	for i in 3:
		var cx := rng.randi_range(40, w * 16 - 40)
		var cy := rng.randi_range(70, 200)
		var r := rng.randi_range(26, 48)
		_fill_circle(img, cx, cy, r, pipe.darkened(0.35))
		_fill_circle(img, cx, cy, r - 5, bt.lerp(pipe, 0.35))
		for k in 6:
			var a := k * PI / 3.0 + rng.randf()
			var ex := cx + int(cos(a) * (r - 8))
			var ey := cy + int(sin(a) * (r - 8))
			img.fill_rect(Rect2i(mini(cx, ex), mini(cy, ey), absi(ex - cx) + 2, absi(ey - cy) + 2), pipe.darkened(0.2))
		_fill_circle(img, cx, cy, 6, pipe)
	for i in 5:
		var px := rng.randi_range(0, w * 16 - 12)
		var pw := rng.randi_range(5, 10)
		img.fill_rect(Rect2i(px, 0, pw, h * 16), pipe)
		img.fill_rect(Rect2i(px + 1, 0, 1, h * 16), pipe.lightened(0.15))
		for j in range(rng.randi_range(10, 30), h * 16, rng.randi_range(40, 70)):
			img.fill_rect(Rect2i(px - 1, j, pw + 2, 3), pipe.lightened(0.08))
	for i in 3:
		var gy := rng.randi_range(30, h * 16 - 60)
		img.fill_rect(Rect2i(0, gy, w * 16, 4), pipe.darkened(0.1))
		for gx in range(0, w * 16, 12):
			img.fill_rect(Rect2i(gx, gy + 4, 2, 6), pipe.darkened(0.15))
	for i in 18:
		var lx := rng.randi_range(0, w * 16 - 2)
		var ly := rng.randi_range(0, h * 16 - 2)
		img.fill_rect(Rect2i(lx, ly, 2, 1), bt.blend(Color(glow, 0.3)))
	# tiles
	var base: Color = P[2]
	var dark: Color = P[3]
	var light: Color = P[4]
	var accent: Color = P[5]
	var tiles := [_noise_tile(base, dark, light, rng, 0), _noise_tile(base, dark, light, rng, 1), _noise_tile(base, dark, light, rng, 2)]
	var inner := _noise_tile(base.darkened(0.35), dark.darkened(0.3), base, rng, 0)
	var src := Rect2i(0, 0, 16, 16)
	for ty in h:
		for tx in w:
			var c := grid[ty * w + tx]
			var X := tx * 16
			var Y := ty * 16
			if c == 35: # '#'
				var up := _is_wall(grid, w, h, tx, ty - 1)
				var dn := _is_wall(grid, w, h, tx, ty + 1)
				var lf := _is_wall(grid, w, h, tx - 1, ty)
				var rt := _is_wall(grid, w, h, tx + 1, ty)
				if up and dn and lf and rt:
					img.blit_rect(inner, src, Vector2i(X, Y))
				else:
					img.blit_rect(tiles[(tx * 7 + ty * 13) % 3], src, Vector2i(X, Y))
				if not up:
					img.fill_rect(Rect2i(X, Y, 16, 2), light)
					img.fill_rect(Rect2i(X, Y + 2, 16, 1), dark)
					if theme == 1 and (tx % 3 == 0):
						img.fill_rect(Rect2i(X + 2, Y + 4, 4, 2), accent.darkened(0.2))
				if not dn:
					img.fill_rect(Rect2i(X, Y + 15, 16, 1), dark.darkened(0.4))
					if (tx + ty) % 4 == 0:
						img.fill_rect(Rect2i(X + 7, Y + 15, 2, 1), accent)
				if not lf:
					img.fill_rect(Rect2i(X, Y, 1, 16), light.darkened(0.2))
				if not rt:
					img.fill_rect(Rect2i(X + 15, Y, 1, 16), light.darkened(0.35))
			elif c == 45: # '-' catwalk
				img.fill_rect(Rect2i(X, Y, 16, 3), light)
				img.fill_rect(Rect2i(X, Y + 3, 16, 1), dark)
				img.fill_rect(Rect2i(X, Y + 7, 16, 1), pipe.lightened(0.1))
				for k in 4:
					img.fill_rect(Rect2i(X + k * 4, Y + 4, 1, 3), pipe.lightened(0.2))
			elif c == 94: # '^' spikes
				var down := _is_wall(grid, w, h, tx, ty - 1) and not _is_wall(grid, w, h, tx, ty + 1)
				img.fill_rect(Rect2i(X, (Y if down else Y + 13), 16, 3), dark)
				for k in 4:
					for r in 7:
						var hw := int((7 - r) / 2.0)
						var yy := (Y + 3 + r) if down else (Y + 12 - r)
						var col := accent.lerp(Color.WHITE, 0.35) if r > 4 else light.lerp(accent, 0.3)
						img.fill_rect(Rect2i(X + k * 4 + 2 - hw, yy, maxi(1, hw * 2), 1), col)
	return ImageTexture.create_from_image(img)

static func _is_wall(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	var c := grid[y * w + x]
	return c == 35
