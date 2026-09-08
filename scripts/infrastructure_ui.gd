extends Control

const DomainSystem = preload("res://scripts/domain_system.gd")

const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const STATUS_GREEN := Color("5fe08a")
const STATUS_WARN := Color("ffad8f")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

var parent
var system
var state_adapter = DomainSystem.new()
var message: String = ""
var selected_type: int = 0
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var summary_label: Label
var metrics_label: Label
var close_button: Button
var type_button: Button
var build_button: Button
var upgrade_button: Button
var repair_button: Button
var scroll: ScrollContainer
var list: VBoxContainer
var refresh_clock := 0.0
var last_signature := ""

func _ready() -> void:
    system = get_node_or_null("/root/RenewInfrastructureSystem")
    parent = get_tree().current_scene
    add_child(state_adapter)
    z_index = 57
    _build_ui()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "InfrastructureModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "InfrastructureCommandPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE))
    add_child(panel)

    title_label = Label.new()
    title_label.text = "INFRASTRUCTURE COMMAND"
    title_label.add_theme_color_override("font_color", TEXT)
    panel.add_child(title_label)

    status_label = Label.new()
    status_label.text = "PHYSICAL NETWORK"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_color_override("font_color", ACCENT)
    panel.add_child(status_label)

    close_button = Button.new()
    close_button.name = "CloseButton"
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(80, 46)
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(_close)
    panel.add_child(close_button)

    summary_label = Label.new()
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary_label.add_theme_color_override("font_color", MUTED)
    panel.add_child(summary_label)

    metrics_label = Label.new()
    metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    metrics_label.add_theme_color_override("font_color", TEXT)
    panel.add_child(metrics_label)

    type_button = Button.new()
    type_button.text = "CHANGE TYPE"
    type_button.custom_minimum_size = Vector2(0, 46)
    type_button.focus_mode = Control.FOCUS_NONE
    type_button.pressed.connect(cycle_type)
    panel.add_child(type_button)

    build_button = Button.new()
    build_button.text = "BUILD"
    build_button.custom_minimum_size = Vector2(0, 46)
    build_button.focus_mode = Control.FOCUS_NONE
    build_button.pressed.connect(build_selected)
    panel.add_child(build_button)

    upgrade_button = Button.new()
    upgrade_button.text = "UPGRADE"
    upgrade_button.custom_minimum_size = Vector2(0, 46)
    upgrade_button.focus_mode = Control.FOCUS_NONE
    upgrade_button.pressed.connect(_upgrade_selected)
    panel.add_child(upgrade_button)

    repair_button = Button.new()
    repair_button.text = "REPAIR"
    repair_button.custom_minimum_size = Vector2(0, 46)
    repair_button.focus_mode = Control.FOCUS_NONE
    repair_button.pressed.connect(repair_damaged)
    panel.add_child(repair_button)

    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)
    list = VBoxContainer.new()
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    return s

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        visible = false

func _process(delta: float) -> void:
    if parent == null: parent = get_tree().current_scene
    if system == null: system = get_node_or_null("/root/RenewInfrastructureSystem")
    if not visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh()

func _parent():
    if parent != null: return parent
    var scene = get_tree().current_scene if get_tree() != null else null
    if scene != null:
        parent = scene
        return parent
    var root_node = get_tree().root if get_tree() != null else null
    if root_node != null: parent = root_node.get_node_or_null("Renew")
    return parent

func _region_controller():
    var game: Node = _parent()
    return game.get_node_or_null("World/RegionController") if game != null else null

func _region_index() -> int:
    var regions = _region_controller()
    if regions != null and regions.get("regions") != null:
        return int(regions.regions.selected)
    return 0

func _region_name() -> String:
    var regions = _region_controller()
    if regions != null and regions.get("regions") != null:
        return str(regions.regions.current().get("name", "Region 1"))
    return "Region 1"

