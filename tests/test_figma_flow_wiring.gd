extends SceneTree

var failed := 0
var checks := 0

const VIEWS := [
    "new_game", "continue_game", "onboarding",
    "property_overview", "restoration_plan", "restoration_confirm", "before_after",
    "business_list", "business_overview", "production",
    "employee_list", "employee_detail", "hiring", "assign_employee",
    "contract_market", "contract_detail", "active_contracts",
    "supply_chain", "supplier_compare", "inventory",
    "budget", "funding", "region_overview", "property_acquisition",
    "infrastructure_roadmap", "company_progress", "milestones", "alliances",
    "reports", "notifications", "accessibility", "pause", "day_summary",
    "level_up", "restoration_complete", "insufficient_funds",
    "offline_error", "loading", "empty_states"
]

func _init() -> void:
    call_deferred("_run")

func check(label: String, ok: bool) -> void:
    checks += 1
    if ok:
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _inside_viewport(control: Control, viewport: Vector2i) -> bool:
    if control == null:
        return false
    var rect := control.get_global_rect()
    return rect.position.x >= -1.0 and rect.end.x <= float(viewport.x) + 1.0

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    var bridge := game.get_node_or_null("UI/MainHUD/FigmaFlowBridge")
    check("Main HUD available", hud != null)
    check("Figma flow bridge mounted", bridge != null)
    check("standard new-game command exists", game.has_method("start_new_game"))
    if hud == null or bridge == null:
        quit(1)
        return

    var state := root.get_node_or_null("RenewGameState")
    if state != null:
        state.set_value("player", "day", 99)
        state.set_value("economy", "cash", 1)
        state.set_value("employees", "roster", [{"id":"stale","name":"Stale Worker"}])
        game.start_new_game()
        await process_frame
        check("new game resets day", int(state.get_value("player", "day", -1)) == 1)
        check("new game resets employee roster", (state.get_value("employees", "roster", []) as Array).is_empty())
        check("new game restores founding cash", int(state.get_value("economy", "cash", 0)) == 35000)
        var finance := root.get_node_or_null("RenewFinanceSystem")
        var production := root.get_node_or_null("RenewProductionSystem")
        var contracts := root.get_node_or_null("RenewContractSystem")
        check("new game resets live finance ledger", finance != null and int(finance.get("cash")) == 35000 and int(finance.get("debt")) == 0)
        check("new game resets live production inventory", production != null and int(production.get("finished_goods")) == 0)
        check("new game resets live contracts", contracts != null and (contracts.get("active_contracts") as Dictionary).is_empty())

    hud.open_figma_view("new_game")
    await process_frame
    check("Figma New Game hides primary navigation", not (hud.get("bottom_nav") as Control).visible)
    hud.open_figma_view("property_overview")
    await process_frame
    check("normal Figma detail restores primary navigation", (hud.get("bottom_nav") as Control).visible)

    for view_name in VIEWS:
        check(view_name + " supported", bool(bridge.supports(view_name)))
        hud.open_figma_view(view_name)
        await process_frame
        await process_frame
        var content := hud.get("mobile_content") as Control
        check(view_name + " builds content", content != null and content.get_node_or_null("FlowDetails") != null)
        if content != null:
            var buttons := content.find_children("FlowAction*", "Button", true, false)
            for candidate in buttons:
                var button := candidate as Button
                check(view_name + " action target >=44px", button.size.y >= 44.0)
                check(view_name + " action inside phone width", _inside_viewport(button, root.size))
            var back := content.get_node_or_null("FlowBack") as Button
            if back != null:
                check(view_name + " back target >=40px", back.size.y >= 40.0)

    # Figma flow must mutate the real property model, never a UI-only mirror.
    hud.open_figma_view("property")
    await process_frame
    if not bool(hud._inspected()):
        game.inspect_property()
    if not bool(hud._owned()):
        if state != null:
            state.set_value("economy", "cash", 1000000)
        game.acquire_property()
    var before := int(hud._building_progress())
    if state != null:
        state.set_value("economy", "cash", 1000000)
    bridge._dispatch("confirm_restore", hud)
    await process_frame
    await process_frame
    var after := int(hud._building_progress())
    check("restoration confirmation mutates authoritative progress", after > before)

    bridge._dispatch("apply_budget", hud)
    await process_frame
    if state != null:
        var plan = state.get_value("finance", "budget_plan", {})
        check("budget action persists a real finance plan", plan is Dictionary and int(plan.get("reserve", 0)) == 25)

    check("contract detail back chain is stable", str(bridge.back_target("contract_detail")) == "contract_market")
    check("restoration confirmation back chain is stable", str(bridge.back_target("restoration_confirm")) == "restoration_plan")
    check("accessibility back chain is stable", str(bridge.back_target("accessibility")) == "settings")

    game.queue_free()
    await process_frame
    print("FIGMA FLOW WIRING: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
