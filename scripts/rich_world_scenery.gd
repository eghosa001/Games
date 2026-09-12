extends Node2D
## Premium presentation-only isometric business district for RENEW.
## This layer reads authoritative game state only to vary presentation; it never
## owns or mutates simulation state. The goal is a dense, legible management-game
## world that remains attractive behind every HUD layout.

const SKY_TOP := Color("0b1720")
const SKY_BOTTOM := Color("18343b")
const GROUND := Color("d8d1bd")
const GROUND_ALT := Color("c7c1ae")
const ROAD := Color("26383e")
const ROAD_EDGE := Color("6c8587")
const WALL_LIGHT := Color("f1ead8")
const WALL_MID := Color("cbbda1")
const WALL_DARK := Color("8c806c")
const GLASS := Color("77bdc0")
const GLASS_DARK := Color("356b72")
const GOLD := Color("e0b85f")
const GREEN := Color("5f9f72")
const GREEN_LIGHT := Color("87bf8a")
const TERRACOTTA := Color("b9684e")
const INK := Color("173039")
const MUTED := Color("6e7f7f")
const PAPER := Color("f4efe2")
const WHITE := Color("fffdf7")

var _time := 0.0
var _redraw_clock := 0.0

func _ready() -> void:
    # Above the legacy authored SVG backdrop, below interactive world/property layers.
    z_index = -24
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    _redraw_clock += delta
    # 4Hz is enough for ambient life without turning the backdrop into a frame-time hog.
    if _redraw_clock >= 0.25:
        _redraw_clock = 0.0
        queue_redraw()

func _draw() -> void:
    var viewport := get_viewport_rect().size
    var w := maxf(viewport.x, 360.0)
    var h := maxf(viewport.y, 568.0)
    var compact := w < 720.0
    _draw_skyline(w, h)
    _draw_island(w, h, compact)
    _draw_business_campus(w, h, compact)
    _draw_industry_strip(w, h, compact)
    _draw_public_realm(w, h, compact)
    _draw_city_life(w, h, compact)
    _draw_world_badges(w, h, compact)

func _draw_skyline(w: float, h: float) -> void:
    var horizon := h * 0.31
    draw_rect(Rect2(0, 0, w, h), SKY_TOP, true)
    for i in range(7):
        var y0 := float(i) * horizon / 7.0
        var c := SKY_TOP.lerp(SKY_BOTTOM, float(i + 1) / 7.0)
        draw_rect(Rect2(0, y0, w, horizon / 7.0 + 1.0), c, true)
    _glow(Vector2(w * 0.80, horizon * 0.36), minf(w * 0.30, 260.0), Color("e0b85f"), 0.08)
    _glow(Vector2(w * 0.20, horizon * 0.55), minf(w * 0.24, 210.0), Color("5ab0a2"), 0.07)

    var step := maxf(42.0, w / 21.0)
    for i in range(24):
        var x := float(i) * step - 24.0
        var bh := 36.0 + float((i * 47) % 125)
        var bw := step - 8.0
        var tone := Color("213d45") if i % 3 else Color("284b50")
        draw_rect(Rect2(x, horizon - bh, bw, bh), tone, true)
        draw_rect(Rect2(x, horizon - bh, bw, 3), Color(GOLD.r, GOLD.g, GOLD.b, 0.24), true)
        for wy in range(int(horizon - bh + 12.0), int(horizon - 8.0), 17):
            if (wy / 17 + i) % 3 != 0:
                draw_rect(Rect2(x + 8, wy, 4, 4), Color("f4d889", 0.34), true)
                if bw > 30:
                    draw_rect(Rect2(x + bw - 13, wy, 4, 4), Color("8ac7c2", 0.24), true)
    draw_rect(Rect2(0, horizon - 2.0, w, 5.0), Color("9ac6bd", 0.12), true)

