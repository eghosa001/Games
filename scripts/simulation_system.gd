extends Node

const DemandModel = preload("res://scripts/demand_model.gd")
const SYSTEM_VERSION := 8
var command_count := 0
var last_command := ""
var last_result: Dictionary = {}
var demand_model = DemandModel.new()

func execute(command: String, args: Dictionary = {}) -> Dictionary:
    command_count += 1; last_command = command
    var result: Dictionary
    match command:
        "spend": result = _finance().spend(int(args.get("amount", 0)), str(args.get("reason", "expense")))
        "receive": result = _finance().receive(int(args.get("amount", 0)), str(args.get("reason", "income")))
        "loan": result = _finance().take_loan(int(args.get("amount", 0)))
        "repay": result = _finance().repay(int(args.get("amount", 0)))
        "produce": result = _produce(args)
        "settle_sales": result = _settle_sales(args)
        "end_day": result = end_day(args)
        _: result = {"ok": false, "message": "Unknown simulation command: %s" % command}
    last_result = result; return result

func _produce(args: Dictionary) -> Dictionary:
    var production = _production(); var economy = _economy()
    if production == null or economy == null: return {"ok": false, "message": "Production dependencies are unavailable."}
    return production.produce(economy, int(args.get("cycles", 0)))

func _settle_sales(args: Dictionary) -> Dictionary:
    return _finance().settle_sales(int(args.get("sales", 0)), int(args.get("wages", 0)), int(args.get("overhead", 0)), int(args.get("contract_income", 0)))

