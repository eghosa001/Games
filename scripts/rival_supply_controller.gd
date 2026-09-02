extends Node2D

# Makes competitors economically meaningful: they can control resource flows,
# raise spot-market prices and create temporary shortages without combat.
var parent
var last_day := 0
var news: Array[String] = []
var resource_control := {
    "The Giant": {"materials": 0, "packaging": 0, "fuel": 1, "food": 0},
    "The Specialist": {"materials": 0, "packaging": 1, "fuel": 0, "food": 0},
    "The Network": {"materials": 1, "packaging": 1, "fuel": 0, "food": 0}
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
    var pressure := 0
    for rival in competitors.rivals:
        var name := String(rival.get("name", ""))
        var controls: Dictionary = resource_control.get(name, {})
        var rival_pressure := int(rival.get("supplier_pressure", 0))
        for resource in controls:
            var control_level := int(controls[resource])
            if control_level <= 0:
                continue
            # Player-owned resource rights directly weaken rival control.
            var rights := int(supply.contracts.player_resource_rights.get(resource, 0))
            var effective_control := max(0, control_level - rights)
            if effective_control > 0:
                pressure += effective_control + rival_pressure
        if int(rival.get("relationship", 0)) < 0 and day % 6 == 0:
            if int(rival.get("supplier_pressure", 0)) < 3:
                rival["supplier_pressure"] = int(rival.get("supplier_pressure", 0)) + 1
                news.append("%s tightened supplier control. Negotiations are becoming important." % name)
    supply.supply.competitor_pressure = clamp(pressure, 0, 20)
    if pressure > 0 and day % 3 == 0:
        news.append("RESOURCE MARKET: Rival control is increasing the cost of independent sourcing.")
    for note in news:
        parent._log("COMPETITION: " + note)

func control_summary() -> String:
    var parts: Array[String] = []
    for name in resource_control:
        var controls: Dictionary = resource_control[name]
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
    var pressure := int(supply.supply.competitor_pressure) if supply != null else 0
    draw_string(ThemeDB.fallback_font, Vector2(865, 587), "Market pressure: %d | %s" % [pressure, control_summary()], HORIZONTAL_ALIGNMENT_LEFT, 375, 11, Color("f2d27a"))
