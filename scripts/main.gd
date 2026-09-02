extends Node2D

var cash := 25000
var reputation := 0
var restoration := 0
var stage := "Neglected"
var inspected := false
var property_name := "Old Warehouse"
var day := 1
var revenue := 0

var stages = [
    ["Neglected", 0, 0],
    ["Cleaned", 20, 1500],
    ["Repaired", 40, 3000],
    ["Rebuilt", 60, 4500],
    ["Installed", 80, 6000],
    ["Designed", 100, 7500]
]

func _ready():
    queue_redraw()

func _process(_delta):
    queue_redraw()

func _input(event):
    if event.is_action_pressed("action_inspect"):
        inspected = true
        queue_redraw()
    if event.is_action_pressed("action_restore"):
        restore_property()

func restore_property():
    if not inspected:
        return
    var next_index = 0
    for i in stages.size():
        if stages[i][0] == stage:
            next_index = i + 1
            break
    if next_index >= stages.size():
        if stage != "Operational":
            stage = "Operational"
            reputation += 10
        revenue = 3500
        cash += revenue
        day += 1
        return
    var cost = stages[next_index][2]
    if cash < cost:
        return
    cash -= cost
    restoration = stages[next_index][1]
    stage = stages[next_index][0]
    reputation += 2
    if restoration == 100:
        stage = "Operational"
        revenue = 3500
        reputation += 10
    queue_redraw()

func _draw():
    draw_rect(Rect2(0, 0, 1280, 720), Color("10151c"))
    draw_rect(Rect2(0, 0, 1280, 76), Color("18232d"))
    draw_string(ThemeDB.fallback_font, Vector2(40, 48), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(180, 46), "DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font, Vector2(430, 46), "CASH  $%s" % _money(cash), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(760, 46), "REPUTATION  %d" % reputation, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f2d27a"))

    draw_string(ThemeDB.fallback_font, Vector2(60, 135), "YOUR FIRST ASSET", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font, Vector2(60, 180), property_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(60, 220), "A neglected property with potential.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("b4bec8"))

    draw_rect(Rect2(60, 270, 700, 250), Color("222e38"), true)
    draw_rect(Rect2(90, 300, 640, 160), Color("35434f"), true)
    draw_rect(Rect2(150, 350, 520, 80), Color("4a3d34"), true)
    draw_string(ThemeDB.fallback_font, Vector2(270, 395), "ABANDONED WAREHOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d6c3a5"))

    draw_string(ThemeDB.fallback_font, Vector2(820, 135), "PROPERTY STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font, Vector2(820, 180), stage, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("8ee6a8"))
    draw_rect(Rect2(820, 210, 360, 18), Color("293640"), true)
    draw_rect(Rect2(820, 210, 360 * restoration / 100.0, 18), Color("5bc47a"), true)
    draw_string(ThemeDB.fallback_font, Vector2(820, 260), "%d%% restored" % restoration, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

    var next_cost = _next_cost()
    if stage != "Operational":
        draw_string(ThemeDB.fallback_font, Vector2(820, 320), "NEXT RESTORATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9fb3c8"))
        draw_string(ThemeDB.fallback_font, Vector2(820, 355), "$%s" % _money(next_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f2d27a"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(820, 320), "BUSINESS IS OPERATING", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8ee6a8"))
        draw_string(ThemeDB.fallback_font, Vector2(820, 355), "+$3,500 / cycle", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("8ee6a8"))

    draw_string(ThemeDB.fallback_font, Vector2(60, 600), "[I] Inspect property", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(340, 600), "[R] Restore next stage", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
    if not inspected:
        draw_string(ThemeDB.fallback_font, Vector2(60, 650), "Inspect the property before spending money on restoration.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f2d27a"))
    elif stage == "Operational":
        draw_string(ThemeDB.fallback_font, Vector2(60, 650), "Your first business is alive. Next: customers, suppliers and competition.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8ee6a8"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(60, 650), "Restore carefully. Every upgrade consumes capital but increases future value.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b4bec8"))

func _next_cost():
    for item in stages:
        if item[0] == stage:
            var idx = stages.find(item)
            if idx + 1 < stages.size():
                return stages[idx + 1][2]
            return 0
    return 0

func _money(value):
    return "%,d" % value
