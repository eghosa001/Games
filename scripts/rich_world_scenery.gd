extends Node2D
## Rich presentation-only world scenery.
## All business/HQ/region state is read from authoritative systems; this node owns no gameplay state.

const BG := Color("081017")
const GROUND := Color("0d1b20")
const ROAD := Color("17282d")
const ROAD_EDGE := Color("315057")
const BUILDING := Color("183039")
const BUILDING_2 := Color("213b43")
const GLASS := Color("6d9b98")
const GOLD := Color("d5b56b")
const GREEN := Color("65b38f")
const MUTED := Color("6f858a")

var _time := 0.0
var _last_signature := ""

func _ready() -> void:
    z_index = -15
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    if fmod(_time, 0.12) < delta:
        queue_redraw()

func _draw() -> void:
    var size := get_viewport_rect().size
    var w := maxf(size.x, 320.0)
    var h := maxf(size.y, 568.0)
    _draw_landscape(w, h)
    _draw_districts(w, h)
    _draw_roads(w, h)
    _draw_facilities(w, h)
    _draw_hq(w, h)
    _draw_life(w, h)
    _draw_region_map(w, h)

func _draw_landscape(w: float, h: float) -> void:
    draw_rect(Rect2(0, 0, w, h), BG, true)
    var horizon := minf(300.0, h * 0.38)
    draw_rect(Rect2(0, horizon, w, h - horizon), GROUND, true)
    for i in range(9):
        var bx := float(i) * maxf(150.0, w / 8.0) - 80.0
        var bh := 45.0 + float((i * 37) % 110)
        draw_rect(Rect2(bx, horizon - bh, 105.0, bh), Color("10242c"), true)
        if i % 2 == 0:
            for wy in range(int(horizon - bh + 12.0), int(horizon - 8.0), 19):
                draw_rect(Rect2(bx + 14, wy, 5, 3), Color(GOLD, 0.18), true)
                draw_rect(Rect2(bx + 40, wy, 5, 3), Color(GLASS, 0.13), true)
    draw_line(Vector2(0, horizon), Vector2(w, horizon), Color("50747a", 0.24), 2.0)
    _draw_atmosphere(Vector2(w * 0.18, horizon * 0.55), minf(240.0, w * 0.28), Color("174139"))
    _draw_atmosphere(Vector2(w * 0.82, horizon * 0.45), minf(280.0, w * 0.30), Color("193744"))

func _draw_atmosphere(center: Vector2, radius: float, tint: Color) -> void:
    for i in range(7, 0, -1):
        var r := radius * float(i) / 7.0
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, 0.012 * float(8 - i)))

func _draw_districts(w: float, h: float) -> void:
    var base_y := minf(420.0, h * 0.58)
    var widths := [0.20, 0.16, 0.22, 0.18, 0.24]
    var names := ["INDUSTRIAL", "LOGISTICS", "COMMERCIAL", "RESEARCH", "RESIDENTIAL"]
    var x := 0.0
    for i in range(widths.size()):
        var dw := w * widths[i]
        draw_rect(Rect2(x, base_y, dw, h - base_y), Color("0f2025") if i % 2 == 0 else Color("10232a"), true)
        draw_string(ThemeDB.fallback_font, Vector2(x + 12, base_y + 24), names[i], HORIZONTAL_ALIGNMENT_LEFT, dw - 24, 9, Color(MUTED, 0.65))
        x += dw

func _draw_roads(w: float, h: float) -> void:
    var horizon := minf(330.0, h * 0.42)
    var road_y := minf(535.0, h * 0.68)
    draw_colored_polygon(PackedVector2Array([
        Vector2(w * 0.42, horizon), Vector2(w * 0.58, horizon),
        Vector2(w * 0.96, h), Vector2(w * 0.04, h)
    ]), ROAD)
    draw_line(Vector2(w * 0.42, horizon), Vector2(w * 0.04, h), ROAD_EDGE, 2.0)
    draw_line(Vector2(w * 0.58, horizon), Vector2(w * 0.96, h), ROAD_EDGE, 2.0)
    for t in range(7):
        var p := (fmod(_time * 0.045 + float(t) * 0.15, 1.0))
        var y := lerpf(horizon + 8.0, h - 20.0, p * p)
        var half := lerpf(7.0, w * 0.18, p)
        draw_line(Vector2(w * 0.5 - half, y), Vector2(w * 0.5 + half, y), Color(GOLD, 0.16), 2.0)
    draw_line(Vector2(0, road_y), Vector2(w, road_y), Color(ROAD_EDGE, 0.6), 5.0)
    for x in range(30, int(w), 100):
        draw_line(Vector2(x, road_y - 4), Vector2(x + 35, road_y - 4), Color(GOLD, 0.24), 2.0)

