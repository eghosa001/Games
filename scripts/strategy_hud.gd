extends CanvasLayer

# Non-blocking CEO dashboard. Keep it clear of the primary touch controls and
# tutorial surface instead of assuming a fixed screen coordinate is safe.
var game: Node
var root: Control
var panel: Panel
var label: Label
var _coordinator_active := false

func _coordinator() -> Node:
    return RenewServices.get_service("RenewUIRegionCoordinator")

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
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

func _enter_tree() -> void:
    var coordinator := _coordinator()
    if coordinator != null:
        coordinator.set_active_screen("")

func _layout_responsive() -> void:
    if root == null or panel == null or label == null:
        return
    var w: float = maxf(root.size.x, 320.0)
    var h: float = maxf(root.size.y, 480.0)
    if w < 1000.0:
        panel.hide()
        return
    panel.position = Vector2(w - 425.0, 116.0)
    panel.size = Vector2(410.0, 82.0)
    label.size = Vector2(panel.size.x - 28.0, 62.0)
    label.add_theme_font_size_override("font_size", 13)
    panel.show()

func _should_show() -> bool:
    if root == null: return false
    return maxf(root.size.x, 320.0) >= 1000.0

func _get_rect() -> Rect2:
    if panel == null: return Rect2()
    return panel.get_global_rect()

func _set_coordinator_active(value: bool) -> void:
    _coordinator_active = value

func _on_screen_changed(open: bool) -> void:
    # When a primary screen opens, hide the floating strategy summary.
    # When it closes, let the next _process tick re-evaluate layout.
    if open:
        panel.hide()
    elif not _coordinator_active:
        _layout_responsive()

func _process(_delta: float) -> void:
    if game == null or label == null:
        return
    var screen_name := ""
    var coordinator := _coordinator()
    if coordinator != null:
        screen_name = coordinator.get_active_screen()
    if screen_name == "":
        _layout_responsive()
    var market = game.get_node_or_null("Systems/MarketDirector")
    var goals = game.get_node_or_null("Systems/EmpireGoals")
    var market_text: Variant = "MARKET: stable"
    if market != null and market.has_method("market_status"):
        market_text = "MARKET: " + market.market_status()
    var goal_text: Variant = "NEXT GOAL: build your company"
    if goals != null and goals.has_method("current_goal"):
        var goal: Dictionary = goals.current_goal()
        var total_goals: int = goals.goals.size()
        var completed: int = goals.completed_count() if goals.has_method("completed_count") else 0
        goal_text = "GOAL %d/%d: %s — %s" % [completed, total_goals, String(goal.get("title", "")), String(goal.get("text", ""))]
    label.text = market_text + "\n" + goal_text
