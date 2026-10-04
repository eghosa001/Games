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
    var Script = load("res://scripts/world_intelligence_ui.gd")
    check(Script != null, "World Intelligence script loads")
    if Script == null:
        quit(1)
        return
    var ui = Script.new()

    var power := {
        "total": 60.0,
        "economic": 65.0,
        "industrial": 55.0,
        "technology": 50.0,
        "logistics": 58.0,
        "diplomatic": 62.0,
        "alliance": 64.0,
        "cultural": 66.0
    }
    var rows: Array = [{"id":"builder","title":"Builder","claimed":1,"total":3,"next":250.0}]
    var stories: Array = [{"id":"story_1","section":"World","headline":"Stable markets","body":"Demand remains firm.","kicker":"Desk"}]

    var baseline: String = str(ui._data_signature(12, 40, power, rows, stories))
    check(baseline == ui._data_signature(12, 40, power.duplicate(true), rows.duplicate(true), stories.duplicate(true)), "Identical intelligence content keeps one signature")

    var changed_power: Dictionary = power.duplicate(true)
    changed_power["economic"] = 70.0
    changed_power["industrial"] = 50.0
    check(float(changed_power["total"]) == float(power["total"]), "Power fixture preserves total score")
    check(ui._data_signature(12, 40, changed_power, rows, stories) != baseline, "Power dimension change invalidates intelligence cache")

    var changed_rows: Array = rows.duplicate(true)
    changed_rows[0]["claimed"] = 2
    check(changed_rows.size() == rows.size(), "Identity fixture preserves row count")
    check(ui._data_signature(12, 40, power, changed_rows, stories) != baseline, "Identity progress change invalidates intelligence cache")

    var changed_stories: Array = stories.duplicate(true)
    changed_stories[0]["headline"] = "Supply shock hits freight"
    check(changed_stories.size() == stories.size(), "News fixture preserves story count")
    check(ui._data_signature(12, 40, power, rows, changed_stories) != baseline, "Headline change invalidates intelligence cache")

    var changed_body: Array = stories.duplicate(true)
    changed_body[0]["body"] = "Demand weakened despite the same headline."
    check(ui._data_signature(12, 40, power, rows, changed_body) != baseline, "News body change invalidates intelligence cache")

    ui.free()
    print("WORLD INTELLIGENCE REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
# World Intelligence final validation scope: content-sensitive cache invalidation.
