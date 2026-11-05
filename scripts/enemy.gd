extends RefCounted
## All Voltline enemies and both bosses. `type` is the room-map letter.
## b sparkbug, d volt drone, t turret, k spring hopper, x shield sentry, m static mine,
## F The Foreman (boss 1), R Core Warden (boss 2).

var type := "b"
var pos := Vector2()      # center
var vel := Vector2()
var w := 12.0
var h := 10.0
var hp := 3
var maxhp := 3
var t := 0.0
var st := "idle"
var st_t := 0.0
var facing := -1
var flash := 0.0
var dead := false
var boss := false
var home := Vector2()
var on_ground := false
var upside := false
var phase := 1
var aux := 0.0
var beam_x := 0.0
var touch := 1
var spin := 0.0

const STATS := {
	"b": [12, 8, 4], "d": [12, 10, 3], "t": [14, 10, 5], "k": [12, 12, 4],
	"x": [14, 16, 7], "m": [10, 10, 1], "F": [30, 30, 34], "R": [40, 40, 96],
}

func setup(tp: String, p: Vector2, g) -> void:
	type = tp
	var s: Array = STATS[tp]
	w = s[0]
	h = s[1]
	hp = s[2]
	maxhp = hp
	pos = p + Vector2(0, 8.0 - h / 2.0)  # stand on the tile's floor
	home = pos
	t = randf() * 3.0
	boss = tp == "F" or tp == "R"
	if tp == "t":
		if g.solid_px(p.x, p.y - 12.0):
			upside = true
			pos = p + Vector2(0, -8.0 + h / 2.0)
	if tp == "d" or tp == "m":
		pos = p
		home = p
	if tp == "R":
		pos = p
		home = p
	st = "idle" if boss else "go"
	st_t = randf_range(0.3, 1.2)

func rect() -> Rect2:
	return Rect2(pos - Vector2(w, h) / 2.0, Vector2(w, h))

func take_hit(g, dmg: int, plasma: bool) -> String:
	if dead or st == "dying" or (boss and st == "idle"):
		return "none"
	if type == "x" and not plasma:
		var pdx: float = g.player.center().x - pos.x
		if signf(pdx) == float(facing) and st != "stun":
			flash = 0.05
			return "block"
	if type == "F" and st == "stunned":
		dmg = int(dmg * 1.5)
	hp -= dmg
	flash = 0.12
	if not boss:
		var kx: float = signf(pos.x - g.player.center().x)
		if type != "t" and type != "m":
			vel.x = kx * 90.0
			if type == "d":
				vel.y = -40.0
	if hp <= 0:
		if boss:
			st = "dying"
			st_t = 2.4 if type == "R" else 1.6
			vel = Vector2.ZERO
		else:
			dead = true
		return "kill"
	return "hit"

func update(g, dt: float) -> void:
	t += dt
	flash = maxf(0.0, flash - dt)
	st_t -= dt
	match type:
		"b": _sparkbug(g, dt)
		"d": _drone(g, dt)
		"t": _turret(g, dt)
		"k": _hopper(g, dt)
		"x": _sentry(g, dt)
		"m": _mine(g, dt)
		"F": _foreman(g, dt)
		"R": _warden(g, dt)

# --- shared physics -------------------------------------------------------------

func _phys(g, dt: float, grav: float = 900.0) -> bool:
	var hit_wall := false
	vel.y = minf(vel.y + grav * dt, 380.0)
	var nx := pos.x + vel.x * dt
	var edge := nx + signf(vel.x) * w / 2.0
	if vel.x != 0.0 and (g.solid_px(edge, pos.y - h / 2.0 + 2.0) or g.solid_px(edge, pos.y + h / 2.0 - 2.0) or g.solid_px(edge, pos.y)):
		hit_wall = true
		vel.x = 0.0
	else:
		pos.x = nx
	pos.x = clampf(pos.x, w / 2.0, 480.0 - w / 2.0)
	var ny := pos.y + vel.y * dt
	on_ground = false
	if vel.y > 0.0:
		var fy := ny + h / 2.0
		if g.solid_px(pos.x - w / 2.0 + 1.0, fy) or g.solid_px(pos.x + w / 2.0 - 1.0, fy) or g.oneway_px_land(pos.x, fy, pos.y + h / 2.0):
			pos.y = floorf(fy / 16.0) * 16.0 - h / 2.0
			vel.y = 0.0
			on_ground = true
		else:
			pos.y = ny
	else:
		var hy := ny - h / 2.0
		if g.solid_px(pos.x - w / 2.0 + 1.0, hy) or g.solid_px(pos.x + w / 2.0 - 1.0, hy):
			pos.y = (floorf(hy / 16.0) + 1.0) * 16.0 + h / 2.0
			vel.y = 0.0
		else:
			pos.y = ny
	return hit_wall

