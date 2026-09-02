extends Node2D

# RENEW Prototype 05 - restoration, business empire, supply chains and resource ownership
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
var debt := 0
var loan_payment := 0
var owned := false
var inspected := false
var restoration := 0
var stage := "Neglected"
var business_open := false
var employees := 3
var capacity_level := 1
var marketing_level := 0
var player_price := 110
var finished_goods := 0
var last_sales := 0
var last_profit := 0
var total_profit := 0
var relationship := 15
var selected_rival := 0
var selected_expansion := 0
var supplier_choice := 0
var contract_days := 0
var contract_bonus := 0
var acquisition_count := 0
var message := "Inspect the abandoned warehouse. Your empire starts here."
var log_lines: Array[String] = []
var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]

func _ready() -> void:
    randomize()
    expansion.unlock_from_reputation(reputation)
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
            KEY_H: hire_employee()
            KEY_U: upgrade_business()
            KEY_M: marketing_campaign()
            KEY_L: improve_alliance()
            KEY_C: make_alliance_offer()
            KEY_E: buy_expansion()
            KEY_Q: upgrade_expansion()
            KEY_K: sign_contract()
            KEY_J: take_loan()
            KEY_V: repay_loan()
            KEY_X: acquire_rival_asset()
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
    message = "Inspection complete: cheap entry, strong demand, moderate renovation risk."
    _log("INSPECTION: acquisition $5,000; restoration estimate $26,500.")

func acquire_property() -> void:
    if not inspected: message = "Inspect the property first."; return
    if owned: message = "You already own the warehouse."; return
    if cash < 5000: message = "Not enough cash."; return
    cash -= 5000; owned = true; reputation += 2
    message = "Acquired Old Warehouse. Now restore it into an asset."
    _log("ACQUIRED: Old Warehouse for $5,000.")

func restore_property() -> void:
    if not owned: message = "Acquire the property first."; return
    if stage == "Operational": message = "Restoration is complete."; return
    var idx := 0
    for i in range(stages.size()):
        if stages[i][0] == stage: idx = i + 1; break
    if idx >= stages.size(): return
    var cost: int = stages[idx][2]
    if cash < cost: message = "Need $%s for the next stage." % _money(cost); return
    cash -= cost; restoration = stages[idx][1]; stage = stages[idx][0]; reputation += 2
    _log("RESTORATION: %s (-$%s)." % [stage, _money(cost)])
    if restoration >= 100:
        stage = "Operational"; reputation += 8
        message = "RESTORATION COMPLETE. Your neglected property is now productive capital."
        _log("The district noticed the transformation.")
    else: message = "%s complete. The building is visibly improving." % stage

func open_business() -> void:
    if not owned or stage != "Operational": message = "Finish restoration first."; return
    if business_open: message = "RENEW Goods is already open."; return
    if cash < 3000: message = "Need $3,000 working capital."; return
    cash -= 3000; business_open = true; reputation += 2
    message = "RENEW Goods is open. Build inventory, win customers and reinvest."
    _log("OPENED: RENEW Goods with 3 employees.")

func buy_inputs() -> void:
    if not business_open: message = "Open the business first."; return
    var resources := ["materials","packaging","fuel"]
    var total := 0
    for resource in resources:
        var q = economy.quote(resource, 12, supplier_choice)
        total += int(q["cost"])
    if cash < total: message = "You need $%s for the complete order." % _money(total); return
    for resource in resources:
        var result = economy.buy_resource(resource, 12, cash, supplier_choice)
        if not result["ok"]:
            message = "%s could not complete delivery." % result["supplier"]
            _log("SUPPLY FAILURE: %s." % result["supplier"])
            return
        cash -= int(result["cost"])
    _log("SUPPLY ORDER: 12 units of every input (-$%s)." % _money(total))
    message = "Inputs delivered. Supplier tier %d." % (supplier_choice + 1)

func produce_goods() -> void:
    if not business_open: message = "Open the business first."; return
    var result = production.produce(economy, employees + capacity_level - 1)
    if not result["ok"]: message = "Production stopped: inputs are too low."; return
    finished_goods += int(result["output"])
    message = "Produced %d goods at quality %d." % [result["output"],result["quality"]]
    _log("PRODUCTION: %d goods; quality %d." % [result["output"],result["quality"]])

func hire_employee() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 1200 + employees * 250
    if cash < cost: message = "Hiring requires $%s." % _money(cost); return
    cash -= cost; employees += 1; reputation += 1
    _log("HIRING: employee %d joined (-$%s)." % [employees,_money(cost)])
    message = "Employee hired. More capacity, higher daily wages."