func advance_day(state: Dictionary, context: Dictionary) -> Dictionary:
    if not bool(state.get("business_open", false)): return {"ok": false, "message": "There is no operating business yet."}
    var rivals = context.get("rivals")
    var economy = context.get("economy")
    var events = context.get("events")
    var expansion = context.get("expansion")
    var districts = context.get("districts")
    var employee_system = context.get("employee_system")
    var business_system = context.get("business_system")
    if rivals == null or economy == null or events == null or expansion == null or districts == null or employee_system == null or business_system == null:
        return {"ok": false, "message": "Simulation domain dependencies are unavailable."}

    var selected_rival := int(state.get("selected_rival", 0))
    var selected_district := int(state.get("selected_district", 0))
    var performance := int(state.get("last_profit", 0))
    var employee_result: Dictionary = employee_system.daily_update(performance)
    for warning in employee_result.get("warnings", []): _append_log(state, "STAFF: " + str(warning))
    economy.end_market_day()
    business_system.produce_goods()
    var game_state = _game_state()
    if game_state != null:
        state["finished_goods"] = int(game_state.get_value("production", "finished_goods", state.get("finished_goods", 0)))
        state["cash"] = int(game_state.get_value("economy", "cash", state.get("cash", 0)))

    var finished_goods := int(state.get("finished_goods", 0))
    var production_config: Dictionary = {"operating_cost":75,"reputation_effect":1,"production_time":1.0,"base_price":110}
    if "production" in business_system and business_system.production != null:
        production_config = business_system.production.get_product_config("consumer_goods")
    var production_run: Dictionary = {}
    if "production" in business_system and business_system.production != null and business_system.production.system != null:
        production_run = business_system.production.system.last_run.duplicate(true)
    var production_operating_cost := int(production_run.get("operating_cost", 0))
    if production_operating_cost <= 0:
        var configured_cost := int(production_config.get("operating_cost", 75))
        var produced_cycles := int(production_run.get("cycles", 0))
        production_operating_cost = configured_cost * max(0, produced_cycles)
    var production_reputation_effect := int(production_run.get("reputation_effect", production_config.get("reputation_effect", 1)))

    var rival_price: int = int(rivals.rivals[0]["price"])
    var player_price := int(state.get("player_price", int(production_config.get("base_price", 110))))
    var reputation := int(state.get("reputation", 0))
    var quality := int(production_run.get("quality", 75))
    var marketing_level := int(state.get("marketing_level", 0))
    var contract_bonus := int(state.get("contract_bonus", 0))
    var employee_productivity := float(employee_system.get_productivity_multiplier("factory_001"))
    var district_mult := float(districts.business_multiplier("Consumer Goods"))
    var pressure := float(rivals.district_pressure(selected_district))
    var alliance: Dictionary = rivals.alliance_bonus(selected_rival)
    var deal: Dictionary = rivals.deal_bonus(selected_rival)
    var demand_result: Dictionary = demand_model.calculate("consumer_goods", float(player_price), float(rival_price), reputation, quality, marketing_level, contract_bonus, employee_productivity, district_mult, pressure, float(alliance.get("sales", 0)), float(deal.get("sales", 0)))
    if not bool(demand_result.get("ok", false)): return {"ok": false, "message": "Customer demand model is unavailable."}

    var customer_demand := int(demand_result["demand"])
    var units_sold := min(customer_demand, finished_goods)
    var sales: int = units_sold * player_price
    finished_goods -= units_sold
    var demand_modifiers: Dictionary = demand_result.get("modifiers", {})
    _append_log(state, "MARKET: price $%d vs rival $%d -> demand %d; sold %d." % [player_price, rival_price, customer_demand, units_sold])

    var contract_income := 0
    var contract_penalty := 0
    var contract_result: Dictionary = _execute_contract(state, finished_goods)
    if bool(contract_result.get("ok", false)):
        contract_income = int(contract_result.get("revenue", 0))
        contract_penalty = int(contract_result.get("penalty", 0))
        finished_goods -= int(contract_result.get("delivered", 0))
        _append_log(state, str(contract_result.get("log", "")))

    var wages := employee_system.get_daily_wage_total()
    var capacity_level := int(state.get("capacity_level", 1))
    var administrative_overhead := 650 + capacity_level * 100
    var profit: int = sales + contract_income - contract_penalty - wages - administrative_overhead - production_operating_cost
    state["cash"] = int(state.get("cash", 0)) + profit
    state["finished_goods"] = max(0, finished_goods)
    state["last_sales"] = sales + contract_income
    state["last_customer_demand"] = customer_demand
    state["last_units_sold"] = units_sold
    state["last_price_modifier"] = float(demand_modifiers.get("price", 1.0))
    state["last_demand_modifiers"] = demand_modifiers.duplicate(true)
    state["last_demand_raw"] = float(demand_result.get("raw_demand", customer_demand))
    state["last_relative_price"] = float(demand_result.get("relative_price", 1.0))
    state["last_profit"] = profit
    state["total_profit"] = int(state.get("total_profit", 0)) + profit
    if profit >= 0: reputation += production_reputation_effect
    else: reputation = max(0, reputation - 1)
    state["reputation"] = reputation

    var debt := int(state.get("debt", 0))
    var loan_payment := int(state.get("loan_payment", 0))
    if debt > 0:
        var interest := max(100, int(round(debt * 0.012)))
        state["cash"] = int(state["cash"]) - interest
        _append_log(state, "BANK: $%s interest charged." % _money(interest))
    if loan_payment > 0 and debt > 0:
        var payment := min(loan_payment, debt)
        if int(state["cash"]) >= payment:
            state["cash"] -= payment; debt -= payment; state["debt"] = debt
        else:
            _append_log(state, "BANK: missed loan payment; credit reputation damaged.")
            state["reputation"] = max(0, int(state["reputation"]) - 2)

    state["day"] = int(state.get("day", 1)) + 1
    for news in rivals.daily_update(int(state["day"])): _append_log(state, "RIVAL: " + news)
    var ai_player_state: Dictionary = state.duplicate(true)
    ai_player_state["selected_rival"] = selected_rival; ai_player_state["selected_district"] = selected_district
    for news in rivals.strategic_ai_update(int(state["day"]), ai_player_state): _append_log(state, "CORPORATE AI: " + news)

    if int(state["day"]) % 2 == 0:
        var event: Dictionary = events.roll()
        state["cash"] += int(event["cash"]); state["reputation"] += int(event["rep"])
        _append_log(state, "EVENT: %s — %s" % [event["title"], event["text"]])

    var empire: Dictionary = expansion.operate_day()
    state["cash"] += int(empire["profit"])
    if int(empire["businesses"]) > 0:
        _append_log(state, "EMPIRE: %d businesses generated $%s net." % [empire["businesses"], _money(int(empire["profit"]))])
    expansion.unlock_from_reputation(int(state["reputation"]))
    districts.update_unlocks(int(state["reputation"]))

    var district_name: String = str(districts.current()["name"])
    _append_log(state, "DAY %d: %d sold | demand %d | price $%s vs rival $%s | sales $%s | profit $%s | production cost $%s | district %s." % [state["day"], units_sold, customer_demand, _money(player_price), _money(rival_price), _money(sales), _money(profit), _money(production_operating_cost), district_name])
    state["message"] = "Day %d closed. %d/%d demand sold at $%s; profit $%s; production cost $%s; empire profit $%s." % [state["day"], units_sold, customer_demand, _money(player_price), _money(profit), _money(production_operating_cost), _money(int(empire["profit"]))]
    var production_system = _production()
    if production_system != null: production_system.advance_day()
    return {"ok": true,"message": state["message"],"state": state.duplicate(true),"contract": contract_result,"wages": wages,"production_operating_cost": production_operating_cost,"production_config": production_config,"employee_update": employee_result,"customer_demand":customer_demand,"units_sold":units_sold,"player_price":player_price,"competitor_price":rival_price,"demand_modifiers":demand_modifiers,"relative_price":float(demand_result.get("relative_price",1.0)),"raw_demand":float(demand_result.get("raw_demand",customer_demand))}