func _ledge_ahead(g) -> bool:
	var fx := pos.x + facing * (w / 2.0 + 2.0)
	return not g.solid_px(fx, pos.y + h / 2.0 + 4.0) and not g.oneway_px(fx, pos.y + h / 2.0 + 4.0)

func _wall_ahead(g) -> bool:
	return g.solid_px(pos.x + facing * (w / 2.0 + 2.0), pos.y)

func _pdir(g) -> Vector2:
	return (g.player.center() - pos)

# --- regular enemies --------------------------------------------------------------

func _sparkbug(g, dt: float) -> void:
	if on_ground and (_ledge_ahead(g) or _wall_ahead(g)):
		facing = -facing
	vel.x = move_toward(vel.x, facing * 34.0, 400.0 * dt)
	_phys(g, dt)
	if randf() < dt * 3.0:
		g.spark(pos + Vector2(facing * 4.0, -h / 2.0 - 3.0), Color("#ffe066"))

func _drone(g, dt: float) -> void:
	var d := _pdir(g)
	var target := home + Vector2(sin(t * 1.3) * 18.0, sin(t * 2.1) * 8.0)
	var spd := 40.0
	if d.length() < 135.0:
		target = g.player.center() + Vector2(0, -6)
		spd = 62.0
	var want := (target - pos).limit_length(spd)
	vel = vel.move_toward(want, 160.0 * dt)
	var np := pos + vel * dt
	if not g.solid_px(np.x, pos.y):
		pos.x = np.x
	else:
		vel.x = -vel.x * 0.5
	if not g.solid_px(pos.x, np.y):
		pos.y = np.y
	else:
		vel.y = -vel.y * 0.5
	facing = 1 if d.x > 0.0 else -1

func _turret(g, dt: float) -> void:
	var d := _pdir(g)
	aux = lerp_angle(aux, d.angle(), 4.0 * dt)
	if st_t <= 0.0:
		if st == "go":
			if d.length() < 240.0 and ((upside and d.y > -10.0) or (not upside and d.y < 10.0)):
				st = "tell"
				st_t = 0.35
			else:
				st_t = 0.4
		else:
			st = "go"
			st_t = 1.9
			var dir := Vector2.from_angle(aux)
			g.spawn_bullet(pos + dir * 8.0, dir * 118.0, "bolt", 1, 3.0)
			g.sfx("bolt")

func _hopper(g, dt: float) -> void:
	var d := _pdir(g)
	if on_ground:
		vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
		facing = 1 if d.x > 0.0 else -1
		if st_t <= 0.0 and d.length() < 200.0:
			vel = Vector2(clampf(d.x * 1.3, -105.0, 105.0), -275.0)
			st_t = randf_range(0.8, 1.2)
			g.sfx("jump", 0.7)
	_phys(g, dt)

func _sentry(g, dt: float) -> void:
	var d := _pdir(g)
	if st == "stun":
		vel.x = move_toward(vel.x, 0.0, 500.0 * dt)
		if st_t <= 0.0:
			st = "go"
	elif st == "bash":
		vel.x = facing * 150.0
		if st_t <= 0.0:
			st = "go"
			st_t = 1.0
	else:
		if aux <= 0.0:
			facing = 1 if d.x > 0.0 else -1
			aux = 0.9
		aux -= dt
		var near := absf(d.y) < 34.0 and absf(d.x) < 170.0
		var sp := 26.0 if near else 14.0
		if near and absf(d.x) < 46.0 and st_t <= 0.0 and signf(d.x) == float(facing):
			st = "bash"
			st_t = 0.22
			g.sfx("dash", 0.6)
		if _ledge_ahead(g) or _wall_ahead(g):
			if not near:
				facing = -facing
			vel.x = 0.0
		else:
			vel.x = move_toward(vel.x, facing * sp, 300.0 * dt)
	if st == "bash" and (_ledge_ahead(g) or _wall_ahead(g)):
		vel.x = 0.0
		st = "go"
	_phys(g, dt)

