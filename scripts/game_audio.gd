class_name GameAudio
extends Node
## Layered original combat audio. A bounded priority pool protects voices and supers.

const STYLE_ALIASES := {"kai": "fire", "neon": "sonic", "yuki": "ice", "ivy": "thorn", "rook": "crimson", "atlas": "seismic", "zero": "precision", "vex": "void", "sora": "wind", "raijin": "electric"}
const NEW_SOUNDS := ["punch_light", "punch_heavy", "swing_light", "swing_heavy", "cloth_hit", "guard_clash", "land", "jump", "voice_grunt_0", "voice_grunt_1", "voice_grunt_2", "voice_yelp_0", "voice_yelp_1", "style_fire", "style_sonic", "style_ice", "style_thorn", "style_crimson", "style_seismic", "style_precision", "style_void", "style_wind", "style_electric", "super_charge", "super_swing", "super_boom"]

var enabled: bool = true
## Allows deterministic resource/pool validation without starting a device mixer.
var playback_enabled: bool = true
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var cursor: int = 0
var sounds: Dictionary = {}
var _volume_tween: Tween
var _priorities: Array[int] = []
var _started: Array[int] = []
var _last_played: Dictionary[String, int] = {}
var _voice_cursor: int = 0
var _last_voice: int = -1000
var _last_hit: int = -1000
var _last_swing: int = -1000


func _ready() -> void:
	music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = _load_wav("riot_engine")
	if stream != null:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.volume_db = -24 if enabled else -80
	add_child(music)
	if playback_enabled: music.play()
	for id: String in ["menu_select", "impact", "block", "burst", "round"]:
		sounds[id] = _load_wav(id)
	for id: String in NEW_SOUNDS:
		sounds[id] = _load_wav(id)
	for i: int in range(14):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -14
		add_child(voice)
		voices.append(voice)
		_priorities.append(-1)
		_started.append(-1000)


func _load_wav(id: String) -> AudioStreamWAV:
	var path: String = "res://assets/audio/" + id + ".wav"
	if FileAccess.file_exists(path + ".import"):
		return load(path) as AudioStreamWAV
	# Newly generated PCM files also work before an editor reimport.
	return AudioStreamWAV.load_from_file(path)


func _exit_tree() -> void:
	if _volume_tween != null: _volume_tween.kill()
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice: AudioStreamPlayer in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	sounds.clear()


func set_music(value: bool) -> void:
	enabled = value
	if _volume_tween != null: _volume_tween.kill()
	if music != null: music.volume_db = -22 if enabled else -80


func set_battle(value: bool) -> void:
	if music == null: return
	if _volume_tween != null: _volume_tween.kill()
	_volume_tween = create_tween()
	_volume_tween.tween_property(music, "volume_db", (-19.0 if value else -25.0) if enabled else -80.0, 0.6)


func play(id: String, strong: bool = false, pitch: float = 1.0) -> void:
	match id:
		"impact": _play_sound("punch_heavy" if strong else "punch_light", 2, -9 if strong else -13, pitch)
		"block": _play_sound("guard_clash", 2, -13, pitch)
		"burst": _play_sound("super_boom", 3, -11, pitch)
		"charge": _play_sound("super_charge", 3, -15, pitch)
		"swing": play_swing("heavy" if strong else "light")
		"land": _play_sound("land", 1, -16, pitch)
		"jump": _play_sound("jump", 0, -19, pitch)
		_: _play_sound(id, 3 if id in ["round", "menu_select"] else 1, -10 if strong else -15, pitch)


