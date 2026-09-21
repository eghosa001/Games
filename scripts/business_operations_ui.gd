extends CanvasLayer

## Dedicated business command surface. Simulation authority remains on BusinessSystem and ProductionSystem.
var game: Node
var production: Node
var business: Node
var scrim: ColorRect
var panel: Panel
var header: Label
var summary: Label
var production_label: Label
var inventory_label: Label
var machine_label: Label
var close_button: Button
var produce_button: Button
var buy_inputs_button: Button
var upgrade_button: Button
var marketing_button: Button
var price_button: Button
var staff_button: Button
var status: Label

const BG := Color("0b1630f2")
const CARD := Color("14254d")
const BORDER := Color("5367af")
const TEXT := Color("f7f9ff")
const MUTED := Color("adbbe0")
const ACCENT := Color("f2c65c")
const POSITIVE := Color("86c9a9")
const WARNING := Color("f0ad88")

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    production = get_node_or_null("/root/RenewProductionSystem")
    business = get_node_or_null("/root/RenewBusinessSystem")
    _build()
    visible = false
    _layout()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _build() -> void:
    scrim = ColorRect.new()
    scrim.color = Color(0.01, 0.02, 0.06, 0.34)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(scrim)
    panel = Panel.new()
    panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 18))
    add_child(panel)
    header = _label("OPERATE", 20, TEXT)
    summary = _label("LIVE COMPANY • TAP ACTIONS, WATCH THE WORLD RESPOND", 9, MUTED)
    production_label = _label("", 11, TEXT)
    inventory_label = _label("", 10, MUTED)
    machine_label = _label("", 10, MUTED)
    status = _label("", 9, MUTED)
    for node in [header, summary, production_label, inventory_label, machine_label, status]: panel.add_child(node)
    close_button = _button("CLOSE", Callable(self, "_close"), 44)
    produce_button = _button("PRODUCE", Callable(self, "_produce"), 46)
    buy_inputs_button = _button("BUY INPUTS", Callable(self, "_buy_inputs"), 46)
    upgrade_button = _button("UPGRADE CAPACITY", Callable(self, "_upgrade"), 46)
    marketing_button = _button("MARKETING", Callable(self, "_marketing"), 46)
    price_button = _button("CHANGE PRICE", Callable(self, "_price"), 46)
    staff_button = _button("STAFF", Callable(self, "_staff"), 46)
    for button in [close_button, produce_button, buy_inputs_button, upgrade_button, marketing_button, price_button, staff_button]: panel.add_child(button)

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.border_color = border
    s.set_border_width_all(1)
    s.set_border_width(SIDE_TOP, 2)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 12; s.content_margin_right = 12
    s.content_margin_top = 8; s.content_margin_bottom = 8
    s.shadow_color = Color(0, 0, 0, 0.42)
    s.shadow_size = 14
    s.shadow_offset = Vector2(0, 6)
    return s

func _button(text: String, callback: Callable, height: int) -> Button:
    var b := Button.new()
    b.text = text; b.custom_minimum_size = Vector2(0, height)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    b.add_theme_font_size_override("font_size", 10)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_stylebox_override("normal", _style(CARD, BORDER, 9))
    b.add_theme_stylebox_override("hover", _style(Color("1b3b42"), ACCENT, 9))
    b.add_theme_stylebox_override("pressed", _style(Color("244d4e"), ACCENT, 9))
    return b