func _mine(g, dt: float) -> void:
	var d := _pdir(g)
	var target := home + Vector2(0, sin(t * 2.0) * 4.0)
	if d.length() < 95.0:
		target = g.player.center()
	vel = vel.move_toward((target - pos).limit_length(42.0 if d.length() < 95.0 else 20.0), 120.0 * dt)
	pos += vel * dt
	spin += dt * (6.0 if d.length() < 95.0 else 2.0)

# --- bosses -------------------------------------------------------------------------

func _foreman(g, dt: float) -> void:
	var d := _pdir(g)
	if st == "idle":
		_phys(g, dt)
		return
	if st == "dying":
		if randf() < dt * 14.0:
			g.explosion(pos + Vector2(randf_range(-16, 16), randf_range(-16, 16)), 10)
		if st_t <= 0.0:
			dead = true
			g.on_boss_defeated(self)
		return
	if phase == 1 and hp <= maxhp / 2:
		phase = 2
		g.sfx("boss", 1.3)
		g.shake(5.0)
		g.banner_small("THE FOREMAN OVERCLOCKS!")
	var spd := 1.0 if phase == 1 else 1.3
	touch = 1
	match st:
		"intro":
			if st_t <= 0.0:
				_pick_foreman(g)
		"walk":
			facing = 1 if d.x > 0.0 else -1
			vel.x = move_toward(vel.x, facing * 58.0 * spd, 300.0 * dt)
			if st_t <= 0.0:
				_pick_foreman(g)
		"leap_tell":
			vel.x = 0.0
			if st_t <= 0.0:
				st = "leap"
				var tx: float = clampf(g.player.center().x, 48.0, 432.0)
				vel = Vector2((tx - pos.x) / 0.95, -410.0)
				on_ground = false
				g.sfx("jump", 0.5)
		"leap":
			if on_ground and vel.y >= 0.0:
				st = "recover"
				st_t = 0.65 / spd
				vel.x = 0.0
				g.shake(6.0)
				g.sfx("wave")
				var fy := pos.y + h / 2.0 - 6.0
				g.spawn_bullet(Vector2(pos.x - 16.0, fy), Vector2(-170.0 * spd, 0), "wave", 1, 6.0)
				g.spawn_bullet(Vector2(pos.x + 16.0, fy), Vector2(170.0 * spd, 0), "wave", 1, 6.0)
				g.burst(Vector2(pos.x, pos.y + h / 2.0), 14, Color("#c99a5b"), 120.0)
				if phase == 2:
					for i in 3:
						g.spawn_bullet(Vector2(randf_range(48.0, 432.0), 36.0), Vector2(0, 30.0), "debris", 1, 5.0)
		"charge_tell":
			vel.x = 0.0
			facing = 1 if d.x > 0.0 else -1
			if st_t <= 0.0:
				st = "charge"
				st_t = 3.0
				g.sfx("dash", 0.5)
		"charge":
			touch = 2
			vel.x = facing * 265.0 * (1.0 if phase == 1 else 1.15)
			if randf() < dt * 20.0:
				g.burst(Vector2(pos.x - facing * 14.0, pos.y + h / 2.0), 1, Color("#ffb347"), 40.0)
		"stunned":
			vel.x = move_toward(vel.x, 0.0, 400.0 * dt)
			if st_t <= 0.0:
				_pick_foreman(g)
		"recover":
			if st_t <= 0.0:
				_pick_foreman(g)
	var hit_wall := _phys(g, dt, 860.0)
	if st == "charge" and (hit_wall or st_t <= 0.0):
		st = "stunned"
		st_t = 1.5
		g.shake(7.0)
		g.sfx("explode", 1.4)
		var n := 2 if phase == 1 else 4
		for i in n:
			g.spawn_bullet(Vector2(randf_range(48.0, 432.0), 36.0), Vector2(0, 20.0), "debris", 1, 5.0)

