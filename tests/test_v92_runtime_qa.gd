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
    check(Rivals != null, "Competitor model loads")
    if Rivals == null:
        quit(1)
        return
    var rivals = Rivals.new()
    check(rivals._money(1234567) == "1,234,567", "Money groups thousands")
    check(rivals._money(999) == "999", "Small money ungrouped")
    check(rivals._money(-42000) == "-42,000", "Negative money groups")
    check(rivals._money(0) == "0", "Zero money renders")
    var bad: Array = []
    var dir := DirAccess.open("res://scripts")
    check(dir != null, "Scripts directory is readable")
    if dir != null:
        for file_name in dir.get_files():
            if not str(file_name).ends_with(".gd"):
                continue
            var file := FileAccess.open("res://scripts/" + str(file_name), FileAccess.READ)
            if file == null:
                bad.append(str(file_name))
                continue
            if str(file.get_as_text()).find("%,d") >= 0:
                bad.append(str(file_name))
    check(bad.is_empty(), "No invalid %,d specifiers in scripts")
    var audio = root.get_node_or_null("RenewAudioManager")
    check(audio != null, "Audio manager available")
    if audio != null:
        var before_cursor: int = int(audio.get("_sfx_cursor"))
        audio.play_ui_tap()
        audio.play_success()
        audio.play_failure()
        var players: Array = audio.get("_sfx_players") as Array
        var active_players := 0
        for player in players:
            if player is AudioStreamPlayer and (player as AudioStreamPlayer).is_playing():
                active_players += 1
        check(active_players > 0, "SFX calls start at least one playback stream")
        check(int(audio.get("_sfx_cursor")) != before_cursor, "SFX calls advance the playback cursor")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for soundscape QA")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        var services = root.get_node_or_null("RenewServices")
        var ambient = services.get_service("RenewAmbientAudio") if services != null else null
        check(ambient != null, "Soundscape available")
        game.free()
        await process_frame
    print("V92 RUNTIME QA RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
