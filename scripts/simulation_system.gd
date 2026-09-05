# ===============================================
# File: scripts/simulation_system.gd
# ===============================================
extends Node

const DemandModel = preload("res://scripts/demand_model.gd")
const SYSTEM_VERSION := 9

var command_count: int = 0
var last_command: String = ""
var last_result: Dictionary = {}
var demand_model = DemandModel.new()
var production_system: Node = null

func execute(command: String, args: Dictionary = {}) -> Dictionary:
    command_count += 1
    last_command = command
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
    last_result = result
    return result

func _produce(args: Dictionary) -> Dictionary:
    var production = _production()
    var economy = _economy()
    if not production or not economy:
        return {"ok": false, "message": "Production dependencies unavailable."}
    return production.produce(economy, int(args.get("cycles", 0)))

func _settle_sales(args: Dictionary) -> Dictionary:
    var finance = _finance()
    if not finance:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    return finance.settle_sales(int(args.get("sales", 0)), int(args.get("wages", 0)), int(args.get("overhead", 0)), int(args.get("contract_income", 0)))

func _sync_finance_mirror(state: Dictionary) -> void:
    # FinanceSystem is authoritative. Legacy GameState is only a read/display mirror.
    # Never copy legacy cash/debt back into FinanceSystem because that can erase
    # transactions already recorded by the authoritative ledger.
    _sync_state_from_finance(state)

func _sync_state_from_finance(state: Dictionary) -> void:
    var game_state = _game_state()
    var finance = _finance()
    if not finance:
        return
    state["cash"] = int(finance.cash)
    state["debt"] = int(finance.debt)
    state["loan_payment"] = int(finance.loan_payment)
    if not game_state:
        return
    game_state.set_value("economy", "cash", int(finance.cash))
    game_state.set_value("finance", "debt", int(finance.debt))
    game_state.set_value("finance", "loan_payment", int(finance.loan_payment))

func _apply_cash_delta(state: Dictionary, amount: int, reason: String) -> bool:
    var finance = _finance()
    if not finance:
        return false
    if amount >= 0:
        var received = finance.receive(amount, reason)
        if not bool(received.get("ok", false)):
            return false
    else:
        var spent = finance.spend(-amount, reason)
        if not bool(spent.get("ok", false)):
            return false
    _sync_state_from_finance(state)
    return true

