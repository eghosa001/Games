extends CanvasLayer

## RESTORA production command UI.
## This is the runtime implementation of the approved Figma production screens.
## Gameplay remains authoritative in Main and domain systems; this layer is presentation + routing only.

const MOBILE_DESIGN_W = 390.0
const MOBILE_CONTENT_H = 744.0
const MOBILE_NAV_H = 70.0
const MOBILE_NAV_BOTTOM = 16.0
const DESKTOP_BREAKPOINT = 1000.0
const TABLET_BREAKPOINT = 700.0
const ART_ROOT = "res://Assets/Art/"
const RESTORATION_ART = ART_ROOT + "premium_restoration_site.svg"
const DISTRICT_ART = ART_ROOT + "premium_industrial_district.svg"
const ICON_ROOT = ART_ROOT + "Icons/"
const NAV_ICON_ROOT = ART_ROOT + "NavIcons/"
const WAREHOUSE_STAGE_ART = ART_ROOT + "building_warehouse_progression.svg"
const WORKSHOP_STAGE_ART = ART_ROOT + "building_factory_progression.svg"
const COMMERCIAL_STAGE_ART = ART_ROOT + "building_office_progression.svg"
const BUILDING_FRAME_SIZE = Vector2(256, 144)

var parent: Node
var root: Control
var background: ColorRect
var mobile_scroll: ScrollContainer
var mobile_content: Control
var bottom_nav: Panel
var tabs: HBoxContainer
var mode_buttons: Array[Button] = []
var active_tab = 0
var active_view = "live"
var refs: Dictionary = {}
var feedback_label: Label
var status_label: Label
var hero_goal: Label
var hero_action: Button
var _refresh_elapsed = 0.0
var _last_signature = ""
var _layout_kind = ""
var _last_progress_level := -1
var _view_transition: Tween

var _font_regular: SystemFont
var _font_semibold: SystemFont
var _font_bold: SystemFont

func _ready() -> void:
    if OS.has_feature("mobile") and DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
    parent = get_tree().root.get_node_or_null("Renew")
    _make_fonts()
    _build_root()
    var manager = _theme_manager()
    if manager != null and not manager.theme_changed.is_connected(_on_theme_changed):
        manager.theme_changed.connect(_on_theme_changed)
    if not get_viewport().size_changed.is_connected(_layout_responsive):
        get_viewport().size_changed.connect(_layout_responsive)
    _show_view("live")
    call_deferred("_bind_runtime_after_parent_ready")

func _bind_runtime_after_parent_ready() -> void:
    # Child CanvasLayers become ready before Main finishes constructing the
    # command systems. Rebuild once the authoritative property model exists so
    # desktop/tablet labels and staged art never freeze on fallback values.
    if _property_system() != null:
        _last_signature = ""
        _rebuild_current()

func _process(delta: float) -> void:
    _refresh_elapsed += delta
    if _refresh_elapsed < 0.5:
        return
    _refresh_elapsed = 0.0
    var sig = _state_signature()
    if _company_level() != _last_progress_level:
        _rebuild_current()
        return
    if sig != _last_signature:
        _last_signature = sig
        _refresh()

func _theme_manager():
    return get_node_or_null("/root/RestoraThemeManager")

func _game_state():
    return get_node_or_null("/root/RenewGameState")

func _screen_manager():
    return get_node_or_null("/root/RenewUIScreenManager")

func _audio_manager():
    return get_node_or_null("/root/RenewAudioManager")

func _monetization():
    return get_node_or_null("/root/RenewMonetizationSystem")

func _realtime_status() -> Dictionary:
    var realtime = get_node_or_null("/root/RenewRealTimeEconomySystem")
    return realtime.status() if realtime != null and realtime.has_method("status") else {}

func _demand_remaining() -> int:
    return maxi(0, int(_realtime_status().get("consumer_demand_remaining", 0)))

func _property_system():
    if parent == null:
        return null
    var command = parent.get("command_system")
    if command == null:
        return null
    return command.get("property_system")

func _building_catalog() -> Array:
    var model = _property_system()
    return model.list_properties() if model != null and model.has_method("list_properties") else []

func _selected_building() -> Dictionary:
    var model = _property_system()
    return model.get_selected_property() if model != null and model.has_method("get_selected_property") else {}

func _building_name() -> String:
    return str(_selected_building().get("name", "Riverside Warehouse"))

func _building_type() -> String:
    return str(_selected_building().get("type", "Warehouse"))

func _building_progress(building: Dictionary = {}) -> int:
    var item := building if not building.is_empty() else _selected_building()
    if item.is_empty():
        return _restoration()
    var total := 0
    for step in ["cleaning", "repair", "painting", "furnishing"]:
        total += clampi(int(item.get(step, 0)), 0, 100)
    return int(round(float(total) / 4.0))

func _building_stage_slot(building: Dictionary = {}) -> int:
    var item := building if not building.is_empty() else _selected_building()
    if item.is_empty() or not bool(item.get("owned", false)):
        return 0
    if int(item.get("cleaning", 0)) < 100:
        return 0
    if int(item.get("repair", 0)) < 100:
        return 1
    if int(item.get("painting", 0)) < 100:
        return 2
    if int(item.get("furnishing", 0)) < 50:
        return 3
    if int(item.get("furnishing", 0)) < 100:
        return 4
    return 5

func _building_stage_name(building: Dictionary = {}) -> String:
    return ["ABANDONED", "CLEANED", "REPAIRED", "PAINTED", "FURNISHING", "OPERATIONAL"][_building_stage_slot(building)]

func _building_stage_texture(building: Dictionary = {}) -> Texture2D:
    var item := building if not building.is_empty() else _selected_building()
    var kind := str(item.get("type", "Warehouse"))
    var path := WAREHOUSE_STAGE_ART
    if kind == "Workshop":
        path = WORKSHOP_STAGE_ART
    elif kind == "Commercial Building":
        path = COMMERCIAL_STAGE_ART
    var source := _asset_texture(path)
    if source == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    atlas.region = Rect2(0, float(_building_stage_slot(item)) * BUILDING_FRAME_SIZE.y, BUILDING_FRAME_SIZE.x, BUILDING_FRAME_SIZE.y)
    return atlas

func _select_building(index: int) -> void:
    var model = _property_system()
    var catalog := _building_catalog()
    if model == null or index < 0 or index >= catalog.size():
        return
    model.select_property(str(catalog[index].get("id", "")))
    _rebuild_current()

func _progression():
    return parent.get_node_or_null("Systems/StrategicProgression") if parent != null else null

func _company_level() -> int:
    var progression = _progression()
    if progression != null and progression.has_method("get_level"):
        return int(progression.get_level())
    return int(_state_value("progression", "level", 1))

func _has_unlock(unlock_id: String) -> bool:
    if unlock_id.is_empty():
        return true
    var progression = _progression()
    if progression != null and progression.has_method("has_unlock"):
        return bool(progression.has_unlock(unlock_id))
    var unlocks = _state_value("progression", "unlocks", [])
    return unlocks is Array and unlock_id in unlocks

func _unlock_level(unlock_id: String) -> int:
    var levels := {
        "finance": 2, "contracts": 2, "employees": 2,
        "branches": 3, "regions": 3, "supply_chain": 3,
        "competitors": 4, "alliances": 4, "ownership": 4,
        "technology": 6, "research": 6, "infrastructure": 6,
        "headquarters": 8, "world_power": 8,
        "museum": 9, "legacy": 9
    }
    return int(levels.get(unlock_id, 1))

func _make_fonts() -> void:
    _font_regular = SystemFont.new()
    _font_regular.font_names = PackedStringArray(["Inter", "Roboto", "Noto Sans", "Arial"])
    _font_regular.font_weight = 400
    _font_semibold = SystemFont.new()
    _font_semibold.font_names = PackedStringArray(["Inter", "Roboto", "Noto Sans", "Arial"])
    _font_semibold.font_weight = 600
    _font_bold = SystemFont.new()
    _font_bold.font_names = PackedStringArray(["Inter", "Roboto", "Noto Sans", "Arial"])
    _font_bold.font_weight = 700

func _font(weight: int) -> Font:
    if weight >= 700:
        return _font_bold
    if weight >= 600:
        return _font_semibold
    return _font_regular

func _color(role: String) -> Color:
    var manager = _theme_manager()
    if manager != null and manager.has_method("color"):
        return manager.color(role)
    match role:
        "bg": return Color("0b0d10")
        "surface": return Color("151a1f")
        "surface_2": return Color("20262c")
        "surface_3": return Color("292f35")
        "selected": return Color("32202a")
        "border": return Color("3c3831")
        "text": return Color("f2efe8")
        "muted": return Color("928a80")
        "gold": return Color("c99a4b")
        "plum": return Color("7a405f")
        "success": return Color("7fa88a")
        "warning": return Color("c28a3a")
        "danger": return Color("b85c4a")
        _: return Color("f2efe8")

func _asset_texture(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    return load(path) as Texture2D

func _add_texture(parent_node: Node, name: String, rect: Rect2, texture: Texture2D, alpha := 1.0) -> TextureRect:
    if texture == null:
        return null
    var art := TextureRect.new()
    art.name = name
    art.texture = texture
    art.position = rect.position
    art.size = rect.size
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.modulate = Color(1, 1, 1, alpha)
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent_node.add_child(art)
    return art

func _add_art(parent_node: Node, name: String, rect: Rect2, path: String, alpha := 1.0) -> TextureRect:
    return _add_texture(parent_node, name, rect, _asset_texture(path), alpha)

func _add_icon(parent_node: Node, name: String, icon_key: String, rect: Rect2, role := "muted", alpha := 1.0, icon_root := ICON_ROOT) -> TextureRect:
    var icon := _add_art(parent_node, name, rect, icon_root + icon_key + ".svg", alpha)
    if icon != null:
        var tint := _color(role)
        icon.modulate = Color(tint.r, tint.g, tint.b, alpha)
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    return icon

func _build_root() -> void:
    root = Control.new()
    root.name = "RestoraFigmaRuntime"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)

func _clear_root() -> void:
    refs.clear()
    mode_buttons.clear()
    tabs = null
    mobile_scroll = null
    mobile_content = null
    bottom_nav = null
    feedback_label = null
    status_label = null
    hero_goal = null
    hero_action = null
    for child in root.get_children():
        child.free()

func _on_theme_changed(_mode: String) -> void:
    _rebuild_current()

func _layout_size() -> Vector2:
    if root != null and is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0:
        return root.size
    return get_viewport().get_visible_rect().size

func _layout_responsive() -> void:
    var next_kind = _layout_class()
    if next_kind != _layout_kind:
        _layout_kind = next_kind
        _rebuild_current()
        return
    if _layout_kind == "mobile":
        var size = _layout_size()
        var canvas_w = minf(MOBILE_DESIGN_W, size.x)
        var scroll_h = maxf(120.0, size.y - (MOBILE_NAV_H + MOBILE_NAV_BOTTOM))
        var expected_width = canvas_w
        if scroll_h < MOBILE_CONTENT_H and is_equal_approx(canvas_w, size.x):
            expected_width = maxf(240.0, canvas_w - 8.0)
        if mobile_content != null and not is_equal_approx(mobile_content.custom_minimum_size.x, expected_width):
            _rebuild_current()
        else:
            _layout_mobile_host()

func _layout_class() -> String:
    var size = _layout_size()
    if size.x >= DESKTOP_BREAKPOINT and active_view == "live":
        return "desktop"
    if size.x >= TABLET_BREAKPOINT and size.y >= 900.0 and active_view == "live":
        return "tablet"
    return "mobile"

func _rebuild_current() -> void:
    _clear_root()
    background = ColorRect.new()
    background.name = "MainHUDBackground"
    background.color = _color("bg")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)

    _layout_kind = _layout_class()
    if _layout_kind == "desktop":
        _build_desktop_live()
    elif _layout_kind == "tablet":
        _build_tablet_live()
    else:
        _build_mobile_host()
        _build_mobile_view()
    _last_progress_level = _company_level()
    _refresh()
    _animate_view_in()

func _animate_view_in() -> void:
    if root == null:
        return
    if _view_transition != null and _view_transition.is_valid():
        _view_transition.kill()
    if _reduce_motion():
        root.modulate = Color.WHITE
        return
    root.modulate = Color(1.0, 1.0, 1.0, 0.86)
    _view_transition = create_tween()
    _view_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _view_transition.set_trans(Tween.TRANS_QUAD)
    _view_transition.set_ease(Tween.EASE_OUT)
    _view_transition.tween_property(root, "modulate", Color.WHITE, 0.08)

func _show_view(view_name: String) -> void:
    var previous_view := active_view
    active_view = view_name
    match view_name:
        "live":
            active_tab = 0
        "operate":
            active_tab = 1
        "property", "portfolio", "empire", "intelligence":
            active_tab = 2
        "finance":
            active_tab = 3
        _:
            active_tab = 4

    # On phones the shell/navigation is persistent. Rebuild only the changing
    # page body instead of destroying and recreating the entire UI tree.
    if _layout_kind == "mobile" and mobile_content != null and bottom_nav != null:
        if previous_view == view_name and mobile_content.get_child_count() > 0:
            _refresh_bottom_nav()
            return
        _rebuild_mobile_content()
        return

    _rebuild_current()

