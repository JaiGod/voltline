extends Node2D
## Voltline - main game controller: states, rooms, collisions, combat, saving, input.

const Rooms = preload("res://scripts/rooms.gd")
const Art = preload("res://scripts/art.gd")
const Hud = preload("res://scripts/hud.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

const RW := 30
const RH := 17
const SAVE_PATH := "user://voltline_save.json"
const CFG_PATH := "user://voltline_cfg.json"
const SOLIDS := [35, 61, 37, 126, 88]  # # = % ~ X
const ITEM_TOTAL := 9

enum { TITLE, HOWTO, PLAY, PAUSE, MAP, DEAD, WIN }
var state := TITLE

var audio
var player
var cur := Vector2i(0, 1)
var grid := PackedByteArray()
var room_tex: ImageTexture
var tex_cache := {}
var enemies: Array = []
var bullets: Array = []
var parts: Array = []
var pickups: Array = []
var anchors: Array = []
var stations: Array = []
var hints: Array = []
var boss = null
var boss_lock := false
var prog := {}
var cfg := {"sound": true, "best": -1.0, "clears": 0}
var weapon := 0
var max_hp := 5
var world_off := Vector2()
var shake_amt := 0.0
var shake_off := Vector2()
var freeze := 0.0
var fade := 0.0
var banner_t := 0.0
var banner_title := ""
var banner_sub := ""
var msg := ""
var msg_t := 0.0
var room_title_t := 0.0
var invincible := false
var menu_sel := 0
var menu_rects: Array = []
var menu_click := -1
var tap_confirm := false
var touch_mode := false
var touch_buttons: Array = []
var touches := {}
var t_global := 0.0
var station_inside := false
var dead_t := 0.0
var win_t := 0.0
var win_pending := -1.0
var spike_cd := 0.0
var swing_hits := {}
var test_mode := false
var test_inp := {}
var test_prev := {}
var spawn_point := Vector2(51, 210)
var has_save := false

func _ready() -> void:
	randomize()
	_setup_input()
	audio = SfxScript.new()
	add_child(audio)
	player = PlayerScript.new()
	_load_cfg()
	audio.set_enabled(bool(cfg.sound))
	audio.play_music("explore")
	has_save = FileAccess.file_exists(SAVE_PATH)
	prog = _default_prog()
	load_room(Vector2i(0, 1))
	if OS.has_feature("web"):
		_demo_link.call_deferred()
	touch_mode = DisplayServer.is_touchscreen_available() and OS.has_feature("web") and (OS.has_feature("web_android") or OS.has_feature("web_ios"))

# --- input -------------------------------------------------------------------------------

func _add_action(a: String, keys: Array, pads: Array, axes: Array = []) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.35)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(a, e)
	for b in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(a, j)
	for ax in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[0]
		m.axis_value = ax[1]
		InputMap.action_add_event(a, m)

