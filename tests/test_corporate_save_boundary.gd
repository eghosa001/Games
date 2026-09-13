extends SceneTree

const SaveSystem = preload("res://scripts/save_system.gd")
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
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var corporate = game.get_node_or_null("World/Corporate")
    var state = root.get_node_or_null("RenewGameState")
    check(corporate != null, "Corporate controller resolves")
    check(state != null, "GameState resolves")
    if corporate == null or state == null:
        game.free()
        quit(1)
        return

    corporate.takeover_wins = 3
    corporate.hostile_attempts = 7
    corporate.takeover_cooldown = 9
    corporate.dividends_paid = 12345
    corporate.milestone_level = 4

    var payload: Dictionary = state.capture()
    payload["schema_version"] = SaveSystem.CURRENT_VERSION
    SaveSystem._capture_runtime_corporate(payload)
    var company: Dictionary = payload.get("domains", {}).get("company", {})
    var snapshot: Dictionary = company.get("corporate_controller", {})
    check(not snapshot.is_empty(), "Corporate state is embedded in canonical save payload")
    check(int(snapshot.get("takeover_wins", 0)) == 3, "Takeover wins captured")
    check(int(snapshot.get("hostile_attempts", 0)) == 7, "Hostile attempts captured")
    check(int(snapshot.get("takeover_cooldown", 0)) == 9, "Takeover cooldown captured")
    check(int(snapshot.get("dividends_paid", 0)) == 12345, "Dividend history captured")
    check(int(snapshot.get("milestone_level", 0)) == 4, "Corporate milestone captured")
    check(not snapshot.has("ownership_state"), "Corporate snapshot does not duplicate ownership authority")

    corporate.takeover_wins = 0
    corporate.hostile_attempts = 0
    corporate.takeover_cooldown = 0
    corporate.dividends_paid = 0
    corporate.milestone_level = 0
    SaveSystem._restore_runtime_corporate(payload)
    check(int(corporate.takeover_wins) == 3, "Takeover wins restore")
    check(int(corporate.hostile_attempts) == 7, "Hostile attempts restore")
    check(int(corporate.takeover_cooldown) == 9, "Takeover cooldown restores")
    check(int(corporate.dividends_paid) == 12345, "Dividend history restores")
    check(int(corporate.milestone_level) == 4, "Corporate milestone restores")

    game.free()
    await process_frame
    print("CORPORATE SAVE BOUNDARY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
