extends CanvasLayer

# Non-blocking CEO dashboard. It makes the deeper strategy visible without
# covering the existing touch controls.
var game: Node
var label: Label

func _ready() -> void:
    game = get_parent()
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var panel := Panel.new()
    panel.position = Vector2(430, 72)
    panel.size = Vector2(820, 82)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(panel)
    label = Label.new()
    label.position = Vector2(14, 10)
    label.size = Vector2(792, 62)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", 13)
    panel.add_child(label)

func _process(_delta: float) -> void:
    if game == null or label == null:
        return
    var market = game.get_node_or_null("MarketDirector")
    var goals = game.get_node_or_null("EmpireGoals")
    var market_text := "MARKET: stable"
    if market != null:
        market_text = "MARKET: " + market.market_status()
    var goal_text := "NEXT GOAL: build your company"
    if goals != null:
        var goal: Dictionary = goals.current_goal()
        goal_text = "GOAL %d/%d: %s — %s" % [goals.completed_count(), goals.goals.size(), String(goal.get("title", "")), String(goal.get("text", ""))]
    label.text = market_text + "\n" + goal_text
