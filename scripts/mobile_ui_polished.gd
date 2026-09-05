extends "res://scripts/mobile_ui.gd"

# Premium presentation layer for the mobile/web build.
# Gameplay actions remain in mobile_ui.gd; this layer owns responsive layout,
# touch sizing and the player-facing restoration/cooperation story.
var top_bar: ColorRect
var bottom_bar: ColorRect
var status_panel: Panel
var network_panel: Panel
var network_title: Label
var network_summary: Label
var network_cards: HBoxContainer
var button_theme: Theme
var tab_normal_style: StyleBoxFlat
var tab_active_style: StyleBoxFlat
var tab_hover_style: StyleBoxFlat
var panel_style: StyleBoxFlat
var accent_line: ColorRect
var network_refresh_clock := 0.0

func _build_ui() -> void:
    root = Control.new(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    top_bar = ColorRect.new(); top_bar.color = Color("0b151a"); top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top_bar)
    accent_line = ColorRect.new(); accent_line.color = Color("d5b56b"); accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(accent_line)
    var brand := Label.new(); brand.text = "RENEW"; brand.name = "Brand"; brand.add_theme_font_size_override("font_size", 22); brand.add_theme_color_override("font_color", Color("edf7f4")); brand.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(brand)
    var subtitle := Label.new(); subtitle.text = "RESTORE  /  OPERATE  /  COOPERATE  /  EXPAND"; subtitle.name = "Subtitle"; subtitle.add_theme_font_size_override("font_size", 9); subtitle.add_theme_color_override("font_color", Color("81979b")); subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(subtitle)
    tabs = HBoxContainer.new(); tabs.add_theme_constant_override("separation", 7); tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tabs)
    for i in range(tab_names.size()):
        var button := Button.new(); button.text = tab_names[i]; button.focus_mode = Control.FOCUS_NONE; button.mouse_filter = Control.MOUSE_FILTER_STOP; button.pressed.connect(_set_tab.bind(i)); tabs.add_child(button)
    status_panel = Panel.new(); status_panel.name = "StatusPill"; status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(status_panel)
    status_label = Label.new(); status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; status_label.add_theme_font_size_override("font_size", 12); status_label.add_theme_color_override("font_color", Color("d7e6e3")); status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; status_panel.add_child(status_label)
    action_scroll = ScrollContainer.new(); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; action_scroll.focus_mode = Control.FOCUS_NONE; action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(action_scroll)
    actions = GridContainer.new(); actions.add_theme_constant_override("h_separation", 9); actions.add_theme_constant_override("v_separation", 8); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE; action_scroll.add_child(actions)
    network_panel = Panel.new(); network_panel.name = "RestorationNetwork"; network_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(network_panel)
    network_title = Label.new(); network_title.text = "RESTORATION NETWORK"; network_title.add_theme_font_size_override("font_size", 13); network_title.add_theme_color_override("font_color", Color("e8f1ee")); network_title.mouse_filter = Control.MOUSE_FILTER_IGNORE; network_panel.add_child(network_title)
    network_summary = Label.new(); network_summary.add_theme_font_size_override("font_size", 10); network_summary.add_theme_color_override("font_color", Color("93acae")); network_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE; network_panel.add_child(network_summary)
    network_cards = HBoxContainer.new(); network_cards.add_theme_constant_override("separation", 8); network_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE; network_panel.add_child(network_cards)
    feedback_panel = Panel.new(); feedback_panel.name = "FeedbackCard"; feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.hide(); root.add_child(feedback_panel)
    feedback_label = Label.new(); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; feedback_label.add_theme_font_size_override("font_size", 14); feedback_label.add_theme_color_override("font_color", Color("dce8e8")); feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.add_child(feedback_label)
    goal_label = Label.new(); goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; goal_label.add_theme_font_size_override("font_size", 13); goal_label.add_theme_color_override("font_color", Color("b7cec9")); goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(goal_label)
    bottom_bar = ColorRect.new(); bottom_bar.color = Color("0b151a"); bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bottom_bar)
    button_theme = _make_button_theme(); panel_style = _make_panel_style(); feedback_panel.add_theme_stylebox_override("panel", panel_style); status_panel.add_theme_stylebox_override("panel", _make_status_style()); network_panel.add_theme_stylebox_override("panel", _make_network_style())
    _layout_responsive(); _apply_tab_state(); _refresh_network()

