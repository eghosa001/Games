extends SceneTree

const VisualState = preload("res://scripts/restora_3d_visual_state.gd")
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    check("neglected stage maps to neglected", VisualState.stage_from_values(false, "Neglected", 0, 0, 0, 0) == "neglected")
    check("finished restoration maps to operational", VisualState.stage_from_values(true, "Operational", 100, 100, 100, 100) == "operational")
    check("finished progress overrides stale label", VisualState.stage_from_values(true, "Painted", 100, 100, 100, 100) == "operational")
    check("factory property maps to factory archetype", VisualState.archetype_from_property({"type": "industrial_factory"}) == "factory")
    check("empty property falls back to warehouse", VisualState.archetype_from_property({}) == "warehouse")
    var snapshot := VisualState.snapshot_from_values({}, false, "Neglected", 0, 0, 0, 0, false, 0)
    check("empty catalog snapshot is safe", snapshot.get("archetype") == "warehouse" and snapshot.get("stage") == "neglected")
    print("RESTORA 3D VISUAL STATE: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