func play_hit(style: String, heavy: bool = false, voice_pitch: float = 1.0, cue: String = "") -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hit < 42: return
	_last_hit = now
	var family: String = str(STYLE_ALIASES.get(style, style))
	var contact_pitch := 0.94 if heavy else 1.0
	var accent_pitch := 1.0
	var accent_volume := -16.0 if heavy else -21.0
	var contact_mix: Array = {
		"fire": [0.96, 0.82], "sonic": [1.08, 1.24], "ice": [1.14, 1.08],
		"thorn": [0.89, 0.86], "crimson": [0.84, 0.76], "seismic": [0.76, 0.68],
		"precision": [1.10, 1.02], "void": [0.95, 0.88], "wind": [1.18, 1.13], "electric": [1.27, 1.32],
	}.get(family, [1.0, 1.0]) as Array
	contact_pitch *= float(contact_mix[0])
	accent_pitch = float(contact_mix[1])
	if cue.begins_with("kai_"):
		contact_pitch *= 0.93
	elif cue.begins_with("neon_"):
		contact_pitch *= 1.08
	if cue.ends_with("_special") or cue.ends_with("_grab") or cue.ends_with("_counter"):
		accent_volume += 3.0
		accent_pitch *= 0.88
	elif cue.ends_with("_low"):
		contact_pitch *= 0.92
	_play_sound("punch_heavy" if heavy else "punch_light", 2, -10 if heavy else -13, contact_pitch)
	_play_sound("cloth_hit", 0, -19, 0.95 if heavy else 1.05)
	_play_sound("style_" + family, 1, accent_volume, accent_pitch)
	play_voice(voice_pitch, heavy)


func play_swing(kind: String = "light") -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_swing < 65: return
	_last_swing = now
	var heavy: bool = kind in ["heavy", "special", "launcher", "finisher", "super"]
	_play_sound("swing_heavy" if heavy else "swing_light", 0, -14 if heavy else -17, 0.94 if heavy else 1.02)


## Attack starts use a cue instead of a generic category. The sounds are still
## synthesized project assets, but their pitch, emphasis and layer timing give
## Kai's combustion and Neon's signal attacks different silhouettes.
func play_move(move: MoveData, style: String, voice_pitch: float = 1.0) -> void:
	if move == null:
		return
	var cue := move.sfx_cue
	var family: String = str(STYLE_ALIASES.get(style, style))
	var primary := "swing_light"
	var primary_pitch := 1.02
	var primary_volume := -17.0
	var style_volume := -80.0
	var style_pitch := 1.0
	match cue:
		"kai_body_hook":
			primary_pitch = .72
			primary_volume = -14
		"kai_knee":
			primary = "swing_heavy"
			primary_pitch = 1.15
			primary_volume = -14
			style_volume = -25
		"kai_spin_kick":
			primary = "super_swing"
			primary_pitch = 1.15
			primary_volume = -12
			style_volume = -21
		"kai_side_kick":
			primary = "swing_heavy"
			primary_pitch = .72
			primary_volume = -13
			style_volume = -26
		"kai_light":
			primary_pitch = 1.08
			style_volume = -28.0
			style_pitch = 1.20
		"kai_heavy":
			primary = "swing_heavy"
			primary_pitch = 0.84
			primary_volume = -12.0
			style_volume = -20.0
			style_pitch = 0.78
		"kai_low":
			primary = "swing_heavy"
			primary_pitch = 1.08
			primary_volume = -14.0
		"kai_launcher":
			primary = "swing_heavy"
			primary_pitch = 0.92
			primary_volume = -12.0
			style_volume = -18.0
			style_pitch = 1.16
		"kai_dodge":
			primary_pitch = 0.80
			primary_volume = -23.0
		"kai_special":
			primary = "super_swing"
			primary_pitch = 0.82
			primary_volume = -13.0
			style_volume = -17.0
			style_pitch = 0.76
		"neon_light":
			primary_pitch = 1.24
			style_volume = -27.0
			style_pitch = 1.32
		"neon_heavy":
			primary = "swing_heavy"
			primary_pitch = 0.76
			primary_volume = -12.0
			style_volume = -19.0
			style_pitch = 0.70
		"neon_low":
			primary_pitch = 0.82
			primary_volume = -17.0
			style_volume = -25.0
			style_pitch = 0.66
		"neon_launcher":
			primary = "swing_heavy"
			primary_pitch = 1.10
			primary_volume = -13.0
			style_volume = -19.0
			style_pitch = 1.28
		"neon_dodge":
			primary_pitch = 1.38
			primary_volume = -24.0
			style_volume = -30.0
			style_pitch = 1.42
		"neon_projectile":
			primary_pitch = 1.34
			primary_volume = -19.0
			style_volume = -15.0
			style_pitch = 0.72
		_:
			var heavy: bool = move.category in ["Heavy", "Low", "Special I", "Special II", "Super"]
			primary = "swing_heavy" if heavy else "swing_light"
			var authored_mix: Array = {
				"ice": [1.16, 0.94, -22.0], "thorn": [0.90, 0.84, -20.0],
				"crimson": [0.82, 0.78, -18.0], "seismic": [0.74, 0.68, -17.0],
				"precision": [1.12, 1.04, -23.0], "void": [0.96, 0.88, -20.0],
				"wind": [1.22, 1.08, -23.0], "electric": [1.30, 1.16, -19.0],
			}.get(family, [1.02, 0.94, -80.0]) as Array
			primary_pitch = float(authored_mix[1] if heavy else authored_mix[0])
			primary_volume = -14.0 if heavy else -17.0
			style_volume = float(authored_mix[2]) if move.category.begins_with("Special") or cue.ends_with("_heavy") else -80.0
			style_pitch = 0.82 if family == "seismic" else 1.24 if family == "electric" else 1.12 if family == "wind" else 0.92 if family == "void" else 1.0
			if move.id == "dodge":
				primary_volume -= 7.0
				primary_pitch *= 1.12
			elif move.id == "finisher":
				primary = "super_swing"
				primary_volume = -12.0
				style_volume = maxf(style_volume, -17.0)
	var now: int = Time.get_ticks_msec()
	if now - _last_swing < 55:
		return
	_last_swing = now
	_play_sound(primary, 1, primary_volume, primary_pitch)
	if style_volume > -70.0:
		_play_sound("style_" + family, 0, style_volume, style_pitch)
	if move.id in ["burst", "finisher"]:
		play_voice(voice_pitch, true)