func _draw_facilities(w: float, h: float) -> void:
    var anchors := [Vector2(w * 0.17, h * 0.62), Vector2(w * 0.37, h * 0.69), Vector2(w * 0.67, h * 0.61), Vector2(w * 0.84, h * 0.72)]
    _draw_factory(anchors[0], "FACTORY", 1.0)
    _draw_warehouse(anchors[1], 0.92)
    _draw_logistics_hub(anchors[2])
    _draw_research_center(anchors[3])

func _draw_factory(o: Vector2, label: String, scale := 1.0) -> void:
    var s := scale
    draw_rect(Rect2(o.x - 78*s, o.y - 62*s, 156*s, 62*s), BUILDING, true)
    draw_rect(Rect2(o.x - 66*s, o.y - 48*s, 42*s, 35*s), Color("102329"), true)
    draw_rect(Rect2(o.x - 16*s, o.y - 48*s, 42*s, 35*s), Color("102329"), true)
    draw_rect(Rect2(o.x + 34*s, o.y - 48*s, 30*s, 35*s), Color("102329"), true)
    draw_colored_polygon(PackedVector2Array([Vector2(o.x-88*s,o.y-62*s),Vector2(o.x+78*s,o.y-62*s),Vector2(o.x+55*s,o.y-78*s),Vector2(o.x-64*s,o.y-78*s)]), BUILDING_2)
    draw_rect(Rect2(o.x + 43*s, o.y - 104*s, 14*s, 42*s), Color("31474e"), true)
    draw_circle(Vector2(o.x + 50*s, o.y - 110*s), 10*s, Color(0.6,0.72,0.70,0.05))
    _facility_label(o + Vector2(-80, 18), label)

func _draw_warehouse(o: Vector2, scale := 1.0) -> void:
    _draw_factory(o, "WAREHOUSE", scale)
    draw_rect(Rect2(o.x - 24*scale, o.y - 36*scale, 48*scale, 36*scale), Color("0a1519"), true)
    draw_line(Vector2(o.x, o.y-36*scale), Vector2(o.x, o.y), Color("596b70"), 2.0)

func _draw_logistics_hub(o: Vector2) -> void:
    draw_rect(Rect2(o.x - 88, o.y - 58, 176, 58), Color("18323a"), true)
    draw_rect(Rect2(o.x - 70, o.y - 42, 45, 42), Color("0e1d22"), true)
    draw_rect(Rect2(o.x - 20, o.y - 42, 45, 42), Color("0e1d22"), true)
    draw_rect(Rect2(o.x + 30, o.y - 42, 45, 42), Color("0e1d22"), true)
    for i in range(4):
        draw_line(Vector2(o.x - 72 + i*46, o.y-4), Vector2(o.x - 58 + i*46, o.y-4), GOLD, 2.0)
    _facility_label(o + Vector2(-88, 18), "LOGISTICS HUB")

func _draw_research_center(o: Vector2) -> void:
    draw_rect(Rect2(o.x - 70, o.y - 70, 140, 70), Color("19343c"), true)
    draw_colored_polygon(PackedVector2Array([Vector2(o.x-80,o.y-70),Vector2(o.x+80,o.y-70),Vector2(o.x+48,o.y-90),Vector2(o.x-48,o.y-90)]), Color("25434a"))
    for i in range(4):
        draw_rect(Rect2(o.x - 54 + i*30, o.y-48, 20, 24), Color("8bb7b1", 0.18 + 0.08*sin(_time+i)), true)
    _facility_label(o + Vector2(-70, 18), "RESEARCH")

func _facility_label(pos: Vector2, text: String) -> void:
    draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color(MUTED, 0.82))