func _draw_island(w: float, h: float, compact: bool) -> void:
    var top := h * (0.31 if compact else 0.30)
    var bottom := h * 0.97
    var cx := w * 0.5
    var half_top := w * (0.46 if compact else 0.42)
    var half_bottom := w * (0.62 if compact else 0.54)
    var island := PackedVector2Array([
        Vector2(cx - half_top, top), Vector2(cx + half_top, top),
        Vector2(cx + half_bottom, bottom), Vector2(cx - half_bottom, bottom)
    ])
    draw_colored_polygon(island, GROUND)
    draw_polyline(PackedVector2Array([island[0], island[1], island[2], island[3], island[0]]), Color("fff5db", 0.30), 2.0)

    var road_y := lerpf(top, bottom, 0.62)
    draw_colored_polygon(PackedVector2Array([
        Vector2(cx - half_top * 0.98, road_y - 31), Vector2(cx + half_top * 0.98, road_y - 31),
        Vector2(cx + half_bottom * 0.93, road_y + 38), Vector2(cx - half_bottom * 0.93, road_y + 38)
    ]), ROAD)
    draw_line(Vector2(cx - half_top, road_y - 31), Vector2(cx + half_top, road_y - 31), ROAD_EDGE, 2.0)
    draw_line(Vector2(cx - half_bottom, road_y + 38), Vector2(cx + half_bottom, road_y + 38), ROAD_EDGE, 2.0)
    for x in range(int(cx - half_top + 30), int(cx + half_top - 20), 78):
        draw_line(Vector2(x, road_y + 3), Vector2(x + 35, road_y + 3), Color(GOLD.r, GOLD.g, GOLD.b, 0.70), 2.0)

    # Perspective avenue feeding the campus.
    draw_colored_polygon(PackedVector2Array([
        Vector2(cx - 39, top + 5), Vector2(cx + 39, top + 5),
        Vector2(cx + 108, bottom), Vector2(cx - 108, bottom)
    ]), Color("31474d"))
    for i in range(7):
        var t := float(i + 1) / 8.0
        var y := lerpf(top, bottom, t * t)
        var width := lerpf(30.0, 82.0, t)
        draw_line(Vector2(cx - width * 0.18, y), Vector2(cx + width * 0.18, y), Color("d9c67f", 0.48), 2.0)

func _draw_business_campus(w: float, h: float, compact: bool) -> void:
    var center := Vector2(w * 0.50, h * (0.48 if compact else 0.49))
    var s := clampf(w / 1280.0, 0.62, 1.10)
    if compact:
        s *= 0.90

    # Main open-plan HQ floor: an isometric slab with visible interior zones.
    var floor_center := center + Vector2(0, 38 * s)
    _iso_plate(floor_center, 430 * s, 210 * s, 16 * s, Color("e7dfc9"), Color("b8aa8e"))
    _iso_grid(floor_center, 392 * s, 180 * s, 54 * s)

    # Perimeter glass offices and central strategy room.
    _iso_room(center + Vector2(-165, -4) * s, Vector2(112, 72) * s, 43 * s, Color("e9e4d8"), Color("b8cdd0"), "FINANCE", s)
    _iso_room(center + Vector2(165, -4) * s, Vector2(112, 72) * s, 43 * s, Color("e9e4d8"), Color("9bc5bc"), "PRODUCT", s)
    _iso_room(center + Vector2(0, -64) * s, Vector2(132, 68) * s, 48 * s, Color("f0e8d7"), Color("d6a66d"), "STRATEGY", s)

    # Open office desk clusters.
    for row in range(2):
        for col in range(4):
            var p := center + Vector2((-120 + col * 80), (48 + row * 58)) * s
            _desk_cluster(p, s, (row * 4 + col) % 4)

    # Reception / lounge and branded collaboration islands.
    _lounge(center + Vector2(-150, 112) * s, s)
    _collaboration(center + Vector2(145, 110) * s, s)
    _brand_monument(center + Vector2(0, -145) * s, s)

    # Executive tower gives the whole composition a recognizable silhouette.
    _iso_tower(center + Vector2(0, -185) * s, Vector2(126, 72) * s, 138 * s, s)

