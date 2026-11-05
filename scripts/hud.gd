extends RefCounted
## Voltline UI drawing: title, how-to, HUD, map, pause, death, victory and touch controls.

const Art = preload("res://scripts/art.gd")
const Rooms = preload("res://scripts/rooms.gd")

const C_TEXT := Color("#e8eef5")
const C_DIM := Color("#8a96a8")
const C_VOLT := Color("#ffd23f")
const C_CYAN := Color("#5ef2ff")
const C_PANEL := Color(0.03, 0.04, 0.07, 0.88)

static func fmt_time(s: float) -> String:
	var t := int(s)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

static func panel(ci: CanvasItem, r: Rect2, accent: Color = C_CYAN) -> void:
	ci.draw_rect(r, C_PANEL)
	ci.draw_rect(r, Color(accent, 0.8), false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color(accent, 0.25), false, 1.0)

static func menu(g, items: Array, cx: float, y: float, sc: int = 2, gap: float = 20.0) -> void:
	for i in items.size():
		var s: String = items[i]
		var sel: bool = i == g.menu_sel
		var w := Art.text_w(s, sc)
		var r := Rect2(cx - w / 2.0 - 10.0, y + i * gap - 4.0, w + 20.0, 7.0 * sc + 8.0)
		if sel:
			g.draw_rect(r, Color(C_VOLT, 0.14))
			g.draw_rect(r, Color(C_VOLT, 0.7), false, 1.0)
			var bx := r.position.x - 6.0 + sin(g.t_global * 8.0) * 2.0
			Art.text(g, ">", Vector2(bx, y + i * gap), C_VOLT, sc)
		Art.text_c(g, s, cx, y + i * gap, C_VOLT if sel else C_TEXT, sc)
		g.menu_rects.append(r)

static func _bolt(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, jag: float) -> void:
	var prev := a
	var n := 7
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t)
		if i < n:
			p += Vector2(randf_range(-jag, jag), randf_range(-jag, jag))
		ci.draw_line(prev, p, col, 1.0)
		prev = p

static func draw_title(g, vp: Vector2) -> void:
	var o: Vector2 = g.world_off
	g.draw_texture(g.room_tex, o, Color(0.45, 0.45, 0.55))
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.05, 0.55))
	var cx := vp.x / 2.0
	var ty := o.y + 34.0
	# electric arcs behind the logo
	if randf() < 0.5:
		for i in 2:
			var x0 := randf_range(cx - 140.0, cx + 140.0)
			_bolt(g, Vector2(x0, ty - 20.0), Vector2(x0 + randf_range(-40, 40), ty + 60.0), Color(C_CYAN, 0.5), 6.0)
	var flick := 1.0 if fmod(g.t_global, 4.0) > 0.12 else 0.4
	Art.text_c(g, "VOLTLINE", cx + 2.0, ty + 2.0, Color(C_CYAN, 0.6 * flick), 6, false)
	Art.text_c(g, "VOLTLINE", cx, ty, Color(C_VOLT, flick), 6, false)
	g.draw_rect(Rect2(cx - 140.0, ty + 48.0, 280.0, 1.0), Color(C_CYAN, 0.5))
	Art.text_c(g, "A POWER PLANT ODYSSEY", cx, ty + 54.0, C_DIM, 1)
	# the hero, big
	g.draw_set_transform(Vector2(cx - 150.0, ty + 150.0), 0.0, Vector2(3, 3))
	g.player._body(g, Vector2(-5, -14), 1, 1.0, Color(0, 0, 0, 0), g)
	g.draw_set_transform(Vector2.ZERO)
	var items: Array = g.title_items()
	menu(g, items, cx + 30.0, ty + 78.0, 2, 22.0)
	var foot := "BEST CLEAR " + fmt_time(float(g.cfg.best)) if float(g.cfg.best) >= 0.0 else "MADE BY JAINEIL RANA (JAKING)"
	Art.text_c(g, foot, cx, minf(vp.y - 14.0, o.y + 258.0), C_DIM, 1)

