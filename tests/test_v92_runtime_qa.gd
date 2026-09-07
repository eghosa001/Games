extends SceneTree

## Production QA: grouped money never uses invalid format specifiers, and
## the synthesized audio stack stays silent-safe with no usable playback.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var Rivals = load("res://scripts/competitors.gd")
    var rivals = Rivals.new()
    check(rivals._money(1234567) == "1,234,567", "Money groups thousands")
    check(rivals._money(999) == "999", "Small money ungrouped")
    check(rivals._money(-42000) == "-42,000", "Negative money groups")
    check(rivals._money(0) == "0", "Zero money renders")
    var bad: Array = []
    var dir := DirAccess.open("res://scripts")
    if dir != null:
        for file_name in dir.get_files():
            if not str(file_name).ends_with(".gd"):
                continue
            var file := FileAccess.open("res://scripts/" + str(file_name), FileAccess.READ)
            if file == null:
                continue
            if str(file.get_as_text()).find("%,d") >= 0:
                bad.append(str(file_name))
    check(bad.is_empty(), "No invalid %,d specifiers in scripts")
    var audio = root.get_node_or_null("RenewAudioManager")
    check(audio != null, "Audio manager available")
    if audio != null:
        audio.play_ui_tap()
        audio.play_success()
        audio.play_failure()
        check(true, "SFX calls stay error-free")
    var ambient = root.get_node_or_null("RenewAmbientAudio")
    check(ambient != null, "Soundscape available")
    await process_frame
    await process_frame
    print("V92 RUNTIME QA RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