func _draw_industry_strip(w: float, h: float, compact: bool) -> void:
    var s := clampf(w / 1280.0, 0.60, 1.05)
    var y := h * (0.79 if compact else 0.80)
    _iso_factory(Vector2(w * 0.19, y), s * 0.92, "MANUFACTURING")
    _iso_warehouse(Vector2(w * 0.38, y + 18 * s), s * 0.86, "LOGISTICS")
    _iso_research(Vector2(w * 0.68, y + 2 * s), s * 0.90, "RESEARCH")
    _iso_storefront(Vector2(w * 0.84, y + 22 * s), s * 0.84, "RETAIL")

func _draw_public_realm(w: float, h: float, compact: bool) -> void:
    var s := clampf(w / 1280.0, 0.60, 1.1)
    var park_y := h * 0.66
    # Landscaped islands, benches and street lighting keep the world from feeling like panels on a void.
    for i in range(9):
        var x := w * (0.08 + 0.105 * i)
        var y := park_y + float(i % 2) * 18 * s
        _tree(Vector2(x, y), s * (0.82 + 0.08 * (i % 3)))
    for i in range(6):
        var x := w * (0.14 + 0.145 * i)
        _street_lamp(Vector2(x, h * 0.705), s)
    _fountain(Vector2(w * 0.50, h * 0.69), s)

func _draw_city_life(w: float, h: float, compact: bool) -> void:
    var s := clampf(w / 1280.0, 0.62, 1.0)
    var routes := [
        [Vector2(w*0.16,h*0.62), Vector2(w*0.39,h*0.58)],
        [Vector2(w*0.64,h*0.62), Vector2(w*0.84,h*0.58)],
        [Vector2(w*0.28,h*0.86), Vector2(w*0.46,h*0.76)],
        [Vector2(w*0.72,h*0.84), Vector2(w*0.56,h*0.74)]
    ]
    for i in range(routes.size()):
        var t := fmod(_time * (0.045 + 0.007 * i) + float(i) * 0.21, 1.0)
        var a: Vector2 = routes[i][0]
        var b: Vector2 = routes[i][1]
        var p := a.lerp(b, t)
        _person(p, s * (0.86 + 0.05 * i), i)

    # Delivery vans on the cross road.
    for i in range(3):
        var t := fmod(_time * (0.055 + i * 0.006) + i * 0.31, 1.0)
        var x := lerpf(w * 0.10, w * 0.90, t if i % 2 == 0 else 1.0 - t)
        _vehicle(Vector2(x, h * 0.625 + i * 7), s * 0.82, i)

func _draw_world_badges(w: float, h: float, compact: bool) -> void:
    if compact:
        return
    var state := get_tree().root.get_node_or_null("RenewGameState")
    var day := 1
    var cash := 0
    if state != null and state.has_method("get_value"):
        day = int(state.get_value("player", "day", 1))
        cash = int(state.get_value("economy", "cash", 0))
    _badge(Vector2(24, h - 76), "RENEW CITY", "DAY %d" % day)
    _badge(Vector2(w - 220, h - 76), "ENTERPRISE VALUE", "$%s" % _compact_number(cash))

func _iso_plate(center: Vector2, width: float, depth: float, height: float, top: Color, side: Color) -> void:
    var hw := width * 0.5
    var hd := depth * 0.5
    var top_poly := PackedVector2Array([
        center + Vector2(0, -hd), center + Vector2(hw, 0),
        center + Vector2(0, hd), center + Vector2(-hw, 0)
    ])
    var left := PackedVector2Array([top_poly[3], top_poly[2], top_poly[2] + Vector2(0,height), top_poly[3] + Vector2(0,height)])
    var right := PackedVector2Array([top_poly[1], top_poly[2], top_poly[2] + Vector2(0,height), top_poly[1] + Vector2(0,height)])
    draw_colored_polygon(left, side.darkened(0.14))
    draw_colored_polygon(right, side.darkened(0.28))
    draw_colored_polygon(top_poly, top)
    draw_polyline(PackedVector2Array([top_poly[0],top_poly[1],top_poly[2],top_poly[3],top_poly[0]]), Color("fffaf0",0.45), 1.5)

