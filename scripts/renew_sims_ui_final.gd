extends "res://scripts/renew_sims_ui.gd"

# Stable scene entry point for the premium command-deck UI.
# Adds portfolio-scale restoration context and exception visibility without
# duplicating gameplay state in presentation code.

func _property_system():
    if parent == null or parent.get("command_system") == null:
        return null
    return parent.command_system.get("property_system")

func _management_policy():
    return get_node_or_null("/root/RenewManagementPolicySystem")

func _refresh_metrics() -> void:
    super._refresh_metrics()
    if active_tab != 0 or stat_names.size() < 4 or stat_values.size() < 4:
        return
    var properties = _property_system()
    if properties != null and properties.has_method("restoration_portfolio_status"):
        var status: Dictionary = properties.restoration_portfolio_status()
        stat_names[3].text = "PORTFOLIO"
        stat_values[3].text = "%d / %d" % [int(status.get("restored", 0)), int(status.get("total", 0))]

func _process(delta: float) -> void:
    super._process(delta)
    var policies = _management_policy()
    if policies == null or location_label == null:
        return
    var alerts = policies.get_alerts()
    var critical := 0
    for alert in alerts:
        if alert is Dictionary and str(alert.get("severity", "")) == "critical":
            critical += 1
    if critical > 0:
        location_label.text = "RESTORATION COMMAND  •  %d CRITICAL" % critical
    elif alerts.size() > 0:
        location_label.text = "RESTORATION COMMAND  •  %d ALERT%s" % [alerts.size(), "" if alerts.size() == 1 else "S"]
    else:
        location_label.text = "RESTORATION COMMAND  •  SYSTEMS NOMINAL"
