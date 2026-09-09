extends "res://scripts/renew_sims_ui.gd"

const ACTIVE_TAB := Color("d7b86f")
const INACTIVE_TAB := Color("102a32")
const TAB_TEXT := Color("e7f2ef")
const TAB_MUTED := Color("78949a")
const HUD_REFRESH_INTERVAL := 0.20
var _hud_refresh_accum := 0.0

func _sync_mobile_actions() -> void:
    for child in mobile_actions.get_children(): child.queue_free()

func _style_mode_buttons() -> void:
    if mode_buttons.is_empty(): return
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i] as Button
        if button == null: continue
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
    if root == null: return
    var s := root.size
    var w := maxf(s.x, 320.0)
    var h := maxf(s.y, 480.0)
    _style_mode_buttons()
    if mode_rail != null:
        mode_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for child in mode_rail.get_children():
            if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for button in mode_buttons:
            if button is Control: button.mouse_filter = Control.MOUSE_FILTER_STOP
    if not narrow: return
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
    bottom_mobile.visible = false
    mobile_actions.visible = false
    mobile_objective.visible = false
    left_rail.visible = false
    selected_card.visible = false
    objective_card.visible = false
    if right_card != null: right_card.visible = false
    network_strip.visible = false
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
    if action_grid == null or action_grid.get_child_count() == 0: return
    var button := action_grid.get_child(action_grid.get_child_count() - 1) as Button
    if button == null: return
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
        "REGIONS": return "Manage regional expansion and presence."
        "INFRASTRUCTURE": return "Build and repair regional infrastructure."
        "MISSIONS": return "Review world opportunities and missions."
        "PRODUCTION": return "Open the production command center."
        "LOGISTICS": return "Manage supply chain and internal logistics."
        "EXPANSION": return "Manage expansion businesses."
        "INTELLIGENCE": return "Review empire intelligence and strategic signals."
        "PROPERTY MAP": return "Focus the property and district map."
        "HQ": return "Manage headquarters upgrades and corporate services."
        "CUSTOMERS": return "Review customer segments and demand."
        "LIVE OPS": return "Review seasonal events and live operations."
        "OPPORTUNITIES": return "Review strategic world opportunities."
        _:
            return "Execute %s." % text.to_lower()

func _tab_subtitle() -> String:
    match active_tab:
        0: return "Manage property, restoration and your first operating site."
        1: return "Run production, staffing, pricing, contracts and finance."
        2: return "Manage rivals, alliances, investment, shares and corporate power."
        3: return "Expand regions, infrastructure, logistics, technology and world activity."
        _: return "Choose an action."

func _mobile_context() -> String:
    if parent == null: return "PROPERTY • INITIALIZING"
    var ownership := "OWNED" if bool(parent.owned) else "AVAILABLE"
    var business := "OPEN" if bool(parent.business_open) else "CLOSED"
    return "PROPERTY %s • %d%% RESTORED • BUSINESS %s" % [ownership, int(parent.restoration), business]

func _refresh() -> void:
    super._refresh()
    if action_grid == null: return
    match active_tab:
        0:
            _action("PROPERTY MAP", Callable(self, "_focus_property_map"))
        1:
            _action("PRODUCTION", Callable(self, "_open_screen").bind("ProductionControlPanel"))
            _action("CUSTOMERS", Callable(self, "_open_screen").bind("CustomerSegmentsUI"))
        2:
            _action("INTELLIGENCE", Callable(self, "_open_screen").bind("EmpireIntelligencePanel"))
            _action("HQ", Callable(self, "_open_screen").bind("HeadquartersPanel"))
        3:
            _action("REGIONS", Callable(self, "_open_screen").bind("RegionsPanel"))
            _action("INFRASTRUCTURE", Callable(self, "_open_screen").bind("InfrastructurePanel"))
            _action("MISSIONS", Callable(self, "_open_screen").bind("WorldOpportunitiesPanel"))
            _action("PRODUCTION", Callable(self, "_open_screen").bind("ProductionControlPanel"))
            _action("LOGISTICS", Callable(self, "_open_screen").bind("SupplyChainPanel"))
            _action("EXPANSION", Callable(self, "_open_screen").bind("EmpireExpansionPanel"))
            _action("INTELLIGENCE", Callable(self, "_open_screen").bind("EmpireIntelligencePanel"))
            _action("LIVE OPS", Callable(self, "_open_screen").bind("LiveOpsPanel"))

func _focus_property_map() -> void:
    var map := get_tree().root.get_node_or_null("Renew/World/PropertyMap")
    if map != null:
        map.show()
        map.queue_redraw()
        if parent != null:
            parent.message = "Property map focused. Select a property on the district map."
            show_feedback(str(parent.message))
    elif parent != null:
        parent.message = "Property map is unavailable."
        show_feedback(str(parent.message))

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
    else:
        var scene := get_tree().current_scene if get_tree() != null else null
        if scene != null:
            var node := scene.get_node_or_null("UI/" + screen_name)
            if node != null: node.show()

func _process(delta: float) -> void:
    _hud_refresh_accum += delta
    if _hud_refresh_accum < HUD_REFRESH_INTERVAL:
        return
    _hud_refresh_accum = 0.0
    if parent == null: return
    if action_subtitle != null: action_subtitle.text = _tab_subtitle()
    if selected_title != null: selected_title.text = _selected_title()
    if selected_meta != null: selected_meta.text = _selected_meta()
    if narrow and status_label != null: status_label.text = _mobile_context()
