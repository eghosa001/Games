extends CanvasLayer

const Tutorial = preload("res://scripts/tutorial.gd")

const UPDATE_INTERVAL: float = 0.10
var game: Node
var tutorial = Tutorial.new()
var overlay_root: Control
var panel: Panel
var title_label: Label
var body_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var hint_label: Label
var continue_button: Button
var collapsed_button: Button
var dismissed := false
var last_step := -1
var _update_clock: float = 0.0
var _coordinator_active := false
var _expanded_by_user := false

func _state():
    return get_node_or_null("/root/RenewGameState")

func _theme_manager():
    return get_node_or_null("/root/RestoraThemeManager")

func _coordinator() -> Node:
    var services = get_node_or_null("/root/RenewServices")
    if services != null and services.has_method("get_service"):
        return services.get_service("RenewUIRegionCoordinator")
    return null

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    _load_tutorial_state()
    _build()
    _apply_theme()
    var manager = _theme_manager()
    if manager != null and manager.has_signal("theme_changed") and not manager.theme_changed.is_connected(_on_theme_changed):
        manager.theme_changed.connect(_on_theme_changed)
    overlay_root.resized.connect(_layout_responsive)
    _refresh()
    _layout_responsive()

func _enter_tree() -> void:
    var coordinator = _coordinator()
    if coordinator != null:
        coordinator.set_active_screen("")

func _process(delta: float) -> void:
    if game == null:
        return

    _update_clock += delta
    if _update_clock < UPDATE_INTERVAL:
        return
    _update_clock = fmod(_update_clock, UPDATE_INTERVAL)

    var current_action := String(tutorial.current().get("action", "COMPLETE"))
    if not tutorial.completed and current_action != "COMPLETE":
        var old_step := int(tutorial.step)
        tutorial.notify(current_action, game)
        if int(tutorial.step) != old_step:
            _save_tutorial_state()
            game.message = "TUTORIAL: %s" % String(tutorial.current().get("title", "Next step"))
            _refresh()
            return

    _layout_responsive()

func _build() -> void:
    overlay_root = Control.new()
    overlay_root.name = "TutorialOverlayRoot"
    overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay_root)

    panel = Panel.new()
    panel.name = "TutorialCard"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay_root.add_child(panel)

    title_label = Label.new()
    title_label.name = "TutorialTitle"
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_label.add_theme_font_size_override("font_size", 16)
    panel.add_child(title_label)

    progress_label = Label.new()
    progress_label.name = "TutorialProgress"
    progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_label.add_theme_font_size_override("font_size", 10)
    panel.add_child(progress_label)

    progress_bar = ProgressBar.new()
    progress_bar.name = "TutorialProgressBar"
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    progress_bar.value = 0.0
    progress_bar.show_percentage = false
    progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(progress_bar)

    body_label = Label.new()
    body_label.name = "TutorialBody"
    body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.add_theme_font_size_override("font_size", 12)
    panel.add_child(body_label)

    hint_label = Label.new()
    hint_label.name = "TutorialHint"
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_label.add_theme_font_size_override("font_size", 10)
    panel.add_child(hint_label)

    continue_button = Button.new()
    continue_button.name = "TutorialHideButton"
    continue_button.text = "GOT IT"
    continue_button.custom_minimum_size = Vector2(96, 48)
    continue_button.focus_mode = Control.FOCUS_ALL
    continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
    continue_button.pressed.connect(_hide_overlay)
    panel.add_child(continue_button)

    collapsed_button = Button.new()
    collapsed_button.name = "TutorialGuideChip"
    collapsed_button.text = "GUIDE"
    collapsed_button.custom_minimum_size = Vector2(104, 48)
    collapsed_button.focus_mode = Control.FOCUS_ALL
    collapsed_button.mouse_filter = Control.MOUSE_FILTER_STOP
    collapsed_button.pressed.connect(open_tutorial)
    collapsed_button.hide()
    overlay_root.add_child(collapsed_button)

