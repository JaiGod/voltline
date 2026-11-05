extends Node
## Voltline audio: every sound effect and both music loops are synthesized in code at startup.

const SR := 22050
const MSR := 16000

var enabled := true
var sounds := {}
var pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var tracks := {}
var want_track := ""
var _jobs: Array = []   # incremental music synthesis jobs
var _cur_track := ""

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -13.0
	add_child(music_player)
	_build_sfx()
	_jobs.append(_music_job("explore", 112.0, [45, 45, 48, 45, 41, 41, 43, 40], [0, 3, 7, 10, 12, 10, 7, 3]))
	_jobs.append(_music_job("boss", 140.0, [40, 40, 43, 40, 38, 38, 41, 35], [0, 7, 12, 7, 0, 6, 12, 6]))

func _process(_dt: float) -> void:
	if _jobs.size() > 0:
		var job: Dictionary = _jobs[0]
		_music_step(job, 6000)
		if job.done:
			var s := AudioStreamWAV.new()
			s.format = AudioStreamWAV.FORMAT_16_BITS
			s.mix_rate = MSR
			s.data = job.data
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = job.n
			tracks[job.name] = s
			_jobs.pop_front()
	_update_music()

func set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		music_player.stop()
		_cur_track = ""
	_update_music()

func play_music(name: String) -> void:
	want_track = name

func _update_music() -> void:
	if not enabled or want_track == "":
		if music_player.playing and want_track == "":
			music_player.stop()
			_cur_track = ""
		return
	if _cur_track == want_track:
		return
	if tracks.has(want_track):
		music_player.stream = tracks[want_track]
		music_player.play()
		_cur_track = want_track

func play(name: String, pitch: float = 1.0) -> void:
	if not enabled or not sounds.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.pitch_scale = pitch
			p.play()
			return
	pool[0].stream = sounds[name]
	pool[0].pitch_scale = pitch
	pool[0].play()

# --- synthesis -------------------------------------------------------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.data = data
	return s

func _osc(kind: String, ph: float) -> float:
	match kind:
		"sq":
			return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(ph, 1.0) * 2.0 - 1.0
		"tri":
			return absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
		_:
			return sin(ph * TAU)

func _tone(dur: float, f0: float, f1: float, kind: String, vol: float, noise: float = 0.0, lp: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var nz := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		ph += f / SR
		var env := minf(1.0, i / (SR * 0.004)) * pow(1.0 - t, 1.6)
		nz += (randf() * 2.0 - 1.0 - nz) * lp
		var v := _osc(kind, ph) * (1.0 - noise) + nz * noise
		out[i] = v * env * vol
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: int = 0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size() + offset)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		var j := i - offset
		if j >= 0 and j < b.size():
			v += b[j]
		out[i] = v
	return out

