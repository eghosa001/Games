extends Node2D

# RENEW Prototype 07 - restoration, empire, districts, logistics and dynamic deals
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")
const Events = preload("res://scripts/events.gd")
const Production = preload("res://scripts/production.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const Expansion = preload("res://scripts/expansion.gd")
const ExpansionState = preload("res://scripts/expansion_state.gd")
const Districts = preload("res://scripts/districts.gd")

var economy = Economy.new()
var rivals = Rivals.new()
var events = Events.new()
var production = Production.new()
var expansion = Expansion.new()
var districts = Districts.new()

var cash := 25000
var reputation := 0
var day := 1
var debt := 0
var loan_payment := 0
var owned := false
var inspected := false
var restoration := 0
var stage := "Neglected"
# Runtime compatibility projections. Persistent business truth is GameState.
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
var transport_level := 1
var transport_capacity := 40
var selected_district := 0
var message := "Inspect the abandoned warehouse. Your empire starts here."
var log_lines: Array[String] = []
var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]

func _ready() -> void:
    randomize()
    var game_state = _game_state()
    if game_state != null and not game_state.has_state(): game_state.new_game()
    if game_state != null: game_state.restore_business_runtime(self)
    if game_state != null: game_state.restore_property_runtime(self)
    if game_state != null: game_state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    rivals._normalize()
    expansion.unlock_from_reputation(reputation)
    districts.update_unlocks(reputation)
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
            KEY_Y: buy_expansion_resource()
            KEY_Z: upgrade_expansion_resource()
            KEY_G: generate_expansion_resource()
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
    inspected = true; _sync_property("old_warehouse", {"inspected":true})
    message = "Inspection complete: cheap entry, strong demand, moderate renovation risk."; _log("INSPECTION: acquisition $5,000; restoration estimate $26,500.")
func acquire_property() -> void:
    if not inspected: message = "Inspect the property first."; return
    if owned: message = "You already own the warehouse."; return
    if cash < 5000: message = "Not enough cash."; return
    cash -= 5000; owned = true; reputation += 2
    _sync_property("old_warehouse", {"owned":true,"active":false,"restoration":restoration,"stage":stage})
    message = "Acquired Old Warehouse. Now restore it into an asset."; _log("ACQUIRED: Old Warehouse for $5,000.")
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
    _sync_property("old_warehouse", {"owned":true,"restoration":restoration,"stage":stage,"active":false})
    _log("RESTORATION: %s (-$%s)." % [stage,_money(cost)])
    if restoration >= 100:
        stage = "Operational"; reputation += 8
        _sync_property("old_warehouse", {"restoration":100,"stage":"Operational","active":true})
        message = "RESTORATION COMPLETE. Your neglected property is now productive capital."; _log("The district noticed the transformation.")
    else: message = "%s complete. The building is visibly improving." % stage
func open_business() -> void:
    if not owned or stage != "Operational": message = "Finish restoration first."; return
    if business_open: message = "RENEW Goods is already open."; return
    if cash < 3000: message = "Need $3,000 working capital."; return
    cash -= 3000; reputation += 2; _set_business("open", true); business_open = true
    var employee_controller = _employee_controller()
    if employee_controller != null:
        for employee in employee_controller.employees.active_employees():
            if str(employee.get("assignment_type", "")) == "renew_goods": employee_controller.assign(str(employee["id"]), "branch", "branch_0")
        employees = employee_controller.assigned_count("branch", "branch_0")
    message = "RENEW Goods is open. Build inventory, win customers and reinvest."; _log("OPENED: RENEW Goods with %d employees." % employees)
func buy_inputs() -> void:
    if not business_open: message = "Open the business first."; return
    var resources := ["materials","packaging","fuel"]
    var deal := rivals.deal_bonus(selected_rival); var pressure := rivals.supplier_pressure(selected_district); var total := 0
    for resource in resources: total += int(economy.quote(resource,12,supplier_choice)["cost"])
    total = int(round(total * (1.0 - float(deal["discount"]))) + pressure * 120)
    if cash < total: message = "You need $%s for this supply order." % _money(total); return
    for resource in resources:
        var result = economy.buy_resource(resource,12,cash,supplier_choice)
        if not result["ok"]: message = "%s could not complete delivery." % result["supplier"]; _log("SUPPLY FAILURE: %s." % result["supplier"]); return
        cash -= int(result["cost"])
    if float(deal["discount"]) > 0: cash += int(round(total * float(deal["discount"])))
    if pressure > 0: cash -= pressure * 120
    _log("SUPPLY ORDER: 12 units of every input; district pressure %d." % pressure); message = "Inputs delivered. Supplier pressure: %d." % pressure