func _apply_theme() -> void:
    if panel == null:
        return
    var manager = _theme_manager()
    var bg := Color("151a1f")
    var border := Color("3c3831")
    var text := Color("f2efe8")
    var muted := Color("928a80")
    var gold := Color("c99a4b")
    var plum := Color("7a405f")
    var raised := Color("20262c")
    if manager != null and manager.has_method("color"):
        bg = manager.color("surface")
        border = manager.color("border")
        text = manager.color("text")
        muted = manager.color("muted")
        gold = manager.color("gold")
        plum = manager.color("plum")
        raised = manager.color("surface_2")

    var tutorial_style := StyleBoxFlat.new()
    tutorial_style.bg_color = Color(bg.r, bg.g, bg.b, 0.98)
    tutorial_style.border_color = gold
    tutorial_style.set_border_width_all(1)
    tutorial_style.set_border_width(SIDE_TOP, 3)
    tutorial_style.set_corner_radius_all(18)
    tutorial_style.shadow_color = Color(0, 0, 0, 0.34)
    tutorial_style.shadow_size = 14
    tutorial_style.shadow_offset = Vector2(0, 6)
    panel.add_theme_stylebox_override("panel", tutorial_style)

    var progress_bg := StyleBoxFlat.new()
    progress_bg.bg_color = raised
    progress_bg.set_corner_radius_all(5)
    var progress_fill := StyleBoxFlat.new()
    progress_fill.bg_color = gold
    progress_fill.set_corner_radius_all(5)
    progress_bar.add_theme_stylebox_override("background", progress_bg)
    progress_bar.add_theme_stylebox_override("fill", progress_fill)

    title_label.add_theme_color_override("font_color", text)
    progress_label.add_theme_color_override("font_color", gold)
    body_label.add_theme_color_override("font_color", text)
    hint_label.add_theme_color_override("font_color", muted)

    var button_style := StyleBoxFlat.new()
    button_style.bg_color = raised
    button_style.border_color = plum
    button_style.set_border_width_all(1)
    button_style.set_corner_radius_all(12)
    continue_button.add_theme_stylebox_override("normal", button_style)
    continue_button.add_theme_stylebox_override("hover", button_style)
    continue_button.add_theme_color_override("font_color", text)

    var chip_style := StyleBoxFlat.new()
    chip_style.bg_color = raised
    chip_style.border_color = gold
    chip_style.set_border_width_all(1)
    chip_style.set_corner_radius_all(18)
    collapsed_button.add_theme_stylebox_override("normal", chip_style)
    collapsed_button.add_theme_stylebox_override("hover", chip_style)
    collapsed_button.add_theme_color_override("font_color", gold)

func _on_theme_changed(_mode: String) -> void:
    _apply_theme()

func _main_hud_view() -> String:
    var hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if hud != null:
        return str(hud.get("active_view"))
    return "live"

func _compact_guide_allowed() -> bool:
    return _main_hud_view() in ["live", "property", "operate"]

func _layout_responsive() -> void:
    if overlay_root == null or panel == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    if w <= 1.0 or h <= 1.0:
        return
    var narrow := w < 700.0
    var coordinator = _coordinator()
    if coordinator != null and coordinator.has_method("get_active_screen") and str(coordinator.get_active_screen()) != "":
        panel.hide()
        collapsed_button.hide()
        return
    if _coordinator_active:
        panel.hide()
        collapsed_button.hide()
        return

    var compact_by_default := not _expanded_by_user
    if dismissed or compact_by_default:
        panel.hide()
        if tutorial.completed:
            collapsed_button.hide()
            return
        collapsed_button.text = "GUIDE  %d/%d" % [mini(int(tutorial.step) + 1, tutorial.steps.size()), tutorial.steps.size()]
        if narrow:
            if not _compact_guide_allowed():
                collapsed_button.hide()
                return
            collapsed_button.size = Vector2(104.0, 48.0)
            collapsed_button.position = Vector2(maxf(8.0, w - 116.0), maxf(8.0, h - 154.0))
        elif w >= 1000.0:
            collapsed_button.size = Vector2(112.0, 44.0)
            collapsed_button.position = Vector2(maxf(8.0, w - 128.0), 24.0)
        else:
            collapsed_button.size = Vector2(112.0, 48.0)
            collapsed_button.position = Vector2(maxf(8.0, w - 126.0), maxf(64.0, h - 120.0))
        collapsed_button.show()
        return

    if narrow:
        var panel_y := 92.0 if h >= 640.0 else 74.0
        panel.position = Vector2(8.0, panel_y)
        panel.size = Vector2(w - 16.0, 142.0)
        var content_width := panel.size.x - 28.0
        title_label.position = Vector2(14, 10)
        title_label.size = Vector2(maxf(120.0, panel.size.x - 128.0), 24)
        title_label.add_theme_font_size_override("font_size", 15)
        progress_label.position = Vector2(14, 34)
        progress_label.size = Vector2(content_width, 16)
        progress_bar.position = Vector2(14, 52)
        progress_bar.size = Vector2(content_width, 6)
        body_label.position = Vector2(14, 66)
        body_label.size = Vector2(content_width, 62)
        body_label.add_theme_font_size_override("font_size", 11)
        hint_label.hide()
        continue_button.position = Vector2(panel.size.x - 108.0, 8)
        continue_button.size = Vector2(94, 48)
    elif w >= 1000.0:
        panel.position = Vector2(w - 445.0, 116.0)
        panel.size = Vector2(430.0, 136.0)
        title_label.position = Vector2(18, 12)
        title_label.size = Vector2(panel.size.x - 140.0, 24)
        progress_label.position = Vector2(18, 38)
        progress_label.size = Vector2(panel.size.x - 36.0, 18)
        progress_bar.position = Vector2(18, 58)
        progress_bar.size = Vector2(panel.size.x - 36.0, 6)
        body_label.position = Vector2(18, 72)
        body_label.size = Vector2(panel.size.x - 36.0, 48)
        hint_label.hide()
        continue_button.position = Vector2(panel.size.x - 116.0, 12)
        continue_button.size = Vector2(98, 48)
    else:
        panel.position = Vector2(w - 430.0, 104.0)
        panel.size = Vector2(414.0, 136.0)
        title_label.position = Vector2(18, 12)
        title_label.size = Vector2(panel.size.x - 140.0, 24)
        progress_label.position = Vector2(18, 38)
        progress_label.size = Vector2(panel.size.x - 36.0, 18)
        progress_bar.position = Vector2(18, 58)
        progress_bar.size = Vector2(panel.size.x - 36.0, 6)
        body_label.position = Vector2(18, 72)
        body_label.size = Vector2(panel.size.x - 36.0, 48)
        hint_label.hide()
        continue_button.position = Vector2(panel.size.x - 116.0, 12)
        continue_button.size = Vector2(98, 48)

    collapsed_button.hide()
    panel.show()

