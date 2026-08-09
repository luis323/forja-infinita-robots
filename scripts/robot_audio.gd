class_name RobotAudio
extends Node

const SAMPLE_RATE := 22050
const SFX_VOLUMES := {
	"ui": -12.0,
	"select": -8.0,
	"join": -5.0,
	"unlock": -2.0,
	"step": -13.0,
	"swing": -7.0,
	"hit": -3.0,
	"heavy": -1.0,
	"joint": -2.0,
	"detach": 0.0,
	"shot": -5.0,
	"countdown": -7.0,
	"victory": -2.0,
	"defeat": -6.0,
}

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var streams := {}
var _pool_index := 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "BattleMusic"
	music_player.volume_db = -12.0
	add_child(music_player)
	for index in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%02d" % index
		add_child(player)
		sfx_players.append(player)
	_create_sound_bank()

func play_ui() -> void:
	play_sfx("ui")

func play_sfx(kind: String, pitch: float = 1.0) -> void:
	if not streams.has(kind) or sfx_players.is_empty():
		return
	var player := sfx_players[_pool_index]
	_pool_index = (_pool_index + 1) % sfx_players.size()
	player.stop()
	player.stream = streams[kind]
	player.pitch_scale = pitch
	player.volume_db = float(SFX_VOLUMES.get(kind, -6.0))
	player.play()

func start_battle_music() -> void:
	if music_player.playing:
		return
	music_player.stream = streams.get("battle_music")
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func _create_sound_bank() -> void:
	streams.ui = _make_tone(520.0, 0.055, 18.0, "square", 0.45, 0.0)
	streams.select = _make_tone(760.0, 0.085, 12.0, "sine", 0.62, 280.0)
	streams.join = _make_tone(180.0, 0.28, 7.0, "metal", 0.76, 720.0)
	streams.unlock = _make_chord([659.25, 830.61, 987.77], 0.48, 7.0)
	streams.step = _make_tone(82.0, 0.10, 24.0, "noise", 0.55, -24.0)
	streams.swing = _make_tone(260.0, 0.15, 13.0, "noise", 0.52, 520.0)
	streams.hit = _make_tone(95.0, 0.18, 18.0, "metal", 0.88, -45.0)
	streams.heavy = _make_tone(62.0, 0.34, 11.0, "metal", 0.96, -24.0)
	streams.joint = _make_tone(138.0, 0.24, 8.0, "metal", 0.92, -86.0)
	streams.detach = _make_tone(74.0, 0.48, 6.5, "metal", 1.0, -28.0)
	streams.shot = _make_tone(940.0, 0.22, 11.0, "saw", 0.58, -640.0)
	streams.countdown = _make_tone(440.0, 0.12, 10.0, "square", 0.55, 80.0)
	streams.victory = _make_chord([523.25, 659.25, 783.99], 0.72, 4.5)
	streams.defeat = _make_chord([220.0, 185.0, 146.8], 0.75, 4.2)
	streams.battle_music = _make_battle_music()

func _make_tone(frequency: float, duration: float, decay: float, waveform: String, gain: float, sweep: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var current_frequency := maxf(28.0, frequency + sweep * progress)
		phase += TAU * current_frequency / SAMPLE_RATE
		var wave := 0.0
		match waveform:
			"square":
				wave = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				wave = 2.0 * (fmod(phase / TAU, 1.0)) - 1.0
			"noise":
				wave = sin(time * 6137.0) * sin(time * 3719.0)
			"metal":
				wave = sin(phase) * 0.55 + sin(phase * 1.973) * 0.30 + sin(phase * 3.11) * 0.15
			_:
				wave = sin(phase)
		var envelope := exp(-progress * decay) * minf(1.0, progress * 35.0)
		_write_sample(data, index, wave * envelope * gain)
	return _wav_from_data(data, false)

func _make_chord(frequencies: Array, duration: float, decay: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var wave := 0.0
		for frequency in frequencies:
			wave += sin(TAU * float(frequency) * time)
		wave /= maxf(1.0, float(frequencies.size()))
		var envelope := exp(-progress * decay) * minf(1.0, progress * 22.0)
		_write_sample(data, index, wave * envelope * 0.82)
	return _wav_from_data(data, false)

func _make_battle_music() -> AudioStreamWAV:
	var bpm := 132.0
	var beat_duration := 60.0 / bpm
	var total_beats := 16
	var duration := beat_duration * total_beats
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var bass_notes := [43.65, 43.65, 51.91, 58.27, 43.65, 65.41, 58.27, 51.91]
	var lead_steps := [0, 3, 7, 10, 7, 12, 10, 7, 0, 3, 7, 15, 12, 10, 7, 3]
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var beat := time / beat_duration
		var beat_phase := fmod(beat, 1.0)
		var eighth := floori(beat * 2.0)
		var bass_frequency := float(bass_notes[floori(beat) % bass_notes.size()])
		var bass := sin(TAU * bass_frequency * time) * 0.34
		bass += (1.0 if sin(TAU * bass_frequency * time * 0.5) > 0.0 else -1.0) * 0.08
		var kick_phase := beat_phase
		var kick_frequency := 48.0 + 90.0 * exp(-kick_phase * 18.0)
		var kick := sin(TAU * kick_frequency * time) * exp(-kick_phase * 17.0) * 0.72
		var snare := 0.0
		if floori(beat) % 4 in [1, 3]:
			snare = sin(time * 9317.0) * sin(time * 5279.0) * exp(-beat_phase * 22.0) * 0.30
		var hat_phase := fmod(beat * 2.0, 1.0)
		var hat := sin(time * 15731.0) * sin(time * 11213.0) * exp(-hat_phase * 35.0) * 0.09
		var semitone := int(lead_steps[eighth % lead_steps.size()])
		var lead_frequency := 174.61 * pow(2.0, float(semitone) / 12.0)
		var step_phase := fmod(beat * 2.0, 1.0)
		var lead := sin(TAU * lead_frequency * time) * exp(-step_phase * 3.4) * 0.16
		lead += sin(TAU * lead_frequency * 2.01 * time) * exp(-step_phase * 4.2) * 0.06
		var sample := tanh((bass + kick + snare + hat + lead) * 1.18) * 0.78
		_write_sample(data, index, sample)
	return _wav_from_data(data, true)

func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var value := clampi(int(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
	data.encode_s16(index * 2, value)

func _wav_from_data(data: PackedByteArray, should_loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if should_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = floori(float(data.size()) / 2.0)
	return stream
