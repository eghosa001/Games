extends Node

const DemandModel = preload("res://scripts/demand_model.gd")

var demand_model = DemandModel.new()

func _state(): return get_node_or_null("/root/RenewGameState")
func _finance(): return get_node_or_null("/root/RenewFinanceSystem")
func _contracts(): return get_node_or_null("/root/RenewContractSystem")
func _commands():
    var scene = get_tree().current_scene if get_tree() != null else null
    return scene.get_node_or_null("GameplayCommandSystem") if scene != null else null
func _chain():
    var commands = _commands()
    return commands.business_system.supply_chain if commands != null and commands.business_system != null else null
func _rivals():
    var commands = _commands()
    return commands.relationship_system.rivals if commands != null and commands.relationship_system != null else null
func _districts():
    var commands = _commands()
    return commands.expansion_system.districts if commands != null and commands.expansion_system != null else null
func _employees():
    var commands = _commands()
    return commands.employee_system if commands != null else null
func _product() -> String:
    var state = _state()
    var value = str(state.get_value("businesses", "industry_id", "furniture")) if state != null else "furniture"
    return value if value in ["furniture", "construction_materials", "consumer_electronics"] else "furniture"
func _day() -> int:
    var state = _state(); return int(state.get_value("player", "day", 1)) if state != null else 1
func _analytics() -> Dictionary:
    var state = _state()
    if state == null: return {}
    var root = state.get_value("analytics", "real_time", {})
    if not (root is Dictionary): root = {}
    return root.duplicate(true)
func _market_state() -> Dictionary:
    var root = _analytics(); var value = root.get("active_market", {})
    return value.duplicate(true) if value is Dictionary else {}
func _save_market(value: Dictionary) -> void:
    var state = _state()
    if state == null: return
    var root = _analytics(); root["active_market"] = value.duplicate(true); state.set_value("analytics", "real_time", root)
func _log(text: String) -> void:
    var state = _state()
    if state == null or text.is_empty(): return
    var logs = state.get_value("company", "log_lines", [])
    if not (logs is Array): logs = []
    logs = logs.duplicate(true); logs.append(text)
    if logs.size() > 100: logs.pop_front()
    state.set_value("company", "log_lines", logs)
func _sync_finance() -> void:
    var state = _state(); var finance = _finance()
    if state == null or finance == null: return
    state.set_value("economy", "cash", int(finance.cash))
    state.set_value("finance", "debt", int(finance.debt))
    state.set_value("finance", "loan_payment", int(finance.loan_payment))

func demand_snapshot() -> Dictionary:
    var state = _state(); var rivals = _rivals(); var districts = _districts(); var employees = _employees()
    if state == null or rivals == null or districts == null or employees == null:
        return {"ok": false, "demand": 0, "remaining": 0}
    var price = int(state.get_value("businesses", "player_price", 110))
    var rival_price = int(rivals.rivals[0].get("price", 120)) if rivals.rivals.size() > 0 else 120
    var rep = int(state.get_value("player", "reputation", 0))
    var marketing = int(state.get_value("businesses", "marketing_level", 0))
    var contract_bonus = int(state.get_value("contracts", "contract_bonus", 0))
    var selected_rival = int(state.get_value("competitors", "selected_rival", 0))
    var selected_district = int(state.get_value("regions", "selected_district", 0))
    var productivity = float(employees.get_productivity_multiplier("factory_001"))
    var district_mult = float(districts.business_multiplier("Consumer Goods"))
    var pressure = float(rivals.district_pressure(selected_district))
    var alliance = rivals.alliance_bonus(selected_rival)
    var deal = rivals.deal_bonus(selected_rival)
    var result = demand_model.calculate(_product(), float(price), float(rival_price), rep, 75, marketing, contract_bonus, productivity, district_mult, pressure, float(alliance.get("sales", 0)), float(deal.get("sales", 0)))
    if not bool(result.get("ok", false)): return {"ok": false, "demand": 0, "remaining": 0}
    var demand = maxi(0, int(result.get("demand", 0)))
    var market = _market_state(); var current_day = _day()
    if int(market.get("day", -1)) != current_day:
        market = {"day": current_day, "consumer_units_sold": 0, "consumer_revenue": 0}
        _save_market(market)
    var sold = int(market.get("consumer_units_sold", 0))
    return {"ok": true, "demand": demand, "sold": sold, "remaining": maxi(0, demand - sold), "price": price, "product": _product()}