func open_figma_view(view_name: String) -> void:
    _show_view(view_name)

func _set_tab(index: int) -> void:
    var target_index := clampi(index, 0, 4)
    var views = ["live", "operate", "property", "finance", "more"]
    _show_view(views[target_index])

func _rebuild_mobile_content() -> void:
    if mobile_content == null:
        _rebuild_current()
        return
    refs.clear()
    feedback_label = null
    status_label = null
    hero_goal = null
    hero_action = null
    for child in mobile_content.get_children():
        child.free()

    var content_w := mobile_content.custom_minimum_size.x
    mobile_content.custom_minimum_size = Vector2(content_w, MOBILE_CONTENT_H)
    mobile_content.size = Vector2(content_w, MOBILE_CONTENT_H)
    _build_mobile_view()
    if mobile_scroll != null:
        mobile_scroll.scroll_vertical = 0
    _refresh_bottom_nav()
    _last_progress_level = _company_level()
    _last_signature = _state_signature()
    _refresh()

func _refresh_bottom_nav() -> void:
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i]
        if button == null or not is_instance_valid(button):
            continue
        var active := i == active_tab
        button.add_theme_stylebox_override("normal", _nav_style(active))
        button.add_theme_stylebox_override("hover", _nav_style(active, true))
        button.add_theme_stylebox_override("pressed", _nav_style(true))
        button.add_theme_stylebox_override("focus", _nav_style(active, true))
        var label := button.get_node_or_null("NavLabel") as Label
        if label != null:
            label.add_theme_color_override("font_color", _color("text") if active else _color("muted"))
        var icon := button.get_node_or_null("NavIcon") as TextureRect
        if icon != null:
            var tint := _color("gold") if active else _color("muted")
            icon.modulate = Color(tint.r, tint.g, tint.b, icon.modulate.a)

func _build_mobile_host() -> void:
    var size = _layout_size()
    var canvas_w = minf(MOBILE_DESIGN_W, size.x)
    var x0 = floor((size.x - canvas_w) * 0.5)
    var scroll_h = maxf(120.0, size.y - (MOBILE_NAV_H + MOBILE_NAV_BOTTOM))
    var content_w = canvas_w
    # When the canvas consumes the full narrow viewport and vertical scrolling is
    # required, reserve Godot's 8px scrollbar so the host never grows off-screen.
    if scroll_h < MOBILE_CONTENT_H and is_equal_approx(canvas_w, size.x):
        content_w = maxf(240.0, canvas_w - 8.0)

    mobile_scroll = ScrollContainer.new()
    mobile_scroll.name = "ProductionScroll"
    mobile_scroll.position = Vector2(x0, 0)
    mobile_scroll.size = Vector2(canvas_w, scroll_h)
    mobile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    mobile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    mobile_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    root.add_child(mobile_scroll)

    mobile_content = Control.new()
    mobile_content.name = "ProductionContent"
    mobile_content.custom_minimum_size = Vector2(content_w, MOBILE_CONTENT_H)
    mobile_content.size = Vector2(content_w, MOBILE_CONTENT_H)
    mobile_scroll.add_child(mobile_content)

    _build_bottom_nav(x0, canvas_w, size.y)

func _layout_mobile_host() -> void:
    if mobile_scroll == null or bottom_nav == null:
        return
    var size = _layout_size()
    var canvas_w = minf(MOBILE_DESIGN_W, size.x)
    var x0 = floor((size.x - canvas_w) * 0.5)
    mobile_scroll.position = Vector2(x0, 0)
    mobile_scroll.size = Vector2(canvas_w, maxf(120.0, size.y - (MOBILE_NAV_H + MOBILE_NAV_BOTTOM)))
    bottom_nav.position = Vector2(x0 + 12.0, size.y - MOBILE_NAV_H - MOBILE_NAV_BOTTOM)
    bottom_nav.size = Vector2(canvas_w - 24.0, MOBILE_NAV_H)

func _build_mobile_view() -> void:
    match active_view:
        "live": _build_mobile_live()
        "operate": _build_mobile_operations()
        "empire": _build_mobile_empire()
        "world": _build_mobile_world()
        "more": _build_mobile_more()
        "finance": _build_mobile_finance()
        "portfolio": _build_mobile_portfolio()
        "intelligence": _build_mobile_intelligence()
        "settings": _build_mobile_settings()
        "rewards": _build_mobile_rewards()
        "property": _build_mobile_property()
        _: _build_mobile_live()

func _build_bottom_nav(x0: float, canvas_w: float, viewport_h: float) -> void:
    bottom_nav = Panel.new()
    bottom_nav.name = "PrimaryNavigation"
    bottom_nav.position = Vector2(x0 + 12.0, viewport_h - MOBILE_NAV_H - MOBILE_NAV_BOTTOM)
    bottom_nav.size = Vector2(canvas_w - 24.0, MOBILE_NAV_H)
    bottom_nav.add_theme_stylebox_override("panel", _style(_color("surface"), _color("border"), 22))
    root.add_child(bottom_nav)

    var item_w = 72.0 if canvas_w >= MOBILE_DESIGN_W else (bottom_nav.size.x - 4.0) / 5.0
    tabs = HBoxContainer.new()
    tabs.name = "ProductionTabs"
    tabs.position = Vector2(2, 5)
    tabs.size = Vector2(item_w * 5.0, 58)
    tabs.add_theme_constant_override("separation", 0)
    bottom_nav.add_child(tabs)

    var labels = ["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]
    var icon_keys = ["home", "business", "property", "finance", "more"]
    var required_unlocks = ["", "", "", "finance", ""]
    for i in range(labels.size()):
        var button = Button.new()
        button.name = "Nav_" + labels[i]
        button.text = ""
        button.custom_minimum_size = Vector2(item_w, 58)
        button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_stylebox_override("normal", _nav_style(i == active_tab))
        button.add_theme_stylebox_override("hover", _nav_style(i == active_tab, true))
        button.add_theme_stylebox_override("pressed", _nav_style(true))
        button.add_theme_stylebox_override("focus", _nav_style(true, true))
        button.add_theme_stylebox_override("disabled", _nav_disabled_style())
        var required_unlock := str(required_unlocks[i])
        var locked := not required_unlock.is_empty() and not _has_unlock(required_unlock)
        button.disabled = locked
        if locked:
            button.tooltip_text = "Unlocks at Company Level %d" % _unlock_level(required_unlock)
        button.focus_mode = Control.FOCUS_ALL
        button.pressed.connect(_set_tab.bind(i), CONNECT_DEFERRED)
        tabs.add_child(button)
        mode_buttons.append(button)

        var icon_alpha := 0.42 if locked else 1.0
        _add_icon(button, "NavIcon", icon_keys[i], Rect2((button.custom_minimum_size.x - 20.0) * 0.5, 5, 20, 20), "gold" if i == active_tab else "muted", icon_alpha, NAV_ICON_ROOT)

        var label = _label(button, "NavLabel", labels[i], Rect2(2, 34, button.custom_minimum_size.x - 4, 16), 8, "text" if i == active_tab else "muted", 600, HORIZONTAL_ALIGNMENT_CENTER)
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        if locked:
            _label(button, "UnlockLevel", "L%d" % _unlock_level(required_unlock), Rect2(button.custom_minimum_size.x - 23, 3, 18, 11), 7, "muted", 700, HORIZONTAL_ALIGNMENT_RIGHT)
        button.focus_mode = Control.FOCUS_ALL
    call_deferred("_ensure_nav_focus_modes")

func _ensure_nav_focus_modes() -> void:
    for button in mode_buttons:
        if button != null and is_instance_valid(button) and not button.disabled:
            button.focus_mode = Control.FOCUS_ALL

func _nav_disabled_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    style.border_color = Color(0, 0, 0, 0)
    style.set_corner_radius_all(14)
    return style

func _nav_style(active: bool, hover = false) -> StyleBoxFlat:
    if active:
        var bg = _color("selected")
        if hover:
            bg = bg.lightened(0.04)
        return _style(bg, _color("plum"), 14)
    var empty = StyleBoxFlat.new()
    empty.bg_color = Color(0,0,0,0)
    empty.border_color = Color(0,0,0,0)
    empty.set_corner_radius_all(14)
    return empty

func _style(bg: Color, border: Color, radius: int, border_width = 1) -> StyleBoxFlat:
    var s = StyleBoxFlat.new()
    s.bg_color = Color(bg.r, bg.g, bg.b, 0.94 if not _is_light_theme() else 0.96)
    s.border_color = border
    s.set_border_width_all(border_width)
    if border_width > 0:
        s.set_border_width(SIDE_TOP, maxi(border_width, 2))
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(0, 0, 0, 0.26 if not _is_light_theme() else 0.11)
    s.shadow_size = 9
    s.shadow_offset = Vector2(0, 4)
    return s

func _solid_round(color: Color, radius: int) -> StyleBoxFlat:
    var s = StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(radius)
    return s

func _panel(parent_node: Node, name: String, rect: Rect2, bg_role = "surface", border_role = "border", radius = 18) -> Panel:
    var p = Panel.new()
    p.name = name
    p.position = rect.position
    p.size = rect.size
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_theme_stylebox_override("panel", _style(_color(bg_role), _color(border_role), radius))
    parent_node.add_child(p)
    return p

func _label(parent_node: Node, name: String, text_value: String, rect: Rect2, size_px: int, role = "text", weight = 400, align = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l = Label.new()
    l.name = name
    l.text = text_value
    l.position = rect.position
    l.size = rect.size
    # System font metrics can exceed Figma's nominal text box height on Linux/Android.
    # Keep the authored x/width intact while giving display text enough vertical room.
    if size_px >= 15:
        l.size.y = maxf(l.size.y, float(size_px) + 10.0)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_override("font", _font(weight))
    l.add_theme_font_size_override("font_size", size_px)
    l.add_theme_color_override("font_color", _color(role))
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    parent_node.add_child(l)
    return l

func _remember(key: String, node: Node) -> Node:
    refs[key] = node
    return node

func _transparent_button(parent_node: Node, name: String, rect: Rect2, callback: Callable) -> Button:
    var b = Button.new()
    b.name = name
    b.text = ""
    b.position = rect.position
    b.size = rect.size
    b.focus_mode = Control.FOCUS_ALL
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var empty = StyleBoxEmpty.new()
    b.add_theme_stylebox_override("normal", empty)
    b.add_theme_stylebox_override("hover", empty)
    b.add_theme_stylebox_override("pressed", empty)
    b.add_theme_stylebox_override("disabled", empty)
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color(0, 0, 0, 0)
    focus.border_color = _color("gold")
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(16)
    b.add_theme_stylebox_override("focus", focus)
    if callback.is_valid():
        b.pressed.connect(callback, CONNECT_DEFERRED)
    parent_node.add_child(b)
    return b

func _frame_button(parent_node: Node, name: String, text_value: String, rect: Rect2, callback: Callable, selected = false, gold_fill = false, font_size = 9) -> Button:
    var b = Button.new()
    b.name = name
    b.text = text_value
    b.position = rect.position
    b.size = rect.size
    b.focus_mode = Control.FOCUS_ALL
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    b.add_theme_font_override("font", _font(600))
    b.add_theme_font_size_override("font_size", font_size)
    var bg = _color("gold") if gold_fill else (_color("selected") if selected else _color("surface_2"))
    var border = _color("gold") if gold_fill else (_color("plum") if selected else _color("border"))
    var fg = _color("bg") if gold_fill else (_color("plum") if selected else _color("text"))
    b.add_theme_stylebox_override("normal", _style(bg, border, 12))
    b.add_theme_stylebox_override("hover", _style(bg.lightened(0.05), border, 12))
    b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.05), border, 12))
    b.add_theme_stylebox_override("focus", _style(bg.lightened(0.03), _color("gold"), 12))
    b.add_theme_color_override("font_color", fg)
    b.add_theme_color_override("font_hover_color", fg)
    b.add_theme_color_override("font_pressed_color", fg)
    if callback.is_valid():
        b.pressed.connect(callback, CONNECT_DEFERRED)
    parent_node.add_child(b)
    return b

func _stat_tile(parent_node: Node, key: String, x: float, y: float, w: float, label_text: String, value_text: String, meta_text: String) -> Panel:
    var p = _panel(parent_node, "Stat_" + key, Rect2(x, y, w, 104), "surface_2", "border", 16)
    var icon_map := {"cash":"finance","worth":"empire","rep":"people","goods":"production","inputs":"supply","debt":"finance","revenue":"market","equity":"empire","asset_value":"property","daily_income":"finance"}
    var icon_key := str(icon_map.get(key, "intelligence"))
    _add_icon(p, "StatIcon", icon_key, Rect2(w - 38, 11, 22, 22), "gold", 0.86)
    _remember(key + "_label", _label(p, "Label", label_text, Rect2(15, 13, w - 54, 14), 9, "gold", 600))
    _remember(key + "_value", _label(p, "Value", value_text, Rect2(15, 36, w - 30, 32), 24, "text", 700))
    _remember(key + "_meta", _label(p, "Meta", meta_text, Rect2(15, 75, w - 30, 14), 9, "muted", 600))
    return p

