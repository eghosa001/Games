extends Node

const SYSTEM_VERSION := 2

# Simulation is the authoritative command boundary for time advancement.
# Main supplies a plain state dictionary and domain-system references; this
# system owns the ordering of economic settlement, contracts, world updates,
# events and day progression.
var command_count := 0
var last_command := ""
var last_result: Dictionary = {}

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
        _:
            result = {"ok": false, "message": "Unknown simulation command: %s" % command}
    last_result = result
    return result

func _produce(args: Dictionary) -> Dictionary:
    var production = _production()
    var economy = _economy()
    if production == null or economy == null: return {"ok": false, "message": "Production dependencies are unavailable."}
    return production.produce(economy, int(args.get("cycles", 0)))

func _settle_sales(args: Dictionary) -> Dictionary:
    return _finance().settle_sales(int(args.get("sales", 0)), int(args.get("wages", 0)), int(args.get("overhead", 0)), int(args.get("contract_income", 0)))

# Advances the supplied company snapshot by exactly one operating day.
# No Main node is accessed here: all gameplay inputs are supplied through context.
func advance_day(state: Dictionary, context: Dictionary) -> Dictionary:
    if not bool(state.get("business_open", false)): return {"ok": false, "message": "There is no operating business yet."}
    var finished_goods := int(state.get("finished_goods", 0))
    if finished_goods < 5: return {"ok": false, "message": "Produce at least 5 goods before ending the day."}

    var rivals = context.get("rivals")
    var economy = context.get("economy")
    var events = context.get("events")
    var expansion = context.get("expansion")
    var districts = context.get("districts")
    if rivals == null or economy == null or events == null or expansion == null or districts == null:
        return {"ok": false, "message": "Simulation domain dependencies are unavailable."}

    var selected_rival := int(state.get("selected_rival", 0))
    var selected_district := int(state.get("selected_district", 0))
    var rival_price: int = int(rivals.rivals[0]["price"])
    var alliance := rivals.alliance_bonus(selected_rival)
    var deal := rivals.deal_bonus(selected_rival)
    var pressure := rivals.district_pressure(selected_district)
    var price_factor := clamp(float(rival_price - int(state.get("player_price", 110))) / 50.0, -0.55, 0.75)
    var district_mult := districts.business_multiplier("Consumer Goods")
    var reputation := int(state.get("reputation", 0))
    var marketing_level := int(state.get("marketing_level", 0))
    var demand := clamp(int((55.0 * (0.7 + price_factor) + reputation * 0.7 + marketing_level * 8 + float(alliance["sales"]) * 40.0 + float(deal["sales"]) * 45.0) * (district_mult - pressure)), 5, 100)
    var units := min(demand, finished_goods)
    var player_price := int(state.get("player_price", 110))
    var sales: int = units * player_price
    var employees := int(state.get("employees", 3))
    var capacity_level := int(state.get("capacity_level", 1))
    var wages := employees * 180
    var overhead := 650 + capacity_level * 100
    var contract_income := 0
    var contract_penalty := 0
    var contract_result: Dictionary = _execute_contract(state, finished_goods - units, context)
    if bool(contract_result.get("ok", false)):
        contract_income = int(contract_result.get("revenue", 0))
        contract_penalty = int(contract_result.get("penalty", 0))
        finished_goods -= int(contract_result.get("delivered", 0))
        _append_log(state, str(contract_result.get("log", "")))
    var profit: int = sales + contract_income - contract_penalty - wages - overhead
    var cash := int(state.get("cash", 0)) + profit
    finished_goods -= units
    state["cash"] = cash
    state["finished_goods"] = max(0, finished_goods)
    state["last_sales"] = sales + contract_income
    state["last_profit"] = profit
    state["total_profit"] = int(state.get("total_profit", 0)) + profit
    if profit >= 0: reputation += 1
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
            state["cash"] = int(state["cash"]) - payment
            debt -= payment
            state["debt"] = debt
        else:
            _append_log(state, "BANK: missed loan payment; credit reputation damaged.")
            state["reputation"] = max(0, int(state["reputation"]) - 2)

    state["day"] = int(state.get("day", 1)) + 1
    economy.end_market_day()
    for news in rivals.daily_update(int(state["day"])): _append_log(state, "RIVAL: " + news)
    for news in rivals.strategic_update(int(state["day"]), selected_district, int(state["reputation"])): _append_log(state, "MARKET: " + news)
    if int(state["day"]) % 2 == 0:
        var event: Dictionary = events.roll()
        state["cash"] = int(state["cash"]) + int(event["cash"])
        state["reputation"] = int(state["reputation"]) + int(event["rep"])
        _append_log(state, "EVENT: %s — %s" % [event["title"], event["text"]])
    var empire = expansion.operate_day()
    state["cash"] = int(state["cash"]) + int(empire["profit"])
    if int(empire["businesses"]) > 0: _append_log(state, "EMPIRE: %d businesses generated $%s net." % [empire["businesses"], _money(int(empire["profit"]))])
    expansion.unlock_from_reputation(int(state["reputation"]))
    districts.update_unlocks(int(state["reputation"]))
    var district_name := str(districts.current()["name"])
    _append_log(state, "DAY %d: %d sold | sales $%s | core profit $%s | district %s." % [state["day"], units, _money(sales), _money(profit), district_name])
    state["message"] = "Day %d closed. %d sold; core profit $%s; empire profit $%s." % [state["day"], units, _money(profit), _money(int(empire["profit"]))]
    return {"ok": true, "message": state["message"], "state": state.duplicate(true), "contract": contract_result}