func _layout() -> void:
    if panel == null: return
    var viewport := get_viewport().get_visible_rect().size
    var phone := viewport.x < 430.0
    var narrow := viewport.x < 720.0

    # Frequent operating actions behave as a contextual sheet so the player
    # keeps visual contact with the simulated business instead of entering a
    # disconnected full-screen dashboard.
    var w := viewport.x - 16.0 if narrow else minf(430.0, viewport.x - 32.0)
    var h := minf(520.0, maxf(390.0, viewport.y * (0.60 if narrow else 0.74)))
    panel.size = Vector2(w, h)
    panel.position = Vector2(
        8.0 if narrow else viewport.x - w - 16.0,
        viewport.y - h - 8.0 if narrow else maxf(16.0, (viewport.y - h) * 0.5)
    )

    header.position = Vector2(16, 12); header.size = Vector2(w - 116, 28)
    summary.position = Vector2(16, 42); summary.size = Vector2(w - 116, 20)
    close_button.position = Vector2(w - 92, 10); close_button.size = Vector2(76, 44)
    production_label.position = Vector2(16, 76); production_label.size = Vector2(w - 32, 38)
    inventory_label.position = Vector2(16, 116); inventory_label.size = Vector2(w - 32, 50)
    machine_label.position = Vector2(16, 168); machine_label.size = Vector2(w - 32, 50)

    var buttons := [produce_button, buy_inputs_button, upgrade_button, marketing_button, price_button, staff_button]
    var gap := 8.0
    var columns := 2
    var bw := (w - 32.0 - gap) / float(columns)
    var actions_y := 226.0
    for i in range(buttons.size()):
        var row := i / columns
        var col := i % columns
        buttons[i].position = Vector2(16.0 + col * (bw + gap), actions_y + row * 54.0)
        buttons[i].size = Vector2(bw, 46)
        buttons[i].add_theme_font_size_override("font_size", 9 if phone else 10)
    status.position = Vector2(16, minf(actions_y + 3.0 * 54.0 + 8.0, panel.size.y - 46.0))
    status.size = Vector2(w - 32, 38)

func open_screen() -> void:
    visible = true
    if production == null: production = get_node_or_null("/root/RenewProductionSystem")
    if business == null: business = get_node_or_null("/root/RenewBusinessSystem")
    _layout(); _refresh()

func close_screen() -> void:
    visible = false

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: close_screen()

func _run(callable: Callable) -> void:
    if callable.is_valid(): callable.call()
    if game != null: status.text = str(game.message)
    _refresh()

func _produce() -> void:
    if game != null: _run(Callable(game, "produce_goods"))
func _buy_inputs() -> void:
    if game != null: _run(Callable(game, "buy_inputs"))
func _upgrade() -> void:
    if game != null: _run(Callable(game, "upgrade_business"))
func _marketing() -> void:
    if game != null: _run(Callable(game, "marketing_campaign"))
func _price() -> void:
    if game != null: _run(Callable(game, "change_price"))
func _staff() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null: manager.show_screen("EmployeePanel")

func _refresh() -> void:
    if game != null:
        summary.text = "%s  •  %s  •  PRICE $%d" % ["OPEN" if bool(game.business_open) else "CLOSED", str(game.stage).to_upper(), int(game.player_price)]
        production_label.text = "PRODUCTION  •  %d FINISHED GOODS  •  QUALITY %d" % [int(game.finished_goods), int(_quality())]
    if production != null:
        var inventory_parts: Array[String] = []
        for item in ["timber", "iron", "energy", "furniture", "appliance", "construction_materials", "consumer_electronics"]:
            var amount := int(production.stock(item))
            if amount > 0: inventory_parts.append("%s %d" % [item.to_upper().replace("_", " "), amount])
        inventory_label.text = "INVENTORY  •  " + ("  |  ".join(inventory_parts) if not inventory_parts.is_empty() else "No production stock yet")
        var machines: Dictionary = production.machines
        var parts: Array[String] = []
        for id in ["extractor", "harvester", "processor", "factory", "fleet", "store"]:
            var m: Dictionary = machines.get(id, {})
            if not m.is_empty(): parts.append("%s %s%%" % [id.to_upper(), int(round(float(m.get("condition", 0.0))))])
        machine_label.text = "EQUIPMENT  •  " + "  |  ".join(parts)
    var enabled := game != null and bool(game.business_open)
    for button in [produce_button, buy_inputs_button, upgrade_button, marketing_button, price_button]: button.disabled = not enabled

func _quality() -> int:
    if production != null: return int(production.quality)
    return 0
