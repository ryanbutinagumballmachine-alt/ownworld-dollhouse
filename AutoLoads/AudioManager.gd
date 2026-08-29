# ==============================================================================
# OWNWORLD — PROCEDURAL AUDIO SYNTHESIS & SFX POOL
# File: res://AutoLoads/AudioManager.gd
# Autoload Singleton: AudioManager
# Base Class: Node
#
# Responsibility: Real-time procedural byte synthesis of high-quality, zero-asset
# sound effects and a pooled AudioStreamPlayer playback engine.
# ==============================================================================

extends Node

const POOL_SIZE: int = 8
const SAMPLE_RATE: int = 22050

const MASTER_BUS: StringName = &"Master"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null

var snd_pop_grab: AudioStreamWAV = null
var snd_drop_cushion: AudioStreamWAV = null
var snd_snap_chime: AudioStreamWAV = null
var snd_chew: AudioStreamWAV = null
var snd_pour: AudioStreamWAV = null
var snd_sip: AudioStreamWAV = null

var _next_sfx_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_channels()
	_synthesize_all_sfx()


func _setup_channels() -> void:
	var music_bus_name: StringName = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else MASTER_BUS
	var sfx_bus_name: StringName = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else MASTER_BUS

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicStreamPlayer"
	music_player.bus = music_bus_name
	add_child(music_player)

	sfx_players.clear()
	for index: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % index
		player.bus = sfx_bus_name
		add_child(player)
		sfx_players.append(player)


func _synthesize_all_sfx() -> void:
	snd_pop_grab = _synth_pop(520.0, 0.07, true)
	snd_drop_cushion = _synth_pop(300.0, 0.08, false)
	snd_snap_chime = _synth_chime(880.0, 0.16)
	snd_chew = _synth_noise_burst(0.06)
	snd_pour = _synth_liquid_stream(0.24)
	snd_sip = _synth_gulp(0.12)


func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _find_available_player()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func play_pop_grab() -> void:
	play_sfx(snd_pop_grab, randf_range(0.95, 1.05))


func play_drop_cushion() -> void:
	play_sfx(snd_drop_cushion, randf_range(0.95, 1.05))


func play_snap_chime() -> void:
	play_sfx(snd_snap_chime, 1.0)


func play_chew() -> void:
	play_sfx(snd_chew, randf_range(0.90, 1.10))


func play_pour() -> void:
	play_sfx(snd_pour, randf_range(0.98, 1.02))


func play_sip() -> void:
	play_sfx(snd_sip, randf_range(0.95, 1.08))


func play_music(stream: AudioStream, from_position: float = 0.0) -> void:
	if music_player == null:
		return
	if stream == null:
		stop_music()
		return
	music_player.stream = stream
	music_player.play(from_position)


func stop_music() -> void:
	if music_player != null:
		music_player.stop()


func set_music_volume_db(volume_db: float) -> void:
	if music_player != null:
		music_player.volume_db = volume_db


func _find_available_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in sfx_players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % sfx_players.size()
	return player


func _synth_pop(start_frequency: float, duration: float, pitch_up: bool) -> AudioStreamWAV:
	var sample_count: int = int(float(SAMPLE_RATE) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)

	var time_step: float = 1.0 / float(SAMPLE_RATE)
	var inv_duration: float = 1.0 / duration
	var tau_freq: float = TAU * start_frequency

	for index: int in range(sample_count):
		var time: float = float(index) * time_step
		var envelope: float = exp(-time * 40.0)
		var time_ratio: float = time * inv_duration
		var frequency_mult: float = (1.0 + time_ratio * 0.8) if pitch_up else (1.0 - time_ratio * 0.45)
		var value: float = sin(tau_freq * frequency_mult * time) * envelope * 0.35
		raw.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	return _build_wav(raw)


func _synth_chime(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count: int = int(float(SAMPLE_RATE) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)

	var time_step: float = 1.0 / float(SAMPLE_RATE)
	var tau_freq: float = TAU * frequency
	var tau_freq_1_5: float = tau_freq * 1.5

	for index: int in range(sample_count):
		var time: float = float(index) * time_step
		var envelope: float = exp(-time * 14.0)
		var value: float = (sin(tau_freq * time) * 0.6 + sin(tau_freq_1_5 * time) * 0.4) * envelope * 0.3
		raw.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	return _build_wav(raw)


func _synth_noise_burst(duration: float) -> AudioStreamWAV:
	var sample_count: int = int(float(SAMPLE_RATE) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)

	var time_step: float = 1.0 / float(SAMPLE_RATE)

	for index: int in range(sample_count):
		var time: float = float(index) * time_step
		var envelope: float = exp(-time * 45.0)
		var value: float = randf_range(-0.3, 0.3) * envelope
		raw.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	return _build_wav(raw)


func _synth_liquid_stream(duration: float) -> AudioStreamWAV:
	var sample_count: int = int(float(SAMPLE_RATE) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)

	var time_step: float = 1.0 / float(SAMPLE_RATE)
	var tau_300: float = TAU * 300.0
	var tau_80: float = TAU * 80.0

	for index: int in range(sample_count):
		var time: float = float(index) * time_step
		var tau_freq: float = tau_300 + sin(time * 50.0) * tau_80
		var value: float = (sin(tau_freq * time) * 0.2 + randf_range(-0.08, 0.08)) * 0.3
		raw.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	return _build_wav(raw)


func _synth_gulp(duration: float) -> AudioStreamWAV:
	var sample_count: int = int(float(SAMPLE_RATE) * duration)
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(sample_count * 2)

	var time_step: float = 1.0 / float(SAMPLE_RATE)
	var inv_duration: float = 1.0 / duration
	var tau_240: float = TAU * 240.0

	for index: int in range(sample_count):
		var time: float = float(index) * time_step
		var envelope: float = exp(-time * 22.0)
		var tau_freq: float = tau_240 * (1.0 - time * inv_duration * 0.45)
		var value: float = sin(tau_freq * time) * envelope * 0.4
		raw.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	return _build_wav(raw)


func _build_wav(byte_data: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = byte_data
	return wav
