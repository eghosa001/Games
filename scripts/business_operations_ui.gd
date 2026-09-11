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

const BG := Color("08151bf7")
const CARD := Color("10252d")
const BORDER := Color("31565e")
const TEXT := Color("edf6f3")
const MUTED := Color("8fa8ac")
const ACCENT := Color("d8b76d")
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
    scrim.color = Color(0.01, 0.04, 0.06, 0.82)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(scrim)
    panel = Panel.new()
    panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 18))
    add_child(panel)
    header = _label("BUSINESS OPERATIONS", 19, TEXT)
    summary = _label("LIVE OPERATING BOARD", 9, MUTED)
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
    s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left = 12; s.content_margin_right = 12
    s.content_margin_top = 8; s.content_margin_bottom = 8
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
    var s := get_viewport().get_visible_rect().size
    var phone := s.x < 430.0
    var narrow := s.x < 720.0
    var w := minf(780.0, maxf(304.0, s.x - (16.0 if narrow else 56.0)))
    var h := minf(620.0, maxf(470.0, s.y - (70.0 if narrow else 90.0)))
    panel.size = Vector2(w, minf(h, s.y - 16.0))
    panel.position = Vector2((s.x - w) * 0.5, maxf(38.0, (s.y - panel.size.y) * 0.5))
    header.position = Vector2(14, 10); header.size = Vector2(w - 112, 28)
    summary.position = Vector2(14, 39); summary.size = Vector2(w - 112, 18)
    close_button.position = Vector2(w - 88, 10); close_button.size = Vector2(76, 44)
    production_label.position = Vector2(14, 72); production_label.size = Vector2(w - 28, 42)
    inventory_label.position = Vector2(14, 116); inventory_label.size = Vector2(w - 28, 56)
    machine_label.position = Vector2(14, 174); machine_label.size = Vector2(w - 28, 56)
    var buttons := [produce_button, buy_inputs_button, upgrade_button, marketing_button, price_button, staff_button]
    var gap := 7.0
    var bw := (w - 28.0 - gap) / 2.0
    var actions_y := 238.0
    for i in range(buttons.size()):
        var row := i / 2
        var col := i % 2
        buttons[i].position = Vector2(14.0 + col * (bw + gap), actions_y + row * 53.0)
        buttons[i].size = Vector2(bw, 46)
        buttons[i].add_theme_font_size_override("font_size", 9 if phone or narrow else 10)
    status.position = Vector2(14, minf(actions_y + 3.0 * 53.0 + 8.0, panel.size.y - 48.0))
    status.size = Vector2(w - 28, 42)

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