func _make_button_theme() -> Theme:
    var theme := Theme.new(); theme.default_font_size = 14
    var normal := StyleBoxFlat.new(); normal.bg_color = Color("15272e"); normal.border_color = Color("36545c"); normal.set_border_width_all(1); normal.set_corner_radius_all(9); normal.content_margin_left = 10.0; normal.content_margin_right = 10.0; normal.content_margin_top = 7.0; normal.content_margin_bottom = 7.0; normal.shadow_color = Color(0, 0, 0, 0.28); normal.shadow_size = 4
    var hover := normal.duplicate(); hover.bg_color = Color("23464a"); hover.border_color = Color("d5b56b"); hover.shadow_color = Color(0.18, 0.55, 0.48, 0.22); hover.shadow_size = 6
    var pressed := hover.duplicate(); pressed.bg_color = Color("35645f"); pressed.border_color = Color("e4c77f")
    var disabled := normal.duplicate(); disabled.bg_color = Color("10191d"); disabled.border_color = Color("203137")
    theme.set_stylebox("normal", "Button", normal); theme.set_stylebox("hover", "Button", hover); theme.set_stylebox("pressed", "Button", pressed); theme.set_stylebox("disabled", "Button", disabled)
    theme.set_color("font_color", "Button", Color("d8e5e6")); theme.set_color("font_hover_color", "Button", Color("ffffff")); theme.set_color("font_pressed_color", "Button", Color("ffffff")); theme.set_color("font_disabled_color", "Button", Color("66787d")); return theme
func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = Color("12232b"); style.border_color = Color("35535b"); style.set_border_width_all(1); style.set_corner_radius_all(10); style.shadow_color = Color(0, 0, 0, 0.34); style.shadow_size = 8; return style
func _make_network_style() -> StyleBoxFlat:
    var style := _make_panel_style(); style.bg_color = Color("0f2228"); style.border_color = Color("3c6b67"); return style