static func draw_howto(g, vp: Vector2) -> void:
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var o: Vector2 = g.world_off
	var r := Rect2(o + Vector2(20, 10), Vector2(440, 252))
	panel(g, r)
	var x := r.position.x + 14.0
	var y := r.position.y + 12.0
	Art.text_c(g, "HOW TO PLAY", r.get_center().x, y, C_VOLT, 2)
	y += 24.0
	var lines := [
		["GOAL", "RESTORE THE GRID: REACH THE REACTOR CORE"],
		["", "AND DESTROY THE CORE WARDEN."],
		["MOVE", "ARROWS / WASD - D-PAD / STICK"],
		["JUMP", "Z / SPACE - (A)   HOLD FOR HEIGHT"],
		["ATTACK", "X / J - (X)   UP/DOWN TO AIM"],
		["DASH", "C / SHIFT / K - (B)"],
		["GRAPPLE", "V / L - (Y)   NEAR GLOWING ANCHORS"],
		["MAP", "M / TAB - (BACK)    PAUSE: ESC / P"],
		["", ""],
		["TIPS", "DOWN-ATTACK IN THE AIR TO POGO."],
		["", "SLASH ENEMY BOLTS TO DEFLECT THEM."],
		["", "STATIONS SAVE AND REFILL HEALTH."],
		["", "NEW ABILITIES OPEN OLD DOORS."],
	]
	for ln in lines:
		Art.text(g, ln[0], Vector2(x, y), C_CYAN, 1)
		Art.text(g, ln[1], Vector2(x + 66.0, y), C_TEXT, 1)
		y += 13.0
	Art.text_c(g, "TOUCH: ON-SCREEN BUTTONS APPEAR WHEN YOU TAP", r.get_center().x, r.end.y - 30.0, C_DIM, 1)
	Art.text_c(g, "PRESS JUMP OR TAP TO RETURN", r.get_center().x, r.end.y - 16.0, C_VOLT, 1)

static func draw_hud(g, vp: Vector2) -> void:
	var o: Vector2 = g.world_off
	var p = g.player
	# health cells
	for i in int(g.max_hp):
		var x := o.x + 8.0 + i * 10.0
		var y := o.y + 8.0
		g.draw_rect(Rect2(x, y, 8, 11), Color("#0a0d14"))
		g.draw_rect(Rect2(x + 2, y - 2, 4, 2), Color("#0a0d14"))
		var full: bool = i < p.hp
		var col := Color("#7dff9a") if p.hp > 2 else Color("#ff6b3d")
		if full:
			g.draw_rect(Rect2(x + 1, y + 1, 6, 9), col)
			g.draw_rect(Rect2(x + 1, y + 1, 2, 9), col.lightened(0.4))
		else:
			g.draw_rect(Rect2(x + 1, y + 1, 6, 9), Color("#1f2633"))
		g.draw_rect(Rect2(x, y, 8, 11), Color("#cfd8e3", 0.7), false, 1.0)
	# weapon + abilities
	var wn: String = ["BLADE", "ARC-WHIP", "PLASMA"][g.weapon]
	var wc: Color = [C_CYAN, Color("#bffcff"), Color("#e9b8ff")][g.weapon]
	Art.text(g, wn, Vector2(o.x + 472.0 - Art.text_w(wn), o.y + 8.0), wc)
	var abs_ := [["dj", "2J"], ["climb", "CL"], ["dash", "DA"], ["grapple", "GR"]]
	for i in 4:
		var has: bool = g.has_ab(abs_[i][0])
		var bx := o.x + 472.0 - (4 - i) * 19.0 + 2.0
		var by := o.y + 19.0
		g.draw_rect(Rect2(bx, by, 17, 10), Color(C_VOLT, 0.85) if has else Color("#1f2633", 0.8))
		Art.text(g, abs_[i][1], Vector2(bx + 3, by + 2), Color("#14100a") if has else Color("#4a5568"), 1, false)
	# room title
	if g.room_title_t > 0.0:
		var a := clampf(g.room_title_t, 0.0, 1.0)
		var nm: String = Rooms.ROOMS[Rooms.key(g.cur)].name
		Art.text_c(g, nm, o.x + 240.0, o.y + 34.0, Color(C_TEXT, a), 2)
		Art.text_c(g, "SECTOR " + Rooms.key(g.cur).replace(",", "-"), o.x + 240.0, o.y + 52.0, Color(C_DIM, a), 1)
	# boss bar
	if g.boss != null and g.boss.st != "idle":
		var b = g.boss
		var bw := 300.0
		var bx2 := o.x + 90.0
		var by2 := o.y + 254.0
		var nm2 := "THE FOREMAN" if b.type == "F" else "CORE WARDEN"
		Art.text(g, nm2, Vector2(bx2, by2 - 10.0), Color("#ff9ec8"))
		g.draw_rect(Rect2(bx2, by2, bw, 6), Color("#1a0a12"))
		g.draw_rect(Rect2(bx2, by2, bw * maxf(0.0, float(b.hp)) / b.maxhp, 6), Color("#ff4fa3") if b.phase == 1 else Color("#ff2d2d"))
		g.draw_rect(Rect2(bx2, by2, bw, 6), Color("#ffd6e8", 0.6), false, 1.0)
	# banner
	if g.banner_t > 0.0 and g.state == g.PLAY:
		var a2 := clampf(g.banner_t * 2.0, 0.0, 1.0)
		var tw := maxf(Art.text_w(g.banner_title, 2), Art.text_w(g.banner_sub)) + 30.0
		var r := Rect2(o.x + 240.0 - tw / 2.0, o.y + 72.0, tw, 40.0)
		g.draw_rect(r, Color(0.02, 0.03, 0.06, 0.85 * a2))
		g.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(C_VOLT, a2))
		g.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(C_VOLT, a2))
		Art.text_c(g, g.banner_title, r.get_center().x, r.position.y + 8.0, Color(C_VOLT, a2), 2)
		Art.text_c(g, g.banner_sub, r.get_center().x, r.position.y + 27.0, Color(C_TEXT, a2), 1)
	if g.msg_t > 0.0:
		var a3 := clampf(g.msg_t * 2.0, 0.0, 1.0)
		Art.text_c(g, g.msg, o.x + 240.0, o.y + 236.0, Color(C_CYAN, a3), 1)

