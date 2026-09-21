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
    check("early furnishing stays painted", VisualState.stage_from_values(true, "Furnished", 100, 100, 100, 25) == "painted")
    check("half furnishing becomes furnished", VisualState.stage_from_values(true, "Painted", 100, 100, 100, 50) == "furnished")
    check("factory property maps to factory archetype", VisualState.archetype_from_property({"type": "industrial_factory"}) == "factory")
    check("workshop catalog type maps to factory archetype", VisualState.archetype_from_property({"type": "Workshop", "name": "Foundry Workshop"}) == "factory")
    check("commercial catalog type maps to retail archetype", VisualState.archetype_from_property({"type": "Commercial Building", "name": "Main Street Building"}) == "retail")
    check("named commercial offices map to office archetype", VisualState.archetype_from_property({"type": "Commercial Building", "name": "Riverside Offices"}) == "office")
    check("empty property falls back to warehouse", VisualState.archetype_from_property({}) == "warehouse")
    var snapshot := VisualState.snapshot_from_values({}, false, "Neglected", 0, 0, 0, 0, false, 0)
    check("empty catalog snapshot is safe", snapshot.get("archetype") == "warehouse" and snapshot.get("stage") == "neglected")

    var state := FakeState.new()
    state.values = {
        "properties": {
            "selected_property": 1,
            "owned": false,
            "stage": "Operational",
            "catalog": [
                {"id":"a", "name":"A", "owned":false},
                {"id":"b", "name":"B", "type":"factory", "owned":true, "cleaning":100, "repair":100, "painting":100, "furnishing":100}
            ]
        },
        "businesses": {"business_open": true, "origin_property_id":"a", "capacity_level":3, "marketing_level":2},
        "employees": {"roster":[{"id":"e1"},{"id":"e2"},{"id":"e3"},{"id":"e4"},{"id":"e5"}]},
        "production": {"finished_goods":12},
        "economy": {"last_sales":7, "total_profit":2400},
        "player": {"day":8, "reputation":64}
    }
    var selected_snapshot := VisualState.snapshot_from_game_state(state)
    check("selected property owns its 3D state", selected_snapshot.get("owned") == true and selected_snapshot.get("stage") == "operational")
    check("open activity stays on origin property", selected_snapshot.get("business_open") == false)
    state.values["businesses"]["origin_property_id"] = "b"
    selected_snapshot = VisualState.snapshot_from_game_state(state)
    check("origin property enables operating visuals", selected_snapshot.get("business_open") == true)
    check("live company activity raises visual tier", int(selected_snapshot.get("activity_tier", 0)) == 3)
    check("live staffing drives visible worker pool", int(selected_snapshot.get("worker_visual_count", 0)) == 5)
    check("sales and marketing drive district traffic", int(selected_snapshot.get("traffic_level", 0)) == 3)
    check("snapshot carries authoritative day and reputation", int(selected_snapshot.get("day", 0)) == 8 and int(selected_snapshot.get("reputation", 0)) == 64)
    state.free()

    print("RESTORA 3D VISUAL STATE: %s" % ("PASS" if failed == 0 else "FAIL"))
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