func produce_goods() -> void:
    if not business_open: message = "Open the business first."; return
    var employee_controller = _employee_controller(); var staffing := employees
    if employee_controller != null: staffing = employee_controller.effective_staffing()
    var result = production.produce(economy, staffing+capacity_level-1)
    if not result["ok"]: message = "Production stopped: inputs are too low."; return
    var output := int(result["output"]); finished_goods += output; _set_business("finished_goods", finished_goods)
    message = "Produced %d goods at quality %d." % [output,result["quality"]]; _log("PRODUCTION: %d goods; quality %d; staffing %.2fx." % [output,result["quality"],float(result.get("staffing_efficiency",1.0))])
func hire_employee() -> void:
    if not business_open: message = "Open the business first."; return
    var employee_controller = _employee_controller()
    if employee_controller == null: message = "Employee system is not ready."; return
    var current_staff := employee_controller.assigned_count("branch", "branch_0"); var cost := 1200 + current_staff*250
    if cash < cost: message = "Hiring requires $%s" % _money(cost); return
    var result = employee_controller.hire_for_assignment("Worker", "branch", "branch_0")
    if not bool(result.get("ok", false)): message = str(result.get("message", "Hiring failed.")); return
    cash -= cost; employees = employee_controller.assigned_count("branch", "branch_0"); reputation += 1
    _log("HIRING: %s joined RENEW Goods as a persistent employee (-$%s)." % [str(result["employee"]["name"]),_money(cost)]); message = "%s hired for RENEW Goods. Staff: %d." % [str(result["employee"]["name"]),employees]
func upgrade_business() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 4500*capacity_level
    if cash < cost: message = "Capacity upgrade requires $%s." % _money(cost); return
    cash -= cost; capacity_level += 1; reputation += 2; _set_business("capacity_level",capacity_level)
    _log("UPGRADE: RENEW Goods capacity level %d." % capacity_level); message = "Production capacity upgraded to level %d." % capacity_level
func marketing_campaign() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 1800+marketing_level*700
    if cash < cost: message = "Marketing requires $%s." % _money(cost); return
    cash -= cost; marketing_level += 1; reputation += 2; _set_business("marketing_level",marketing_level)
    _log("MARKETING: campaign %d launched (-$%s)." % [marketing_level,_money(cost)]); message = "Brand strength increased."
func change_price() -> void:
    if not business_open: message = "Open the business first."; return
    player_price += 10
    if player_price > 160: player_price = 80
    _set_business("price",player_price); message = "Selling price is now $%s." % _money(player_price)

func advance_day() -> void:
    if not business_open: message = "There is no operating business yet."; return
    if finished_goods < 5: message = "Produce at least 5 goods before ending the day."; return
    var rival_price: int = int(rivals.rivals[0]["price"]); var alliance := rivals.alliance_bonus(selected_rival); var deal := rivals.deal_bonus(selected_rival); var pressure := rivals.district_pressure(selected_district)
    var price_factor := clamp(float(rival_price-player_price)/50.0,-0.55,0.75); var district_mult := districts.business_multiplier("Consumer Goods")
    var demand := clamp(int((55.0*(0.7+price_factor)+reputation*0.7+marketing_level*8+float(alliance["sales"])*40.0+float(deal["sales"])*45.0)*(district_mult-pressure)),5,100)
    var units := min(demand,finished_goods); var sales: int = units*player_price; var overhead := 650+capacity_level*100; var contract_income := contract_bonus if contract_days > 0 else 0
    var profit: int = sales+contract_income-overhead
    cash += profit; finished_goods -= units; last_sales = sales+contract_income; last_profit = profit; total_profit += profit
    _set_business_values({"finished_goods":finished_goods,"last_sales":last_sales,"last_profit":last_profit,"total_profit":total_profit})
    if contract_days > 0: contract_days -= 1; _set_business("contract_days",contract_days)
    if profit >= 0: reputation += 1
    else: reputation = max(0,reputation-1)
    if debt > 0:
        var interest := max(100,int(round(debt*0.012))); cash -= interest; _log("BANK: $%s interest charged." % _money(interest))
    if loan_payment > 0 and debt > 0:
        var payment := min(loan_payment,debt)
        if cash >= payment: cash -= payment; debt -= payment
        else: _log("BANK: missed loan payment; credit reputation damaged."); reputation = max(0,reputation-2)
    day += 1; economy.end_market_day()
    for news in rivals.daily_update(day): _log("RIVAL: " + news)
    for news in rivals.strategic_update(day,selected_district,reputation): _log("MARKET: " + news)
    if day % 2 == 0:
        var event: Dictionary = events.roll(); cash += int(event["cash"]); reputation += int(event["rep"]); _log("EVENT: %s — %s" % [event["title"],event["text"]])
    _sync_expansion_runtime()
    var empire = expansion.operate_day()
    var empire_profit := int(empire["profit"])
    var state := _game_state()
    if state != null:
        var expansion_result := ExpansionState.advance_day(state, empire_profit, int(expansion.restored_count) * 2)
        cash += empire_profit
        state.restore_expansion_runtime(expansion)
        expansion.day = int(expansion_result["day"])
    else:
        cash += empire_profit
        expansion.day = day
        expansion.cash = cash
        expansion.population += expansion.restored_count * 2
    if int(empire["businesses"]) > 0: _log("EMPIRE: %d businesses generated $%s net." % [empire["businesses"],_money(empire_profit)])
    expansion.unlock_from_reputation(reputation); districts.update_unlocks(reputation)
    _sync_expansion_runtime()
    _log("DAY %d: %d sold | sales $%s | core profit $%s | district %s." % [day,units,_money(sales),_money(profit),districts.current()["name"]]); message = "Day %d closed. %d sold; core profit $%s; empire profit $%s." % [day,units,_money(profit),_money(empire_profit)]

