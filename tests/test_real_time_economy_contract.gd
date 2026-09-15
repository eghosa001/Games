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
    var source := FileAccess.get_file_as_string("res://scripts/real_time_economy_system.gd")
    var active_source := FileAccess.get_file_as_string("res://scripts/active_market_system.gd")
    var calendar_source := FileAccess.get_file_as_string("res://scripts/calendar_day_system.gd")
    var tech_source := FileAccess.get_file_as_string("res://scripts/technology_system.gd")
    var state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
    var ui_source := FileAccess.get_file_as_string("res://scripts/renew_sims_ui_final.gd")
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
    check(ui_source.contains("_deliver_contract_now"), "premium shell retains explicit contract-delivery action path")
    check(not ui_source.contains("\"END DAY\""), "legacy End Day command is absent from premium shell")
    check(main_source.contains("KEY_N: sell_goods()"), "desktop N shortcut sells instead of skipping the day")
    check(not mobile_source.contains("primary_button.text = \"END DAY\""), "obsolete mobile End Day control is removed")

    print("REAL-TIME ECONOMY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)