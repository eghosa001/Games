extends "res://scripts/renew_sims_ui.gd"

# Stable scene entry point for the premium command-deck UI.
# Adds portfolio-scale restoration context, exception visibility and the
# real-world economy clock without duplicating gameplay state.

func _property_system():
    if parent == null or parent.get("command_system") == null:
        return null
    return parent.command_system.get("property_system")

func _management_policy():
    return get_node_or_null("/root/RenewManagementPolicySystem")

func _real_time_economy():
    return get_node_or_null("/root/RenewRealTimeEconomySystem")

func _refresh_metrics() -> void:
    super._refresh_metrics()
    if active_tab != 0 or stat_names.size() < 4 or stat_values.size() < 4:
        return
    var properties = _property_system()
    if properties != null and properties.has_method("restoration_portfolio_status"):
        var status: Dictionary = properties.restoration_portfolio_status()
        stat_names[3].text = "PORTFOLIO"
        stat_values[3].text = "%d / %d" % [int(status.get("restored", 0)), int(status.get("total", 0))]

func _sell_goods_now() -> Dictionary:
    var economy = _real_time_economy()
    if economy == null or not economy.has_method("sell_goods"):
        return {"ok": false, "message": "Active market is unavailable."}
    return economy.sell_goods()

func _deliver_contract_now() -> Dictionary:
    var economy = _real_time_economy()
    if economy == null or not economy.has_method("deliver_contract"):
        return {"ok": false, "message": "Contract delivery is unavailable."}
    return economy.deliver_contract()

func _primary_move() -> Dictionary:
    if parent == null:
        return {"label": "NEXT MOVE", "call": Callable()}
    if not bool(parent.inspected):
        return {"label": "INSPECT", "call": parent.inspect_property}
    if not bool(parent.owned):
        return {"label": "ACQUIRE", "call": parent.acquire_property}
    if str(parent.stage) != "Operational":
        return {"label": "RESTORE", "call": parent.restore_property}
    if not bool(parent.business_open):
        return {"label": "OPEN BUSINESS", "call": parent.open_business}
    if int(parent.finished_goods) <= 0:
        return {"label": "PRODUCE", "call": parent.produce_goods}
    return {"label": "SELL GOODS", "call": Callable(self, "_sell_goods_now")}

func _refresh() -> void:
    super._refresh()
    var end_day_button = action_list.get_node_or_null("Action_end_day") if action_list != null else null
    if end_day_button != null:
        end_day_button.visible = false
    if active_tab == 0:
        section_caption.text = "Restore assets, operate freely and watch the live economy move in real-world time."
    if active_tab == 1 and bool(parent.business_open):
        _group("Active trading", "You control production and selling. Consumer demand is finite each real-world day.")
        _action("Sell goods now", Callable(self, "_sell_goods_now"), "Sell available inventory into today's remaining customer demand", true)
        if int(parent.contract_days) > 0:
            _action("Deliver contract", Callable(self, "_deliver_contract_now"), "Settle today's contract delivery before the calendar rolls over", true)

    var clock := Time.get_datetime_dict_from_system()
    var hh := "%02d" % int(clock.get("hour", 0))
    var mm := "%02d" % int(clock.get("minute", 0))
    var economy = _real_time_economy()
    if economy != null and economy.has_method("status"):
        var rt: Dictionary = economy.status()
        var hourly := int(round(float(rt.get("hourly_net", 0.0))))
        var passive_assets := int(rt.get("businesses", 0)) + int(rt.get("resource_sites", 0))
        var demand_left := int(rt.get("consumer_demand_remaining", 0))
        hero_meta.text = "%s:%s  •  LIVE  •  REP %d  •  PASSIVE %s$%s/HR  •  DEMAND %d" % [hh, mm, int(parent.reputation), "+" if hourly >= 0 else "-", String.num_int64(abs(hourly)), demand_left]
        if passive_assets > 0 and status_label.text.is_empty():
            status_label.text = "%d passive asset%s operating • active business remains player-controlled" % [passive_assets, "" if passive_assets == 1 else "s"]
    else:
        hero_meta.text = "%s:%s  •  LIVE  •  REP %d" % [hh, mm, int(parent.reputation)]

func _process(delta: float) -> void:
    super._process(delta)
    var policies = _management_policy()
    if location_label == null:
        return
    var economy = _real_time_economy()
    var passive_text := ""
    if economy != null and economy.has_method("status"):
        var rt: Dictionary = economy.status()
        var hourly := int(round(float(rt.get("hourly_net", 0.0))))
        var assets := int(rt.get("businesses", 0)) + int(rt.get("resource_sites", 0))
        if assets > 0:
            passive_text = "  •  PASSIVE %s$%s/HR" % ["+" if hourly >= 0 else "-", String.num_int64(abs(hourly))]
    if policies == null:
        location_label.text = "RESTORATION COMMAND" + passive_text
        return
    var alerts = policies.get_alerts()
    var critical := 0
    for alert in alerts:
        if alert is Dictionary and str(alert.get("severity", "")) == "critical": critical += 1
    if critical > 0:
        location_label.text = "RESTORATION COMMAND  •  %d CRITICAL%s" % [critical, passive_text]
    elif alerts.size() > 0:
        location_label.text = "RESTORATION COMMAND  •  %d ALERT%s%s" % [alerts.size(), "" if alerts.size() == 1 else "S", passive_text]
    else:
        location_label.text = "RESTORATION COMMAND  •  SYSTEMS NOMINAL" + passive_text
