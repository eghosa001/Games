extends SceneTree

## Phase 24 smoke/invariant tests for basic V1 alliances: membership,
## invitations, chat, treasury contributions, cooperative projects and rewards.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var AllianceSystem = load("res://scripts/alliance_v1_system.gd")
    check(AllianceSystem != null, "Alliance system loads")
    if AllianceSystem == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        finance.cash = 60000
        finance.debt = 0
        finance.financing = {}
        finance.equity_contributed = 60000.0
        finance.retained_earnings = 0.0
    var system: Node = AllianceSystem.new()
    root.add_child(system)
    await process_frame
    var created: Dictionary = system.create_alliance("Renew Builders")
    check(bool(created.get("ok", false)), "Alliance created")
    var id := str(created.get("alliance", {}).get("id", ""))
    check(not id.is_empty(), "Alliance has an id")
    check(bool(system.invite_member(id, "player", "member_1").get("ok", false)), "Member invited")
    check(bool(system.join_alliance(id, "member_1").get("ok", false)), "Member joined")
    check(bool(system.post_message(id, "member_1", "Ready to build together.").get("ok", false)), "Message posted")
    var cash_before := int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash)
    check(bool(system.donate_money("player", 1000).get("ok", false)), "Money donated")
    var started: Dictionary = system.start_cooperative_project("player")
    check(bool(started.get("ok", false)), "Cooperative railway project started")
    check(str(started.get("project", {}).get("id", "")) == "regional_railway", "Cooperative project is the regional railway")
    var project_cash_before := int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash)
    var contributed: Dictionary = system.contribute_to_railway("player", 1000, 0, 0, 10)
    check(bool(contributed.get("ok", false)), "Member contribution recorded")
    check(int(contributed.get("project", {}).get("contributed", {}).get("money", -1)) == 1000, "Money contribution tracked")
    check(int(contributed.get("project", {}).get("contributed", {}).get("project_points", -1)) == 10, "Project points tracked")
    check(str(contributed.get("project", {}).get("status", "")) == "active", "Railway still needs full funding")
    var alliance: Dictionary = system.get_alliance(id)
    check(int(alliance.get("members", {}).size()) == 2, "Alliance has 2 members")
    check(int(alliance.get("chat", []).size()) == 1, "Alliance has 1 chat message")
    check(int(alliance.get("treasury", -1)) == 1000, "Treasury holds the donation")
    var spent := cash_before - (int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash))
    check(spent == 2000, "Donation plus railway contribution spent cash")
    check(project_cash_before - (int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash)) == 1000, "Railway contribution spent cash")
    check(bool(system.leave_alliance("member_1").get("ok", false)), "Member left alliance")
    var after_leave: Dictionary = system.get_alliance(id)
    check(not after_leave.get("members", {}).has("member_1"), "Member is gone after leaving")
    print("PHASE 24 ALLIANCE RESULT: %d passed, %d failed" % [passed, failed])
    system.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
