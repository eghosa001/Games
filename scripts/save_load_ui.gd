extends CanvasLayer

## Dedicated persistence command surface. Gameplay state remains authoritative on Main/SaveSystem.
const SURFACE := Color("0b1b22")
const SURFACE_2 := Color("102a31")
const BORDER := Color("31565d")
const TEXT := Color("edf6f3")
const MUTED := Color("8da7aa")
const ACCENT := Color("d8b76d")
const SCRIM := Color(0.02, 0.08, 0.10, 0.82)

var dimmer: ColorRect
var panel: PanelContainer
var status: Label
var warning: Label
var save_button: Button
var load_button: Button
var new_button: Button
var confirm_button: Button
var cancel_button: Button
var visible_panel := false
var confirm_new := false
var parent: Node

func _ready() -> void:
    layer = 91
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    _set_visible(false)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)
    _layout()

func open_screen() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    confirm_new = false
    _set_visible(true)
    _refresh()

func close_screen() -> void:
    confirm_new = false
    _set_visible(false)

func _set_visible(value: bool) -> void:
    visible_panel = value
    if is_instance_valid(dimmer): dimmer.visible = value
    if is_instance_valid(panel): panel.visible = value

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    return s

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "PersistenceModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = PanelContainer.new()
    panel.name = "SaveLoadCommandPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE))
    add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
    panel.add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    margin.add_child(root)

    var header := HBoxContainer.new()
    root.add_child(header)
    var title := Label.new()
    title.text = "COMPANY CONTROL"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", TEXT)
    header.add_child(title)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close := Button.new()
    close.name = "CloseButton"
    close.text = "CLOSE"
    close.custom_minimum_size = Vector2(82, 46)
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(close_screen)
    header.add_child(close)

    var subtitle := Label.new()
    subtitle.text = "PERSISTENCE & DYNASTY MANAGEMENT"
    subtitle.add_theme_font_size_override("font_size", 9)
    subtitle.add_theme_color_override("font_color", ACCENT)
    root.add_child(subtitle)

    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size.y = 42
    status.add_theme_font_size_override("font_size", 11)
    status.add_theme_color_override("font_color", MUTED)
    root.add_child(status)

    save_button = _button("SAVE COMPANY", _save)
    load_button = _button("LOAD COMPANY", _load)
    new_button = _button("START NEW DYNASTY", _request_new)
    root.add_child(save_button); root.add_child(load_button); root.add_child(new_button)

    warning = Label.new()
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.add_theme_font_size_override("font_size", 10)
    warning.add_theme_color_override("font_color", ACCENT)
    warning.visible = false
    root.add_child(warning)

    var confirm_row := HBoxContainer.new()
    confirm_row.name = "ConfirmRow"
    confirm_row.add_theme_constant_override("separation", 8)
    root.add_child(confirm_row)
    confirm_button = _button("CONFIRM NEW DYNASTY", _confirm_new)
    cancel_button = _button("CANCEL", _cancel_new)
    confirm_row.add_child(confirm_button); confirm_row.add_child(cancel_button)
    confirm_row.visible = false

func _button(text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 46)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 10)
    b.add_theme_stylebox_override("normal", _style(SURFACE_2))
    b.add_theme_stylebox_override("hover", _style(Color("18363a"), ACCENT))
    b.add_theme_stylebox_override("pressed", _style(Color("18363a"), ACCENT))
    b.pressed.connect(callback)
    return b

func _refresh() -> void:
    if parent == null:
        status.text = "GAME SESSION UNAVAILABLE."
        save_button.disabled = true
        load_button.disabled = true
        new_button.disabled = true
        return
    save_button.disabled = false
    load_button.disabled = false
    var victory := get_node_or_null("/root/RenewVictorySystem")
    var can_start: bool = victory != null and victory.has_method("stored_victory") and not victory.stored_victory().is_empty()
    new_button.disabled = not can_start
    if can_start:
        status.text = "Company data is ready. Save or restore the current campaign, or begin a new dynasty using your earned legacy bonuses."
    else:
        status.text = "Company data is ready. Save or restore the current campaign. A new dynasty unlocks after a campaign victory."
    if confirm_new:
        warning.text = "STARTING A NEW DYNASTY RESETS THE CURRENT CAMPAIGN. Your earned legacy bonuses are retained. Confirm only if you intend to leave this company."
        warning.visible = true
        confirm_button.get_parent().visible = true
    else:
        warning.visible = false
        confirm_button.get_parent().visible = false

func _message(default_text: String) -> void:
    if parent != null and str(parent.get("message")) != "":
        status.text = str(parent.get("message"))
    else:
        status.text = default_text

func _save() -> void:
    if parent == null or not parent.has_method("save_game"): return
    parent.save_game()
    _message("Company saved successfully.")

func _load() -> void:
    if parent == null or not parent.has_method("load_game"): return
    parent.load_game()
    _message("Company loaded successfully.")

func _request_new() -> void:
    confirm_new = true
    _refresh()

func _confirm_new() -> void:
    if parent == null or not parent.has_method("found_new_company"): return
    parent.found_new_company()
    confirm_new = false
    var result_message := str(parent.get("message"))
    _refresh()
    if result_message.is_empty():
        result_message = "NEW DYNASTY COMMAND COMPLETED."
    status.text = result_message

func _cancel_new() -> void:
    confirm_new = false
    _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if not visible_panel: return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        close_screen()
        get_viewport().set_input_as_handled()

func _layout() -> void:
    if not is_instance_valid(panel) or get_viewport() == null: return
    var size := get_viewport().get_visible_rect().size
    dimmer.position = Vector2.ZERO
    dimmer.size = size
    var phone := size.x < 430.0
    var w := minf(560.0, maxf(288.0, size.x - (16.0 if phone else 32.0)))
    var h := minf(500.0, maxf(360.0, size.y - 72.0))
    panel.position = Vector2((size.x - w) / 2.0, (size.y - h) / 2.0)
    panel.size = Vector2(w, h)
    save_button.custom_minimum_size.y = 46
    load_button.custom_minimum_size.y = 46
    new_button.custom_minimum_size.y = 46
    confirm_button.custom_minimum_size.y = 46
    cancel_button.custom_minimum_size.y = 46
