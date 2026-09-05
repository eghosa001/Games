extends "res://scripts/renew_sims_ui.gd"

# Final responsive presentation pass. One authoritative action grid is used on
# desktop and mobile so every button reaches the same gameplay callbacks.

func _sync_mobile_actions() -> void:
    # Do not duplicate callbacks into the legacy mobile grid.
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

    # Mobile: world first, compact status bar, mode tabs, then a contained
    # command sheet. Nothing important is allowed to sit under the browser
    # edge or collide with the mode tabs on short phone screens.
    mode_rail.visible = true
    mode_rail.position = Vector2(8, 64)
    mode_rail.size = Vector2(w - 16, 42)

    var dock_height := clampf(h * 0.40, 218.0, 250.0)
    var dock_top := maxf(114.0, h - dock_height - 8.0)
    action_dock.visible = true
    action_dock.position = Vector2(8, dock_top)
    action_dock.size = Vector2(w - 16, h - dock_top - 8.0)

    action_title.position = Vector2(10, 7)
    action_title.size = Vector2(w - 36, 20)
    action_subtitle.position = Vector2(10, 27)
    action_subtitle.size = Vector2(w - 36, 20)
    action_scroll.position = Vector2(8, 50)
    action_scroll.size = Vector2(w - 32, maxf(132.0, action_dock.size.y - 58.0))
    action_grid.columns = 2

    var gap := 8.0
    var button_width := maxf(0.0, (action_scroll.size.x - gap - 8.0) / 2.0)
    for child in action_grid.get_children():
        if child is Button:
            child.custom_minimum_size = Vector2(button_width, 44.0)
            child.size_flags_horizontal = Control.SIZE_FILL

    # Hide duplicate/legacy mobile chrome and desktop-only context cards.
    bottom_mobile.visible = false
    mobile_actions.visible = false
    mobile_objective.visible = false
    left_rail.visible = false
    selected_card.visible = false
    objective_card.visible = false
    right_card.visible = false
    network_strip.visible = false

    # Compact top HUD. Keep all three values visible even on 320px devices.
    top_strip.position = Vector2(8, 8)
    top_strip.size = Vector2(w - 16, 50)
    brand.position = Vector2(9, 3)
    brand.size = Vector2(70, 30)
    brand.add_theme_font_size_override("font_size", 18 if w >= 380.0 else 16)
    location_label.visible = false
    day_label.visible = true
    var compact := w < 390.0
    cash_label.position = Vector2(w - (205.0 if compact else 230.0), 5)
    cash_label.size = Vector2(68.0 if compact else 80.0, 28)
    rep_label.position = Vector2(w - (130.0 if compact else 150.0), 5)
    rep_label.size = Vector2(62.0 if compact else 70.0, 28)
    day_label.position = Vector2(w - 62.0, 5)
    day_label.size = Vector2(58.0, 28)
    cash_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    rep_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    day_label.add_theme_font_size_override("font_size", 10)

func _process(delta: float) -> void:
    super._process(delta)
    if parent == null:
        return
    if selected_title != null:
        selected_title.text = _selected_title()
    if selected_meta != null:
        selected_meta.text = _selected_meta()
