extends Node

## Phase 24 smoke/invariant tests. Run with the Godot test harness when available.
const AllianceSystem = preload("res://scripts/alliance_v1_system.gd")

func run_phase24_tests() -> Dictionary:
    var state = get_node_or_null("/root/RenewGameState")
    var system := AllianceSystem.new()
    if state == null:
        return {"ok": false, "message": "GameState unavailable."}
    add_child(system)
    state.clear()
    var created := system.create_alliance("Renew Builders")
    assert(created.get("ok", false))
    var id := str(created["alliance"]["id"])
    assert(system.invite_member(id, "player", "member_1").get("ok", false))
    assert(system.join_alliance(id, "member_1").get("ok", false))
    assert(system.post_message(id, "member_1", "Ready to build together.").get("ok", false))
    assert(system.donate_money("player", 1000).get("ok", false))
    assert(system.start_cooperative_project("player", "Shared Workshop").get("ok", false))
    assert(system.contribute_to_project("player").get("ok", false))
    var completed := system.contribute_to_project("member_1")
    assert(completed.get("ok", false))
    var alliance := system.get_alliance(id)
    assert(alliance["members"].size() == 2)
    assert(alliance["chat"].size() == 1)
    assert(alliance["projects"][0]["status"] == "complete")
    assert(int(alliance["treasury"]) == 2500)
    assert(int(state.get_value("economy", "cash", 0)) == 24000)
    assert(system.leave_alliance("member_1").get("ok", false))
    return {"ok": true, "message": "Phase 24 V1 alliance tests passed."}
