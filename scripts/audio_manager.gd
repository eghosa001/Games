extends Node
## RENEW V1 procedural audio manager.
## Generates lightweight UI/gameplay SFX and an adaptive ambient loop at runtime,
## avoiding external binary audio dependencies while keeping Android-friendly audio.

const SAMPLE_RATE := 22050
const MAX_SFX_PLAYERS := 8
var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _last_message := ""
var _last_day := 1
var _last_restoration := 0
var _music_phase := 0.0
var _music_bar := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
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
    _music_player.name = "RenewAmbientMusic"
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = 2.0
    _music_player.stream = stream
    _music_player.volume_db = -19.0
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
    var target := int(SAMPLE_RATE * max(delta, 0.04))
    var count := min(frames, target)
    for i in range(count):
        var t := _music_phase / float(SAMPLE_RATE)
        var bar_pos := fmod(_music_bar, 8.0)
        var chord := 110.0
        if bar_pos >= 2.0 and bar_pos < 4.0: chord = 123.47
        elif bar_pos >= 4.0 and bar_pos < 6.0: chord = 146.83
        elif bar_pos >= 6.0: chord = 130.81
        var slow := sin(TAU * chord * t) * 0.045
        var pad := sin(TAU * chord * 2.0 * t) * 0.018
        var shimmer := sin(TAU * chord * 3.0 * t) * 0.009
        var sample := slow + pad + shimmer
        _music_playback.push_frame(Vector2(sample, sample))
        _music_phase += 1.0
        _music_bar += 1.0 / float(SAMPLE_RATE)

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

func _sfx_stream(frequency: float, duration: float, volume: float, slide: float = 0.0, noise: float = 0.0) -> AudioStreamGenerator:
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = max(0.15, duration + 0.05)
    return stream

func _play_tone(frequency: float, duration: float, volume: float, slide: float = 0.0, noise: float = 0.0, attack := 0.008, release := 0.06) -> void:
    var player := _sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    var stream := _sfx_stream(frequency, duration, volume, slide, noise)
    player.stream = stream
    player.volume_db = 0.0
    player.play()
    var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
    var frames := min(playback.get_frames_available(), int(SAMPLE_RATE * duration))
    for i in range(frames):
        var p := float(i) / float(max(frames, 1))
        var freq := max(20.0, frequency + slide * p)
        var env := 1.0
        if p < attack:
            env = p / attack
        elif p > 1.0 - release:
            env = (1.0 - p) / release
        var s := sin(TAU * freq * float(i) / float(SAMPLE_RATE)) * volume * env
        if noise != 0.0:
            s += randf_range(-1.0, 1.0) * noise * env
        playback.push_frame(Vector2(s, s))

func play_ui_tap() -> void:
    _play_tone(620.0, 0.045, 0.12, 180.0, 0.005, 0.004, 0.025)

func play_success() -> void:
    _play_tone(523.25, 0.07, 0.14, 60.0, 0.0, 0.004, 0.025)
    await get_tree().create_timer(0.055).timeout
    _play_tone(783.99, 0.11, 0.13, 90.0, 0.0, 0.004, 0.045)

func play_failure() -> void:
    _play_tone(220.0, 0.13, 0.13, -55.0, 0.0, 0.004, 0.06)

func play_day_end() -> void:
    _play_tone(659.25, 0.08, 0.11, 0.0, 0.0, 0.005, 0.035)
    await get_tree().create_timer(0.07).timeout
    _play_tone(880.0, 0.18, 0.12, 0.0, 0.0, 0.005, 0.09)

func play_restoration() -> void:
    _play_tone(310.0, 0.10, 0.09, 180.0, 0.025, 0.004, 0.04)
    await get_tree().create_timer(0.08).timeout
    _play_tone(520.0, 0.12, 0.08, 80.0, 0.012, 0.004, 0.05)

func play_construction() -> void:
    _play_tone(95.0, 0.16, 0.10, 35.0, 0.09, 0.002, 0.08)
    await get_tree().create_timer(0.10).timeout
    _play_tone(180.0, 0.08, 0.07, 0.0, 0.06, 0.002, 0.04)