func build_selected() -> void:
    var game: Node = _parent()
    if game == null or system == null:
        message = "Infrastructure system is unavailable."
        _refresh()
        return
    var ownership_snapshot := _capture_ownership_state()
    var result = system.build(system.TYPES[selected_type], _region_index(), "founder", int(game.cash), int(game.day))
    message = str(result.get("message", "Construction request completed."))
    if bool(result.get("ok", false)) and not _spend_result(result, "infrastructure construction"):
        var asset_id := str(result.get("id", ""))
        if asset_id != "": system.assets.erase(asset_id)
        _restore_ownership_state(ownership_snapshot)
        message = "Construction payment failed; the site was cancelled."
    last_signature = ""
    _refresh()

func _upgrade_selected() -> void:
    var game: Node = _parent()
    if game == null or system == null:
        message = "Infrastructure system is unavailable."
        return
    var target := _first_asset(system.ACTIVE)
    if target == "":
        message = "No active infrastructure to upgrade in this region."
        _refresh()
        return
    var before = system.assets.get(target, {}).duplicate(true)
    var result = system.upgrade(target, "founder", int(game.cash), int(game.day))
    message = str(result.get("message", "Upgrade request completed."))
    if bool(result.get("ok", false)) and not _spend_result(result, "infrastructure upgrade"):
        system.assets[target] = before
        message = "Upgrade payment failed."
    last_signature = ""
    _refresh()

func cycle_type() -> void:
    if system == null or system.TYPES.is_empty(): return
    selected_type = (selected_type + 1) % system.TYPES.size()
    message = "Selected %s." % _type_name()
    _refresh()

func repair_damaged() -> void:
    var game: Node = _parent()
    if game == null or system == null:
        message = "Infrastructure system is unavailable."
        return
    var target := _first_asset(system.DISRUPTED)
    if target == "":
        message = "No disrupted infrastructure to repair in this region."
        _refresh()
        return
    var before = system.assets.get(target, {}).duplicate(true)
    var result = system.repair(target, "founder", int(game.cash), int(game.day))
    message = str(result.get("message", "Repair request completed."))
    if bool(result.get("ok", false)) and not _spend_result(result, "infrastructure repair"):
        system.assets[target] = before
        message = "Repair payment failed."
    last_signature = ""
    _refresh()

func _first_asset(status: String) -> String:
    if system == null: return ""
    for asset in system.list_region(_region_index()):
        if str(asset.get("status", "")) == status: return str(asset.get("id", ""))
    return ""

func _type_name() -> String:
    if system == null or system.TYPES.is_empty(): return "Infrastructure"
    return str(system.TYPES[selected_type]).replace("_", " ").capitalize()

func _spend_result(result: Dictionary, reason: String) -> bool:
    if not bool(result.get("ok", false)): return false
    var spend = state_adapter.spend(int(result.get("cost", 0)), reason)
    if bool(spend.get("ok", false)): return true
    message = str(spend.get("message", "Payment failed."))
    return false

func _capture_ownership_state() -> Dictionary:
    var ownership = get_node_or_null("/root/RenewOwnershipSystem")
    if ownership == null:
        var scene = get_tree().current_scene if get_tree() != null else null
        if scene != null:
            ownership = scene.get_node_or_null("Systems/OwnershipSystem")
            if ownership == null: ownership = scene.get_node_or_null("OwnershipSystem")
    if ownership != null and ownership.has_method("capture_state"): return ownership.capture_state()
    if ownership != null and ownership.has_method("save_state"): return ownership.save_state()
    return {}

func _restore_ownership_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    var ownership = get_node_or_null("/root/RenewOwnershipSystem")
    if ownership == null:
        var scene = get_tree().current_scene if get_tree() != null else null
        if scene != null:
            ownership = scene.get_node_or_null("Systems/OwnershipSystem")
            if ownership == null: ownership = scene.get_node_or_null("OwnershipSystem")
    if ownership == null: return
    if ownership.has_method("restore_state"): ownership.restore_state(snapshot)
    elif ownership.has_method("load_state"): ownership.load_state(snapshot)

