extends Node
## RENEW premium adaptive audio system.
## Runtime synthesis keeps the build self-contained and Android-friendly.

const SAMPLE_RATE: int = 22050
const MAX_SFX_PLAYERS: int = 12
const TAU_F: float = TAU

var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _last_message: String = ""
var _last_day: int = 1
var _last_restoration: int = 0
var _last_business_open: bool = false
var _music_phase: float = 0.0
var _music_time: float = 0.0
var _music_note: int = 0
var _music_note_time: float = 0.0
var _music_seed: float = 0.0
var _last_tap_ms: int = -1000

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    _music_seed = randf() * 100.0
    _setup_music()
    for i: int in range(MAX_SFX_PLAYERS):
        var player: AudioStreamPlayer = AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        _sfx_players.append(player)
    call_deferred("_hook_ui")
    get_tree().node_added.connect(_on_node_added)

func _setup_music() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "RenewAdaptiveMusic"
    var stream: AudioStreamGenerator = AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = 2.0
    _music_player.stream = stream
    _music_player.volume_db = -23.0
    add_child(_music_player)
    _music_player.play()
    _music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
    _feed_music(0.75)

func _process(delta: float) -> void:
    _feed_music(delta)
    _watch_game_state()

func _feed_music(delta: float) -> void:
    if _music_playback == null:
        return
    var frames: int = _music_playback.get_frames_available()
    var target: int = int(SAMPLE_RATE * clampf(delta, 0.04, 0.12))
    var count: int = mini(frames, target)
    for i: int in range(count):
        var t: float = _music_phase / float(SAMPLE_RATE)
        _music_time += 1.0 / float(SAMPLE_RATE)
        _music_note_time += 1.0 / float(SAMPLE_RATE)
        if _music_note_time >= 0.72:
            _music_note_time = 0.0
            _music_note = (_music_note + 1) % 8
        var root: float = _adaptive_root()
        var scale_steps: Array[int] = [0, 2, 4, 7, 9, 7, 4, 2]
        var semitone: float = float(scale_steps[_music_note])
        var melody_freq: float = root * pow(2.0, semitone / 12.0)
        var melody_pos: float = _music_note_time / 0.72
        var attack: float = clampf(melody_pos / 0.10, 0.0, 1.0)
        var decay: float = 1.0 - clampf((melody_pos - 0.18) / 0.54, 0.0, 0.65)
        var pulse: float = attack * decay
        var bass: float = sin(TAU_F * root * 0.5 * t) * 0.012
        var pad_a: float = sin(TAU_F * root * t) * 0.016
        var pad_b: float = sin(TAU_F * root * 1.5 * t + 0.7) * 0.006
        var melody: float = (sin(TAU_F * melody_freq * t) * 0.010 + sin(TAU_F * melody_freq * 2.0 * t) * 0.0025) * pulse
        var shimmer: float = sin(TAU_F * melody_freq * 4.0 * t + sin(t * 0.4)) * 0.0015 * pulse
        var stereo: float = sin(t * 0.23 + _music_seed) * 0.003
        var left: float = bass + pad_a + pad_b + melody + shimmer + stereo
        var right: float = bass + pad_a + pad_b + melody + shimmer - stereo
        _music_playback.push_frame(Vector2(left, right))
        _music_phase += 1.0

func _adaptive_root() -> float:
    var state: Node = get_node_or_null("/root/RenewGameState")
    if state == null:
        return 110.0
    var day: int = int(state.get_value("player", "day", 1))
    var restoration: int = int(state.get_value("properties", "restoration", 0))
    var business: bool = bool(state.get_value("businesses", "business_open", false))
    if business and restoration >= 3:
        return 146.83
    if restoration >= 2:
        return 130.81
    if day >= 4:
        return 123.47
    return 110.0

func _watch_game_state() -> void:
    var state: Node = get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var message: String = str(state.get_value("company", "message", ""))
    if message != _last_message:
        if _last_message != "":
            var lower: String = message.to_lower()
            if _is_failure(lower):
                play_failure()
            elif message != "":
                play_success()
        _last_message = message
    var day: int = int(state.get_value("player", "day", 1))
    if day != _last_day:
        _last_day = day
        play_day_end()
    var restoration: int = int(state.get_value("properties", "restoration", 0))
    if restoration != _last_restoration:
        if restoration > _last_restoration:
            play_restoration()
        _last_restoration = restoration
    var business_open: bool = bool(state.get_value("businesses", "business_open", false))
    if business_open and not _last_business_open:
        play_construction()
    _last_business_open = business_open

func _is_failure(text: String) -> bool:
    return text.contains("failed") or text.contains("unable") or text.contains("not enough") or text.contains("cannot") or text.contains("can't") or text.contains("no save") or text.contains("save failed") or text.contains("insufficient")

func _on_node_added(node: Node) -> void:
    if node is BaseButton:
        _hook_button(node as BaseButton)

func _hook_ui() -> void:
    var root: Node = get_tree().current_scene
    if root != null:
        _hook_tree(root)

