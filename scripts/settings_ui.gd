extends CanvasLayer
## RESTORA player settings: appearance, audio, accessibility, purchases, privacy and data controls.

const UI_PREFS_PATH := "user://restora_ui.cfg"

var dimmer: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var feedback: Label
var premium_status: Label
var rewards_status: Label
var music_slider: HSlider
var sfx_slider: HSlider
var reduce_motion_toggle: CheckButton
var theme_buttons: Dictionary = {}
var visible_panel := false

func _ready() -> void:
    layer = 92
    _build_ui()
    _connect_services()
    _set_visible(false)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)
    _layout()

func _theme_manager():
    return get_node_or_null("/root/RestoraThemeManager")

func _monetization():
    return get_node_or_null("/root/RenewMonetizationSystem")

func _audio():
    return get_node_or_null("/root/RenewAudioManager")

func _main():
    return get_tree().root.get_node_or_null("Renew")

func _screen_manager():
    return get_node_or_null("/root/RenewUIScreenManager")

func _connect_services() -> void:
    var manager = _theme_manager()
    if manager != null and not manager.theme_changed.is_connected(_on_theme_changed):
        manager.theme_changed.connect(_on_theme_changed)
    var monetization = _monetization()
    if monetization != null:
        if not monetization.monetization_status_changed.is_connected(_refresh):
            monetization.monetization_status_changed.connect(_refresh)
        if not monetization.premium_changed.is_connected(_on_premium_changed):
            monetization.premium_changed.connect(_on_premium_changed)

func open_screen() -> void:
    _set_visible(true)
    _apply_theme()
    _load_preferences()
    _refresh()

func close_screen() -> void:
    _set_visible(false)

func _set_visible(value: bool) -> void:
    visible_panel = value
    if is_instance_valid(dimmer):
        dimmer.visible = value
    if is_instance_valid(panel):
        panel.visible = value

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "SettingsModalScrim"
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = PanelContainer.new()
    panel.name = "SettingsCommandPanel"
    add_child(panel)

    var outer := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        outer.add_theme_constant_override("margin_" + side, 16)
    panel.add_child(outer)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    outer.add_child(root)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    root.add_child(header)

    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_stack)
    var title := Label.new()
    title.text = "SETTINGS"
    title.add_theme_font_size_override("font_size", 22)
    title_stack.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "APPEARANCE • AUDIO • PREMIUM • DATA"
    subtitle.name = "MutedText"
    subtitle.add_theme_font_size_override("font_size", 9)
    title_stack.add_child(subtitle)

    var close := _button("CLOSE", close_screen)
    close.custom_minimum_size.x = 88
    header.add_child(close)

    var scroll := ScrollContainer.new()
    scroll.name = "SettingsScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    content = VBoxContainer.new()
    content.name = "SettingsContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 10)
    scroll.add_child(content)

    _build_appearance()
    _build_audio_accessibility()
    _build_premium()
    _build_data_privacy()

    feedback = Label.new()
    feedback.name = "MutedText"
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback.custom_minimum_size.y = 34
    content.add_child(feedback)

func _section(title: String) -> VBoxContainer:
    var card := PanelContainer.new()
    card.name = title.to_pascal_case() + "Section"
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(card)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 14)
    card.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)
    var heading := Label.new()
    heading.text = title.to_upper()
    heading.name = "SectionHeading"
    heading.add_theme_font_size_override("font_size", 10)
    box.add_child(heading)
    return box

func _build_appearance() -> void:
    var box := _section("Appearance")
    var help := Label.new()
    help.text = "Choose one theme for every RESTORA command screen."
    help.name = "MutedText"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(help)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    box.add_child(row)
    for mode_value in ["dark", "light", "system"]:
        var mode: String = str(mode_value)
        var label: String = "DEVICE" if mode == "system" else mode.to_upper()
        var button := _button(label, _set_theme.bind(mode))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size.y = 48
        row.add_child(button)
        theme_buttons[mode] = button