static func draw_pickup(g, pk: Dictionary, t: float) -> void:
	var p: Vector2 = pk.p
	if pk.kind == "heal":
		if pk.get("life", 9.0) < 2.0 and fmod(t * 10.0, 2.0) < 1.0:
			return
		g.draw_rect(Rect2(p.x - 3, p.y - 4, 6, 8), Color("#0a0d14"))
		g.draw_rect(Rect2(p.x - 2, p.y - 3, 4, 6), Color("#7dff9a"))
		g.draw_rect(Rect2(p.x - 1, p.y - 5, 2, 1), Color("#cfd8e3"))
		return
	var bob := sin(pk.t * 3.0) * 2.0
	var c := p + Vector2(0, bob)
	var cols := {"J": C_CYAN, "C": C_VOLT, "A": Color("#ff4fa3"), "G": Color("#ffe066"), "W": Color("#bffcff"), "L": Color("#c08bff"), "h": Color("#7dff9a")}
	var col: Color = cols.get(pk.kind, C_TEXT)
	g.draw_circle(c, 11.0 + sin(pk.t * 5.0), Color(col, 0.12))
	g.draw_circle(c, 8.0, Color(0.05, 0.06, 0.1, 0.9))
	g.draw_arc(c, 8.0, pk.t * 2.0, pk.t * 2.0 + PI * 1.4, 12, col, 1.5)
	var labels := {"J": "2J", "C": "CL", "A": "DA", "G": "GR", "W": "~", "L": "*", "h": "+"}
	var lb: String = labels.get(pk.kind, "?")
	Art.text_c(g, lb, c.x + 0.5, c.y - 3.0, col, 1, false)
	if randf() < 0.15:
		g.spark(c + Vector2(randf_range(-8, 8), randf_range(-8, 8)), col)

