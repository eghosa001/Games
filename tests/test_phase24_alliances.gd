extends SceneTree

## Phase 24 smoke/invariant tests. Run with the Godot test harness when available.
const AllianceSystem = preload("res://scripts/alliance_v1_system.gd")

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
    var state = get_node_or_null("/root/RenewGameState")
    var system := AllianceSystem.new()
    if state == null:
        print("PHASE 24 ALLIANCE RESULT: 0 passed, 1 failed (GameState unavailable)")
        quit(1)
        return
    root.add_child(system)
    state.clear()
    var created := system.create_alliance("Renew Builders")
    check(created.get("ok", false), "Alliance created")
    var id := str(created["alliance"]["id"])
    check(system.invite_member(id, "player", "member_1").get("ok", false), "Member invited")
    check(system.join_alliance(id, "member_1").get("ok", false), "Member joined")
    check(system.post_message(id, "member_1", "Ready to build together.").get("ok", false), "Message posted")
    check(system.donate_money("player", 1000).get("ok", false), "Money donated")
    check(system.start_cooperative_project("player", "Shared Workshop").get("ok", false), "Project started")
    check(system.contribute_to_project("player").get("ok", false), "Player contributed")
    var completed := system.contribute_to_project("member_1")
    check(completed.get("ok", false), "Member contributed and completed")
    var alliance := system.get_alliance(id)
    check(alliance["members"].size() == 2, "Alliance has 2 members")
    check(alliance["chat"].size() == 1, "Alliance has 1 chat message")
    check(alliance["projects"][0]["status"] == "complete", "Project completed")
    check(int(alliance["treasury"]) == 2500, "Treasury is 2500")
    check(int(state.get_value("economy", "cash", 0)) == 24000, "Player cash is 24000")
    check(system.leave_alliance("member_1").get("ok", false), "Member left alliance")
    print("PHASE 24 ALLIANCE RESULT: %d passed, %d failed" % [passed, failed])
    system.queue_free()
    quit(1 if failed > 0 else 0)