func _build_audio_accessibility() -> void:
    var box := _section("Audio & accessibility")

    var music_label := Label.new()
    music_label.text = "MUSIC"
    box.add_child(music_label)
    music_slider = HSlider.new()
    music_slider.min_value = 0.0
    music_slider.max_value = 1.0
    music_slider.step = 0.01
    music_slider.custom_minimum_size = Vector2(0, 44)
    music_slider.value_changed.connect(_on_music_changed)
    box.add_child(music_slider)

    var sfx_label := Label.new()
    sfx_label.text = "SOUND EFFECTS"
    box.add_child(sfx_label)
    sfx_slider = HSlider.new()
    sfx_slider.min_value = 0.0
    sfx_slider.max_value = 1.0
    sfx_slider.step = 0.01
    sfx_slider.custom_minimum_size = Vector2(0, 44)
    sfx_slider.value_changed.connect(_on_sfx_changed)
    box.add_child(sfx_slider)

    reduce_motion_toggle = CheckButton.new()
    reduce_motion_toggle.text = "REDUCE MOTION"
    reduce_motion_toggle.custom_minimum_size.y = 46
    reduce_motion_toggle.tooltip_text = "Minimize screen and button movement while keeping gameplay feedback."
    reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
    box.add_child(reduce_motion_toggle)

func _build_premium() -> void:
    var box := _section("Premium & rewards")
    premium_status = Label.new()
    premium_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(premium_status)

    var purchase_row := HBoxContainer.new()
    purchase_row.add_theme_constant_override("separation", 8)
    box.add_child(purchase_row)
    var purchase := _button("VIEW PREMIUM", _purchase_premium)
    purchase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    purchase_row.add_child(purchase)
    var restore := _button("RESTORE PURCHASES", _restore_premium)
    restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    purchase_row.add_child(restore)

    rewards_status = Label.new()
    rewards_status.name = "MutedText"
    rewards_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(rewards_status)

    var rewards := _button("OPTIONAL REWARDS", _open_rewards)
    box.add_child(rewards)

func _build_data_privacy() -> void:
    var box := _section("Save, data & privacy")
    var save_row := HBoxContainer.new()
    save_row.add_theme_constant_override("separation", 8)
    box.add_child(save_row)
    var save := _button("SAVE COMPANY", _save_company)
    save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    save_row.add_child(save)
    var load := _button("LOAD COMPANY", _load_company)
    load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    save_row.add_child(load)

    var advanced := _button("DYNASTY & ADVANCED SAVE", _open_company_control)
    box.add_child(advanced)
    var privacy := _button("PRIVACY POLICY", _open_privacy)
    box.add_child(privacy)

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 46)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    return button

func _apply_theme() -> void:
    var manager = _theme_manager()
    if manager == null:
        return
    if panel != null:
        panel.theme = manager.get_theme_resource()
    if dimmer != null:
        dimmer.color = manager.color("scrim")
    if content != null:
        for node in content.find_children("*", "Label", true, false):
            var label := node as Label
            if label.name == "SectionHeading":
                label.add_theme_color_override("font_color", manager.color("gold"))
            elif label.name == "MutedText":
                label.add_theme_color_override("font_color", manager.color("muted"))
            else:
                label.add_theme_color_override("font_color", manager.color("text"))
    _refresh_theme_buttons()

func _refresh_theme_buttons() -> void:
    var manager = _theme_manager()
    if manager == null:
        return
    var current := str(manager.get_mode())
    for mode in theme_buttons:
        var button: Button = theme_buttons[mode]
        var selected := str(mode) == current
        button.text = ("DEVICE" if mode == "system" else str(mode).to_upper()) + ("  ✓" if selected else "")
        var normal := StyleBoxFlat.new()
        normal.bg_color = manager.color("selected") if selected else manager.color("surface_2")
        normal.border_color = manager.color("plum") if selected else manager.color("border")
        normal.set_border_width_all(1)
        normal.set_corner_radius_all(12)
        button.add_theme_stylebox_override("normal", normal)
        button.add_theme_color_override("font_color", manager.color("plum") if selected else manager.color("text"))

func _load_preferences() -> void:
    var audio = _audio()
    if music_slider != null:
        music_slider.set_value_no_signal(float(audio.get_music_level()) if audio != null and audio.has_method("get_music_level") else 0.72)
    if sfx_slider != null:
        sfx_slider.set_value_no_signal(float(audio.get_sfx_level()) if audio != null and audio.has_method("get_sfx_level") else 0.84)
    var reduced := bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false))
    var file := ConfigFile.new()
    if file.load(UI_PREFS_PATH) == OK:
        reduced = bool(file.get_value("accessibility", "reduce_motion", reduced))
    ProjectSettings.set_setting("renew/ui/reduce_motion", reduced)
    reduce_motion_toggle.set_pressed_no_signal(reduced)

