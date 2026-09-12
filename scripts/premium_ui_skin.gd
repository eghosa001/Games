extends Control

## RENEW premium presentation skin.
## Keeps gameplay callbacks/node names intact while unifying all screens into a
## restrained glass command deck that lets the illustrated world remain visible.
## The active-screen pass also upgrades every managed detail screen at runtime:
## desktop dialogs become asymmetric command surfaces with a live executive rail,
## while phone layouts keep their authored responsive geometry.

const THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const DEEP := Color("071218")
const SURFACE := Color("0b2028")
const SURFACE_2 := Color("12313a")
const EDGE := Color("416a70")
const GOLD := Color("f2c65c")
const GREEN := Color("58d39b")
const CYAN := Color("55c7e8")
const BLUE := Color("6f9cff")
const PURPLE := Color("b78cff")
const ORANGE := Color("ff9d62")
const PINK := Color("ed7fbd")
const TEXT := Color("f4faf7")
const MUTED := Color("91a9ad")
const SUBTLE := Color("5d767b")
const PRIMARY_SECTORS := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
const CONTEXT_RAIL_NAME := "PremiumContextRail"

var hud_root: Control
var _theme: Theme
var _theme_refresh_queued := false
var _pulse := 0.0
var _last_redraw := 0.0
var _screen_polish_clock := 0.0
var _last_active_screen := ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _theme = load(THEME_PATH) as Theme
    if not get_tree().tree_changed.is_connected(_queue_theme_refresh):
        get_tree().tree_changed.connect(_queue_theme_refresh)
    call_deferred("_install")

func _process(delta: float) -> void:
    _pulse += delta
    _last_redraw += delta
    _screen_polish_clock += delta
    if _last_redraw >= 0.20:
        _last_redraw = 0.0
        queue_redraw()
    if _screen_polish_clock >= 0.20:
        _screen_polish_clock = 0.0
        _refresh_active_screen_presentation()

func _install() -> void:
    var main_hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if main_hud != null:
        hud_root = main_hud.get("root") as Control
        _align_functional_navigation(main_hud)
    if hud_root == null and get_parent() is Control:
        hud_root = get_parent() as Control
    _apply_theme_to_all_ui()
    if hud_root != null:
        _style_existing_controls(hud_root)
    _refresh_active_screen_presentation()
    queue_redraw()

func _queue_theme_refresh() -> void:
    if _theme_refresh_queued:
        return
    _theme_refresh_queued = true
    call_deferred("_run_theme_refresh")

func _run_theme_refresh() -> void:
    _theme_refresh_queued = false
    var main_hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if main_hud != null:
        _align_functional_navigation(main_hud)
    _apply_theme_to_all_ui()
    if hud_root != null and is_instance_valid(hud_root):
        _style_existing_controls(hud_root)
    _refresh_active_screen_presentation()

func _align_functional_navigation(main_hud: Node) -> void:
    var left_rail := main_hud.get("left_rail") as Panel
    if left_rail == null or left_rail.get_child_count() == 0:
        return
    var stack := left_rail.get_child(0)
    if stack == null:
        return
    var index := 0
    for child in stack.get_children():
        if child is Button and index < PRIMARY_SECTORS.size():
            (child as Button).text = PRIMARY_SECTORS[index]
            index += 1

func _apply_theme_to_all_ui() -> void:
    if _theme == null:
        return
    var game_root := get_tree().root.get_node_or_null("Renew")
    if game_root == null:
        return
    var ui := game_root.get_node_or_null("UI")
    if ui != null:
        _apply_theme_recursive(ui)

func _apply_theme_recursive(node: Node) -> void:
    if node is Control and node != self:
        var c := node as Control
        c.theme = _theme
        c.add_theme_font_size_override("font_size", _theme.default_font_size)
    for child in node.get_children():
        _apply_theme_recursive(child)