static func draw_bullet(g, b: Dictionary, t: float) -> void:
	var p: Vector2 = b.p
	match b.k:
		"bolt":
			g.draw_circle(p, 4.0, Color("#ff6b3d", 0.35))
			g.draw_circle(p, 2.0, Color("#ffe0b0"))
		"orb":
			g.draw_circle(p, 5.5, Color("#ff4fa3", 0.35))
			g.draw_circle(p, 3.0, Color("#ff4fa3"))
			g.draw_circle(p, 1.5, Color.WHITE)
		"plasma":
			var d: Vector2 = b.v.normalized()
			g.draw_line(p - d * 9.0, p, Color("#c08bff", 0.5), 3.0)
			g.draw_circle(p, 4.0, Color("#c08bff", 0.45))
			g.draw_circle(p, 2.2, Color("#f4e8ff"))
		"wave":
			var hh := 12.0 + sin(t * 30.0) * 2.0
			var s := signf(b.v.x)
			g.draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * s, 6), p + Vector2(6 * s, 6), p + Vector2(0, 6 - hh)]), Color("#ffb347", 0.85))
			g.draw_colored_polygon(PackedVector2Array([p + Vector2(-3 * s, 6), p + Vector2(3 * s, 6), p + Vector2(0, 6 - hh * 0.6)]), Color("#fff1c0"))
		"debris":
			g.draw_rect(Rect2(p.x - 4, p.y - 4, 8, 8), Color("#6d5a45"))
			g.draw_rect(Rect2(p.x - 4, p.y - 4, 8, 2), Color("#a08a70"))

static func layout_touch(g, vp: Vector2, portrait: bool) -> void:
	g.touch_buttons.clear()
	var bl := []
	if portrait:
		var top: float = g.world_off.y + 272.0
		var cy := top + (vp.y - top) * 0.5 + 6.0
		var r := 30.0
		var lx := 96.0
		var rx := vp.x - 96.0
		bl = [["left", Vector2(lx - 50, cy), r, "{"], ["right", Vector2(lx + 50, cy), r, "}"],
			["up", Vector2(lx, cy - 50), r * 0.8, "^"], ["down", Vector2(lx, cy + 50), r * 0.8, "~"],
			["jump", Vector2(rx, cy + 46), r * 1.1, "JUMP"], ["attack", Vector2(rx - 56, cy), r, "ATK"],
			["dash", Vector2(rx + 56, cy), r, "DASH"], ["grapple", Vector2(rx, cy - 50), r * 0.9, "GRAB"],
			["pause", Vector2(vp.x - 26, top + 22), 16.0, "II"], ["map", Vector2(vp.x - 64, top + 22), 16.0, "MAP"]]
	else:
		var cy2 := vp.y - 46.0
		var r2 := 21.0
		bl = [["left", Vector2(34, cy2), r2, "{"], ["right", Vector2(86, cy2), r2, "}"],
			["up", Vector2(60, cy2 - 40), r2 * 0.75, "^"], ["down", Vector2(60, cy2 + 30), r2 * 0.65, "~"],
			["jump", Vector2(vp.x - 40, cy2 + 8), r2 * 1.1, "JMP"], ["attack", Vector2(vp.x - 90, cy2 + 8), r2, "ATK"],
			["dash", Vector2(vp.x - 62, cy2 - 38), r2 * 0.85, "DSH"], ["grapple", Vector2(vp.x - 110, cy2 - 34), r2 * 0.8, "GRB"],
			["pause", Vector2(vp.x / 2.0 + 20, vp.y - 14), 12.0, "II"], ["map", Vector2(vp.x / 2.0 - 20, vp.y - 14), 12.0, "M"]]
	for b in bl:
		g.touch_buttons.append({"a": b[0], "c": b[1], "r": b[2], "l": b[3]})

static func draw_touch(g) -> void:
	for b in g.touch_buttons:
		var on := Input.is_action_pressed(b.a)
		var c: Vector2 = b.c
		g.draw_circle(c, b.r, Color(1, 1, 1, 0.22 if on else 0.08))
		g.draw_arc(c, b.r, 0, TAU, 24, Color(C_CYAN, 0.65 if on else 0.35), 1.5)
		var sc := 2 if b.r >= 24.0 and (b.l as String).length() <= 4 else 1
		Art.text_c(g, b.l, c.x, c.y - 3.5 * sc, Color(C_TEXT, 0.9 if on else 0.6), sc, false)

