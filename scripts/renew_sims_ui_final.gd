extends "res://scripts/renew_sims_ui.gd"

# Final responsive pass: use the same authoritative action grid on every
# viewport. On phones/tablets the command dock becomes a bottom sheet, while
# the world stays visible above it. This avoids duplicate mobile callbacks and
# keeps every action wired to the same game-state boundary.

func _sync_mobile_actions() -> void:
    # The final layout uses action_grid directly on mobile. The legacy duplicate
    # mobile grid is intentionally disabled so actions cannot drift apart.
    for child in mobile_actions.get_children():
        child.queue_free()

func _layout_responsive() -> void:
    super._layout_responsive()
    if root == null:
        return
    var s := root.size
    var w := maxf(s.x, 320.0)
    var h := maxf(s.y, 480.0)
    if not narrow:
        return

    # Compact top mode switcher, similar to a life-sim mode bar.
    mode_rail.visible = true
    mode_rail.position = Vector2(8, 64)
    mode_rail.size = Vector2(w - 16, 42)

    # The world remains the primary visual surface; commands sit in a single
    # touch-friendly bottom sheet with a scrollable two-column action grid.
    action_dock.visible = true
    action_dock.position = Vector2(8, h - minf(270.0, h * 0.44))
    action_dock.size = Vector2(w - 16, minf(262.0, h * 0.43))
    action_title.position = Vector2(10, 7)
    action_title.size = Vector2(w - 36, 20)
    action_subtitle.position = Vector2(10, 27)
    action_subtitle.size = Vector2(w - 36, 22)
    action_scroll.position = Vector2(8, 52)
    action_scroll.size = Vector2(w - 32, action_dock.size.y - 61)
    action_grid.columns = 2
    for child in action_grid.get_children():
        if child is Button:
            child.custom_minimum_size = Vector2(maxf(125.0, (w - 50.0) / 2.0), 44)

    # The duplicate legacy mobile dock is kept in the scene for compatibility,
    # but never rendered by this final presentation.
    bottom_mobile.visible = false
    mobile_actions.visible = false
    mobile_objective.visible = false

    # Reassert touch-safe top-bar geometry after the parent layout pass.
    top_strip.position = Vector2(8, 8)
    top_strip.size = Vector2(w - 16, 50)
    brand.position = Vector2(9, 3)
    brand.size = Vector2(90, 30)
    brand.add_theme_font_size_override("font_size", 18)
    location_label.visible = false
    cash_label.position = Vector2(w - 230, 5)
    cash_label.size = Vector2(80, 28)
    rep_label.position = Vector2(w - 150, 5)
    rep_label.size = Vector2(70, 28)
    day_label.visible = false

func _process(delta: float) -> void:
    super._process(delta)
    if parent == null:
        return
    # Keep the contextual property information fresh without covering the world.
    if selected_title != null:
        selected_title.text = _selected_title()
    if selected_meta != null:
        selected_meta.text = _selected_meta()