func _content_width() -> float:
    return mobile_content.size.x if mobile_content != null and mobile_content.size.x > 0.0 else minf(MOBILE_DESIGN_W, _layout_size().x)

func _header(title: String, subtitle: String, right_text = "", status_role = "gold") -> void:
    var w = _content_width()
    _remember("title", _label(mobile_content, "Title", title, Rect2(18, 18, w - 120, 34), 24 if title == "RESTORA" else 21, "text", 700))
    status_label = _label(mobile_content, "Status", subtitle, Rect2(18, 48 if title != "RESTORA" else 52, w - 130, 16), 9, status_role, 600)
    _remember("status", status_label)
    if not right_text.is_empty():
        _remember("right_status", _label(mobile_content, "RightStatus", right_text, Rect2(w - 104, 24, 84, 18), 9 if title != "RESTORA" else 11, "plum" if active_view == "settings" else "text", 600, HORIZONTAL_ALIGNMENT_RIGHT))

func _build_mobile_live() -> void:
    var w = _content_width()
    _header("RESTORA", "BUILD • RESTORE • OPERATE", "DAY %d" % _day())
    var inner_w = w - 36.0
    var hero = _panel(mobile_content, "ExecutiveHero", Rect2(18, 82, inner_w, 154), "surface", "border", 22)
    hero.clip_contents = true
    var hero_texture := _building_stage_texture()
    if hero_texture != null:
        _add_texture(hero, "HeroBuildingArt", Rect2(inner_w * 0.48, 0, inner_w * 0.52, 154), hero_texture, 0.90 if not _is_light_theme() else 0.78)
    var hero_wash := ColorRect.new()
    hero_wash.name = "HeroContrastWash"
    hero_wash.position = Vector2(inner_w * 0.30, 0)
    hero_wash.size = Vector2(inner_w * 0.70, 154)
    var hero_bg := _color("surface")
    var wash_alpha := 0.56 if _is_light_theme() else 0.62
    hero_wash.color = Color(hero_bg.r, hero_bg.g, hero_bg.b, wash_alpha)
    hero_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero.add_child(hero_wash)
    var rail = Panel.new()
    rail.position = Vector2(-1, -1)
    rail.size = Vector2(6, 154)
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rail.add_theme_stylebox_override("panel", _solid_round(_color("gold"), 0))
    hero.add_child(rail)
    _label(hero, "Eyebrow", "NEXT MOVE", Rect2(21, 17, 120, 14), 9, "gold", 600)
    _remember("hero_title", _label(hero, "HeroTitle", _objective_title(), Rect2(21, 41, inner_w - 42, 30), 22, "text", 700))
    hero_goal = _label(hero, "HeroGoal", _stage_meta(), Rect2(21, 77, inner_w - 42, 18), 12, "muted", 400)
    _remember("hero_goal", hero_goal)
    var progress_bg = Panel.new()
    progress_bg.position = Vector2(21, 107)
    progress_bg.size = Vector2(inner_w - 44, 12)
    progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_bg.add_theme_stylebox_override("panel", _solid_round(_color("surface_2"), 6))
    hero.add_child(progress_bg)
    var progress_fill = Panel.new()
    progress_fill.name = "ProgressFill"
    progress_fill.position = Vector2.ZERO
    progress_fill.size = Vector2(maxf(4.0, (inner_w - 44) * float(_restoration()) / 100.0), 12)
    progress_fill.add_theme_stylebox_override("panel", _solid_round(_color("gold"), 6))
    progress_bg.add_child(progress_fill)
    _remember("progress_fill", progress_fill)
    hero_action = _transparent_button(hero, "PrimaryNextMove", Rect2(0, 0, inner_w, 154), _show_view.bind(_objective_view()))

    var gap = 6.0
    var tile_w = (inner_w - gap) * 0.5
    _stat_tile(mobile_content, "cash", 18, 254, tile_w, "CASH", _money(_cash()), "LIVE")
    _stat_tile(mobile_content, "worth", 18 + tile_w + gap, 254, tile_w, "WORTH", _money(_worth()), "LIVE")
    _stat_tile(mobile_content, "rep", 18, 370, tile_w, "REP", str(_rep()), "RISING" if _rep() >= 50 else "BUILDING")
    _stat_tile(mobile_content, "goods", 18 + tile_w + gap, 370, tile_w, "GOODS", str(_goods()), "READY" if _goods() > 0 else "EMPTY")

    var signals = _panel(mobile_content, "Signals", Rect2(18, 494, inner_w, 192), "surface", "border", 18)
    _label(signals, "Head", "THE RESTORA LOOP", Rect2(15, 15, inner_w - 30, 14), 10, "gold", 600)
    _remember("signals", _label(signals, "SignalBody", _core_loop_lines(), Rect2(15, 43, inner_w - 30, 104), 12, "text", 600))
    _remember("signal_footer", _label(signals, "Footer", _core_loop_status(), Rect2(15, 153, inner_w - 30, 24), 9, "success", 600))