static func draw_pause(g, vp: Vector2) -> void:
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	var o: Vector2 = g.world_off
	var r := Rect2(o + Vector2(140, 50), Vector2(200, 170))
	panel(g, r)
	Art.text_c(g, "PAUSED", r.get_center().x, r.position.y + 14.0, C_VOLT, 3)
	menu(g, g.pause_items(), r.get_center().x, r.position.y + 54.0, 1, 22.0)
	Art.text_c(g, "TIME " + fmt_time(float(g.prog.time)), r.get_center().x, r.end.y - 18.0, C_DIM, 1)

static func _room_open(rows: Array, d: Vector2i) -> bool:
	if d.x == 1:
		for y in 17:
			if rows[y][29] != "#":
				return true
	elif d.x == -1:
		for y in 17:
			if rows[y][0] != "#":
				return true
	elif d.y == 1:
		return (rows[16] as String).count("#") < 30
	elif d.y == -1:
		return (rows[0] as String).count("#") < 30
	return false

static func draw_map(g, vp: Vector2) -> void:
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.7))
	var o: Vector2 = g.world_off
	var r := Rect2(o + Vector2(14, 8), Vector2(452, 256))
	panel(g, r)
	Art.text_c(g, "PLANT SCHEMATIC", r.get_center().x, r.position.y + 10.0, C_VOLT, 2)
	var cw := 58.0
	var ch := 34.0
	var gap := 8.0
	var gx := r.get_center().x - (5 * cw + 4 * gap) / 2.0
	var gy := r.position.y + 32.0
	var visited: Dictionary = g.prog.visited
	for key in Rooms.ROOMS:
		var parts: PackedStringArray = (key as String).split(",")
		var v := Vector2i(int(parts[0]), int(parts[1]))
		var rows: Array = Rooms.ROOMS[key].map
		var cr := Rect2(gx + v.x * (cw + gap), gy + v.y * (ch + gap), cw, ch)
		var seen: bool = visited.has(key)
		var near := false
		if not seen:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nk := Rooms.key(v + d)
				if visited.has(nk) and _room_open(rows, d):
					near = true
		if not seen and not near:
			continue
		var pal: Array = Art.PAL[Rooms.theme_of(v)]
		if seen:
			g.draw_rect(cr, Color(pal[2], 0.9))
			g.draw_rect(cr, Color(pal[5], 0.8), false, 1.0)
			# connectors
			if _room_open(rows, Vector2i(1, 0)):
				g.draw_rect(Rect2(cr.end.x, cr.get_center().y + 6, gap, 5), Color(pal[4], 0.8))
			if _room_open(rows, Vector2i(0, 1)):
				g.draw_rect(Rect2(cr.get_center().x - 3, cr.end.y, 6, gap), Color(pal[4], 0.8))
			var nm: String = Rooms.ROOMS[key].name
			var short := nm.split(" ")[0].left(8)
			Art.text_c(g, short, cr.get_center().x, cr.position.y + 4.0, Color("#0a0d14"), 1, false)
			# icons
			var ix := cr.position.x + 4.0
			for ln in rows:
				if (ln as String).contains("S"):
					g.draw_rect(Rect2(ix, cr.end.y - 9, 5, 5), Color("#7dff9a"))
					ix += 8.0
					break
			var items_left := 0
			for y in 17:
				for x in 30:
					var c: String = rows[y][x]
					if c in ["J", "C", "A", "G", "L", "h"] and not g.prog.got.has("%s:%s:%d:%d" % [key, c, x, y]):
						items_left += 1
			if key == "4,0" and not g.prog.got.has("boss:W"):
				items_left += 1
			for i in items_left:
				g.draw_rect(Rect2(ix, cr.end.y - 9, 5, 5), C_VOLT)
				ix += 8.0
			var bt := "F" if key == "4,0" else ("R" if key == "4,3" else "")
			if bt != "" and not g.prog.bosses.has(bt):
				g.draw_circle(Vector2(cr.end.x - 7, cr.end.y - 7), 3.0, Color("#ff4fa3"))
		else:
			g.draw_rect(cr, Color(1, 1, 1, 0.25), false, 1.0)
			Art.text_c(g, "?", cr.get_center().x, cr.get_center().y - 3.0, C_DIM, 1, false)
		if v == g.cur and fmod(g.t_global, 0.6) < 0.4:
			var pp: Vector2 = g.player.center()
			g.draw_rect(Rect2(cr.position.x + pp.x / 480.0 * cw - 2, cr.position.y + pp.y / 272.0 * ch - 2, 4, 4), Color.WHITE)
	var sy := r.end.y - 42.0
	Art.text(g, "TIME " + fmt_time(float(g.prog.time)), Vector2(r.position.x + 14, sy), C_TEXT)
	Art.text(g, "ITEMS %d/%d" % [g.items_got(), g.ITEM_TOTAL], Vector2(r.position.x + 14, sy + 12), C_TEXT)
	Art.text(g, "DEATHS %d" % int(g.prog.deaths), Vector2(r.position.x + 14, sy + 24), C_TEXT)
	g.draw_rect(Rect2(r.position.x + 150, sy, 5, 5), Color("#7dff9a"))
	Art.text(g, "SAVE", Vector2(r.position.x + 160, sy), C_DIM)
	g.draw_rect(Rect2(r.position.x + 150, sy + 12, 5, 5), C_VOLT)
	Art.text(g, "ITEM", Vector2(r.position.x + 160, sy + 12), C_DIM)
	g.draw_circle(Vector2(r.position.x + 152.5, sy + 26.5), 3.0, Color("#ff4fa3"))
	Art.text(g, "BOSS", Vector2(r.position.x + 160, sy + 24), C_DIM)
	Art.text(g, "M / TAP TO CLOSE", Vector2(r.end.x - 14 - Art.text_w("M / TAP TO CLOSE"), sy + 24), C_DIM)