func _refresh() -> void:
    if game == null:
        return
    var current: Dictionary = tutorial.current()
    var step := int(tutorial.step)
    last_step = step
    title_label.text = String(current.get("title", "RESTORA TUTORIAL"))
    var total_steps := maxi(1, tutorial.steps.size())
    progress_label.text = "PHASE A  •  STEP %d/%d" % [mini(step + 1, total_steps), total_steps]
    progress_bar.value = clampf(float(mini(step + 1, total_steps)) / float(total_steps), 0.0, 1.0)
    body_label.text = String(current.get("text", "Keep building."))
    hint_label.text = "Goal: " + String(current.get("action", "COMPLETE"))
    continue_button.text = "HIDE"
    if tutorial.completed:
        title_label.text = "FIRST BUSINESS COMPLETE"
        progress_label.text = "PHASE A  •  COMPLETE"
        progress_bar.value = 1.0
        body_label.text = String(current.get("text", "Keep building and expand the company."))
    _layout_responsive()

func _load_tutorial_state() -> void:
    var state = _state()
    if state == null:
        dismissed = false
        return
    tutorial.load_snapshot({
        "step": int(state.get_value("progression", "tutorial_step", 0)),
        "completed": bool(state.get_value("progression", "tutorial_completed", false))
    })
    dismissed = bool(state.get_value("progression", "tutorial_dismissed", false))
    if tutorial.completed:
        dismissed = true

func _save_tutorial_state() -> void:
    var state = _state()
    if state == null:
        return
    state.set_value("progression", "tutorial_step", int(tutorial.step))
    state.set_value("progression", "tutorial_completed", bool(tutorial.completed))
    state.set_value("progression", "tutorial_dismissed", dismissed)

func open_tutorial() -> void:
    dismissed = false
    _expanded_by_user = true
    _save_tutorial_state()
    _refresh()

func hide_tutorial() -> void:
    _hide_overlay()

func tutorial_status() -> Dictionary:
    return {
        "step": int(tutorial.step),
        "total": int(tutorial.steps.size()),
        "completed": bool(tutorial.completed),
        "dismissed": dismissed,
        "current": tutorial.current().duplicate(true)
    }

func reset_tutorial() -> void:
    tutorial.step = 0
    tutorial.completed = false
    dismissed = false
    _expanded_by_user = false
    _save_tutorial_state()
    _refresh()

func _dismiss_current() -> void:
    _hide_overlay()

func _hide_overlay() -> void:
    dismissed = true
    _expanded_by_user = false
    _save_tutorial_state()
    panel.hide()
    _layout_responsive()

func _collapse() -> void:
    _hide_overlay()

func _expand() -> void:
    open_tutorial()

func _should_show() -> bool:
    return not dismissed and not tutorial.completed

func _get_rect() -> Rect2:
    if panel == null:
        return Rect2()
    return panel.get_global_rect()

func _set_coordinator_active(value: bool) -> void:
    _coordinator_active = value

func _on_screen_changed(open: bool) -> void:
    if open:
        panel.hide()
        collapsed_button.hide()
    elif not _coordinator_active:
        _layout_responsive()