func _hook_tree(node: Node) -> void:
    if node is BaseButton:
        _hook_button(node as BaseButton)
    for child: Node in node.get_children():
        _hook_tree(child)

func _hook_button(button: BaseButton) -> void:
    if button.has_meta("renew_audio_hooked"):
        return
    button.set_meta("renew_audio_hooked", true)
    button.pressed.connect(play_ui_tap)

func _sfx_stream(duration: float) -> AudioStreamGenerator:
    var stream: AudioStreamGenerator = AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = maxf(0.18, duration + 0.06)
    return stream

func _begin_sfx(duration: float) -> AudioStreamGeneratorPlayback:
    var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    player.stream = _sfx_stream(duration)
    player.volume_db = 0.0
    player.play()
    return player.get_stream_playback() as AudioStreamGeneratorPlayback

func _render_sequence(notes: Array, total_duration: float, amplitude: float, harmonic: float = 0.15, spacing: float = 0.055) -> void:
    var playback: AudioStreamGeneratorPlayback = _begin_sfx(total_duration)
    var total_frames: int = mini(playback.get_frames_available(), int(SAMPLE_RATE * total_duration))
    var spacing_frames: int = int(SAMPLE_RATE * spacing)
    var note_frames: int = int(SAMPLE_RATE * minf(0.16, total_duration))
    for frame: int in range(total_frames):
        var sample: float = 0.0
        for n: int in range(notes.size()):
            var start: int = n * spacing_frames
            var local: int = frame - start
            if local < 0 or local >= note_frames:
                continue
            var p: float = float(local) / float(maxi(note_frames, 1))
            var env: float = minf(clampf(p / 0.010, 0.0, 1.0), clampf((1.0 - p) / 0.075, 0.0, 1.0))
            var freq: float = float(notes[n])
            sample += (sin(TAU_F * freq * float(local) / SAMPLE_RATE) + sin(TAU_F * freq * 2.0 * float(local) / SAMPLE_RATE) * harmonic) * amplitude * env
        var pan: float = sin(float(frame) / SAMPLE_RATE * 2.0 + _music_seed) * 0.10
        playback.push_frame(Vector2(sample * (1.0 - maxf(pan, 0.0)), sample * (1.0 + minf(pan, 0.0))))

func _tone(playback: AudioStreamGeneratorPlayback, duration: float, frequency: float, amplitude: float, slide: float = 0.0, harmonic: float = 0.0, noise: float = 0.0, pan: float = 0.0) -> void:
    var frames: int = mini(playback.get_frames_available(), int(SAMPLE_RATE * duration))
    for i: int in range(frames):
        var p: float = float(i) / float(maxi(frames, 1))
        var f: float = maxf(20.0, frequency + slide * p)
        var env: float = minf(clampf(p / 0.012, 0.0, 1.0), clampf((1.0 - p) / 0.08, 0.0, 1.0))
        var s: float = sin(TAU_F * f * float(i) / SAMPLE_RATE)
        s += sin(TAU_F * f * 2.0 * float(i) / SAMPLE_RATE) * harmonic
        s += randf_range(-1.0, 1.0) * noise * (1.0 - p)
        s *= amplitude * env
        playback.push_frame(Vector2(s * (1.0 - maxf(pan, 0.0)), s * (1.0 + minf(pan, 0.0))))

func play_ui_tap() -> void:
    var now: int = Time.get_ticks_msec()
    if now - _last_tap_ms < 55:
        return
    _last_tap_ms = now
    var playback: AudioStreamGeneratorPlayback = _begin_sfx(0.065)
    _tone(playback, 0.055, 680.0, 0.075, 120.0, 0.22, 0.006, -0.08)

func play_success() -> void:
    _render_sequence([523.25, 659.25, 783.99], 0.24, 0.075, 0.28, 0.065)

func play_failure() -> void:
    var playback: AudioStreamGeneratorPlayback = _begin_sfx(0.24)
    _tone(playback, 0.20, 247.0, 0.085, -72.0, 0.35, 0.018, 0.0)

func play_day_end() -> void:
    _render_sequence([659.25, 783.99, 987.77, 1174.66], 0.38, 0.065, 0.32, 0.075)

func play_restoration() -> void:
    var playback: AudioStreamGeneratorPlayback = _begin_sfx(0.30)
    _tone(playback, 0.10, 280.0, 0.055, 90.0, 0.25, 0.045, -0.2)
    _tone(playback, 0.11, 410.0, 0.060, 130.0, 0.22, 0.025, 0.1)
    _tone(playback, 0.12, 620.0, 0.065, 80.0, 0.30, 0.01, -0.05)

func play_construction() -> void:
    var playback: AudioStreamGeneratorPlayback = _begin_sfx(0.34)
    _tone(playback, 0.16, 82.0, 0.060, 26.0, 0.45, 0.11, -0.12)
    _tone(playback, 0.10, 175.0, 0.040, 40.0, 0.28, 0.08, 0.12)
    _tone(playback, 0.11, 310.0, 0.055, 65.0, 0.35, 0.025, -0.04)
