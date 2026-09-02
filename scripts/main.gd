extends Node2D

# RENEW Prototype 02
# Discover -> Inspect -> Acquire -> Restore -> Operate -> Earn -> Reinvest

var cash: int = 25000
var reputation: int = 0
var day: int = 1
var property_cost: int = 5000
var owned: bool = false
var inspected: bool = false
var property_name := "Old Warehouse"
var property_type := "Warehouse"
var restoration: int = 0
var stage := "Neglected"
var revenue: int = 0
var operating_cost: int = 0
var business_open: bool = false
var employees: int = 0
var inventory: int = 0
var customer_demand: int = 70
var competitor_price: int = 120
var player_price: int = 110
var message := "Inspect the property to reveal its potential."
var event_log: Array[String] = []

var stages = [
    ["Neglected", 0, 0],
    ["Cleaned", 20, 1500],
    ["Repaired", 40, 3000],
    ["Rebuilt", 60, 4500],
    ["Installed", 80, 6000],
    ["Designed", 100, 7500]
]

func _ready() -> void:
    _log("You found an abandoned warehouse. It could become your first business.")
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_I: inspect_property()
            KEY_A: acquire_property()
            KEY_R: restore_property()
            KEY_O: open_business()
            KEY_N: advance_day()
            KEY_P: change_price()

func inspect_property() -> void:
    inspected = true
    message = "Inspection complete: low acquisition cost, strong local demand, moderate renovation risk."
    _log("Inspection: $5,000 acquisition. Estimated restoration: $26,500. Potential daily sales are strong.")

func acquire_property() -> void:
    if not inspected:
        message = "Inspect the property first."
        return
    if owned:
        message = "You already own this property."
        return
    if cash < property_cost:
        message = "Not enough cash to acquire the property."
        return
    cash -= property_cost
    owned = true
    reputation += 2
    message = "Acquired! This neglected warehouse is now yours."
    _log("Acquired Old Warehouse for $5,000.")

func restore_property() -> void:
    if not owned:
        message = "Acquire the property before restoring it."
        return
    if stage == "Operational":
        message = "The property is fully restored. Open a business or advance the day."
        return
    var next_index := 0
    for i in range(stages.size()):
        if stages[i][0] == stage:
            next_index = i + 1
            break
    if next_index >= stages.size():
        return
    var next_stage: String = stages[next_index][0]
    var cost: int = stages[next_index][2]
    if cash < cost:
        message = "You need $%s for the %s stage." % [_money(cost), next_stage]
        return
    cash -= cost
    restoration = stages[next_index][1]
    stage = next_stage
    reputation += 2
    message = "%s complete. The warehouse is visibly improving." % stage
    _log("Restoration: %s (-$%s)." % [stage, _money(cost)])
    if restoration >= 100:
        stage = "Operational"
        restoration = 100
        reputation += 8
        message = "Restoration complete! You turned an abandoned building into an asset."
        _log("RESTORATION COMPLETE. You can now open a business here.")

func open_business() -> void:
    if not owned or stage != "Operational":
        message = "Finish restoration before opening the business."
        return
    if business_open:
        message = "The warehouse business is already operating."
        return
    if cash < 3000:
        message = "You need $3,000 working capital to open."
        return
    cash -= 3000
    business_open = true
    employees = 3
    inventory = 20
    customer_demand = 70
    operating_cost = 900
    message = "Business opened! Hire wisely, manage prices and survive the market."
    _log("Opened RENEW Goods, a small consumer-goods operation. 3 employees hired.")

func change_price() -> void:
    if not business_open:
        message = "Open the business first."
        return
    player_price += 10
    if player_price > 160:
        player_price = 80
    message = "Selling price changed to $%s." % _money(player_price)
    _log("You changed your selling price to $%s." % _money(player_price))