func play_voice(pitch: float = 1.0, strong: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_voice < (240 if strong else 180): return
	_last_voice = now
	var id: String = "voice_yelp_%d" % (_voice_cursor % 2) if strong else "voice_grunt_%d" % (_voice_cursor % 3)
	_voice_cursor += 1
	_play_sound(id, 3, -13 if strong else -16, pitch)


func play_super(stage: int, style: String = "") -> void:
	if style == "kai" and stage > 0:
		_play_sound("punch_heavy", 4, -8 if stage < 4 else -5, [1.0, .85, 1.08, .7][stage-1])
		_play_sound("cloth_hit", 2, -12, .8)
		_play_sound("style_fire", 3, -15 if stage < 4 else -9, .8)
		if stage == 4: _play_sound("super_boom", 4, -10, .78)
		return
	var id: String = "super_charge" if stage <= 0 else "super_swing" if stage < 4 else "super_boom"
	_play_sound(id, 4, -14 if stage <= 0 else -10, 0.9 if stage == 3 else 1.0)
	if stage == 2: _play_sound("punch_heavy", 3, -14, 1.12)
	if stage >= 4: play_voice(0.92, true)


func _play_sound(id: String, priority: int, volume: float, pitch: float) -> void:
	if not sounds.has(id) or sounds[id] == null or voices.is_empty(): return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000)) < 28: return
	var slot: int = -1
	for offset: int in range(voices.size()):
		var index: int = (cursor + offset) % voices.size()
		if not voices[index].playing:
			slot = index
			break
	if slot < 0:
		for index: int in range(voices.size()):
			if _priorities[index] > priority: continue
			if slot < 0 or _priorities[index] < _priorities[slot] or (_priorities[index] == _priorities[slot] and _started[index] < _started[slot]):
				slot = index
	if slot < 0: return
	_last_played[id] = now
	_priorities[slot] = priority
	_started[slot] = now
	cursor = (slot + 1) % voices.size()
	var voice: AudioStreamPlayer = voices[slot]
	voice.stop()
	voice.stream = sounds[id] as AudioStream
	voice.pitch_scale = clampf(pitch, 0.65, 1.6)
	voice.volume_db = volume
	if playback_enabled: voice.play()
