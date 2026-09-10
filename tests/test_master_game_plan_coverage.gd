extends SceneTree

## RENEW MASTER GAME-PLAN COVERAGE GATE
## Source basis: game-plan.txt, game-plan-revised.txt and UI.txt.
## Purpose: one executable acceptance gate spanning the documented development
## phases, V0/V1/V1.5/V2/V3 roadmap, gameplay pillars, retention, LiveOps,
## authoritative-system integration, persistence and responsive presentation.
## Future-only systems are tested as roadmap readiness rather than fabricated
## gameplay: the gate never creates fake state just to make a future phase pass.

const MOBILE_TARGETS := [Vector2i(320, 568), Vector2i(360, 640), Vector2i(390, 844), Vector2i(412, 915)]
const DESKTOP_TARGETS := [Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]
const REQUIRED_SYSTEMS := {
    "RenewGameState": "res://scripts/game_state.gd",
    "RenewFinanceSystem": "res://scripts/finance_system_fixed.gd",
    "RenewProductionSystem": "res://scripts/production_system.gd",
    "RenewContractSystem": "res://scripts/contract_system.gd",
    "RenewAllianceSystem": "res://scripts/alliance_v1_system.gd",
    "RenewReputationSystem": "res://scripts/reputation_system.gd",
    "RenewInfrastructureSystem": "res://scripts/infrastructure_system.gd",
    "RenewTechnologySystem": "res://scripts/technology_system.gd",
    "RenewEmployeeSystem": "res://scripts/employee_system.gd",
    "RenewCompanyCultureSystem": "res://scripts/company_culture_system.gd",
    "RenewGlobalRankingSystem": "res://scripts/global_ranking_system.gd",
    "RenewWorldEventSystem": "res://scripts/world_event_system.gd",
    "RenewLiveOpsSystem": "res://scripts/liveops_system.gd",
    "RenewNewsSystem": "res://scripts/news_system.gd",
    "RenewHistorySystem": "res://scripts/history_system.gd",
    "RenewCollectionSystem": "res://scripts/collection_system.gd",
    "RenewHeadquartersSystem": "res://scripts/headquarters_system.gd",
    "RenewCompetitorReactionSystem": "res://scripts/competitor_reaction_system.gd"
}

var passed := 0
var failed := 0
var skipped := 0
var failures: Array[String] = []
var skips: Array[String] = []
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

func skip(label: String) -> void:
    skipped += 1
    skips.append(label)
    print("SKIP (roadmap/future): " + label)

func _system(node_name: String) -> Node:
    var direct := root.get_node_or_null(node_name)
    if direct != null:
        return direct
    var services := root.get_node_or_null("RenewServices")
    if services != null and services.has_method("get_service"):
        return services.get_service(node_name)
    return null

func _dispose_game(g: Node) -> void:
    if g != null and is_instance_valid(g):
        g.free()
    game = null
    current_scene = null
    await process_frame

func run() -> void:
    print("============================================================")
    print("RENEW MASTER GAME-PLAN COVERAGE GATE")
    print("============================================================")
    await test_phase_1_core_prototype()
    await test_phase_2_vertical_slice()
    await test_phase_3_closed_alpha()
    await test_phase_4_v1_production()
    await test_phase_5_soft_launch()
    await test_phase_6_global_launch()
    await test_v0_to_v3_roadmap()
    await test_five_pillars_and_player_journey()
    await test_retention_and_session_structure()
    await test_authoritative_integration_and_persistence()
    await test_responsive_ui_contract()
    await test_runtime_stability()
    finish()

func _new_game() -> Node:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        return null
    game = packed.instantiate()
    check(game != null, "Main scene instantiates")
    if game == null:
        return null
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    return game

func test_phase_1_core_prototype() -> void:
    var g := await _new_game()
    if g == null:
        return
    check(g.has_method("inspect_property"), "Phase 1: inspect command exists")
    check(g.has_method("acquire_property"), "Phase 1: acquire command exists")
    check(g.has_method("restore_property"), "Phase 1: restore command exists")
    check(g.has_method("open_business"), "Phase 1: business command exists")
    check(g.has_method("advance_day"), "Phase 1: revenue/day progression exists")
    g.cash = 500000
    g.inspect_property()
    check(bool(g.inspected), "Phase 1: player can inspect the starting property")
    g.acquire_property()
    check(bool(g.owned), "Phase 1: player can acquire the starting property")
    for _i in range(8):
        g.restore_property()
        await process_frame
    check(str(g.stage) == "Operational" and int(g.restoration) >= 100, "Phase 1: restore reaches operational state")
    g.choose_business_purpose(0)
    g.open_business()
    check(bool(g.business_open), "Phase 1: restored property becomes a business")
    g.buy_inputs()
    g.produce_goods()
    var before_day := int(g.day)
    g.advance_day()
    check(int(g.day) > before_day, "Phase 1: business can progress through a day")
    check(int(g.cash) != 500000 or int(g.total_profit) != 0, "Phase 1: operation produces an economic consequence")
    await _dispose_game(g)