func _style_existing_controls(node: Node) -> void:
    for child in node.get_children():
        if child == self:
            continue
        if child is Button:
            _style_button(child as Button)
        elif child is Panel:
            _style_panel(child as Panel)
        elif child is Label:
            _style_label(child as Label)
        elif child is ProgressBar:
            _style_progress(child as ProgressBar)
        elif child is LineEdit:
            _style_line_edit(child as LineEdit)
        elif child is ColorRect:
            var rect := child as ColorRect
            if rect.name != "PremiumChromeBackground":
                rect.color = Color(rect.color.r, rect.color.g, rect.color.b, minf(rect.color.a, 0.13))
        if child is Control:
            _style_existing_controls(child)

func _sector_accent(label: String) -> Color:
    var t := label.to_upper()
    if t.contains("FINANCE") or t.contains("LOAN") or t.contains("CASH") or t.contains("PORTFOLIO") or t.contains("CAPITAL"):
        return GREEN
    if t.contains("EMPLOYEE") or t.contains("HIRE") or t.contains("PEOPLE") or t.contains("HEADQUARTERS"):
        return PINK
    if t.contains("PRODUCE") or t.contains("PRODUCTION") or t.contains("SUPPLY") or t.contains("INPUT") or t.contains("OPERAT") or t.contains("INFRA") or t.contains("BUSINESS"):
        return ORANGE
    if t.contains("NETWORK") or t.contains("ALLIANCE") or t.contains("RIVAL") or t.contains("RELATION") or t.contains("EMPIRE") or t.contains("CORPORATION"):
        return PURPLE
    if t.contains("WORLD") or t.contains("MARKET") or t.contains("REGION") or t.contains("EXPANSION") or t.contains("DIPLOMACY"):
        return CYAN
    if t.contains("TECHNOLOGY") or t.contains("RESEARCH") or t.contains("INTELLIGENCE"):
        return BLUE
    if t.contains("NEWS") or t.contains("HISTORY") or t.contains("EVENT"):
        return GOLD
    if t.contains("LIVE") or t.contains("DASHBOARD") or t.contains("PROPERTY"):
        return GREEN
    return EDGE

func _style_panel(panel: Panel) -> void:
    var accent := _sector_accent(panel.name)
    var box := StyleBoxFlat.new()
    box.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.84)
    box.border_color = Color(accent.r, accent.g, accent.b, 0.34)
    box.set_border_width_all(1)
    box.set_border_width(SIDE_TOP, 2)
    box.set_corner_radius_all(16)
    box.shadow_color = Color(0, 0, 0, 0.46)
    box.shadow_size = 12
    box.shadow_offset = Vector2(0, 5)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 12
    box.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", box)

func _style_button(button: Button) -> void:
    var accent := _sector_accent(button.text)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.82)
    normal.border_color = Color(accent.r, accent.g, accent.b, 0.34)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = SURFACE_2.lerp(accent, 0.17)
    hover.border_color = Color(accent.r, accent.g, accent.b, 0.92)
    hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
    hover.shadow_size = 10
    hover.shadow_offset = Vector2(0, 2)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = SURFACE_2.lerp(accent, 0.26)
    pressed.border_color = accent
    pressed.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
    pressed.shadow_size = 5

    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("09171d", 0.72)
    disabled.border_color = Color("253a40", 0.45)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 11)
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 44.0)

func _style_label(label: Label) -> void:
    var name_upper := label.name.to_upper()
    var text_upper := label.text.to_upper()
    if name_upper.contains("TITLE") or name_upper.contains("HEADER") or text_upper.begins_with("RENEW"):
        label.add_theme_color_override("font_color", TEXT)
        label.add_theme_font_size_override("font_size", maxi(16, label.get_theme_font_size("font_size")))
    elif name_upper.contains("VALUE") or name_upper.contains("TOTAL") or name_upper.contains("AMOUNT"):
        label.add_theme_color_override("font_color", Color("f5deb0"))
    else:
        label.add_theme_color_override("font_color", Color(TEXT.r, TEXT.g, TEXT.b, 0.91))

