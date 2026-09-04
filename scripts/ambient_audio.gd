extends Node
## RENEW premium world soundscape.
## Procedural ambience adds a quiet sense of place without external audio assets.
## Layers evolve slowly with restoration, time and business activity.

const SAMPLE_RATE := 22050
const BUFFER_SECONDS := 2.0
const TAU_F := TAU

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _seed := 0.0
var _business_level := 0.0
var _market_level := 0.0
var _city_level := 0.0
var _last_state_refresh := 0.0
var _noise_state_l := 0.0
var _noise_state_r := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    _seed = randf() * 100.0
    _player = AudioStreamPlayer.new()
    _player.name = "RenewWorldSoundscape"
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = BUFFER_SECONDS
    _player.stream = stream
    _player.volume_db = -30.0
    add_child(_player)
    _player.play()
    _playback = _player.get_stream_playback()
    _refresh_state()
    _feed(0.75)

func _process(delta: float) -> void:
    _last_state_refresh += delta
    if _last_state_refresh >= 0.15:
        _last_state_refresh = 0.0
        _refresh_state()
    _feed(delta)

func _refresh_state() -> void:
    var state := get_node_or_null("/root/RenewGameState")
    var restoration := 0
    var day := 1
    var business_open := false
    if state != null:
        restoration = int(state.get_value("properties", "restoration", 0))
        day = int(state.get_value("player", "day", 1))
        business_open = bool(state.get_value("businesses", "business_open", false))
    _business_level = lerp(_business_level, 1.0 if business_open else 0.0, 0.08)
    _market_level = lerp(_market_level, clamp(float(day - 1) / 8.0, 0.0, 1.0), 0.06)
    _city_level = lerp(_city_level, clamp(float(restoration) / 6.0, 0.0, 1.0), 0.06)

func _feed(delta: float) -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    var target := int(SAMPLE_RATE * clamp(delta, 0.04, 0.12))
    var count := min(frames, target)
    for i in range(count):
        var t := _phase / float(SAMPLE_RATE)
        var slow := sin(TAU_F * 0.031 * t + _seed)
        var breathe := 0.65 + 0.35 * sin(TAU_F * 0.071 * t + _seed * 0.37)

        var raw_l := randf_range(-1.0, 1.0)
        var raw_r := randf_range(-1.0, 1.0)
        _noise_state_l = lerp(_noise_state_l, raw_l, 0.018)
        _noise_state_r = lerp(_noise_state_r, raw_r, 0.018)
        var air_l := (_noise_state_l * 0.0020 + sin(TAU_F * 0.17 * t + _seed) * 0.0008) * (0.65 + _city_level * 0.35)
        var air_r := (_noise_state_r * 0.0020 + sin(TAU_F * 0.19 * t + _seed + 1.7) * 0.0008) * (0.65 + _city_level * 0.35)

        var office := (sin(TAU_F * 57.0 * t + 0.3) * 0.0015 + sin(TAU_F * 113.0 * t + 1.1) * 0.0010) * (0.30 + _business_level * 0.70) * breathe
        var city := (sin(TAU_F * 37.0 * t + slow * 0.8) * 0.0016 + sin(TAU_F * 71.0 * t + 2.0) * 0.0009) * _city_level
        var market := sin(TAU_F * 2.0 * t + sin(t * 0.09)) * 0.00065 * _market_level

        var pulse_cycle := fmod(t + _seed * 0.13, 2.7)
        var pulse_window := max(0.0, 1.0 - pulse_cycle / 0.13)
        var pulse_freq := 280.0 + 80.0 * sin(_seed + floor(t / 2.7) * 1.73)
        var pulse := sin(TAU_F * pulse_freq * pulse_cycle) * 0.0018 * pulse_window * _business_level

        var sample_l := air_l + office + city + market + pulse
        var sample_r := air_r + office + city + market + pulse
        var pan := sin(t * 0.13 + _seed) * 0.07
        _playback.push_frame(Vector2(sample_l * (1.0 - max(pan, 0.0)), sample_r * (1.0 + min(pan, 0.0))))
        _phase += 1.0