func upgrade_business() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 4500 * capacity_level
    if cash < cost: message = "Capacity upgrade requires $%s." % _money(cost); return
    cash -= cost; capacity_level += 1; reputation += 2
    _log("UPGRADE: RENEW Goods capacity level %d." % capacity_level)
    message = "Production capacity upgraded to level %d." % capacity_level

func marketing_campaign() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 1800 + marketing_level * 700
    if cash < cost: message = "Marketing requires $%s." % _money(cost); return
    cash -= cost; marketing_level += 1; reputation += 2
    _log("MARKETING: campaign %d launched (-$%s)." % [marketing_level,_money(cost)])
    message = "Brand strength increased."

func change_price() -> void:
    if not business_open: message = "Open the business first."; return
    player_price += 10
    if player_price > 160: player_price = 80
    message = "Selling price is now $%s." % _money(player_price)

func advance_day() -> void:
    if not business_open: message = "There is no operating business yet."; return
    if finished_goods < 5: message = "Produce at least 5 goods before ending the day."; return
    var rival_price: int = int(rivals.rivals[0]["price"])
    var alliance := rivals.alliance_bonus(selected_rival)
    var price_factor := clamp(float(rival_price - player_price) / 50.0, -0.55, 0.75)
    var demand := clamp(int(55.0 * (0.7 + price_factor) + reputation * 0.7 + marketing_level * 8 + float(alliance["sales"]) * 40.0), 5, 100)
    var units := min(demand, finished_goods)
    var sales := units * player_price
    var wages := employees * 180
    var overhead := 650 + capacity_level * 100
    var contract_income := contract_bonus if contract_days > 0 else 0
    var profit := sales + contract_income - wages - overhead
    cash += profit; finished_goods -= units; last_sales = sales + contract_income; last_profit = profit; total_profit += profit
    if contract_days > 0: contract_days -= 1
    if profit >= 0: reputation += 1
    else: reputation = max(0, reputation - 1)
    if debt > 0:
        var interest := max(100, int(round(debt * 0.012)))
        cash -= interest
        _log("BANK: $%s interest charged." % _money(interest))
    if loan_payment > 0 and debt > 0:
        var payment := min(loan_payment, debt)
        if cash >= payment: cash -= payment; debt -= payment
        else: _log("BANK: missed loan payment; credit reputation damaged."); reputation = max(0,reputation-2)
    day += 1
    economy.end_market_day()
    for news in rivals.daily_update(day): _log("RIVAL: " + news)
    if day % 2 == 0:
        var event: Dictionary = events.roll()
        cash += int(event["cash"]); reputation += int(event["rep"])
        _log("EVENT: %s — %s" % [event["title"],event["text"]])
    var empire = expansion.operate_day()
    cash += int(empire["profit"])
    if int(empire["businesses"]) > 0: _log("EMPIRE: %d businesses generated $%s net." % [empire["businesses"],_money(int(empire["profit"]))])
    expansion.unlock_from_reputation(reputation)
    _log("DAY %d: %d sold | sales $%s | core profit $%s." % [day,units,_money(sales),_money(profit)])
    message = "Day %d closed. %d sold; core profit $%s; empire profit $%s." % [day,units,_money(profit),_money(int(empire["profit"]))]

func cycle_supplier() -> void:
    supplier_choice = (supplier_choice + 1) % 3
    message = "Supplier tier %d selected: lower price tiers trade reliability for savings." % (supplier_choice + 1)

func select_rival(index: int) -> void:
    if index < 0 or index >= rivals.rivals.size(): return
    selected_rival = index; relationship = int(rivals.rivals[index]["relationship"])
    message = "Selected %s." % rivals.rivals[index]["name"]

func select_expansion(index: int) -> void:
    if index < 0 or index >= expansion.properties.size(): return
    selected_expansion = index
    var p = expansion.properties[index]
    message = "Selected expansion: %s." % p["name"]
    _log("EXPANSION SELECTED: %s." % p["name"])

func improve_alliance() -> void:
    var text := rivals.improve_relationship(selected_rival)
    relationship = int(rivals.rivals[selected_rival]["relationship"])
    message = text; _log("RELATIONSHIP: " + text)

func make_alliance_offer() -> void:
    var result = rivals.offer_alliance(selected_rival)
    relationship = int(rivals.rivals[selected_rival]["relationship"])
    message = result["message"]; _log("ALLIANCE: " + result["message"])