func _iso_grid(center: Vector2, width: float, depth: float, spacing: float) -> void:
    var hw := width * 0.5
    var hd := depth * 0.5
    var lines := int(width / spacing)
    for i in range(1, lines):
        var t := float(i) / float(lines)
        var x := lerpf(-hw, hw, t)
        draw_line(center + Vector2(x, -hd + abs(x) * depth / width), center + Vector2(x, hd - abs(x) * depth / width), Color("7f7767",0.12), 1.0)

func _iso_room(center: Vector2, footprint: Vector2, wall_h: float, wall: Color, accent: Color, label: String, s: float) -> void:
    _iso_plate(center, footprint.x, footprint.y, 5*s, wall.lightened(0.05), WALL_MID)
    var hw := footprint.x * 0.5
    var hd := footprint.y * 0.5
    var back_left := center + Vector2(-hw, 0)
    var back_top := center + Vector2(0, -hd)
    var back_right := center + Vector2(hw, 0)
    draw_colored_polygon(PackedVector2Array([back_left,back_top,back_top+Vector2(0,-wall_h),back_left+Vector2(0,-wall_h)]), wall.darkened(0.08))
    draw_colored_polygon(PackedVector2Array([back_top,back_right,back_right+Vector2(0,-wall_h),back_top+Vector2(0,-wall_h)]), wall.darkened(0.18))
    draw_line(back_left+Vector2(0,-wall_h), back_top+Vector2(0,-wall_h), accent, 2*s)
    draw_line(back_top+Vector2(0,-wall_h), back_right+Vector2(0,-wall_h), accent, 2*s)
    # glass strips
    draw_line(back_left.lerp(back_top,0.25)+Vector2(0,-wall_h*0.55), back_left.lerp(back_top,0.82)+Vector2(0,-wall_h*0.55), Color(accent.r,accent.g,accent.b,0.55), 5*s)
    draw_line(back_top.lerp(back_right,0.18)+Vector2(0,-wall_h*0.55), back_top.lerp(back_right,0.76)+Vector2(0,-wall_h*0.55), Color(accent.r,accent.g,accent.b,0.45), 5*s)
    draw_string(ThemeDB.fallback_font, center + Vector2(-footprint.x*0.26, footprint.y*0.18), label, HORIZONTAL_ALIGNMENT_LEFT, footprint.x*0.62, maxi(7,int(9*s)), Color(INK.r,INK.g,INK.b,0.74))

func _desk_cluster(p: Vector2, s: float, variant: int) -> void:
    var wood: Color = [Color("b9865c"),Color("a67658"),Color("c39b69"),Color("93735c")][variant]
    _iso_plate(p, 52*s, 26*s, 4*s, wood, wood.darkened(0.22))
    # monitors
    draw_rect(Rect2(p + Vector2(-9,-19)*s, Vector2(18,10)*s), Color("19343b"), true)
    draw_rect(Rect2(p + Vector2(11,-15)*s, Vector2(13,8)*s), Color("265a62"), true)
    draw_line(p+Vector2(0,-9)*s, p+Vector2(0,-2)*s, Color("4b5b59"), 2*s)
    # chairs + people
    draw_circle(p + Vector2(-14,19)*s, 7*s, Color("31464a"))
    _person(p + Vector2(14,15)*s, s*0.72, variant)

func _lounge(p: Vector2, s: float) -> void:
    _iso_plate(p, 116*s, 64*s, 4*s, Color("d6c7aa"), Color("9c8d75"))
    _iso_plate(p+Vector2(-26,4)*s, 44*s, 24*s, 8*s, Color("5f8079"), Color("3f5d58"))
    _iso_plate(p+Vector2(30,4)*s, 44*s, 24*s, 8*s, Color("7e6d66"), Color("574b47"))
    _plant(p+Vector2(0,-18)*s,s)

func _collaboration(p: Vector2, s: float) -> void:
    _iso_plate(p, 120*s, 70*s, 4*s, Color("e1d5bb"), Color("a89b81"))
    draw_circle(p, 24*s, Color("c7995d"))
    draw_circle(p, 15*s, Color("eadfca"))
    for i in range(5):
        var a := TAU * float(i)/5.0
        draw_circle(p+Vector2(cos(a),sin(a))*34*s, 7*s, Color("39565b"))