func advance_day(state: Dictionary, context: Dictionary) -> Dictionary:
    if not bool(state.get("business_open", false)):
        return {"ok": false, "message": "No operating business yet."}

    var rivals = context.get("rivals")
    var economy = context.get("economy")
    var events = context.get("events")
    var expansion = context.get("expansion")
    var districts = context.get("districts")
    var employee_system = context.get("employee_system")
    var business_system = context.get("business_system")
    var finance = _finance()

    if not rivals or not economy or not events or not expansion or not districts or not employee_system or not business_system or not finance:
        return {"ok": false, "message": "Simulation dependencies unavailable."}

    _sync_finance_mirror(state)

    var performance = int(state.get("last_profit", 0))
    var employee_result = employee_system.daily_update(performance)
    for warning in employee_result.get("warnings", []):
        _append_log(state, "STAFF: " + str(warning))

    economy.end_market_day()

    business_system.produce_goods()
    var finished_goods = int(state.get("finished_goods", 0))
    var game_state = _game_state()
    if game_state:
        state["finished_goods"] = int(game_state.get_value("production", "finished_goods", state.get("finished_goods", 0)))
    _sync_state_from_finance(state)

    var player_price = int(state.get("player_price", 110))
    var rival_price = int(rivals.rivals[0]["price"]) if rivals.rivals.size() > 0 else 120
    var reputation = int(state.get("reputation", 0))
    var quality = 75
    var marketing_level = int(state.get("marketing_level", 0))
    var contract_bonus = int(state.get("contract_bonus", 0))
    var employee_productivity = float(employee_system.get_productivity_multiplier("factory_001"))
    var district_mult = float(districts.business_multiplier("Consumer Goods"))
    var pressure = float(rivals.district_pressure(int(state.get("selected_district", 0))))
    var alliance = rivals.alliance_bonus(int(state.get("selected_rival", 0)))
    var deal = rivals.deal_bonus(int(state.get("selected_rival", 0)))

    var demand_result = demand_model.calculate("consumer_goods", float(player_price), float(rival_price), reputation, quality, marketing_level, contract_bonus, employee_productivity, district_mult, pressure, float(alliance.get("sales", 0)), float(deal.get("sales", 0)))
    if not bool(demand_result.get("ok", false)):
        return {"ok": false, "message": "Demand model failed."}
    var customer_demand = int(demand_result["demand"])
    var units_sold = min(customer_demand, finished_goods)
    var sales = units_sold * player_price
    finished_goods -= units_sold
    state["finished_goods"] = max(0, finished_goods)
    state["last_units_sold"] = units_sold

    var contract_result = _execute_contract(state, finished_goods)
    var contract_income = int(contract_result.get("revenue", 0))
    var contract_penalty = int(contract_result.get("penalty", 0))
    if contract_result.get("ok", false):
        state["finished_goods"] = max(0, int(state["finished_goods"]) - int(contract_result.get("delivered", 0)))

    var wages = int(employee_system.get_daily_wage_total())
    var capacity_level = int(state.get("capacity_level", 1))
    var administrative_overhead = 650 + capacity_level * 100

    var settlement = finance.settle_sales(sales, wages, administrative_overhead + contract_penalty, contract_income)
    var profit = int(settlement.get("profit", 0))
    state["last_sales"] = sales + contract_income
    state["last_profit"] = profit
    state["total_profit"] = int(state.get("total_profit", 0)) + profit
    _sync_state_from_finance(state)
    if profit >= 0:
        reputation += 1
    else:
        reputation = max(0, reputation - 1)
    state["reputation"] = reputation

    var debt_result = finance.settle_debt_day()
    _sync_state_from_finance(state)
    if bool(debt_result.get("missed", false)):
        _append_log(state, "BANK: missed loan payment; credit reputation damaged.")
        state["reputation"] = max(0, int(state["reputation"]) - 2)
    elif int(debt_result.get("interest", 0)) > 0:
        _append_log(state, "BANK: $%s interest charged." % _money(int(debt_result["interest"])))

    state["day"] = int(state.get("day", 1)) + 1

    for news in rivals.daily_update(int(state["day"])):
        _append_log(state, "RIVAL: " + news)
    var ai_player_state = state.duplicate(true)
    ai_player_state["selected_rival"] = int(state.get("selected_rival", 0))
    ai_player_state["selected_district"] = int(state.get("selected_district", 0))
    for news in rivals.strategic_ai_update(int(state["day"]), ai_player_state):
        _append_log(state, "CORPORATE AI: " + news)

    if int(state["day"]) % 2 == 0:
        var event = events.roll()
        var event_cash = int(event.get("cash", 0))
        if event_cash != 0 and not _apply_cash_delta(state, event_cash, "dynamic event: %s" % str(event.get("title", "event"))):
            _append_log(state, "EVENT: cash effect could not be applied.")
        state["reputation"] += int(event.get("rep", 0))
        _append_log(state, "EVENT: %s — %s" % [event["title"], event["text"]])

    var empire = expansion.operate_day()
    var empire_profit = int(empire.get("profit", 0))
    if empire_profit != 0 and not _apply_cash_delta(state, empire_profit, "empire daily operating result"):
        _append_log(state, "EMPIRE: daily cash result could not be applied.")
    if int(empire["businesses"]) > 0:
        _append_log(state, "EMPIRE: %d businesses generated $%s net." % [int(empire["businesses"]), _money(empire_profit)])

    expansion.unlock_from_reputation(int(state["reputation"]))
    districts.update_unlocks(int(state["reputation"]))

    state["message"] = "Day %d closed. %d/%d demand sold at $%s; profit $%s; empire profit $%s." % [int(state["day"]), units_sold, customer_demand, _money(player_price), _money(profit), _money(empire_profit)]

    var production_system_node = _production()
    if production_system_node:
        production_system_node.advance_day()

    _sync_state_from_finance(state)
    return {
        "ok": true,
        "message": state["message"],
        "state": state.duplicate(true),
        "contract": contract_result,
        "wages": wages,
        "production_operating_cost": 0,
        "production_config": {},
        "employee_update": employee_result,
        "customer_demand": customer_demand,
        "units_sold": units_sold,
        "player_price": player_price,
        "competitor_price": rival_price,
        "demand_modifiers": demand_result.get("modifiers", {}),
        "relative_price": float(demand_result.get("relative_price", 1.0)),
        "raw_demand": float(demand_result.get("raw_demand", customer_demand))
    }