func _style_progress(progress: ProgressBar) -> void:
    var accent := _sector_accent(progress.name)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color("07151a", 0.70)
    bg.set_corner_radius_all(7)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(accent.r, accent.g, accent.b, 0.92)
    fill.set_corner_radius_all(7)
    fill.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
    fill.shadow_size = 4
    progress.add_theme_stylebox_override("background", bg)
    progress.add_theme_stylebox_override("fill", fill)
    progress.add_theme_color_override("font_color", TEXT)

func _style_line_edit(line: LineEdit) -> void:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("07171d", 0.80)
    box.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.62)
    box.set_border_width_all(1)
    box.set_corner_radius_all(10)
    box.content_margin_left = 12
    box.content_margin_right = 12
    line.add_theme_stylebox_override("normal", box)
    line.add_theme_color_override("font_color", TEXT)
    line.add_theme_color_override("font_placeholder_color", MUTED)

# --- Managed-screen premium composition ------------------------------------

func _refresh_active_screen_presentation() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager == null or not manager.has_method("get_active_screen_name"):
        return
    var active_name := str(manager.call("get_active_screen_name"))
    _soften_manager_backdrop(active_name != "")
    if active_name == "":
        _last_active_screen = ""
        return

    var screen := _find_active_screen(active_name)
    if screen == null:
        return

    if active_name != _last_active_screen:
        _last_active_screen = active_name
        _apply_theme_recursive(screen)
        _style_existing_controls(screen)
        _soften_scrims_recursive(screen)
        _ensure_context_rail(screen, active_name)

    _soften_scrims_recursive(screen)
    _layout_context_rail(screen, active_name)
    _dock_primary_panel(screen, active_name)
    _update_context_rail(screen, active_name)

func _find_active_screen(active_name: String) -> Node:
    var screen := get_node_or_null("/root/Renew/UI/" + active_name)
    if screen == null:
        screen = get_node_or_null("/root/Renew/" + active_name)
    if screen == null:
        screen = get_tree().root.get_node_or_null(active_name)
    return screen

func _soften_manager_backdrop(active: bool) -> void:
    var backdrop := get_node_or_null("/root/Renew/UI/FocusedScreenBackdrop/Backdrop") as ColorRect
    if backdrop != null:
        var alpha := 0.28 if active else 0.0
        backdrop.color = Color(0.012, 0.028, 0.036, alpha)

func _soften_scrims_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is ColorRect:
            var rect := child as ColorRect
            var n := rect.name.to_lower()
            if n.contains("scrim") or n.contains("dimmer") or n.contains("backdrop"):
                rect.color = Color(rect.color.r, rect.color.g, rect.color.b, minf(rect.color.a, 0.38))
        _soften_scrims_recursive(child)

func _primary_panel(screen: Node) -> Panel:
    var best: Panel = null
    var best_area := 0.0
    for child in screen.get_children():
        if child is Panel and child.name != CONTEXT_RAIL_NAME:
            var panel := child as Panel
            var area := panel.size.x * panel.size.y
            if area > best_area:
                best = panel
                best_area = area
    if best != null:
        return best
    return _first_panel_recursive(screen)

func _first_panel_recursive(node: Node) -> Panel:
    for child in node.get_children():
        if child is Panel and child.name != CONTEXT_RAIL_NAME:
            return child as Panel
        var nested := _first_panel_recursive(child)
        if nested != null:
            return nested
    return null

func _dock_primary_panel(screen: Node, active_name: String) -> void:
    var viewport := get_viewport_rect().size
    if viewport.x < 980.0:
        return
    if active_name == "DashboardPanel":
        return
    var panel := _primary_panel(screen)
    if panel == null or panel.size.x <= 1.0 or panel.size.y <= 1.0:
        return
    # Large authored command centers already use the canvas deliberately. Only
    # recompose narrow legacy/modal surfaces into a right-hand executive deck.
    if panel.size.x > minf(760.0, viewport.x * 0.66):
        return
    var target_x := viewport.x - panel.size.x - 42.0
    var minimum_x := viewport.x * 0.43
    panel.position.x = maxf(minimum_x, target_x)
    panel.position.y = maxf(54.0, panel.position.y)