func cycle_supplier() -> void: supplier_choice = (supplier_choice+1)%3; message = "Supplier tier %d selected: lower price tiers trade reliability for savings." % (supplier_choice+1)
func select_rival(index:int)->void:
    if index<0 or index>=rivals.rivals.size(): return
    selected_rival=index; relationship=int(rivals.rivals[index]["relationship"]); message="Selected %s."%rivals.rivals[index]["name"]
func select_expansion(index:int)->void:
    if index<0 or index>=expansion.properties.size(): return
    selected_expansion=index; expansion.selected_index=index; message="Selected expansion: %s."%expansion.properties[index]["name"]; _log("EXPANSION SELECTED: %s."%expansion.properties[index]["name"]); _sync_expansion_runtime()
func select_district(index:int)->void:
    var result=districts.select(index); message=result["message"]
    if result["ok"]: selected_district=index; _log("DISTRICT: %s selected."%districts.current()["name"])
func improve_alliance()->void:
    var text:=rivals.improve_relationship(selected_rival); relationship=int(rivals.rivals[selected_rival]["relationship"]); message=text; _log("RELATIONSHIP: "+text)
func make_alliance_offer()->void:
    var result=rivals.offer_alliance(selected_rival); relationship=int(rivals.rivals[selected_rival]["relationship"]); message=result["message"]; _log("ALLIANCE: "+result["message"])
func propose_supply_deal()->void:
    var result=rivals.propose_supply_deal(selected_rival); relationship=int(rivals.rivals[selected_rival]["relationship"]); message=result["message"]; _log("DEAL: "+result["message"])
func propose_customer_partnership()->void:
    var result=rivals.propose_customer_partnership(selected_rival); relationship=int(rivals.rivals[selected_rival]["relationship"]); message=result["message"]; _log("DEAL: "+result["message"])
func negotiate_selected_acquisition()->void:
    var result=rivals.negotiate_acquisition(selected_rival,cash,reputation)
    if not result["ok"]: message=result["message"]; return
    cash-=int(result["cost"]); acquisition_count+=1; reputation+=8; message=result["message"]; _log("ACQUISITION: strategic foothold purchased for $%s."%_money(int(result["cost"])))
func reject_selected_acquisition()->void:
    var result=rivals.reject_acquisition(selected_rival); message=result["message"]; _log("BOARDROOM: "+result["message"])
func sign_contract()->void:
    if not business_open: message="Open a business before signing contracts."; return
    if contract_days>0: message="An active customer contract is already running."; return
    if reputation<10: message="Major customers need at least 10 reputation."; return
    contract_days=5; contract_bonus=900+reputation*20; reputation+=2; _set_business_values({"contract_days":contract_days,"contract_bonus":contract_bonus})
    _log("CONTRACT: five-day customer supply deal signed for $%s/day."%_money(contract_bonus)); message="Contract signed. Deliver every day for guaranteed revenue."
func take_loan()->void:
    if debt>0: message="Repay the current loan before borrowing again."; return
    var amount:=20000+reputation*300; debt=amount; loan_payment=int(ceil(float(amount)/20.0)); cash+=amount; _log("BANK: borrowed $%s. Daily repayment is $%s."%[_money(amount),_money(loan_payment)]); message="Loan approved. Growth is faster, but default will hurt your company."