func _brand_monument(p: Vector2, s: float) -> void:
    draw_circle(p, 28*s, Color("14333b",0.92))
    draw_circle(p, 20*s, Color("275960"))
    draw_arc(p, 14*s, -PI*0.8, PI*0.8, 22, GOLD, 4*s)
    draw_line(p+Vector2(-8,6)*s,p+Vector2(8,-6)*s,Color("f4e1a0"),3*s)

func _iso_tower(p: Vector2, footprint: Vector2, height: float, s: float) -> void:
    var hw := footprint.x*0.5
    var hd := footprint.y*0.5
    var roof := PackedVector2Array([p+Vector2(0,-hd-height),p+Vector2(hw,-height),p+Vector2(0,hd-height),p+Vector2(-hw,-height)])
    var left := PackedVector2Array([p+Vector2(-hw,0),p+Vector2(0,hd),roof[2],roof[3]])
    var right := PackedVector2Array([p+Vector2(hw,0),p+Vector2(0,hd),roof[2],roof[1]])
    draw_colored_polygon(left, Color("25464d"))
    draw_colored_polygon(right, Color("17373f"))
    draw_colored_polygon(roof, Color("50767a"))
    for i in range(5):
        var yy := -18.0 - i*21.0
        draw_line(p+Vector2(-hw*0.82,yy),p+Vector2(-4,hd*0.72+yy),Color("8fd0cb",0.38),3*s)
        draw_line(p+Vector2(hw*0.82,yy),p+Vector2(4,hd*0.72+yy),Color("5ca7ad",0.30),3*s)
    draw_line(roof[3],roof[0],GOLD,2*s)
    draw_line(roof[0],roof[1],GOLD,2*s)
    draw_string(ThemeDB.fallback_font,p+Vector2(-28,-height*0.52),"RENEW",HORIZONTAL_ALIGNMENT_CENTER,56*s,maxi(9,int(12*s)),Color("f6e7b0"))

func _iso_factory(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p, 168*s, 82*s, 12*s, Color("c8b997"), Color("81765f"))
    _iso_room(p+Vector2(-18,-18)*s,Vector2(128,58)*s,46*s,Color("c2aa86"),TERRACOTTA,label,s)
    for i in range(3):
        var stack := p+Vector2(45+i*18,-55-i*4)*s
        draw_rect(Rect2(stack-Vector2(5,34)*s,Vector2(10,34)*s),Color("6e665b"),true)
        draw_circle(stack-Vector2(0,38)*s,5*s,Color("d2d4c7",0.16))

func _iso_warehouse(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p,158*s,76*s,10*s,Color("d4c8ae"),Color("8f836d"))
    _iso_room(p+Vector2(0,-12)*s,Vector2(132,58)*s,36*s,Color("d0c1a6"),Color("6e9d9d"),label,s)
    for i in range(3):
        draw_rect(Rect2(p+Vector2(-42+i*34,-7)*s,Vector2(24,18)*s),Color("30484a"),true)

func _iso_research(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p,150*s,80*s,10*s,Color("d9d7c8"),Color("9a9686"))
    _iso_room(p+Vector2(0,-18)*s,Vector2(122,60)*s,52*s,Color("dbe4df"),GLASS,label,s)
    draw_circle(p+Vector2(44,-68)*s,10*s,Color("79c6b8",0.42))

func _iso_storefront(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p,142*s,72*s,9*s,Color("d9c8aa"),Color("96846b"))
    _iso_room(p+Vector2(0,-13)*s,Vector2(116,55)*s,38*s,Color("d9c3a6"),TERRACOTTA,label,s)
    draw_rect(Rect2(p+Vector2(-24,-28)*s,Vector2(48,20)*s),Color("2d5960",0.88),true)

func _tree(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p+Vector2(-2,0)*s,Vector2(4,18)*s),Color("76543c"),true)
    draw_circle(p+Vector2(0,-6)*s,15*s,GREEN)
    draw_circle(p+Vector2(-9,-2)*s,9*s,GREEN_LIGHT)
    draw_circle(p+Vector2(8,-3)*s,10*s,Color("4f8c63"))

