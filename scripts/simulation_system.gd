extends Node

const SYSTEM_VERSION := 6
var command_count := 0
var last_command := ""
var last_result: Dictionary = {}

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

    # 1. START DAY -> Employee daily update.
    var employee_result: Dictionary = employee_system.daily_update(performance)
    for warning in employee_result.get("warnings", []): _append_log(state, "STAFF: " + str(warning))

    # 2. Resource market update. Production sees the current market state.
    economy.end_market_day()

    # 3. Production. BusinessSystem calculates employee capacity, efficiency,
    # technology, property condition and morale, while Production owns the
    # resource requirements and consumes actual market stock.
    business_system.produce_goods()
    var game_state = _game_state()
    if game_state != null:
        state["finished_goods"] = int(game_state.get_value("production", "finished_goods", state.get("finished_goods", 0)))
        state["cash"] = int(game_state.get_value("economy", "cash", state.get("cash", 0)))

    var finished_goods := int(state.get("finished_goods", 0))

    # Production economics are configuration data, not hard-coded in the loop.
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

    # 4. Sales.
    var rival_price: int = int(rivals.rivals[0]["price"])
    var alliance: Dictionary = rivals.alliance_bonus(selected_rival)
    var deal: Dictionary = rivals.deal_bonus(selected_rival)
    var pressure: float = float(rivals.district_pressure(selected_district))
    var price_factor: float = clamp(float(rival_price - int(state.get("player_price", 110))) / 50.0, -0.55, 0.75)
    var district_mult: float = float(districts.business_multiplier("Consumer Goods"))
    var reputation := int(state.get("reputation", 0))
    var marketing_level := int(state.get("marketing_level", 0))
    var demand := clamp(int((55.0 * (0.7 + price_factor) + reputation * 0.7 + marketing_level * 8 + float(alliance["sales"]) * 40.0 + float(deal["sales"]) * 45.0) * (district_mult - pressure)), 5, 100)
    var units := min(demand, finished_goods)
    var player_price := int(state.get("player_price", int(production_config.get("base_price", 110))))
    var sales: int = units * player_price
    finished_goods -= units

    # 5. Contracts.
    var contract_income := 0
    var contract_penalty := 0
    var contract_result: Dictionary = _execute_contract(state, finished_goods)
    if bool(contract_result.get("ok", false)):
        contract_income = int(contract_result.get("revenue", 0))
        contract_penalty = int(contract_result.get("penalty", 0))
        finished_goods -= int(contract_result.get("delivered", 0))
        _append_log(state, str(contract_result.get("log", "")))

    # 6. Wages. EmployeeSystem is authoritative for every salary.
    var wages := employee_system.get_daily_wage_total()
    var capacity_level := int(state.get("capacity_level", 1))
    var administrative_overhead := 650 + capacity_level * 100
    var profit: int = sales + contract_income - contract_penalty - wages - administrative_overhead - production_operating_cost
    state["cash"] = int(state.get("cash", 0)) + profit
    state["finished_goods"] = max(0, finished_goods)
    state["last_sales"] = sales + contract_income
    state["last_profit"] = profit
    state["total_profit"] = int(state.get("total_profit", 0)) + profit
    if profit >= 0: reputation += production_reputation_effect
    else: reputation = max(0, reputation - 1)
    state["reputation"] = reputation

    # 7. Debt.
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

    # 8. Competitors.
    state["day"] = int(state.get("day", 1)) + 1
    for news in rivals.daily_update(int(state["day"])): _append_log(state, "RIVAL: " + news)
    var ai_player_state: Dictionary = state.duplicate(true)
    ai_player_state["selected_rival"] = selected_rival; ai_player_state["selected_district"] = selected_district
    for news in rivals.strategic_ai_update(int(state["day"]), ai_player_state): _append_log(state, "CORPORATE AI: " + news)

    # 9. Events.
    if int(state["day"]) % 2 == 0:
        var event: Dictionary = events.roll()
        state["cash"] += int(event["cash"]); state["reputation"] += int(event["rep"])
        _append_log(state, "EVENT: %s — %s" % [event["title"], event["text"]])

    # 10. Expansion.
    var empire: Dictionary = expansion.operate_day()
    state["cash"] += int(empire["profit"])
    if int(empire["businesses"]) > 0: _append_log(state, "EMPIRE: %d businesses generated $%s net." % [empire["businesses"], _money(int(empire["profit"])))
    expansion.unlock_from_reputation(int(state["reputation"]))
    districts.update_unlocks(int(state["reputation"]))

    # 11-12. History and news are recorded after all daily outcomes are known.
    var district_name: String = str(districts.current()["name"])
    _append_log(state, "DAY %d: %d sold | sales $%s | profit $%s | production cost $%s | district %s." % [state["day"], units, _money(sales), _money(profit), _money(production_operating_cost), district_name])
    state["message"] = "Day %d closed. %d sold; profit $%s; production cost $%s; empire profit $%s." % [state["day"], units, _money(profit), _money(production_operating_cost), _money(int(empire["profit"]))]

    # END DAY: machine wear advances only after the complete loop has resolved.
    var production_system = _production()
    if production_system != null: production_system.advance_day()

    return {"ok": true,"message": state["message"],"state": state.duplicate(true),"contract": contract_result,"wages": wages,"production_operating_cost": production_operating_cost,"production_config": production_config,"employee_update": employee_result}

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
