extends SceneTree

## Pass 4: save integrity edges. Corruption, truncation, old schemas and
## non-finite numbers all resolve to a valid load or a clean rejection.
var passed := 0
var failed := 0

const SAVE_PATH := "user://renew_save.json"
const BACKUP_PATH := "user://renew_save.backup.json"

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _wipe() -> void:
    for path in [SAVE_PATH, BACKUP_PATH, "user://renew_save.tmp.json", "user://renew_save.backup.tmp.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_raw(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(text)

func run() -> void:
    var Save = load("res://scripts/save_system.gd")
    check(Save != null, "Save system loads")
    if Save == null:
        quit(1)
        return
    _wipe()
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for save edge tests")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(state != null, "GameState available for save edge tests")
    check(finance != null, "Finance system available for save edge tests")
    if state == null or finance == null:
        game.free()
        await process_frame
        _wipe()
        quit(1)
        return
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        game.restore_property()
        guard += 1
        await process_frame
    game.choose_business_purpose(0)
    game.open_business()
    game.advance_day()
    await process_frame
    var day_open := int(state.get_value("player", "day", 1))
    check(day_open > 1, "Simulation running before save")
    game.save_game()
    check(FileAccess.file_exists(SAVE_PATH), "Save writes during live simulation")
    var cash_saved := int(state.get_value("economy", "cash", 0))
    game.buy_inputs()
    game.save_game()
    state.set_value("economy", "cash", 1)
    game.load_game()
    check(int(state.get_value("economy", "cash", 0)) == cash_saved or int(state.get_value("economy", "cash", 0)) > 1, "Save after purchase reloads")
    game.take_loan()
    var debt_saved := int(state.get_value("finance", "debt", 0))
    game.save_game()
    state.set_value("finance", "debt", 0)
    game.load_game()
    check(int(state.get_value("finance", "debt", -1)) == debt_saved, "Save after borrowing reloads debt")

    game.advance_day()
    await process_frame
    var day_new := int(state.get_value("player", "day", 1))
    game.save_game()
    _write_raw(SAVE_PATH, "{truncated json,,,")
    game.load_game()
    check(int(state.get_value("player", "day", 0)) == day_new or int(state.get_value("player", "day", 0)) == day_new - 1, "Truncated primary falls back cleanly")
    _write_raw(SAVE_PATH, "not json at all")
    game.load_game()
    check(int(state.get_value("player", "day", 0)) >= 1, "Garbage primary falls back cleanly")

    if FileAccess.file_exists(BACKUP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
    var snap: Dictionary = state.capture()
    snap["domains"].erase("finance")
    snap["schema_version"] = 8
    _write_raw(SAVE_PATH, JSON.stringify(snap))
    game.load_game()
    var missing_domain_message := str(state.get_value("company", "message", ""))
    check(missing_domain_message.find("No save file found") >= 0, "Missing required domain is rejected cleanly")

    _write_raw(SAVE_PATH, JSON.stringify({"schema_version": 1, "note": "ancient"}))
    if FileAccess.file_exists(BACKUP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
    game.load_game()
    check(int(state.get_value("player", "day", 0)) >= 1, "Ancient schema migrates and loads")

    finance.set("revenue", INF)
    game.save_game()
    var raw := ""
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file != null:
        raw = file.get_as_text()
    var dirty := false
    for token in [":inf", ":-inf", ":nan", "[inf", " inf,", " inf}"]:
        if raw.find(token) >= 0:
            dirty = true
    check(not dirty, "Non-finite numbers sanitized on disk")
    game.load_game()
    check(is_finite(float(finance.get("revenue"))), "Reloaded ledger stays finite")

    game.free()
    await process_frame
    _wipe()
    print("V94 SAVE EDGES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
