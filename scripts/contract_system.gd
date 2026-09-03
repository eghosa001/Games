extends Node

const SYSTEM_VERSION := 4
const MAX_HISTORY := 500
const DEFAULT_CUSTOMER := "Harbor Retail Cooperative"
const INITIAL_RELATIONSHIP := 50
var next_contract_id := 1
var active_contracts: Dictionary = {}
var completed_contracts: Array = []
var history: Array = []
var customer_relationships: Dictionary = {}
func _customer_id(parties: Array) -> String: return str(parties[1]) if parties.size() >= 2 else DEFAULT_CUSTOMER
func _get_relationship(customer_id: String) -> int: return clampi(int(customer_relationships.get(customer_id, INITIAL_RELATIONSHIP)), 0, 100)
func _set_relationship(customer_id: String, value: int) -> void: customer_relationships[customer_id] = clampi(value, 0, 100)
func get_customer_relationship(customer_id: String = DEFAULT_CUSTOMER) -> int: return _get_relationship(customer_id)
func _competitor_bid_modifier() -> float:
    var reaction = get_node_or_null("/root/RenewCompetitorReactionSystem")
    if reaction == null or reaction.rivals == null: return 0.0
    var total := 0.0
    for i in range(reaction.rivals.rivals.size()): total += float(reaction.get_future_bid_modifier(i))
    return min(0.20, total / max(1.0, float(reaction.rivals.rivals.size())))
func get_future_contract_offer(reputation: int, customer_id: String = DEFAULT_CUSTOMER) -> Dictionary:
    var relationship := _get_relationship(customer_id)
    if relationship < 20: return {"ok": false, "eligible": false, "relationship": relationship, "message": "Customer relationship is too weak for a new contract."}
    var quantity := max(10, 25 + int(round(float(relationship - 50) * 0.2))); var base_price := max(120, 180 + reputation * 2 + int(round(float(relationship - 50) * 0.8))); var competitor_pressure := _competitor_bid_modifier(); var price := int(round(float(base_price) * (1.0 + competitor_pressure))); var duration := 5 if relationship >= 60 else 4
    return {"ok": true, "eligible": true, "relationship": relationship, "quantity": quantity, "price": price, "duration_days": duration, "competitor_bid_pressure": competitor_pressure, "message": "Customer contract offer available."}
func _new_id() -> String:
    var value := "contract_%04d" % next_contract_id; next_contract_id += 1; return value
func create_customer_contract(parties: Array, product: String, quantity: int, price: int, quality_requirement: int, delivery_schedule: Dictionary, destination: String, penalty: int, cancellation: Dictionary, renewal: Dictionary, reputation_impact: Dictionary) -> Dictionary:
    if parties.size() < 2 or product.is_empty() or quantity <= 0 or price <= 0 or quality_requirement < 0 or quality_requirement > 100 or destination.is_empty() or penalty < 0: return {"ok": false, "message": "Invalid contract terms."}
    var customer_id := _customer_id(parties)
    if _get_relationship(customer_id) < 20: return {"ok": false, "message": "Customer relationship is too weak for this contract."}
    var duration := max(1, int(delivery_schedule.get("duration_days", 1))); var frequency := str(delivery_schedule.get("frequency", "daily")); var quantity_per_delivery := max(1, int(delivery_schedule.get("quantity_per_delivery", quantity))); var id := _new_id()
    var contract := {"id": id, "parties": parties.duplicate(true), "customer_id": customer_id, "resource_product": product, "quantity": quantity, "price": price, "quality_requirement": quality_requirement, "delivery_schedule": delivery_schedule.duplicate(true), "destination": destination, "penalty": penalty, "cancellation": cancellation.duplicate(true), "renewal": renewal.duplicate(true), "reputation_impact": reputation_impact.duplicate(true), "execution_status": "active", "signed_day": int(delivery_schedule.get("start_day", 1)), "days_elapsed": 0, "quantity_delivered": 0, "quantity_due": 0, "quality_delivered": 0, "revenue_earned": 0, "penalties_paid": 0, "missed_deliveries": 0, "cancel_reason": "", "renewal_offered": false, "renewed_contract_id": "", "last_execution": {}, "next_delivery_day": int(delivery_schedule.get("start_day", 1)), "schedule_frequency": frequency, "schedule_quantity": quantity_per_delivery, "customer_relationship_at_signing": _get_relationship(customer_id), "competitor_bid_pressure_at_signing": _competitor_bid_modifier()}
    active_contracts[id] = contract; _record("signed", id, {"customer": customer_id, "product": product, "quantity": quantity, "relationship": _get_relationship(customer_id)}); return {"ok": true, "contract": contract.duplicate(true)}
