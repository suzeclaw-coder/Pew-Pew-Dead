extends Node

# Procedural 16-bit PCM WAV synthesizer and audio player pooling engine for Pew-Pew-Dead.

# SFX buses
@export var sfx_bus: String = "Master"

# Pool configuration
const POOL_SIZE_2D: int = 16
const POOL_SIZE_3D: int = 12

var _2d_pool: Array[AudioStreamPlayer] = []
var _3d_pool: Array[AudioStreamPlayer3D] = []
var _2d_idx: int = 0
var _3d_idx: int = 0

# Pre-generated procedural streams
var streams: Dictionary = {}

func _ready() -> void:
	_init_procedural_streams()
	_init_pools()

func _init_procedural_streams() -> void:
	# Weapon shots
	streams["shot_pistol"] = _gen_wav(480.0, 0.12, 3.5, 0.35, 0.7)
	streams["shot_rifle"] = _gen_wav(360.0, 0.09, 4.0, 0.45, 0.65)
	streams["shot_shotgun"] = _gen_wav(160.0, 0.22, 2.5, 0.75, 0.85)
	
	# Impacts & combat feedback
	streams["hit_body"] = _gen_wav(140.0, 0.08, 4.5, 0.6, 0.5)
	streams["hit_headshot"] = _gen_wav(1760.0, 0.15, 2.0, 0.05, 0.6)
	streams["kill"] = _gen_wav(110.0, 0.18, 3.0, 0.7, 0.75)
	
	# Player movement & actions
	streams["slide"] = _gen_slide_sweep(320.0, 110.0, 0.28, 1.8, 0.7, 0.6)
	streams["jump"] = _gen_pitch_sweep(180.0, 440.0, 0.12, 2.2, 0.3, 0.55)
	streams["melee"] = _gen_pitch_sweep(340.0, 90.0, 0.16, 2.5, 0.55, 0.75)
	streams["player_hurt"] = _gen_wav(95.0, 0.24, 2.0, 0.3, 0.7)
	
	# Zombie cues
	streams["zombie_windup"] = _gen_pitch_sweep(120.0, 380.0, 0.45, 1.5, 0.25, 0.6)
	streams["zombie_groan"] = _gen_wav(85.0, 0.35, 1.6, 0.65, 0.55)

func _init_pools() -> void:
	for i in POOL_SIZE_2D:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_2d_pool.append(p)
	for i in POOL_SIZE_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = sfx_bus
		p.max_distance = 40.0
		add_child(p)
		_3d_pool.append(p)

# ========== Low-latency playback methods ==========

func play_shot(weapon_name: String = "pistol") -> void:
	var key := "shot_pistol"
	var name_lower := weapon_name.to_lower()
	if name_lower.contains("rifle"):
		key = "shot_rifle"
	elif name_lower.contains("shotgun"):
		key = "shot_shotgun"
	elif name_lower.contains("pistol"):
		key = "shot_pistol"
	
	var stream: AudioStream = streams.get(key, streams.get("shot_pistol", null))
	_play_2d(stream, 0.0, randf_range(0.96, 1.04))

func play_hit() -> void:
	_play_2d(streams.get("hit_body", null), -2.0, randf_range(0.95, 1.05))

func play_headshot() -> void:
	_play_2d(streams.get("hit_headshot", null), 2.0, randf_range(0.98, 1.02))

func play_kill() -> void:
	_play_2d(streams.get("kill", null), 1.0, randf_range(0.95, 1.05))

func play_slide() -> void:
	_play_2d(streams.get("slide", null), -1.0, randf_range(0.95, 1.05))

func play_jump() -> void:
	_play_2d(streams.get("jump", null), -2.0, randf_range(0.97, 1.03))

func play_melee() -> void:
	_play_2d(streams.get("melee", null), 0.0, randf_range(0.95, 1.05))

func play_player_hurt() -> void:
	_play_2d(streams.get("player_hurt", null), 1.0, randf_range(0.95, 1.05))