func advance_day() -> void:
    if not business_open:
        message = "There is no operating business yet."
        return
    var price_factor := clamp(float(competitor_price - player_price) / 40.0, -0.6, 0.7)
    var units_sold: int = clamp(int(customer_demand * (0.65 + price_factor)), 5, 70)
    units_sold = min(units_sold, inventory)
    var sales: int = units_sold * player_price
    var costs: int = operating_cost + units_sold * 45
    var profit: int = sales - costs
    cash += profit
    revenue = sales
    inventory -= units_sold
    if inventory < 15:
        inventory += 25
        cash -= 25 * 55
        _log("Restocked 25 units from your supplier (-$1,375).")
    day += 1
    _competitor_turn()
    if profit >= 0:
        reputation += 1
        message = "Day %d closed: +$%s profit. Customers are responding to your price." % [day, _money(profit)]
    else:
        reputation = max(0, reputation - 1)
        message = "Day %d closed: -$%s loss. Your business needs attention." % [day, _money(abs(profit))]
    _log("Day %d P&L: sales $%s | costs $%s | profit $%s." % [day, _money(sales), _money(costs), _money(profit)])

func _competitor_turn() -> void:
    if day % 3 == 0:
        competitor_price = max(85, competitor_price - 5)
        _log("NEWS: The Giant lowered its market price to $%s." % _money(competitor_price))
        message += " The Giant is putting pressure on your market."
    elif day % 4 == 0:
        competitor_price = min(150, competitor_price + 10)
        _log("NEWS: Supply tightened across the district; competitor prices rose.")

func _log(text: String) -> void:
    event_log.push_front("DAY %d  %s" % [day, text])
    if event_log.size() > 4:
        event_log.pop_back()

func _next_cost() -> int:
    for i in range(stages.size()):
        if stages[i][0] == stage and i + 1 < stages.size():
            return stages[i + 1][2]
    return 0

func _money(value: int) -> String:
    return "%,d" % value

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("0e141b"))
    draw_rect(Rect2(0, 0, 1280, 72), Color("18232d"))
    draw_string(ThemeDB.fallback_font, Vector2(36, 46), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(180, 44), "DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font, Vector2(330, 44), "CASH  $%s" % _money(cash), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(570, 44), "REPUTATION  %d" % reputation, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f2d27a"))
    draw_string(ThemeDB.fallback_font, Vector2(820, 44), "MARKET  %s $%s" % [property_type, _money(competitor_price)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b4bec8"))

    # Property card
    draw_rect(Rect2(34, 98, 720, 390), Color("1b2731"), true)
    draw_string(ThemeDB.fallback_font, Vector2(60, 132), "YOUR FIRST ASSET", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("7f98ad"))
    draw_string(ThemeDB.fallback_font, Vector2(60, 170), property_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(60, 198), "%s • Acquisition $5,000" % property_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("a9b6c2"))

    _draw_warehouse(Vector2(60, 225))

    draw_string(ThemeDB.fallback_font, Vector2(500, 245), "STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7f98ad"))
    draw_string(ThemeDB.fallback_font, Vector2(500, 278), stage, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("8ee6a8"))
    draw_rect(Rect2(500, 300, 220, 14), Color("2a3944"), true)
    draw_rect(Rect2(500, 300, 220.0 * restoration / 100.0, 14), Color("5bc47a"), true)
    draw_string(ThemeDB.fallback_font, Vector2(500, 340), "%d%% restored" % restoration, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
    if not owned:
        draw_string(ThemeDB.fallback_font, Vector2(500, 375), "ACQUISITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7f98ad"))
        draw_string(ThemeDB.fallback_font, Vector2(500, 402), "$5,000", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f2d27a"))
    elif stage != "Operational":
        draw_string(ThemeDB.fallback_font, Vector2(500, 375), "NEXT UPGRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7f98ad"))
        draw_string(ThemeDB.fallback_font, Vector2(500, 402), "$%s" % _money(_next_cost()), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f2d27a"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(500, 375), "BUSINESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7f98ad"))
        draw_string(ThemeDB.fallback_font, Vector2(500, 402), "OPEN" if business_open else "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("8ee6a8"))

    # Business card
    draw_rect(Rect2(774, 98, 472, 390), Color("1b2731"), true)
    draw_string(ThemeDB.fallback_font, Vector2(800, 132), "COMPANY OPERATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("7f98ad"))
    if business_open:
        draw_string(ThemeDB.fallback_font, Vector2(800, 170), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(800, 210), "Employees     %d" % employees, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d4dce2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 240), "Inventory     %d units" % inventory, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d4dce2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 270), "Your price    $%s" % _money(player_price), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d4dce2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 300), "Rival price   $%s" % _money(competitor_price), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d4dce2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 342), "Last sales    $%s" % _money(revenue), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8ee6a8"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 372), "Operating     $%s/day" % _money(operating_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f2d27a"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 420), "[P] Change price    [N] End day", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("a9b6c2"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(800, 185), "No business yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("b4bec8"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 225), "Restore the warehouse, then", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8fa2b2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 252), "open a consumer-goods company.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8fa2b2"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 305), "Startup capital", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7f98ad"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 333), "$3,000", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f2d27a"))
        draw_string(ThemeDB.fallback_font, Vector2(800, 420), "[O] Open business", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("8ee6a8"))

    # Event log / controls
    draw_rect(Rect2(34, 510, 1212, 165), Color("151e27"), true)
    draw_string(ThemeDB.fallback_font, Vector2(60, 540), "ACTIVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7f98ad"))
    for i in range(event_log.size()):
        draw_string(ThemeDB.fallback_font, Vector2(60, 567 + i * 22), event_log[i], HORIZONTAL_ALIGNMENT_LEFT, 1140, 15, Color("c5ced6"))
    draw_string(ThemeDB.fallback_font, Vector2(60, 655), "[I] Inspect  [A] Acquire  [R] Restore  [O] Open  [P] Price  [N] End day", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(60, 695), message, HORIZONTAL_ALIGNMENT_LEFT, 1140, 16, Color("f2d27a"))