func sign_contract() -> void:
    if not business_open: message = "Open a business before signing contracts."; return
    if contract_days > 0: message = "An active customer contract is already running."; return
    if reputation < 10: message = "Major customers need at least 10 reputation."; return
    contract_days = 5; contract_bonus = 900 + reputation * 20; reputation += 2
    _log("CONTRACT: five-day customer supply deal signed for $%s/day." % _money(contract_bonus))
    message = "Contract signed. Deliver every day for guaranteed revenue."

func take_loan() -> void:
    if debt > 0: message = "Repay the current loan before borrowing again."; return
    var amount := 20000 + reputation * 300
    debt = amount; loan_payment = int(ceil(float(amount) / 20.0)); cash += amount
    _log("BANK: borrowed $%s. Daily repayment is $%s." % [_money(amount),_money(loan_payment)])
    message = "Loan approved. Growth is faster, but default will hurt your company."

func repay_loan() -> void:
    if debt <= 0: message = "You have no outstanding loan."; return
    var amount := min(debt, max(1000, debt / 4))
    if cash < amount: message = "Not enough cash to make a voluntary repayment."; return
    cash -= amount; debt -= amount
    if debt == 0: loan_payment = 0
    _log("BANK: voluntary repayment $%s. Remaining debt $%s." % [_money(amount),_money(debt)])
    message = "Loan balance reduced."

func buy_expansion() -> void:
    expansion.unlock_from_reputation(reputation)
    var result = expansion.buy(selected_expansion, cash)
    if not result["ok"]: message = result["message"]; return
    cash -= int(result["cost"]); reputation += 5
    _log("EXPANSION: %s" % result["message"])
    message = result["message"] + " It now operates as part of your empire."

func upgrade_expansion() -> void:
    var result = expansion.upgrade(selected_expansion, cash)
    if not result["ok"]: message = result["message"]; return
    cash -= int(result["cost"]); reputation += 2
    _log("EMPIRE: %s" % result["message"]); message = result["message"]

func acquire_rival_asset() -> void:
    if reputation < 25: message = "Acquisitions unlock at 25 reputation."; return
    var rival = rivals.rivals[selected_rival]
    var cost := 50000 + max(0, int(rival["cash"]) / 12)
    if cash < cost: message = "Acquiring a %s asset requires $%s." % [rival["name"],_money(cost)]; return
    cash -= cost; acquisition_count += 1; reputation += 8
    rival["cash"] = max(0,int(rival["cash"]) - cost / 2)
    _log("ACQUISITION: bought a distressed %s asset for $%s." % [rival["name"],_money(cost)])
    message = "Acquisition complete. A competitor's foothold is now yours."

func save_game() -> void:
    var state := {"cash":cash,"reputation":reputation,"day":day,"debt":debt,"loan_payment":loan_payment,"owned":owned,"inspected":inspected,"restoration":restoration,"stage":stage,"business_open":business_open,"employees":employees,"capacity_level":capacity_level,"marketing_level":marketing_level,"player_price":player_price,"finished_goods":finished_goods,"last_sales":last_sales,"last_profit":last_profit,"total_profit":total_profit,"contract_days":contract_days,"contract_bonus":contract_bonus,"acquisition_count":acquisition_count,"supplier_choice":supplier_choice,"expansion":expansion.properties,"resource_sites":expansion.resource_sites,"management_level":expansion.management_level,"management_overhead":expansion.management_overhead,"rivals":rivals.rivals,"resources":economy.resources}
    message = "Game saved." if SaveSystem.save_game(state) else "Save failed."

func load_game() -> void:
    var state := SaveSystem.load_game()
    if state.is_empty(): message = "No save found."; return
    for key in ["cash","reputation","day","debt","loan_payment","owned","inspected","restoration","stage","business_open","employees","capacity_level","marketing_level","player_price","finished_goods","last_sales","last_profit","total_profit","contract_days","contract_bonus","acquisition_count","supplier_choice"]:
        if state.has(key): set(key,state[key])
    if state.has("expansion"): expansion.properties = state["expansion"]
    if state.has("resource_sites"): expansion.resource_sites = state["resource_sites"]
    if state.has("management_level"): expansion.management_level = int(state["management_level"])
    if state.has("management_overhead"): expansion.management_overhead = int(state["management_overhead"])
    expansion._normalize_all()
    if state.has("rivals"): rivals.rivals = state["rivals"]
    if state.has("resources"): economy.resources = state["resources"]
    expansion.unlock_from_reputation(reputation)
    message = "Game loaded."; _log("SAVE: Previous company, empire and resource state restored.")

