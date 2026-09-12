extends Control

## RENEW functional bar chart (UI 2.0 foundation).
## Renders a real numeric series (income vs spend, production by good,
## headcount by site) as vertical bars around a zero baseline with an
## optional target line. `layout_bars()` is pure geometry for headless tests.
var values: Array[float] = []
var gain_color := Color("58d39b")
var loss_color := Color("f26d6d")
var baseline_color := Color("315b63")
var target_value := 0.0
var has_target := false
var gap := 6.0

func _init() -> void:
    custom_minimum_size = Vector2(220, 80)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_bars(data: Array) -> void:
    values.clear()
    for entry in data:
        values.append(float(entry))
    queue_redraw()

func set_target(value: float) -> void:
    target_value = value
    has_target = true
    queue_redraw()

func clear_target() -> void:
    has_target = false
    queue_redraw()

static func layout_bars(data: Array, rect: Rect2, bar_gap: float = 6.0) -> Array[Rect2]:
    var bars: Array[Rect2] = []
    if data.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return bars
    var numbers: Array[float] = []
    for entry in data:
        numbers.append(float(entry))
    var peak := 0.0
    for value in numbers:
        peak = maxf(peak, absf(value))
    peak = maxf(peak, 0.0001)
    var count := numbers.size()
    var slot := rect.size.x / float(count)
    var width := maxf(2.0, slot - bar_gap)
    var zero_y := rect.position.y + rect.size.y * 0.5
    var half := rect.size.y * 0.5
    for index in range(count):
        var magnitude := absf(numbers[index]) / peak
        var height := half * magnitude
        var x := rect.position.x + slot * float(index) + (slot - width) * 0.5
        if numbers[index] >= 0.0:
            bars.append(Rect2(x, zero_y - height, width, height))
        else:
            bars.append(Rect2(x, zero_y, width, height))
    return bars

func _draw() -> void:
    if values.is_empty():
        return
    var area := Rect2(Vector2.ZERO, size)
    var bars := layout_bars(values, area, gap)
    var zero_y := area.position.y + area.size.y * 0.5
    draw_line(Vector2(area.position.x, zero_y), Vector2(area.end.x, zero_y), baseline_color, 1.0)
    for index in range(bars.size()):
        var color := gain_color if values[index] >= 0.0 else loss_color
        draw_rect(bars[index], color)
    if has_target:
        var peak := 0.0001
        for value in values:
            peak = maxf(peak, absf(value))
        peak = maxf(peak, absf(target_value))
        var span := peak * 2.0
        var y := area.position.y + area.size.y * (1.0 - (target_value + peak) / span)
        y = clampf(y, area.position.y, area.end.y)
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("f2c65c"), 1.0)
