extends Control

## RENEW functional trend chart (UI 2.0 foundation).
## Plots a real numeric series (finance history, cash flow, reputation,
## production output) as an area + line + endpoint dot. Data-first:
## `set_series()` takes plain numbers; `map_points()` is pure math so the
## release matrix can verify geometry without a renderer.
var values: Array[float] = []
var line_color := Color("f2c65c")
var fill_color := Color(0.95, 0.78, 0.36, 0.18)
var dot_color := Color("eef8f5")
var show_dots := false

func _init() -> void:
    custom_minimum_size = Vector2(220, 64)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_series(data: Array) -> void:
    values.clear()
    for entry in data:
        values.append(float(entry))
    queue_redraw()

func series_min() -> float:
    if values.is_empty():
        return 0.0
    var lowest: float = values[0]
    for value in values:
        lowest = minf(lowest, value)
    return lowest

func series_max() -> float:
    if values.is_empty():
        return 0.0
    var highest: float = values[0]
    for value in values:
        highest = maxf(highest, value)
    return highest

static func map_points(data: Array, rect: Rect2) -> PackedVector2Array:
    var mapped := PackedVector2Array()
    if data.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return mapped
    var numbers: Array[float] = []
    for entry in data:
        numbers.append(float(entry))
    var lowest: float = numbers[0]
    var highest: float = numbers[0]
    for value in numbers:
        lowest = minf(lowest, value)
        highest = maxf(highest, value)
    var span := maxf(highest - lowest, 0.0001)
    var count := numbers.size()
    for index in range(count):
        var x := rect.position.x
        if count > 1:
            x += rect.size.x * float(index) / float(count - 1)
        var normalized := (numbers[index] - lowest) / span
        var y := rect.position.y + rect.size.y * (1.0 - normalized)
        mapped.append(Vector2(x, y))
    return mapped

func _draw() -> void:
    if values.is_empty():
        return
    var area := Rect2(Vector2.ZERO, size)
    var points := map_points(values, area)
    if points.size() < 2:
        if points.size() == 1:
            draw_circle(points[0], 3.0, dot_color)
        return
    var filled := PackedVector2Array(points)
    filled.append(Vector2(area.end.x, area.end.y))
    filled.append(Vector2(area.position.x, area.end.y))
    draw_colored_polygon(filled, fill_color)
    draw_polyline(points, line_color, 2.0, true)
    if show_dots:
        for point in points:
            draw_circle(point, 2.0, dot_color)
    else:
        draw_circle(points[points.size() - 1], 3.0, dot_color)
