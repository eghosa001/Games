extends Node

# Phase 3 command layer.
# Main owns input/navigation compatibility; this system owns gameplay mutations
# and delegates domain work to the existing gameplay systems.

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

var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]

func _game_state():
    return get_node_or_null("/root/RenewGameState")

func _state_value(domain: String, key: String, default_value):
    var state = _game_state()
    if state == null:
        return default_value
    return state.get_value(domain, key, default_value)

func _set_state_value(domain: String, key: String, value) -> void:
    var state = _game_state()
    if state != null:
        state.set_value(domain, key, value)

func _v(domain: String, key: String, default_value):
    return _state_value(domain, key, default_value)

func _set(domain: String, key: String, value) -> void:
    _set_state_value(domain, key, value)

func _log(text: String) -> void:
    var logs = _state_value("company", "log_lines", [])
    if not logs is Array:
        logs = []
    logs = logs.duplicate(true)
    logs.append(text)
    if logs.size() > 100:
        logs.pop_front()
    _set("company", "log_lines", logs)

func _money(value: int) -> String:
    return "%d" % value

func initialize() -> void:
    randomize()
    rivals._normalize()
    expansion.unlock_from_reputation(int(_v("player", "reputation", 0)))
    districts.update_unlocks(int(_v("player", "reputation", 0)))
    if _v("company", "log_lines", []).is_empty():
        _log("Opportunity discovered: an abandoned warehouse in a growing district.")

func inspect_property() -> void:
    _set("properties", "inspected", true)
    _set("company", "message", "Inspection complete: cheap entry, strong demand, moderate renovation risk.")
    _log("INSPECTION: acquisition $5,000; restoration estimate $26,500.")

func acquire_property() -> void:
    if not bool(_v("properties", "inspected", false)):
        _set("company", "message", "Inspect the property first.")
        return
    if bool(_v("properties", "owned", false)):
        _set("company", "message", "You already own the warehouse.")
        return
    var cash := int(_v("economy", "cash", 25000))
    if cash < 5000:
        _set("company", "message", "Not enough cash.")
        return
    _set("economy", "cash", cash - 5000)
    _set("properties", "owned", true)
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 2)
    _set("company", "message", "Acquired Old Warehouse. Now restore it into an asset.")
    _log("ACQUIRED: Old Warehouse for $5,000.")

func restore_property() -> void:
    if not bool(_v("properties", "owned", false)):
        _set("company", "message", "Acquire the property first.")
        return
    var stage := str(_v("properties", "stage", "Neglected"))
    if stage == "Operational":
        _set("company", "message", "Restoration is complete.")
        return
    var idx := 0
    for i in range(stages.size()):
        if stages[i][0] == stage:
            idx = i + 1
            break
    if idx >= stages.size():
        return
    var cost: int = stages[idx][2]
    var cash := int(_v("economy", "cash", 25000))
    if cash < cost:
        _set("company", "message", "Need $%s for the next stage." % _money(cost))
        return
    _set("economy", "cash", cash - cost)
    _set("properties", "restoration", stages[idx][1])
    _set("properties", "stage", stages[idx][0])
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 2)
    _log("RESTORATION: %s (-$%s)." % [stages[idx][0], _money(cost)])
    if int(stages[idx][1]) >= 100:
        _set("properties", "stage", "Operational")
        _set("player", "reputation", int(_v("player", "reputation", 0)) + 8)
        _set("company", "message", "RESTORATION COMPLETE. Your neglected property is now productive capital.")
        _log("The district noticed the transformation.")
    else:
        _set("company", "message", "%s complete. The building is visibly improving." % stages[idx][0])

func open_business() -> void:
    if not bool(_v("properties", "owned", false)) or str(_v("properties", "stage", "Neglected")) != "Operational":
        _set("company", "message", "Finish restoration first.")
        return
    if bool(_v("businesses", "business_open", false)):
        _set("company", "message", "RENEW Goods is already open.")
        return
    var cash := int(_v("economy", "cash", 25000))
    if cash < 3000:
        _set("company", "message", "Need $3,000 working capital.")
        return
    _set("economy", "cash", cash - 3000)
    _set("businesses", "business_open", true)
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 2)
    _set("company", "message", "RENEW Goods is open. Build inventory, win customers and reinvest.")
    _log("OPENED: RENEW Goods with 3 employees.")