func test_phase_2_vertical_slice() -> void:
    var g := await _new_game()
    if g == null:
        return
    var state := _system("RenewGameState")
    check(state != null, "Phase 2: GameState available")
    check(g.expansion != null and g.expansion.properties.size() >= 3, "Phase 2: multiple property choices exist")
    check(g.command_system != null and g.command_system.business_system != null, "Phase 2: composed business system exists")
    check(_system("RenewEmployeeSystem") != null, "Phase 2: employee system exists")
    check(_system("RenewContractSystem") != null, "Phase 2: contract system exists")
    check(_system("RenewTechnologySystem") != null, "Phase 2: technology system exists")
    check(_system("RenewCompetitorReactionSystem") != null, "Phase 2: competitor reaction system exists")
    var hud := g.get_node_or_null("UI/MainHUD")
    check(hud != null, "Phase 2: playable management HUD exists")
    if hud != null:
        check(hud.has_method("_set_tab") and hud.has_method("_layout_responsive"), "Phase 2: navigation/responsive surface exists")
    await _dispose_game(g)

func test_phase_3_closed_alpha() -> void:
    var g := await _new_game()
    if g == null:
        return
    var analytics := _system("RenewAnalyticsSystem")
    check(analytics != null, "Phase 3: analytics/measurement system exists")
    check(_system("RenewHistorySystem") != null, "Phase 3: player history measurement surface exists")
    check(_system("RenewNewsSystem") != null, "Phase 3: player-facing world feedback exists")
    check(FileAccess.file_exists("res://tests/test_long_soak.gd"), "Phase 3: long-session stability test exists")
    check(FileAccess.file_exists("res://tests/test_extreme_soak.gd"), "Phase 3: extreme-session stability test exists")
    check(FileAccess.file_exists("res://tests/mobile_qa_test.gd"), "Phase 3: mobile QA automation exists")
    check(FileAccess.file_exists("res://tests/test_quality_gate.gd"), "Phase 3: release quality gate exists")
    check(analytics != null and (analytics.has_method("track") or analytics.has_method("_process")), "Phase 3: analytics system is a live node, not only a placeholder")
    await _dispose_game(g)

func test_phase_4_v1_production() -> void:
    var g := await _new_game()
    if g == null:
        return
    check(g.expansion != null and g.expansion.properties.size() >= 3, "Phase 4: at least 3 property slots/types are represented")
    check(g.economy != null, "Phase 4: economy is composed into Main")
    if g.economy != null:
        for resource in ["timber", "iron", "energy"]:
            check(g.economy.resources.has(resource), "Phase 4: canonical resource exists: " + resource)
    check(_system("RenewProductionSystem") != null, "Phase 4: production system")
    check(_system("RenewContractSystem") != null, "Phase 4: contracts")
    check(_system("RenewAllianceSystem") != null, "Phase 4: basic alliances")
    check(_system("RenewWorldEventSystem") != null, "Phase 4: dynamic world events")
    check(_system("RenewSeasonalRestorationSystem") != null, "Phase 4: seasonal restoration event")
    check(_system("RenewRegionSystem") != null, "Phase 4: one-region world model")
    check(_system("RenewGlobalRankingSystem") != null, "Phase 4: ranking/progression foundation")
    await _dispose_game(g)

