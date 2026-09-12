extends SceneTree

## UI 2.0 widget-kit contract tests.
## Locks the shared theme + widget API that screen rewrites build on:
## palette identity, style factories, touch-compliant buttons, data tables,
## status chips, metrics, clamped progress, and functional chart geometry.
const RenewTheme = preload("res://scripts/renew_theme.gd")
const RenewWidgets = preload("res://scripts/renew_widgets.gd")
const RenewTrendChart = preload("res://scripts/renew_trend_chart.gd")
const RenewBarChart = preload("res://scripts/renew_bar_chart.gd")

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var palette: Dictionary = RenewTheme.get_palette()
    check(palette.size() >= 14, "Theme exposes the full command-deck palette")
    check(palette.get("gold") == Color("f2c65c"), "Theme gold matches the RENEW identity")
    check(palette.get("surface") == Color("0d222b"), "Theme surface matches the RENEW identity")
    check(RenewTheme.money(2500) == "2500", "Theme money formatting is stable")
    check(RenewTheme.percent(0.25) == "25%", "Theme percent formatting is stable")

    var card_style: StyleBoxFlat = RenewTheme.card_style()
    check(card_style != null and card_style.corner_radius_top_left == RenewTheme.RADIUS_CARD, "Theme card style carries the card radius")

    var label: Label = RenewTheme.make_label("Hello", RenewTheme.FONT_TITLE, RenewTheme.TEXT)
    check(label.text == "Hello", "Theme label keeps caller text")
    check(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Theme label wraps long content")

    var button: Button = RenewTheme.make_button("TEST")
    check(button.custom_minimum_size.x >= 44.0 and button.custom_minimum_size.y >= 44.0, "Theme button meets the 44px touch floor")
    var close_button: Button = RenewTheme.make_close_button()
    check(close_button.name == "UniversalCloseButton", "Theme close button uses the manager close contract")
    check(close_button.custom_minimum_size.x >= 44.0 and close_button.custom_minimum_size.y >= 44.0, "Theme close button meets the 44px touch floor")

    var header: VBoxContainer = RenewWidgets.make_header("Dashboard", "Command overview")
    check(header.get_node_or_null("HeaderTitle") != null, "Widget header exposes its title node")
    check(header.get_node_or_null("HeaderSubtitle") != null, "Widget header exposes its subtitle node")

    var metric: VBoxContainer = RenewWidgets.make_metric("Cash", "$100000", RenewTheme.GOLD)
    var metric_value := metric.get_node_or_null("MetricValue") as Label
    check(metric_value != null and str(metric_value.text) == "$100000", "Widget metric exposes its value node")

    var good := RenewWidgets.make_chip("Allied", "good")
    var bad := RenewWidgets.make_chip("War", "bad")
    var good_label := good.get_node_or_null("ChipLabel") as Label
    var bad_label := bad.get_node_or_null("ChipLabel") as Label
    check(good_label != null and bad_label != null, "Widget chips expose their text nodes")
    var good_ink: Color = good_label.get_theme_color("font_color")
    var bad_ink: Color = bad_label.get_theme_color("font_color")
    check(good_ink != bad_ink, "Widget chip kinds are visually distinct")
    check(RenewWidgets.chip_color("unknown") == RenewTheme.MUTED, "Widget chip falls back to muted for unknown kinds")

    var bar := RenewWidgets.make_progress(0.5)
    check(is_equal_approx(bar.value, 0.5), "Widget progress keeps its initial value")
    RenewWidgets.set_progress(bar, 1.5)
    check(is_equal_approx(bar.value, 1.0), "Widget progress clamps above the range")
    RenewWidgets.set_progress(bar, -2.0)
    check(is_equal_approx(bar.value, 0.0), "Widget progress clamps below the range")

    var columns: Array = ["Rival", "Stance", "Power"]
    var rows: Array = [["Northstar", "Allied", "62"], ["Vex", "Hostile", "88"]]
    var table: VBoxContainer = RenewWidgets.make_table(columns, rows, ["left", "left", "right"])
    var header_cells := table.get_node_or_null("TableHeader") as HBoxContainer
    check(header_cells != null and header_cells.get_child_count() == 3, "Widget table builds one header cell per column")
    check(RenewWidgets.table_row_count(table) == 2, "Widget table builds one row per record")
    var first_row := table.get_node_or_null("TableBody").get_child(0) as HBoxContainer
    check(first_row != null and first_row.get_child_count() == 3, "Widget table rows align with the columns")
    var right_cell := first_row.get_child(2) as Label
    check(right_cell.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Widget table honors right alignment")
    var ragged: VBoxContainer = RenewWidgets.make_table(columns, [["Only"]])
    check(RenewWidgets.table_row_count(ragged) == 1, "Widget table tolerates ragged rows")

    var trend := RenewTrendChart.new()
    root.add_child(trend)
    check(trend.custom_minimum_size.x > 0.0 and trend.custom_minimum_size.y > 0.0, "Trend chart ships a usable minimum size")
    trend.set_series([10.0, 20.0, 15.0, 30.0])
    check(is_equal_approx(trend.series_min(), 10.0), "Trend chart reports its data minimum")
    check(is_equal_approx(trend.series_max(), 30.0), "Trend chart reports its data maximum")
    var mapped: PackedVector2Array = RenewTrendChart.map_points([10.0, 20.0, 15.0, 30.0], Rect2(Vector2.ZERO, Vector2(300, 100)))
    check(mapped.size() == 4, "Trend mapping keeps every sample")
    check(is_equal_approx(mapped[0].x, 0.0) and is_equal_approx(mapped[3].x, 300.0), "Trend mapping spans the full width")
    check(mapped[3].y < mapped[0].y, "Trend mapping places the maximum above the minimum")
    check(RenewTrendChart.map_points([], Rect2(Vector2.ZERO, Vector2(300, 100))).is_empty(), "Trend mapping tolerates empty series")
    trend.set_series([])
    check(trend.series_min() == 0.0 and trend.series_max() == 0.0, "Trend chart reports zero bounds for empty series")
    trend.queue_free()

    var bars := RenewBarChart.new()
    root.add_child(bars)
    bars.set_bars([120.0, -40.0, 60.0])
    var laid: Array = RenewBarChart.layout_bars([120.0, -40.0, 60.0], Rect2(Vector2.ZERO, Vector2(300, 100)))
    check(laid.size() == 3, "Bar layout keeps every value")
    var gain := laid[0] as Rect2
    var loss := laid[1] as Rect2
    check(gain.size.y > (laid[2] as Rect2).size.y, "Bar layout scales height by magnitude")
    check(loss.position.y >= 50.0, "Bar layout draws losses below the zero baseline")
    check(RenewBarChart.layout_bars([], Rect2(Vector2.ZERO, Vector2(300, 100))).is_empty(), "Bar layout tolerates empty series")
    bars.set_target(80.0)
    check(bars.has_target and is_equal_approx(bars.target_value, 80.0), "Bar chart stores its target line")
    bars.clear_target()
    check(not bars.has_target, "Bar chart clears its target line")
    bars.queue_free()

    await process_frame
    print("RENEW WIDGET KIT RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