func _pick_foreman(g) -> void:
	var r := randf()
	if r < 0.4:
		st = "leap_tell"
		st_t = 0.4 if phase == 1 else 0.28
	elif r < 0.75:
		st = "charge_tell"
		st_t = 0.6 if phase == 1 else 0.42
	else:
		st = "walk"
		st_t = randf_range(0.8, 1.4)

func _warden(g, dt: float) -> void:
	spin += dt * (1.0 if phase == 1 else 2.2)
	if st == "idle":
		pos = home + Vector2(0, sin(t * 2.0) * 3.0)
		return
	if st == "dying":
		pos += Vector2(randf_range(-1, 1), randf_range(-1, 1))
		if randf() < dt * 18.0:
			g.explosion(pos + Vector2(randf_range(-22, 22), randf_range(-22, 22)), 12)
		if st_t <= 0.0:
			dead = true
			g.on_boss_defeated(self)
		return
	if phase == 1 and hp <= maxhp / 2:
		phase = 2
		g.sfx("boss", 1.5)
		g.shake(6.0)
		g.banner_small("CORE CRITICAL - WARDEN UNSHACKLED")
		st = "move"
		st_t = 1.0
	var sp := 0.55 if phase == 1 else 0.8
	aux += dt * sp
	var target := Vector2(240.0 + sin(aux) * 150.0, 84.0 + sin(aux * 2.0) * 26.0)
	pos = pos.lerp(target, clampf(3.0 * dt, 0.0, 1.0))
	match st:
		"intro":
			if st_t <= 0.0:
				st = "move"
				st_t = 1.0
		"move":
			if st_t <= 0.0:
				_pick_warden(g)
		"beam_tell":
			if st_t <= 0.0:
				st = "beam"
				st_t = 0.5
				g.sfx("beam")
				g.shake(4.0)
		"beam":
			var pr: Rect2 = g.player.rect()
			if pr.position.x < beam_x + 9.0 and pr.end.x > beam_x - 9.0:
				g.player.hurt(g, 2, beam_x)
			if st_t <= 0.0:
				st = "move"
				st_t = 0.6

func _pick_warden(g) -> void:
	var opts := ["burst", "aim", "summon", "burst", "aim"]
	if phase == 2:
		opts += ["beam", "beam", "spiral"]
	var pick: String = opts[randi() % opts.size()]
	var d := _pdir(g).normalized()
	st = "move"
	st_t = 1.5 if phase == 1 else 1.05
	match pick:
		"burst":
			var n := 10 if phase == 1 else 14
			var off := randf() * TAU
			for i in n:
				var a := off + TAU * i / n
				g.spawn_bullet(pos + Vector2.from_angle(a) * 18.0, Vector2.from_angle(a) * 82.0, "orb", 1, 4.0)
			g.sfx("shoot", 0.6)
		"aim":
			var n2 := 3 if phase == 1 else 5
			for i in n2:
				var a2 := d.angle() + (i - (n2 - 1) / 2.0) * 0.22
				g.spawn_bullet(pos + d * 18.0, Vector2.from_angle(a2) * 140.0, "orb", 1, 4.0)
			g.sfx("bolt", 0.7)
		"summon":
			if g.count_type("d") < 2:
				g.spawn_enemy("d", pos + Vector2(-30, 10))
				g.spawn_enemy("d", pos + Vector2(30, 10))
				g.sfx("grapple", 0.5)
			else:
				_pick_warden(g)
		"spiral":
			for i in 18:
				var a3 := spin * 2.0 + i * 0.7
				g.spawn_bullet(pos + Vector2.from_angle(a3) * 18.0, Vector2.from_angle(a3) * (60.0 + i * 4.0), "orb", 1, 4.0)
			g.sfx("shoot", 0.5)
		"beam":
			st = "beam_tell"
			st_t = 0.85
			beam_x = clampf(g.player.center().x, 40.0, 440.0)

# --- drawing --------------------------------------------------------------------------

func _c(c: Color) -> Color:
	return Color(1, 1, 1, c.a) if flash > 0.0 else c

func _box(ci: CanvasItem, x: float, y: float, ww: float, hh: float, c: Color) -> void:
	ci.draw_rect(Rect2(floorf(pos.x + x), floorf(pos.y + y), ww, hh), _c(c))