func _draw_warehouse(origin: Vector2) -> void:
    # The building changes as restoration progresses, making investment visible.
    var wall_color := Color("3a3430")
    var roof_color := Color("272c32")
    var window_color := Color("171b20")
    if restoration >= 20:
        wall_color = Color("4b4945")
    if restoration >= 40:
        roof_color = Color("39414a")
    if restoration >= 60:
        window_color = Color("526775")
    if restoration >= 80:
        wall_color = Color("66736f")
    if restoration >= 100:
        wall_color = Color("788f86")
        window_color = Color("9bc5d3")
    draw_rect(Rect2(origin, Vector2(390, 190)), Color("252d35"), true)
    draw_colored_polygon(PackedVector2Array([origin + Vector2(15, 45), origin + Vector2(195, 5), origin + Vector2(375, 45), origin + Vector2(375, 165), origin + Vector2(15, 165)]), roof_color)
    draw_rect(Rect2(origin + Vector2(38, 65), Vector2(314, 100)), wall_color, true)
    for x in range(3):
        draw_rect(Rect2(origin + Vector2(62 + x * 92, 88), Vector2(55, 38)), window_color, true)
    draw_rect(Rect2(origin + Vector2(160, 122), Vector2(70, 43)), Color("20262b"), true)
    if restoration < 20:
        draw_circle(origin + Vector2(45, 155), 11, Color("6a5a45"))
        draw_circle(origin + Vector2(340, 150), 8, Color("665745"))
    if restoration >= 60:
        draw_rect(Rect2(origin + Vector2(280, 125), Vector2(22, 40)), Color("8c9695"), true)
    if restoration >= 80:
        draw_circle(origin + Vector2(370, 65), 8, Color("f2d27a"))
    if restoration >= 100:
        draw_string(ThemeDB.fallback_font, origin + Vector2(117, 30), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2d27a"))
