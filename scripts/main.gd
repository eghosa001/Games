extends Node2D

# RENEW Prototype 07 - restoration, empire, districts, logistics and dynamic deals
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")
const Events = preload("res://scripts/events.gd")
const Production = preload("res://scripts/production.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const Expansion = preload("res://scripts/expansion.gd")
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
    inspected = true; message = "Inspection complete: cheap entry, strong demand, moderate renovation risk."; _log("INSPECTION: acquisition $5,000; restoration estimate $26,500.")
func acquire_property() -> void:
    if not inspected: message = "Inspect the property first."; return
    if owned: message = "You already own the warehouse."; return
    if cash < 5000: message = "Not enough cash."; return
    cash -= 5000; owned = true; reputation += 2; message = "Acquired Old Warehouse. Now restore it into an asset."; _log("ACQUIRED: Old Warehouse for $5,000.")
func restore_property() -> void:
    if not owned: message = "Acquire the property first."; return
    if stage == "Operational": message = "Restoration is complete."; return
    var idx := 0
    for i in range(stages.size()):
        if stages[i][0] == stage: idx = i + 1; break
    if idx >= stages.size(): return
    var cost: int = stages[idx][2]
    if cash < cost: message = "Need $%s for the next stage." % _money(cost); return
    cash -= cost; restoration = stages[idx][1]; stage = stages[idx][0]; reputation += 2; _log("RESTORATION: %s (-$%s)." % [stage,_money(cost)])
    if restoration >= 100: stage = "Operational"; reputation += 8; message = "RESTORATION COMPLETE. Your neglected property is now productive capital."; _log("The district noticed the transformation.")
    else: message = "%s complete. The building is visibly improving." % stage
func open_business() -> void:
    if not owned or stage != "Operational": message = "Finish restoration first."; return
    if business_open: message = "RENEW Goods is already open."; return
    if cash < 3000: message = "Need $3,000 working capital."; return
    cash -= 3000; business_open = true; reputation += 2; message = "RENEW Goods is open. Build inventory, win customers and reinvest."; _log("OPENED: RENEW Goods with 3 employees.")
func buy_inputs() -> void:
    if not business_open: message = "Open the business first."; return
    var resources := ["materials","packaging","fuel"]
    var deal := rivals.deal_bonus(selected_rival)
    var pressure := rivals.supplier_pressure(selected_district)
    var total := 0
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
    var result = production.produce(economy,employees+capacity_level-1)
    if not result["ok"]: message = "Production stopped: inputs are too low."; return
    finished_goods += int(result["output"]); message = "Produced %d goods at quality %d." % [result["output"],result["quality"]]; _log("PRODUCTION: %d goods; quality %d." % [result["output"],result["quality"]])
func hire_employee() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 1200 + employees*250
    if cash < cost: message = "Hiring requires $%s." % _money(cost); return
    cash -= cost; employees += 1; reputation += 1; _log("HIRING: employee %d joined (-$%s)." % [employees,_money(cost)]); message = "Employee hired. More capacity, higher daily wages."
func upgrade_business() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 4500*capacity_level
    if cash < cost: message = "Capacity upgrade requires $%s." % _money(cost); return
    cash -= cost; capacity_level += 1; reputation += 2; _log("UPGRADE: RENEW Goods capacity level %d." % capacity_level); message = "Production capacity upgraded to level %d." % capacity_level
func marketing_campaign() -> void:
    if not business_open: message = "Open the business first."; return
    var cost := 1800+marketing_level*700
    if cash < cost: message = "Marketing requires $%s." % _money(cost); return
    cash -= cost; marketing_level += 1; reputation += 2; _log("MARKETING: campaign %d launched (-$%s)." % [marketing_level,_money(cost)]); message = "Brand strength increased."
func change_price() -> void:
    if not business_open: message = "Open the business first."; return
    player_price += 10
    if player_price > 160: player_price = 80
    message = "Selling price is now $%s." % _money(player_price)

func advance_day() -> void:
    var simulation = get_node_or_null("/root/RenewSimulationSystem")
    if simulation == null:
        message = "SimulationSystem is unavailable."; return
    var result: Dictionary = simulation.advance_day(_simulation_state(), _simulation_context())
    if not bool(result.get("ok", false)):
        message = str(result.get("message", "Unable to advance the day.")); return
    _apply_simulation_state(result["state"])

func _simulation_state() -> Dictionary:
    return {"cash":cash,"reputation":reputation,"day":day,"debt":debt,"loan_payment":loan_payment,"business_open":business_open,"employees":employees,"capacity_level":capacity_level,"marketing_level":marketing_level,"player_price":player_price,"finished_goods":finished_goods,"last_sales":last_sales,"last_profit":last_profit,"total_profit":total_profit,"relationship":relationship,"selected_rival":selected_rival,"selected_expansion":selected_expansion,"supplier_choice":supplier_choice,"contract_days":contract_days,"contract_bonus":contract_bonus,"acquisition_count":acquisition_count,"transport_level":transport_level,"transport_capacity":transport_capacity,"selected_district":selected_district,"message":message,"log_lines":log_lines.duplicate(true)}

func _apply_simulation_state(state: Dictionary) -> void:
    for key in ["cash","reputation","day","debt","loan_payment","business_open","employees","capacity_level","marketing_level","player_price","finished_goods","last_sales","last_profit","total_profit","relationship","selected_rival","selected_expansion","supplier_choice","contract_days","contract_bonus","acquisition_count","transport_level","transport_capacity","selected_district","message"]:
        if state.has(key): set(key, state[key])
    if state.get("log_lines", []) is Array: log_lines = state["log_lines"].duplicate(true)

func _simulation_context() -> Dictionary:
    return {"economy":economy,"rivals":rivals,"events":events,"expansion":expansion,"districts":districts}

func cycle_supplier() -> void:
    supplier_choice = (supplier_choice+1)%3; message = "Supplier tier %d selected: lower price tiers trade reliability for savings." % (supplier_choice+1)
func select_rival(index:int)->void:
    if index<0 or index>=rivals.rivals.size(): return
    selected_rival=index; relationship=int(rivals.rivals[index]["relationship"]); message="Selected %s."%rivals.rivals[index]["name"]
func select_expansion(index:int)->void:
    if index<0 or index>=expansion.properties.size(): return
    selected_expansion=index; message="Selected expansion: %s."%expansion.properties[index]["name"]; _log("EXPANSION SELECTED: %s."%expansion.properties[index]["name"])
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
    contract_days=5; contract_bonus=900+reputation*20; reputation+=2; _log("CONTRACT: customer supply agreement requested."); message="Contract requested. The SimulationSystem will execute its deliveries."
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
    expansion.unlock_from_reputation(reputation); var result=expansion.buy(selected_expansion,cash)
    if not result["ok"]: message=result["message"]; return
    cash-=int(result["cost"]); reputation+=int(result["rep"]); _log("EXPANSION: %s (-$%s)."%[result["name"],_money(int(result["cost"]))]); message=result["message"]
func upgrade_expansion()->void:
    var result=expansion.upgrade(selected_expansion,cash)
    if not result["ok"]: message=result["message"]; return
    cash-=int(result["cost"]); reputation+=int(result["rep"]); _log("EMPIRE UPGRADE: %s."%result["name"]); message=result["message"]
func acquire_rival_asset()->void:
    var result=rivals.negotiate_acquisition(selected_rival,cash,reputation)
    if not result["ok"]: message=result["message"]; return
    cash-=int(result["cost"]); acquisition_count+=1; reputation+=8; _log("ACQUISITION: strategic foothold purchased for $%s."%_money(int(result["cost"]))); message=result["message"]
func save_game()->void:
    var state=_state_dict(); message="Game saved." if SaveSystem.save_game(state) else "Save failed."; queue_redraw()
func load_game()->void:
    var state=SaveSystem.load_game()
    if state.is_empty(): message="No save file found."; return
    _apply_loaded_state(state); message="Game loaded."; queue_redraw()
func _state_dict()->Dictionary:
    var state={"cash":cash,"reputation":reputation,"day":day,"debt":debt,"loan_payment":loan_payment,"owned":owned,"inspected":inspected,"restoration":restoration,"stage":stage,"business_open":business_open,"employees":employees,"capacity_level":capacity_level,"marketing_level":marketing_level,"player_price":player_price,"finished_goods":finished_goods,"last_sales":last_sales,"last_profit":last_profit,"total_profit":total_profit,"relationship":relationship,"selected_rival":selected_rival,"selected_expansion":selected_expansion,"supplier_choice":supplier_choice,"contract_days":contract_days,"contract_bonus":contract_bonus,"acquisition_count":acquisition_count,"transport_level":transport_level,"transport_capacity":transport_capacity,"selected_district":selected_district,"message":message,"log_lines":log_lines,"rivals":rivals.rivals,"events":events.state,"expansion":expansion.state,"districts":districts.state}
    return state
func _apply_loaded_state(state:Dictionary)->void:
    for key in ["cash","reputation","day","debt","loan_payment","owned","inspected","restoration","stage","business_open","employees","capacity_level","marketing_level","player_price","finished_goods","last_sales","last_profit","total_profit","relationship","selected_rival","selected_expansion","supplier_choice","contract_days","contract_bonus","acquisition_count","transport_level","transport_capacity","selected_district","message"]:
        if state.has(key): set(key,state[key])
    if state.has("log_lines"): log_lines=state["log_lines"]
    if state.has("rivals"): rivals.rivals=state["rivals"]
    if state.has("events"): events.state=state["events"]
    if state.has("expansion"): expansion.state=state["expansion"]
    if state.has("districts"): districts.state=state["districts"]
func _log(text:String)->void:
    log_lines.append(text)
    if log_lines.size()>100: log_lines.pop_front()
func _money(value:int)->String: return "%d"%value
