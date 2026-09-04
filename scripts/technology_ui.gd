extends Node2D

## Technology presentation layer. Reads GameState; does not own research state.

func _ready() -> void:
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var state: Node = get_node_or_null("/root/RenewGameState")
    var tech: Node = get_node_or_null("/root/RenewTechnologySystem")
    if state == null or tech == null:
        return
    draw_rect(Rect2(875, 24, 380, 300), Color(0.04, 0.05, 0.08, 0.94))
    draw_rect(Rect2(875, 24, 380, 3), Color(0.25, 0.75, 0.95, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(895, 50), "TECHNOLOGY", HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color.WHITE)
    var research_points: int = int(state.get_value("technology", "research_points", 20))
    var cash: int = int(state.get_value("economy", "cash", 25000))
    draw_string(ThemeDB.fallback_font, Vector2(895, 70), "RP %d   Cash $%d   |   Y: research next" % [research_points, cash], HORIZONTAL_ALIGNMENT_LEFT, 340, 13, Color(0.75, 0.8, 0.88, 1))
    var y: float = 94.0
    var tier: int = 0
    for item: Variant in tech.get_technologies():
        var item_tier: int = int(item.tier)
        if item_tier != tier:
            tier = item_tier
            y += 5.0
            draw_string(ThemeDB.fallback_font, Vector2(895, y), "TIER %d" % tier, HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.45, 0.8, 1.0, 1))
            y += 18.0
        var unlocked: bool = bool(tech.is_unlocked(str(item.id)))
        var research_result: Dictionary = tech.can_research(str(item.id)) as Dictionary
        var status: String = "RESEARCHED" if unlocked else ("READY" if bool(research_result.get("ok", false)) else "LOCKED")
        var label: String = "%s — %s  ($%d / %d RP / %dd)" % [str(item.name), status, int(item.cost_money), int(item.cost_points), int(item.time_days)]
        var text_color: Color = Color(0.55, 1.0, 0.65, 1) if unlocked else Color(0.9, 0.9, 0.92, 1)
        draw_string(ThemeDB.fallback_font, Vector2(895, y), label, HORIZONTAL_ALIGNMENT_LEFT, 345, 11, text_color)
        y += 19.0
        if y > 310.0:
            break
