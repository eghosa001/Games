extends Node2D

# RENEW Prototype 03 - integrated economic vertical slice
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")
const Events = preload("res://scripts/events.gd")
const Production = preload("res://scripts/production.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const Expansion = preload("res://scripts/expansion.gd")

var economy = Economy.new()
var rivals = Rivals.new()
var events = Events.new()
var production = Production.new()
var expansion = Expansion.new()

var cash := 25000
var reputation := 0
var day := 1
var property_cost := 5000
var owned := false
var inspected := false
var restoration := 0
var stage := "Neglected"
var business_open := false
var employees := 3
var player_price := 110
var last_sales := 0
var last_profit := 0
var relationship := 15
var supplier_resource := "materials"
var finished_goods := 0
var total_profit := 0
var message := "Inspect the warehouse. Your first empire starts here."
var log_lines: Array[String] = []
var selected_rival := 0
var selected_expansion := 0

var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]

func _ready() -> void:
    randomize()
    _log("Opportunity discovered: an abandoned warehouse in a growing district.")
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
            KEY_S: buy_inputs()
            KEY_B: produce_goods()
            KEY_L: improve_alliance()
            KEY_C: make_alliance_offer()
            KEY_E: buy_expansion()
            KEY_1: select_rival(0)
            KEY_2: select_rival(1)
            KEY_3: select_rival(2)
            KEY_7: select_expansion(0)
            KEY_8: select_expansion(1)
            KEY_9: select_expansion(2)
            KEY_T: cycle_supplier()
            KEY_F5: save_game()
            KEY_F9: load_game()

func inspect_property() -> void:
    inspected = true
    message = "Inspection complete: low entry cost, strong demand, moderate renovation risk."
    _log("Inspection: acquisition $5,000; restoration estimate $26,500.")

func acquire_property() -> void:
    if not inspected:
        message = "Inspect the property first."; return
    if owned:
        message = "You already own it."; return
    if cash < property_cost:
        message = "Not enough cash."; return
    cash -= property_cost
    owned = true
    reputation += 2
    message = "Acquired Old Warehouse. Now make the restoration decision."
    _log("ACQUIRED: Old Warehouse for $5,000.")

func restore_property() -> void:
    if not owned:
        message = "Acquire the property first."; return
    if stage == "Operational":
        message = "Restoration is complete."; return
    var idx := 0
    for i in range(stages.size()):
        if stages[i][0] == stage:
            idx = i + 1
            break
    if idx >= stages.size(): return
    var cost: int = stages[idx][2]
    if cash < cost:
        message = "Need $%s for the next restoration stage." % _money(cost); return
    cash -= cost
    restoration = stages[idx][1]
    stage = stages[idx][0]
    reputation += 2
    _log("RESTORATION: %s (-$%s)." % [stage, _money(cost)])
    if restoration >= 100:
        stage = "Operational"
        reputation += 8
        message = "RESTORATION COMPLETE. The abandoned warehouse has become a real asset."
        _log("The district noticed your transformation. Business can now open.")
    else:
        message = "%s complete. The building is visibly improving." % stage

func open_business() -> void:
    if not owned or stage != "Operational":
        message = "Finish restoration first."; return
    if business_open:
        message = "RENEW Goods is already open."; return
    if cash < 3000:
        message = "Need $3,000 working capital."; return
    cash -= 3000
    business_open = true
    finished_goods = 0
    reputation += 2
    message = "RENEW Goods is open. Buy inputs, produce goods and manage the market."
    _log("OPENED: RENEW Goods. Initial workforce: 3 employees.")

func buy_inputs() -> void:
    if not business_open:
        message = "Open the business first."; return
    var supplier: Dictionary = economy.supplier_for(supplier_resource)
    if randi_range(1, 100) > int(supplier["reliability"]):
        message = "%s failed to deliver today's order." % supplier["name"]
        _log("SUPPLIER FAILURE: %s delayed your inputs." % supplier["name"])
        return
    var total_cost := 0
    for resource in ["materials", "packaging", "fuel"]:
        var result = economy.buy_resource(resource, 12, cash - total_cost)
        if not result["ok"]:
            message = "Not enough cash for the full input order."; return
        total_cost += int(result["cost"])
    cash -= total_cost
    _log("SUPPLY ORDER: 12 materials + 12 packaging + 12 fuel (-$%s)." % _money(total_cost))
    message = "Inputs delivered by %s." % supplier["name"]

func produce_goods() -> void:
    if not business_open:
        message = "Open the business first."; return
    var result = production.produce(economy, employees)
    if not result["ok"]:
        message = "Production stopped: not enough materials, packaging or fuel."; return
    finished_goods += int(result["output"])
    message = "Produced %d finished goods at quality %d." % [result["output"], result["quality"]]
    _log("PRODUCTION: %d goods made; quality %d." % [result["output"], result["quality"]])

func change_price() -> void:
    if not business_open:
        message = "Open the business first."; return
    player_price += 10
    if player_price > 160: player_price = 80
    message = "Selling price is now $%s." % _money(player_price)

