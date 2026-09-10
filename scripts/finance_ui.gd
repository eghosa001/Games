extends CanvasLayer

## Finance command center: compact on phones, readable on tablets/desktop.
## Mutations remain delegated to Main/FinanceSystem; this surface never edits ledger state directly.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const GOOD := Color("5fe08a")
const WARN := Color("ffad8f")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var overview_label: Label
var credit_label: Label
var tx_label: Label
var feedback_label: Label
var loan_button: Button
var repay_button: Button
var investor_button: Button
var close_button: Button
var transaction_scroll: ScrollContainer
var refresh_clock := 0.0
var last_signature := ""
var feedback := ""

func _ready() -> void:
    layer = 65
    _build_ui()
    _layout()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if panel == null or not panel.visible:
        return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _finance():
    var services := get_node_or_null("/root/RenewServices")
    if services != null and services.has_method("get_service"):
        var finance = services.get_service("RenewFinanceSystem")
        if finance != null:
            return finance
    return get_node_or_null("/root/RenewFinanceSystem")

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    return s

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "FinanceModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "FinancePanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    add_child(panel)

    title_label = _label("FINANCE COMMAND", 20, TEXT)
    status_label = _label("LIVE LEDGER", 10, ACCENT)
    overview_label = _label("", 12, TEXT)
    credit_label = _label("", 11, MUTED)
    tx_label = _label("", 11, MUTED)
    feedback_label = _label("", 10, GOOD)

    loan_button = _button("LOAN")
    loan_button.pressed.connect(_loan)
    repay_button = _button("REPAY")
    repay_button.pressed.connect(_repay)
    investor_button = _button("INVESTOR")
    investor_button.pressed.connect(_investor)
    close_button = _button("CLOSE")
    close_button.pressed.connect(_close)

    transaction_scroll = ScrollContainer.new()
    transaction_scroll.name = "FinanceTransactionScroll"
    transaction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    transaction_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(transaction_scroll)
    tx_label.reparent(transaction_scroll)

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
    button.clip_text = true
    button.custom_minimum_size = Vector2(0, 46)
    button.add_theme_stylebox_override("normal", _style(SURFACE_2))
    button.add_theme_stylebox_override("hover", _style(Color("17343d"), ACCENT))
    button.add_theme_stylebox_override("pressed", _style(Color("1b3d46"), ACCENT))
    button.add_theme_color_override("font_color", TEXT)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null:
        return
    var viewport: Vector2 = get_viewport().size
    var phone := viewport.x < 430.0
    var narrow := viewport.x < 760.0
    var margin := 8.0 if phone else 14.0
    var width := minf(640.0, maxf(280.0, viewport.x - margin * 2.0))
    var height := minf(680.0, maxf(430.0, viewport.y - 72.0))
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(38.0, (viewport.y - height) / 2.0))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 8.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport

    title_label.position = Vector2(14, 10)
    title_label.size = Vector2(maxf(110.0, width - 190.0), 30)
    title_label.add_theme_font_size_override("font_size", 17 if phone else 20)
    status_label.position = Vector2(maxf(140.0, width - 178.0), 14)
    status_label.size = Vector2(maxf(78.0, width - status_label.position.x - 14.0), 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_font_size_override("font_size", 8 if phone else 9)

    overview_label.position = Vector2(14, 48)
    overview_label.size = Vector2(width - 28.0, 64)
    overview_label.add_theme_font_size_override("font_size", 10 if phone else 12)
    credit_label.position = Vector2(14, 116)
    credit_label.size = Vector2(width - 28.0, 38)
    credit_label.add_theme_font_size_override("font_size", 9 if phone else 11)
    feedback_label.position = Vector2(14, 156)
    feedback_label.size = Vector2(width - 28.0, 32)

    var tx_top := 190.0
    transaction_scroll.position = Vector2(14, tx_top)
    transaction_scroll.size = Vector2(width - 28.0, maxf(90.0, panel.size.y - 330.0))
    tx_label.position = Vector2.ZERO
    tx_label.size = Vector2(width - 28.0, maxf(90.0, tx_label.get_combined_minimum_size().y))
    tx_label.add_theme_font_size_override("font_size", 9 if phone else 11)

    var action_y := panel.size.y - 128.0
    var gap := 6.0
    var action_width := (width - 28.0 - gap * 2.0) / 3.0
    if narrow:
        action_width = maxf(72.0, action_width)
    loan_button.position = Vector2(14, action_y)
    loan_button.size = Vector2(action_width, 46)
    repay_button.position = Vector2(14 + action_width + gap, action_y)
    repay_button.size = Vector2(action_width, 46)
    investor_button.position = Vector2(14 + (action_width + gap) * 2.0, action_y)
    investor_button.size = Vector2(action_width, 46)
    for b in [loan_button, repay_button, investor_button]:
        b.add_theme_font_size_override("font_size", 8 if phone else 10)

    close_button.position = Vector2(14, panel.size.y - 70.0)
    close_button.size = Vector2(width - 28.0, 46)
    close_button.add_theme_font_size_override("font_size", 10 if phone else 11)

func _refresh(_force: bool) -> void:
    var finance = _finance()
    if finance == null:
        status_label.text = "OFFLINE"
        status_label.add_theme_color_override("font_color", WARN)
        overview_label.text = "Finance system unavailable."
        credit_label.text = "Ledger data cannot be displayed until the finance system is ready."
        feedback_label.text = ""
        tx_label.text = ""
        return

    var bs: Dictionary = finance.balance_sheet() if finance.has_method("balance_sheet") else {}
    var cash := int(finance.get("cash"))
    var debt := int(finance.get("debt"))
    var revenue := int(finance.get("revenue"))
    var expenses := int(finance.get("operating_expenses"))
    var equity := int(float(bs.get("equity", 0.0)))
    overview_label.text = "CASH  $%s    DEBT  $%s\nREVENUE  $%s    EXPENSES  $%s    EQUITY  $%s" % [_money(cash), _money(debt), _money(revenue), _money(expenses), _money(equity)]

    var valid: Dictionary = finance.validate_invariants() if finance.has_method("validate_invariants") else {"ok": true}
    var balanced := bool(valid.get("ok", false))
    credit_label.text = "CREDIT %s  •  SCORE %d  •  BOOKS %s" % [str(finance.get("credit_rating")), int(finance.get("credit_score")), "BALANCED" if balanced else "NEEDS REVIEW"]
    credit_label.add_theme_color_override("font_color", GOOD if balanced else WARN)
    status_label.text = "LEDGER HEALTHY" if balanced else "LEDGER REVIEW"
    status_label.add_theme_color_override("font_color", GOOD if balanced else WARN)

    var lines: Array[String] = []
    var history = finance.get("history")
    if history is Array:
        var start := maxi(0, history.size() - 10)
        for entry in history.slice(start, history.size()):
            if entry is Dictionary:
                var amount := int(entry.get("amount", 0))
                lines.append("%s   $%s\n%s" % [str(entry.get("kind", "TRANSACTION")).to_upper(), _money(abs(amount)), str(entry.get("reason", "Ledger entry"))])
    tx_label.text = "RECENT TRANSACTIONS\n\n" + ("\n\n".join(lines) if not lines.is_empty() else "No transactions recorded yet.")
    feedback_label.text = feedback
    feedback_label.add_theme_color_override("font_color", GOOD if feedback == "" or not feedback.to_lower().contains("fail") else WARN)
    var signature := "%d:%d:%d:%d:%d:%d:%s" % [cash, debt, revenue, expenses, equity, int(finance.get("credit_score")), feedback]
    if signature == last_signature and not _force:
        return
    last_signature = signature
    _layout()

func _loan() -> void:
    var game = _game()
    if game != null and game.has_method("take_loan"):
        game.take_loan()
        feedback = "Loan request submitted to the finance engine."
    else:
        feedback = "Loan service is unavailable."
    _refresh(true)

func _repay() -> void:
    var game = _game()
    if game != null and game.has_method("repay_loan"):
        game.repay_loan()
        feedback = "Repayment request submitted to the finance engine."
    else:
        feedback = "Repayment service is unavailable."
    _refresh(true)

func _investor() -> void:
    var game = _game()
    if game != null and game.has_method("request_investment"):
        game.request_investment()
        feedback = "Investment request submitted to the finance engine."
    else:
        feedback = "Investor service is unavailable."
    _refresh(true)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        panel.visible = false
        dimmer.visible = false

func _money(amount: int) -> String:
    if amount >= 1000000:
        return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
