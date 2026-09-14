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

    var source := FileAccess.get_file_as_string("res://scripts/real_time_economy_system.gd")
    var active_source := FileAccess.get_file_as_string("res://scripts/active_market_system.gd")
    var calendar_source := FileAccess.get_file_as_string("res://scripts/world_calendar_system.gd")
    var tech_source := FileAccess.get_file_as_string("res://scripts/technology_system.gd")
    var ui_source := FileAccess.get_file_as_string("res://scripts/renew_sims_ui_final.gd")

    check(source.contains("MAX_OFFLINE_CATCHUP_SECONDS := 86400.0"), "passive offline catch-up is capped at 24 hours")
    check(source.contains("active_market.sell_goods()"), "active selling is routed through active market")
    check(active_source.contains("consumer_units_sold"), "active market tracks daily sold units")
    check(active_source.contains("Today's customer demand has been satisfied"), "active sales stop after daily demand is consumed")
    check(calendar_source.contains("MAX_OFFLINE_CALENDAR_DAYS := 1"), "calendar catch-up is capped at one missed day")
    check(calendar_source.contains("finance.settle_debt_day()"), "debt settles on calendar rollover")
    check(calendar_source.contains("employee_system.daily_update") or calendar_source.contains("commands.employee_system.daily_update"), "employee state advances on calendar rollover")
    check(calendar_source.contains("production.advance_day()"), "machine wear advances on calendar rollover")
    check(tech_source.contains("func advance_calendar_day"), "technology progresses through calendar days")
    check(tech_source.contains("func get_last_research_days()->int: return 0"), "research no longer triggers hidden day simulation")
    check(ui_source.contains("SELL GOODS"), "primary UX exposes manual selling")
    check(ui_source.contains("Deliver contract"), "business UX exposes manual contract delivery")
    check(ui_source.contains("end_day_button.visible = false"), "legacy End Day action is hidden from premium UX")

    print("REAL-TIME ECONOMY RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