func _log(text: String) -> void:
    log_lines.push_front("D%d  %s" % [day,text])
    if log_lines.size() > 7: log_lines.pop_back()

func _money(value: int) -> String:
    return "%,d" % value

func _next_cost() -> int:
    if stage == "Operational": return 0
    for s in stages:
        if s[0] == stage:
            var idx := stages.find(s) + 1
            if idx < stages.size(): return stages[idx][2]
    return 0

func _draw() -> void:
    draw_rect(Rect2(0,0,1280,720),Color("0c1218"))
    draw_rect(Rect2(0,0,1280,64),Color("17232d"))
    draw_string(ThemeDB.fallback_font,Vector2(28,41),"RENEW",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(160,39),"DAY %d"%day,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("9fb3c8"))
    draw_string(ThemeDB.fallback_font,Vector2(270,39),"CASH $%s"%_money(cash),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(500,39),"REP %d"%reputation,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(620,39),"DEBT $%s"%_money(debt),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(790,39),"PROFIT $%s"%_money(total_profit),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b7d7ff"))

    draw_rect(Rect2(25,82,390,270),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,112),"RESTORATION",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(45,146),"OLD WAREHOUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,176),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("8ee6a8"))
    draw_rect(Rect2(45,192,330,14),Color("293945"),true)
    draw_rect(Rect2(45,192,330.0*restoration/100.0,14),Color("62c97d"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,229),"%d%% restored"%restoration,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,258),"Next stage: $%s"%_money(_next_cost()),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(45,292),"I inspect  A acquire  R restore  O open",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,318),"The building improves as you invest in it.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aab8c3"))

    draw_rect(Rect2(435,82,390,270),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(455,112),"RENEW GOODS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(455,145),"EMPLOYEES %d   CAPACITY %d"%[employees,capacity_level],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(455,174),"GOODS %d   PRICE $%d"%[finished_goods,player_price],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(455,203),"MARKETING %d"%marketing_level,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(455,234),"S buy inputs  T supplier  P price",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(455,257),"B produce  H hire  U capacity  M marketing",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(455,280),"N end day  K contract  J loan  V repay",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(455,303),"Contract: %d days | $%s/day"%[contract_days,_money(contract_bonus)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(455,326),"Last P&L: $%s"%_money(last_profit),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

    draw_rect(Rect2(845,82,410,270),Color("18242e"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,112),"EMPIRE & COMPETITION",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    var r = rivals.rivals[selected_rival]
    draw_string(ThemeDB.fallback_font,Vector2(865,143),"[%d] %s"%[selected_rival+1,r["name"]],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,171),"Price $%d | Relationship %d"%[r["price"],r["relationship"]],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,198),"1-3 select  L improve  C alliance",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,228),"Expansion %d: %s"%[selected_expansion+1,expansion.properties[selected_expansion]["name"]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,252),"7-9 select  E acquire  Q upgrade",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,276),"X acquire rival asset | Acquisitions %d"%acquisition_count,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,304),"Alliance bonus activates at relationship 35+.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aab8c3"))
    draw_string(ThemeDB.fallback_font,Vector2(865,326),"Empire businesses operate automatically each day.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aab8c3"))

    draw_rect(Rect2(25,375,800,315),Color("111b23"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,404),"ACTIVITY / MARKET",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(45,432),"Materials $%d   Packaging $%d   Fuel $%d"%[economy.resources["materials"]["price"],economy.resources["packaging"]["price"],economy.resources["fuel"]["price"]],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,457),"Supplier tier %d | Debt payment $%s/day"%[supplier_choice+1,_money(loan_payment)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b7d7ff"))
    for i in range(log_lines.size()):
        draw_string(ThemeDB.fallback_font,Vector2(45,490+i*27),log_lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aab8c3"))

    draw_rect(Rect2(845,375,410,315),Color("111b23"),true)
    draw_string(ThemeDB.fallback_font,Vector2(865,405),"CEO STATUS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(865,438),message,HORIZONTAL_ALIGNMENT_LEFT,365,15,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(865,493),"F5 save    F9 load",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(865,530),"Core loop: RESTORE → OPERATE → PROFIT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,556),"COMPETE → ALLY → ACQUIRE → EXPAND",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(865,610),"RENEW: rebuild the world you eventually control.",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("aab8c3"))
