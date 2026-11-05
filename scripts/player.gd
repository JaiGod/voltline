extends RefCounted
## VOLT-7, the courier robot. Tile-based kinematic controller with coyote time,
## jump buffering, variable jump height, double jump, wall-climb, dash and grapple.

const W := 10.0
const H := 14.0
const RUN := 112.0
const ACC_G := 1500.0
const ACC_A := 1050.0
const GRAV_UP := 900.0
const GRAV_DN := 1450.0
const MAX_FALL := 330.0
const JUMP_V := -290.0
const DJUMP_V := -262.0
const COYOTE := 0.1
const BUFFER := 0.13
const DASH_V := 320.0
const DASH_T := 0.18
const GRAPPLE_V := 310.0

var pos := Vector2()
var vel := Vector2()
var facing := 1
var on_ground := false
var was_ground := false
var coyote := 0.0
var jump_buf := 0.0
var air_jumps := 0
var dash_t := 0.0
var dash_cd := 0.0
var can_air_dash := true
var on_wall := 0
var climbing := false
var wall_lock := 0.0
var grapple_on := false
var grapple_pt := Vector2()
var grapple_t := 0.0
var last_anchor := Vector2(-999, -999)
var last_anchor_t := 0.0
var atk_t := 0.0
var atk_cd := 0.0
var atk_dir := Vector2.RIGHT
var shoot_t := 0.0
var hurt_t := 0.0
var hp := 5
var anim := 0.0
var safe_pos := Vector2()
var safe_t := 0.0
var land_t := 0.0
var ghost: Array = []

func center() -> Vector2:
	return pos + Vector2(W / 2.0, H / 2.0)

func rect() -> Rect2:
	return Rect2(pos, Vector2(W, H))

func reset_at(p: Vector2) -> void:
	pos = p
	vel = Vector2.ZERO
	grapple_on = false
	dash_t = 0.0
	atk_t = 0.0
	safe_pos = p

