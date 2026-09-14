extends "res://scripts/renew_sims_ui.gd"

# Production entry point for the layered RESTORA shell. Adds live-economy context
# without flattening secondary systems back onto the home screen.

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
    var size := root.size if root != null and root.size.x > 0.0 else get_viewport().get_visible_rect().size
    var mobile := size.x < 700.0
    # Keep the persistent world edge visible on wide screens while retaining a
    # full-width management surface on mobile.
    shell.add_theme_constant_override("margin_left", 10 if mobile else 86)
    for child in action_grid.get_children():
        if child is Button:
            var action_button := child as Button
            action_button.clip_text = true
            action_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _property_system():
    if parent == null or parent.get("command_system") == null:
        return null
    return parent.command_system.get("property_system")

func _management_policy():
    return get_node_or_null("/root/RenewManagementPolicySystem")

func _real_time_economy():
    return get_node_or_null("/root/RenewRealTimeEconomySystem")

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
        return {"label": "CHOOSE BUSINESS", "call": Callable(self, "_open_business_choices")}
    if int(parent.finished_goods) <= 0:
        return {"label": "PRODUCE", "call": parent.produce_goods}
    return {"label": "SELL GOODS", "call": Callable(self, "_sell_goods_now")}

func _refresh_metrics() -> void:
    super._refresh_metrics()
    if active_tab != 0 or stat_names.size() < 4 or stat_values.size() < 4:
        return
    var properties = _property_system()
    if properties != null and properties.has_method("restoration_portfolio_status"):
        var status: Dictionary = properties.restoration_portfolio_status()
        stat_names[3].text = "PORTFOLIO"
        stat_values[3].text = "%d / %d" % [int(status.get("restored", 0)), int(status.get("total", 0))]

func _refresh() -> void:
    super._refresh()
    if parent == null:
        return
    var clock := Time.get_datetime_dict_from_system()
    var hh := "%02d" % int(clock.get("hour", 0))
    var mm := "%02d" % int(clock.get("minute", 0))
    var economy = _real_time_economy()
    if economy != null and economy.has_method("status"):
        var rt: Dictionary = economy.status()
        var hourly := int(round(float(rt.get("hourly_net", 0.0))))
        var demand_left := int(rt.get("consumer_demand_remaining", 0))
        hero_meta.text = "%s:%s • %s • %s$%s/hr • demand %d" % [
            hh, mm,
            "OPERATING" if bool(parent.business_open) else str(parent.stage).to_upper(),
            "+" if hourly >= 0 else "-",
            String.num_int64(abs(hourly)),
            demand_left
        ]
    else:
        hero_meta.text = "%s:%s • %s" % [hh, mm, "OPERATING" if bool(parent.business_open) else str(parent.stage).to_upper()]

func _process(delta: float) -> void:
    super._process(delta)
    if background != null and background.color.a < 0.99:
        background.color.a = 1.0
    if location_label == null:
        return
    var policies = _management_policy()
    if policies == null:
        location_label.text = "ACQUIRE • RESTORE • OPERATE • EXPAND"
        return
    var alerts = policies.get_alerts()
    var critical := 0
    for alert in alerts:
        if alert is Dictionary and str(alert.get("severity", "")) == "critical":
            critical += 1
    if critical > 0:
        location_label.text = "RESTORA • %d CRITICAL DECISION%s" % [critical, "" if critical == 1 else "S"]
    elif alerts.size() > 0:
        location_label.text = "RESTORA • %d ACTIVE SIGNAL%s" % [alerts.size(), "" if alerts.size() == 1 else "S"]
    else:
        location_label.text = "ACQUIRE • RESTORE • OPERATE • EXPAND"