func _ensure_context_rail(screen: Node, active_name: String) -> void:
    if screen.get_node_or_null(CONTEXT_RAIL_NAME) != null:
        return
    var rail := Panel.new()
    rail.name = CONTEXT_RAIL_NAME
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rail.z_index = 1
    rail.theme = _theme
    rail.add_theme_stylebox_override("panel", _context_rail_style(_sector_accent(active_name)))
    screen.add_child(rail)

    var eyebrow := Label.new()
    eyebrow.name = "Eyebrow"
    eyebrow.text = "RENEW // EXECUTIVE NETWORK"
    eyebrow.add_theme_color_override("font_color", MUTED)
    eyebrow.add_theme_font_size_override("font_size", 10)
    rail.add_child(eyebrow)

    var title := Label.new()
    title.name = "ContextTitle"
    title.text = _humanize(active_name)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_color_override("font_color", TEXT)
    title.add_theme_font_size_override("font_size", 26)
    rail.add_child(title)

    var subtitle := Label.new()
    subtitle.name = "ContextSubtitle"
    subtitle.text = _context_tagline(active_name)
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_color_override("font_color", _sector_accent(active_name))
    subtitle.add_theme_font_size_override("font_size", 11)
    rail.add_child(subtitle)

    var pulse_label := Label.new()
    pulse_label.name = "PulseLabel"
    pulse_label.text = "COMPANY PULSE"
    pulse_label.add_theme_color_override("font_color", MUTED)
    pulse_label.add_theme_font_size_override("font_size", 9)
    rail.add_child(pulse_label)

    for spec in [["MomentumBar", "MOMENTUM"], ["ReputationBar", "REPUTATION"], ["ReadinessBar", "READINESS"]]:
        var label := Label.new()
        label.name = str(spec[0]) + "Label"
        label.text = str(spec[1])
        label.add_theme_color_override("font_color", MUTED)
        label.add_theme_font_size_override("font_size", 9)
        rail.add_child(label)
        var bar := ProgressBar.new()
        bar.name = str(spec[0])
        bar.show_percentage = false
        bar.min_value = 0.0
        bar.max_value = 100.0
        bar.value = 0.0
        rail.add_child(bar)
        _style_progress(bar)

    var metrics := Label.new()
    metrics.name = "ContextMetrics"
    metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    metrics.add_theme_color_override("font_color", TEXT)
    metrics.add_theme_font_size_override("font_size", 12)
    rail.add_child(metrics)

    var footer := Label.new()
    footer.name = "ContextFooter"
    footer.text = "LIVE MODEL"
    footer.add_theme_color_override("font_color", MUTED)
    footer.add_theme_font_size_override("font_size", 9)
    rail.add_child(footer)

