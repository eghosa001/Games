extends Node
## RENEW ambient soundscape layer.
## Adds subtle office, market, city and business activity without external assets.
## The layer is intentionally quiet so it supports, rather than competes with, music and SFX.

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
var _last_pulse := 0.0

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
    _player.volume_db = -28.0
    add_child(_player)
    _player.play()
    _playback = _player.get_stream_playback()
    _refresh_state()
    _feed(0.75)

func _process(delta: float) -> void:
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
    _business_level = lerp(_business_level, 1.0 if business_open else 0.0, 0.025)
    _market_level = lerp(_market_level, clamp(float(day - 1) / 8.0, 0.0, 1.0), 0.018)
    _city_level = lerp(_city_level, clamp(float(restoration) / 6.0, 0.0, 1.0), 0.018)

func _feed(delta: float) -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    var target := int(SAMPLE_RATE * clamp(delta, 0.04, 0.12))
    var count := min(frames, target)
    for i in range(count):
        var t := _phase / float(SAMPLE_RATE)
        var office := (sin(TAU_F * 63.0 * t) * 0.005 + sin(TAU_F * 127.0 * t + 0.4) * 0.002) * (0.35 + _business_level * 0.65)
        var air := sin(TAU_F * 0.17 * t + _seed) * 0.0018
        var city := (sin(TAU_F * 39.0 * t + sin(t * 0.11)) * 0.003 + sin(TAU_F * 73.0 * t + 1.2) * 0.0015) * _city_level
        var market := sin(TAU_F * 2.5 * t + sin(t * 0.07)) * 0.0012 * _market_level
        var pulse_phase := fmod(t, 1.6)
        var pulse_env := max(0.0, 1.0 - pulse_phase / 0.16)
        var pulse := sin(TAU_F * 310.0 * pulse_phase) * 0.0025 * pulse_env * _business_level
        var sample := office + air + city + market + pulse
        var pan := sin(t * 0.19 + _seed) * 0.10
        _playback.push_frame(Vector2(sample * (1.0 - max(pan, 0.0)), sample * (1.0 + min(pan, 0.0))))
        _phase += 1.0