func _fbox(ci: CanvasItem, x: float, y: float, ww: float, hh: float, c: Color) -> void:
	# mirrored by facing
	var xx := x if facing == 1 else -x - ww
	_box(ci, xx, y, ww, hh, c)

func draw(ci: CanvasItem, g) -> void:
	match type:
		"b":
			var leg := 1.0 if fmod(t * 10.0, 2.0) > 1.0 else 0.0
			_box(ci, -6, -2, 12, 5, Color("#3d5afe"))
			_box(ci, -5, -4, 10, 3, Color("#7c94ff"))
			_box(ci, -4, -3, 3, 1, Color("#c8d4ff"))
			_fbox(ci, 4, -2, 3, 3, Color("#ffe066"))
			_fbox(ci, 5, -6, 1, 3, Color("#ffe066"))
			_box(ci, -5, 3, 2, 1 + leg, Color("#1a237e"))
			_box(ci, -1, 3, 2, 2 - leg, Color("#1a237e"))
			_box(ci, 3, 3, 2, 1 + leg, Color("#1a237e"))
		"d":
			var bl := 1.0 if fmod(t * 20.0, 2.0) > 1.0 else 0.0
			_box(ci, -7 + bl, -6, 14 - bl * 2.0, 1, Color("#cfd8e3", 0.8))
			_box(ci, -1, -5, 2, 2, Color("#9aa7b8"))
			_box(ci, -6, -3, 12, 7, Color("#4a2a4f"))
			_box(ci, -5, -2, 10, 2, Color("#8a5a99"))
			_fbox(ci, 1, 0, 3, 2, Color("#ff4fa3"))
			_box(ci, -4, 4, 2, 2, Color("#5ef2ff"))
			_box(ci, 2, 4, 2, 2, Color("#5ef2ff"))
		"t":
			var s := -1.0 if upside else 1.0
			_box(ci, -7, (-1.0 if not upside else -4.0), 14, 5, Color("#4a3a2c"))
			_box(ci, -5, (-4.0 if not upside else 1.0), 10, 3, Color("#7a5f45"))
			var dir := Vector2.from_angle(aux)
			var base := pos + Vector2(0, -2.0 * s)
			var col := Color("#ff6b3d") if st == "tell" and fmod(t * 20.0, 2.0) > 1.0 else Color("#c99a5b")
			ci.draw_line(base, base + dir * 9.0, _c(col), 3.0)
			ci.draw_circle(base, 3.5, _c(Color("#271d15")))
			ci.draw_circle(base, 1.5, _c(Color("#ff6b3d")))
		"k":
			var squish := 2.0 if on_ground and st_t < 0.3 else 0.0
			_box(ci, -6, -6 + squish, 12, 10 - squish, Color("#2e7d32"))
			_box(ci, -5, -5 + squish, 10, 3, Color("#66bb6a"))
			_fbox(ci, 1, -3 + squish, 3, 2, Color("#e8ff8a"))
			_box(ci, -5, 4, 3, 2, Color("#9aa7b8"))
			_box(ci, 2, 4, 3, 2, Color("#9aa7b8"))
			_box(ci, -3, 5, 6, 1, Color("#cfd8e3"))
		"x":
			_box(ci, -6, -8, 12, 14, Color("#5d4037"))
			_box(ci, -5, -7, 10, 4, Color("#8d6e63"))
			_fbox(ci, 0, -5, 3, 2, Color("#ffeb3b"))
			_box(ci, -5, 6, 3, 2, Color("#3e2723"))
			_box(ci, 2, 6, 3, 2, Color("#3e2723"))
			var sc := Color("#4fe3d6") if flash <= 0.0 else Color.WHITE
			var sx := 6.0 if facing == 1 else -9.0
			ci.draw_rect(Rect2(floorf(pos.x + sx), floorf(pos.y - 9.0), 3, 17), Color(sc, 0.9))
			ci.draw_rect(Rect2(floorf(pos.x + sx + (1.0 if facing == 1 else 1.0)), floorf(pos.y - 7.0), 1, 13), Color(1, 1, 1, 0.6))
		"m":
			var pulse := 0.5 + 0.5 * sin(t * 8.0)
			ci.draw_circle(pos, 6.0, _c(Color("#3a2a00")))
			ci.draw_circle(pos, 4.0, _c(Color("#ffb300").lerp(Color("#fff59d"), pulse)))
			for i in 4:
				var a := spin + i * PI / 2.0
				ci.draw_line(pos + Vector2.from_angle(a) * 5.0, pos + Vector2.from_angle(a) * 8.0, _c(Color("#ffe066")), 1.0)
		"F":
			_draw_foreman(ci)
		"R":
			_draw_warden(ci)

