extends CanvasLayer

# Non-blocking CEO dashboard. Keep it clear of the primary touch controls on
# both desktop and narrow mobile layouts.
var game: Node
var root: Control
var panel: Panel
var label: Label

func _ready() -> void:
    game = get_parent()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    panel = Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(panel)

    label = Label.new()
    label.position = Vector2(14, 10)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 13)
    panel.add_child(label)

    root.resized.connect(_layout_responsive)
    _layout_responsive()

func _layout_responsive() -> void:
    if root == null or panel == null or label == null:
        return
    var w := maxf(root.size.x, 320.0)
    var h := maxf(root.size.y, 480.0)
    if w < 700.0:
        # MobileUI reserves the lower strip for navigation/actions. This slot
        # sits between the goal area and that strip without covering buttons.
        panel.position = Vector2(12, minf(418.0, h - 150.0))
        panel.size = Vector2(w - 24.0, 86.0)
        label.size = Vector2(panel.size.x - 28.0, panel.size.y - 20.0)
        label.add_theme_font_size_override("font_size", 11)
    else:
        # Keep the dashboard in the lower-right activity area rather than
        # covering the restoration, business, or action panels.
        panel.position = Vector2(maxf(845.0, w - 435.0), minf(594.0, h - 100.0))
        panel.size = Vector2(minf(410.0, w - panel.position.x - 18.0), 82.0)
        label.size = Vector2(panel.size.x - 28.0, 62.0)
        label.add_theme_font_size_override("font_size", 13)

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