func advance_day() -> void:
    if not business_open:
        message = "There is no operating business yet."; return
    if finished_goods < 5:
        message = "Customers arrived, but you have no finished goods. Produce before ending the day."; return
    var rival_price: int = int(rivals.rivals[0]["price"])
    var price_factor := clamp(float(rival_price - player_price) / 50.0, -0.55, 0.75)
    var demand := clamp(int(55.0 * (0.7 + price_factor) + reputation * 0.7), 5, 90)
    var units := min(demand, finished_goods)
    var sales := units * player_price
    var wages := employees * 180
    var overhead := 650
    var profit := sales - wages - overhead
    cash += profit
    finished_goods -= units
    last_sales = sales
    last_profit = profit
    total_profit += profit
    if profit >= 0: reputation += 1
    else: reputation = max(0, reputation - 1)
    day += 1
    economy.end_market_day()
    for news in rivals.daily_update(day): _log("RIVAL: " + news)
    if day % 2 == 0:
        var event: Dictionary = events.roll()
        cash += int(event["cash"])
        reputation += int(event["rep"])
        _log("EVENT: %s — %s" % [event["title"], event["text"]])
    expansion.unlock_from_reputation(reputation)
    _log("DAY %d: %d sold | sales $%s | profit $%s." % [day, units, _money(sales), _money(profit)])
    message = "Day %d closed. %d units sold; profit %s$%s." % [day, units, "+" if profit >= 0 else "-", _money(abs(profit))]

func select_rival(index: int) -> void:
    if index < 0 or index >= rivals.rivals.size(): return
    selected_rival = index
    relationship = int(rivals.rivals[selected_rival]["relationship"])
    message = "Selected %s." % rivals.rivals[selected_rival]["name"]

func select_expansion(index: int) -> void:
    expansion.unlock_from_reputation(reputation)
    if index < 0 or index >= expansion.unlocked: message = "That expansion is not unlocked yet."; return
    selected_expansion = index
    message = "Selected %s." % expansion.properties[selected_expansion]["name"]

func cycle_supplier() -> void:
    var names := ["materials", "packaging", "fuel"]
    var current := names.find(supplier_resource)
    supplier_resource = names[(current + 1) % names.size()]
    var supplier: Dictionary = economy.supplier_for(supplier_resource)
    message = "Preferred supplier focus: %s." % supplier["name"]

func improve_alliance() -> void:
    var text := rivals.improve_relationship(selected_rival)
    relationship = int(rivals.rivals[selected_rival]["relationship"])
    message = text
    _log("RELATIONSHIP: " + text)

func make_alliance_offer() -> void:
    var result = rivals.offer_alliance(selected_rival)
    relationship = int(rivals.rivals[selected_rival]["relationship"])
    message = result["message"]
    _log("ALLIANCE: " + result["message"])

func buy_expansion() -> void:
    expansion.unlock_from_reputation(reputation)
    var result = expansion.buy(selected_expansion, cash)
    if not result["ok"]:
        message = result["message"]; return
    cash -= int(result["cost"])
    reputation += 5
    message = result["message"] + " This is the beginning of your multi-business empire."
    _log("EXPANSION: " + result["message"])

func save_game() -> void:
    var state := {"cash":cash,"reputation":reputation,"day":day,"owned":owned,"inspected":inspected,"restoration":restoration,"stage":stage,"business_open":business_open,"employees":employees,"finished_goods":finished_goods,"player_price":player_price,"total_profit":total_profit}
    message = "Game saved." if SaveSystem.save_game(state) else "Save failed."

func load_game() -> void:
    var state := SaveSystem.load_game()
    if state.is_empty():
        message = "No save found."; return
    for key in state: set(key, state[key])
    message = "Game loaded."
    _log("SAVE: Previous company state restored.")

func _log(text: String) -> void:
    log_lines.push_front("D%d  %s" % [day, text])
    if log_lines.size() > 6: log_lines.pop_back()

func _money(value: int) -> String:
    return "%,d" % value