func _arp(notes: Array, step: float, kind: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in notes.size():
		var f := 440.0 * pow(2.0, (float(notes[k]) - 69.0) / 12.0)
		out = _mix(out, _tone(step * 2.2, f, f, kind, vol), int(k * step * SR))
	return out

func _build_sfx() -> void:
	sounds.jump = _wav(_tone(0.11, 260, 560, "sq", 0.22))
	sounds.djump = _wav(_tone(0.15, 420, 980, "tri", 0.35))
	sounds.land = _wav(_tone(0.06, 140, 60, "sq", 0.12, 0.7, 0.3))
	sounds.slash = _wav(_tone(0.11, 1400, 260, "saw", 0.25, 0.55, 0.6))
	sounds.whip = _wav(_mix(_tone(0.18, 1800, 160, "saw", 0.22, 0.4, 0.8), _tone(0.12, 3000, 900, "sq", 0.08)))
	sounds.shoot = _wav(_tone(0.13, 980, 180, "sq", 0.22, 0.15))
	sounds.hit = _wav(_tone(0.09, 320, 90, "sq", 0.28, 0.5, 0.5))
	sounds.clang = _wav(_mix(_tone(0.12, 1800, 1700, "sq", 0.15), _tone(0.12, 2650, 2600, "tri", 0.12)))
	sounds.hurt = _wav(_tone(0.32, 520, 70, "saw", 0.3, 0.25))
	sounds.kill = _wav(_tone(0.3, 220, 40, "sq", 0.3, 0.75, 0.25))
	sounds.explode = _wav(_tone(0.6, 120, 30, "sq", 0.45, 0.85, 0.12))
	sounds.dash = _wav(_tone(0.18, 300, 1200, "saw", 0.12, 0.8, 0.9))
	sounds.grapple = _wav(_tone(0.16, 220, 1400, "sine", 0.3, 0.1))
	sounds.bolt = _wav(_tone(0.09, 700, 320, "sq", 0.12))
	sounds.break_ = _wav(_tone(0.35, 400, 60, "saw", 0.32, 0.7, 0.35))
	sounds.select = _wav(_tone(0.05, 660, 660, "sq", 0.15))
	sounds.confirm = _wav(_arp([72, 79], 0.05, "sq", 0.16))
	sounds.pickup = _wav(_arp([60, 64, 67, 72, 76, 79, 84], 0.06, "sq", 0.15))
	sounds.save = _wav(_arp([67, 71, 74, 79, 83], 0.08, "tri", 0.3))
	sounds.heal = _wav(_arp([76, 83], 0.05, "tri", 0.28))
	sounds.boss = _wav(_mix(_tone(1.1, 90, 38, "saw", 0.35, 0.3, 0.3), _tone(1.0, 45, 30, "sq", 0.2)))
	sounds.beam = _wav(_tone(0.5, 200, 120, "saw", 0.2, 0.5, 0.7))
	sounds.wave = _wav(_tone(0.25, 90, 50, "sq", 0.3, 0.6, 0.2))

# Incremental chiptune generator so startup never stalls.
func _music_job(name: String, bpm: float, bass: Array, arp: Array) -> Dictionary:
	var beat := 60.0 / bpm
	var bars := bass.size()
	var n := int(bars * 4 * beat * MSR)
	var data := PackedByteArray()
	data.resize(n * 2)
	return {"name": name, "beat": beat, "bass": bass, "arp": arp, "n": n, "i": 0, "data": data, "done": false, "ph1": 0.0, "ph2": 0.0, "nz": 0.0}

func _music_step(job: Dictionary, count: int) -> void:
	var n: int = job.n
	var i0: int = job.i
	var i1 := mini(n, i0 + count)
	var beat: float = job.beat
	var bass: Array = job.bass
	var arp: Array = job.arp
	var data: PackedByteArray = job.data
	job.data = PackedByteArray()
	var ph1: float = job.ph1
	var ph2: float = job.ph2
	var nz: float = job.nz
	var boss: bool = job.name == "boss"
	for i in range(i0, i1):
		var t := float(i) / MSR
		var b := t / beat
		var bar := int(b / 4.0) % bass.size()
		var root: int = bass[bar]
		var eighth := b * 2.0
		var e_i := int(eighth)
		var e_f := eighth - e_i
		# bass: root on beats, octave jump on offbeats
		var bn := root + (12 if e_i % 2 == 1 else 0)
		var bf := 440.0 * pow(2.0, (bn - 69.0) / 12.0)
		ph1 += bf / MSR
		var bass_v := (absf(fmod(ph1, 1.0) * 4.0 - 2.0) - 1.0) * 0.32 * (1.0 - e_f * 0.6)
		# arpeggio lead (16ths)
		var s16 := int(b * 4.0)
		var s_f := b * 4.0 - s16
		var an: int = root + 24 + int(arp[s16 % arp.size()])
		var af := 440.0 * pow(2.0, (an - 69.0) / 12.0)
		ph2 += af / MSR
		var duty := 0.25 if boss else 0.5
		var lead := (1.0 if fmod(ph2, 1.0) < duty else -1.0) * 0.07 * pow(1.0 - s_f, 2.0)
		if (bar % 4) == 3 and not boss:
			lead *= 0.4
		# drums: kick on beats, hat on offbeat 8ths, snare on 2 and 4
		var beat_f := b - floorf(b)
		var kick := sin(TAU * 55.0 * beat_f * beat * (1.0 + (1.0 - beat_f) * 2.0)) * pow(maxf(0.0, 1.0 - beat_f * 5.0), 2.0) * 0.45
		nz += (randf() * 2.0 - 1.0 - nz) * 0.9
		var hat := nz * 0.06 * pow(maxf(0.0, 1.0 - e_f * 8.0), 2.0) * (1.0 if e_i % 2 == 1 else 0.4)
		var snare := 0.0
		if int(b) % 2 == 1:
			snare = nz * 0.16 * pow(maxf(0.0, 1.0 - beat_f * 6.0), 2.0)
		var v := bass_v + lead + kick + hat + snare
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	job.data = data
	job.i = i1
	job.ph1 = ph1
	job.ph2 = ph2
	job.nz = nz
	if i1 >= n:
		job.done = true