func _refresh() -> void:
    if system == null: return
    var region := _region_index()
    var items: Array = system.list_region(region)
    var active := 0
    var disrupted := 0
    var capacity := 0.0
    var maintenance := 0
    for asset in items:
        if str(asset.get("status", "")) == system.ACTIVE:
            active += 1
            capacity += float(asset.get("capacity", 0.0))
            maintenance += int(asset.get("maintenance", 0))
        elif str(asset.get("status", "")) == system.DISRUPTED:
            disrupted += 1
    var cash := 0
    var day := 1
    var game := _parent()
    if game != null:
        cash = int(game.cash)
        day = int(game.day)
    summary_label.text = "%s  •  DAY %d\nPhysical assets, capacity and disruption risk for the selected region." % [_region_name(), day]
    metrics_label.text = "ACTIVE %d   •   DISRUPTED %d   •   CAPACITY %.0f   •   UPKEEP $%s\nAVAILABLE CASH $%s   •   SELECTED TYPE %s" % [active, disrupted, capacity, _money(maintenance), _money(cash), _type_name()]
    status_label.text = "NETWORK STABLE" if disrupted == 0 else "%d DISRUPTED" % disrupted
    status_label.add_theme_color_override("font_color", STATUS_GREEN if disrupted == 0 else STATUS_WARN)
    build_button.tooltip_text = "Build a new %s in %s." % [_type_name().to_lower(), _region_name()]
    upgrade_button.tooltip_text = "Upgrade the first active infrastructure asset in this region."
    repair_button.tooltip_text = "Repair the first disrupted infrastructure asset in this region."
    type_button.tooltip_text = "Cycle through available infrastructure types."
    var signature := "%d:%d:%s:%d:%d:%s" % [region, cash, _type_name(), active, disrupted, message]
    if signature == last_signature: return
    last_signature = signature
    for child in list.get_children(): child.queue_free()
    if items.is_empty():
        _add_empty("No infrastructure assets are deployed here yet. Build the selected network asset to establish regional capacity.")
    else:
        for asset in items: _add_asset_card(asset)
    _layout()

func _add_asset_card(asset: Dictionary) -> void:
    var card := Panel.new()
    card.add_theme_stylebox_override("panel", _style(SURFACE_2))
    card.custom_minimum_size = Vector2(0, 82)
    list.add_child(card)
    var name := Label.new()
    name.text = str(asset.get("type", "Infrastructure")).replace("_", " ").capitalize()
    name.add_theme_font_size_override("font_size", 15)
    name.add_theme_color_override("font_color", TEXT)
    name.position = Vector2(12, 9)
    name.size = Vector2(190, 25)
    card.add_child(name)
    var status := str(asset.get("status", "unknown")).replace("_", " ").to_upper()
    var state := Label.new()
    state.text = status
    state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    state.add_theme_color_override("font_color", STATUS_GREEN if status == "ACTIVE" else STATUS_WARN)
    state.position = Vector2(195, 9)
    state.size = Vector2(120, 25)
    card.add_child(state)
    var detail := Label.new()
    detail.text = "Capacity %s  •  Utilization %s  •  Upkeep $%s" % [_num(asset.get("capacity", 0)), _num(asset.get("utilization", 0)), _money(int(asset.get("maintenance", 0)))]
    detail.add_theme_color_override("font_color", MUTED)
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.position = Vector2(12, 38)
    detail.size = Vector2(303, 35)
    card.add_child(detail)

func _add_empty(text: String) -> void:
    var card := Panel.new()
    card.add_theme_stylebox_override("panel", _style(SURFACE_2))
    card.custom_minimum_size = Vector2(0, 96)
    list.add_child(card)
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_color_override("font_color", MUTED)
    label.position = Vector2(14, 12)
    label.size = Vector2(300, 72)
    card.add_child(label)

