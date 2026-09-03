extends RefCounted

const SaveSystem = preload("res://scripts/save_system.gd")

static func run() -> void:
    var v1 := {"schema_version": 1}
    v1 = SaveSystem.migrate(v1, 1)
    assert(v1["schema_version"] == 2)
    v1 = SaveSystem.migrate(v1, 2)
    assert(v1["schema_version"] == 3)
    v1 = SaveSystem.migrate(v1, 3)
    assert(v1["schema_version"] == 4)
    assert(v1["employees"]["roster"] is Array)
    v1 = SaveSystem.migrate(v1, 4)
    assert(v1["schema_version"] == 5)
    v1 = SaveSystem.migrate(v1, 5)
    assert(v1["schema_version"] == 6)
    v1 = SaveSystem.migrate(v1, 6)
    assert(v1["schema_version"] == 7)
    v1 = SaveSystem.migrate(v1, 7)
    assert(v1["schema_version"] == 8)
    assert(v1["domains"] is Dictionary)
    assert(v1["domains"].has("history"))
    assert(v1["domains"].has("news"))
    print("PHASE 33 MIGRATION TESTS PASSED")