func _execute_contract(state: Dictionary, available_after_sales: int, context: Dictionary) -> Dictionary:
    var contracts = _contracts()
    if contracts == null: return {}
    var active := contracts.active_contract()
    if active.is_empty():
        if int(state.get("contract_days", 0)) <= 0: return {}
        var created = contracts.create_default_customer_contract(int(state.get("day", 1)), int(state.get("reputation", 0)))
        if not bool(created.get("ok", false)): return {}
        active = created["contract"]
    var production = _production()
    var quality := 75
    if production != null:
        var snapshot: Dictionary = production.capture_state()
        var last_run: Dictionary = snapshot.get("last_run", {})
        if last_run.has("quality"): quality = int(last_run["quality"])
    var result := contracts.execute_day(str(active["id"]), max(0, available_after_sales), quality, int(state.get("day", 1)))
    if not bool(result.get("ok", false)): return result
    if bool(result.get("finished", false)):
        var final_contract: Dictionary = result["contract"]
        var status := str(final_contract.get("execution_status", "breached"))
        var impact: Dictionary = final_contract.get("reputation_impact", {})
        var rep_key := "on_fulfilled" if status == "fulfilled" else "on_failed"
        state["reputation"] = max(0, int(state.get("reputation", 0)) + int(impact.get(rep_key, 0)))
        state["contract_days"] = 0
        state["contract_bonus"] = 0
        if status == "fulfilled" and bool(final_contract.get("renewal_offered", false)): state["contract_days"] = int(final_contract["renewal"].get("term_days", 0))
        _append_log(state, "CONTRACT %s: %s." % [final_contract["id"], status.to_upper()])
    result["log"] = "CONTRACT: delivered %d; revenue $%s; penalty $%s." % [int(result.get("delivered", 0)), _money(int(result.get("revenue", 0))), _money(int(result.get("penalty", 0)))]
    return result

func _append_log(state: Dictionary, text: String) -> void:
    if text.is_empty(): return
    var logs = state.get("log_lines", [])
    if logs is Array:
        logs.append(text)
        if logs.size() > 100: logs.pop_front()
        state["log_lines"] = logs

func _money(value: int) -> String: return "%d" % value

func end_day(args: Dictionary = {}) -> Dictionary:
    var finance = _finance()
    if finance == null: return {"ok": false, "message": "FinanceSystem is unavailable."}
    var debt_result := finance.settle_debt_day()
    var economy = _economy()
    if economy != null: economy.end_market_day()
    last_result = debt_result
    return debt_result

func capture_state() -> Dictionary:
    var result := {"system_version": SYSTEM_VERSION, "command_count": command_count, "last_command": last_command, "last_result": last_result.duplicate(true)}
    var finance = _finance()
    var production = _production()
    if finance != null: result["finance"] = finance.capture_state()
    if production != null: result["production"] = production.capture_state()
    return result

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    command_count = int(snapshot.get("command_count", 0))
    last_command = str(snapshot.get("last_command", ""))
    last_result = snapshot.get("last_result", {}).duplicate(true)
    var finance = _finance()
    if finance != null and snapshot.get("finance", {}) is Dictionary: finance.restore_state(snapshot["finance"])
    var production = _production()
    if production != null and snapshot.get("production", {}) is Dictionary: production.restore_state(snapshot["production"])

func _finance():
    var root = get_tree().root
    return root.get_node_or_null("RenewFinanceSystem") if root else null
func _production():
    var root = get_tree().root
    return root.get_node_or_null("RenewProductionSystem") if root else null
func _economy():
    var main = get_tree().root.get_node_or_null("Main")
    return main.economy if main != null and "economy" in main else null
func _contracts():
    var root = get_tree().root
    return root.get_node_or_null("RenewContractSystem") if root else null