func _draw_foreman(ci: CanvasItem) -> void:
	var tell := (st == "charge_tell" or st == "leap_tell") and fmod(t * 16.0, 2.0) > 1.0
	var body := Color("#ffb347") if not tell else Color("#ff6b3d")
	var crouch := 4.0 if st == "leap_tell" else 0.0
	if st == "stunned":
		crouch = 2.0
	# treads
	_box(ci, -15, 9, 30, 6, Color("#271d15"))
	for i in 5:
		_box(ci, -13 + i * 6 + fmod(t * 20.0 * absf(vel.x) / 100.0, 6.0) * 0.0, 11, 3, 2, Color("#6d5a45"))
	# torso
	_box(ci, -13, -8 + crouch, 26, 17 - crouch, body.darkened(0.25))
	_box(ci, -12, -7 + crouch, 24, 5, body)
	for i in 4:
		_box(ci, -11 + i * 6, 3, 3, 4, Color("#111111"))
		_box(ci, -8 + i * 6, 3, 3, 4, Color("#ffd23f"))
	# head/cab
	_fbox(ci, -4, -15 + crouch, 14, 8, Color("#4a3a2c"))
	_fbox(ci, 2, -13 + crouch, 7, 3, Color("#ff3d3d") if phase == 2 else Color("#5ef2ff"))
	# hammer arm
	var arm_y := -4.0 + crouch
	if st == "charge":
		arm_y = 0.0
	_fbox(ci, 12, arm_y, 6, 4, Color("#7a5f45"))
	_fbox(ci, 16, arm_y - 6, 6, 14, Color("#9aa7b8"))
	_fbox(ci, 16, arm_y - 6, 6, 2, Color("#dfe6ee"))
	if st == "stunned":
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			ci.draw_circle(pos + Vector2(cos(a) * 10.0, -22.0 + sin(a) * 3.0), 1.5, Color("#ffe066"))

func _draw_warden(ci: CanvasItem) -> void:
	var core := Color("#ff4fa3") if phase == 1 else Color("#ff2d2d")
	var r := 17.0
	# rotating shell segments
	for i in 6:
		var a := spin + i * TAU / 6.0
		var p := pos + Vector2.from_angle(a) * (r + 4.0)
		ci.draw_circle(p, 5.0, _c(Color("#4a2a4f")))
		ci.draw_circle(p, 3.0, _c(Color("#d38bd6")))
	ci.draw_circle(pos, r, _c(Color("#231327")))
	ci.draw_arc(pos, r, 0, TAU, 28, _c(Color("#d38bd6")), 2.0)
	var pulse := 0.5 + 0.5 * sin(t * (6.0 if phase == 1 else 12.0))
	ci.draw_circle(pos, 9.0 + pulse * 2.0, _c(core.darkened(0.3)))
	ci.draw_circle(pos, 6.0 + pulse, _c(core))
	ci.draw_circle(pos + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.8))

func draw_fx(ci: CanvasItem, g) -> void:
	# telegraphs drawn above everything
	if type == "R" and (st == "beam_tell" or st == "beam"):
		if st == "beam_tell":
			var a := 0.3 + 0.3 * sin(t * 30.0)
			ci.draw_line(Vector2(beam_x, 32), Vector2(beam_x, 240), Color(1, 0.3, 0.4, a), 1.0)
			ci.draw_rect(Rect2(beam_x - 9, 32, 18, 208), Color(1, 0.2, 0.4, 0.08))
		else:
			ci.draw_rect(Rect2(beam_x - 9, 32, 18, 208), Color("#ff4fa3", 0.75))
			ci.draw_rect(Rect2(beam_x - 4, 32, 8, 208), Color("#ffe0f0"))
	if type == "t" and st == "tell":
		var dir := Vector2.from_angle(aux)
		ci.draw_line(pos, pos + dir * 30.0, Color(1, 0.4, 0.2, 0.35), 1.0)