func create_default_customer_contract(day: int, reputation: int) -> Dictionary:
    var offer := get_future_contract_offer(reputation)
    if not bool(offer.get("eligible", false)): return offer
    var quantity := int(offer.get("quantity", 25)); var duration := int(offer.get("duration_days", 5)); var per_delivery := int(ceil(float(quantity) / float(duration)))
    return create_customer_contract(["RENEW Goods", DEFAULT_CUSTOMER], "consumer_goods", quantity, int(offer.get("price", 180)), 70, {"frequency": "daily", "quantity_per_delivery": per_delivery, "duration_days": duration, "start_day": day}, "Harbor District Retail Hub", 600, {"player_can_cancel": true, "notice_days": 1, "fee": 900}, {"eligible": true, "term_days": duration, "price_adjustment": 0.05}, {"on_fulfilled": 10, "on_missed": -2, "on_cancelled": -4, "on_failed": -20})
func execute_day(contract_id: String, available_quantity: int, average_quality: int, day: int) -> Dictionary:
    if not active_contracts.has(contract_id): return {"ok": false, "message": "Contract not found."}
    var contract: Dictionary = active_contracts[contract_id]
    if contract["execution_status"] != "active": return {"ok": false, "message": "Contract is not active."}
    var schedule: Dictionary = contract["delivery_schedule"]; var start_day := int(schedule.get("start_day", contract["signed_day"])); var duration := max(1, int(schedule.get("duration_days", 1)))
    if day < start_day: return {"ok": false, "message": "Delivery window has not started."}
    if int(contract["days_elapsed"]) >= duration: return {"ok": false, "message": "Contract delivery window has ended."}
    var frequency := str(schedule.get("frequency", "daily")); var delivery_day := true
    if frequency == "weekly": delivery_day = (int(contract["days_elapsed"]) % 7) == 0
    elif frequency == "every_2_days": delivery_day = (int(contract["days_elapsed"]) % 2) == 0
    elif frequency == "monthly": delivery_day = (int(contract["days_elapsed"]) % 30) == 0
    if not delivery_day:
        contract["days_elapsed"] = int(contract["days_elapsed"]) + 1; contract["last_execution"] = {"day": day, "due": 0, "delivered": 0, "shortfall": 0, "quality_ok": true, "revenue": 0, "penalty": 0, "scheduled": false}
        if int(contract["days_elapsed"]) >= duration: _finish(contract)
        else: active_contracts[contract_id] = contract
        return {"ok": true, "contract": contract.duplicate(true), "delivered": 0, "revenue": 0, "penalty": 0, "quality_ok": true, "shortfall": 0, "finished": int(contract["days_elapsed"]) >= duration, "scheduled": false}
    var daily_due := max(0, min(int(contract["quantity"]) - int(contract["quantity_due"]), int(schedule.get("quantity_per_delivery", contract["quantity"]))))
    var delivered := min(daily_due, max(0, available_quantity)); var quality_ok := average_quality >= int(contract["quality_requirement"])
    if not quality_ok: delivered = 0
    var shortfall := daily_due - delivered; var revenue := delivered * int(contract["price"]); var penalty := shortfall * int(contract["penalty"])
    if not quality_ok and daily_due > 0: penalty += int(contract["penalty"])
    contract["days_elapsed"] = int(contract["days_elapsed"]) + 1; contract["quantity_due"] = int(contract["quantity_due"]) + daily_due; contract["quantity_delivered"] = int(contract["quantity_delivered"]) + delivered; contract["quality_delivered"] = max(int(contract["quality_delivered"]), average_quality); contract["revenue_earned"] = int(contract["revenue_earned"]) + revenue; contract["penalties_paid"] = int(contract["penalties_paid"]) + penalty
    if shortfall > 0: contract["missed_deliveries"] = int(contract["missed_deliveries"]) + 1
    contract["last_execution"] = {"day": day, "due": daily_due, "delivered": delivered, "shortfall": shortfall, "quality_ok": quality_ok, "revenue": revenue, "penalty": penalty, "scheduled": true}
    var finished := int(contract["days_elapsed"]) >= duration or int(contract["quantity_due"]) >= int(contract["quantity"])
    if finished: _finish(contract)
    else: active_contracts[contract_id] = contract
    return {"ok": true, "contract": contract.duplicate(true), "delivered": delivered, "revenue": revenue, "penalty": penalty, "quality_ok": quality_ok, "shortfall": shortfall, "finished": finished, "scheduled": true}
func cancel_contract(contract_id: String, reason: String, day: int) -> Dictionary:
    if not active_contracts.has(contract_id): return {"ok": false, "message": "Contract not found."}
    var contract: Dictionary = active_contracts[contract_id]; var terms: Dictionary = contract["cancellation"]
    if not bool(terms.get("player_can_cancel", false)): return {"ok": false, "message": "This contract cannot be cancelled by the company."}
    contract["execution_status"] = "cancelled"; contract["cancel_reason"] = reason; var fee := int(terms.get("fee", 0)); contract["penalties_paid"] = int(contract["penalties_paid"]) + fee
    var customer_id := str(contract.get("customer_id", DEFAULT_CUSTOMER)); var before := _get_relationship(customer_id); _set_relationship(customer_id, before + int(contract.get("reputation_impact", {}).get("on_cancelled", -4))); contract["customer_relationship_change"] = _get_relationship(customer_id) - before
    _record("cancelled", contract_id, {"day": day, "reason": reason, "relationship": _get_relationship(customer_id)}); active_contracts.erase(contract_id); completed_contracts.append(contract.duplicate(true)); _trim_completed(); return {"ok": true, "contract": contract.duplicate(true), "penalty": fee, "customer_relationship": _get_relationship(customer_id), "relationship_change": contract["customer_relationship_change"]}
