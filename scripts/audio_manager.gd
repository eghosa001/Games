extends Node
## RENEW premium adaptive audio system.
## Runtime synthesis keeps the build self-contained and Android-friendly while
## using layered envelopes, harmonics, noise textures and evolving motifs.

const SAMPLE_RATE := 22050
const MAX_SFX_PLAYERS := 12
const TAU_F := TAU

var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _last_message := ""
var _last_day := 1
var _last_restoration := 0
var _last_business_open := false
var _music_phase := 0.0
var _music_time := 0.0
var _music_note := 0
var _music_note_time := 0.0
var _music_seed := 0.0
var _last_tap_ms := -1000

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    _music_seed = randf() * 100.0
    _setup_music()
    for i in range(MAX_SFX_PLAYERS):
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        _sfx_players.append(player)
    call_deferred("_hook_ui")
    get_tree().node_added.connect(_on_node_added)

func _setup_music() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "RenewAdaptiveMusic"
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = 2.0
    _music_player.stream = stream
    _music_player.volume_db = -23.0
    add_child(_music_player)
    _music_player.play()
    _music_playback = _music_player.get_stream_playback()
    _feed_music(0.75)

func _process(delta: float) -> void:
    _feed_music(delta)
    _watch_game_state()

func _feed_music(delta: float) -> void:
    if _music_playback == null:
        return
    var frames := _music_playback.get_frames_available()
    var target := int(SAMPLE_RATE * clamp(delta, 0.04, 0.12))
    var count := min(frames, target)
    for i in range(count):
        var t := _music_phase / float(SAMPLE_RATE)
        _music_time += 1.0 / float(SAMPLE_RATE)
        _music_note_time += 1.0 / float(SAMPLE_RATE)
        if _music_note_time >= 0.72:
            _music_note_time = 0.0
            _music_note = (_music_note + 1) % 8
        var root := _adaptive_root()
        var scale_steps := [0, 2, 4, 7, 9, 7, 4, 2]
        var semitone := scale_steps[_music_note]
        var melody_freq := root * pow(2.0, float(semitone) / 12.0)
        var melody_env := _music_note_time / 0.72
        var attack := clamp(melody_env / 0.10, 0.0, 1.0)
        var decay := 1.0 - clamp((melody_env - 0.18) / 0.54, 0.0, 0.65)
        var pulse := attack * decay
        var bass := sin(TAU_F * root * 0.5 * t) * 0.012
        var pad_a := sin(TAU_F * root * t) * 0.016
        var pad_b := sin(TAU_F * root * 1.5 * t + 0.7) * 0.006
        var melody := (sin(TAU_F * melody_freq * t) * 0.010 + sin(TAU_F * melody_freq * 2.0 * t) * 0.0025) * pulse
        var shimmer := sin(TAU_F * melody_freq * 4.0 * t + sin(t * 0.4)) * 0.0015 * pulse
        var stereo := sin(t * 0.23 + _music_seed) * 0.003
        var left := bass + pad_a + pad_b + melody + shimmer + stereo
        var right := bass + pad_a + pad_b + melody + shimmer - stereo
        _music_playback.push_frame(Vector2(left, right))
        _music_phase += 1.0

func _adaptive_root() -> float:
    var state := get_node_or_null("/root/RenewGameState")
    if state == null:
        return 110.0
    var day := int(state.get_value("player", "day", 1))
    var restoration := int(state.get_value("properties", "restoration", 0))
    var business := bool(state.get_value("businesses", "business_open", false))
    if business and restoration >= 3:
        return 146.83
    if restoration >= 2:
        return 130.81
    if day >= 4:
        return 123.47
    return 110.0

func _watch_game_state() -> void:
    var state := get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var message = state.get_value("company", "message", "")
    if str(message) != _last_message:
        if _last_message != "":
            var lower := str(message).to_lower()
            if _is_failure(lower):
                play_failure()
            elif str(message) != "":
                play_success()
        _last_message = str(message)
    var day := int(state.get_value("player", "day", 1))
    if day != _last_day:
        _last_day = day
        play_day_end()
    var restoration := int(state.get_value("properties", "restoration", 0))
    if restoration != _last_restoration:
        if restoration > _last_restoration:
            play_restoration()
        _last_restoration = restoration
    var business_open := bool(state.get_value("businesses", "business_open", false))
    if business_open and not _last_business_open:
        play_construction()
    _last_business_open = business_open

func _is_failure(text: String) -> bool:
    return text.contains("failed") or text.contains("unable") or text.contains("not enough") or text.contains("cannot") or text.contains("can't") or text.contains("no save") or text.contains("save failed") or text.contains("insufficient")

