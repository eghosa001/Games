extends CanvasLayer

## Finance overview: ledger truth, credit standing, recent transactions.
## Every action routes through Main into the authoritative finance system.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var overview_label: Label
var credit_label: Label
var tx_label: Label
var loan_button: Button
var repay_button: Button
var investor_button: Button
var close_button: Button
var refresh_clock := 0.0

const SURFACE := Color("0d2028")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

func _ready() -> void:
    layer = 65
    _build_ui()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible:
        return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "FinanceModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "FinancePanel"
    var style := StyleBoxFlat.new()
    style.bg_color = SURFACE
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    title_label = _label("FINANCE", 20, TEXT)
    status_label = _label("LIVE LEDGER", 10, ACCENT)
    overview_label = _label("", 12, TEXT)
    credit_label = _label("", 12, MUTED)
    tx_label = _label("", 11, MUTED)

    loan_button = _button("LOAN")
    loan_button.pressed.connect(_loan)
    repay_button = _button("REPAY")
    repay_button.pressed.connect(_repay)
    investor_button = _button("INVESTOR")
    investor_button.pressed.connect(_investor)
    close_button = _button("CLOSE")
    close_button.pressed.connect(_close)
    _layout()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 46)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null:
        return
    var viewport: Vector2 = get_viewport().size
    var margin := 12.0 if viewport.x < 390.0 else 16.0
    var width := minf(560.0, maxf(280.0, viewport.x - margin * 2.0))
    var height := minf(560.0, maxf(340.0, viewport.y - 96.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(48.0, (viewport.y - height) / 2.0))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))

    var compact := width < 390.0
    var side := 14.0
    title_label.position = Vector2(side, 12)
    title_label.size = Vector2(width - 140.0, 28)
    status_label.position = Vector2(width - 112.0, 14)
    status_label.size = Vector2(98.0, 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    overview_label.position = Vector2(side, 46)
    overview_label.size = Vector2(width - side * 2.0, 60 if compact else 58)
    credit_label.position = Vector2(side, 108 if compact else 106)
    credit_label.size = Vector2(width - side * 2.0, 42)
    tx_label.position = Vector2(side, 154 if compact else 152)
    tx_label.size = Vector2(width - side * 2.0, maxf(50.0, panel.size.y - 276.0))

    var y := panel.size.y - 108.0
    var gap := 7.0
    var action_width := maxf(72.0, (width - side * 2.0 - gap * 2.0) / 3.0)
    loan_button.position = Vector2(side, y)
    loan_button.size = Vector2(action_width, 46)
    repay_button.position = Vector2(side + action_width + gap, y)
    repay_button.size = Vector2(action_width, 46)
    investor_button.position = Vector2(side + (action_width + gap) * 2.0, y)
    investor_button.size = Vector2(action_width, 46)
    for button in [loan_button, repay_button, investor_button]:
        button.add_theme_font_size_override("font_size", 10 if compact else 11)

    close_button.position = Vector2(side, panel.size.y - 56)
    close_button.size = Vector2(width - side * 2.0, 46)
    close_button.add_theme_font_size_override("font_size", 11)

func _refresh(_force: bool) -> void:
    var finance = _finance()
    if finance == null:
        overview_label.text = "Finance system unavailable."
        credit_label.text = ""
        tx_label.text = ""
        return
    var bs: Dictionary = finance.balance_sheet() if finance.has_method("balance_sheet") else {}
    overview_label.text = "CASH  $%s    DEBT  $%s\nREVENUE  $%s    EXPENSES  $%s    EQUITY  $%s" % [_money(int(finance.get("cash"))), _money(int(finance.get("debt"))), _money(int(finance.get("revenue"))), _money(int(finance.get("operating_expenses"))), _money(int(float(bs.get("equity", 0.0))))]
    var valid: Dictionary = finance.validate_invariants() if finance.has_method("validate_invariants") else {"ok": true}
    credit_label.text = "Credit %s (score %d)  •  Books %s" % [str(finance.get("credit_rating")), int(finance.get("credit_score")), "BALANCED" if bool(valid.get("ok", false)) else "NEEDS REVIEW"]
    var lines: Array = []
    var history: Array = finance.get("history") as Array
    for entry in history.slice(maxi(0, history.size() - 8), history.size()):
        if entry is Dictionary:
            lines.append("%s   $%s — %s" % [str((entry as Dictionary).get("kind", "?")), _money(abs(int((entry as Dictionary).get("amount", 0)))), str((entry as Dictionary).get("reason", ""))])
    tx_label.text = "RECENT TRANSACTIONS\n" + ("\n".join(lines) if not lines.is_empty() else "No transactions yet.")

func _loan() -> void:
    var game = _game()
    if game != null and game.has_method("take_loan"):
        game.take_loan()

func _repay() -> void:
    var game = _game()
    if game != null and game.has_method("repay_loan"):
        game.repay_loan()

func _investor() -> void:
    var game = _game()
    if game != null and game.has_method("request_investment"):
        game.request_investment()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000000:
        return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