func _num(value) -> String:
    return "%.0f" % float(value)

func _money(amount: int) -> String:
    if amount >= 1000000: return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000: return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or system == null or _parent() == null: return
    match event.keycode:
        KEY_F11: cycle_type()
        KEY_F12: build_selected()
        KEY_F13: _upgrade_selected()
        KEY_F14: repair_damaged()

func _layout() -> void:
    if panel == null or get_viewport() == null: return
    var size := get_viewport().get_visible_rect().size
    var phone := size.x < 430.0
    var narrow := size.x < 760.0
    var margin := 10.0 if phone else 16.0
    var w := minf(560.0, maxf(300.0, size.x - margin * 2.0))
    var h := minf(700.0, maxf(430.0, size.y - 70.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = size
    panel.position = Vector2((size.x - w) / 2.0, maxf(34.0, (size.y - h) / 2.0)) if not narrow else Vector2(margin, maxf(34.0, (size.y - h) / 2.0))
    panel.size = Vector2(w, minf(h, size.y - panel.position.y - 8.0))
    title_label.position = Vector2(14, 10)
    title_label.size = Vector2(w - 210.0, 30)
    title_label.add_theme_font_size_override("font_size", 18 if phone else 21)
    status_label.position = Vector2(w - 196.0, 14)
    status_label.size = Vector2(112, 20)
    status_label.add_theme_font_size_override("font_size", 9 if phone else 10)
    close_button.position = Vector2(w - 84.0, 7)
    close_button.size = Vector2(70, 46)
    close_button.add_theme_font_size_override("font_size", 10)
    summary_label.position = Vector2(14, 50)
    summary_label.size = Vector2(w - 28.0, 42)
    summary_label.add_theme_font_size_override("font_size", 10 if phone else 11)
    metrics_label.position = Vector2(14, 91)
    metrics_label.size = Vector2(w - 28.0, 48)
    metrics_label.add_theme_font_size_override("font_size", 10 if phone else 11)
    var button_y := 143.0
    if phone:
        type_button.position = Vector2(14, button_y)
        type_button.size = Vector2(w - 28.0, 44)
        build_button.position = Vector2(14, button_y + 50)
        build_button.size = Vector2(w - 28.0, 44)
        upgrade_button.position = Vector2(14, button_y + 100)
        upgrade_button.size = Vector2((w - 34.0) / 2.0, 44)
        repair_button.position = Vector2(20 + (w - 34.0) / 2.0, button_y + 100)
        repair_button.size = Vector2((w - 34.0) / 2.0, 44)
        scroll.position = Vector2(12, button_y + 154)
    else:
        type_button.position = Vector2(14, button_y)
        type_button.size = Vector2((w - 34.0) / 2.0, 46)
        build_button.position = Vector2(20 + (w - 34.0) / 2.0, button_y)
        build_button.size = Vector2((w - 34.0) / 2.0, 46)
        upgrade_button.position = Vector2(14, button_y + 52)
        upgrade_button.size = Vector2((w - 34.0) / 2.0, 46)
        repair_button.position = Vector2(20 + (w - 34.0) / 2.0, button_y + 52)
        repair_button.size = Vector2((w - 34.0) / 2.0, 46)
        scroll.position = Vector2(12, button_y + 106)
    scroll.size = Vector2(w - 24.0, maxf(150.0, panel.size.y - scroll.position.y - 12.0))
    list.custom_minimum_size.x = maxf(1.0, w - 24.0)
    for card in list.get_children():
        if card is Panel:
            for child in card.get_children():
                if child is Label:
                    if child.position.x >= 190.0:
                        child.position.x = maxf(150.0, w - 150.0)
                        child.size.x = 120.0
                    elif child.position.y >= 38.0:
                        child.size.x = maxf(140.0, w - 48.0)