func repay_loan()->void:
    if debt<=0: message="You have no outstanding loan."; return
    var amount:=min(debt,max(1000,debt/4))
    if cash<amount: message="Not enough cash to make a voluntary repayment."; return
    cash-=amount; debt-=amount
    if debt==0: loan_payment=0
    _log("BANK: voluntary repayment $%s. Remaining debt $%s."%[_money(amount),_money(debt)]); message="Loan balance reduced."
func buy_expansion()->void:
    var state=_game_state()
    if state==null:
        message="Game state is unavailable."; return
    expansion.unlock_from_reputation(reputation)
    var site=expansion.get_property(selected_expansion)
    if site.is_empty(): message="Unknown expansion property."; return
    if not bool(site.get("unlocked", true)): message="More reputation is required to access this property."; return
    var cost:=int(site.get("restoration_cost",site.get("cost",0)))
    _sync_expansion_runtime()
    if not ExpansionState.record_purchase(state,selected_expansion,cost,5):
        message="Expansion purchase could not be committed."; return
    cash-=cost; reputation+=3
    state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    message="%s restored and acquired." % site.get("name","Expansion")
    _log("EXPANSION: %s (-$%s) committed to GameState."%[site.get("name","Expansion"),_money(cost)])
func upgrade_expansion()->void:
    var state=_game_state()
    if state==null:
        message="Game state is unavailable."; return
    var site=expansion.get_property(selected_expansion)
    if site.is_empty() or not bool(site.get("owned",false)): message="Own the expansion property first."; return
    var cost:=7000*int(site.get("level",1))
    _sync_expansion_runtime()
    if not ExpansionState.record_property_upgrade(state,selected_expansion,cost,500,5000):
        message="Expansion upgrade could not be committed."; return
    cash-=cost
    state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    message="%s upgraded to level %d."%[site.get("name","Expansion"),int(expansion.get_property(selected_expansion).get("level",1))]
    _log("EXPANSION UPGRADE: %s (-$%s) committed to GameState."%[site.get("name","Expansion"),_money(cost)])

func buy_expansion_resource() -> void:
    var state = _game_state()
    if state == null:
        message = "Game state is unavailable."; return
    if selected_expansion < 0 or selected_expansion >= expansion.resource_sites.size():
        message = "Select a valid resource site."; return
    _sync_expansion_runtime()
    var site: Dictionary = expansion.get_resource_site(selected_expansion)
    if site.is_empty():
        message = "Unknown resource site."; return
    var cost := int(site.get("cost", 0))
    if not ExpansionState.record_resource_purchase(state, selected_expansion, cost, 2):
        message = "Resource-site purchase could not be committed."; return
    state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    message = "%s acquired." % site.get("name", "Resource site")
    _log("RESOURCE SITE: %s (-$%s) committed to GameState." % [site.get("name", "Resource site"), _money(cost)])

func upgrade_expansion_resource() -> void:
    var state = _game_state()
    if state == null:
        message = "Game state is unavailable."; return
    if selected_expansion < 0 or selected_expansion >= expansion.resource_sites.size():
        message = "Select a valid resource site."; return
    _sync_expansion_runtime()
    var site: Dictionary = expansion.get_resource_site(selected_expansion)
    if site.is_empty():
        message = "Unknown resource site."; return
    var cost := 9000 * int(site.get("level", 1))
    if not ExpansionState.record_resource_upgrade(state, selected_expansion, cost, 2, -1):
        message = "Resource-site upgrade could not be committed."; return
    state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    message = "%s upgraded to level %d." % [site.get("name", "Resource site"), int(expansion.get_resource_site(selected_expansion).get("level", 1))]
    _log("RESOURCE UPGRADE: %s (-$%s) committed to GameState." % [site.get("name", "Resource site"), _money(cost)])

func generate_expansion_resource() -> void:
    var state = _game_state()
    if state == null:
        message = "Game state is unavailable."; return
    if selected_expansion < 0 or selected_expansion >= expansion.resource_sites.size():
        message = "Select a valid resource site."; return
    _sync_expansion_runtime()
    var site: Dictionary = expansion.get_resource_site(selected_expansion)
    if site.is_empty() or not bool(site.get("owned", false)):
        message = "Own the resource site first."; return
    var output := int(site.get("output", 0)) * int(site.get("level", 1))
    if not ExpansionState.record_resource_generation(state, selected_expansion, output):
        message = "Resource generation could not be committed."; return
    state.restore_expansion_runtime(expansion)
    _sync_expansion_runtime()
    message = "%s generated %d %s." % [site.get("name", "Resource site"), output, site.get("resource", "resource")]
    _log("RESOURCE GENERATION: %s +%d %s; stock %d." % [site.get("name", "Resource site"), output, site.get("resource", "resource"), int(expansion.get_resource_site(selected_expansion).get("stock", 0))])