func _execute_contract(state: Dictionary, available_after_sales: int) -> Dictionary:
    var contracts = _contracts()
    if contracts == null: return {}
    var active: Dictionary = contracts.active_contract()
    if active.is_empty():
        if int(state.get("contract_days", 0)) <= 0: return {}
        var created: Dictionary = contracts.create_default_customer_contract(int(state.get("day", 1)), int(state.get("reputation", 0)))
        if not bool(created.get("ok", false)): return {}
        active = created["contract"]
    var production = _production()
    var quality := 75
    if production != null:
        var snapshot: Dictionary = production.capture_state(); var last_run: Dictionary = snapshot.get("last_run", {})
        if last_run.has("quality"): quality = int(last_run["quality"])
    var result: Dictionary = contracts.execute_day(str(active["id"]), max(0, available_after_sales), quality, int(state.get("day", 1)))
    if not bool(result.get("ok", false)): return result
    if bool(result.get("finished", false)):
        var final_contract: Dictionary = result["contract"]; var status := str(final_contract.get("execution_status", "breached")); var impact: Dictionary = final_contract.get("reputation_impact", {}); var rep_key := "on_fulfilled" if status == "fulfilled" else "on_failed"
        state["reputation"] = max(0, int(state.get("reputation", 0)) + int(impact.get(rep_key, 0))); state["contract_days"] = 0; state["contract_bonus"] = 0
        _append_log(state, "CONTRACT %s: %s." % [final_contract["id"], status.to_upper()])
    result["log"] = "CONTRACT: delivered %d; revenue $%s; penalty $%s." % [int(result.get("delivered", 0)), _money(int(result.get("revenue", 0))), _money(int(result.get("penalty", 0)))]
    return result

func _append_log(state: Dictionary, text: String) -> void:
    if text.is_empty(): return
    var logs = state.get("log_lines", [])
    if logs is Array:
        logs.append(text); if logs.size() > 100: logs.pop_front(); state["log_lines"] = logs
func _money(value: int) -> String: return "%d" % value
func end_day(args: Dictionary = {}) -> Dictionary:
    var finance = _finance(); if finance == null: return {"ok": false, "message": "FinanceSystem is unavailable."}
    var debt_result: Dictionary = finance.settle_debt_day(); var economy = _economy(); if economy != null: economy.end_market_day(); last_result = debt_result; return debt_result
func capture_state() -> Dictionary:
    var result: Dictionary = {"system_version": SYSTEM_VERSION,"command_count": command_count,"last_command": last_command,"last_result": last_result.duplicate(true)}
    var finance = _finance(); var production = _production()
    if finance != null: result["finance"] = finance.capture_state()
    if production != null: result["production"] = production.capture_state()
    return result
func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    command_count = int(snapshot.get("command_count", 0)); last_command = str(snapshot.get("last_command", "")); last_result = snapshot.get("last_result", {}).duplicate(true)
    var finance = _finance(); if finance != null and snapshot.get("finance", {}) is Dictionary: finance.restore_state(snapshot["finance"])
    var production = _production(); if production != null and snapshot.get("production", {}) is Dictionary: production.restore_state(snapshot["production"])
func _game_state():
    var root = get_tree().root; if root == null: return null
    return root.get_node_or_null("RenewGameState")
func _finance():
    var root = get_tree().root; if root == null: return null
    return root.get_node_or_null("RenewFinanceSystem")
func _production():
    var root = get_tree().root; if root == null: return null
    return root.get_node_or_null("RenewProductionSystem")
func _economy():
    var root = get_tree().current_scene; if root == null: return null
    if "economy" in root: return root.economy
    return null
func _contracts():
    var root = get_tree().root; if root == null: return null
    return root.get_node_or_null("RenewContractSystem")