func buy_inputs() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var supplier := int(_v("supply_chain", "supplier_choice", 0))
    var rival := int(_v("competitors", "selected_rival", 0))
    var district := int(_v("regions", "selected_district", 0))
    var resources := ["materials","packaging","fuel"]
    var deal := rivals.deal_bonus(rival)
    var pressure := rivals.supplier_pressure(district)
    var total := 0
    for resource in resources:
        total += int(economy.quote(resource, 12, supplier)["cost"])
    total = int(round(total * (1.0 - float(deal["discount"]))) + pressure * 120)
    var cash := int(_v("economy", "cash", 25000))
    if cash < total:
        _set("company", "message", "You need $%s for this supply order." % _money(total))
        return
    for resource in resources:
        var result = economy.buy_resource(resource, 12, cash, supplier)
        if not result["ok"]:
            _set("company", "message", "%s could not complete delivery." % result["supplier"])
            _log("SUPPLY FAILURE: %s." % result["supplier"])
            return
        cash -= int(result["cost"])
    if float(deal["discount"]) > 0:
        cash += int(round(total * float(deal["discount"])))
    if pressure > 0:
        cash -= pressure * 120
    _set("economy", "cash", cash)
    _log("SUPPLY ORDER: 12 units of every input; district pressure %d." % pressure)
    _set("company", "message", "Inputs delivered. Supplier pressure: %d." % pressure)

func produce_goods() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var employee_count := int(_v("employees", "employees", 3))
    var capacity := int(_v("businesses", "capacity_level", 1))
    var result = production.produce(economy, employee_count + capacity - 1)
    if not result["ok"]:
        _set("company", "message", "Production stopped: inputs are too low.")
        return
    _set("production", "finished_goods", int(result["finished_goods"] if result.has("finished_goods") else production.finished_goods))
    _set("company", "message", "Produced %d goods at quality %d." % [result["output"], result["quality"]])
    _log("PRODUCTION: %d goods; quality %d." % [result["output"], result["quality"]])

func hire_employee() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var count := int(_v("employees", "employees", 3))
    var cost := 1200 + count * 250
    var cash := int(_v("economy", "cash", 25000))
    if cash < cost:
        _set("company", "message", "Hiring requires $%s." % _money(cost))
        return
    _set("economy", "cash", cash - cost)
    _set("employees", "employees", count + 1)
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 1)
    _log("HIRING: employee %d joined (-$%s)." % [count + 1, _money(cost)])
    _set("company", "message", "Employee hired. More capacity, higher daily wages.")

func upgrade_business() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var level := int(_v("businesses", "capacity_level", 1))
    var cost := 4500 * level
    var cash := int(_v("economy", "cash", 25000))
    if cash < cost:
        _set("company", "message", "Capacity upgrade requires $%s." % _money(cost))
        return
    _set("economy", "cash", cash - cost)
    _set("businesses", "capacity_level", level + 1)
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 2)
    _log("UPGRADE: RENEW Goods capacity level %d." % (level + 1))
    _set("company", "message", "Production capacity upgraded to level %d." % (level + 1))

func marketing_campaign() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var level := int(_v("businesses", "marketing_level", 0))
    var cost := 1800 + level * 700
    var cash := int(_v("economy", "cash", 25000))
    if cash < cost:
        _set("company", "message", "Marketing requires $%s." % _money(cost))
        return
    _set("economy", "cash", cash - cost)
    _set("businesses", "marketing_level", level + 1)
    _set("player", "reputation", int(_v("player", "reputation", 0)) + 2)
    _log("MARKETING: campaign %d launched (-$%s)." % [level + 1, _money(cost)])
    _set("company", "message", "Brand strength increased.")

func change_price() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open the business first.")
        return
    var price := int(_v("businesses", "player_price", 110)) + 10
    if price > 160:
        price = 80
    _set("businesses", "player_price", price)
    _set("company", "message", "Selling price is now $%s." % _money(price))

func advance_day() -> void:
    var simulation = get_node_or_null("/root/RenewSimulationSystem")
    if simulation == null:
        _set("company", "message", "SimulationSystem is unavailable.")
        return
    var result: Dictionary = simulation.advance_day(_simulation_state(), _simulation_context())
    if not bool(result.get("ok", false)):
        _set("company", "message", str(result.get("message", "Unable to advance the day.")))
        return
    _apply_simulation_state(result["state"])