func _build_mobile_operations() -> void:
    var property_ready := _stage() == "Operational"
    var business_ready := _business_open()
    var w = _content_width()
    var status_text := "OPERATING" if business_ready else ("READY TO OPEN" if property_ready else "RESTORATION REQUIRED")
    _header("BUSINESS OPERATIONS", "%s • %s" % [_building_name().to_upper(), status_text], "", "success" if business_ready else "gold")
    var day_chip = _panel(mobile_content, "DayChip", Rect2(w - 98, 20, 80, 34), "surface_2", "gold", 17)
    _label(day_chip, "Day", "DAY %d" % _day(), Rect2(12, 10, 56, 14), 9, "gold", 600, HORIZONTAL_ALIGNMENT_CENTER)
    var inner_w = w - 36.0
    var gap = 6.0
    var tile_w = (inner_w - gap) * 0.5
    _stat_tile(mobile_content, "inputs", 18, 82, tile_w, "INPUTS", str(_inputs()), "READY" if _inputs() > 0 else "LOW")
    _stat_tile(mobile_content, "goods", 18 + tile_w + gap, 82, tile_w, "GOODS", str(_goods()), "READY" if _goods() > 0 else "EMPTY")

    var prod = _panel(mobile_content, "ProductionControl", Rect2(18, 204, inner_w, 150), "surface", "border", 18)
    _label(prod, "Head", "PRODUCTION CONTROL", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    var half = (inner_w - 42.0) * 0.5
    if not property_ready:
        _remember("production_rate", _label(prod, "Rate", "RESTORE %s FIRST" % _building_name().to_upper(), Rect2(16, 42, inner_w - 32, 18), 13, "text", 600))
        _label(prod, "Meta", "Business selection unlocks when this property reaches Operational.", Rect2(16, 70, inner_w - 32, 28), 11, "muted", 400)
        _frame_button(prod, "ContinueRestoration", "CONTINUE RESTORATION", Rect2(16, 104, inner_w - 32, 34), _show_view.bind("property"), false, true, 9)
    elif business_ready:
        _remember("production_rate", _label(prod, "Rate", _production_rate_text(), Rect2(16, 42, inner_w - 32, 18), 13, "text", 600))
        _label(prod, "Meta", "Customer demand remaining today: %d units." % _demand_remaining(), Rect2(16, 70, inner_w - 32, 28), 11, "muted", 400)
        _frame_button(prod, "ProduceBatch", "PRODUCE BATCH", Rect2(16, 104, half, 34), _produce, false, true, 9)
        _frame_button(prod, "BuyInputs", "BUY INPUTS", Rect2(26 + half, 104, half, 34), _buy_inputs, false, false, 9)
    else:
        _remember("production_rate", _label(prod, "Rate", "%s IS READY FOR A BUSINESS" % _building_name().to_upper(), Rect2(16, 42, inner_w - 32, 18), 13, "text", 600))
        _label(prod, "Meta", "Choose what this restored property will operate before buying inputs.", Rect2(16, 70, inner_w - 32, 28), 11, "muted", 400)
        _frame_button(prod, "ChooseBusiness", "CHOOSE BUSINESS", Rect2(16, 104, half, 34), _open_business_choices, false, true, 9)
        _frame_button(prod, "BackProperty", "VIEW PROPERTY", Rect2(26 + half, 104, half, 34), _show_view.bind("property"), false, false, 9)

    var commercial = _panel(mobile_content, "CommercialControls", Rect2(18, 370, inner_w, 176), "surface", "border", 18)
    _label(commercial, "Head", "COMMERCIAL CONTROLS", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    if business_ready:
        _remember("commercial_body", _label(commercial, "Body", _commercial_text(), Rect2(16, 44, inner_w - 32, 88), 12, "text", 400))
        _transparent_button(commercial, "OpenCommercial", Rect2(0, 0, inner_w, 176), _open_commercial_actions)
    else:
        var commercial_lock := "Restore the property first." if not property_ready else "Choose a business to unlock pricing, staff, marketing and contracts."
        _remember("commercial_body", _label(commercial, "Body", "LOCKED\n" + commercial_lock, Rect2(16, 44, inner_w - 32, 88), 12, "muted", 500))

    var equip = _panel(mobile_content, "Equipment", Rect2(18, 562, inner_w, 112), "surface", "border", 18)
    _label(equip, "Head", "EQUIPMENT HEALTH", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    if business_ready:
        _label(equip, "Body", "Fleet Level %d  •  %d inputs  •  %d finished goods" % [maxi(1,_transport_level()), _inputs(), _goods()], Rect2(16, 46, inner_w - 32, 36), 12, "text", 600)
        _label(equip, "Meta", "No maintenance action required.", Rect2(16, 76, inner_w - 32, 14), 10, "success", 600)
        _transparent_button(equip, "OpenEquipment", Rect2(0, 0, inner_w, 112), _open_screen.bind("ProductionControlPanel"))
    else:
        _label(equip, "Body", "Equipment unlocks with the first operating business.", Rect2(16, 46, inner_w - 32, 36), 12, "muted", 500)
        _label(equip, "Meta", "No equipment action required yet.", Rect2(16, 76, inner_w - 32, 14), 10, "muted", 600)

func _build_mobile_finance() -> void:
    var w = _content_width()
    _header("FINANCE COMMAND", "LIVE LEDGER • DEBT %s" % _money(_debt()), "", "success" if _debt() == 0 else "gold")
    var inner_w = w - 36.0
    var gap = 6.0
    var tile_w = (inner_w - gap) * 0.5
    _stat_tile(mobile_content, "cash", 18, 82, tile_w, "CASH", _money(_cash()), "LIVE")
    _stat_tile(mobile_content, "debt", 18 + tile_w + gap, 82, tile_w, "DEBT", _money(_debt()), "LOW" if _debt() < 100000 else "WATCH")
    _stat_tile(mobile_content, "revenue", 18, 198, tile_w, "REVENUE", _money(maxi(0, _last_sales())), "LIVE")
    _stat_tile(mobile_content, "equity", 18 + tile_w + gap, 198, tile_w, "EQUITY", _money(maxi(0, _worth() - _debt())), "BALANCED")

    var credit = _panel(mobile_content, "CreditHealth", Rect2(18, 320, inner_w, 88), "surface", "border", 18)
    _label(credit, "Head", "CREDIT HEALTH", Rect2(16, 14, 180, 14), 10, "gold", 600)
    _label(credit, "Score", _credit_score_text(), Rect2(16, 38, inner_w - 32, 24), 17, "text", 700)
    _label(credit, "Meta", "Books balanced • Investor confidence %s" % ("strong" if _rep() >= 60 else "building"), Rect2(16, 64, inner_w - 32, 14), 10, "success", 600)

    var tx = _panel(mobile_content, "Transactions", Rect2(18, 424, inner_w, 214), "surface", "border", 18)
    _label(tx, "Head", "RECENT TRANSACTIONS", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    var rows = _transaction_rows()
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        var y = 46.0 + i * 38.0
        _label(tx, "Kind%d" % i, str(row.get("kind", "")), Rect2(16, y, 84, 14), 10, "text", 600)
        _label(tx, "Reason%d" % i, str(row.get("reason", "")), Rect2(104, y, 110, 14), 9, "muted", 400)
        _label(tx, "Amount%d" % i, str(row.get("amount", "")), Rect2(inner_w - 140, y, 110, 14), 10, str(row.get("role", "text")), 600, HORIZONTAL_ALIGNMENT_RIGHT)

    var action_w = (inner_w - 16.0) / 3.0
    _frame_button(mobile_content, "Loan", "LOAN", Rect2(18, 656, action_w, 48), _take_loan)
    _frame_button(mobile_content, "Repay", "REPAY", Rect2(26 + action_w, 656, action_w, 48), _repay_loan)
    _frame_button(mobile_content, "Investor", "INVESTOR", Rect2(34 + action_w * 2.0, 656, action_w, 48), _request_investor, false, true)

func _build_mobile_property() -> void:
    if mobile_content != null:
        mobile_content.custom_minimum_size.y = maxf(mobile_content.custom_minimum_size.y, 1380.0)
        mobile_content.size.y = maxf(mobile_content.size.y, 1380.0)

    var building := _selected_building()
    var building_name := str(building.get("name", "Riverside Warehouse"))
    var building_type := str(building.get("type", "Warehouse"))
    var building_owned := bool(building.get("owned", _owned()))
    var building_inspected := bool(building.get("inspected", _inspected()))
    var progress := _building_progress(building)
    var w = _content_width()
    _header("PROPERTY", "%s • %s" % [building_name.to_upper(), "OWNED" if building_owned else ("SURVEYED" if building_inspected else "AVAILABLE")])
    var inner_w = w - 36.0

    var visual = _panel(mobile_content, "PropertyVisual", Rect2(18, 82, inner_w, 238), "surface", "border", 22)
    visual.clip_contents = true
    var stage_texture := _building_stage_texture(building)
    if stage_texture != null:
        _add_texture(visual, "BuildingStageArt", Rect2(0, 0, inner_w, 238), stage_texture, 1.0)
    var top_scrim := ColorRect.new()
    top_scrim.position = Vector2.ZERO
    top_scrim.size = Vector2(inner_w, 54)
    top_scrim.color = Color(1, 1, 1, 0.78) if _is_light_theme() else Color(0.02, 0.03, 0.03, 0.66)
    top_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual.add_child(top_scrim)
    var bottom_scrim := ColorRect.new()
    bottom_scrim.position = Vector2(0, 174)
    bottom_scrim.size = Vector2(inner_w, 64)
    bottom_scrim.color = Color(1, 1, 1, 0.86) if _is_light_theme() else Color(0.02, 0.03, 0.03, 0.72)
    bottom_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual.add_child(bottom_scrim)
    _label(visual, "Stage", "%s • STAGE %d/6" % [_building_stage_name(building), _building_stage_slot(building) + 1], Rect2(16, 15, inner_w - 150, 16), 10, "gold", 700)
    _label(visual, "Restoration", "%d%% RESTORED" % progress, Rect2(inner_w - 140, 15, 124, 16), 10, "success", 700, HORIZONTAL_ALIGNMENT_RIGHT)
    _label(visual, "BuildingName", building_name, Rect2(16, 184, inner_w - 32, 26), 19, "text", 700)
    _label(visual, "BuildingType", "%s • Market value %s" % [building_type, _money(int(building.get("value", 0)))], Rect2(16, 212, inner_w - 32, 16), 10, "muted", 500)

    var prog = _panel(mobile_content, "RestorationProgress", Rect2(18, 338, inner_w, 116), "surface", "border", 18)
    _label(prog, "Head", "RESTORATION", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    _label(prog, "Step", _stage_step_text(), Rect2(16, 40, inner_w - 32, 24), 17, "text", 700)
    _label(prog, "Next", _next_stage_text(), Rect2(16, 72, inner_w - 32, 16), 11, "muted", 400)
    var track = Panel.new()
    track.position = Vector2(16, 94)
    track.size = Vector2(inner_w - 32, 10)
    track.add_theme_stylebox_override("panel", _solid_round(_color("surface_2"), 5))
    prog.add_child(track)
    var fill = Panel.new()
    fill.size = Vector2(maxf(4, track.size.x * float(progress) / 100.0), 10)
    fill.add_theme_stylebox_override("panel", _solid_round(_color("gold"), 5))
    track.add_child(fill)

    var details = _panel(mobile_content, "BuildingDetails", Rect2(18, 472, inner_w, 126), "surface", "border", 18)
    _label(details, "Head", "BUILDING DETAILS", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    _label(details, "Body", "Condition %d%%  •  Capacity %d\nCompatible: %s" % [
        int(building.get("condition", 0)),
        int(building.get("capacity", 0)),
        ", ".join(building.get("industry_compatibility", []))
    ], Rect2(16, 42, inner_w - 32, 58), 11, "text", 400)

    var cta = _frame_button(mobile_content, "PropertyCTA", _property_cta_label(), Rect2(18, 616, inner_w, 64), _property_cta, false, true, 11)
    cta.add_theme_stylebox_override("normal", _style(_color("gold"), _color("gold"), 16))
    cta.add_theme_stylebox_override("hover", _style(_color("gold").lightened(0.05), _color("gold"), 16))

    _label(mobile_content, "BuildingListHead", "BUILDINGS", Rect2(18, 790, inner_w, 18), 11, "gold", 700)
    _label(mobile_content, "BuildingListMeta", "Select another building to inspect or restore.", Rect2(18, 814, inner_w, 22), 10, "muted", 400)

    var catalog := _building_catalog()
    var selected_index := int(_state_value("properties", "selected_property", 0))
    for i in range(catalog.size()):
        var item: Dictionary = catalog[i]
        var y := 852.0 + float(i) * 56.0
        var selected := i == selected_index
        var row = _panel(mobile_content, "BuildingRow%d" % i, Rect2(18, y, inner_w, 48), "selected" if selected else "surface", "plum" if selected else "border", 12)
        _label(row, "Name", str(item.get("name", "Property")), Rect2(12, 7, inner_w - 126, 16), 10, "text", 600)
        _label(row, "Meta", "%s • %d%% restored" % [str(item.get("type", "Building")), _building_progress(item)], Rect2(12, 25, inner_w - 126, 14), 9, "muted", 400)
        var state_text := "RESTORED" if _building_stage_slot(item) == 5 else ("OWNED" if bool(item.get("owned", false)) else ("SURVEYED" if bool(item.get("inspected", false)) else "AVAILABLE"))
        _label(row, "State", state_text, Rect2(inner_w - 110, 16, 92, 14), 8, "success" if bool(item.get("owned", false)) else "gold", 600, HORIZONTAL_ALIGNMENT_RIGHT)
        _transparent_button(row, "SelectBuilding%d" % i, Rect2(0, 0, inner_w, 48), _select_building.bind(i))

func _build_mobile_empire() -> void:
    var w = _content_width()
    _header("EMPIRE EXPANSION", "ASSET STRATEGY • LIVE")
    var inner_w = w - 36.0
    var cap = _panel(mobile_content, "ManagementCapacity", Rect2(18, 82, inner_w, 88), "surface", "border", 18)
    _label(cap, "Head", "MANAGEMENT CAPACITY", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    _remember("capacity_value", _label(cap, "Value", _capacity_text(), Rect2(16, 38, inner_w - 32, 24), 18, "text", 700))
    _label(cap, "Meta", "Reputation %d • %d assets unlocked" % [_rep(), _unlocked_asset_count()], Rect2(16, 66, inner_w - 32, 14), 10, "success", 600)
    _transparent_button(cap, "OpenIntelligence", Rect2(0, 0, inner_w, 88), _show_view.bind("intelligence"))

    var list_panel = _panel(mobile_content, "ExpansionAssets", Rect2(18, 188, inner_w, 278), "surface", "border", 18)
    _label(list_panel, "Head", "EXPANSION ASSETS", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    var assets = _expansion_assets()
    for i in range(mini(4, assets.size())):
        _build_asset_row(list_panel, i, assets[i], 42 + i * 54, inner_w - 24)

    var selected = _selected_asset()
    var detail = _panel(mobile_content, "AssetDetail", Rect2(18, 484, inner_w, 166), "surface", "border", 18)
    _remember("asset_name", _label(detail, "Head", str(selected.get("name", "NO ASSET")), Rect2(16, 14, inner_w - 120, 20), 15, "text", 700))
    _remember("asset_state", _label(detail, "State", _asset_state(selected), Rect2(inner_w - 112, 17, 96, 14), 9, _asset_state_role(selected), 600, HORIZONTAL_ALIGNMENT_RIGHT))
    _remember("asset_body", _label(detail, "Body", _asset_detail_text(selected), Rect2(16, 44, inner_w - 32, 90), 11, "muted", 400))

    _frame_button(mobile_content, "EmpireCTA", _asset_cta_label(selected), Rect2(18, 668, inner_w, 60), _asset_cta, false, true, 11)

func _build_asset_row(panel: Panel, index: int, asset: Dictionary, y: float, w: float) -> void:
    var selected = index == _selected_asset_index()
    var row = _panel(panel, "AssetRow%d" % index, Rect2(12, y, w, 46), "selected" if selected else "surface_2", "plum" if selected else "border", 12)
    _label(row, "Name", str(asset.get("name", "ASSET")).to_upper(), Rect2(12, 8, 150, 14), 10, "text", 600)
    _label(row, "State", _asset_state(asset), Rect2(w - 150, 8, 138, 14), 9, _asset_state_role(asset), 600, HORIZONTAL_ALIGNMENT_RIGHT)
    _label(row, "Meta", "L%d • %s" % [int(asset.get("level", 1)), _money(int(asset.get("value", asset.get("cost", 0))))], Rect2(12, 26, w - 24, 14), 9, "muted", 400)
    _transparent_button(row, "SelectAsset%d" % index, Rect2(0, 0, w, 46), _select_asset.bind(index))

func _build_mobile_world() -> void:
    var w = _content_width()
    _header("WORLD NETWORK", "%d REGIONS • %d TRADE ROUTES" % [_region_presence_count(), _trade_route_count()])
    var inner_w = w - 36.0
    var map = _panel(mobile_content, "RegionalMap", Rect2(18, 82, inner_w, 220), "surface", "border", 22)
    map.clip_contents = true
    _add_art(map, "RegionalDistrictArt", Rect2(0, 0, inner_w, 220), DISTRICT_ART, 0.88)
    var map_scrim := ColorRect.new()
    map_scrim.position = Vector2.ZERO
    map_scrim.size = Vector2(inner_w, 220)
    map_scrim.color = Color(0.02, 0.04, 0.045, 0.38 if not _is_light_theme() else 0.28)
    map_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map.add_child(map_scrim)
    _label(map, "Head", "REGIONAL FOOTPRINT", Rect2(14, 14, inner_w - 28, 14), 10, "gold", 600)
    _route_bar(map, Vector2(86, 92), 120, -12)
    _route_bar(map, Vector2(198, 74), 94, 29)
    _route_bar(map, Vector2(96, 116), 78, 52)
    var pts = [
        {"x":72.0,"y":82.0,"role":"success","name":"CENTRAL"},
        {"x":190.0,"y":56.0,"role":"gold","name":"NORTH"},
        {"x":268.0,"y":132.0,"role":"warning","name":"EAST"},
        {"x":112.0,"y":154.0,"role":"muted","name":"SOUTH"}
    ]
    for p in pts:
        var dot = Panel.new()
        dot.position = Vector2(minf(float(p.get("x", 0.0)), inner_w - 40), float(p.get("y", 0.0)))
        dot.size = Vector2(22,22)
        dot.add_theme_stylebox_override("panel", _solid_round(_color(str(p.get("role", "muted"))), 11))
        map.add_child(dot)
        _label(map, "Region" + str(p.get("name", "REGION")), str(p.get("name", "REGION")), Rect2(dot.position.x - 18, dot.position.y + 28, 64, 14), 8, str(p.get("role", "muted")), 600, HORIZONTAL_ALIGNMENT_CENTER)

    var region = _panel(mobile_content, "RegionDetail", Rect2(18, 320, inner_w, 142), "surface", "border", 18)
    _label(region, "Head", _current_region_name(), Rect2(16, 14, inner_w - 140, 20), 15, "text", 700)
    _label(region, "State", "PRESENCE ESTABLISHED" if _region_presence_count() > 0 else "EXPANSION READY", Rect2(inner_w - 150, 17, 134, 14), 9, "success" if _region_presence_count() > 0 else "gold", 600, HORIZONTAL_ALIGNMENT_RIGHT)
    _label(region, "Body", _region_detail_text(), Rect2(16, 46, inner_w - 32, 70), 11, "muted", 400)

    var opp = _panel(mobile_content, "WorldOpportunities", Rect2(18, 480, inner_w, 176), "surface", "border", 18)
    _label(opp, "Head", "WORLD OPPORTUNITIES", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    var items = [
        ["CUSTOMER DEMAND", "%d units remain" % _demand_remaining(), "ACTIVE" if _demand_remaining() > 0 else "SATISFIED", "success" if _demand_remaining() > 0 else "muted"],
        ["EXPANSION ASSETS", "%d unlocked" % _unlocked_asset_count(), "READY" if _unlocked_asset_count() > _owned_asset_count() else "MANAGED", "gold"],
        ["RIVAL NETWORK", "%d tracked" % _rival_count(), "MONITOR" if _rival_count() > 0 else "QUIET", "warning" if _rival_count() > 0 else "muted"]
    ]
    for i in range(items.size()):
        var y = 46.0 + i * 40.0
        _label(opp, "Item%d" % i, items[i][0], Rect2(16, y, 118, 14), 10, "text", 600)
        _label(opp, "Meta%d" % i, items[i][1], Rect2(146, y, 92, 14), 9, "muted", 400)
        _label(opp, "State%d" % i, items[i][2], Rect2(inner_w - 106, y, 86, 14), 9, items[i][3], 600, HORIZONTAL_ALIGNMENT_RIGHT)

    _frame_button(mobile_content, "WorldCTA", "UPGRADE NORTH INFRASTRUCTURE", Rect2(18, 674, inner_w, 54), _upgrade_region, false, true, 10)

func _route_bar(parent_node: Node, pos: Vector2, width: float, degrees: float) -> void:
    var r = Panel.new()
    r.position = pos
    r.size = Vector2(width,4)
    r.rotation_degrees = degrees
    r.add_theme_stylebox_override("panel", _solid_round(_color("border"), 2))
    parent_node.add_child(r)

func _build_mobile_portfolio() -> void:
    var w = _content_width()
    _header("PORTFOLIO", "%d ASSETS • %s VALUE" % [_owned_asset_count(), _money(_worth())])
    var inner_w = w - 36.0
    var gap = 6.0
    var tile_w = (inner_w - gap) * 0.5
    _stat_tile(mobile_content, "asset_value", 18, 82, tile_w, "ASSET VALUE", _money(_worth()), "LIVE")
    _stat_tile(mobile_content, "daily_income", 18 + tile_w + gap, 82, tile_w, "DAILY INCOME", _money(maxi(0,_last_profit())), "LIVE")

    var list_panel = _panel(mobile_content, "OwnedAssets", Rect2(18, 204, inner_w, 350), "surface", "border", 18)
    _label(list_panel, "Head", "OWNED ASSETS", Rect2(16, 14, inner_w - 32, 14), 10, "gold", 600)
    var rows = _portfolio_rows()
    for i in range(mini(6, rows.size())):
        var row: Dictionary = rows[i]
        var y = 42.0 + i * 49.0
        var p = _panel(list_panel, "PortfolioRow%d" % i, Rect2(12, y, inner_w - 24, 42), "surface_2", "border", 10)
        _label(p, "Name", str(row.get("name","ASSET")), Rect2(12,8,136,13), 9, "text", 600)
        _label(p, "State", str(row.get("state","OWNED")), Rect2(inner_w - 180,8,144,12), 8, str(row.get("role","success")), 600, HORIZONTAL_ALIGNMENT_RIGHT)
        _label(p, "Meta", str(row.get("meta","")), Rect2(12,24,inner_w - 48,12), 8, "muted", 400)

    var mix = _panel(mobile_content, "PortfolioBalance", Rect2(18, 572, inner_w, 156), "surface", "border", 18)
    _label(mix, "Head", "PORTFOLIO BALANCE", Rect2(16,14,inner_w - 32,14), 10, "gold", 600)
    _label(mix, "Body", _portfolio_balance_text(), Rect2(16,44,inner_w - 32,94), 11, "text", 400)

func _build_mobile_intelligence() -> void:
    var w = _content_width()
    _header("EMPIRE INTELLIGENCE", "POWER %d • %d REGIONS • %d RIVALS" % [_power_total(), _region_presence_count(), _rival_count()])
    var inner_w = w - 36.0
    var company = _panel(mobile_content, "Company", Rect2(18, 82, inner_w, 82), "surface", "border", 18)
    _label(company, "Name", _company_name(), Rect2(16,14,inner_w - 32,20), 15, "text", 700)
    _label(company, "Meta", "DAY %d • CASH %s • REP %d" % [_day(), _money(_cash()), _rep()], Rect2(16,44,inner_w - 32,14), 10, "muted", 600)

    var cards = _intelligence_cards()
    for i in range(mini(5,cards.size())):
        var c: Dictionary = cards[i]
        var y = 182.0 + i * 102.0
        var selected = i == 0
        var p = _panel(mobile_content, "IntelCard%d" % i, Rect2(18,y,inner_w,88), "selected" if selected else "surface", "plum" if selected else "border", 16)
        _label(p, "Head", str(c.get("head","")), Rect2(14,12,150,14), 9, "gold", 600)
        _label(p, "Title", str(c.get("title","")), Rect2(14,32,inner_w - 28,18), 13, "text", 600)
        _label(p, "Body", str(c.get("body","")), Rect2(14,54,inner_w - 28,30), 10, "muted", 400)

func _build_mobile_more() -> void:
    var w = _content_width()
    _header("MORE COMMANDS", "MANAGE THE ENTERPRISE")
    var inner_w = w - 36.0
    var company = _panel(mobile_content, "CompanyProfile", Rect2(18, 82, inner_w, 94), "surface", "border", 18)
    _label(company, "Name", _company_name(), Rect2(16,14,inner_w - 32,20), 15, "text", 700)
    _label(company, "Meta", "Reputation %d • Company Level %d • Autosave on" % [_rep(), _company_level()], Rect2(16,42,inner_w - 32,14), 10, "muted", 400)
    _label(company, "Health", "%d ACTIVE CONTRACT%s" % [_active_contracts(), "" if _active_contracts() == 1 else "S"], Rect2(16,68,180,14), 9, "success", 600)

    var tiles = [
        ["REGIONS","Markets and expansion","world","regions"],
        ["INTELLIGENCE","Company and market signals","intelligence",""],
        ["CORPORATIONS","Rivals and diplomacy","CorporationsPanel","competitors"],
        ["CONTRACTS","Customers and renewals","ContractPanel","contracts"],
        ["TECHNOLOGY","Research and upgrades","TechnologyPanel","technology"],
        ["HEADQUARTERS","Capacity and policy","HeadquartersPanel","headquarters"],
        ["HISTORY","Milestones and museum","HistoryPanel",""],
        ["SAVE / LOAD","Profiles and recovery","SaveLoadPanel",""],
        ["SETTINGS","Theme, audio, purchases, privacy","settings",""]
    ]
    var gap = 8.0
    var col_w = (inner_w - gap) * 0.5
    for i in range(tiles.size()):
        var col = i % 2
        var row = floori(float(i) / 2.0)
        var x = 18.0 + col * (col_w + gap)
        var y = 196.0 + row * 94.0
        var required_unlock := str(tiles[i][3])
        var locked := not required_unlock.is_empty() and not _has_unlock(required_unlock)
        var p = _panel(mobile_content, "MoreTile%d" % i, Rect2(x,y,col_w,82), "surface" if locked else ("selected" if i == 0 else "surface"), "border" if locked else ("plum" if i == 0 else "border"), 16)
        _label(p, "Head", tiles[i][0], Rect2(14,14,col_w - 28,14), 10, "muted" if locked else ("gold" if i == 0 else "text"), 600)
        var body_text := "Unlocks at Company Level %d" % _unlock_level(required_unlock) if locked else str(tiles[i][1])
        _label(p, "Body", body_text, Rect2(14,38,col_w - 28,32), 9, "muted", 400)
        var target = str(tiles[i][2])
        var open_button: Button
        if ["world","intelligence","settings"].has(target):
            open_button = _transparent_button(p, "Open"+target, Rect2(0,0,col_w,82), _show_view.bind(target))
        else:
            open_button = _transparent_button(p, "Open"+target, Rect2(0,0,col_w,82), _open_screen.bind(target))
        open_button.disabled = locked
        if locked:
            open_button.tooltip_text = body_text

func _build_mobile_settings() -> void:
    if mobile_content != null:
        mobile_content.custom_minimum_size.y = maxf(mobile_content.custom_minimum_size.y, 790.0)
        mobile_content.size.y = maxf(mobile_content.size.y, 790.0)
    var w = _content_width()
    var mode = "LIGHT MODE" if _is_light_theme() else "DARK MODE"
    _header("SETTINGS", "PERSONALIZE RESTORA", mode)
    var inner_w = w - 36.0

    var appearance = _panel(mobile_content, "Appearance", Rect2(18,82,inner_w,160), "surface", "border", 18)
    _label(appearance, "Head", "APPEARANCE", Rect2(16,14,180,14), 10, "gold", 600)
    _label(appearance, "Theme", "THEME", Rect2(16,44,100,16), 11, "text", 600)
    var btn_gap = 8.0
    var b1 = 96.0
    var b2 = maxf(96.0, inner_w - 32.0 - b1*2.0 - btn_gap*2.0)
    _frame_button(appearance, "DarkTheme", "DARK", Rect2(16,70,b1,54), _set_theme.bind("dark"), not _is_light_theme() and _theme_mode() == "dark")
    _frame_button(appearance, "LightTheme", "LIGHT", Rect2(16+b1+btn_gap,70,b1,54), _set_theme.bind("light"), _is_light_theme() and _theme_mode() == "light")
    _frame_button(appearance, "DeviceTheme", "DEVICE", Rect2(16+b1*2+btn_gap*2,70,b2,54), _set_theme.bind("system"), _theme_mode() == "system")
    _label(appearance, "Help", "Applies across every command screen.", Rect2(16,134,inner_w - 32,14), 9, "muted", 400)

    var audio = _panel(mobile_content, "AudioAccessibility", Rect2(18,258,inner_w,174), "surface", "border", 18)
    _label(audio, "Head", "AUDIO & ACCESSIBILITY", Rect2(16,14,220,14), 10, "gold", 600)
    _label(audio, "Music", "MUSIC", Rect2(16,44,180,16), 11, "text", 600)
    _label(audio, "MusicMeta", "Adaptive soundtrack", Rect2(16,64,214,14), 9, "muted", 400)
    _frame_button(audio, "MusicValue", "%d%%" % int(round(_music_level()*100.0)), Rect2(inner_w-116,36,98,48), _cycle_music)
    _label(audio, "Sfx", "SOUND EFFECTS", Rect2(16,84,180,16), 11, "text", 600)
    _label(audio, "SfxMeta", "UI, restoration, success cues", Rect2(16,104,214,14), 9, "muted", 400)
    _frame_button(audio, "SfxValue", "%d%%" % int(round(_sfx_level()*100.0)), Rect2(inner_w-116,84,98,48), _cycle_sfx)
    _label(audio, "Motion", "REDUCE MOTION", Rect2(16,140,190,16), 11, "text", 600)
    _toggle(audio, "MotionToggle", Vector2(inner_w-68,136), _reduce_motion(), _toggle_motion)

    var monet = _panel(mobile_content, "Monetization", Rect2(18,448,inner_w,230), "surface", "border", 18)
    _label(monet, "Head", "PREMIUM & REWARDS", Rect2(16,14,220,14), 10, "gold", 600)
    _label(monet, "Premium", "PREMIUM", Rect2(16,44,180,16), 11, "text", 600)
    _label(monet, "PremiumMeta", _premium_meta(), Rect2(16,64,214,14), 9, "muted", 400)
    _frame_button(monet, "PremiumView", "VIEW", Rect2(inner_w-116,34,98,48), _purchase_premium, true)
    _label(monet, "Restore", "RESTORE PURCHASES", Rect2(16,86,180,16), 11, "text", 600)
    _label(monet, "RestoreMeta", "Verify Google Play entitlement", Rect2(16,106,214,14), 9, "muted", 400)
    _frame_button(monet, "RestoreButton", "RESTORE", Rect2(inner_w-116,82,98,48), _restore_premium)
    _label(monet, "Rewards", "OPTIONAL REWARDED OFFERS", Rect2(16,130,220,16), 11, "text", 600)
    _toggle(monet, "RewardsToggle", Vector2(inner_w-68,128), _rewarded_enabled(), _open_rewards)
    _label(monet, "RewardMeta", "Sponsor Grant + Market Research • max 2/day", Rect2(16,150,inner_w - 32,14), 9, "muted", 400)
    _label(monet, "NoForced", "NO FORCED ADS", Rect2(16,180,130,14), 9, "success", 600)
    _transparent_text_button(monet, "Privacy", "PRIVACY POLICY", Rect2(inner_w-128,174,112,48), _open_privacy, "plum")

    var save = _panel(mobile_content, "SaveData", Rect2(18,694,inner_w,86), "surface", "border", 18)
    _label(save, "Head", "SAVE & DATA", Rect2(16,12,160,14), 10, "gold", 600)
    _label(save, "Auto", "AUTOSAVE", Rect2(16,38,180,16), 11, "text", 600)
    _label(save, "AutoMeta", "Enabled on mobile pause/close", Rect2(16,58,214,14), 9, "muted", 400)
    _frame_button(save, "AutosaveState", "ON", Rect2(inner_w-116,30,98,48), _save_company)

func _toggle(parent_node: Node, name: String, pos: Vector2, on: bool, callback: Callable) -> void:
    var track = Panel.new()
    track.name = name
    track.position = pos
    track.size = Vector2(48,28)
    track.add_theme_stylebox_override("panel", _solid_round(_color("plum") if on else _color("surface_2"), 14))
    parent_node.add_child(track)
    var knob = Panel.new()
    knob.position = Vector2(23 if on else 3,3)
    knob.size = Vector2(22,22)
    knob.add_theme_stylebox_override("panel", _solid_round(_color("surface"), 11))
    track.add_child(knob)
    _transparent_button(track, name+"Hit", Rect2(0,-10,48,48), callback)

func _transparent_text_button(parent_node: Node, name: String, text_value: String, rect: Rect2, callback: Callable, role: String) -> Button:
    var b = Button.new()
    b.name = name
    b.text = text_value
    b.position = rect.position
    b.size = rect.size
    b.focus_mode = Control.FOCUS_ALL
    b.flat = true
    b.add_theme_font_override("font", _font(600))
    b.add_theme_font_size_override("font_size", 9)
    b.add_theme_color_override("font_color", _color(role))
    b.add_theme_color_override("font_hover_color", _color(role).lightened(0.08))
    if callback.is_valid(): b.pressed.connect(callback, CONNECT_DEFERRED)
    parent_node.add_child(b)
    return b

func _build_desktop_live() -> void:
    var size = _layout_size()
    var design = Vector2(1280,720)
    var scale_factor = minf(size.x/design.x, size.y/design.y)
    var canvas = Control.new()
    canvas.name = "DesktopExecutive"
    canvas.size = design
    canvas.scale = Vector2.ONE * scale_factor
    canvas.position = (size - design * scale_factor) * 0.5
    root.add_child(canvas)

    _label(canvas, "Brand", "RESTORA", Rect2(34,26,240,34), 28, "text", 700)
    _label(canvas, "Mode", "EXECUTIVE COMMAND • DAY %d" % _day(), Rect2(34,62,300,16), 10, "gold", 600)
    var world = _panel(canvas, "WorldPropertyView", Rect2(34,104,560,552), "surface", "border", 24)
    _label(world, "Head", "CURRENT BUILDING", Rect2(21,19,250,16), 11, "gold", 600)
    var scene = _panel(world, "Scene", Rect2(21,57,516,316), "surface_2", "border", 20)
    scene.clip_contents = true
    _remember("desktop_building_art", _add_texture(scene, "DesktopBuildingArt", Rect2(0,0,516,316), _building_stage_texture(), 1.0))
    _remember("desktop_property_meta", _label(world, "Meta", "%s • %s\n%d%% restored • %s market value" % [_building_name(), _building_type(), _building_progress(), _money(int(_selected_building().get("value", 0)))], Rect2(21,401,500,54), 14, "text", 400))
    _transparent_button(world, "OpenProperty", Rect2(0,0,560,552), _show_view.bind("property"))

    _desktop_stat(canvas, "Cash", Rect2(620,104,190,96), "CASH", _money(_cash()), "cash")
    _desktop_stat(canvas, "Worth", Rect2(824,104,190,96), "WORTH", _money(_worth()), "worth")
    _desktop_stat(canvas, "Rep", Rect2(1028,104,218,96), "REP", str(_rep()), "rep")

    var objective = _panel(canvas, "Objective", Rect2(620,220,626,184), "surface", "border", 18)
    _label(objective, "Head", "NEXT OBJECTIVE", Rect2(18,16,200,16), 10, "gold", 600)
    _remember("desktop_objective_title", _label(objective, "Title", _objective_title(), Rect2(18,44,440,28), 22, "text", 700))
    _remember("desktop_objective_body", _label(objective, "Body", _objective_detail(), Rect2(18,84,560,48), 13, "muted", 400))

    var signals = _panel(canvas, "Signals", Rect2(620,426,304,230), "surface", "border", 18)
    _label(signals, "Head", "SIGNALS", Rect2(18,16,180,16), 10, "gold", 600)
    _remember("desktop_signals", _label(signals, "Body", _signal_lines(), Rect2(18,50,260,120), 13, "text", 400))

    var quick = _panel(canvas, "QuickActions", Rect2(942,426,304,230), "selected", "plum", 18)
    _label(quick, "Head", "QUICK ACTIONS", Rect2(18,16,180,16), 10, "gold", 600)
    _frame_button(quick, "OpenBuilding", "PROPERTY", Rect2(18,48,268,38), _show_view.bind("property"))
    _frame_button(quick, "OpenBusiness", "BUSINESS", Rect2(18,92,268,38), _show_view.bind("operate"))
    _frame_button(quick, "OpenFinance", "FINANCE", Rect2(18,136,268,38), _show_view.bind("finance"))
    _frame_button(quick, "OpenMore", "MORE", Rect2(18,180,268,38), _show_view.bind("more"))

func _desktop_stat(parent_node: Node, name: String, rect: Rect2, label_text: String, value_text: String, ref_key := "") -> void:
    var p = _panel(parent_node, name, rect, "surface", "border", 16)
    _label(p, "Label", label_text, Rect2(14,12,rect.size.x-28,14), 9, "gold", 600)
    var value_label := _label(p, "Value", value_text, Rect2(14,36,rect.size.x-28,30), 23, "text", 700)
    if not ref_key.is_empty():
        _remember(ref_key + "_value", value_label)
    _label(p, "Meta", "LIVE", Rect2(14,72,rect.size.x-28,14), 9, "muted", 600)

func _build_tablet_live() -> void:
    var size = _layout_size()
    var design = Vector2(834,1194)
    var scale_factor = minf(size.x/design.x, size.y/design.y)
    var canvas = Control.new()
    canvas.name = "TabletLive"
    canvas.size = design
    canvas.scale = Vector2.ONE * scale_factor
    canvas.position = (size - design * scale_factor) * 0.5
    root.add_child(canvas)
    _label(canvas, "Brand", "RESTORA", Rect2(32,28,260,36), 30, "text", 700)
    _label(canvas, "Mode", "TABLET • LIVE COMMAND", Rect2(32,68,300,16), 10, "gold", 600)
    var hero = _panel(canvas, "Hero", Rect2(32,112,770,250), "surface", "border", 24)
    _label(hero, "Head", "NEXT MOVE", Rect2(22,20,180,16), 10, "gold", 600)
    _remember("tablet_objective_title", _label(hero, "Title", _objective_title(), Rect2(22,52,420,36), 28, "text", 700))
    _remember("tablet_stage_meta", _label(hero, "Meta", _stage_meta(), Rect2(22,96,360,20), 14, "muted", 400))
    var scene = _panel(hero, "Scene", Rect2(506,22,240,206), "surface_2", "border", 20)
    scene.clip_contents = true
    _remember("tablet_building_art", _add_texture(scene, "TabletBuildingArt", Rect2(0,0,240,206), _building_stage_texture(), 1.0))
    var xs = [32.0,228.0,424.0,620.0]
    var names = ["CASH","WORTH","REPUTATION","GOODS"]
    var vals = [_money(_cash()),_money(_worth()),str(_rep()),str(_goods())]
    for i in range(4):
        _desktop_stat(canvas, "Stat%d"%i, Rect2(xs[i],390,180 if i<3 else 182,96), names[i], vals[i], ["cash","worth","rep","goods"][i])
    var ops = _panel(canvas, "Operations", Rect2(32,508,370,524), "surface", "border", 18)
    _label(ops, "Head", "OPERATIONS", Rect2(20,18,180,18), 12, "gold", 600)
    _remember("tablet_operations", _label(ops, "Body", "Production\n%s\n\nContracts\n%d active\n\nPeople\n%d staff\n\nInventory\n%d inputs • %d goods\n\nFleet\nLevel %d" % [_production_rate_text(), _active_contracts(), _employees(), _inputs(), _goods(), maxi(1,_transport_level())], Rect2(20,56,330,330), 15, "text", 400))
    var sig = _panel(canvas, "SignalsObjectives", Rect2(420,508,382,524), "surface", "border", 18)
    _label(sig, "Head", "SIGNALS + OBJECTIVES", Rect2(20,18,250,18), 12, "gold", 600)
    _remember("tablet_signals", _label(sig, "Body", "%s\n\nNEXT OBJECTIVE\n%s" % [_signal_lines(), _objective_title()], Rect2(20,56,342,330), 15, "text", 400))
    var nav = _panel(canvas, "Nav", Rect2(32,1054,770,92), "surface", "border", 26)
    _label(nav, "Labels", "HOME        BUSINESS        PROPERTY        FINANCE        MORE", Rect2(54,36,660,20), 13, "text", 600, HORIZONTAL_ALIGNMENT_CENTER)

func _refresh() -> void:
    if root == null:
        return
    if _layout_kind != _layout_class():
        _rebuild_current()
        return
    match active_view:
        "live":
            _set_ref_text("right_status", "DAY %d" % _day())
            _set_ref_text("hero_title", _objective_title())
            _set_ref_text("hero_goal", _stage_meta())
            _set_ref_text("cash_value", _money(_cash()))
            _set_ref_text("worth_value", _money(_worth()))
            _set_ref_text("rep_value", str(_rep()))
            _set_ref_text("goods_value", str(_goods()))
            _set_ref_text("signals", _core_loop_lines())
            _set_ref_text("signal_footer", _core_loop_status())
            _set_ref_text("desktop_property_meta", "%s • %s\n%d%% restored • %s market value" % [_building_name(), _building_type(), _building_progress(), _money(int(_selected_building().get("value", 0)))])
            _set_ref_text("desktop_objective_title", _objective_title())
            _set_ref_text("desktop_objective_body", _objective_detail())
            _set_ref_text("desktop_signals", _signal_lines())
            _set_ref_text("tablet_objective_title", _objective_title())
            _set_ref_text("tablet_stage_meta", _stage_meta())
            _set_ref_text("tablet_operations", "Production\n%s\n\nContracts\n%d active\n\nPeople\n%d staff\n\nInventory\n%d inputs • %d goods\n\nFleet\nLevel %d" % [_production_rate_text(), _active_contracts(), _employees(), _inputs(), _goods(), maxi(1,_transport_level())])
            _set_ref_text("tablet_signals", "%s\n\nNEXT OBJECTIVE\n%s" % [_signal_lines(), _objective_title()])
            for art_key in ["desktop_building_art", "tablet_building_art"]:
                var art = refs.get(art_key) as TextureRect
                if art != null:
                    art.texture = _building_stage_texture()
            var fill = refs.get("progress_fill") as Control
            if fill != null and fill.get_parent() is Control:
                fill.size.x = maxf(4.0, (fill.get_parent() as Control).size.x * float(_restoration()) / 100.0)
        "operate":
            _set_ref_text("inputs_value", str(_inputs()))
            _set_ref_text("goods_value", str(_goods()))
            _set_ref_text("production_rate", _production_rate_text())
            _set_ref_text("commercial_body", _commercial_text())
        "finance":
            _set_ref_text("cash_value", _money(_cash()))
            _set_ref_text("debt_value", _money(_debt()))
            _set_ref_text("revenue_value", _money(maxi(0,_last_sales())))
            _set_ref_text("equity_value", _money(maxi(0,_worth()-_debt())))
        "empire":
            _set_ref_text("capacity_value", _capacity_text())
            var selected = _selected_asset()
            _set_ref_text("asset_name", str(selected.get("name","NO ASSET")))
            _set_ref_text("asset_state", _asset_state(selected))
            _set_ref_text("asset_body", _asset_detail_text(selected))

func _set_ref_text(key: String, value: String) -> void:
    var node = refs.get(key)
    if node is Label:
        (node as Label).text = value

func _state_signature() -> String:
    return "%s|%d|%d|%d|%d|%d|%d|%s|%s" % [
        active_view, _cash(), _rep(), _day(), _restoration(), _goods(), _debt(),
        str(_business_open()), str(_selected_asset_index())
    ]

func _state_value(domain: String, key: String, default_value):
    var state = _game_state()
    if state != null and state.has_method("get_value"):
        return state.get_value(domain, key, default_value)
    return default_value

func _cash() -> int:
    return int(parent.cash) if parent != null and "cash" in parent else int(_state_value("finance","cash",0))

func _rep() -> int:
    return int(parent.reputation) if parent != null and "reputation" in parent else int(_state_value("company","reputation",0))

func _day() -> int:
    return int(parent.day) if parent != null and "day" in parent else int(_state_value("company","day",1))

func _debt() -> int:
    return int(parent.debt) if parent != null and "debt" in parent else int(_state_value("finance","debt",0))

func _restoration() -> int:
    return int(parent.restoration) if parent != null and "restoration" in parent else int(_state_value("properties","restoration",0))

func _stage() -> String:
    return str(parent.stage) if parent != null and "stage" in parent else str(_state_value("properties","stage","Neglected"))

func _owned() -> bool:
    return bool(parent.owned) if parent != null and "owned" in parent else bool(_state_value("properties","owned",false))

func _inspected() -> bool:
    return bool(parent.inspected) if parent != null and "inspected" in parent else bool(_state_value("properties","inspected",false))

func _business_open() -> bool:
    return bool(parent.business_open) if parent != null and "business_open" in parent else bool(_state_value("business","open",false))

func _goods() -> int:
    return int(parent.finished_goods) if parent != null and "finished_goods" in parent else int(_state_value("production","finished_goods",0))

func _inputs() -> int:
    return int(_state_value("production","inputs",0))

func _employees() -> int:
    return int(parent.employees) if parent != null and "employees" in parent else int(_state_value("employees","count",0))

func _last_sales() -> int:
    return int(parent.last_sales) if parent != null and "last_sales" in parent else int(_state_value("finance","last_sales",0))

func _last_profit() -> int:
    return int(parent.last_profit) if parent != null and "last_profit" in parent else int(_state_value("finance","last_profit",0))

func _transport_level() -> int:
    return int(parent.transport_level) if parent != null and "transport_level" in parent else int(_state_value("branches","transport_level",0))

func _active_contracts() -> int:
    if parent != null and "contract_days" in parent and int(parent.contract_days) > 0:
        return 1
    return int(_state_value("contracts","active_count",0))

func _money(value: int) -> String:
    var abs_value = abs(value)
    var prefix = "-$" if value < 0 else "$"
    if abs_value >= 1000000:
        return "%s%.2fM" % [prefix, float(abs_value)/1000000.0]
    if abs_value >= 1000:
        return "%s%.1fK" % [prefix, float(abs_value)/1000.0]
    return "%s%d" % [prefix, abs_value]

func _worth() -> int:
    var value = _cash()
    var model = _property_system()
    if model != null and model.has_method("list_properties"):
        for property in model.list_properties():
            if property is Dictionary and bool(property.get("owned", false)):
                if model.has_method("sale_value"):
                    value += int(model.sale_value(property))
                else:
                    value += int(property.get("value", 0))
    else:
        value += int(_state_value("properties","value",0))
    for a in _expansion_assets():
        if bool(a.get("owned",false)):
            value += int(a.get("value",a.get("cost",0)))
    return maxi(value, _cash())

func _acquisition_cost() -> int:
    var model = _property_system()
    if model != null and model.has_method("acquisition_cost"):
        return int(model.acquisition_cost())
    if parent != null and parent.has_method("_acquisition_cost"):
        return int(parent._acquisition_cost())
    return 5000

func _objective_title() -> String:
    if not _inspected():
        return "Inspect " + _building_name()
    if not _owned():
        return "Acquire " + _building_name()
    if _stage() != "Operational":
        return "Restore " + _building_name()
    if not _business_open():
        return "Open your first business"
    if _inputs() <= 0 and _goods() <= 0:
        return "Buy production inputs"
    if _goods() <= 0:
        return "Produce your first batch"
    if _last_sales() <= 0:
        return "Sell your first goods"
    return "Reinvest and grow"

func _objective_detail() -> String:
    if not _inspected():
        return "Start with the property: inspect it to understand condition and restoration needs."
    if not _owned():
        return "Acquire the inspected property for %s so restoration can begin." % _money(_acquisition_cost())
    if _stage() != "Operational":
        return "Finish the restoration stages. An Operational property can host a business."
    if not _business_open():
        return "Move to Business and choose what the restored property will operate as."
    if _inputs() <= 0 and _goods() <= 0:
        return "Buy inputs in Business. Inputs are the raw materials used to make goods."
    if _goods() <= 0:
        return "Produce a batch in Business. Finished goods are the inventory you can sell."
    if _last_sales() <= 0:
        return "Open Commercial Controls in Business and sell the finished goods."
    return "The core loop is complete. Reinvest profit into capacity, property and expansion."

func _objective_view() -> String:
    if not _inspected() or not _owned() or _stage() != "Operational":
        return "property"
    if not _business_open() or _inputs() <= 0 or _goods() <= 0 or _last_sales() <= 0:
        return "operate"
    return "more"

func _core_phase() -> String:
    if _stage() != "Operational":
        return "RESTORE"
    if not _business_open() or _last_sales() <= 0:
        return "OPERATE"
    return "GROW"

func _core_loop_lines() -> String:
    var restore_mark := "●" if _core_phase() == "RESTORE" else "✓"
    var operate_mark := "●" if _core_phase() == "OPERATE" else ("✓" if _core_phase() == "GROW" else "○")
    var grow_mark := "●" if _core_phase() == "GROW" else "○"
    return "%s  1. RESTORE PROPERTY\n%s  2. OPERATE BUSINESS\n%s  3. REINVEST & GROW" % [restore_mark, operate_mark, grow_mark]

func _core_loop_status() -> String:
    return "CURRENT PHASE: %s  •  %s" % [_core_phase(), _objective_title().to_upper()]

func _stage_meta() -> String:
    return "%s • %d%% restored" % [_building_name(), _building_progress()]

func _stage_index() -> int:
    var names = ["Neglected","Cleaned","Repaired","Painted","Operational"]
    var idx = names.find(_stage())
    return maxi(1, idx + 1)

func _stage_step_text() -> String:
    match _stage():
        "Neglected": return "Initial inspection pending" if not _inspected() else "Property surveyed"
        "Cleaned": return "Site cleaned"
        "Repaired": return "Utilities restored"
        "Painted": return "Exterior reinforced"
        "Operational": return "Restoration complete"
        _: return _stage()

func _next_stage_text() -> String:
    if not _inspected(): return "NEXT  •  Inspect property condition"
    if not _owned(): return "NEXT  •  Acquire property  •  %s" % _money(_acquisition_cost())
    if _stage() == "Operational": return "NEXT  •  Begin operating the asset"
    var cost = 0
    if parent != null and parent.has_method("_next_cost"):
        cost = int(parent._next_cost())
    return "NEXT  •  %s  •  %s" % [_next_stage_name(), _money(cost)]

func _next_stage_name() -> String:
    match _stage():
        "Neglected": return "Site cleanup"
        "Cleaned": return "Structural repair"
        "Repaired": return "Exterior reinforcement"
        "Painted": return "Operational fit-out"
        _: return "Open operations"

func _property_cta_label() -> String:
    if not _inspected(): return "INSPECT PROPERTY"
    if not _owned(): return "ACQUIRE PROPERTY  •  %s" % _money(_acquisition_cost())
    if _stage() != "Operational":
        var cost = int(parent._next_cost()) if parent != null and parent.has_method("_next_cost") else 0
        return "RESTORE NEXT STAGE  •  %s" % _money(cost)
    return "OPEN OPERATIONS"

func _property_cta() -> void:
    if parent == null: return
    if not _inspected() and parent.has_method("inspect_property"):
        parent.inspect_property()
    elif not _owned() and parent.has_method("acquire_property"):
        parent.acquire_property()
    elif _stage() != "Operational" and parent.has_method("restore_property"):
        parent.restore_property()
    else:
        _show_view("operate")
        return
    _rebuild_current()

func _production_rate_text() -> String:
    return "Capacity L%d  •  %d finished goods" % [
        maxi(1, int(_state_value("businesses","capacity_level",1))),
        _goods()
    ]

func _commercial_text() -> String:
    var price = int(parent.player_price) if parent != null and "player_price" in parent else int(_state_value("business","price",42))
    return "PRICE  %s  •  STAFF  %d  •  CAPACITY L%d\nMARKETING  %s\nCONTRACTS  %d live  •  %s" % [
        _money(price), _employees(), maxi(1, int(_state_value("businesses","capacity_level",1))),
        "Local campaign active" if int(_state_value("business","marketing_level",0)) > 0 else "Ready",
        _active_contracts(), "renewal due" if _active_contracts() > 0 else "open market"
    ]

func _open_business_choices() -> void:
    if parent == null or not parent.has_method("get_business_purposes"):
        return
    var purposes: Array = parent.get_business_purposes()
    if purposes.is_empty():
        return
    var old = mobile_content.get_node_or_null("BusinessChoiceModal") if mobile_content != null else null
    if old != null:
        old.queue_free()
    var w = _content_width()
    var panel = _panel(mobile_content, "BusinessChoiceModal", Rect2(18, 188, w - 36, 278), "selected", "plum", 18)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _label(panel, "Head", "CHOOSE BUSINESS", Rect2(16, 14, w - 68, 18), 12, "gold", 600)
    _label(panel, "Help", "Choose what this restored property will become.", Rect2(16, 40, w - 68, 32), 10, "muted", 400)
    var y = 82.0
    for i in range(mini(3, purposes.size())):
        var purpose: Dictionary = purposes[i] if purposes[i] is Dictionary else {}
        var name = str(purpose.get("name", "BUSINESS")).to_upper()
        _frame_button(panel, "Purpose%d" % i, name, Rect2(16, y, w - 68, 46), _choose_business.bind(i), i == 0, false, 10)
        y += 56.0
    _frame_button(panel, "CancelPurpose", "CANCEL", Rect2(16, 238, w - 68, 30), panel.queue_free, false, false, 9)

func _choose_business(index: int) -> void:
    if parent != null and parent.has_method("choose_business_purpose"):
        parent.choose_business_purpose(index)
    _rebuild_current()

func _open_commercial_actions() -> void:
    if mobile_content == null:
        return
    var existing = mobile_content.get_node_or_null("CommercialActionModal")
    if existing != null:
        existing.queue_free()
    var w = _content_width()
    var panel = _panel(mobile_content, "CommercialActionModal", Rect2(18, 318, w - 36, 250), "selected", "plum", 18)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _label(panel, "Head", "COMMERCIAL ACTIONS", Rect2(16, 14, w - 68, 18), 12, "gold", 600)
    _label(panel, "Help", "Move finished goods, fulfill live contracts, or open customer segments.", Rect2(16, 40, w - 68, 34), 10, "muted", 400)
    _frame_button(panel, "SellGoods", "SELL GOODS", Rect2(16, 86, w - 68, 42), _sell_goods, false, true, 10)
    _frame_button(panel, "DeliverContract", "DELIVER CONTRACT", Rect2(16, 138, w - 68, 42), _deliver_contract, false, false, 10)
    _frame_button(panel, "CustomerSegments", "CUSTOMER SEGMENTS", Rect2(16, 190, w - 68, 36), _open_screen.bind("CustomerSegmentsUI"), false, false, 9)
    _frame_button(panel, "CloseCommercialActions", "CLOSE", Rect2(w - 106, 14, 54, 28), panel.queue_free, false, false, 8)

func _sell_goods() -> void:
    if parent != null and parent.has_method("sell_goods"):
        parent.sell_goods()
    _rebuild_current()

func _deliver_contract() -> void:
    if parent != null and parent.has_method("deliver_contract"):
        parent.deliver_contract()
    _rebuild_current()

func _produce() -> void:
    if parent != null and parent.has_method("produce_goods"):
        parent.produce_goods()
    _refresh()

func _buy_inputs() -> void:
    if parent != null and parent.has_method("buy_inputs"):
        parent.buy_inputs()
    _refresh()

func _take_loan() -> void:
    if parent != null and parent.has_method("take_loan"):
        parent.take_loan()
    _refresh()

func _repay_loan() -> void:
    if parent != null and parent.has_method("repay_loan"):
        parent.repay_loan()
    _refresh()

func _request_investor() -> void:
    if parent != null and parent.has_method("request_investment"):
        parent.request_investment()
    else:
        _open_screen("FinancePanel")
    _refresh()

func _credit_score_text() -> String:
    var score = clampi(620 + _rep()*2 - int(float(_debt())/5000.0), 500, 850)
    var grade = "A−" if score >= 760 else ("B+" if score >= 700 else ("B" if score >= 650 else "C"))
    return "%s  •  SCORE %d" % [grade,score]

func _transaction_rows() -> Array:
    return [
        {"kind":"SALE","reason":"Goods revenue","amount":"+ " + _money(maxi(0,_last_sales())),"role":"success"},
        {"kind":"PAYROLL","reason":"%d employees" % _employees(),"amount":"- " + _money(maxi(0,_employees()*100)),"role":"danger"},
        {"kind":"SUPPLY","reason":"Core inputs","amount":"- " + _money(maxi(0,_inputs()*2)),"role":"danger"},
        {"kind":"REGION","reason":"Branch income","amount":"+ " + _money(maxi(0,_last_profit())),"role":"success"}
    ]

func _expansion_model():
    if parent == null or parent.get("command_system") == null:
        return null
    var expansion_system = parent.command_system.get("expansion_system")
    if expansion_system == null:
        return null
    return expansion_system.get("expansion")

func _expansion_assets() -> Array:
    var e = _expansion_model()
    if e != null and "properties" in e:
        return e.properties
    return []

func _selected_asset_index() -> int:
    if parent != null and "selected_expansion" in parent:
        return clampi(int(parent.selected_expansion),0,maxi(0,_expansion_assets().size()-1))
    return 0

func _selected_asset() -> Dictionary:
    var assets = _expansion_assets()
    if assets.is_empty(): return {}
    return assets[_selected_asset_index()]

func _select_asset(index: int) -> void:
    if parent != null and parent.has_method("select_expansion"):
        parent.select_expansion(index)
    _rebuild_current()

func _asset_state(a: Dictionary) -> String:
    if a.is_empty(): return "UNAVAILABLE"
    if bool(a.get("owned",false)):
        return "OPERATING" if bool(a.get("active",false)) else "OWNED / PAUSED"
    return "AVAILABLE" if bool(a.get("unlocked",false)) else "LOCKED"

func _asset_state_role(a: Dictionary) -> String:
    var state = _asset_state(a)
    if state == "OPERATING": return "success"
    if state == "AVAILABLE": return "gold"
    if state == "OWNED / PAUSED": return "warning"
    return "muted"

func _asset_detail_text(a: Dictionary) -> String:
    if a.is_empty(): return "No expansion asset is currently available."
    return "%s / %s\nCondition %d%%  •  Level %d\nValue %s  •  Income %s/day\nAcquire %s  •  Management +1" % [
        str(a.get("type","Asset")), str(a.get("industry","General")), int(a.get("condition",0)),
        int(a.get("level",1)), _money(int(a.get("value",0))), _money(int(a.get("income",0))), _money(int(a.get("cost",0)))
    ]

func _asset_cta_label(a: Dictionary) -> String:
    if a.is_empty(): return "NO ASSET AVAILABLE"
    if bool(a.get("owned",false)): return "UPGRADE %s" % str(a.get("name","ASSET")).to_upper()
    return "ACQUIRE %s • %s" % [str(a.get("name","ASSET")).to_upper(), _money(int(a.get("cost",0)))]

func _asset_cta() -> void:
    var a = _selected_asset()
    if a.is_empty() or parent == null: return
    if bool(a.get("owned",false)):
        if parent.has_method("upgrade_expansion"): parent.upgrade_expansion()
    elif parent.has_method("buy_expansion"):
        parent.buy_expansion()
    _rebuild_current()

func _capacity_text() -> String:
    if parent != null and parent.get("command_system") != null:
        var es = parent.command_system.get("expansion_system")
        if es != null and es.has_method("management_capacity"):
            var c: Dictionary = es.management_capacity()
            return "%d / %d ASSETS MANAGED" % [int(c.get("used",0)), int(c.get("capacity",0))]
    return "%d ASSETS MANAGED" % _owned_asset_count()

func _owned_asset_count() -> int:
    var count = 0
    for a in _expansion_assets():
        if bool(a.get("owned",false)): count += 1
    return count

func _unlocked_asset_count() -> int:
    var count = 0
    for a in _expansion_assets():
        if bool(a.get("unlocked",false)): count += 1
    return count

func _region_controller():
    return parent.get_node_or_null("World/RegionController") if parent != null else null

func _region_presence_count() -> int:
    var c = _region_controller()
    if c != null and "regions" in c and c.regions != null and "player_presence" in c.regions:
        return int(c.regions.player_presence.count(1))
    return 0

func _trade_route_count() -> int:
    return int(_state_value("regions","trade_routes",0))

func _current_region_name() -> String:
    var names = ["CENTRAL REGION","NORTH REGION","EAST REGION","SOUTH REGION"]
    var idx = int(parent.selected_district) if parent != null and "selected_district" in parent else 1
    return names[clampi(idx,0,names.size()-1)]

func _region_detail_text() -> String:
    return "Infrastructure L%d  •  %d region%s active\nBranch: %s Trade Office\nTransport fleet L%d  •  %d rival%s tracked" % [
        maxi(1,int(_state_value("regions","infrastructure_level",1))),
        _region_presence_count(), "" if _region_presence_count() == 1 else "s",
        _current_region_name().replace(" REGION","").capitalize(),
        maxi(1,_transport_level()),
        _rival_count(), "" if _rival_count() == 1 else "s"
    ]

func _upgrade_region() -> void:
    if parent != null and parent.has_method("upgrade_regional_infrastructure"):
        parent.upgrade_regional_infrastructure()
    else:
        _open_screen("InfrastructurePanel")
    _refresh()

func _portfolio_rows() -> Array:
    var out: Array = []
    if _business_open():
        out.append({"name":"RESTORA GOODS","state":"OPERATING","meta":"%s • %s/day" % [_money(maxi(100000,_worth()/3)),_money(maxi(0,_last_profit()))],"role":"success"})
    for a in _expansion_assets():
        if bool(a.get("owned",false)):
            out.append({"name":str(a.get("name","ASSET")).to_upper(),"state":_asset_state(a),"meta":"%s • %s/day" % [_money(int(a.get("value",0))),_money(int(a.get("income",0)))],"role":_asset_state_role(a)})
        if out.size() >= 6: break
    while out.size() < 6:
        var slot_number := out.size() + 1
        out.append({"name":"ASSET SLOT %d" % slot_number,"state":"OPEN","meta":"Acquire an asset to fill this slot","role":"muted"})
    return out

func _portfolio_balance_text() -> String:
    return "OPERATING BUSINESSES  %d\nRESOURCE SITES  %d\nMANAGEMENT CAPACITY  %s\nTRANSPORT FLEET  LEVEL %d" % [
        1 if _business_open() else 0, maxi(0,_owned_asset_count()-1), _capacity_text().replace(" ASSETS MANAGED",""), maxi(1,_transport_level())
    ]

func _company_name() -> String:
    if parent != null and "company_name" in parent:
        var n = str(parent.get("company_name"))
        if not n.is_empty() and n != "<null>": return n.to_upper()
    return "RESTORA HOLDINGS"

func _rival_count() -> int:
    var c = parent.get_node_or_null("World/Corporate") if parent != null else null
    return c.rivals.size() if c != null and "rivals" in c else 0

func _power_total() -> int:
    var ranking = get_node_or_null("/root/RenewGlobalRankingSystem")
    if ranking != null and ranking.has_method("world_power"):
        var power: Dictionary = ranking.world_power()
        return int(round(float(power.get("total",0.0))))
    return clampi(int((_rep()+_region_presence_count()*10+_owned_asset_count()*8)/2.0),0,100)

func _compact_card_text(value: String, limit := 56) -> String:
    var clean := value.replace("\n", " ").strip_edges()
    if clean.length() <= limit:
        return clean
    return clean.left(maxi(1, limit - 1)).strip_edges() + "…"

func _intelligence_cards() -> Array:
    var objective = _objective_title()
    var goal_body = _objective_detail()
    var prog = parent.get_node_or_null("Systems/Progression") if parent != null else null
    var claimed = 0
    var total = 0
    if prog != null and "milestones" in prog:
        claimed = int(prog.claimed.size()) if prog.claimed is Dictionary else 0
        total = prog.milestones.size()
    return [
        {"head":"NEXT OBJECTIVE","title":objective,"body":goal_body},
        {"head":"MILESTONES","title":"%d / %d achieved" % [claimed,total],"body":"Next milestone tracks the company's next major strategic achievement."},
        {"head":"WORLD POWER","title":"%d / 100" % _power_total(),"body":"Economic • Industrial • Logistics • Diplomacy"},
        {"head":"GLOBAL RANKING","title":"Valuation network","body":"Track RESTORA against the live corporate field."},
        {"head":"LATEST NOTICE","title":_compact_card_text(str(parent.message), 56) if parent != null and "message" in parent and not str(parent.message).is_empty() else "Systems stable","body":"Current company signals are synchronized with the live simulation."}
    ]

func _signal_lines() -> String:
    return "• Customer demand: %d units remain\n• Finished goods: %d\n• Rivals tracked: %d" % [
        _demand_remaining(), _goods(), _rival_count()
    ]

func _signal_footer() -> String:
    return "%d ACTIVE CONTRACT%s  •  %d RESEARCH READY" % [
        _active_contracts(), "" if _active_contracts() == 1 else "S",
        int(_state_value("technology","available_count",0))
    ]

func _open_screen(screen_name: String) -> void:
    var manager = _screen_manager()
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)

func _set_theme(mode: String) -> void:
    var manager = _theme_manager()
    if manager != null:
        manager.set_mode(mode)

func _theme_mode() -> String:
    var manager = _theme_manager()
    return str(manager.get_mode()) if manager != null and manager.has_method("get_mode") else ("light" if _is_light_theme() else "dark")

func _is_light_theme() -> bool:
    var manager = _theme_manager()
    return bool(manager.is_light()) if manager != null and manager.has_method("is_light") else false

func _music_level() -> float:
    var audio = _audio_manager()
    return float(audio.get_music_level()) if audio != null and audio.has_method("get_music_level") else 0.72

func _sfx_level() -> float:
    var audio = _audio_manager()
    return float(audio.get_sfx_level()) if audio != null and audio.has_method("get_sfx_level") else 0.84

func _cycle_music() -> void:
    var audio = _audio_manager()
    if audio != null and audio.has_method("set_music_level"):
        var next = fmod(_music_level() + 0.25, 1.25)
        if next > 1.0: next = 0.0
        audio.set_music_level(next)
    _rebuild_current()

func _cycle_sfx() -> void:
    var audio = _audio_manager()
    if audio != null and audio.has_method("set_sfx_level"):
        var next = fmod(_sfx_level() + 0.25, 1.25)
        if next > 1.0: next = 0.0
        audio.set_sfx_level(next)
    _rebuild_current()

func _reduce_motion() -> bool:
    return bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false))

func _toggle_motion() -> void:
    ProjectSettings.set_setting("renew/ui/reduce_motion", not _reduce_motion())
    var file = ConfigFile.new()
    file.load("user://restora_ui.cfg")
    file.set_value("accessibility","reduce_motion",_reduce_motion())
    file.save("user://restora_ui.cfg")
    _rebuild_current()

func _premium_status() -> Dictionary:
    var m = _monetization()
    return m.status() if m != null and m.has_method("status") else {}

func _premium_meta() -> String:
    var s = _premium_status()
    if bool(s.get("premium",false)): return "Premium active"
    return "Free • subscription available" if bool(s.get("subscriptions_enabled",false)) else "Free • premium optional"

func _rewarded_enabled() -> bool:
    return bool(_premium_status().get("rewarded_ads_enabled",false))

func _purchase_premium() -> void:
    var m = _monetization()
    if m != null and m.has_method("purchase_premium"): m.purchase_premium()

func _restore_premium() -> void:
    var m = _monetization()
    if m != null and m.has_method("restore_premium"): m.restore_premium()

func _open_rewards() -> void:
    _show_view("rewards")

func _build_mobile_rewards() -> void:
    var w = _content_width()
    _header("REWARDED OFFERS", "OPTIONAL • NO FORCED ADS")
    var inner_w = w - 36.0
    var intro = _panel(mobile_content, "RewardIntro", Rect2(18,82,inner_w,116), "surface", "border", 18)
    _label(intro, "Head", "YOUR CHOICE", Rect2(16,14,180,14), 10, "gold", 600)
    _label(intro, "Body", "Sponsored rewards are optional. Core restoration, production and expansion never require an ad.", Rect2(16,40,inner_w-32,58), 11, "text", 400)

    var monet = _monetization()
    var offers: Array[Dictionary] = []
    if monet != null and monet.has_method("available_rewarded_offers"):
        offers = monet.available_rewarded_offers()

    var y := 216.0
    for offer in offers:
        var reward_id := str(offer.get("id", ""))
        var card = _panel(mobile_content, "Reward_" + reward_id, Rect2(18,y,inner_w,146), "surface", "border", 18)
        _label(card, "Title", str(offer.get("title", "Reward")), Rect2(16,14,inner_w-132,20), 15, "text", 700)
        _label(card, "Body", str(offer.get("description", "")), Rect2(16,44,inner_w-32,50), 10, "muted", 400)
        var eligibility := {"ok": false, "reason": "Reward service unavailable."}
        if monet != null and monet.has_method("can_show_rewarded_offer"):
            eligibility = monet.can_show_rewarded_offer(reward_id)
        var available := bool(eligibility.get("ok", false))
        var button := _frame_button(card, "Claim_" + reward_id, "WATCH" if available else "UNAVAILABLE", Rect2(inner_w-124,96,108,48), _request_rewarded_offer.bind(reward_id), false, available, 9)
        button.disabled = not available
        var status_text := "Ready when you choose." if available else str(eligibility.get("reason", "Unavailable."))
        _label(card, "Status", status_text, Rect2(16,108,inner_w-150,28), 9, "success" if available else "muted", 400)
        y += 164.0

    if offers.is_empty():
        var empty = _panel(mobile_content, "NoRewards", Rect2(18,216,inner_w,112), "surface", "border", 18)
        _label(empty, "Body", "No rewarded offers are configured in this build.", Rect2(16,28,inner_w-32,54), 11, "muted", 400)

    _frame_button(mobile_content, "BackToSettings", "BACK TO SETTINGS", Rect2(18,minf(y + 8.0, 680.0),inner_w,52), _show_view.bind("settings"))

func _request_rewarded_offer(reward_id: String) -> void:
    var monet = _monetization()
    if monet == null or not monet.has_method("request_rewarded_offer"):
        return
    var result: Dictionary = monet.request_rewarded_offer(reward_id)
    var state = _game_state()
    if state != null and not bool(result.get("ok", false)):
        state.set_value("company", "message", str(result.get("reason", "Reward unavailable.")))
    _rebuild_current()

func _open_privacy() -> void:
    var m = _monetization()
    if m != null and m.has_method("privacy_policy_url"):
        var url = str(m.privacy_policy_url())
        if not url.is_empty(): OS.shell_open(url)

func _save_company() -> void:
    if parent != null and parent.has_method("save_game"): parent.save_game()