func _execute_contract(state: Dictionary, available_after_sales: int) -> Dictionary:
    var contracts = _contracts()
    if not contracts:
        return {}
    var active = contracts.active_contract()
    if active.is_empty():
        if int(state.get("contract_days", 0)) <= 0:
            return {}
        var created = contracts.create_default_customer_contract(int(state.get("day", 1)), int(state.get("reputation", 0)))
        if not bool(created.get("ok", false)):
            return {}
        active = created["contract"]
    var production = _production()
    var quality = 75
    if production:
        var snapshot = production.capture_state()
        var last_run = snapshot.get("last_run", {})
        if last_run.has("quality"):
            quality = int(last_run["quality"])
    var result = contracts.execute_day(str(active["id"]), max(0, available_after_sales), quality, int(state.get("day", 1)))
    if not bool(result.get("ok", false)):
        return result
    if bool(result.get("finished", false)):
        var final_contract = result["contract"]
        var status = str(final_contract.get("execution_status", "breached"))
        var impact = final_contract.get("reputation_impact", {})
        var rep_key = "on_fulfilled" if status == "fulfilled" else "on_failed"
        state["reputation"] = max(0, int(state.get("reputation", 0)) + int(impact.get(rep_key, 0)))
        state["contract_days"] = 0
        state["contract_bonus"] = 0
        _append_log(state, "CONTRACT %s: %s." % [final_contract["id"], status.to_upper()])
    result["log"] = "CONTRACT: delivered %d; revenue $%s; penalty $%s." % [int(result.get("delivered", 0)), _money(int(result.get("revenue", 0))), _money(int(result.get("penalty", 0)))]
    return result

func _append_log(state: Dictionary, text: String) -> void:
    if text.is_empty():
        return
    var logs = state.get("log_lines", [])
    if logs is Array:
        logs.append(text)
        if logs.size() > 100:
            logs.pop_front()
        state["log_lines"] = logs

func _money(value: int) -> String:
    return str(value)

func end_day(args: Dictionary = {}) -> Dictionary:
    # Legacy compatibility endpoint. The canonical day lifecycle is
    # advance_day(state, context), invoked by GameplayCommandSystem.
    # This endpoint must never settle debt or mutate the market independently,
    # otherwise callers can charge a second day's interest/payment.
    return {
        "ok": false,
        "message": "Legacy end_day is disabled. Use the canonical advance_day flow."
    }

func capture_state() -> Dictionary:
    var result = {
        "system_version": SYSTEM_VERSION,
        "command_count": command_count,
        "last_command": last_command,
        "last_result": last_result.duplicate(true)
    }
    var finance = _finance()
    var production = _production()
    if finance and finance.has_method("capture_state"): result["finance"] = finance.capture_state()
    if production and production.has_method("capture_state"): result["production"] = production.capture_state()
    return result

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    command_count = int(snapshot.get("command_count", 0))
    last_command = str(snapshot.get("last_command", ""))
    last_result = snapshot.get("last_result", {}).duplicate(true)
    var finance = _finance()
    var production = _production()
    if finance and snapshot.get("finance", {}) is Dictionary and finance.has_method("restore_state"): finance.restore_state(snapshot["finance"])
    if production and snapshot.get("production", {}) is Dictionary and production.has_method("restore_state"): production.restore_state(snapshot["production"])

func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem")

func _game_state() -> Node:
    return get_node_or_null("/root/RenewGameState")

func _economy():
    var scene = get_tree().current_scene
    if scene == null:
        return null
    var command_system = scene.get_node_or_null("GameplayCommandSystem")
    if command_system != null and command_system.supply_system != null:
        return command_system.supply_system.economy
    return null

func _production() -> Node:
    if production_system != null:
        return production_system
    var root = get_tree().root
    var autoload = root.get_node_or_null("RenewProductionSystem")
    if autoload: return autoload
    var scene = get_tree().current_scene
    return scene.get_node_or_null("Systems/ProductionSystem") if scene else null

func _contracts() -> Node:
    var root = get_tree().root
    var autoload = root.get_node_or_null("RenewContractSystem")
    if autoload: return autoload
    var scene = get_tree().current_scene
    return scene.get_node_or_null("Systems/ContractSystem") if scene else null