func _draw() -> void:
    draw_rect(Rect2(0,0,1280,720), Color("0c1218"))
    draw_rect(Rect2(0,0,1280,68), Color("17232d"))
    draw_string(ThemeDB.fallback_font,Vector2(32,44),"RENEW",HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(180,42),"DAY %d"%day,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font,Vector2(300,42),"CASH $%s"%_money(cash),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(510,42),"REP %d"%reputation,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(650,42),"PROFIT $%s"%_money(total_profit),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("b7d7ff"))

    draw_rect(Rect2(28,88,590,360),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(52,122),"RESTORATION",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(52,157),"OLD WAREHOUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(52,188),"Turn a neglected asset into productive capital.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("aab8c3"))
    _draw_warehouse(Vector2(52,215))
    draw_string(ThemeDB.fallback_font,Vector2(350,242),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("8ee6a8"))
    draw_rect(Rect2(350,260,230,13),Color("293945"),true)
    draw_rect(Rect2(350,260,230.0*restoration/100.0,13),Color("62c97d"),true)
    draw_string(ThemeDB.fallback_font,Vector2(350,297),"%d%% restored"%restoration,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(350,330),"Next: $%s"%_money(_next_cost()),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(350,370),"[I] Inspect  [A] Acquire  [R] Restore",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(350,400),"[O] Open business",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8ee6a8"))

    draw_rect(Rect2(640,88,612,360),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(664,122),"COMPANY CONTROL ROOM",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(664,158),"RENEW GOODS",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color.WHITE)
    if business_open:
        draw_string(ThemeDB.fallback_font,Vector2(664,193),"Employees: %d    Finished goods: %d"%[employees,finished_goods],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d0dae1"))
        draw_string(ThemeDB.fallback_font,Vector2(664,220),"Your price: $%s    The Giant: $%s"%[_money(player_price),_money(int(rivals.rivals[0]["price"]))],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d0dae1"))
        draw_string(ThemeDB.fallback_font,Vector2(664,247),"Last sales: $%s    Last profit: $%s"%[_money(last_sales),_money(last_profit)],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8ee6a8"))
        draw_string(ThemeDB.fallback_font,Vector2(664,274),"Materials $%d | Packaging $%d | Fuel $%d"%[int(economy.resources["materials"]["price"]),int(economy.resources["packaging"]["price"]),int(economy.resources["fuel"]["price"])],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c6d0d8"))
        var supplier: Dictionary = economy.supplier_for(supplier_resource)
        draw_string(ThemeDB.fallback_font,Vector2(664,306),"Supplier focus: %s | reliability %d%%"%[supplier["name"],supplier["reliability"]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f2d27a"))
        draw_string(ThemeDB.fallback_font,Vector2(664,345),"[S] Supplies   [B] Produce   [P] Price   [N] End day",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
        draw_string(ThemeDB.fallback_font,Vector2(664,374),"[L] Trust   [C] Alliance   [1-3] Rival   [E] Expansion",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b7d7ff"))
        draw_string(ThemeDB.fallback_font,Vector2(664,403),"Rival: %s | %s | relationship %d"%[rivals.rivals[selected_rival]["name"],rivals.rivals[selected_rival]["stance"],relationship],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d0dae1"))
    else:
        draw_string(ThemeDB.fallback_font,Vector2(664,200),"Restore the warehouse to 100%, then open your first company.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("aab8c3"))
        draw_string(ThemeDB.fallback_font,Vector2(664,238),"The economy, suppliers and rivals are waiting.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("aab8c3"))

    draw_rect(Rect2(28,468,1224,224),Color("121b23"),true)
    draw_string(ThemeDB.fallback_font,Vector2(52,500),"MARKET + EMPIRE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(52,530),"Rivals: Giant / Specialist / Network",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(52,557),"[1-3] select rival | [L] improve trust | [C] propose alliance",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c6d0d8"))
    expansion.unlock_from_reputation(reputation)
    draw_string(ThemeDB.fallback_font,Vector2(52,584),"Expansion: %d/%d unlocked | [7-9] select | selected: %s"%[expansion.unlocked,expansion.properties.size(),expansion.properties[selected_expansion]["name"]],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(52,610),"[T] Change supplier focus | [F5] Save | [F9] Load",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b7d7ff"))
    for i in range(log_lines.size()):
        draw_string(ThemeDB.fallback_font,Vector2(520,530+i*22),log_lines[i],HORIZONTAL_ALIGNMENT_LEFT,690,14,Color("aebbc5"))
    draw_string(ThemeDB.fallback_font,Vector2(52,655),"Goal: restore the world, build businesses, make allies and compete for control of the economy.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(52,682),message,HORIZONTAL_ALIGNMENT_LEFT,1160,15,Color("f2d27a"))

func _next_cost() -> int:
    for i in range(stages.size()):
        if stages[i][0] == stage and i+1 < stages.size(): return stages[i+1][2]
    return 0

func _draw_warehouse(o: Vector2) -> void:
    var wall := Color("393632")
    var roof := Color("252b31")
    if restoration >= 40: roof = Color("46515b")
    if restoration >= 80: wall = Color("65736f")
    draw_colored_polygon(PackedVector2Array([o+Vector2(0,48),o+Vector2(125,0),o+Vector2(250,48)]),roof)
    draw_rect(Rect2(o+Vector2(18,48),Vector2(215,105)),wall)
    for x in [38,88,138,188]:
        draw_rect(Rect2(o+Vector2(x,70),Vector2(28,40)),Color("526775") if restoration>=60 else Color("171b20"))
    draw_rect(Rect2(o+Vector2(92,112),Vector2(65,41)),Color("22292e"))
    if restoration < 40:
        draw_circle(o+Vector2(32,155),8,Color("675c4d"))
        draw_circle(o+Vector2(205,158),10,Color("675c4d"))
    if restoration >= 100:
        draw_rect(Rect2(o+Vector2(55,18),Vector2(140,20)),Color("263a32"))
        draw_string(ThemeDB.fallback_font,o+Vector2(65,34),"RENEW GOODS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8ee6a8"))