func _setup_input() -> void:
	_add_action("left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("jump", [KEY_Z, KEY_SPACE], [JOY_BUTTON_A])
	_add_action("attack", [KEY_X, KEY_J], [JOY_BUTTON_X])
	_add_action("dash", [KEY_C, KEY_SHIFT, KEY_K], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("grapple", [KEY_V, KEY_L], [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER])
	_add_action("map", [KEY_M, KEY_TAB], [JOY_BUTTON_BACK])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("accept", [KEY_ENTER, KEY_KP_ENTER], [])

func act(a: String) -> bool:
	if test_mode:
		return test_inp.get(a, false)
	return Input.is_action_pressed(a)

func actp(a: String) -> bool:
	if test_mode:
		return test_inp.get(a, false) and not test_prev.get(a, false)
	return Input.is_action_just_pressed(a)

func axis_x() -> float:
	return (1.0 if act("right") else 0.0) - (1.0 if act("left") else 0.0)

func axis_y() -> float:
	return (1.0 if act("down") else 0.0) - (1.0 if act("up") else 0.0)

func confirm_pressed() -> bool:
	var c := actp("jump") or actp("attack") or actp("accept") or tap_confirm
	tap_confirm = false
	return c

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		touch_mode = true
		var st := ev as InputEventScreenTouch
		if st.pressed:
			var a := _touch_hit(st.position)
			if a != "":
				touches[st.index] = a
				Input.action_press(a)
		else:
			if touches.has(st.index):
				Input.action_release(touches[st.index])
				touches.erase(st.index)
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		var a2 := _touch_hit(sd.position)
		var old: String = touches.get(sd.index, "")
		if old != a2 and (old == "" or old in ["left", "right", "up", "down"]):
			if old != "":
				Input.action_release(old)
				touches.erase(sd.index)
			if a2 != "" and a2 in ["left", "right", "up", "down"]:
				touches[sd.index] = a2
				Input.action_press(a2)
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if state == PLAY and touch_mode:
				return
			for i in menu_rects.size():
				var r: Rect2 = menu_rects[i]
				if r.grow(3).has_point(mb.position):
					menu_click = i
					menu_sel = i
					return
			if state in [HOWTO, DEAD, WIN, MAP]:
				tap_confirm = true
	elif ev is InputEventKey and ev.pressed:
		if not (ev as InputEventKey).echo and touches.is_empty():
			pass

func _touch_hit(p: Vector2) -> String:
	if state != PLAY:
		return ""
	var best := ""
	var bd := 1e9
	for b in touch_buttons:
		var d: float = p.distance_to(b.c)
		if d < b.r * 1.3 and d < bd:
			bd = d
			best = b.a
	return best

func release_touches() -> void:
	for k in touches:
		Input.action_release(touches[k])
	touches.clear()

# --- save data ---------------------------------------------------------------------------

func _default_prog() -> Dictionary:
	return {"ab": {"dj": false, "climb": false, "dash": false, "grapple": false}, "weapon": 0, "max_hp": 5,
		"got": {}, "bosses": {}, "visited": {}, "broken": {}, "save_room": "0,1", "save_pos": [spawn_point.x, spawn_point.y],
		"time": 0.0, "deaths": 0, "kills": 0}

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	return data if data is Dictionary else null

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func _load_cfg() -> void:
	var c = _read_json(CFG_PATH)
	if c != null:
		for k in c:
			cfg[k] = c[k]

func save_cfg() -> void:
	if not test_mode:
		_write_json(CFG_PATH, cfg)

func save_progress() -> void:
	prog.weapon = weapon
	prog.max_hp = max_hp
	if not test_mode:
		_write_json(SAVE_PATH, prog)
	has_save = true

func has_ab(n: String) -> bool:
	return bool(prog.ab.get(n, false))

func items_got() -> int:
	return prog.got.size()

# --- game flow ---------------------------------------------------------------------------

func new_game() -> void:
	prog = _default_prog()
	weapon = 0
	max_hp = 5
	save_progress()
	_enter_play(Vector2i(0, 1), spawn_point)
	banner("VOLT-7 ONLINE", "THE PLANT IS DARK. REACH THE REACTOR CORE.")

func continue_game() -> void:
	var p = _read_json(SAVE_PATH)
	if p == null:
		new_game()
		return
	prog = _default_prog()
	for k in p:
		prog[k] = p[k]
	weapon = int(prog.weapon)
	max_hp = int(prog.max_hp)
	_respawn()

func _respawn() -> void:
	var k: String = prog.save_room
	var parts_k := k.split(",")
	var sp: Array = prog.save_pos
	_enter_play(Vector2i(int(parts_k[0]), int(parts_k[1])), Vector2(float(sp[0]), float(sp[1])))

func _enter_play(room: Vector2i, p: Vector2) -> void:
	state = PLAY
	release_touches()
	load_room(room)
	player.reset_at(p)
	player.hp = max_hp
	player.hurt_t = 0.0
	player.facing = 1
	station_inside = true
	win_pending = -1.0
	fade = 1.0
	audio.play_music("explore")

func load_room(k: Vector2i) -> void:
	cur = k
	var key := Rooms.key(k)
	var R: Dictionary = Rooms.ROOMS[key]
	var rows: Array = R.map
	grid.resize(RW * RH)
	enemies.clear()
	bullets.clear()
	pickups.clear()
	anchors.clear()
	stations.clear()
	boss = null
	boss_lock = false
	var static_grid := PackedByteArray()
	static_grid.resize(RW * RH)
	for y in RH:
		var row: String = rows[y]
		for x in RW:
			var ch := row[x]
			var code := ch.unicode_at(0)
			var out := 46
			var center := Vector2(x * 16 + 8, y * 16 + 8)
			match ch:
				"#", "-", "^":
					out = code
				"=", "%", "~":
					out = 46 if prog.broken.has("%s:%d:%d" % [key, x, y]) else code
				"X":
					out = 46 if prog.bosses.has("F") else code
				"o":
					anchors.append(center)
				"S":
					stations.append(Vector2(x * 16, y * 16))
				"P":
					spawn_point = Vector2(x * 16 + 3, y * 16 + 2)
				"J", "C", "A", "G", "L", "h":
					var id := "%s:%s:%d:%d" % [key, ch, x, y]
					if not prog.got.has(id):
						pickups.append({"kind": ch, "p": center, "id": id, "t": randf() * 3.0})
				"b", "d", "t", "k", "x", "m":
					spawn_enemy(ch, center)
				"F", "R":
					if not prog.bosses.has(ch):
						boss = spawn_enemy(ch, center)
			grid[y * RW + x] = out
			static_grid[y * RW + x] = code if code in [35, 45, 94] else 46
	if not tex_cache.has(key):
		tex_cache[key] = Art.build_room(static_grid, RW, RH, Rooms.theme_of(k), hash(key) & 0xffff)
	room_tex = tex_cache[key]
	hints = R.hints
	prog.visited[key] = true
	room_title_t = 2.4

func spawn_enemy(tp: String, p: Vector2):
	var e = EnemyScript.new()
	e.setup(tp, p, self)
	enemies.append(e)
	return e

func count_type(tp: String) -> int:
	var n := 0
	for e in enemies:
		if e.type == tp and not e.dead:
			n += 1
	return n

# --- tiles ---------------------------------------------------------------------------------

func tile(tx: int, ty: int) -> int:
	if tx < 0 or tx >= RW or ty < 0 or ty >= RH:
		return 0
	return grid[ty * RW + tx]

func solid(tx: int, ty: int) -> bool:
	if tx < 0 or tx >= RW or ty < 0 or ty >= RH:
		if boss_lock:
			return true
		var d := Vector2i(-1 if tx < 0 else (1 if tx >= RW else 0), 0)
		if d.x == 0:
			d.y = -1 if ty < 0 else 1
		elif ty < 0 or ty >= RH:
			return true
		return not Rooms.ROOMS.has(Rooms.key(cur + d))
	return grid[ty * RW + tx] in SOLIDS

func solid_px(x: float, y: float) -> bool:
	return solid(int(floor(x / 16.0)), int(floor(y / 16.0)))

func oneway_px(x: float, y: float) -> bool:
	return tile(int(floor(x / 16.0)), int(floor(y / 16.0))) == 45

func oneway_px_land(x: float, fy: float, prev_bottom: float) -> bool:
	var ty := int(floor(fy / 16.0))
	return tile(int(floor(x / 16.0)), ty) == 45 and prev_bottom <= ty * 16.0 + 0.5

func col_solid(tx: int, y: float, h: float) -> bool:
	for ty in range(int(floor(y / 16.0)), int(floor((y + h - 0.01) / 16.0)) + 1):
		if solid(tx, ty):
			return true
	return false

func row_solid(ty: int, x: float, w: float) -> bool:
	for tx in range(int(floor(x / 16.0)), int(floor((x + w - 0.01) / 16.0)) + 1):
		if solid(tx, ty):
			return true
	return false

func row_oneway(ty: int, x: float, w: float) -> bool:
	for tx in range(int(floor(x / 16.0)), int(floor((x + w - 0.01) / 16.0)) + 1):
		if tile(tx, ty) == 45:
			return true
	return false

func rect_solid(r: Rect2) -> bool:
	for ty in range(int(floor(r.position.y / 16.0)), int(floor((r.end.y - 0.01) / 16.0)) + 1):
		for tx in range(int(floor(r.position.x / 16.0)), int(floor((r.end.x - 0.01) / 16.0)) + 1):
			if solid(tx, ty):
				return true
	return false

func rect_has_spikes(r: Rect2) -> bool:
	for ty in range(int(floor(r.position.y / 16.0)), int(floor((r.end.y - 0.01) / 16.0)) + 1):
		for tx in range(int(floor(r.position.x / 16.0)), int(floor((r.end.x - 0.01) / 16.0)) + 1):
			if tile(tx, ty) == 94:
				return true
	return false

func safe_spot(r: Rect2) -> bool:
	var ty := int(floor((r.end.y + 2.0) / 16.0))
	for tx in range(int(floor((r.position.x - 18.0) / 16.0)), int(floor((r.end.x + 18.0) / 16.0)) + 1):
		if tile(tx, ty) == 94 or tile(tx, ty - 1) == 94:
			return false
	return r.position.x > 4.0 and r.end.x < 476.0 and r.position.y > 4.0

func break_tiles(tx: int, ty: int) -> void:
	var code := tile(tx, ty)
	if code != 61 and code != 37 and code != 126:
		return
	var key := Rooms.key(cur)
	var stack := [Vector2i(tx, ty)]
	var col := Color("#5ab0ff") if code == 61 else (Color("#ff5a5a") if code == 37 else Color("#c99a5b"))
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		if tile(c.x, c.y) != code:
			continue
		grid[c.y * RW + c.x] = 46
		prog.broken["%s:%d:%d" % [key, c.x, c.y]] = true
		burst(Vector2(c.x * 16 + 8, c.y * 16 + 8), 8, col, 110.0)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	sfx("break_")
	shake(3.0)
	save_progress()

func dash_break(r: Rect2) -> void:
	for ty in range(int(floor(r.position.y / 16.0)), int(floor((r.end.y - 0.01) / 16.0)) + 1):
		for tx in range(int(floor(r.position.x / 16.0)), int(floor((r.end.x - 0.01) / 16.0)) + 1):
			if tile(tx, ty) == 126:
				break_tiles(tx, ty)

func find_anchor(c: Vector2, facing: int, exclude: Vector2 = Vector2(-999, -999)):
	var best = null
	var bs := 1e9
	for a in anchors:
		if (a as Vector2).distance_to(exclude) < 1.0:
			continue
		var d: Vector2 = a - c
		var dist := d.length()
		if dist > 136.0 or dist < 10.0:
			continue
		var score := dist
		if d.x * facing < -24.0:
			continue
		if d.y > 30.0:
			score += 70.0
		if score < bs:
			bs = score
			best = a
	return best

# --- effects -------------------------------------------------------------------------------

func sfx(n: String, pitch: float = 1.0) -> void:
	audio.play(n, pitch * randf_range(0.96, 1.04))

func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)

func burst(p: Vector2, n: int, col: Color, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * spd
		parts.append({"p": p, "v": Vector2.from_angle(a) * s + Vector2(0, -spd * 0.2), "l": randf_range(0.25, 0.6), "m": 0.6, "c": col, "s": 2.0 if randf() < 0.6 else 1.0, "g": 260.0, "k": 0})

func spark(p: Vector2, col: Color) -> void:
	parts.append({"p": p, "v": Vector2(randf_range(-30, 30), randf_range(-50, -10)), "l": 0.25, "m": 0.25, "c": col, "s": 1.0, "g": 100.0, "k": 0})

func ring(p: Vector2, col: Color) -> void:
	parts.append({"p": p, "v": Vector2.ZERO, "l": 0.3, "m": 0.3, "c": col, "s": 4.0, "g": 0.0, "k": 1})

func explosion(p: Vector2, size: int) -> void:
	burst(p, size, Color("#ffd23f"), 140.0)
	burst(p, size / 2, Color("#ff6b3d"), 90.0)
	parts.append({"p": p, "v": Vector2.ZERO, "l": 0.25, "m": 0.25, "c": Color("#fff6c0"), "s": float(size), "g": 0.0, "k": 2})
	sfx("explode", randf_range(0.8, 1.2))
	shake(3.0)

func banner(title: String, sub: String) -> void:
	banner_title = title
	banner_sub = sub
	banner_t = 3.4

func banner_small(s: String) -> void:
	msg = s
	msg_t = 2.6

func spawn_bullet(p: Vector2, v: Vector2, kind: String, dmg: int, r: float) -> void:
	bullets.append({"p": p, "v": v, "k": kind, "d": dmg, "r": r, "l": 5.0, "f": false})

func fire_plasma(p: Vector2, d: Vector2) -> void:
	bullets.append({"p": p, "v": d * 340.0, "k": "plasma", "d": 4, "r": 3.0, "l": 1.2, "f": true})
	burst(p, 3, Color("#e9b8ff"), 60.0)

func new_swing() -> void:
	swing_hits.clear()

# --- combat ----------------------------------------------------------------------------------

func player_melee(r: Rect2, dmg: int) -> bool:
	var hit := false
	for e in enemies:
		if e.dead or swing_hits.has(e):
			continue
		if r.intersects(e.rect()):
			swing_hits[e] = true
			var res: String = e.take_hit(self, dmg, false)
			if res == "block":
				sfx("clang")
				spark(e.pos + Vector2(e.facing * 8.0, 0), Color("#bffcff"))
				burst(e.pos + Vector2(e.facing * 8.0, 0), 4, Color("#4fe3d6"), 80.0)
				player.vel.x = -player.facing * 140.0
				hit = true
			elif res != "none":
				_on_enemy_hit(e, res)
				hit = true
	for ty in range(int(floor(r.position.y / 16.0)), int(floor((r.end.y - 0.01) / 16.0)) + 1):
		for tx in range(int(floor(r.position.x / 16.0)), int(floor((r.end.x - 0.01) / 16.0)) + 1):
			var c := tile(tx, ty)
			if c == 61 and weapon >= 1:
				break_tiles(tx, ty)
				hit = true
			elif (c == 61 or c == 37) and not swing_hits.has("wall"):
				swing_hits["wall"] = true
				sfx("clang")
				spark(Vector2(tx * 16 + 8, ty * 16 + 8), Color.WHITE)
				banner_small("TOO TOUGH FOR THIS WEAPON")
			elif c == 94 and player.atk_dir.y > 0.0:
				hit = true
	for b in bullets:
		if not b.f and (b.k == "bolt" or b.k == "orb") and r.grow(2).has_point(b.p):
			b.l = 0.0
			spark(b.p, Color.WHITE)
			sfx("clang", 1.3)
	return hit

func _on_enemy_hit(e, res: String) -> void:
	if res == "kill":
		sfx("kill")
		burst(e.pos, 14, Color("#ffd23f"), 120.0)
		burst(e.pos, 6, Color("#5ef2ff"), 80.0)
		shake(2.5)
		freeze = 0.05
		prog.kills = int(prog.kills) + 1
		if e.type == "m":
			explosion(e.pos, 8)
		elif randf() < 0.25 and not e.boss:
			pickups.append({"kind": "heal", "p": e.pos, "v": Vector2(randf_range(-40, 40), -120), "id": "", "t": 0.0, "life": 7.0})
	else:
		sfx("hit")
		burst(e.pos, 5, Color("#ffffff"), 90.0)
		freeze = 0.035
		if e.boss:
			shake(1.5)

func on_player_hurt() -> void:
	sfx("hurt")
	shake(5.0)
	freeze = 0.09
	burst(player.center(), 10, Color("#ff6b3d"), 120.0)
	if player.hp <= 0:
		_die()

func player_spiked() -> void:
	if spike_cd > 0.0 or state != PLAY:
		return
	spike_cd = 0.5
	if player.hurt_t <= 0.0 and not invincible:
		player.hp -= 1
		sfx("hurt")
		shake(4.0)
		burst(player.center(), 10, Color("#ff6b3d"), 120.0)
		if player.hp <= 0:
			_die()
			return
	player.reset_at(player.safe_pos)
	player.hurt_t = 1.0
	fade = 0.6
	freeze = 0.15

func _die() -> void:
	state = DEAD
	dead_t = 0.0
	prog.deaths = int(prog.deaths) + 1
	explosion(player.center(), 16)
	release_touches()
	save_progress()
	audio.play_music("")

func on_boss_defeated(e) -> void:
	prog.bosses[e.type] = true
	boss_lock = false
	boss = null
	explosion(e.pos, 24)
	shake(10.0)
	if e.type == "F":
		for i in grid.size():
			if grid[i] == 88:
				grid[i] = 46
		pickups.append({"kind": "W", "p": Vector2(e.pos.x, 216), "id": "boss:W", "t": 0.0})
		banner("THE FOREMAN IS DOWN", "THE FLOOR GATE HAS OPENED")
		audio.play_music("explore")
	else:
		win_pending = 2.8
		banner("CORE WARDEN DESTROYED", "REROUTING POWER...")
		audio.play_music("")
	save_progress()

func _collect(pk: Dictionary) -> void:
	var k: String = pk.kind
	if k == "heal":
		player.hp = mini(max_hp, player.hp + 1)
		sfx("heal")
		burst(pk.p, 6, Color("#7dff9a"), 60.0)
		return
	match k:
		"J": prog.ab.dj = true
		"C": prog.ab.climb = true
		"A": prog.ab.dash = true
		"G": prog.ab.grapple = true
		"W": weapon = maxi(weapon, 1)
		"L": weapon = 2
		"h":
			max_hp += 1
	player.hp = max_hp
	prog.got[pk.id] = true
	var info: Array = Rooms.ITEM_INFO[k]
	banner(info[0] + " ACQUIRED", info[1])
	sfx("pickup")
	freeze = 0.45
	shake(3.0)
	ring(pk.p, Color("#ffe066"))
	burst(pk.p, 24, Color("#ffe066"), 140.0)
	save_progress()

# --- main loop ---------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if not test_mode:
		game_step(dt)

func _process(_dt: float) -> void:
	queue_redraw()

func game_step(dt: float) -> void:
	t_global += dt
	match state:
		TITLE:
			_title_step()
		HOWTO:
			if confirm_pressed() or actp("pause"):
				state = TITLE
				menu_sel = 0
				sfx("select")
		PLAY:
			_play_step(dt)
		PAUSE:
			_pause_step()
		MAP:
			if actp("map") or actp("pause") or confirm_pressed():
				state = PLAY
		DEAD:
			dead_t += dt
			if dead_t > 1.0 and confirm_pressed():
				_respawn()
				sfx("save")
		WIN:
			win_t += dt
			if win_t > 2.0 and confirm_pressed():
				state = TITLE
				menu_sel = 0
				audio.play_music("explore")
	_update_parts(dt)
	shake_amt = move_toward(shake_amt, 0.0, 28.0 * dt)
	shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	fade = maxf(0.0, fade - dt * 3.0)
	banner_t = maxf(0.0, banner_t - dt)
	msg_t = maxf(0.0, msg_t - dt)
	room_title_t = maxf(0.0, room_title_t - dt)
	if test_mode:
		test_prev = test_inp.duplicate()

func menu_pick(n: int) -> int:
	if actp("up"):
		menu_sel = wrapi(menu_sel - 1, 0, n)
		sfx("select")
	if actp("down"):
		menu_sel = wrapi(menu_sel + 1, 0, n)
		sfx("select")
	if menu_click >= 0:
		var c := menu_click
		menu_click = -1
		sfx("confirm")
		return c
	if confirm_pressed():
		sfx("confirm")
		return menu_sel
	return -1

func title_items() -> Array:
	var items := []
	if has_save:
		items.append("CONTINUE")
	items.append("NEW GAME")
	items.append("HOW TO PLAY")
	items.append("SOUND: " + ("ON" if cfg.sound else "OFF"))
	return items

func _title_step() -> void:
	var items := title_items()
	menu_sel = clampi(menu_sel, 0, items.size() - 1)
	var c := menu_pick(items.size())
	if c < 0:
		return
	var label: String = items[c]
	if label == "CONTINUE":
		continue_game()
	elif label == "NEW GAME":
		new_game()
	elif label == "HOW TO PLAY":
		state = HOWTO
	else:
		toggle_sound()

func toggle_sound() -> void:
	cfg.sound = not bool(cfg.sound)
	audio.set_enabled(bool(cfg.sound))
	save_cfg()

func pause_items() -> Array:
	return ["RESUME", "MAP", "SOUND: " + ("ON" if cfg.sound else "OFF"), "QUIT TO TITLE"]

func _pause_step() -> void:
	if actp("pause"):
		state = PLAY
		return
	var c := menu_pick(4)
	match c:
		0: state = PLAY
		1: state = MAP
		2: toggle_sound()
		3:
			save_progress()
			state = TITLE
			menu_sel = 0
			audio.play_music("explore")

func _play_step(dt: float) -> void:
	if actp("pause"):
		state = PAUSE
		menu_sel = 0
		release_touches()
		return
	if actp("map"):
		state = MAP
		release_touches()
		return
	prog.time = float(prog.time) + dt
	spike_cd = maxf(0.0, spike_cd - dt)
	if win_pending > 0.0:
		win_pending -= dt
		if win_pending <= 0.0:
			_win()
			return
	if freeze > 0.0:
		freeze -= dt
		return
	player.step(self, dt)
	if state != PLAY:
		return
	_check_transition()
	# enemies
	var pr: Rect2 = player.rect().grow(-1.5)
	for e in enemies.duplicate():
		if e.dead:
			continue
		e.update(self, dt)
		if e.dead:
			continue
		if e.st != "dying" and e.st != "idle" and e.rect().grow(-1.0).intersects(pr):
			if e.type == "m":
				e.dead = true
				explosion(e.pos, 10)
				player.hurt(self, 1, e.pos.x)
			elif player.dash_t > 0.0 and not e.boss and has_ab("dash") and false:
				pass
			else:
				player.hurt(self, e.touch, e.pos.x)
		if state != PLAY:
			return
	enemies = enemies.filter(func(e): return not e.dead)
	_update_bullets(dt)
	_update_pickups(dt)
	_check_stations()
	_check_boss_trigger()

func _check_transition() -> void:
	var c: Vector2 = player.center()
	var d := Vector2i.ZERO
	if c.x < 0.0:
		d = Vector2i(-1, 0)
	elif c.x > 480.0:
		d = Vector2i(1, 0)
	elif c.y < 0.0:
		d = Vector2i(0, -1)
	elif c.y > 272.0:
		d = Vector2i(0, 1)
	if d == Vector2i.ZERO:
		return
	var nk := cur + d
	if not Rooms.ROOMS.has(Rooms.key(nk)) or boss_lock:
		player.pos.x = clampf(player.pos.x, 0.0, 470.0)
		player.pos.y = clampf(player.pos.y, 0.0, 258.0)
		return
	player.pos -= Vector2(d.x * 480.0, d.y * 272.0)
	if d.y < 0:
		player.vel.y = minf(player.vel.y, -340.0)
	load_room(nk)
	player.safe_pos = player.pos
	if d.y < 0:
		player.safe_pos = player.pos + Vector2(0, -30)
	station_inside = false
	fade = 0.35

func _check_stations() -> void:
	var inside := false
	for s in stations:
		var r := Rect2(s + Vector2(-2, -14), Vector2(20, 30))
		if r.intersects(player.rect()):
			inside = true
			if not station_inside:
				player.hp = max_hp
				prog.save_room = Rooms.key(cur)
				prog.save_pos = [s.x + 3.0, s.y + 2.0]
				save_progress()
				sfx("save")
				ring(s + Vector2(8, 4), Color("#7dff9a"))
				burst(s + Vector2(8, 0), 16, Color("#7dff9a"), 90.0)
				banner_small("POWER RESTORED - PROGRESS SAVED")
	station_inside = inside

func _check_boss_trigger() -> void:
	if boss == null or boss.st != "idle":
		return
	if player.center().x > 6.0 * 16.0 and player.center().x < 470.0:
		boss_lock = true
		boss.st = "intro"
		boss.st_t = 1.6
		sfx("boss")
		shake(6.0)
		if boss.type == "F":
			banner("THE FOREMAN", "DEMOLITION UNIT - STILL ON SHIFT")
		else:
			banner("CORE WARDEN", "GUARDIAN OF THE DEAD REACTOR")
		audio.play_music("boss")

func _update_bullets(dt: float) -> void:
	for b in bullets:
		b.l -= dt
		if b.l <= 0.0:
			continue
		if b.k == "debris":
			b.v.y = minf(b.v.y + 520.0 * dt, 360.0)
		b.p += b.v * dt
		var p: Vector2 = b.p
		if p.x < -10 or p.x > 490 or p.y < -10 or p.y > 282:
			b.l = 0.0
			continue
		if b.k == "wave":
			if solid_px(p.x + signf(b.v.x) * 4.0, p.y):
				b.l = 0.0
				burst(p, 4, Color("#c99a5b"), 60.0)
			elif randf() < 0.5:
				spark(p + Vector2(0, 4), Color("#ffb347"))
		elif solid_px(p.x, p.y):
			if b.f:
				var tx := int(floor(p.x / 16.0))
				var ty := int(floor(p.y / 16.0))
				if tile(tx, ty) in [61, 37, 126]:
					break_tiles(tx, ty)
			b.l = 0.0
			burst(p, 5, Color("#e9b8ff") if b.f else Color("#ffb347"), 70.0)
			if b.k == "debris":
				sfx("hit", 0.6)
			continue
		if b.f:
			for e in enemies:
				if not e.dead and e.rect().grow(b.r).has_point(p):
					var res: String = e.take_hit(self, b.d, true)
					if res != "none":
						_on_enemy_hit(e, res)
						b.l = 0.0
						break
		else:
			var pr: Rect2 = player.rect().grow(b.r - 2.0)
			if pr.has_point(p):
				player.hurt(self, b.d, p.x)
				if b.k != "wave":
					b.l = 0.0
	bullets = bullets.filter(func(b): return b.l > 0.0)

func _update_pickups(dt: float) -> void:
	var pr: Rect2 = player.rect().grow(3.0)
	for pk in pickups:
		pk.t += dt
		if pk.kind == "heal":
			pk.life -= dt
			pk.v.y = minf(pk.v.y + 500.0 * dt, 200.0)
			var np: Vector2 = pk.p + pk.v * dt
			if solid_px(np.x, np.y + 3.0) or oneway_px(np.x, np.y + 3.0):
				pk.v = Vector2.ZERO
			else:
				pk.p = np
		if pr.has_point(pk.p):
			pk.taken = true
			_collect(pk)
	pickups = pickups.filter(func(pk): return not pk.get("taken", false) and pk.get("life", 1.0) > 0.0)

func _update_parts(dt: float) -> void:
	for p in parts:
		p.l -= dt
		p.v.y += p.g * dt
		p.p += p.v * dt
	parts = parts.filter(func(p): return p.l > 0.0)
	if parts.size() > 600:
		parts = parts.slice(parts.size() - 600)

func _win() -> void:
	state = WIN
	win_t = 0.0
	var tm := float(prog.time)
	if float(cfg.best) < 0.0 or tm < float(cfg.best):
		cfg.best = tm
	cfg.clears = int(cfg.clears) + 1
	save_cfg()
	prog.cleared = true
	save_progress()
	audio.play_music("explore")
	sfx("save")

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#05060a"))
	var portrait := vp.y > 272.0 + 150.0
	var oy := floorf((vp.y - 272.0) / 2.0)
	if portrait:
		oy = floorf(clampf((vp.y - 272.0) * 0.22, 20.0, 120.0))
	world_off = Vector2(floorf((vp.x - 480.0) / 2.0), oy)
	Hud.layout_touch(self, vp, portrait)
	menu_rects.clear()
	if state == TITLE or state == HOWTO:
		Hud.draw_title(self, vp)
		if state == HOWTO:
			Hud.draw_howto(self, vp)
		return
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	# letterbox masks
	draw_rect(Rect2(0, 0, vp.x, world_off.y), Color("#05060a"))
	draw_rect(Rect2(0, world_off.y + 272.0, vp.x, vp.y), Color("#05060a"))
	draw_rect(Rect2(0, 0, world_off.x, vp.y), Color("#05060a"))
	draw_rect(Rect2(world_off.x + 480.0, 0, vp.x, vp.y), Color("#05060a"))
	if portrait:
		draw_rect(Rect2(world_off.x - 1, world_off.y - 1, 482, 274), Color("#2b4a57"), false, 1.0)
	Hud.draw_hud(self, vp)
	if state == PLAY and touch_mode:
		Hud.draw_touch(self)
	match state:
		PAUSE: Hud.draw_pause(self, vp)
		MAP: Hud.draw_map(self, vp)
		DEAD: Hud.draw_dead(self, vp)
		WIN: Hud.draw_win(self, vp)

func _draw_world() -> void:
	draw_set_transform(world_off + shake_off.round())
	draw_texture(room_tex, Vector2.ZERO)
	var t := t_global
	# live tiles
	for ty in RH:
		for tx in RW:
			var c := grid[ty * RW + tx]
			if c == 46 or c == 35 or c == 45 or c == 94:
				continue
			var X := tx * 16.0
			var Y := ty * 16.0
			match c:
				61:
					draw_rect(Rect2(X, Y, 16, 16), Color("#1565c0", 0.45))
					for i in 3:
						var lx := X + 2.0 + i * 5.0 + sin(t * 7.0 + tx + i * 2.0 + ty) * 1.5
						draw_rect(Rect2(floorf(lx), Y, 1, 16), Color("#90caf9", 0.55 + 0.4 * sin(t * 13.0 + i + ty)))
					draw_rect(Rect2(X, Y, 16, 1), Color("#e3f2fd", 0.5))
				37:
					draw_rect(Rect2(X, Y, 16, 16), Color("#5a1414"))
					draw_rect(Rect2(X + 1, Y + 1, 14, 14), Color("#8e2424"))
					draw_line(Vector2(X + 2, Y + 2), Vector2(X + 14, Y + 14), Color("#c94040"), 2.0)
					draw_line(Vector2(X + 14, Y + 2), Vector2(X + 2, Y + 14), Color("#c94040"), 2.0)
					draw_rect(Rect2(X + 7, Y + 7, 2, 2), Color("#ffb0b0"))
				126:
					draw_rect(Rect2(X, Y, 16, 16), Color("#5d4a3a"))
					draw_line(Vector2(X + 3, Y), Vector2(X + 8, Y + 7), Color("#1a120c"), 1.0)
					draw_line(Vector2(X + 8, Y + 7), Vector2(X + 5, Y + 16), Color("#1a120c"), 1.0)
					draw_line(Vector2(X + 8, Y + 7), Vector2(X + 14, Y + 9), Color("#1a120c"), 1.0)
					draw_rect(Rect2(X, Y, 16, 1), Color("#a08060"))
				88:
					draw_rect(Rect2(X, Y, 16, 16), Color("#1a1a1a"))
					for i in 4:
						var sx := X + fmod(i * 8.0 + t * 10.0, 32.0) - 8.0
						draw_colored_polygon(PackedVector2Array([Vector2(clampf(sx, X, X + 16), Y + 2), Vector2(clampf(sx + 4, X, X + 16), Y + 2), Vector2(clampf(sx + 8, X, X + 16), Y + 14), Vector2(clampf(sx + 4, X, X + 16), Y + 14)]), Color("#ffd23f"))
	# boss lock walls
	if boss_lock:
		var a := 0.5 + 0.3 * sin(t * 10.0)
		for side in [0.0, 478.0]:
			draw_rect(Rect2(side, 160, 2, 80), Color("#ff4fa3", a))
	# hints
	for hnt in hints:
		Art.text(self, hnt[2], Vector2(hnt[0] * 16.0, hnt[1] * 16.0), Color("#cfd8e3", 0.55), 1, false)
	# anchors
	var target = null
	if has_ab("grapple") and not player.grapple_on:
		target = find_anchor(player.center(), player.facing)
	for a in anchors:
		var glow := 0.6 + 0.4 * sin(t * 4.0 + a.x)
		draw_circle(a, 6.0, Color("#3a2a00"))
		draw_circle(a, 4.0, Color("#ffd23f", glow))
		draw_circle(a, 1.5, Color("#fff6c0"))
		if target != null and a == target:
			draw_arc(a, 10.0 + sin(t * 10.0), 0, TAU, 16, Color("#ffe066"), 1.0)
	# save stations
	var save_key := Rooms.key(cur)
	for s in stations:
		var active: bool = prog.save_room == save_key and absf(float(prog.save_pos[0]) - (s.x + 3.0)) < 1.0
		draw_rect(Rect2(s.x - 3, s.y + 12, 22, 4), Color("#2b3a2f"))
		draw_rect(Rect2(s.x - 2, s.y - 14, 3, 26), Color("#3a4a3f"))
		draw_rect(Rect2(s.x + 15, s.y - 14, 3, 26), Color("#3a4a3f"))
		draw_rect(Rect2(s.x - 3, s.y - 17, 22, 4), Color("#2b3a2f"))
		var gc := Color("#7dff9a") if active else Color("#3f8f55")
		draw_rect(Rect2(s.x - 2, s.y + 11, 20, 1), gc)
		draw_rect(Rect2(s.x - 2, s.y - 14, 20, 1), gc)
		if active:
			for i in 3:
				var yy: float = s.y + 10.0 - fmod(t * 20.0 + i * 8.0, 24.0)
				draw_rect(Rect2(s.x + 1, yy, 14, 1), Color("#7dff9a", 0.35))
		draw_circle(s + Vector2(8, -18), 2.0, gc if fmod(t, 1.0) < 0.6 else gc.darkened(0.5))
	# pickups
	for pk in pickups:
		Hud.draw_pickup(self, pk, t)
	for e in enemies:
		e.draw(self, self)
	if state != DEAD:
		player.draw(self, self)
	for b in bullets:
		Hud.draw_bullet(self, b, t)
	for p in parts:
		var a2: float = clampf(p.l / p.m, 0.0, 1.0)
		if p.k == 1:
			draw_arc(p.p, p.s + (1.0 - a2) * 14.0, 0, TAU, 18, Color(p.c, a2), 1.5)
		elif p.k == 2:
			draw_circle(p.p, p.s * (1.2 - a2 * 0.5), Color(p.c, a2 * 0.8))
		else:
			draw_rect(Rect2(floorf(p.p.x), floorf(p.p.y), p.s, p.s), Color(p.c, a2))
	for e in enemies:
		e.draw_fx(self, self)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, 480, 272), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))