func _save_reduce_motion() -> void:
    var file := ConfigFile.new()
    file.load(UI_PREFS_PATH)
    file.set_value("accessibility", "reduce_motion", bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false)))
    file.save(UI_PREFS_PATH)

func _refresh() -> void:
    var monetization = _monetization()
    if monetization == null:
        premium_status.text = "Premium services are unavailable."
        rewards_status.text = "Sponsored rewards are unavailable."
        return
    var status: Dictionary = monetization.status()
    if bool(status.get("premium", false)):
        premium_status.text = "PREMIUM ACTIVE • Verified through %s" % str(status.get("premium_source", "Google Play")).replace("_", " ").capitalize()
    elif bool(status.get("subscriptions_enabled", false)):
        premium_status.text = "FREE PLAN • Premium subscription available."
    else:
        premium_status.text = "FREE PLAN • Premium subscription is not configured in this build."
    if bool(status.get("rewarded_ads_enabled", false)):
        rewards_status.text = "Optional Sponsor Grant + Market Research rewards • maximum 2 per real day • NO FORCED ADS."
    else:
        rewards_status.text = "Optional sponsored rewards are disabled in this build • NO FORCED ADS."
    _refresh_theme_buttons()

func _set_theme(mode: String) -> void:
    var manager = _theme_manager()
    if manager != null:
        manager.set_mode(mode)

func _on_theme_changed(_mode: String) -> void:
    _apply_theme()
    feedback.text = "Theme updated across RESTORA."

func _on_music_changed(value: float) -> void:
    var audio = _audio()
    if audio != null and audio.has_method("set_music_level"):
        audio.set_music_level(value)

func _on_sfx_changed(value: float) -> void:
    var audio = _audio()
    if audio != null and audio.has_method("set_sfx_level"):
        audio.set_sfx_level(value)

func _on_reduce_motion_toggled(value: bool) -> void:
    ProjectSettings.set_setting("renew/ui/reduce_motion", value)
    _save_reduce_motion()
    feedback.text = "Reduced motion enabled." if value else "Full premium motion enabled."

func _purchase_premium() -> void:
    var monetization = _monetization()
    if monetization == null:
        feedback.text = "Premium service is unavailable."
        return
    var result: Dictionary = monetization.purchase_premium()
    feedback.text = str(result.get("message", "Opening Google Play purchase flow…"))

func _restore_premium() -> void:
    var monetization = _monetization()
    if monetization == null:
        feedback.text = "Premium service is unavailable."
        return
    var result: Dictionary = monetization.restore_premium()
    feedback.text = str(result.get("message", "Checking Google Play purchases…"))

func _open_rewards() -> void:
    var manager = _screen_manager()
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen("LiveOpsPanel")

func _open_privacy() -> void:
    var monetization = _monetization()
    var url: String = ""
    if monetization != null and monetization.has_method("privacy_policy_url"):
        url = str(monetization.privacy_policy_url())
    if url.is_empty():
        feedback.text = "Privacy policy URL is not configured."
        return
    OS.shell_open(url)

func _save_company() -> void:
    var game = _main()
    if game != null and game.has_method("save_game"):
        game.save_game()
        feedback.text = str(game.get("message")) if str(game.get("message")) != "" else "Company saved."

func _load_company() -> void:
    var game = _main()
    if game != null and game.has_method("load_game"):
        game.load_game()
        feedback.text = str(game.get("message")) if str(game.get("message")) != "" else "Company loaded."

func _open_company_control() -> void:
    var manager = _screen_manager()
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen("SaveLoadPanel")

func _on_premium_changed(_active: bool) -> void:
    _refresh()

func _layout() -> void:
    if panel == null or get_viewport() == null:
        return
    var size := get_viewport().get_visible_rect().size
    dimmer.position = Vector2.ZERO
    dimmer.size = size
    var phone := size.x < 520.0
    var width := minf(720.0, maxf(304.0, size.x - (16.0 if phone else 36.0)))
    var height := minf(760.0, maxf(430.0, size.y - 80.0))
    panel.position = Vector2((size.x - width) * 0.5, maxf(36.0, (size.y - height) * 0.5))
    panel.size = Vector2(width, minf(height, size.y - panel.position.y - 8.0))
    if content != null:
        content.custom_minimum_size.x = maxf(260.0, width - 54.0)

func _unhandled_input(event: InputEvent) -> void:
    if not visible_panel:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        close_screen()
        get_viewport().set_input_as_handled()
