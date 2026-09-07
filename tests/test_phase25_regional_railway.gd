extends SceneTree

## Phase 25 regression tests for the regional railway cooperative project.
const AllianceSystem = preload("res://scripts/alliance_v1_system.gd")

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
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    check(float(state.get_value("supply_chain", "transport_cost_multiplier", 1.0)) == 1.0, "Transport multiplier starts at baseline")
    check(float(state.get_value("supply_chain", "resource_delivery_multiplier", 1.0)) == 1.0, "Delivery multiplier starts at baseline")
    check(int(state.get_value("regions", "regional_reputation", 0)) == 0, "Regional reputation starts at zero")

    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        finance.financing = {}
        finance.debt = 0
        finance.loan_payment = 0
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
        finance.retained_earnings = 0.0
        finance.equity_contributed = 1000000.0
        finance.cash = 1000000

    var system: Node = AllianceSystem.new()
    root.add_child(system)
    await process_frame
    var created: Dictionary = system.create_alliance("Regional Builders")
    check(bool(created.get("ok", false)), "Alliance created")
    var alliance_id := str(created.get("alliance", {}).get("id", ""))
    check(not alliance_id.is_empty(), "Alliance has an id")

    var started: Dictionary = system.start_cooperative_project("player")
    check(bool(started.get("ok", false)), "Railway project started")
    var project: Dictionary = started.get("project", {})
    check(str(project.get("id", "")) == "regional_railway", "Project is the regional railway")
    check(int(project.get("requirements", {}).get("money", 0)) == 1000000, "Railway requires money")
    check(int(project.get("requirements", {}).get("steel", 0)) == 500, "Railway requires steel")
    check(int(project.get("requirements", {}).get("timber", 0)) == 100, "Railway requires timber")
    check(int(project.get("requirements", {}).get("project_points", 0)) == 100, "Railway requires project points")

    state.set_value("resources", "resources", {"steel": 499, "timber": 100})
    var before_cash := int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash)
    var failed_contribution: Dictionary = system.contribute_to_railway("player", 1000000, 500, 100, 100)
    check(not bool(failed_contribution.get("ok", false)), "Short contribution is rejected")
    var after_cash := int(state.get_value("economy", "cash", 0)) if finance == null else int(finance.cash)
    check(after_cash == before_cash, "Rejected contribution spends nothing")
    var after_failed: Dictionary = system.get_alliance(alliance_id).get("projects", [{}])[0].get("contributed", {})
    check(int(after_failed.get("money", -1)) == 0, "Rejected money not recorded")
    check(int(after_failed.get("steel", -1)) == 0, "Rejected steel not recorded")
    check(int(after_failed.get("timber", -1)) == 0, "Rejected timber not recorded")
    check(int(after_failed.get("project_points", -1)) == 0, "Rejected points not recorded")

    state.set_value("resources", "resources", {"steel": 500, "timber": 100})
    var contribution: Dictionary = system.contribute_to_railway("player", 1000000, 500, 100, 100)
    check(bool(contribution.get("ok", false)), "Full contribution succeeds")
    check(str(contribution.get("project", {}).get("status", "")) == "complete", "Railway completes on full funding")
    check(float(state.get_value("supply_chain", "transport_cost_multiplier", 1.0)) == 0.90, "Railway cuts transport costs")
    check(float(state.get_value("supply_chain", "resource_delivery_multiplier", 1.0)) == 1.10, "Railway boosts delivery")
    check(int(state.get_value("regions", "regional_reputation", 0)) == 5, "Railway grants regional reputation")
    check(str(system.get_alliance(alliance_id).get("projects", [{}])[0].get("id", "")) == "regional_railway", "Railway project persists")
    print("PHASE 25 RESULT: %d passed, %d failed" % [passed, failed])
    system.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
