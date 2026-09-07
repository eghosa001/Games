extends CanvasLayer

## Finance overview: ledger truth, credit standing, recent transactions.
## Every action routes through Main into the authoritative finance system.
var panel: Panel
var title_label: Label
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
    var viewport: Vector2 = get_viewport().size
    var margin := 16.0
    var width := minf(560.0, viewport.x - margin * 2.0)
    var height := minf(560.0, viewport.y - 140.0)
    panel.position = Vector2((viewport.x - width) / 2.0, 70.0)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 12)
    title_label.size = Vector2(width - 28, 28)
    overview_label.position = Vector2(14, 44)
    overview_label.size = Vector2(width - 28, 70)
    credit_label.position = Vector2(14, 118)
    credit_label.size = Vector2(width - 28, 44)
    tx_label.position = Vector2(14, 166)
    tx_label.size = Vector2(width - 28, maxf(40.0, height - 286.0))
    var y := height - 108.0
    loan_button.position = Vector2(14, y)
    loan_button.size = Vector2((width - 42) / 3.0, 46)
    repay_button.position = Vector2(20 + (width - 42) / 3.0, y)
    repay_button.size = Vector2((width - 42) / 3.0, 46)
    investor_button.position = Vector2(26 + (width - 42) * 2.0 / 3.0, y)
    investor_button.size = Vector2((width - 42) / 3.0, 46)
    close_button.position = Vector2(14, height - 56)
    close_button.size = Vector2(width - 28, 46)

func _refresh(_force: bool) -> void:
    var finance = _finance()
    if finance == null:
        overview_label.text = "Finance system unavailable."
        return
    var bs: Dictionary = finance.balance_sheet() if finance.has_method("balance_sheet") else {}
    overview_label.text = "Cash $%s  •  Debt $%s\nRevenue $%s  •  Expenses $%s  •  Equity $%s" % [_money(int(finance.get("cash"))), _money(int(finance.get("debt"))), _money(int(finance.get("revenue"))), _money(int(finance.get("operating_expenses"))), _money(int(float(bs.get("equity", 0.0))))]
    var valid: Dictionary = finance.validate_invariants() if finance.has_method("validate_invariants") else {"ok": true}
    credit_label.text = "Credit %s (score %d)  •  Books %s" % [str(finance.get("credit_rating")), int(finance.get("credit_score")), "balanced" if bool(valid.get("ok", false)) else "NEEDS REPAIR"]
    var lines: Array = []
    for entry in (finance.get("history") as Array).slice(maxi(0, (finance.get("history") as Array).size() - 8), (finance.get("history") as Array).size()):
        if entry is Dictionary:
            lines.append("%s $%s — %s" % [str((entry as Dictionary).get("kind", "?")), _money(abs(int((entry as Dictionary).get("amount", 0)))), str((entry as Dictionary).get("reason", ""))])
    tx_label.text = "Recent transactions\n" + ("\n".join(lines) if not lines.is_empty() else "No transactions yet.")

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
