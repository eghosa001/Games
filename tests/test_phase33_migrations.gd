extends SceneTree

const SaveSystem = preload("res://scripts/save_system.gd")

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var v1 := {"schema_version": 1}
    v1 = SaveSystem.migrate(v1, 1)
    check(v1["schema_version"] == 2, "Migration v1 -> v2")
    v1 = SaveSystem.migrate(v1, 2)
    check(v1["schema_version"] == 3, "Migration v2 -> v3")
    v1 = SaveSystem.migrate(v1, 3)
    check(v1["schema_version"] == 4, "Migration v3 -> v4")
    v1 = SaveSystem.migrate(v1, 4)
    check(v1["schema_version"] == 5, "Migration v4 -> v5")
    v1 = SaveSystem.migrate(v1, 5)
    check(v1["schema_version"] == 6, "Migration v5 -> v6")
    v1 = SaveSystem.migrate(v1, 6)
    check(v1["schema_version"] == 7, "Migration v6 -> v7")
    v1 = SaveSystem.migrate(v1, 7)
    check(v1["schema_version"] == 8, "Migration v7 -> v8")
    check(v1.has("domains"), "v8 has domains")
    check(v1["domains"] is Dictionary, "v8 domains is Dictionary")
    check(v1["domains"].has("history"), "v8 domains has history")
    check(v1["domains"].has("news"), "v8 domains has news")
    print("PHASE 33 MIGRATION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