func _on_node_added(node: Node) -> void:
    if node is BaseButton:
        _hook_button(node)

func _hook_ui() -> void:
    var root := get_tree().current_scene
    if root != null:
        _hook_tree(root)

func _hook_tree(node: Node) -> void:
    if node is BaseButton:
        _hook_button(node)
    for child in node.get_children():
        _hook_tree(child)

func _hook_button(button: BaseButton) -> void:
    if button.has_meta("renew_audio_hooked"):
        return
    button.set_meta("renew_audio_hooked", true)
    button.pressed.connect(play_ui_tap)

func _sfx_stream(duration: float) -> AudioStreamGenerator:
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = max(0.18, duration + 0.06)
    return stream

func _begin_sfx(duration: float) -> AudioStreamGeneratorPlayback:
    var player := _sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    player.stream = _sfx_stream(duration)
    player.volume_db = 0.0
    player.play()
    return player.get_stream_playback() as AudioStreamGeneratorPlayback

func _tone(playback: AudioStreamGeneratorPlayback, start: int, duration: float, frequency: float, amplitude: float, slide: float = 0.0, harmonic := 0.0, noise := 0.0, pan := 0.0) -> void:
    var frames := min(playback.get_frames_available(), int(SAMPLE_RATE * duration))
    for i in range(frames):
        var p := float(i) / float(max(frames, 1))
        var f := max(20.0, frequency + slide * p)
        var attack := clamp(p / 0.012, 0.0, 1.0)
        var release := clamp((1.0 - p) / 0.08, 0.0, 1.0)
        var env := min(attack, release)
        var s := sin(TAU_F * f * float(i + start) / float(SAMPLE_RATE))
        if harmonic > 0.0:
            s += sin(TAU_F * f * 2.0 * float(i + start) / float(SAMPLE_RATE)) * harmonic
        if noise > 0.0:
            s += randf_range(-1.0, 1.0) * noise * (1.0 - p)
        s *= amplitude * env
        var l := s * (1.0 - max(pan, 0.0))
        var r := s * (1.0 + min(pan, 0.0))
        playback.push_frame(Vector2(l, r))

func _play_sequence(notes: Array, duration: float, amplitude: float, harmonic := 0.15, pan_swing := 0.0) -> void:
    var playback := _begin_sfx(duration)
    var cursor := 0
    for note in notes:
        var len := min(0.16, duration - float(cursor) / SAMPLE_RATE)
        if len <= 0.0:
            break
        _tone(playback, cursor, len, float(note), amplitude, 0.0, harmonic, 0.0, sin(float(cursor)) * pan_swing)
        cursor += int(SAMPLE_RATE * 0.055)

func play_ui_tap() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_tap_ms < 55:
        return
    _last_tap_ms = now
    var playback := _begin_sfx(0.065)
    _tone(playback, 0, 0.055, 680.0, 0.075, 120.0, 0.22, 0.006, -0.08)

func play_success() -> void:
    _play_sequence([523.25, 659.25, 783.99], 0.22, 0.075, 0.28, 0.16)

func play_failure() -> void:
    var playback := _begin_sfx(0.24)
    _tone(playback, 0, 0.20, 247.0, 0.085, -72.0, 0.35, 0.018, 0.0)
    _tone(playback, 0, 0.15, 185.0, 0.035, -35.0, 0.2, 0.0, 0.0)

func play_day_end() -> void:
    _play_sequence([659.25, 783.99, 987.77, 1174.66], 0.34, 0.065, 0.32, 0.22)

func play_restoration() -> void:
    var playback := _begin_sfx(0.30)
    _tone(playback, 0, 0.10, 280.0, 0.055, 90.0, 0.25, 0.045, -0.2)
    _tone(playback, int(SAMPLE_RATE * 0.08), 0.11, 410.0, 0.060, 130.0, 0.22, 0.025, 0.1)
    _tone(playback, int(SAMPLE_RATE * 0.16), 0.12, 620.0, 0.065, 80.0, 0.30, 0.01, -0.05)

func play_construction() -> void:
    var playback := _begin_sfx(0.34)
    _tone(playback, 0, 0.16, 82.0, 0.060, 26.0, 0.45, 0.11, -0.12)
    _tone(playback, int(SAMPLE_RATE * 0.10), 0.10, 175.0, 0.040, 40.0, 0.28, 0.08, 0.12)
    _tone(playback, int(SAMPLE_RATE * 0.20), 0.11, 310.0, 0.055, 65.0, 0.35, 0.025, -0.04)
