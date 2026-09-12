extends RefCounted

## RENEW purpose-built widgets (UI 2.0 foundation).
## Data-first building blocks for screen rewrites: every builder takes plain
## game data (Arrays/Dictionaries/numbers) and returns standard Controls.
## No scene-tree access, no autoloads: safe to construct in headless tests.
## Screens own positioning; widgets ship with compliant minimum sizes
## (touch targets >= 44px where the release matrix requires them).
const RenewTheme = preload("res://scripts/renew_theme.gd")

const CHIP_KINDS := ["good", "warn", "bad", "info", "neutral"]

static func chip_color(kind: String) -> Color:
    match kind.to_lower():
        "good":
            return RenewTheme.GREEN
        "warn", "warning":
            return RenewTheme.YELLOW
        "bad", "danger", "critical":
            return RenewTheme.RED
        "info":
            return RenewTheme.CYAN
    return RenewTheme.MUTED

static func make_card() -> Panel:
    var card := Panel.new()
    card.name = "Card"
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.add_theme_stylebox_override("panel", RenewTheme.card_style())
    return card

static func make_header(title: String, subtitle: String = "") -> VBoxContainer:
    var box := VBoxContainer.new()
    box.name = "ScreenHeader"
    box.add_theme_constant_override("separation", 2)
    var title_label := RenewTheme.make_label(title, RenewTheme.FONT_TITLE, RenewTheme.TEXT)
    title_label.name = "HeaderTitle"
    box.add_child(title_label)
    if not subtitle.is_empty():
        var sub := RenewTheme.make_label(subtitle, RenewTheme.FONT_SMALL, RenewTheme.GOLD_DIM)
        sub.name = "HeaderSubtitle"
        box.add_child(sub)
    return box

static func make_metric(caption: String, value: String, accent: Color = RenewTheme.TEXT) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.name = "Metric"
    box.add_theme_constant_override("separation", 0)
    var caption_label := RenewTheme.make_label(caption.to_upper(), RenewTheme.FONT_SMALL, RenewTheme.MUTED)
    caption_label.name = "MetricCaption"
    box.add_child(caption_label)
    var value_label := RenewTheme.make_label(value, RenewTheme.FONT_SECTION, accent)
    value_label.name = "MetricValue"
    box.add_child(value_label)
    return box

static func make_chip(text: String, kind: String = "neutral") -> PanelContainer:
    var chip := PanelContainer.new()
    chip.name = "StatusChip"
    var color: Color = chip_color(kind)
    var background := Color(color.r, color.g, color.b, 0.16)
    chip.add_theme_stylebox_override("panel", RenewTheme.panel_style(background, color, RenewTheme.RADIUS_CHIP))
    var label := RenewTheme.make_label(text.to_upper(), RenewTheme.FONT_SMALL, color)
    label.name = "ChipLabel"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chip.add_child(label)
    return chip

static func make_progress(initial: float = 0.0) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.name = "Progress"
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.custom_minimum_size = Vector2(80, 12)
    set_progress(bar, initial)
    return bar

static func set_progress(bar: ProgressBar, value: float) -> void:
    bar.value = clampf(value, 0.0, 1.0)

static func make_table(columns: Array, rows: Array, aligns: Array = []) -> VBoxContainer:
    var table := VBoxContainer.new()
    table.name = "DataTable"
    table.add_theme_constant_override("separation", 4)
    table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var header := HBoxContainer.new()
    header.name = "TableHeader"
    header.add_theme_constant_override("separation", 8)
    for index in range(columns.size()):
        var title := str(columns[index])
        var cell := RenewTheme.make_label(title.to_upper(), RenewTheme.FONT_SMALL, RenewTheme.MUTED)
        cell.name = "HeaderCell%d" % index
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cell.custom_minimum_size = Vector2(40, 20)
        if _align_right(aligns, index):
            cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        header.add_child(cell)
    table.add_child(header)
    var rule := HSeparator.new()
    rule.name = "TableRule"
    table.add_child(rule)
    var body := VBoxContainer.new()
    body.name = "TableBody"
    body.add_theme_constant_override("separation", 2)
    for row in rows:
        body.add_child(make_table_row(columns.size(), row, aligns))
    table.add_child(body)
    return table

static func make_table_row(column_count: int, row: Array, aligns: Array = []) -> HBoxContainer:
    var line := HBoxContainer.new()
    line.name = "TableRow"
    line.add_theme_constant_override("separation", 8)
    for index in range(column_count):
        var text := ""
        if index < row.size():
            text = str(row[index])
        var cell := RenewTheme.make_label(text, RenewTheme.FONT_BODY, RenewTheme.TEXT)
        cell.name = "RowCell%d" % index
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cell.custom_minimum_size = Vector2(40, 22)
        if _align_right(aligns, index):
            cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        line.add_child(cell)
    return line

static func table_row_count(table: VBoxContainer) -> int:
    var body := table.get_node_or_null("TableBody")
    if body == null:
        return 0
    return body.get_child_count()

static func _align_right(aligns: Array, index: int) -> bool:
    if index < 0 or index >= aligns.size():
        return false
    return str(aligns[index]).to_lower() == "right"