func test_phase_5_soft_launch() -> void:
    check(FileAccess.file_exists("res://.github/workflows/godot-tests.yml"), "Phase 5: automated CI workflow exists")
    check(FileAccess.file_exists("res://tests/mobile_qa_test.gd"), "Phase 5: mobile/device-oriented QA gate exists")
    check(FileAccess.file_exists("res://MOBILE_QA.md") or FileAccess.file_exists("res://Docs/MOBILE_QA.md"), "Phase 5: mobile QA procedure is documented")
    check(FileAccess.file_exists("res://Docs/GAME_QUALITY_STANDARD.md"), "Phase 5: measurable quality standard exists")
    check(FileAccess.file_exists("res://tests/QUALITY_TEST_PROTOCOL.md"), "Phase 5: strict QA protocol exists")
    check(FileAccess.file_exists("res://tests/release/test_full_coverage.gd") or FileAccess.file_exists("res://tests/release/test_release_smoke.gd"), "Phase 5: release suite exists")
    var g := await _new_game()
    if g != null:
        if _system("RenewAnalyticsSystem") == null:
            skip("Real-player soft-launch metrics require the analytics service")
        await _dispose_game(g)

func test_phase_6_global_launch() -> void:
    var g := await _new_game()
    if g == null:
        return
    check(_system("RenewLiveOpsSystem") != null, "Phase 6: LiveOps system exists")
    check(g.get_node_or_null("UI/LiveOpsPanel") != null, "Phase 6: LiveOps UI exists")
    check(_system("RenewNewsSystem") != null, "Phase 6: recurring world/news surface exists")
    check(_system("RenewDynamicEventController") != null, "Phase 6: dynamic event controller exists")
    check(_system("RenewWorldEventSystem") != null, "Phase 6: world event system exists")
    check(_system("RenewSeasonalRestorationSystem") != null, "Phase 6: seasonal restoration content hook exists")
    check(_system("RenewGlobalRankingSystem") != null, "Phase 6: global ranking hook exists")
    await _dispose_game(g)

func test_v0_to_v3_roadmap() -> void:
    check(FileAccess.file_exists("res://tests/test_new_game_flow.gd") or FileAccess.file_exists("res://tests/test_runner.gd"), "V0: restore -> business -> revenue regression path exists")
    var v1_scripts := [
        "res://scripts/employee_system.gd", "res://scripts/contract_system.gd",
        "res://scripts/technology_system.gd", "res://scripts/region_system.gd",
        "res://scripts/alliance_v1_system.gd", "res://scripts/world_event_system.gd"
    ]
    for path in v1_scripts:
        check(FileAccess.file_exists(path), "V1: system file exists: " + path)
    var v15_candidates := [
        "res://scripts/acquisition_system.gd", "res://scripts/executive_system.gd",
        "res://scripts/ownership_system.gd", "res://scripts/investment_system.gd"
    ]
    var v15_present := 0
    for path in v15_candidates:
        if FileAccess.file_exists(path):
            v15_present += 1
    check(v15_present > 0 or FileAccess.file_exists("res://Docs/V1_IMPLEMENTATION.md"), "V1.5: expansion architecture or implementation documentation exists")
    check(_system("RenewFinanceSystem") != null, "V1.5: financial system foundation exists")
    var v2_candidates := [
        "res://scripts/joint_venture_system.gd", "res://scripts/trade_system.gd",
        "res://scripts/share_system.gd", "res://scripts/investment_system.gd",
        "res://scripts/diplomacy_system.gd", "res://scripts/diplomacy_ai.gd"
    ]
    var v2_present := 0
    for path in v2_candidates:
        if FileAccess.file_exists(path):
            v2_present += 1
    check(v2_present >= 2, "V2: multiple international/diplomacy/ownership expansion systems are present")
    var g := await _new_game()
    if g != null:
        var v3_found := 0
        for node_name in ["RenewGlobalRankingSystem", "RenewDiplomacySystem", "RenewInfrastructureSystem", "RenewLiveOpsSystem"]:
            if _system(node_name) != null:
                v3_found += 1
        check(v3_found >= 3, "V3: global-scale simulation foundations are present")
        await _dispose_game(g)

func test_five_pillars_and_player_journey() -> void:
    var g := await _new_game()
    if g == null:
        return
    g.cash = 1000000
    g.inspect_property(); g.acquire_property()
    check(bool(g.owned), "Pillar Restore/Build: property ownership is reachable")
    for _i in range(8):
        g.restore_property(); await process_frame
    check(str(g.stage) == "Operational", "Pillar Restore: property becomes operational")
    g.choose_business_purpose(0); g.open_business()
    check(bool(g.business_open), "Pillar Build: restored asset becomes business")
    g.buy_inputs(); g.produce_goods(); g.sign_contract()
    check(_system("RenewContractSystem") != null, "Pillar Compete: contract economy is available")
    check(_system("RenewCompetitorReactionSystem") != null, "Pillar Compete: competitor reaction system is available")
    check(_system("RenewAllianceSystem") != null, "Pillar Collaborate: alliance system is available")
    check(_system("RenewGlobalRankingSystem") != null, "Pillar Influence: ranking/influence foundation is available")
    await _dispose_game(g)