## Share/demo links: ?room=4,2&w=2 jumps straight into a room with every ability (used for screenshots).
func _demo_link() -> void:
	var q := str(JavaScriptBridge.eval("location.search", true))
	if not q.contains("room="):
		return
	var args := {}
	for kv in q.trim_prefix("?").split("&"):
		var pair := kv.split("=")
		if pair.size() == 2:
			args[pair[0]] = pair[1].uri_decode()
	var r := str(args.get("room", "0,1")).split(",")
	if r.size() != 2 or not Rooms.ROOMS.has(Rooms.key(Vector2i(int(r[0]), int(r[1])))):
		return
	prog = _default_prog()
	give_all()
	weapon = clampi(int(args.get("w", "2")), 0, 2)
	max_hp = 8
	test_prev = {}
	debug_goto(Vector2i(int(r[0]), int(r[1])), Vector2(float(args.get("x", "40")), float(args.get("y", "226"))))
	audio.play_music("explore")

# --- test helpers ---------------------------------------------------------------------------------

func debug_goto(k: Vector2i, p: Vector2) -> void:
	state = PLAY
	player = PlayerScript.new()
	freeze = 0.0
	win_pending = -1.0
	spike_cd = 0.0
	load_room(k)
	player.reset_at(p)
	player.hp = max_hp

func give_all() -> void:
	for a in ["dj", "climb", "dash", "grapple"]:
		prog.ab[a] = true
	weapon = 2
