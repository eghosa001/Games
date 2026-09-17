extends SceneTree

const VisualState = preload("res://scripts/restora_3d_visual_state.gd")
var failed := 0

class FakeState extends Node:
    var values := {}
    func get_value(section: String, key: String, fallback = null):
        return values.get(section, {}).get(key, fallback)

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

    var state := FakeState.new()
    state.values = {
        "properties": {
            "selected_property": 1,
            "owned": false,
            "stage": "Neglected",
            "catalog": [
                {"name":"A", "owned":false},
                {"name":"B", "type":"factory", "owned":true, "cleaning":100, "repair":100, "painting":100, "furnishing":100}
            ]
        },
        "businesses": {"business_open": true}
    }
    var selected_snapshot := VisualState.snapshot_from_game_state(state)
    check("selected property owns its 3D state", selected_snapshot.get("owned") == true and selected_snapshot.get("stage") == "operational")
    state.free()

    print("RESTORA 3D VISUAL STATE: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
