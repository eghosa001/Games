extends "res://scripts/renew_sims_ui.gd"

# Stable scene entry point for the premium command-deck UI.
# Adds portfolio-scale restoration context, exception visibility and the
# real-world economy clock without duplicating gameplay state.

# Compatibility alias for the primary sector tabs. The base deck calls this
# bottom_nav; exposing it explicitly keeps automated responsive QA aligned with
# the actual navigation control rather than a stale/nonexistent field.
var tabs: HBoxContainer

func _build_ui() -> void:
    super._build_ui()
    background.name = "MainHUDBackground"
    brand.text = "RESTORA"
    location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tabs = bottom_nav

func _layout_responsive() -> void:
    super._layout_responsive()
    var width := get_viewport().get_visible_rect().size.x
    var mobile := width < 700.0
    var micro := width < 340.0
    shell.add_theme_constant_override("margin_left", 12 if mobile else 108)
    page.add_theme_constant_override("separation", 7 if mobile else 12)
    hero_card.custom_minimum_size.y = 132.0 if mobile else 152.0
    stat_grid.visible = not micro
    for card in stat_cards:
        card.custom_minimum_size.y = 68.0 if mobile else 82.0
    section_caption.visible = not mobile
    status_label.visible = not mobile
    hero_action.custom_minimum_size = Vector2(112.0 if mobile else 168.0, 52.0)
    for nav_button in mode_buttons:
        nav_button.custom_minimum_size = Vector2(0.0 if mobile else 100.0, 44.0 if mobile else 50.0)
        nav_button.add_theme_font_size_override("font_size", 9 if mobile else 12)
    if action_list != null:
        for child in action_list.get_children():
            if child is Button:
                var action_button := child as Button
                action_button.clip_text = true
                action_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                action_button.custom_minimum_size.x = 0.0

func _action(text: String, callback: Callable, subtitle := "", emphasis := false) -> void:
    super._action(text, callback, subtitle, emphasis)
    if action_list == null or action_list.get_child_count() == 0:
        return
    var child := action_list.get_child(action_list.get_child_count() - 1)
    if child is Button:
        var action_button := child as Button
        action_button.clip_text = true
        action_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        action_button.custom_minimum_size.x = 0.0

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
    if background != null and background.color.a < 0.99:
        background.color = Color(background.color.r, background.color.g, background.color.b, 1.0)
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
