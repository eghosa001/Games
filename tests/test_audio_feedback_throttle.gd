extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _run() -> void:
    var audio := root.get_node_or_null("RenewAudioManager")
    check(audio != null, "Audio manager available")
    if audio == null:
        quit(1)
        return

    var previous_level := float(audio.get_sfx_level())
    audio.set_sfx_level(1.0)
    audio.set("_last_feedback_ms", {})

    var cursor_before_success := int(audio.get("_sfx_cursor"))
    audio.play_success()
    var cursor_after_success := int(audio.get("_sfx_cursor"))
    audio.play_success()
    var cursor_after_duplicate_success := int(audio.get("_sfx_cursor"))
    check(cursor_after_success != cursor_before_success, "First success cue allocates one SFX voice")
    check(cursor_after_duplicate_success == cursor_after_success, "Rapid duplicate success cue is throttled")

    audio.set("_last_feedback_ms", {})
    var cursor_before_failure := int(audio.get("_sfx_cursor"))
    audio.play_failure()
    var cursor_after_failure := int(audio.get("_sfx_cursor"))
    audio.play_failure()
    var cursor_after_duplicate_failure := int(audio.get("_sfx_cursor"))
    check(cursor_after_failure != cursor_before_failure, "First failure cue allocates one SFX voice")
    check(cursor_after_duplicate_failure == cursor_after_failure, "Rapid duplicate failure cue is throttled")

    audio.set_sfx_level(0.0)
    audio.set("_last_feedback_ms", {})
    var cursor_before_muted := int(audio.get("_sfx_cursor"))
    audio.play_day_end()
    audio.play_restoration()
    audio.play_construction()
    check(int(audio.get("_sfx_cursor")) == cursor_before_muted, "Muted SFX allocate no playback voices")

    var source := FileAccess.get_file_as_string("res://scripts/audio_manager.gd")
    check(source.contains("if not candidate.is_playing()"), "SFX allocator prefers idle players")
    check(source.contains("if player == null:\n        return null"), "SFX allocator drops overflow instead of replacing an active stream")

    audio.set_sfx_level(previous_level)
    audio.set("_last_feedback_ms", {})

    print("AUDIO FEEDBACK THROTTLE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