static func draw_dead(g, vp: Vector2) -> void:
	var a := clampf(g.dead_t * 1.5, 0.0, 0.75)
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.25, 0.0, 0.03, a))
	var o: Vector2 = g.world_off
	if g.dead_t > 0.4:
		var jit := Vector2(randf_range(-1, 1), 0) if fmod(g.t_global, 1.0) < 0.1 else Vector2.ZERO
		Art.text_c(g, "SYSTEM FAILURE", o.x + 240.0 + jit.x, o.y + 100.0, Color("#ff6b6b"), 3)
		Art.text_c(g, "VOLT-7 HAS LOST POWER", o.x + 240.0, o.y + 132.0, C_TEXT, 1)
	if g.dead_t > 1.0 and fmod(g.t_global, 1.0) < 0.7:
		Art.text_c(g, "PRESS JUMP / TAP TO REBOOT AT LAST STATION", o.x + 240.0, o.y + 160.0, C_VOLT, 1)

static func draw_win(g, vp: Vector2) -> void:
	var a := clampf(g.win_t, 0.0, 0.85)
	g.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, a))
	var o: Vector2 = g.world_off
	var cx := o.x + 240.0
	for i in 3:
		if randf() < 0.4:
			var x0 := randf_range(o.x + 20, o.x + 460)
			_bolt(g, Vector2(x0, o.y), Vector2(x0 + randf_range(-30, 30), o.y + 60), Color(C_VOLT, 0.6), 5.0)
	Art.text_c(g, "GRID RESTORED", cx, o.y + 54.0, C_VOLT, 4)
	Art.text_c(g, "THE LIGHTS OF THE CITY FLICKER BACK ON.", cx, o.y + 92.0, C_TEXT, 1)
	Art.text_c(g, "VOLT-7 DELIVERED THE LAST PARCEL: POWER.", cx, o.y + 104.0, C_TEXT, 1)
	var lines := ["TIME     " + fmt_time(float(g.prog.time)), "ITEMS    %d/%d" % [g.items_got(), g.ITEM_TOTAL],
		"DEATHS   %d" % int(g.prog.deaths), "BEST     " + fmt_time(float(g.cfg.best))]
	for i in lines.size():
		Art.text(g, lines[i], Vector2(cx - 70.0, o.y + 130.0 + i * 14.0), C_CYAN, 1)
	if g.win_t > 2.0 and fmod(g.t_global, 1.0) < 0.7:
		Art.text_c(g, "PRESS JUMP / TAP FOR TITLE", cx, o.y + 200.0, C_VOLT, 1)
	Art.text_c(g, "MADE BY JAINEIL RANA (JAKING) - JAIGOD", cx, o.y + 244.0, C_DIM, 1)