func _context_rail_style(accent: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(DEEP.r, DEEP.g, DEEP.b, 0.82)
    box.border_color = Color(accent.r, accent.g, accent.b, 0.42)
    box.set_border_width_all(1)
    box.set_border_width(SIDE_LEFT, 3)
    box.set_corner_radius_all(18)
    box.shadow_color = Color(0, 0, 0, 0.42)
    box.shadow_size = 16
    box.shadow_offset = Vector2(0, 7)
    box.content_margin_left = 18
    box.content_margin_right = 18
    box.content_margin_top = 18
    box.content_margin_bottom = 18
    return box

func _layout_context_rail(screen: Node, active_name: String) -> void:
    var rail := screen.get_node_or_null(CONTEXT_RAIL_NAME) as Panel
    if rail == null:
        return
    var viewport := get_viewport_rect().size
    if viewport.x < 980.0 or active_name == "DashboardPanel":
        rail.visible = false
        return
    rail.visible = true
    var width := minf(360.0, viewport.x * 0.30)
    var height := minf(520.0, viewport.y - 132.0)
    rail.position = Vector2(42.0, maxf(72.0, (viewport.y - height) * 0.5))
    rail.size = Vector2(width, height)

    var eyebrow := rail.get_node_or_null("Eyebrow") as Label
    var title := rail.get_node_or_null("ContextTitle") as Label
    var subtitle := rail.get_node_or_null("ContextSubtitle") as Label
    var pulse_label := rail.get_node_or_null("PulseLabel") as Label
    if eyebrow != null:
        eyebrow.position = Vector2(22, 20); eyebrow.size = Vector2(width - 44, 18)
    if title != null:
        title.position = Vector2(22, 48); title.size = Vector2(width - 44, 68)
    if subtitle != null:
        subtitle.position = Vector2(22, 116); subtitle.size = Vector2(width - 44, 44)
    if pulse_label != null:
        pulse_label.position = Vector2(22, 178); pulse_label.size = Vector2(width - 44, 16)

    var names := ["MomentumBar", "ReputationBar", "ReadinessBar"]
    for i in range(names.size()):
        var label := rail.get_node_or_null(names[i] + "Label") as Label
        var bar := rail.get_node_or_null(names[i]) as ProgressBar
        var y := 210.0 + float(i) * 54.0
        if label != null:
            label.position = Vector2(22, y); label.size = Vector2(width - 44, 16)
        if bar != null:
            bar.position = Vector2(22, y + 20); bar.size = Vector2(width - 44, 8)

    var metrics := rail.get_node_or_null("ContextMetrics") as Label
    if metrics != null:
        metrics.position = Vector2(22, 382); metrics.size = Vector2(width - 44, maxf(58.0, height - 438.0))
    var footer := rail.get_node_or_null("ContextFooter") as Label
    if footer != null:
        footer.position = Vector2(22, height - 34); footer.size = Vector2(width - 44, 16)

func _update_context_rail(screen: Node, active_name: String) -> void:
    var rail := screen.get_node_or_null(CONTEXT_RAIL_NAME) as Panel
    if rail == null or not rail.visible:
        return
    var state := get_node_or_null("/root/RenewGameState")
    var day := 1
    var cash := 0
    var reputation := 0
    var profit := 0
    var readiness := 0.0
    if state != null and state.has_method("get_value"):
        day = int(state.get_value("player", "day", 1))
        cash = int(state.get_value("economy", "cash", 0))
        reputation = int(state.get_value("player", "reputation", 0))
        profit = int(state.get_value("economy", "total_profit", 0))
        readiness = float(state.get_value("properties", "condition", 0.0))
        if readiness <= 0.0 and str(state.get_value("properties", "stage", "")) == "Operational":
            readiness = 100.0

    var momentum := clampf(18.0 + float(maxi(0, profit)) / 180.0, 8.0, 100.0)
    var rep_value := clampf(float(reputation), 0.0, 100.0)
    var ready_value := clampf(readiness, 0.0, 100.0)
    var momentum_bar := rail.get_node_or_null("MomentumBar") as ProgressBar
    var reputation_bar := rail.get_node_or_null("ReputationBar") as ProgressBar
    var readiness_bar := rail.get_node_or_null("ReadinessBar") as ProgressBar
    if momentum_bar != null: momentum_bar.value = momentum
    if reputation_bar != null: reputation_bar.value = rep_value
    if readiness_bar != null: readiness_bar.value = ready_value

    var metrics := rail.get_node_or_null("ContextMetrics") as Label
    if metrics != null:
        metrics.text = "DAY %d\nCASH  $%s\nREPUTATION  %d\n\n%s" % [day, _compact_number(cash), reputation, _context_signal(active_name)]
    var footer := rail.get_node_or_null("ContextFooter") as Label
    if footer != null:
        footer.text = "LIVE MODEL  •  DAY %d  •  %s" % [day, _context_tagline(active_name)]

func _humanize(value: String) -> String:
    var base := value.replace("Panel", "").replace("UI", "")
    var out := ""
    for i in range(base.length()):
        var ch := base.substr(i, 1)
        if i > 0 and ch == ch.to_upper() and ch != ch.to_lower():
            var prev := base.substr(i - 1, 1)
            if prev != prev.to_upper() or prev == prev.to_lower():
                out += " "
        out += ch
    return out.to_upper()

func _context_tagline(active_name: String) -> String:
    var t := active_name.to_upper()
    if t.contains("FINANCE") or t.contains("PORTFOLIO") or t.contains("CAPITAL") or t.contains("CORPORATION"):
        return "CAPITAL & ASSET CONTROL"
    if t.contains("PRODUCTION") or t.contains("SUPPLY") or t.contains("BUSINESS") or t.contains("CONTRACT") or t.contains("INFRA"):
        return "OPERATIONS NETWORK"
    if t.contains("REGION") or t.contains("WORLD") or t.contains("EXPANSION") or t.contains("DIPLOMACY") or t.contains("ALLIANCE"):
        return "MARKET EXPANSION"
    if t.contains("EMPLOYEE") or t.contains("HEADQUARTERS") or t.contains("CUSTOMER"):
        return "ORGANISATION & TALENT"
    if t.contains("TECHNOLOGY") or t.contains("INTELLIGENCE") or t.contains("HISTORY") or t.contains("NEWS"):
        return "STRATEGIC INTELLIGENCE"
    return "EXECUTIVE COMMAND SURFACE"

func _context_signal(active_name: String) -> String:
    var t := active_name.to_upper()
    if t.contains("FINANCE"):
        return "Capital desk synced to the live ledger."
    if t.contains("PORTFOLIO"):
        return "Asset register linked to property state."
    if t.contains("PRODUCTION"):
        return "Factory throughput linked to live operations."
    if t.contains("SUPPLY"):
        return "Supply network linked to inventory and routes."
    if t.contains("REGION") or t.contains("EXPANSION"):
        return "Expansion view linked to the regional network."
    if t.contains("TECHNOLOGY") or t.contains("INTELLIGENCE"):
        return "Research and intelligence feeds synchronized."
    return "Authoritative simulation state connected."

func _compact_number(value: int) -> String:
    var n := absi(value)
    if n >= 1000000000:
        return "%.1fB" % (float(value) / 1000000000.0)
    if n >= 1000000:
        return "%.1fM" % (float(value) / 1000000.0)
    if n >= 1000:
        return "%.1fK" % (float(value) / 1000.0)
    return str(value)

func _draw() -> void:
    var s := get_viewport_rect().size
    if s.x <= 0.0 or s.y <= 0.0:
        return
    var mobile := s.x < 760.0
    var top_h := 84.0 if mobile else 90.0

    # Ambient header glass instead of a solid bar.
    for i in range(6):
        var alpha := 0.62 - float(i) * 0.075
        var band_h := top_h / 6.0
        draw_rect(Rect2(0, float(i) * band_h, s.x, band_h + 1), Color(DEEP.r, DEEP.g, DEEP.b, maxf(0.10, alpha)), true)
    draw_rect(Rect2(0, 0, s.x, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.46), true)
    draw_line(Vector2(18, top_h - 1), Vector2(s.x - 18, top_h - 1), Color(EDGE.r, EDGE.g, EDGE.b, 0.52), 1.0)

    _corner(Vector2(18, top_h + 14), 28.0, GOLD)
    _corner(Vector2(s.x - 18, top_h + 14), -28.0, CYAN)

    # Soft ambient glints establish depth without creating fake controls.
    var pulse := 0.22 + 0.08 * sin(_pulse * 0.85)
    _halo(Vector2(s.x * 0.22, top_h + 54), 90.0, Color(GREEN.r, GREEN.g, GREEN.b, pulse * 0.08))
    _halo(Vector2(s.x * 0.79, top_h + 38), 108.0, Color(CYAN.r, CYAN.g, CYAN.b, pulse * 0.07))

func _corner(origin: Vector2, direction: float, tint: Color) -> void:
    draw_line(origin, origin + Vector2(direction, 0), Color(tint.r, tint.g, tint.b, 0.60), 2.0)
    draw_line(origin, origin + Vector2(0, 18), Color(tint.r, tint.g, tint.b, 0.34), 2.0)

func _halo(center: Vector2, radius: float, tint: Color) -> void:
    for i in range(4, 0, -1):
        var r := radius * float(i) / 4.0
        var a := tint.a * (1.0 - float(i) / 5.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, a))
