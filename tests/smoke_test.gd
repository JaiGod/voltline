extends SceneTree
## Headless smoke test: godot --headless --path . --script res://tests/smoke_test.gd
## Drives the real game logic with scripted input and checks every gate is passable.

var g
var fails := 0

func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1

func steps(n: int, inp: Dictionary = {}) -> void:
	g.test_inp = inp
	for i in n:
		g.game_step(1.0 / 60.0)

func hold(n: int, inp: Dictionary) -> void:
	steps(n, inp)

func _initialize() -> void:
	g = load("res://scenes/Main.tscn").instantiate()
	root.add_child(g)
	_run.call_deferred()

func _run() -> void:
	await process_frame
	g.test_mode = true
	print("VOLTLINE SMOKE TEST")
	# title menu -> new game
	steps(5)
	g.new_game()
	steps(90)
	check(g.player.on_ground, "player lands in loading dock")
	# walk right through the first rooms
	hold(400, {"right": true})
	check(g.cur == Vector2i(1, 1) or g.cur == Vector2i(2, 1), "walked into the next rooms (%s)" % str(g.cur))
	# every room loads and survives random input
	for key in g.Rooms.ROOMS:
		var p: PackedStringArray = key.split(",")
		g.give_all()
		g.invincible = true
		g.debug_goto(Vector2i(int(p[0]), int(p[1])), Vector2(60, 100))
		for i in 240:
			var inp := {}
			for a in ["left", "right", "jump", "attack", "dash", "grapple", "up", "down"]:
				if randf() < 0.3:
					inp[a] = true
			g.test_inp = inp
			g.game_step(1.0 / 60.0)
		check(g.state == g.PLAY, "room %s survives random play" % key)
	g.invincible = false
	_jump_heights()
	_dash_gate()
	_grapple_gate()
	_climb_gate()
	_pickup_and_save()
	_boss("4,0", 0, "F")
	_boss("4,3", 2, "R")
	_death()
	print("SMOKE %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(0 if fails == 0 else 1)

func _fresh(abilities: Array, weapon: int) -> void:
	g.prog = g._default_prog()
	for a in abilities:
		g.prog.ab[a] = true
	g.weapon = weapon
	g.max_hp = 5

func _jump_heights() -> void:
	_fresh([], 0)
	g.debug_goto(Vector2i(0, 1), Vector2(200, 226))
	steps(20)
	var y0: float = g.player.pos.y
	var best := y0
	g.test_inp = {"jump": true}
	for i in 60:
		g.game_step(1.0 / 60.0)
		best = minf(best, g.player.pos.y)
	print("  single jump height: %.1f px" % (y0 - best))
	check(y0 - best > 34.0 and y0 - best < 48.0, "single jump clears 2 tiles but not 3")
	_fresh(["dj"], 0)
	g.debug_goto(Vector2i(0, 1), Vector2(200, 226))
	steps(20)
	best = g.player.pos.y
	g.test_inp = {"jump": true}
	for i in 90:
		if i == 22:
			g.test_inp = {}
		if i == 23:
			g.test_inp = {"jump": true}
		g.game_step(1.0 / 60.0)
		best = minf(best, g.player.pos.y)
	print("  double jump height: %.1f px" % (y0 - best))
	check(y0 - best > 66.0, "double jump clears 4 tiles")

func _run_dash(with_dash: bool) -> bool:
	_fresh(["dj", "dash"] if with_dash else ["dj"], 0)
	g.debug_goto(Vector2i(2, 2), Vector2(20, 226))
	steps(10)
	var spiked := false
	var phase := 0
	var tj := 0
	for i in 600:
		var inp := {"right": true}
		var x: float = g.player.pos.x
		var on: bool = g.player.on_ground
		var edge := 5 * 16.0 - 11.0 if x < 13 * 16 else 16 * 16.0 - 11.0
		if on and x >= edge and x < edge + 12.0 and phase % 2 == 0:
			phase += 1
			tj = i
		if phase % 2 == 1:
			var k := i - tj
			if k < 16:
				inp["jump"] = true
			elif k == 17:
				pass
			elif k >= 18 and k < 30:
				inp["jump"] = true
			if k == 24:
				inp["dash"] = true
			if k > 30 and on:
				phase += 1
		var hp_before: int = g.player.hp
		g.test_inp = inp
		g.game_step(1.0 / 60.0)
		if g.player.hp < hp_before or g.state != g.PLAY:
			spiked = true
			break
		if g.cur != Vector2i(2, 2):
			break
	return not spiked and g.cur == Vector2i(3, 2)

func _dash_gate() -> void:
	check(_run_dash(true), "sludge channel is crossable with double jump + dash")
	check(not _run_dash(false), "sludge channel blocks players without dash")

func _grapple_gate() -> void:
	_fresh(["dj", "dash", "grapple"], 0)
	g.debug_goto(Vector2i(4, 2), Vector2(26, 226))
	steps(10)
	var ok := false
	for i in 900:
		var inp := {"right": true}
		if g.player.on_ground and g.player.pos.x < 60.0:
			inp["jump"] = true
		if not g.player.on_ground and not g.player.grapple_on and i % 6 == 0:
			inp["grapple"] = true
		var hp_before: int = g.player.hp
		g.test_inp = inp
		g.game_step(1.0 / 60.0)
		if g.player.hp < hp_before:
			break
		if g.player.pos.x > 25 * 16.0 and g.player.on_ground:
			ok = true
			break
	check(ok, "arc furnace is crossable by chaining grapples (x=%.0f)" % g.player.pos.x)

func _climb_gate() -> void:
	_fresh(["dj", "climb"], 0)
	g.debug_goto(Vector2i(0, 2), Vector2(15 * 16.0 + 2.0, 226))
	steps(10)
	var top := 999.0
	for i in 400:
		var inp := {"left": true, "up": true}
		if i == 2:
			inp["jump"] = true
		g.test_inp = inp
		g.game_step(1.0 / 60.0)
		top = minf(top, g.player.pos.y)
	check(top < 64.0, "filter vault pillar is climbable (top y=%.0f)" % top)
	_fresh(["dj"], 0)
	g.debug_goto(Vector2i(0, 2), Vector2(15 * 16.0 + 2.0, 226))
	steps(10)
	top = 999.0
	for i in 200:
		var inp := {"left": true, "jump": (i % 30) < 20}
		g.test_inp = inp
		g.game_step(1.0 / 60.0)
		top = minf(top, g.player.pos.y)
	check(top > 64.0, "pillar is not reachable without wall-climb")

func _pickup_and_save() -> void:
	_fresh([], 0)
	g.debug_goto(Vector2i(3, 1), Vector2(240, 226))
	steps(10)
	hold(80, {"right": true, "jump": true})
	hold(60, {"right": true})
	check(g.has_ab("dj"), "double jump pickup collected in relay station")
	g.debug_goto(Vector2i(0, 1), Vector2(60, 226))
	steps(10)
	hold(60, {"right": true})
	check(g.prog.save_room == "0,1", "save station records progress")

func _boss(key: String, weapon: int, tp: String) -> void:
	_fresh(["dj", "dash", "climb", "grapple"], weapon)
	var p := key.split(",")
	g.invincible = true
	g.debug_goto(Vector2i(int(p[0]), int(p[1])), Vector2(30, 226))
	steps(10)
	hold(70, {"right": true})
	check(g.boss_lock, "%s fight locks the arena" % tp)
	var done := false
	for i in 60 * 120:
		var b = g.boss
		if b == null:
			done = true
			break
		var dx: float = b.pos.x - g.player.center().x
		var inp := {"attack": i % 8 < 4}
		if absf(dx) > 20.0:
			inp["right" if dx > 0 else "left"] = true
		if b.pos.y < g.player.center().y - 40.0:
			inp["up"] = true
			if g.player.on_ground and i % 40 < 20:
				inp["jump"] = true
		g.test_inp = inp
		g.game_step(1.0 / 60.0)
	g.invincible = false
	check(done and g.prog.bosses.has(tp), "boss %s can be defeated" % tp)
	if tp == "F":
		check(g.tile(26, 15) == 46, "foreman's floor gate opens")
	else:
		steps(200)
		check(g.state == g.WIN, "defeating the warden wins the game")

func _death() -> void:
	_fresh([], 0)
	g.prog.save_room = "0,1"
	g.debug_goto(Vector2i(3, 0), Vector2(40, 226))
	g.player.hp = 1
	steps(5)
	g.player.hurt(g, 1, 0.0)
	steps(5)
	check(g.state == g.DEAD, "player dies at 0 hp")
	steps(80)
	g.tap_confirm = true
	steps(2)
	check(g.state == g.PLAY and g.cur == Vector2i(0, 1), "reboot at last station")