func test_retention_and_session_structure() -> void:
    var g := await _new_game()
    if g == null:
        return
    check(_system("RenewAutosave") != null, "Retention: autosave supports unfinished progression")
    check(_system("RenewNewsSystem") != null, "Retention: daily news surface")
    check(_system("RenewAllianceSystem") != null, "Retention: alliance activity surface")
    check(_system("RenewLiveOpsSystem") != null, "Retention: surprise/live event surface")
    check(_system("RenewProgressionSystem") != null, "Retention: long-term progression surface")
    check(_system("RenewHistorySystem") != null, "Retention: persistent journey/history surface")
    await _dispose_game(g)

func test_authoritative_integration_and_persistence() -> void:
    var g := await _new_game()
    if g == null:
        return
    for node_name in REQUIRED_SYSTEMS.keys():
        check(_system(node_name) != null, "Authoritative integration: system alive: " + node_name)
    check(g.command_system != null, "Authoritative integration: command boundary exists")
    check(g.economy != null, "Authoritative integration: economy is wired")
    check(g.expansion != null, "Authoritative integration: expansion is wired")
    var state := _system("RenewGameState")
    check(state != null and state.has_method("capture") and state.has_method("restore"), "Persistence: GameState capture/restore API exists")
    if state != null:
        var snapshot: Dictionary = state.capture()
        check(not snapshot.is_empty(), "Persistence: capture produces state")
        check(bool(state.restore(snapshot)), "Persistence: captured state restores")
    g.cash = 246810
    g.save_game()
    g.cash = 1
    g.load_game()
    check(int(g.cash) == 246810, "Persistence: Main save/load preserves authoritative cash")
    await _dispose_game(g)

func test_responsive_ui_contract() -> void:
    var g := await _new_game()
    if g == null:
        return
    var hud := g.get_node_or_null("UI/MainHUD")
    check(hud != null, "UI: MainHUD exists")
    if hud == null:
        await _dispose_game(g)
        return
    var ui_root := hud.get("root") as Control
    check(ui_root != null, "UI: responsive root Control exists")
    if ui_root != null:
        for target in MOBILE_TARGETS + DESKTOP_TARGETS:
            ui_root.size = Vector2(target)
            hud._layout_responsive()
            await process_frame
            check(ui_root.size.x >= target.x - 1 and ui_root.size.y >= target.y - 1, "UI: accepts viewport %dx%d" % [target.x, target.y])
            var tabs := hud.get("tabs") as Control
            if tabs != null:
                check(Rect2(Vector2.ZERO, Vector2(target)).encloses(Rect2(tabs.position, tabs.size)), "UI: navigation stays inside %dx%d" % [target.x, target.y])
                for child in tabs.get_children():
                    var button := child as Button
                    if button != null:
                        check(button.size.x >= 44 and button.size.y >= 44, "UI: tab touch target >=44px at %dx%d" % [target.x, target.y])
    check(hud.has_method("_set_tab"), "UI: deterministic tab switching API exists")
    await _dispose_game(g)

func test_runtime_stability() -> void:
    var g := await _new_game()
    if g == null:
        return
    var start_frames := Engine.get_process_frames()
    var start := Time.get_ticks_msec()
    while Time.get_ticks_msec() - start < 1500:
        await process_frame
    var elapsed := maxf(float(Time.get_ticks_msec() - start) / 1000.0, 0.001)
    var fps := float(Engine.get_process_frames() - start_frames) / elapsed
    check(fps >= 30.0, "Runtime: sustained sample >=30 FPS (%.1f)" % fps)
    check(g.is_inside_tree(), "Runtime: Main remains alive after stability sample")
    await _dispose_game(g)

func finish() -> void:
    print("============================================================")
    print("MASTER GAME-PLAN COVERAGE RESULT: %d passed, %d failed, %d roadmap skips" % [passed, failed, skipped])
    if not failures.is_empty():
        for item in failures:
            print("FAILED: " + item)
    if not skips.is_empty():
        for item in skips:
            print("ROADMAP: " + item)
    print("============================================================")
    quit(1 if failed > 0 else 0)
