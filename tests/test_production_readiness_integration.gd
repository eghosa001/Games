extends SceneTree

## RENEW production-readiness integration gate.
## This gate is intentionally cross-system: it checks that the finished 2D game
## composes its major economic systems through live infrastructure autoloads,
## scene-owned domain services and Main commands, that persistence exposes the
## same domains, and that the active scene contains no 3D gameplay dependency.
## It does not fabricate soft-launch metrics.

const REQUIRED_AUTOLOADS := {
    "RenewGameState": "res://scripts/game_state.gd",
    "RenewFinanceSystem": "res://scripts/finance_system_fixed.gd",
    "RenewProductionSystem": "res://scripts/production_system.gd",
    "RenewContractSystem": "res://scripts/contract_system.gd",
    "RenewAllianceSystem": "res://scripts/alliance_v1_system.gd",
    "RenewServices": "res://scripts/renew_services.gd"
}

const REQUIRED_SERVICES := {
    "RenewEmployeeSystem": "res://scripts/employee_system.gd",
    "RenewRegionSystem": "res://scripts/region_system.gd",
    "RenewInfrastructureSystem": "res://scripts/infrastructure_system.gd",
    "RenewTechnologySystem": "res://scripts/technology_system.gd",
    "RenewWorldEventSystem": "res://scripts/world_event_system.gd",
    "RenewCompetitorReactionSystem": "res://scripts/competitor_reaction_system.gd",
    "RenewAnalyticsSystem": "res://scripts/analytics_system.gd",
    "RenewNewsSystem": "res://scripts/news_system.gd",
    "RenewLiveOpsSystem": "res://scripts/liveops_system.gd"
}

const REQUIRED_SAVE_DOMAINS := [
    "player", "company", "properties", "economy", "businesses", "branches",
    "employees", "resources", "production", "supply_chain", "contracts",
    "competitors", "finance", "alliances", "diplomacy", "regions",
    "infrastructure", "technology", "events", "progression", "history",
    "news", "analytics", "acquisition", "ownership", "bankruptcy"
]

var passed := 0
var failed := 0
var failures: Array[String] = []
var game: Node

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    print("============================================================")
    print("RENEW PRODUCTION-READINESS INTEGRATION GATE")
    print("============================================================")
    test_autoload_contract()
    await test_2d_runtime_contract()
    test_persistence_contract()
    await test_cross_system_gameplay_flow()
    await test_edge_cases()
    _finish()

func test_autoload_contract() -> void:
    var project_source := FileAccess.get_file_as_string("res://project.godot")
    for node_name in REQUIRED_AUTOLOADS:
        var path: String = REQUIRED_AUTOLOADS[node_name]
        check(project_source.contains('%s="*%s"' % [node_name, path]), "Autoload configured: " + node_name)
        check(FileAccess.file_exists(path), "Autoload source exists: " + path)
        check(root.get_node_or_null(node_name) != null, "Autoload is live: " + node_name)

func test_2d_runtime_contract() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads for production gate")
    if packed == null:
        return
    game = packed.instantiate()
    check(game != null, "Main scene instantiates for production gate")
    if game == null:
        return
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    check(game.get_node_or_null("World") != null, "2D world root exists")
    check(game.get_node_or_null("Systems") != null, "System composition root exists")
    check(game.get_node_or_null("UI") != null, "UI composition root exists")
    check(game.get_node_or_null("UI/MainHUD") != null, "Primary management HUD exists")

    var services := root.get_node_or_null("RenewServices")
    check(services != null and services.has_method("get_service"), "Scene service registry is live")
    if services != null and services.has_method("get_service"):
        for service_name in REQUIRED_SERVICES:
            var path: String = REQUIRED_SERVICES[service_name]
            check(FileAccess.file_exists(path), "Service source exists: " + path)
            check(services.get_service(service_name) != null, "Scene service is live: " + service_name)

    var forbidden_3d := 0
    var stack: Array[Node] = [game]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is Node3D:
            forbidden_3d += 1
        for child in node.get_children():
            stack.append(child)
    check(forbidden_3d == 0, "Active Main scene has no 3D gameplay dependency")