func _draw_hq(w: float, h: float) -> void:
    var hq := get_node_or_null("/root/Renew/Systems/HeadquartersSystem")
    if hq == null:
        hq = get_node_or_null("/root/RenewHeadquartersSystem")
    var stage := 0
    var stage_name := "Small Office"
    if hq != null:
        if hq.has_method("get_stage_index"): stage = int(hq.get_stage_index())
        if hq.has_method("get_stage"): stage_name = str(hq.get_stage())
    var o := Vector2(w * 0.51, minf(485.0, h * 0.60))
    var height := 62.0 + float(stage) * 48.0
    var width := 100.0 + float(stage) * 24.0
    draw_rect(Rect2(o.x-width*0.5, o.y-height, width, height), Color("1b3540"), true)
    for floor in range(max(2, stage + 2)):
        var fy := o.y - 16.0 - float(floor) * 34.0
        draw_line(Vector2(o.x-width*0.42, fy), Vector2(o.x+width*0.42, fy), Color("3c5961"), 1.0)
        for window in range(4):
            var wx := o.x - width*0.32 + float(window)*width*0.21
            draw_rect(Rect2(wx, fy-17, width*0.12, 12), Color(GLASS, 0.35 + 0.08*float(stage)), true)
    if stage >= 2:
        draw_rect(Rect2(o.x-width*0.62, o.y-16, width*0.16, 16), Color("314a52"), true)
        draw_rect(Rect2(o.x+width*0.46, o.y-28, width*0.16, 28), Color("314a52"), true)
    if stage >= 3:
        draw_rect(Rect2(o.x-width*0.18, o.y-height-32, width*0.36, 32), Color("24434b"), true)
    if stage >= 4:
        draw_line(Vector2(o.x, o.y-height-32), Vector2(o.x, o.y-height-78), GOLD, 3.0)
        draw_circle(Vector2(o.x, o.y-height-82), 5.0, GOLD)
    draw_string(ThemeDB.fallback_font, Vector2(o.x-110, o.y+20), "HEADQUARTERS • %s" % stage_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 220, 10, Color("d7e3e4"))

func _draw_life(w: float, h: float) -> void:
    # Small animated vehicles, workers and landscaping details keep the world alive.
    for i in range(5):
        var p := fmod(_time * (0.018 + i * 0.003) + float(i) * 0.19, 1.0)
        var x := lerpf(-40.0, w + 40.0, p)
        var y := minf(535.0, h * 0.68) + float(i % 2) * 12.0
        draw_rect(Rect2(x, y-4, 18, 7), Color("d2a95f", 0.7), true)
        draw_circle(Vector2(x+4,y+4), 3, Color("071116"))
        draw_circle(Vector2(x+15,y+4), 3, Color("071116"))
    for i in range(12):
        var x := 18.0 + float((i * 97) % max(120, int(w-30)))
        var y := minf(610.0, h * 0.78) + float((i * 31) % 50)
        draw_line(Vector2(x,y), Vector2(x,y-12), Color("315f4d", 0.8), 3.0)
        draw_circle(Vector2(x,y-15), 7.0, Color("29523f", 0.75))

func _draw_region_map(w: float, h: float) -> void:
    var regions_node := get_node_or_null("/root/Renew/World/RegionController")
    if regions_node == null or not "regions" in regions_node:
        return
    var data = regions_node.regions
    if data == null or not "regions" in data:
        return
    var regions: Array = data.regions
    if regions.is_empty():
        return
    var panel := Rect2(18, 86, minf(300.0, w-36.0), minf(126.0, h*0.22))
    draw_rect(panel, Color(0.035,0.07,0.08,0.90), true)
    draw_rect(panel, Color("34545a"), false, 1.0)
    draw_string(ThemeDB.fallback_font, panel.position+Vector2(12,22), "REGIONAL OPERATING MAP", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x-24, 12, Color("d7e3e4"))
    var selected := int(data.selected)
    for i in range(regions.size()):
        var cols := 3
        var cell_w := (panel.size.x-28)/float(cols)
        var row := i/cols
        var col := i%cols
        var pos := panel.position+Vector2(10+col*cell_w, 34+row*38)
        var active := i == selected
        var unlocked := bool(regions[i].get("unlocked", false))
        draw_circle(pos+Vector2(8,0), 5.0 if active else 3.5, Color(GOLD if active else GREEN, 0.9 if unlocked else 0.25))
        draw_string(ThemeDB.fallback_font, pos+Vector2(18,4), str(regions[i].get("name", "Region")), HORIZONTAL_ALIGNMENT_LEFT, cell_w-20, 9, Color("d7e3e4") if unlocked else Color("61777d"))
        if i < regions.size()-1:
            draw_line(pos+Vector2(14,10), pos+Vector2(cell_w-6,10), Color("29434a",0.7), 1.0)