func sell_goods() -> Dictionary:
    var state = _state(); var finance = _finance(); var chain = _chain()
    if state == null or finance == null or chain == null: return {"ok": false, "message": "Market services are unavailable."}
    if not bool(state.get_value("businesses", "business_open", false)): return {"ok": false, "message": "Open a business before selling goods."}
    var demand = demand_snapshot()
    if not bool(demand.get("ok", false)): return {"ok": false, "message": "Customer demand is unavailable."}
    var product = str(demand.get("product", _product())); var stock = int(floor(float(chain.stock(product))))
    var quantity = mini(stock, int(demand.get("remaining", 0)))
    if quantity <= 0:
        return {"ok": false, "message": "No sale available: produce more stock or wait for the next real-world trading day." if stock <= 0 else "Today's customer demand has been satisfied. Demand resets on the next real-world day."}
    var price = int(demand.get("price", 110)); var sale = chain.sell_product(product, quantity, price)
    if not bool(sale.get("ok", false)): return {"ok": false, "message": "Sale failed: %s" % str(sale.get("reason", "unknown"))}
    var revenue = int(sale.get("revenue", quantity * price)); var received = finance.receive(revenue, "active customer sales")
    if not bool(received.get("ok", false)): return {"ok": false, "message": str(received.get("message", "Sale settlement failed."))}
    _sync_finance()
    var market = _market_state(); market["consumer_units_sold"] = int(market.get("consumer_units_sold", 0)) + quantity; market["consumer_revenue"] = int(market.get("consumer_revenue", 0)) + revenue; _save_market(market)
    state.set_value("production", "finished_goods", int(floor(float(chain.stock(product)))))
    state.set_value("economy", "last_sales", revenue); state.set_value("economy", "last_profit", revenue); state.set_value("economy", "total_profit", int(state.get_value("economy", "total_profit", 0)) + revenue)
    _log("ACTIVE SALE: %d %s sold for $%d; %d demand remains today." % [quantity, product.replace("_", " "), revenue, maxi(0, int(demand.get("remaining", 0)) - quantity)])
    var message = "Sold %d %s for $%d. Today's remaining consumer demand: %d." % [quantity, product.replace("_", " "), revenue, maxi(0, int(demand.get("remaining", 0)) - quantity)]
    state.set_value("company", "message", message)
    return {"ok": true, "message": message, "units": quantity, "revenue": revenue}

func deliver_contract() -> Dictionary:
    var state = _state(); var finance = _finance(); var chain = _chain(); var contracts = _contracts()
    if state == null or finance == null or chain == null or contracts == null: return {"ok": false, "message": "Contract services are unavailable."}
    var active = contracts.active_contract()
    if active.is_empty(): return {"ok": false, "message": "There is no active contract to deliver."}
    var last = active.get("last_execution", {})
    if last is Dictionary and int(last.get("day", -1)) == _day(): return {"ok": false, "message": "Today's contract delivery has already been settled."}
    var product = str(active.get("resource_product", _product()))
    var stock = int(floor(float(chain.stock(product))))
    var result = contracts.execute_day(str(active.get("id", "")), stock, 75, _day())
    if not bool(result.get("ok", false)): return result
    var delivered = int(result.get("delivered", 0)); var revenue = int(result.get("revenue", 0)); var penalty = int(result.get("penalty", 0))
    if delivered > 0:
        var removed = chain.sell_product(product, delivered, int(active.get("price", 0)))
        if not bool(removed.get("ok", false)): return {"ok": false, "message": "Contract inventory settlement failed."}
        finance.receive(revenue, "contract delivery")
    if penalty > 0: finance.spend(penalty, "contract shortfall penalty")
    _sync_finance(); state.set_value("production", "finished_goods", int(floor(float(chain.stock(_product())))))
    var updated = result.get("contract", {}); var duration = int((updated.get("delivery_schedule", {}) as Dictionary).get("duration_days", 0)) if updated is Dictionary else 0
    var remaining = maxi(0, duration - int(updated.get("days_elapsed", 0))) if updated is Dictionary else 0
    state.set_value("contracts", "contract_days", remaining)
    if bool(result.get("finished", false)): state.set_value("contracts", "contract_bonus", 0)
    var message = "Contract settled: %d delivered, $%d revenue, $%d penalty." % [delivered, revenue, penalty]
    state.set_value("company", "message", message); _log("CONTRACT: " + message)
    return {"ok": true, "message": message, "delivered": delivered, "revenue": revenue, "penalty": penalty}