func _plant(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p+Vector2(-7,4)*s,Vector2(14,9)*s),Color("a96e4f"),true)
    for i in range(5):
        var a := -PI*0.85+float(i)*PI*0.42
        draw_line(p+Vector2(0,4)*s,p+Vector2(cos(a),sin(a))*17*s,GREEN_LIGHT,3*s)

func _street_lamp(p: Vector2, s: float) -> void:
    draw_line(p,p+Vector2(0,-32)*s,Color("546164"),2*s)
    draw_circle(p+Vector2(0,-34)*s,4*s,Color("ffe6a5",0.88))
    _glow(p+Vector2(0,-34)*s,14*s,Color("ffd67a"),0.12)

func _fountain(p: Vector2, s: float) -> void:
    draw_ellipse(p,34*s,15*s,Color("8caeaa"),Color("507a78"))
    draw_circle(p,8*s,Color("d9e4db"))
    draw_line(p,p+Vector2(0,-18)*s,Color("a4d6d3",0.65),2*s)
    draw_circle(p+Vector2(0,-18)*s,3*s,Color("d6f4ef",0.85))

func draw_ellipse(center: Vector2, rx: float, ry: float, fill: Color, edge: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(25):
        var a := TAU*float(i)/24.0
        pts.append(center+Vector2(cos(a)*rx,sin(a)*ry))
    draw_colored_polygon(pts,fill)
    draw_polyline(pts,edge,1.5)

func _person(p: Vector2, s: float, variant: int) -> void:
    var shirts: Array[Color] = [Color("d36d55"),Color("527aa3"),Color("d7a846"),Color("5a9d82"),Color("8b6f9e")]
    var skins: Array[Color] = [Color("6d402c"),Color("9a6448"),Color("c48b68"),Color("5d3829")]
    var skin: Color = skins[variant%skins.size()]
    var shirt: Color = shirts[variant%shirts.size()]
    draw_circle(p+Vector2(0,-12)*s,4.2*s,skin)
    draw_line(p+Vector2(0,-7)*s,p+Vector2(0,5)*s,shirt,5*s)
    draw_line(p+Vector2(0,4)*s,p+Vector2(-5,12)*s,Color("26373c"),2*s)
    draw_line(p+Vector2(0,4)*s,p+Vector2(5,12)*s,Color("26373c"),2*s)

func _vehicle(p: Vector2, s: float, variant: int) -> void:
    var cols: Array[Color] = [Color("d8b65d"),Color("6da7a0"),Color("c76d59")]
    var c: Color = cols[variant%cols.size()]
    _iso_plate(p,44*s,22*s,6*s,c,c.darkened(0.25))
    draw_rect(Rect2(p+Vector2(-10,-11)*s,Vector2(20,7)*s),Color("21464e"),true)
    draw_circle(p+Vector2(-13,9)*s,4*s,Color("142126"))
    draw_circle(p+Vector2(13,9)*s,4*s,Color("142126"))

func _badge(pos: Vector2, title: String, value: String) -> void:
    var r := Rect2(pos,Vector2(196,52))
    draw_rect(r,Color("0b181d",0.82),true)
    draw_rect(r,Color("6f918f",0.38),false,1.0)
    draw_string(ThemeDB.fallback_font,pos+Vector2(12,18),title,HORIZONTAL_ALIGNMENT_LEFT,170,9,Color("a9bcba"))
    draw_string(ThemeDB.fallback_font,pos+Vector2(12,39),value,HORIZONTAL_ALIGNMENT_LEFT,170,13,Color("f2d98b"))

func _glow(center: Vector2, radius: float, tint: Color, strength: float) -> void:
    for i in range(5,0,-1):
        var r := radius*float(i)/5.0
        var a := strength*(1.0-float(i)/6.0)
        draw_circle(center,r,Color(tint.r,tint.g,tint.b,a))

func _compact_number(value: int) -> String:
    var n := abs(value)
    if n >= 1000000000:
        return "%.1fB" % (float(value)/1000000000.0)
    if n >= 1000000:
        return "%.1fM" % (float(value)/1000000.0)
    if n >= 1000:
        return "%.1fK" % (float(value)/1000.0)
    return str(value)