func _simulation_state() -> Dictionary:
    return {"cash":_v("economy","cash",25000),"reputation":_v("player","reputation",0),"day":_v("player","day",1),"debt":_v("finance","debt",0),"loan_payment":_v("finance","loan_payment",0),"business_open":_v("businesses","business_open",false),"employees":_v("employees","employees",3),"capacity_level":_v("businesses","capacity_level",1),"marketing_level":_v("businesses","marketing_level",0),"player_price":_v("businesses","player_price",110),"finished_goods":_v("production","finished_goods",0),"last_sales":_v("economy","last_sales",0),"last_profit":_v("economy","last_profit",0),"total_profit":_v("economy","total_profit",0),"relationship":_v("competitors","relationship",15),"selected_rival":_v("competitors","selected_rival",0),"selected_expansion":_v("branches","selected_expansion",0),"supplier_choice":_v("supply_chain","supplier_choice",0),"contract_days":_v("contracts","contract_days",0),"contract_bonus":_v("contracts","contract_bonus",0),"acquisition_count":_v("ownership","acquisition_count",0),"transport_level":_v("supply_chain","transport_level",1),"transport_capacity":_v("supply_chain","transport_capacity",40),"selected_district":_v("regions","selected_district",0),"message":_v("company","message",""),"log_lines":_v("company","log_lines",[]).duplicate(true)}

func _apply_simulation_state(state: Dictionary) -> void:
    var map := {"cash":["economy","cash"],"reputation":["player","reputation"],"day":["player","day"],"debt":["finance","debt"],"loan_payment":["finance","loan_payment"],"business_open":["businesses","business_open"],"employees":["employees","employees"],"capacity_level":["businesses","capacity_level"],"marketing_level":["businesses","marketing_level"],"player_price":["businesses","player_price"],"finished_goods":["production","finished_goods"],"last_sales":["economy","last_sales"],"last_profit":["economy","last_profit"],"total_profit":["economy","total_profit"],"relationship":["competitors","relationship"],"selected_rival":["competitors","selected_rival"],"selected_expansion":["branches","selected_expansion"],"supplier_choice":["supply_chain","supplier_choice"],"contract_days":["contracts","contract_days"],"contract_bonus":["contracts","contract_bonus"],"acquisition_count":["ownership","acquisition_count"],"transport_level":["supply_chain","transport_level"],"transport_capacity":["supply_chain","transport_capacity"],"selected_district":["regions","selected_district"],"message":["company","message"]}
    for key in map:
        if state.has(key):
            _set(map[key][0], map[key][1], state[key])
    if state.get("log_lines", []) is Array:
        _set("company", "log_lines", state["log_lines"].duplicate(true))

func _simulation_context() -> Dictionary:
    return {"economy":economy,"rivals":rivals,"events":events,"expansion":expansion,"districts":districts}

func cycle_supplier() -> void:
    var choice := (int(_v("supply_chain", "supplier_choice", 0)) + 1) % 3
    _set("supply_chain", "supplier_choice", choice)
    _set("company", "message", "Supplier tier %d selected: lower price tiers trade reliability for savings." % (choice + 1))

func select_rival(index: int) -> void:
    if index < 0 or index >= rivals.rivals.size():
        return
    _set("competitors", "selected_rival", index)
    _set("competitors", "relationship", int(rivals.rivals[index]["relationship"]))
    _set("company", "message", "Selected %s." % rivals.rivals[index]["name"])

func select_expansion(index: int) -> void:
    if index < 0 or index >= expansion.properties.size():
        return
    _set("branches", "selected_expansion", index)
    _set("company", "message", "Selected expansion: %s." % expansion.properties[index]["name"])
    _log("EXPANSION SELECTED: %s." % expansion.properties[index]["name"])

func select_district(index: int) -> void:
    var result = districts.select(index)
    _set("company", "message", result["message"])
    if result["ok"]:
        _set("regions", "selected_district", index)
        _log("DISTRICT: %s selected." % districts.current()["name"])