func renew_contract(contract_id: String, day: int) -> Dictionary:
    var source: Dictionary = {}
    for item in completed_contracts:
        if str(item.get("id", "")) == contract_id: source = item.duplicate(true); break
    if source.is_empty() or str(source.get("execution_status", "")) != "fulfilled" or not bool(source.get("renewal_offered", false)): return {"ok": false, "message": "Contract is not eligible for renewal."}
    var customer_id := str(source.get("customer_id", DEFAULT_CUSTOMER)); var relationship := _get_relationship(customer_id)
    if relationship < 50: return {"ok": false, "message": "Customer relationship is not strong enough for renewal."}
    var terms: Dictionary = source.get("renewal", {}); var new_price := max(1, int(round(float(source["price"]) * (1.0 + float(terms.get("price_adjustment", 0.0)))))
    var schedule: Dictionary = source["delivery_schedule"].duplicate(true); schedule["start_day"] = day; schedule["duration_days"] = max(1, int(terms.get("term_days", schedule.get("duration_days", 1))))
    var result := create_customer_contract(source["parties"], str(source["resource_product"]), int(source["quantity"]), new_price, int(source["quality_requirement"]), schedule, str(source["destination"]), int(source["penalty"]), source["cancellation"], source["renewal"], source["reputation_impact"])
    if bool(result.get("ok", false)):
        var new_id := str(result["contract"]["id"])
        for item in completed_contracts:
            if str(item.get("id", "")) == contract_id: item["renewed_contract_id"] = new_id; break
        _record("renewed", contract_id, {"new_contract_id": new_id, "day": day, "price": new_price, "relationship": relationship})
    return result
func _finish(contract: Dictionary) -> void:
    var due := max(1, int(contract["quantity_due"])); var delivered := int(contract["quantity_delivered"]); var fulfilment := float(delivered) / float(due); var status := "fulfilled" if fulfilment >= 0.999 and int(contract["missed_deliveries"]) == 0 else "breached"; contract["execution_status"] = status
    var customer_id := str(contract.get("customer_id", DEFAULT_CUSTOMER)); var impact: Dictionary = contract.get("reputation_impact", {}); var relationship_delta := int(impact.get("on_fulfilled", 10)) if status == "fulfilled" else int(impact.get("on_failed", -20)); var before := _get_relationship(customer_id)
    _set_relationship(customer_id, before + relationship_delta); contract["customer_relationship_before"] = before; contract["customer_relationship_after"] = _get_relationship(customer_id); contract["customer_relationship_change"] = relationship_delta; contract["renewal_offered"] = status == "fulfilled" and bool(contract["renewal"].get("eligible", false)) and _get_relationship(customer_id) >= 60
    _record(status, contract["id"], {"fulfilment": fulfilment, "revenue": contract["revenue_earned"], "penalties": contract["penalties_paid"], "customer": customer_id, "relationship_change": relationship_delta, "relationship": _get_relationship(customer_id)}); active_contracts.erase(contract["id"]); completed_contracts.append(contract.duplicate(true)); _trim_completed()
func _record(event_type: String, contract_id: String, details: Dictionary) -> void:
    history.append({"event": event_type, "contract_id": contract_id, "details": details}); if history.size() > MAX_HISTORY: history.pop_front()
func _trim_completed() -> void:
    while completed_contracts.size() > MAX_HISTORY: completed_contracts.pop_front()
func active_contract(id: String = "") -> Dictionary:
    if id.is_empty():
        for value in active_contracts.values(): return value.duplicate(true)
        return {}
    return active_contracts.get(id, {}).duplicate(true)
func list_active_contracts() -> Array:
    var result: Array = []
    for value in active_contracts.values(): result.append(value.duplicate(true))
    return result
func capture_state() -> Dictionary: return {"system_version": SYSTEM_VERSION, "next_contract_id": next_contract_id, "active_contracts": active_contracts.duplicate(true), "completed_contracts": completed_contracts.duplicate(true), "history": history.duplicate(true), "customer_relationships": customer_relationships.duplicate(true)}
func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    next_contract_id = max(1, int(snapshot.get("next_contract_id", 1))); active_contracts = snapshot.get("active_contracts", {}).duplicate(true); completed_contracts = snapshot.get("completed_contracts", []).duplicate(true); history = snapshot.get("history", []).duplicate(true); customer_relationships = snapshot.get("customer_relationships", {}).duplicate(true)
