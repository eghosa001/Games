extends SceneTree

var failed := 0
var checks := 0

func _init() -> void:
    call_deferred("_run")

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        print("FAIL: %s" % label)

func _run() -> void:
    var audio_source := FileAccess.get_file_as_string("res://scripts/audio_manager.gd")
    var ambient_source := FileAccess.get_file_as_string("res://scripts/ambient_audio.gd")
    check("adaptive music explicitly forces stream playback", audio_source.contains("_music_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM"))
    check("SFX generator explicitly forces stream playback", audio_source.contains("player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM"))
    check("ambient generator explicitly forces stream playback", ambient_source.contains("_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM"))
    check("ambient synthesis uses the lower-cost 11.025 kHz mix rate", ambient_source.contains("const SAMPLE_RATE: int = 11025"))
    var feed_start := audio_source.find("func _feed_music")
    var sample_loop := audio_source.find("for i: int in range(count):", feed_start)
    var root_cache := audio_source.find("var root: float = _adaptive_root()", feed_start)
    check("adaptive music root is cached outside the per-sample loop", root_cache > feed_start and root_cache < sample_loop)
    check("music scale steps are reused as a constant", audio_source.contains("const MUSIC_SCALE_STEPS: Array[int]"))

    var probe := AudioStreamPlayer.new()
    probe.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
    check("Godot exposes stream playback mode", probe.get_playback_type() == AudioServer.PLAYBACK_TYPE_STREAM)
    probe.free()

    print("--- AUDIO WEB COMPAT SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failed])
    quit(1 if failed > 0 else 0)
