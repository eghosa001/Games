extends Node2D

# Phase 14: competitor-driven resource pressure. Resource control is keyed by
# stable corporation IDs so names can change without breaking gameplay.
var parent
var last_day: Variant = 0
var news: Array[String] = []
var resource_control: Variant = {
    "apex_materials": {"iron": 2, "energy": 1},
    "northstar_logistics": {"energy": 2, "food": 1},
    "greenbuild_industries": {"timber": 2, "electronics": 1}
}

func _ready() -> void:
    parent = get_parent()
    last_day = parent.day
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null:
        return
    if parent.day != last_day:
        _advance_competition(parent.day)
        last_day = parent.day
    queue_redraw()

func _advance_competition(day: int) -> void:
    news.clear()
    var competitors = parent.rivals
    var supply = parent.get_node_or_null("SupplyChainController")
    if supply == null:
        return
    var pressure: Variant = 0
    for rival in competitors.rivals:
        var rival_id: Variant = String(rival.get("id", ""))
        var controls: Dictionary = resource_control.get(rival_id, {})
        var rival_pressure: Variant = int(rival.get("supplier_pressure", 0))
        for resource in controls:
            var control_level: Variant = int(controls[resource])
            if control_level <= 0:
                continue
            var rights: Variant = int(supply.contracts.player_resource_rights.get(resource, 0))
            var effective_control: Variant = max(0, control_level - rights)
            if effective_control > 0:
                pressure += effective_control + rival_pressure
        if int(rival.get("relationship", 0)) < 0 and day % 6 == 0:
            if int(rival.get("supplier_pressure", 0)) < 3:
                rival["supplier_pressure"] = int(rival.get("supplier_pressure", 0)) + 1
                news.append("%s tightened supplier control. Negotiations are becoming important." % rival.get("name", "Rival"))
    supply.supply.competitor_pressure = clamp(pressure, 0, 20)
    if pressure > 0 and day % 3 == 0:
        news.append("RESOURCE MARKET: Rival control is increasing the cost of independent sourcing.")
    for note in news:
        parent._log("COMPETITION: " + note)

func control_summary() -> String:
    var parts: Array[String] = []
    for rival in parent.rivals.rivals:
        var rival_id: Variant = String(rival.get("id", ""))
        var name: Variant = String(rival.get("name", rival_id))
        var controls: Dictionary = resource_control.get(rival_id, {})
        var held: Array[String] = []
        for resource in controls:
            if int(controls[resource]) > 0:
                held.append(resource)
        if held.size() > 0:
            parts.append("%s: %s" % [name, ", ".join(held)])
    return " | ".join(parts)

func _draw() -> void:
    if parent == null:
        return
    draw_rect(Rect2(845, 515, 410, 100), Color("17232c"), true)
    draw_string(ThemeDB.fallback_font, Vector2(865, 540), "RESOURCE COMPETITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(ThemeDB.fallback_font, Vector2(865, 564), "Rivals can control key resources and pressure your sourcing.", HORIZONTAL_ALIGNMENT_LEFT, 380, 12, Color.WHITE)
    var supply = parent.get_node_or_null("SupplyChainController")
    var pressure: Variant = int(supply.supply.competitor_pressure) if supply != null else 0
    draw_string(ThemeDB.fallback_font, Vector2(865, 587), "Market pressure: %d | %s" % [pressure, control_summary()], HORIZONTAL_ALIGNMENT_LEFT, 375, 11, Color("f2d27a"))