func improve_alliance() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var text := rivals.improve_relationship(selected)
    _set("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    _set("company", "message", text)
    _log("RELATIONSHIP: " + text)

func make_alliance_offer() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var result = rivals.offer_alliance(selected)
    _set("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    _set("company", "message", result["message"])
    _log("ALLIANCE: " + result["message"])

func propose_supply_deal() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var result = rivals.propose_supply_deal(selected)
    _set("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    _set("company", "message", result["message"])
    _log("DEAL: " + result["message"])

func propose_customer_partnership() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var result = rivals.propose_customer_partnership(selected)
    _set("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    _set("company", "message", result["message"])
    _log("DEAL: " + result["message"])

func negotiate_selected_acquisition() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var cash := int(_v("economy", "cash", 25000))
    var reputation := int(_v("player", "reputation", 0))
    var result = rivals.negotiate_acquisition(selected, cash, reputation)
    if not result["ok"]:
        _set("company", "message", result["message"])
        return
    _set("economy", "cash", cash - int(result["cost"]))
    _set("ownership", "acquisition_count", int(_v("ownership", "acquisition_count", 0)) + 1)
    _set("player", "reputation", reputation + 8)
    _set("company", "message", result["message"])
    _log("ACQUISITION: strategic foothold purchased for $%s." % _money(int(result["cost"])))

func reject_selected_acquisition() -> void:
    var selected := int(_v("competitors", "selected_rival", 0))
    var result = rivals.reject_acquisition(selected)
    _set("company", "message", result["message"])
    _log("BOARDROOM: " + result["message"])

func sign_contract() -> void:
    if not bool(_v("businesses", "business_open", false)):
        _set("company", "message", "Open a business before signing contracts.")
        return
    if int(_v("contracts", "contract_days", 0)) > 0:
        _set("company", "message", "An active customer contract is already running.")
        return
    var reputation := int(_v("player", "reputation", 0))
    if reputation < 10:
        _set("company", "message", "Major customers need at least 10 reputation.")
        return
    _set("contracts", "contract_days", 5)
    _set("contracts", "contract_bonus", 900 + reputation * 20)
    _set("player", "reputation", reputation + 2)
    _log("CONTRACT: customer supply agreement requested.")
    _set("company", "message", "Contract requested. The SimulationSystem will execute its deliveries.")

func take_loan() -> void:
    if int(_v("finance", "debt", 0)) > 0:
        _set("company", "message", "Repay the current loan before borrowing again.")
        return
    var reputation := int(_v("player", "reputation", 0))
    var amount := 20000 + reputation * 300
    _set("finance", "debt", amount)
    _set("finance", "loan_payment", int(ceil(float(amount) / 20.0)))
    _set("economy", "cash", int(_v("economy", "cash", 25000)) + amount)
    _log("BANK: borrowed $%s. Daily repayment is $%s." % [_money(amount), _money(int(_v("finance", "loan_payment", 0)))])
    _set("company", "message", "Loan approved. Growth is faster, but default will hurt your company.")

func repay_loan() -> void:
    var debt := int(_v("finance", "debt", 0))
    if debt <= 0:
        _set("company", "message", "You have no outstanding loan.")
        return
    var amount := min(debt, max(1000, debt / 4))
    var cash := int(_v("economy", "cash", 25000))
    if cash < amount:
        _set("company", "message", "Not enough cash to make a voluntary repayment.")
        return
    _set("economy", "cash", cash - amount)
    debt -= amount
    _set("finance", "debt", debt)
    if debt == 0:
        _set("finance", "loan_payment", 0)
    _log("BANK: voluntary repayment $%s. Remaining debt $%s." % [_money(amount), _money(debt)])
    _set("company", "message", "Loan balance reduced.")

func buy_expansion() -> void:
    var reputation := int(_v("player", "reputation", 0))
    expansion.unlock_from_reputation(reputation)
    var selected := int(_v("branches", "selected_expansion", 0))
    var cash := int(_v("economy", "cash", 25000))
    var result = expansion.buy(selected, cash)
    if not result["ok"]:
        _set("company", "message", result["message"])
        return
    _set("economy", "cash", cash - int(result["cost"]))
    _set("player", "reputation", reputation + int(result["rep"]))
    _log("EXPANSION: %s (-$%s)." % [result["name"], _money(int(result["cost"]))])
    _set("company", "message", result["message"])

func upgrade_expansion() -> void:
    var selected := int(_v("branches", "selected_expansion", 0))
    var cash := int(_v("economy", "cash", 25000))
    var result = expansion.upgrade(selected, cash)
    if not result["ok"]:
        _set("company", "message", result["message"])
        return
    _set("economy", "cash", cash - int(result["cost"]))
    _set("player", "reputation", int(_v("player", "reputation", 0)) + int(result["rep"]))
    _log("EMPIRE UPGRADE: %s." % result["name"])
    _set("company", "message", result["message"])

func acquire_rival_asset() -> void:
    negotiate_selected_acquisition()

func save_game() -> void:
    var state := _state_dict()
    _set("company", "message", "Game saved." if SaveSystem.save_game(state) else "Save failed.")

func load_game() -> void:
    var state := SaveSystem.load_game()
    if state.is_empty():
        _set("company", "message", "No save file found.")
        return
    _apply_loaded_state(state)
    _set("company", "message", "Game loaded.")

func _state_dict() -> Dictionary:
    var state = {"cash":_v("economy","cash",25000),"reputation":_v("player","reputation",0),"day":_v("player","day",1),"debt":_v("finance","debt",0),"loan_payment":_v("finance","loan_payment",0),"owned":_v("properties","owned",false),"inspected":_v("properties","inspected",false),"restoration":_v("properties","restoration",0),"stage":_v("properties","stage","Neglected"),"business_open":_v("businesses","business_open",false),"employees":_v("employees","employees",3),"capacity_level":_v("businesses","capacity_level",1),"marketing_level":_v("businesses","marketing_level",0),"player_price":_v("businesses","player_price",110),"finished_goods":_v("production","finished_goods",0),"last_sales":_v("economy","last_sales",0),"last_profit":_v("economy","last_profit",0),"total_profit":_v("economy","total_profit",0),"relationship":_v("competitors","relationship",15),"selected_rival":_v("competitors","selected_rival",0),"selected_expansion":_v("branches","selected_expansion",0),"supplier_choice":_v("supply_chain","supplier_choice",0),"contract_days":_v("contracts","contract_days",0),"contract_bonus":_v("contracts","contract_bonus",0),"acquisition_count":_v("ownership","acquisition_count",0),"transport_level":_v("supply_chain","transport_level",1),"transport_capacity":_v("supply_chain","transport_capacity",40),"selected_district":_v("regions","selected_district",0),"message":_v("company","message",""),"log_lines":_v("company","log_lines",[]),"rivals":rivals.rivals,"events":events.state,"expansion":expansion.state,"districts":districts.state}
    var game_state = _game_state()
    if game_state != null:
        return game_state.capture(state).merged({"schema_version": 8})
    return state

func _apply_loaded_state(state: Dictionary) -> void:
    var game_state = _game_state()
    if game_state != null and state.has("game_state") and state["game_state"] is Dictionary:
        state = game_state.restore(state["game_state"])
    var map := {"cash":["economy","cash"],"reputation":["player","reputation"],"day":["player","day"],"debt":["finance","debt"],"loan_payment":["finance","loan_payment"],"owned":["properties","owned"],"inspected":["properties","inspected"],"restoration":["properties","restoration"],"stage":["properties","stage"],"business_open":["businesses","business_open"],"employees":["employees","employees"],"capacity_level":["businesses","capacity_level"],"marketing_level":["businesses","marketing_level"],"player_price":["businesses","player_price"],"finished_goods":["production","finished_goods"],"last_sales":["economy","last_sales"],"last_profit":["economy","last_profit"],"total_profit":["economy","total_profit"],"relationship":["competitors","relationship"],"selected_rival":["competitors","selected_rival"],"selected_expansion":["branches","selected_expansion"],"supplier_choice":["supply_chain","supplier_choice"],"contract_days":["contracts","contract_days"],"contract_bonus":["contracts","contract_bonus"],"acquisition_count":["ownership","acquisition_count"],"transport_level":["supply_chain","transport_level"],"transport_capacity":["supply_chain","transport_capacity"],"selected_district":["regions","selected_district"],"message":["company","message"]}
    for key in map:
        if state.has(key):
            _set(map[key][0], map[key][1], state[key])
    if state.has("log_lines"):
        _set("company", "log_lines", state["log_lines"].duplicate(true))
    if state.has("rivals"):
        rivals.rivals = state["rivals"].duplicate(true)
    if state.has("events"):
        events.state = state["events"].duplicate(true)
    if state.has("expansion"):
        expansion.state = state["expansion"].duplicate(true)
    if state.has("districts"):
        districts.state = state["districts"].duplicate(true)
