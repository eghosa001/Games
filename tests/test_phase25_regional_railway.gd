extends Node

## Phase 25 regression tests. Requires the Godot project runtime to execute.
const AllianceSystem = preload("res://scripts/alliance_v1_system.gd")

func _ready() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    assert(state != null)
    assert(float(state.get_value("supply_chain", "transport_cost_multiplier", 1.0)) == 1.0)
    assert(float(state.get_value("supply_chain", "resource_delivery_multiplier", 1.0)) == 1.0)
    assert(int(state.get_value("regions", "regional_reputation", 0)) == 0)

    var system := AllianceSystem.new()
    add_child(system)
    var created := system.create_alliance("Regional Builders")
    assert(bool(created.get("ok", false)))
    var alliance_id := str(created["alliance"]["id"])

    var started := system.start_cooperative_project("player")
    assert(bool(started.get("ok", false)))
    var project: Dictionary = started["project"]
    assert(str(project["id"]) == "regional_railway")
    assert(int(project["requirements"]["money"]) == 1000000)
    assert(int(project["requirements"]["steel"]) == 500)
    assert(int(project["requirements"]["timber"]) == 100)
    assert(int(project["requirements"]["project_points"]) == 100)

    state.set_value("economy", "cash", 1000000)
    state.set_value("resources", "resources", {"steel": 500, "timber": 100})
    var contribution := system.contribute_to_railway("player", 1000000, 500, 100, 100)
    assert(bool(contribution.get("ok", false)))
    assert(str(contribution["project"]["status"]) == "complete")
    assert(float(state.get_value("supply_chain", "transport_cost_multiplier", 1.0)) == 0.90)
    assert(float(state.get_value("supply_chain", "resource_delivery_multiplier", 1.0)) == 1.10)
    assert(int(state.get_value("regions", "regional_reputation", 0)) == 5)
    assert(str(system.get_alliance(alliance_id)["projects"][0]["id"]) == "regional_railway")
    queue_free()