func play_zombie_windup(pos: Vector3 = Vector3.ZERO) -> void:
	if pos != Vector3.ZERO:
		_play_3d(streams.get("zombie_windup", null), pos, 0.0, randf_range(0.92, 1.08))
	else:
		_play_2d(streams.get("zombie_windup", null), -2.0, randf_range(0.92, 1.08))

func play_zombie_groan(pos: Vector3 = Vector3.ZERO) -> void:
	if pos != Vector3.ZERO:
		_play_3d(streams.get("zombie_groan", null), pos, 0.0, randf_range(0.90, 1.10))
	else:
		_play_2d(streams.get("zombie_groan", null), -2.0, randf_range(0.90, 1.10))

# ========== Pool management ==========

func _play_2d(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _2d_pool.is_empty():
		return
	var p: AudioStreamPlayer = null
	for candidate in _2d_pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _2d_pool[_2d_idx]
		_2d_idx = (_2d_idx + 1) % _2d_pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()

func _play_3d(stream: AudioStream, pos: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or _3d_pool.is_empty():
		return
	var p: AudioStreamPlayer3D = null
	for candidate in _3d_pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _3d_pool[_3d_idx]
		_3d_idx = (_3d_idx + 1) % _3d_pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.global_position = pos
	p.play()

# ========== Procedural synthesis engine ==========

func _gen_wav(freq: float, duration: float, fade_exp: float, noise_mix: float, gain: float) -> AudioStreamWAV:
	const SR: int = 22050
	var num: int = int(SR * duration)
	var bytes := PackedByteArray()
	bytes.resize(num * 2)
	for i in num:
		var t: float = float(i) / float(SR)
		var env: float = pow(1.0 - t / duration, fade_exp)
		var tone: float = sin(t * freq * TAU)
		var noise_v: float = randf() * 2.0 - 1.0
		var amp: float = env * (tone * (1.0 - noise_mix) + noise_v * noise_mix) * gain
		var s16: int = clampi(int(amp * 32767.0), -32767, 32767)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	return s

func _gen_pitch_sweep(start_freq: float, end_freq: float, duration: float, fade_exp: float, noise_mix: float, gain: float) -> AudioStreamWAV:
	const SR: int = 22050
	var num: int = int(SR * duration)
	var bytes := PackedByteArray()
	bytes.resize(num * 2)
	var phase: float = 0.0
	for i in num:
		var t: float = float(i) / float(SR)
		var progress: float = t / duration
		var current_freq: float = lerpf(start_freq, end_freq, progress)
		phase += current_freq * TAU / float(SR)
		var env: float = pow(1.0 - progress, fade_exp)
		var tone: float = sin(phase)
		var noise_v: float = randf() * 2.0 - 1.0
		var amp: float = env * (tone * (1.0 - noise_mix) + noise_v * noise_mix) * gain
		var s16: int = clampi(int(amp * 32767.0), -32767, 32767)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	return s

func _gen_slide_sweep(start_freq: float, end_freq: float, duration: float, fade_exp: float, noise_mix: float, gain: float) -> AudioStreamWAV:
	const SR: int = 22050
	var num: int = int(SR * duration)
	var bytes := PackedByteArray()
	bytes.resize(num * 2)
	var phase: float = 0.0
	# Attack-decay envelope for whoosh/slide
	var attack_time: float = duration * 0.15
	for i in num:
		var t: float = float(i) / float(SR)
		var progress: float = t / duration
		var current_freq: float = lerpf(start_freq, end_freq, progress)
		phase += current_freq * TAU / float(SR)
		var env: float = 0.0
		if t < attack_time:
			env = t / attack_time
		else:
			var decay_progress: float = (t - attack_time) / (duration - attack_time)
			env = pow(1.0 - decay_progress, fade_exp)
		var tone: float = sin(phase)
		var noise_v: float = randf() * 2.0 - 1.0
		var amp: float = env * (tone * (1.0 - noise_mix) + noise_v * noise_mix) * gain
		var s16: int = clampi(int(amp * 32767.0), -32767, 32767)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	return s
