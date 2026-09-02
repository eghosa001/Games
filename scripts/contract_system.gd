extends Node

const SYSTEM_VERSION := 1
const MAX_HISTORY := 500

var next_contract_id := 1
var active_contracts: Dictionary = {}
var completed_contracts: Array = []
var history: Array = []

func _new_id() -> String:
    var value := "contract_%04d" % next_contract_id
    next_contract_id += 1
    return value

func create_customer_contract(parties: Array, product: String, quantity: int, price: int, quality_requirement: int, delivery_schedule: Dictionary, destination: String, penalty: int, cancellation: Dictionary, renewal: Dictionary, reputation_impact: Dictionary) -> Dictionary:
    if product.is_empty() or quantity <= 0 or price <= 0:
        return {"ok": false, "message": "Invalid contract terms."}
    var id := _new_id()
    var contract := {"id": id, "parties": parties.duplicate(true), "resource_product": product, "quantity": quantity, "price": price, "quality_requirement": quality_requirement, "delivery_schedule": delivery_schedule.duplicate(true), "destination": destination, "penalty": penalty, "cancellation": cancellation.duplicate(true), "renewal": renewal.duplicate(true), "reputation_impact": reputation_impact.duplicate(true), "execution_status": "active", "signed_day": int(delivery_schedule.get("start_day", 1)), "days_elapsed": 0, "quantity_delivered": 0, "quantity_due": 0, "quality_delivered": 0, "revenue_earned": 0, "penalties_paid": 0, "missed_deliveries": 0, "cancel_reason": "", "renewal_offered": false, "last_execution": {}}
    active_contracts[id] = contract
    _record("signed", id, {"product": product, "quantity": quantity, "destination": destination})
    return {"ok": true, "contract": contract.duplicate(true)}

func create_default_customer_contract(day: int, reputation: int) -> Dictionary:
    return create_customer_contract(["RENEW Goods", "Harbor Retail Cooperative"], "consumer_goods", 25, 180 + reputation * 2, 70, {"frequency": "daily", "quantity_per_delivery": 5, "duration_days": 5, "start_day": day}, "Harbor District Retail Hub", 600, {"player_can_cancel": true, "notice_days": 1, "fee": 900}, {"eligible": true, "term_days": 5, "price_adjustment": 0.05}, {"on_fulfilled": 3, "on_missed": -2, "on_cancelled": -4, "on_failed": -8})

func execute_day(contract_id: String, available_quantity: int, average_quality: int, day: int) -> Dictionary:
    if not active_contracts.has(contract_id): return {"ok": false, "message": "Contract not found."}
    var contract: Dictionary = active_contracts[contract_id]
    var schedule: Dictionary = contract["delivery_schedule"]
    var daily_due := int(schedule.get("quantity_per_delivery", contract["quantity"]))
    var delivered := min(daily_due, max(0, available_quantity))
    var quality_ok := average_quality >= int(contract["quality_requirement"])
    if not quality_ok: delivered = 0
    var shortfall := daily_due - delivered
    var revenue := delivered * int(contract["price"])
    var penalty := shortfall * int(contract["penalty"])
    if not quality_ok and delivered == 0: penalty += int(contract["penalty"])
    contract["days_elapsed"] = int(contract["days_elapsed"]) + 1
    contract["quantity_due"] = int(contract["quantity_due"]) + daily_due
    contract["quantity_delivered"] = int(contract["quantity_delivered"]) + delivered
    contract["quality_delivered"] = max(int(contract["quality_delivered"]), average_quality)
    contract["revenue_earned"] = int(contract["revenue_earned"]) + revenue
    contract["penalties_paid"] = int(contract["penalties_paid"]) + penalty
    if shortfall > 0: contract["missed_deliveries"] = int(contract["missed_deliveries"]) + 1
    contract["last_execution"] = {"day": day, "due": daily_due, "delivered": delivered, "shortfall": shortfall, "quality_ok": quality_ok, "revenue": revenue, "penalty": penalty}
    var duration := int(schedule.get("duration_days", 1))
    var finished := int(contract["days_elapsed"]) >= duration
    if finished:
        _finish(contract)
    else:
        active_contracts[contract_id] = contract
    return {"ok": true, "contract": contract.duplicate(true), "delivered": delivered, "revenue": revenue, "penalty": penalty, "quality_ok": quality_ok, "shortfall": shortfall, "finished": finished}

func cancel_contract(contract_id: String, reason: String, day: int) -> Dictionary:
    if not active_contracts.has(contract_id): return {"ok": false, "message": "Contract not found."}
    var contract: Dictionary = active_contracts[contract_id]
    var terms: Dictionary = contract["cancellation"]
    if not bool(terms.get("player_can_cancel", false)): return {"ok": false, "message": "This contract cannot be cancelled by the company."}
    contract["execution_status"] = "cancelled"
    contract["cancel_reason"] = reason
    contract["penalties_paid"] = int(contract["penalties_paid"]) + int(terms.get("fee", 0))
    _record("cancelled", contract_id, {"day": day, "reason": reason})
    active_contracts.erase(contract_id)
    completed_contracts.append(contract)
    _trim_completed()
    return {"ok": true, "contract": contract.duplicate(true)}

func _finish(contract: Dictionary) -> void:
    var due := max(1, int(contract["quantity_due"]))
    var delivered := int(contract["quantity_delivered"])
    var fulfilment := float(delivered) / float(due)
    var status := "fulfilled" if fulfilment >= 0.999 and int(contract["missed_deliveries"]) == 0 else "breached"
    contract["execution_status"] = status
    var renewal: Dictionary = contract["renewal"]
    contract["renewal_offered"] = status == "fulfilled" and bool(renewal.get("eligible", false))
    _record(status, contract["id"], {"fulfilment": fulfilment, "revenue": contract["revenue_earned"], "penalties": contract["penalties_paid"]})
    active_contracts.erase(contract["id"])
    completed_contracts.append(contract.duplicate(true))
    _trim_completed()

func _record(event_type: String, contract_id: String, details: Dictionary) -> void:
    history.append({"event": event_type, "contract_id": contract_id, "details": details})
    if history.size() > MAX_HISTORY: history.pop_front()

func _trim_completed() -> void:
    while completed_contracts.size() > MAX_HISTORY: completed_contracts.pop_front()

func active_contract(id: String = "") -> Dictionary:
    if id.is_empty():
        for value in active_contracts.values(): return value.duplicate(true)
        return {}
    return active_contracts.get(id, {}).duplicate(true)

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "next_contract_id": next_contract_id, "active_contracts": active_contracts.duplicate(true), "completed_contracts": completed_contracts.duplicate(true), "history": history.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    next_contract_id = max(1, int(snapshot.get("next_contract_id", 1)))
    active_contracts = snapshot.get("active_contracts", {}).duplicate(true)
    completed_contracts = snapshot.get("completed_contracts", []).duplicate(true)
    history = snapshot.get("history", []).duplicate(true)