func _make_status_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = Color("15262b"); style.border_color = Color("31534f"); style.set_border_width_all(1); style.set_corner_radius_all(14); return style
func _make_tab_style(active: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = Color("244b4b") if active else Color("12232b"); style.border_color = Color("d5b56b") if active else Color("2f4b53"); style.set_border_width_all(1); style.set_corner_radius_all(9); style.content_margin_top = 5.0; style.content_margin_bottom = 5.0; return style

func _apply_tab_state() -> void:
    if tabs == null: return
    tab_normal_style = _make_tab_style(false); tab_active_style = _make_tab_style(true); tab_hover_style = _make_tab_style(false); tab_hover_style.bg_color = Color("20383f"); tab_hover_style.border_color = Color("557d78")
    for i in range(tabs.get_child_count()):
        var child := tabs.get_child(i)
        if child is Button:
            child.theme = button_theme; child.add_theme_stylebox_override("normal", tab_active_style if i == active_tab else tab_normal_style); child.add_theme_stylebox_override("hover", tab_hover_style); child.add_theme_stylebox_override("pressed", tab_active_style); child.add_theme_color_override("font_color", Color("f1f8f6") if i == active_tab else Color("9bb0b1")); child.add_theme_color_override("font_hover_color", Color("ffffff"))
func _set_tab(index: int) -> void:
    super._set_tab(index); _apply_tab_state(); _layout_responsive(); _refresh_network()
func _refresh() -> void:
    super._refresh(); call_deferred("_layout_responsive"); call_deferred("_refresh_network")
func _process(delta: float) -> void:
    super._process(delta); network_refresh_clock += delta
    if network_refresh_clock >= 1.0: network_refresh_clock = 0.0; _refresh_network()
func _button(text: String, callback: Callable) -> void:
    var b := Button.new(); b.text = text; b.tooltip_text = "Tap to " + text.to_lower(); b.focus_mode = Control.FOCUS_NONE; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.theme = button_theme; b.pressed.connect(_run_action.bind(text, callback)); actions.add_child(b)
func _browser_size() -> Vector2:
    if not OS.has_feature("web"): return Vector2.ZERO
    var result = JavaScriptBridge.eval("[Math.round(window.innerWidth), Math.round(window.innerHeight)]")
    if result is Array and result.size() >= 2: return Vector2(maxf(1.0, float(result[0])), maxf(1.0, float(result[1])))
    return Vector2.ZERO
func _partner_list() -> Array:
    var result: Array = []
    if parent == null or parent.rivals == null: return result
    for rival in parent.rivals.rivals: result.append(rival)
    return result
func _refresh_network() -> void:
    if network_panel == null: return
    for child in network_cards.get_children(): child.queue_free()
    var partners := _partner_list(); var stage := String(parent.stage) if parent != null else "Unknown"; var restored := stage == "Operational"
    network_summary.text = ("RESTORED • cooperative supply, logistics and capital can accelerate the next district" if restored else "BUILD TOGETHER • materials, logistics and sustainable construction can support restoration")
    for rival in partners:
        var card := Panel.new(); card.custom_minimum_size = Vector2(190, 58); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var card_style := StyleBoxFlat.new(); card_style.bg_color = Color("142b31"); card_style.border_color = Color("31585c"); card_style.set_border_width_all(1); card_style.set_corner_radius_all(7); card.add_theme_stylebox_override("panel", card_style)
        var name := Label.new(); name.text = str(rival.get("name", "Corporate Partner")); name.position = Vector2(8, 5); name.size = Vector2(174, 18); name.add_theme_font_size_override("font_size", 11); name.add_theme_color_override("font_color", Color("e4efec")); name.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(name)
        var role := Label.new(); role.text = "%s  •  relationship %d" % [str(rival.get("strength", "general")).capitalize(), int(rival.get("relationship", 0))]; role.position = Vector2(8, 24); role.size = Vector2(174, 16); role.add_theme_font_size_override("font_size", 9); role.add_theme_color_override("font_color", Color("8eaaa9")); role.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(role)
        var signal := Label.new(); signal.text = "READY TO COOPERATE" if int(rival.get("relationship", 0)) >= 0 else "RELATIONSHIP TO BUILD"; signal.position = Vector2(8, 40); signal.size = Vector2(174, 14); signal.add_theme_font_size_override("font_size", 8); signal.add_theme_color_override("font_color", Color("d5b56b") if int(rival.get("relationship", 0)) >= 0 else Color("789096")); signal.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(signal)
        network_cards.add_child(card)
    network_panel.visible = active_tab == 0 or active_tab == 2

func _layout_responsive() -> void:
    if root == null or tabs == null or action_scroll == null or actions == null: return
    var logical_size := get_viewport().get_visible_rect().size; var browser := _browser_size(); var narrow := logical_size.x < 700.0 or (browser.x > 0.0 and browser.x < 700.0)
    if narrow and browser.x > 0.0: scale = Vector2(maxf(1.0, logical_size.x / browser.x), maxf(1.0, logical_size.x / browser.x))
    else: scale = Vector2.ONE
    var w := browser.x if narrow and browser.x > 0.0 else logical_size.x; var h := browser.y if narrow and browser.y > 0.0 else logical_size.y
    if w <= 1.0 or h <= 1.0: return
    top_bar.position = Vector2.ZERO; top_bar.size = Vector2(w, 64.0); accent_line.position = Vector2(18, 62); accent_line.size = Vector2(112, 2)
    var brand := root.get_node_or_null("Brand") as Label; if brand != null: brand.position = Vector2(18, 7); brand.size = Vector2(180, 34)
    var subtitle := root.get_node_or_null("Subtitle") as Label; if subtitle != null: subtitle.position = Vector2(18, 37); subtitle.size = Vector2(300, 20)
    if narrow:
        tabs.position = Vector2(8, 8); tabs.size = Vector2(w - 16.0, 42.0); var tab_width := maxf(64.0, (w - 37.0) / 4.0)
        for child in tabs.get_children():
            if child is Button: child.custom_minimum_size = Vector2(tab_width, 40.0); child.add_theme_font_size_override("font_size", 10)
        status_panel.position = Vector2(8, 54); status_panel.size = Vector2(w - 16.0, 28.0); status_label.position = Vector2(8, 2); status_label.size = Vector2(w - 32.0, 24.0); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        var network_visible := active_tab == 0 or active_tab == 2; action_scroll.position = Vector2(8, 88); action_scroll.size = Vector2(w - 16.0, 218.0 if network_visible else minf(250.0, maxf(150.0, h * 0.30))); actions.columns = 2; actions.custom_minimum_size = Vector2(w - 16.0, 0); var button_width := maxf(150.0, (w - 25.0) / 2.0)
        for child in actions.get_children():
            if child is Button: child.custom_minimum_size = Vector2(button_width, 46.0); child.add_theme_font_size_override("font_size", 12)
        network_panel.position = Vector2(8, 316); network_panel.size = Vector2(w - 16.0, 112.0); network_title.position = Vector2(10, 7); network_title.size = Vector2(w - 32.0, 18); network_summary.position = Vector2(10, 26); network_summary.size = Vector2(w - 32.0, 24); network_cards.position = Vector2(10, 53); network_cards.size = Vector2(w - 28.0, 50)
        for child in network_cards.get_children(): child.custom_minimum_size = Vector2(maxf(150.0, (w - 38.0) / 3.0), 50.0)
        network_panel.visible = network_visible; feedback_panel.position = Vector2(8, 438 if network_visible else 320); feedback_panel.size = Vector2(w - 16.0, 70.0); feedback_label.position = Vector2(12, 6); feedback_label.size = Vector2(w - 40.0, 58.0); goal_label.position = Vector2(8, 514 if network_visible else 396); goal_label.size = Vector2(w - 16.0, 58.0); bottom_bar.position = Vector2(0, maxf(0.0, h - 82.0)); bottom_bar.size = Vector2(w, 82.0)
    else:
        tabs.position = Vector2(270, 10); tabs.size = Vector2(minf(700.0, w - 570.0), 44.0); var tab_width := maxf(110.0, (tabs.size.x - 21.0) / 4.0)
        for child in tabs.get_children():
            if child is Button: child.custom_minimum_size = Vector2(tab_width, 42.0)
        status_panel.position = Vector2(maxf(730.0, w - 420.0), 14); status_panel.size = Vector2(minf(270.0, w - status_panel.position.x - 12.0), 30.0); status_label.position = Vector2(10, 3); status_label.size = Vector2(status_panel.size.x - 20.0, 24.0); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        action_scroll.position = Vector2(18, 76); action_scroll.size = Vector2(w - 36.0, 150.0); actions.columns = 3; actions.custom_minimum_size = Vector2(w - 36.0, 0)
        for child in actions.get_children():
            if child is Button: child.custom_minimum_size = Vector2(225.0, 48.0)
        network_panel.position = Vector2(18, 238); network_panel.size = Vector2(minf(760.0, w - 36.0), 112.0); network_title.position = Vector2(14, 8); network_title.size = Vector2(400, 20); network_summary.position = Vector2(14, 28); network_summary.size = Vector2(720, 22); network_cards.position = Vector2(14, 54); network_cards.size = Vector2(732, 50)
        for child in network_cards.get_children(): child.custom_minimum_size = Vector2(190, 50)
        network_panel.visible = active_tab == 0 or active_tab == 2; feedback_panel.position = Vector2(18, 362); feedback_panel.size = Vector2(minf(760.0, w - 36.0), 86.0); feedback_label.position = Vector2(18, 8); feedback_label.size = Vector2(feedback_panel.size.x - 36.0, 70.0); goal_label.position = Vector2(18, 462); goal_label.size = Vector2(minf(920.0, w - 36.0), 48.0); bottom_bar.position = Vector2(0, maxf(0.0, h - 64.0)); bottom_bar.size = Vector2(w, 64.0)
    _apply_tab_state()