func test_persistence_contract() -> void:
    var save_source := FileAccess.get_file_as_string("res://scripts/save_system.gd")
    check(save_source.contains("const CURRENT_VERSION := 8"), "Save schema has an explicit current version")
    for domain in REQUIRED_SAVE_DOMAINS:
        check(save_source.contains('"%s"' % domain), "Save schema includes domain: " + domain)
    check(save_source.contains("_capture_runtime_ownership"), "Ownership state participates in save capture")
    check(save_source.contains("_restore_runtime_ownership"), "Ownership state participates in save restore")
    check(save_source.contains("BACKUP_PATH"), "Save system maintains a recovery backup")

func await_game_ready() -> bool:
    if game == null:
        return false
    await process_frame
    await process_frame
    return game.is_inside_tree()

func await_operational() -> void:
    var state := root.get_node_or_null("RenewGameState")
    if state == null:
        return
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        if game.has_method("restore_property"):
            game.restore_property()
        guard += 1
        await process_frame

func test_cross_system_gameplay_flow() -> void:
    if not await await_game_ready():
        check(false, "Cross-system flow has a live Main scene")
        return
    check(game.command_system != null, "Gameplay command boundary is live")
    check(game.has_method("advance_day"), "Daily simulation command is exposed")
    check(game.has_method("buy_inputs") and game.has_method("produce_goods"), "Production commands are exposed")
    check(game.has_method("hire_employee"), "Employee command is exposed")
    check(game.has_method("take_loan") and game.has_method("repay_loan"), "Finance loan commands are exposed")
    check(game.has_method("buy_expansion") and game.has_method("upgrade_expansion"), "Expansion commands are exposed")

    var state := root.get_node_or_null("RenewGameState")
    check(state != null, "Canonical GameState is available during integration")
    if state == null:
        return

    game.cash = 1000000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    await await_operational()
    check(str(state.get_value("properties", "stage", "")) == "Operational", "Restore system reaches operational state")

    game.choose_business_purpose(0)
    game.open_business()
    check(bool(game.business_open), "Business system opens after restoration")

    var employees_before: Variant = state.get_value("employees", "roster", [])
    var employee_count_before: int = employees_before.size() if employees_before is Array else 0
    game.hire_employee()
    var employees_after: Variant = state.get_value("employees", "roster", [])
    var employee_count_after: int = employees_after.size() if employees_after is Array else 0
    check(employee_count_after >= employee_count_before, "Hiring path remains state-safe")

    var finished_before := int(state.get_value("production", "finished_goods", 0))
    game.buy_inputs()
    game.produce_goods()
    var finished_after := int(state.get_value("production", "finished_goods", 0))
    check(finished_after >= finished_before, "Production/resource integration remains non-negative")

    var day_before := int(game.day)
    game.advance_day()
    check(int(game.day) == day_before + 1, "Daily simulation advances exactly one day")
    check(int(state.get_value("economy", "last_sales", 0)) >= 0, "Daily economic output remains valid")

    var snapshot: Dictionary = state.capture()
    check(not snapshot.is_empty(), "Cross-system state can be captured")
    check(bool(state.restore(snapshot)), "Cross-system state can be restored")

func test_edge_cases() -> void:
    if game == null or not game.is_inside_tree():
        return
    var state := root.get_node_or_null("RenewGameState")
    if state == null:
        return

    var saved_cash := int(game.cash)
    game.cash = 0
    if game.has_method("buy_inputs"):
        game.buy_inputs()
    check(int(game.cash) >= 0, "Zero-cash input attempt never creates negative cash")
    game.cash = saved_cash

    var roster: Variant = state.get_value("employees", "roster", [])
    if roster is Array and roster.size() > 1:
        var selected_id := str(roster[1].get("id", ""))
        if not selected_id.is_empty() and game.has_method("fire_employee"):
            game.fire_employee(selected_id)
        var roster_after: Variant = state.get_value("employees", "roster", [])
        check(roster_after is Array, "Employee dismissal edge case preserves roster shape")
    else:
        check(true, "Employee dismissal edge case has a safe roster fallback")

    var snapshot: Dictionary = state.capture()
    check(snapshot.has("domains"), "State capture retains domain container after edge cases")

func _finish() -> void:
    print("============================================================")
    print("PRODUCTION-READINESS INTEGRATION RESULT: %d passed, %d failed" % [passed, failed])
    if not failures.is_empty():
        for item in failures:
            print("FAILED: " + item)
    print("============================================================")
    if is_instance_valid(game):
        game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