func acquire_rival_asset()->void:
    var result=rivals.acquire_asset(selected_rival,cash,reputation)
    if not result["ok"]: message=result["message"]; return
    cash-=int(result["cost"]); acquisition_count+=1; reputation+=5; message=result["message"]; _log("ACQUISITION: %s for $%s."%[result["asset"],_money(int(result["cost"]))])
func save_game()->void:
    _sync_expansion_runtime()
    var result=SaveSystem.save_game(self)
    message="Game saved." if result.get("ok",false) else "Save failed: %s"%result.get("message","unknown error")
func load_game()->void:
    var result=SaveSystem.load_game()
    if result.get("ok",false):
        var state=_game_state()
        if state!=null:
            state.restore_business_runtime(self)
            state.restore_property_runtime(self)
            state.restore_expansion_runtime(expansion)
        if result.has("employees"): employees=int(result["employees"])
        message="Game loaded."; _log("SAVE: restored successfully.")

func _sync_expansion_runtime()->void:
    expansion.cash=cash
    expansion.reputation=reputation
    expansion.day=day
    expansion.selected_index=selected_expansion
    var state=_game_state()
    if state!=null: state.sync_expansion_runtime(expansion)

func _game_state():
    var tree=get_tree()
    if tree==null:return null
    return tree.root.get_node_or_null("RenewGameState")

func _set_business(key:String,value)->void:
    var state=_game_state()
    if state!=null: state.set_business_value(key,value)
    match key:
        "open": business_open=bool(value)
        "capacity_level": capacity_level=int(value)
        "marketing_level": marketing_level=int(value)
        "price": player_price=int(value)
        "finished_goods": finished_goods=int(value)
        "last_sales": last_sales=int(value)
        "last_profit": last_profit=int(value)
        "total_profit": total_profit=int(value)
        "contract_days": contract_days=int(value)
        "contract_bonus": contract_bonus=int(value)

func _set_business_values(values:Dictionary)->void:
    var state=_game_state()
    if state!=null: state.set_business_values(values)
    for key in values.keys():
        match key:
            "open": business_open=bool(values[key])
            "capacity_level": capacity_level=int(values[key])
            "marketing_level": marketing_level=int(values[key])
            "price": player_price=int(values[key])
            "finished_goods": finished_goods=int(values[key])
            "last_sales": last_sales=int(values[key])
            "last_profit": last_profit=int(values[key])
            "total_profit": total_profit=int(values[key])
            "contract_days": contract_days=int(values[key])
            "contract_bonus": contract_bonus=int(values[key])

func _sync_property(property_id:String,values:Dictionary)->void:
    var state=_game_state()
    if state!=null: state.set_property_values(property_id,values)

func _employee_controller(): return get_node_or_null("EmployeeController")
func _money(value:int)->String: return str(value)
func _log(text:String)->void:
    log_lines.push_front(text)
    if log_lines.size()>14: log_lines.pop_back()

func _draw()->void:
    draw_rect(Rect2(25,25,800,455),Color("101820"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,55),"RENEW — RESTORE. BUILD. CONTROL.",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,82),"Day %d | Cash $%s | Reputation %d | Debt $%s"%[day,_money(cash),reputation,_money(debt)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,108),"Property: %s | Restoration %d%% | Business %s | Employees %d"%[stage,restoration,"OPEN" if business_open else "CLOSED",employees],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,135),"Goods %d | Price $%s | Capacity L%d | Marketing L%d"%[finished_goods,_money(player_price),capacity_level,marketing_level],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,165),message,HORIZONTAL_ALIGNMENT_LEFT,750,15,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(45,195),"I inspect | A acquire | R restore | O open | S inputs | B produce | H hire | N end day",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8fa5b5"))
    draw_string(ThemeDB.fallback_font,Vector2(45,218),"U upgrade | M marketing | P price | J loan | V repay | K contract | E expansion | X rival asset",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8fa5b5"))
    draw_string(ThemeDB.fallback_font,Vector2(45,245),"Rivals 1-3 | Expansion 7-9 | T supplier | Y buy resource | Z upgrade resource | G generate | F5 save | F9 load",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8fa5b5"))
    var y:=285
    for line in log_lines:
        draw_string(ThemeDB.fallback_font,Vector2(45,y),line,HORIZONTAL_ALIGNMENT_LEFT,750,11,Color("aebcc6")); y+=19
