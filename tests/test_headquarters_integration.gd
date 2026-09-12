extends SceneTree

## Headquarters must be more than a collectible building. This regression proves
## that paid HQ investment changes research/technology outcomes and feeds legacy.
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

func _set_finance_cash(finance: Node, target: int) -> void:
    var current := int(finance.available_cash())
    if current < target:
        finance.receive(target - current, "HQ integration test seed")
    elif current > target:
        finance.spend(current - target, "HQ integration test normalization")

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for headquarters integration")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var services = root.get_node_or_null("RenewServices")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var hq = services.get_service("RenewHeadquartersSystem") if services != null else null
    var research = services.get_service("RenewResearchSystem") if services != null else null
    var technology = services.get_service("RenewTechnologySystem") if services != null else null
    var legacy = services.get_service("RenewCorporateLegacy") if services != null else null
    check(finance != null and hq != null and research != null and technology != null, "HQ strategic dependency stack resolves")
    check(legacy != null, "Corporate legacy archive resolves")
    if finance == null or hq == null or research == null or technology == null:
        game.free()
        quit(1)
        return

    _set_finance_cash(finance, 500000)
    var baseline_cash := int(finance.available_cash())
    var before_baseline_research := int(finance.available_cash())
    var baseline_research: Dictionary = research.start_research("process_automation", "founder")
    check(bool(baseline_research.get("ok", false)), "Baseline founder research starts")
    check(int(finance.available_cash()) == before_baseline_research - 12000, "Company research charges authoritative finance up front")
    var baseline_duration := int(baseline_research.get("project", {}).get("duration", -1))
    var baseline_tech_days := int(technology.get_research_time_days("smart_factory"))
    check(baseline_duration == 4, "Research baseline is unchanged before HQ facilities")
    check(baseline_tech_days == 4, "Technology baseline is unchanged before Technology Center")

    var before_stage1 := int(finance.available_cash())
    var stage1: Dictionary = hq.upgrade_with_finance(finance, int(game.day))
    check(bool(stage1.get("ok", false)), "HQ upgrades to Headquarters stage")
    check(int(finance.available_cash()) == before_stage1 - int(stage1.get("cost", 0)), "HQ stage upgrade charges finance exactly once")

    var before_research_area := int(finance.available_cash())
    var research_area: Dictionary = hq.build_area_with_finance(finance, "research")
    check(bool(research_area.get("ok", false)), "Research area is built")
    check(int(finance.available_cash()) == before_research_area - int(research_area.get("cost", 0)), "Research area charges finance exactly once")
    var research_area_upgrade: Dictionary = hq.build_area_with_finance(finance, "research")
    check(bool(research_area_upgrade.get("ok", false)) and hq.research_capacity() == 4, "Research area upgrade raises capacity")
    var before_accelerated_research := int(finance.available_cash())
    var accelerated: Dictionary = research.start_research("process_automation", "founder")
    check(bool(accelerated.get("ok", false)), "Accelerated founder research starts")
    check(int(finance.available_cash()) == before_accelerated_research - 12000, "Accelerated research is charged exactly once")
    var accelerated_duration := int(accelerated.get("project", {}).get("duration", -1))
    check(accelerated_duration < baseline_duration, "HQ research capacity shortens founder R&D")
    check(float(accelerated.get("project", {}).get("hq_speed_multiplier", 1.0)) > 1.0, "Research project records HQ acceleration")

    var project_count_before_block := research.list_projects("founder").size()
    _set_finance_cash(finance, 100)
    var blocked_cash := int(finance.available_cash())
    var blocked: Dictionary = research.start_research("mega_infrastructure", "founder")
    check(not bool(blocked.get("ok", false)), "Unaffordable research is rejected")
    check(str(blocked.get("error", "")) == "insufficient_funds", "Unaffordable research reports funding failure")
    check(research.list_projects("founder").size() == project_count_before_block, "Rejected research leaves no ghost project")
    check(int(finance.available_cash()) == blocked_cash, "Rejected research leaves cash unchanged")
    _set_finance_cash(finance, 500000)

    var stage2: Dictionary = hq.upgrade_with_finance(finance, int(game.day))
    check(bool(stage2.get("ok", false)) and hq.get_stage_index() == 2, "HQ reaches Corporate Center")
    var tech_area: Dictionary = hq.build_area_with_finance(finance, "technology_center")
    var tech_area_upgrade: Dictionary = hq.build_area_with_finance(finance, "technology_center")
    check(bool(tech_area.get("ok", false)) and bool(tech_area_upgrade.get("ok", false)), "Technology Center builds and upgrades")
    check(hq.technology_capacity() == 6, "Technology Center exposes strategic capacity")
    var accelerated_tech_days := int(technology.get_research_time_days("smart_factory"))
    check(accelerated_tech_days < baseline_tech_days, "Technology Center shortens technology research time")

    var state = root.get_node_or_null("RenewGameState")
    if state != null:
        state.set_value("technology", "research_points", 0)
    technology.add_daily_research_points(3)
    check(int(state.get_value("technology", "research_points", 0)) >= 5 if state != null else false, "Technology Center increases daily research-point generation")

    var museum: Dictionary = hq.build_area_with_finance(finance, "museum")
    check(bool(museum.get("ok", false)) and hq.museum_available(), "Corporate Museum opens at Corporate Center")
    if legacy != null:
        legacy._scan_hq(int(game.day))
        var founding: Array = legacy.list_category("founding")
        var has_hq := false
        var has_museum := false
        for item in founding:
            var title := str(item.get("title", ""))
            if title.find("Headquarters milestone") >= 0:
                has_hq = true
            if title.find("Corporate Museum opened") >= 0:
                has_museum = true
        check(has_hq, "HQ expansion creates permanent legacy artifacts")
        check(has_museum, "Museum opening creates a permanent legacy artifact")

    check(int(finance.available_cash()) < baseline_cash, "Strategic HQ growth and R&D have real capital costs")
    check(bool(finance.validate_invariants().get("ok", false)), "HQ strategic investment keeps finance balanced")

    print("HEADQUARTERS INTEGRATION RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
