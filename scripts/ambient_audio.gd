extends Node
## RENEW premium world soundscape.
## Procedural ambience adds a quiet sense of place without external audio assets.

const SAMPLE_RATE: int = 22050
const BUFFER_SECONDS: float = 2.0
const TAU_F: float = TAU

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _seed: float = 0.0
var _business_level: float = 0.0
var _market_level: float = 0.0
var _city_level: float = 0.0
var _last_state_refresh: float = 0.0
var _noise_state_l: float = 0.0
var _noise_state_r: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    _seed = randf() * 100.0
    _player = AudioStreamPlayer.new()
    _player.name = "RenewWorldSoundscape"
    var stream: AudioStreamGenerator = AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = BUFFER_SECONDS
    _player.stream = stream
    _player.volume_db = -30.0
    add_child(_player)
    _player.play()
    _playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
    _refresh_state()
    _feed(0.75)

func _process(delta: float) -> void:
    _last_state_refresh += delta
    if _last_state_refresh >= 0.15:
        _last_state_refresh = 0.0
        _refresh_state()
    _feed(delta)

func _refresh_state() -> void:
    var state: Node = get_node_or_null("/root/RenewGameState")
    var restoration: int = 0
    var day: int = 1
    var business_open: bool = false
    if state != null:
        restoration = int(state.get_value("properties", "restoration", 0))
        day = int(state.get_value("player", "day", 1))
        business_open = bool(state.get_value("businesses", "business_open", false))
    var target_business: float = 1.0 if business_open else 0.0
    var target_market: float = clampf(float(day - 1) / 8.0, 0.0, 1.0)
    var target_city: float = clampf(float(restoration) / 6.0, 0.0, 1.0)
    _business_level = lerpf(_business_level, target_business, 0.08)
    _market_level = lerpf(_market_level, target_market, 0.06)
    _city_level = lerpf(_city_level, target_city, 0.06)

func _feed(delta: float) -> void:
    if _playback == null:
        return
    var frames: int = _playback.get_frames_available()
    var target: int = int(SAMPLE_RATE * clampf(delta, 0.04, 0.12))
    var count: int = mini(frames, target)
    for i: int in range(count):
        var t: float = _phase / float(SAMPLE_RATE)
        var slow: float = sin(TAU_F * 0.031 * t + _seed)
        var breathe: float = 0.65 + 0.35 * sin(TAU_F * 0.071 * t + _seed * 0.37)
        var raw_l: float = randf_range(-1.0, 1.0)
        var raw_r: float = randf_range(-1.0, 1.0)
        _noise_state_l = lerpf(_noise_state_l, raw_l, 0.018)
        _noise_state_r = lerpf(_noise_state_r, raw_r, 0.018)
        var air_l: float = (_noise_state_l * 0.0020 + sin(TAU_F * 0.17 * t + _seed) * 0.0008) * (0.65 + _city_level * 0.35)
        var air_r: float = (_noise_state_r * 0.0020 + sin(TAU_F * 0.19 * t + _seed + 1.7) * 0.0008) * (0.65 + _city_level * 0.35)
        var office: float = (sin(TAU_F * 57.0 * t + 0.3) * 0.0015 + sin(TAU_F * 113.0 * t + 1.1) * 0.0010) * (0.30 + _business_level * 0.70) * breathe
        var city: float = (sin(TAU_F * 37.0 * t + slow * 0.8) * 0.0016 + sin(TAU_F * 71.0 * t + 2.0) * 0.0009) * _city_level
        var market: float = sin(TAU_F * 2.0 * t + sin(t * 0.09)) * 0.00065 * _market_level
        var pulse_cycle: float = fmod(t + _seed * 0.13, 2.7)
        var pulse_window: float = maxf(0.0, 1.0 - pulse_cycle / 0.13)
        var pulse_freq: float = 280.0 + 80.0 * sin(_seed + floor(t / 2.7) * 1.73)
        var pulse: float = sin(TAU_F * pulse_freq * pulse_cycle) * 0.0018 * pulse_window * _business_level
        var sample_l: float = air_l + office + city + market + pulse
        var sample_r: float = air_r + office + city + market + pulse
        var pan: float = sin(t * 0.13 + _seed) * 0.07
        _playback.push_frame(Vector2(sample_l * (1.0 - maxf(pan, 0.0)), sample_r * (1.0 + minf(pan, 0.0))))
        _phase += 1.0