func step(g, dt: float) -> void:
	anim += dt
	var ix: float = g.axis_x()
	var iy: float = g.axis_y()
	if g.actp("jump"):
		jump_buf = BUFFER
	jump_buf = maxf(0.0, jump_buf - dt)
	coyote = maxf(0.0, coyote - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	atk_cd = maxf(0.0, atk_cd - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	wall_lock = maxf(0.0, wall_lock - dt)
	shoot_t = maxf(0.0, shoot_t - dt)
	land_t = maxf(0.0, land_t - dt)
	last_anchor_t = maxf(0.0, last_anchor_t - dt)
	if ghost.size() > 0:
		for gh in ghost:
			gh.a -= dt * 3.0
		ghost = ghost.filter(func(gh): return gh.a > 0.0)

	_attack(g, iy)

	# --- grapple -----------------------------------------------------------
	if g.actp("grapple") and g.has_ab("grapple") and not grapple_on:
		var a = g.find_anchor(center(), facing, last_anchor if last_anchor_t > 0.0 else Vector2(-999, -999))
		if a != null:
			grapple_on = true
			grapple_pt = a
			grapple_t = 0.0
			dash_t = 0.0
			g.sfx("grapple")
		else:
			g.sfx("select", 0.6)
	if grapple_on:
		grapple_t += dt
		var d := grapple_pt - center()
		if g.actp("jump") or d.length() < 12.0 or grapple_t > 0.9:
			last_anchor = grapple_pt
			last_anchor_t = 0.7
		if g.actp("jump"):
			grapple_on = false
			vel = Vector2(d.normalized().x * 150.0, JUMP_V)
			jump_buf = 0.0
			_refresh(g)
			g.sfx("jump")
		elif d.length() < 12.0 or grapple_t > 0.9:
			grapple_on = false
			var dir := d.normalized() if d.length() > 0.1 else Vector2(facing, 0)
			vel = Vector2(dir.x * 250.0, minf(dir.y * 200.0, 0.0) - 170.0)
			_refresh(g)
		else:
			vel = d.normalized() * GRAPPLE_V
			if absf(vel.x) > 1.0:
				facing = 1 if vel.x > 0 else -1
			var hit := _move(g, dt)
			if hit:
				grapple_on = false
				vel *= 0.3
		_after_move(g)
		return

	# --- dash ---------------------------------------------------------------
	if g.actp("dash") and g.has_ab("dash") and dash_cd <= 0.0 and (on_ground or can_air_dash):
		if ix != 0.0:
			facing = 1 if ix > 0 else -1
		dash_t = DASH_T
		dash_cd = 0.42
		if not on_ground:
			can_air_dash = false
		g.sfx("dash")
		g.shake(1.5)
	if dash_t > 0.0:
		dash_t -= dt
		vel = Vector2(facing * DASH_V, 0.0)
		ghost.append({"p": pos, "f": facing, "a": 0.6})
		g.dash_break(Rect2(pos + Vector2(facing * 3.0, 0), Vector2(W, H)))
		var hit := _move(g, dt)
		if hit:
			dash_t = 0.0
		if dash_t <= 0.0:
			vel.x = facing * RUN
		if jump_buf > 0.0 and (on_ground or coyote > 0.0):
			dash_t = 0.0
		else:
			_after_move(g)
			return

	# --- run ----------------------------------------------------------------
	var target := ix * RUN
	var acc := ACC_G if on_ground else ACC_A
	if wall_lock > 0.0:
		acc *= 0.25
	vel.x = move_toward(vel.x, target, acc * dt)
	if ix != 0.0 and atk_t <= 0.0:
		facing = 1 if ix > 0 else -1

	# --- walls --------------------------------------------------------------
	on_wall = 0
	climbing = false
	if not on_ground and g.has_ab("climb"):
		if g.rect_solid(Rect2(pos + Vector2(-1.5, 2), Vector2(1, H - 4))):
			on_wall = -1
		elif g.rect_solid(Rect2(pos + Vector2(W + 0.5, 2), Vector2(1, H - 4))):
			on_wall = 1
		if on_wall != 0 and wall_lock <= 0.0 and (ix == on_wall or (iy < 0.0 and ix != -on_wall)):
			climbing = true
			facing = on_wall

	# --- jump ---------------------------------------------------------------
	if jump_buf > 0.0:
		if on_ground or coyote > 0.0:
			vel.y = JUMP_V
			on_ground = false
			coyote = 0.0
			jump_buf = 0.0
			g.sfx("jump")
			g.burst(pos + Vector2(W / 2.0, H), 5, Color("#cfd8e3"), 50.0)
		elif on_wall != 0:
			vel = Vector2(-on_wall * 175.0, -275.0)
			facing = -on_wall
			wall_lock = 0.16
			jump_buf = 0.0
			climbing = false
			g.sfx("jump", 1.15)
			g.burst(pos + Vector2(W / 2.0 + on_wall * 5.0, H / 2.0), 6, Color("#cfd8e3"), 60.0)
		elif air_jumps > 0:
			vel.y = DJUMP_V
			air_jumps -= 1
			jump_buf = 0.0
			g.sfx("djump")
			g.ring(pos + Vector2(W / 2.0, H), Color("#5ef2ff"))

	# --- gravity ------------------------------------------------------------
	if climbing:
		if iy < 0.0:
			vel.y = -75.0
		elif iy > 0.0:
			vel.y = 110.0
		else:
			vel.y = 0.0
		vel.x = on_wall * 10.0
	else:
		var gv := GRAV_UP if (vel.y < 0.0 and g.act("jump")) else GRAV_DN
		if absf(vel.y) < 40.0 and g.act("jump"):
			gv *= 0.7  # apex hang
		vel.y = minf(vel.y + gv * dt, MAX_FALL)
	if g.act("down") and not on_ground and not climbing and vel.y > 0.0:
		vel.y = minf(vel.y + 300.0 * dt, MAX_FALL + 60.0)

	_move(g, dt)
	_after_move(g)

func _refresh(g) -> void:
	air_jumps = 1 if g.has_ab("dj") else 0
	can_air_dash = true

func _after_move(g) -> void:
	if on_ground:
		if not was_ground:
			land_t = 0.12
			g.sfx("land")
			if vel.y >= 0.0:
				g.burst(pos + Vector2(W / 2.0, H), 3, Color("#9aa7b8"), 30.0)
		coyote = COYOTE
		_refresh(g)
		safe_t += 1.0 / 60.0
		if safe_t > 0.25 and g.safe_spot(rect()):
			safe_pos = pos
	else:
		safe_t = 0.0
	was_ground = on_ground
	if g.rect_has_spikes(Rect2(pos + Vector2(2, 3), Vector2(W - 4, H - 4))):
		g.player_spiked()

## returns true if a wall/floor was hit
func _move(g, dt: float) -> bool:
	var hit := false
	# X axis
	var dx := vel.x * dt
	pos.x += dx
	if dx > 0.0:
		var tx := int(floor((pos.x + W - 0.01) / 16.0))
		if g.col_solid(tx, pos.y, H):
			pos.x = tx * 16.0 - W
			vel.x = 0.0
			hit = true
	elif dx < 0.0:
		var tx := int(floor(pos.x / 16.0))
		if g.col_solid(tx, pos.y, H):
			pos.x = (tx + 1) * 16.0
			vel.x = 0.0
			hit = true
	# Y axis
	var prev_bottom := pos.y + H
	var dy := vel.y * dt
	pos.y += dy
	on_ground = false
	if dy > 0.0:
		var ty := int(floor((pos.y + H - 0.01) / 16.0))
		var dropping: bool = g.act("down") and g.act("jump")
		if g.row_solid(ty, pos.x, W) or (not dropping and prev_bottom <= ty * 16.0 + 0.01 and g.row_oneway(ty, pos.x, W)):
			pos.y = ty * 16.0 - H
			vel.y = 0.0
			on_ground = true
			hit = true
	elif dy < 0.0:
		var ty := int(floor(pos.y / 16.0))
		if g.row_solid(ty, pos.x, W):
			pos.y = (ty + 1) * 16.0
			vel.y = 0.0
			hit = true
	if dy == 0.0 and not on_ground:
		# resting check
		var ty2 := int(floor((pos.y + H + 0.5) / 16.0))
		if g.row_solid(ty2, pos.x, W) or (absf(pos.y + H - ty2 * 16.0) < 0.6 and g.row_oneway(ty2, pos.x, W)):
			on_ground = true
	return hit

func _attack(g, iy: float) -> void:
	if g.actp("attack") and atk_cd <= 0.0:
		if g.weapon >= 2:
			var d := Vector2(facing, 0)
			if iy < 0.0:
				d = Vector2(0, -1)
			elif iy > 0.0 and not on_ground:
				d = Vector2(0, 1)
			g.fire_plasma(center() + d * 8.0 + Vector2(0, -1), d)
			atk_cd = 0.24
			shoot_t = 0.12
			atk_dir = d
			g.sfx("shoot")
		else:
			atk_t = 0.15
			atk_cd = 0.3
			atk_dir = Vector2(facing, 0)
			if iy < 0.0:
				atk_dir = Vector2(0, -1)
			elif iy > 0.0 and not on_ground:
				atk_dir = Vector2(0, 1)
			g.new_swing()
			g.sfx("whip" if g.weapon == 1 else "slash")
	if atk_t > 0.0:
		atk_t -= 1.0 / 60.0
		if g.player_melee(atk_rect(g), 3 if g.weapon == 1 else 2) and atk_dir.y > 0.0:
			vel.y = -250.0  # pogo bounce
			_refresh(g)

func atk_rect(g) -> Rect2:
	var c := center()
	var reach := 46.0 if g.weapon == 1 else 24.0
	var thick := 14.0 if g.weapon == 1 else 20.0
	if atk_dir.y < 0.0:
		return Rect2(c.x - thick / 2.0, c.y - reach - 2.0, thick, reach)
	if atk_dir.y > 0.0:
		return Rect2(c.x - thick / 2.0, c.y, thick, reach * 0.8)
	if atk_dir.x > 0.0:
		return Rect2(c.x, c.y - thick / 2.0, reach + 2.0, thick)
	return Rect2(c.x - reach - 2.0, c.y - thick / 2.0, reach + 2.0, thick)

func hurt(g, dmg: int, from_x: float) -> void:
	if hurt_t > 0.0 or g.invincible:
		return
	hp -= dmg
	hurt_t = 1.1
	grapple_on = false
	dash_t = 0.0
	var sx := 1.0 if center().x >= from_x else -1.0
	vel = Vector2(sx * 160.0, -200.0)
	g.on_player_hurt()

# --- drawing ------------------------------------------------------------------

func _r(ci: CanvasItem, cx: float, by: float, f: int, x: float, y: float, w: float, h: float, col: Color) -> void:
	var xx := cx + (x if f == 1 else -x - w)
	ci.draw_rect(Rect2(floorf(xx), floorf(by + y), w, h), col)

func _body(ci: CanvasItem, p: Vector2, f: int, alpha: float, tint: Color, g) -> void:
	var cx := floorf(p.x + W / 2.0)
	var by := floorf(p.y + H)
	var body := Color("#dfe6ee", alpha) if tint.a == 0.0 else Color(tint, alpha)
	var dark := Color("#3a4456", alpha)
	var mid := Color("#9aa7b8", alpha)
	var parcel := Color("#ff9e3d", alpha) if tint.a == 0.0 else Color(tint, alpha)
	var visor := Color("#5ef2ff", alpha)
	var moving := absf(vel.x) > 10.0 and on_ground
	var bob := 0.0
	if on_ground and not moving:
		bob = 1.0 if fmod(anim, 1.2) > 0.6 else 0.0
	if land_t > 0.0:
		bob = 1.0
	# legs
	var la := 0.0
	var lb := 0.0
	if moving:
		var ph := fmod(anim * 12.0, TAU)
		la = 1.0 if sin(ph) > 0.0 else 0.0
		lb = 1.0 - la
	elif not on_ground:
		la = 1.0
		lb = 0.0
	_r(ci, cx, by, f, -3, -3 - la, 2, 3, dark)
	_r(ci, cx, by, f, 1, -3 - lb, 2, 3, dark)
	_r(ci, cx, by, f, -4, -1 - la, 3, 1, mid)
	_r(ci, cx, by, f, 1, -1 - lb, 3, 1, mid)
	# parcel backpack
	_r(ci, cx, by, f, -8, -11 + bob, 4, 7, parcel)
	_r(ci, cx, by, f, -8, -8 + bob, 4, 1, Color(parcel.darkened(0.35), alpha))
	_r(ci, cx, by, f, -7, -11 + bob, 1, 7, Color(parcel.lightened(0.25), alpha))
	# torso
	_r(ci, cx, by, f, -4, -9 + bob, 8, 6, body)
	_r(ci, cx, by, f, -4, -5 + bob, 8, 1, mid)
	_r(ci, cx, by, f, 0, -8 + bob, 2, 2, Color("#ffd23f", alpha))
	# head
	_r(ci, cx, by, f, -4, -16 + bob, 9, 7, body)
	_r(ci, cx, by, f, -4, -10 + bob, 9, 1, mid)
	_r(ci, cx, by, f, 0, -14 + bob, 5, 3, dark)
	var blink := fmod(anim, 3.0) < 0.12
	_r(ci, cx, by, f, 1, -13 + bob, 3, 1 if blink else 2, visor)
	# antenna
	_r(ci, cx, by, f, -2, -19 + bob, 1, 3, mid)
	var tip := Color("#ffd23f", alpha) if fmod(anim, 0.8) < 0.4 else Color("#ff6b3d", alpha)
	_r(ci, cx, by, f, -3, -20 + bob, 2, 2, tip)
	# arm / weapon
	if shoot_t > 0.0 or g.weapon >= 2:
		var ay := -7.0 + bob
		if atk_dir.y < 0.0 and shoot_t > 0.0:
			_r(ci, cx, by, f, 1, -16 + bob, 3, 6, Color("#c03dff", alpha))
		else:
			_r(ci, cx, by, f, 2, ay, 7, 3, Color("#7a3dff", alpha))
			_r(ci, cx, by, f, 8, ay, 1, 3, Color("#e9b8ff", alpha))
	elif atk_t <= 0.0:
		_r(ci, cx, by, f, 3, -7 + bob, 2, 3, mid)

func draw(ci: CanvasItem, g) -> void:
	for gh in ghost:
		_body(ci, gh.p, gh.f, gh.a * 0.5, Color("#5ef2ff"), g)
	if grapple_on:
		var c := center()
		var segs := 8
		var prev := c
		for i in range(1, segs + 1):
			var t := float(i) / segs
			var pt := c.lerp(grapple_pt, t) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * (1.0 - absf(t - 0.5) * 2.0)
			ci.draw_line(prev, pt, Color("#ffe066"), 1.0)
			prev = pt
		ci.draw_circle(grapple_pt, 3.0, Color("#fff6c0"))
	if hurt_t > 0.0 and fmod(hurt_t, 0.14) < 0.07:
		return
	_body(ci, pos, facing, 1.0, Color(0, 0, 0, 0), g)
	if atk_t > 0.0:
		_draw_swing(ci, g)
	if climbing:
		var wx := pos.x - 1.0 if on_wall < 0 else pos.x + W
		ci.draw_rect(Rect2(wx, pos.y + 4.0, 1, 3), Color("#ffd23f"))

func _draw_swing(ci: CanvasItem, g) -> void:
	var c := center()
	var prog := 1.0 - atk_t / 0.15
	var base_a := atk_dir.angle()
	if g.weapon == 1:
		# arc-whip: crackling lash
		var reach := 46.0 * clampf(prog * 1.6, 0.2, 1.0)
		var prev := c
		for i in range(1, 9):
			var t := i / 8.0
			var pt := c + atk_dir * reach * t + atk_dir.orthogonal() * sin(t * 9.0 + prog * 20.0) * 3.0 * t + Vector2(randf_range(-1, 1), randf_range(-1, 1))
			ci.draw_line(prev, pt, Color("#7ff9ff"), 2.0)
			ci.draw_line(prev, pt, Color("#ffffff"), 1.0)
			prev = pt
		ci.draw_circle(prev, 3.0, Color("#bffcff"))
	else:
		var a0 := base_a - 1.3 + prog * 0.4
		var a1 := base_a + 1.3 * (prog * 2.0 - 0.6)
		ci.draw_arc(c, 17.0, a0, a1, 10, Color("#5ef2ff", 0.8), 4.0)
		ci.draw_arc(c, 17.0, a0, a1, 10, Color("#ffffff"), 1.5)
