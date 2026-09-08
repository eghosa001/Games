extends "res://scripts/renew_sims_ui.gd"

# Final responsive presentation pass. One authoritative action grid is used on
# desktop and mobile so every button reaches the same gameplay callbacks.

const ACTIVE_TAB := Color("d7b86f")
const INACTIVE_TAB := Color("102a32")
const TAB_TEXT := Color("e7f2ef")
const TAB_MUTED := Color("78949a")

func _sync_mobile_actions() -> void:
    # Do not duplicate callbacks into the legacy mobile grid.
    for child in mobile_actions.get_children():
        child.queue_free()

func _style_mode_buttons() -> void:
    if mode_buttons.is_empty():
        return
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i] as Button
        if button == null:
            continue
        var normal := StyleBoxFlat.new()
        normal.bg_color = ACTIVE_TAB if i == active_tab else INACTIVE_TAB
        normal.border_color = ACTIVE_TAB if i == active_tab else Color("24434b")
        normal.set_border_width_all(1)
        normal.set_corner_radius_all(8)
        normal.content_margin_left = 6
        normal.content_margin_right = 6
        normal.content_margin_top = 5
        normal.content_margin_bottom = 5
        var hover := normal.duplicate()
        hover.bg_color = Color("183b43")
        hover.border_color = ACTIVE_TAB
        var pressed := hover.duplicate()
        pressed.bg_color = Color("244f50")
        button.add_theme_stylebox_override("normal", normal)
        button.add_theme_stylebox_override("hover", hover)
        button.add_theme_stylebox_override("pressed", pressed)
        button.add_theme_color_override("font_color", TAB_TEXT if i == active_tab else TAB_MUTED)
        button.add_theme_color_override("font_hover_color", Color.WHITE)
        button.add_theme_font_size_override("font_size", 10 if root.size.x < 390.0 else 11)
        button.custom_minimum_size = Vector2(44, 44)

func _layout_responsive() -> void:
    super._layout_responsive()
    if root == null:
        return
    var s := root.size
    var w := maxf(s.x, 320.0)
    var h := maxf(s.y, 480.0)

    _style_mode_buttons()
    if mode_rail != null:
        mode_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for child in mode_rail.get_children():
            if child is Control:
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        # Buttons must remain interactive after the rail itself is made passive.
        for button in mode_buttons:
            if button is Control:
                button.mouse_filter = Control.MOUSE_FILTER_STOP

    if not narrow:
        return

    # Mobile: world first, compact status bar, mode tabs, then a contained
    # command sheet. Nothing important is allowed to sit under the browser
    # edge or collide with the mode tabs on short phone screens.
    mode_rail.visible = true
    mode_rail.position = Vector2(8, 64)
    mode_rail.size = Vector2(w - 16, 44)

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
    if right_card != null: right_card.visible = false
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

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3)
    _refresh()
    _style_mode_buttons()

func _action(text: String, callback: Callable) -> void:
    super._action(text, callback)
    if action_grid == null or action_grid.get_child_count() == 0:
        return
    var button := action_grid.get_child(action_grid.get_child_count() - 1) as Button
    if button == null:
        return
    button.tooltip_text = _action_hint(text)
    button.add_theme_font_size_override("font_size", 10 if narrow else 11)

func _action_hint(text: String) -> String:
    match text:
        "END DAY": return "Advance the simulation by one in-game day."
        "DASHBOARD": return "Open the company overview."
        "ASSETS": return "Review properties, assets and holdings."
        "FINANCE": return "Open financing and balance-sheet tools."
        "DEALS": return "Review contracts and commercial deals."
        "STAFF": return "Manage employees and executives."
        "NETWORK": return "Open the corporate network."
        "PACT": return "Open alliance management."
        "TECH": return "Research and manage technology."
        "WORLD": return "Open world news and developments."
        "PAST": return "Review company history."
        "SAVE": return "Save your current company state."
        "LOAD": return "Load the latest saved company state."
        "NEW COMPANY": return "Start a new dynasty after victory."
        _:
            return "Execute %s." % text.to_lower()

func _process(delta: float) -> void:
    super._process(delta)
    if parent == null:
        return
    if selected_title != null:
        selected_title.text = _selected_title()
    if selected_meta != null:
        selected_meta.text = _selected_meta()
