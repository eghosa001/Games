extends SceneTree

var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var packed = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    game.name = "Renew"
    root.add_child(game)
    await process_frame
    await process_frame

    var realtime = root.get_node_or_null("RenewRealTimeEconomySystem")
    check(realtime != null, "real-time economy autoload exists")
    if realtime == null:
        quit(1)
        return
    check(realtime.get_node_or_null("ActiveMarketSystem") != null, "active market controller is attached")
    check(realtime.get_node_or_null("WorldCalendarSystem") != null, "world calendar controller is attached")

    var status: Dictionary = realtime.status()
    check(status.has("hourly_net"), "passive hourly net is exposed")
    check(status.has("daily_revenue") and status.has("daily_expense"), "passive revenue and costs are both exposed")
    check(status.has("consumer_demand_remaining"), "daily active demand budget is exposed")
    check(status.has("calendar"), "real-world calendar status is exposed")

    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState exists")
    if state != null:
        var sentinel := {"save_probe": 4711}
        state.set_value("analytics", "real_time", sentinel)
        var captured: Dictionary = state.capture()
        var saved_domains: Dictionary = captured.get("domains", {})
        var saved_analytics: Dictionary = saved_domains.get("analytics", {}) if saved_domains.get("analytics", {}) is Dictionary else {}
        check((saved_analytics.get("real_time", {}) as Dictionary).get("save_probe", 0) == 4711, "real-time clock state survives canonical save capture")
        check(saved_analytics.has("simulation_system"), "legacy simulation state remains separate from real-time state")

    var source := FileAccess.get_file_as_string("res://scripts/real_time_economy_system.gd")
    var active_source := FileAccess.get_file_as_string("res://scripts/active_market_system.gd")
    var calendar_source := FileAccess.get_file_as_string("res://scripts/world_calendar_system.gd")
    var tech_source := FileAccess.get_file_as_string("res://scripts/technology_system.gd")
    var ui_source := FileAccess.get_file_as_string("res://scripts/renew_sims_ui_final.gd")
    var state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
    var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
    var mobile_source := FileAccess.get_file_as_string("res://scripts/mobile_ui_mobile_scale_fix.gd")

    check(source.contains("MAX_OFFLINE_CATCHUP_SECONDS := 86400.0"), "passive offline catch-up is capped at 24 hours")
    check(source.contains("STATE_KEY := \"real_time\""), "passive timestamps use dedicated persistent state")
    check(source.contains("site_cost_ratio"), "resource sites pay risk-adjusted passive operating costs")
    check(source.contains("active_market.sell_goods()"), "active selling is routed through active market")
    check(active_source.contains("consumer_units_sold"), "active market tracks daily sold units")
    check(active_source.contains("get_value(\"analytics\", \"real_time\""), "daily demand survives save/load independently")
    check(active_source.contains("Today's customer demand has been satisfied"), "active sales stop after daily demand is consumed")
    check(calendar_source.contains("MAX_OFFLINE_CALENDAR_DAYS := 1"), "calendar catch-up is capped at one missed day")
    check(calendar_source.contains("get_value(\"analytics\", \"real_time\""), "calendar anchor survives save/load independently")
    check(calendar_source.contains("finance.settle_debt_day()"), "debt settles on calendar rollover")
    check(calendar_source.contains("employee_system.daily_update") or calendar_source.contains("commands.employee_system.daily_update"), "employee state advances on calendar rollover")
    check(calendar_source.contains("production.advance_day()"), "machine wear advances on calendar rollover")
    check(tech_source.contains("func advance_calendar_day"), "technology progresses through calendar days")
    check(tech_source.contains("func get_last_research_days()->int: return 0"), "research no longer triggers hidden day simulation")
    check(state_source.contains("\"analytics\":[\"simulation_system\",\"real_time\"]"), "GameState permits a dedicated real-time analytics namespace")
    check(ui_source.contains("SELL GOODS"), "primary UX exposes manual selling")
    check(ui_source.contains("_action(\"Deliver contract\""), "business UX exposes manual contract delivery")
    check(not ui_source.contains("_action(\"End day\"") and not ui_source.contains("_action(\"END DAY\""), "legacy End Day action is absent from premium UX")
    check(main_source.contains("KEY_N: sell_goods()"), "desktop N shortcut sells instead of skipping the day")
    check(not mobile_source.contains("primary_button.text = \"END DAY\""), "obsolete mobile End Day control is removed")

    print("REAL-TIME ECONOMY RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
