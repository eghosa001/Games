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
    "corporate_strategy", "world_power", "headquarters", "legacy", "endgame",
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
        var fresh_roster := state.get_value("employees", "roster", []) as Array
        var stale_employee_present := false
        for employee in fresh_roster:
            if employee is Dictionary and str((employee as Dictionary).get("id", "")) == "stale":
                stale_employee_present = true
        check("new game restores the three-person founding roster", fresh_roster.size() == 3)
        check("new game removes stale employees", not stale_employee_present)
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
    var property_detail := hud.get("mobile_content") as Control
    check("detail screen removes overlapping notification control", property_detail.get_node_or_null("NotificationsButton") == null)
    check("detail screen keeps one top-right back control", property_detail.get_node_or_null("FlowBack") is Button)

    if state != null:
        state.set_value("player", "day", 7)
        hud.open_figma_view("new_game")
        await process_frame
        var unguided := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction1") as Button
        check("new-game screen exposes explicit unguided start", unguided != null and unguided.text == "START WITHOUT GUIDE")
        if unguided != null:
            unguided.pressed.emit()
            await process_frame
            check("unguided start creates a fresh company", int(state.get_value("player", "day", -1)) == 1)
            check("unguided start disables tutorial overlay", bool(state.get_value("progression", "tutorial_completed", false)) and bool(state.get_value("progression", "tutorial_dismissed", false)))
            check("unguided start routes into the live company", str(hud.get("active_view")) == "live")

    bridge._dispatch("continue_save", hud)
    check("continue flow shows Figma loading state before restore", str(hud.get("active_view")) == "loading")
    await process_frame
    await process_frame
    check("loading state completes into the restored company", str(hud.get("active_view")) == "live")

    hud.open_figma_view("business_list")
    await process_frame
    var business_action := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction0") as Button
    check("business list does not open a missing business", business_action != null and business_action.text == "START BUSINESS")
    if business_action != null:
        business_action.pressed.emit()
        await process_frame
        check("empty business list routes to business setup", str(hud.get("active_view")) == "operate")

    hud.open_figma_view("employee_list")
    await process_frame
    var employee_action := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction0") as Button
    check("employee list opens a real employee detail", employee_action != null and employee_action.text == "VIEW EMPLOYEE")
    if employee_action != null:
        employee_action.pressed.emit()
        await process_frame
        check("employee detail is reachable from employee list", str(hud.get("active_view")) == "employee_detail")
        var before_employee_index := int(bridge.get("_selected_employee_index"))
        var before_employee_status := (hud.get("mobile_content") as Control).get_node_or_null("Status") as Label
        var before_employee_name := before_employee_status.text if before_employee_status != null else ""
        var next_employee := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction2") as Button
        check("multi-employee detail exposes next employee", next_employee != null and next_employee.text == "NEXT EMPLOYEE")
        if next_employee != null:
            next_employee.pressed.emit()
            await process_frame
            check("next employee updates Figma employee selection", int(bridge.get("_selected_employee_index")) != before_employee_index)
            var refreshed_status := (hud.get("mobile_content") as Control).get_node_or_null("Status") as Label
            check("same-view employee action refreshes visible Figma content", refreshed_status != null and refreshed_status.text != before_employee_name)

    hud.open_figma_view("contract_market")
    await process_frame
    var active_contracts_button := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction1") as Button
    check("zero active contracts still exposes the authored empty-state route", active_contracts_button != null)
    if active_contracts_button != null:
        active_contracts_button.pressed.emit()
        await process_frame
        check("no-contract condition opens Figma empty state", str(hud.get("active_view")) == "empty_states")

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
    check("business employee list returns to Business hub", str(bridge.back_target("employee_list")) == "operate")
    check("business contract market returns to Business hub", str(bridge.back_target("contract_market")) == "operate")
    check("business supply chain returns to Business hub", str(bridge.back_target("supply_chain")) == "operate")
    check("infrastructure returns to World hub", str(bridge.back_target("infrastructure_roadmap")) == "world")
    check("restoration confirmation back chain is stable", str(bridge.back_target("restoration_confirm")) == "restoration_plan")
    check("accessibility back chain is stable", str(bridge.back_target("accessibility")) == "settings")
    check("corporate strategy returns to More", str(bridge.back_target("corporate_strategy")) == "more")
    check("world power returns to corporate strategy", str(bridge.back_target("world_power")) == "corporate_strategy")
    check("headquarters returns to world power", str(bridge.back_target("headquarters")) == "world_power")
    check("legacy returns to More", str(bridge.back_target("legacy")) == "more")
    check("endgame returns to More", str(bridge.back_target("endgame")) == "more")

    hud.open_figma_view("more")
    await process_frame
    var strategy_button := (hud.get("mobile_content") as Control).find_child("Opencorporate_strategy", true, false) as Button
    var power_button := (hud.get("mobile_content") as Control).find_child("Openworld_power", true, false) as Button
    var headquarters_button := (hud.get("mobile_content") as Control).find_child("Openheadquarters", true, false) as Button
    var legacy_button := (hud.get("mobile_content") as Control).find_child("Openlegacy", true, false) as Button
    var endgame_button := (hud.get("mobile_content") as Control).find_child("Openendgame", true, false) as Button
    var diplomacy_button := (hud.get("mobile_content") as Control).find_child("OpenRenewDiplomacyUI", true, false) as Button
    check("More exposes progression-gated corporate strategy", strategy_button != null)
    check("More exposes progression-gated world power", power_button != null)
    check("More exposes progression-gated headquarters", headquarters_button != null)
    check("More exposes progression-gated legacy", legacy_button != null)
    check("More exposes progression-gated prestige endgame", endgame_button != null)
    check("More exposes progression-gated diplomacy and trade", diplomacy_button != null)

    if state != null:
        hud.open_figma_view("restoration_complete")
        await process_frame
        state.set_value("progression", "xp", 100)
        state.set_value("progression", "level", 2)
        hud.set("_last_progress_level", 1)
        hud.set("_pending_level_up", false)
        hud._process(0.6)
        await process_frame
        check("level-up does not interrupt restoration completion", str(hud.get("active_view")) == "restoration_complete")
        check("level-up is queued while a task screen is active", bool(hud.get("_pending_level_up")))
        hud.open_figma_view("live")
        hud._process(0.6)
        await process_frame
        check("queued level-up does not replace Home navigation", str(hud.get("active_view")) == "live")
        hud.open_figma_view("more")
        await process_frame
        var progression_notice := (hud.get("mobile_content") as Control).find_child("Openlevel_up", true, false) as Button
        check("queued level-up is reachable from the Progression tile", progression_notice != null)
        if progression_notice != null:
            progression_notice.pressed.emit()
            await process_frame
            check("Progression notice opens Figma level-up screen", str(hud.get("active_view")) == "level_up")
            check("opening level-up clears the pending notice", not bool(hud.get("_pending_level_up")))

        hud.open_figma_view("live")
        var day_before_summary := int(state.get_value("player", "day", 1))
        state.set_value("player", "day", day_before_summary + 1)
        hud._process(0.6)
        await process_frame
        check("ordinary game-day changes do not interrupt navigation", str(hud.get("active_view")) == "live")
        var realtime := root.get_node_or_null("RenewRealTimeEconomySystem")
        var calendar := realtime.get_node_or_null("WorldCalendarSystem") if realtime != null else null
        check("world calendar exposes dedicated rollover signal", calendar != null and calendar.has_signal("day_rolled_over"))
        if calendar != null and calendar.has_signal("day_rolled_over"):
            calendar.emit_signal("day_rolled_over", {"ok": true, "day": day_before_summary + 1})
            await process_frame
            check("real calendar rollover opens Figma end-of-day summary", str(hud.get("active_view")) == "day_summary")
            var continue_day := (hud.get("mobile_content") as Control).get_node_or_null("FlowAction0") as Button
            check("day summary continue is reachable", continue_day != null)
            if continue_day != null:
                continue_day.pressed.emit()
                await process_frame
                check("day summary continues without legacy extra day advance", int(state.get_value("player", "day", 0)) == day_before_summary + 1 and str(hud.get("active_view")) == "live")

            hud.open_figma_view("contract_market")
            await process_frame
            calendar.emit_signal("day_rolled_over", {"ok": true, "day": day_before_summary + 2})
            await process_frame
            check("calendar rollover does not interrupt an active management flow", str(hud.get("active_view")) == "contract_market")
            check("deferred day summary is queued", bool(hud.get("_pending_day_summary")))
            hud.open_figma_view("more")
            await process_frame
            var queued_day_summary := (hud.get("mobile_content") as Control).find_child("Openday_summary", true, false) as Button
            check("queued day summary is reachable through the Figma route from More", queued_day_summary != null)
            if queued_day_summary != null:
                queued_day_summary.pressed.emit()
                await process_frame
                check("opening queued day summary clears the notice", str(hud.get("active_view")) == "day_summary" and not bool(hud.get("_pending_day_summary")))

        realtime = root.get_node_or_null("RenewRealTimeEconomySystem")
        check("real-time service exposes Figma error signal", realtime != null and realtime.has_signal("service_error"))
        if realtime != null and realtime.has_signal("service_error"):
            realtime.emit_signal("service_error", "Focused service failure")
            await process_frame
            check("runtime service failure opens Figma offline/error state", str(hud.get("active_view")) == "offline_error")

    game.queue_free()
    await process_frame
    print("FIGMA FLOW WIRING: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
# Focused validation: RESTORA mobile overlap, touch scroll and navigation hierarchy.
# Focused rerun: typed mobile UX layout fix.
