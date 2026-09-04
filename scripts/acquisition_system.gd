extends Node

## RENEW acquisition ledger.
## Acquisitions are asset/control transactions, not simple cash transfers.
## Mergers resolve the operating and corporate state of both organizations.

const DomainSystem = preload("res://scripts/domain_system.gd")
const TYPE_ASSET_PURCHASE := "asset_purchase"
const TYPE_NEGOTIATED_SALE := "negotiated_sale"
const TYPE_AUCTION := "auction"
const TYPE_HOSTILE := "hostile_acquisition"
const TYPE_SHARE_ACCUMULATION := "shareholder_accumulation"
const TYPE_MERGER := "merger"

var acquisitions: Array = []
var mergers: Array = []
var targets: Dictionary = {}
var next_id: Variant = 1
var state_adapter: Variant = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func register_target(target_id: String, target_name: String = "", assets: Array = [], debt: float = 0.0, employees: int = 0, contracts: Array = [], liabilities: float = 0.0, reputation: float = 0.0, hidden_risks: Array = [], extra_state: Dictionary = {}) -> Dictionary:
    if target_id.is_empty(): return {"ok": false, "error": "target_id_required"}
    var target: Variant = {"id": target_id, "name": target_name if not target_name.is_empty() else target_id, "assets": assets.duplicate(true), "debt": max(0.0, debt), "employees": max(0, employees), "contracts": contracts.duplicate(true), "liabilities": max(0.0, liabilities), "reputation": reputation, "hidden_risks": hidden_risks.duplicate(true), "owners": {}, "status": "independent"}
    for key in extra_state.keys(): target[str(key)] = extra_state[key]
    targets[target_id] = target
    return {"ok": true, "target": target.duplicate(true)}

func get_target(target_id: String) -> Dictionary: return targets.get(target_id, {}).duplicate(true)

func due_diligence(target_id: String) -> Dictionary:
    var target: Variant = targets.get(target_id, {})
    if target.is_empty(): return {"ok": false, "error": "target_not_found"}
    var asset_value: Variant = 0.0
    for asset in target.get("assets", []):
        if asset is Dictionary: asset_value += float(asset.get("value", asset.get("cost", 0.0)))
    var liabilities: Variant = float(target.get("debt", 0.0)) + float(target.get("liabilities", 0.0))
    var risk_score: Variant = min(100.0, float(target.get("hidden_risks", []).size()) * 12.0 + liabilities / max(1.0, asset_value) * 35.0)
    return {"ok": true, "asset_value": asset_value, "debt": target.get("debt", 0.0), "liabilities": target.get("liabilities", 0.0), "employees": target.get("employees", 0), "contracts": target.get("contracts", []).size(), "reputation": target.get("reputation", 0.0), "hidden_risk_count": target.get("hidden_risks", []).size(), "risk_score": risk_score, "net_asset_value": asset_value - liabilities}

func acquire_asset(acquirer_id: String, target_id: String, asset_index: int, price: float, cash_available: float) -> Dictionary:
    var target: Variant = targets.get(target_id, {})
    if target.is_empty() or asset_index < 0 or asset_index >= target.get("assets", []).size() or price < 0.0: return {"ok": false, "error": "invalid_asset_purchase"}
    if cash_available < price: return {"ok": false, "error": "insufficient_cash"}
    if price > 0.0:
        var spend := state_adapter.spend(int(ceil(price)), "asset acquisition")
        if not bool(spend.get("ok", false)): return {"ok": false, "error": "insufficient_cash", "cash": int(state_adapter.get_value("economy", "cash", 0))}
    var asset = target["assets"][asset_index]
    target["assets"].remove_at(asset_index)
    targets[target_id] = target
    return _record_transaction(TYPE_ASSET_PURCHASE, acquirer_id, target_id, price, {"assets": [asset], "debt_assumed": 0.0, "liabilities_assumed": 0.0, "employees_transferred": 0, "contracts_transferred": [], "reputation_transfer": 0.0, "hidden_risks": []})

func acquire_company(acquirer_id: String, target_id: String, price: float, method: String = TYPE_NEGOTIATED_SALE, assume_debt: bool = true, retain_employees: bool = true, assume_liabilities: bool = true, transfer_contracts: bool = true, reputation_transfer: float = 1.0) -> Dictionary:
    if method == TYPE_MERGER: return merge_entities(acquirer_id, target_id, price)
    var target: Variant = targets.get(target_id, {})
    if target.is_empty() or price < 0.0: return {"ok": false, "error": "invalid_company_acquisition"}
    if not [TYPE_NEGOTIATED_SALE, TYPE_AUCTION, TYPE_HOSTILE, TYPE_SHARE_ACCUMULATION].has(method): return {"ok": false, "error": "invalid_acquisition_method"}
    var diligence: Variant = due_diligence(target_id)
    var transferred: Variant = {"assets": target.get("assets", []).duplicate(true), "debt_assumed": float(target.get("debt", 0.0)) if assume_debt else 0.0, "liabilities_assumed": float(target.get("liabilities", 0.0)) if assume_liabilities else 0.0, "employees_transferred": int(target.get("employees", 0)) if retain_employees else 0, "contracts_transferred": target.get("contracts", []).duplicate(true) if transfer_contracts else [], "reputation_transfer": float(target.get("reputation", 0.0)) * reputation_transfer, "hidden_risks": target.get("hidden_risks", []).duplicate(true)}
    if price > 0.0:
        var spend := state_adapter.spend(int(ceil(price)), "company acquisition: %s" % target_id)
        if not bool(spend.get("ok", false)): return {"ok": false, "error": "insufficient_cash", "cash": int(state_adapter.get_value("economy", "cash", 0)), "required": int(ceil(price))}
    var result: Variant = _record_transaction(method, acquirer_id, target_id, price, transferred)
    if bool(result.get("ok", false)):
        target["status"] = "acquired"
        target["owners"] = {acquirer_id: 100.0}
        targets[target_id] = target
        result["due_diligence"] = diligence
    return result

func auction_target(acquirer_id: String, target_id: String, bid: float, reserve: float, cash_available: float) -> Dictionary:
    if bid < reserve: return {"ok": false, "error": "reserve_not_met"}
    if cash_available < bid: return {"ok": false, "error": "insufficient_cash"}
    return acquire_company(acquirer_id, target_id, bid, TYPE_AUCTION)

func hostile_acquire(acquirer_id: String, target_id: String, offer: float, control_percent: float = 50.1) -> Dictionary:
    if control_percent < 50.1 or control_percent > 100.0: return {"ok": false, "error": "invalid_control_target"}
    var target: Variant = targets.get(target_id, {})
    if target.is_empty(): return {"ok": false, "error": "target_not_found"}
    var control_bridge = get_node_or_null("/root/RenewDiplomacyControl")
    if control_bridge != null:
        for owner_id in target.get("owners", {}).keys():
            var owner: Variant = str(owner_id)
            if owner != acquirer_id and control_bridge.has_defense_treaty(owner, acquirer_id):
                return {"ok": false, "error": "defense_treaty_blocks_hostile_acquisition", "owner": owner, "target_id": target_id, "treaty": control_bridge.get_defense_treaty(owner, acquirer_id)}
    var result: Variant = acquire_company(acquirer_id, target_id, offer, TYPE_HOSTILE)
    if bool(result.get("ok", false)): result["control_percent"] = control_percent
    return result

func accumulate_shares(acquirer_id: String, target_id: String, shares: float, price: float) -> Dictionary:
    var target: Variant = targets.get(target_id, {})
    if target.is_empty() or shares <= 0.0 or price < 0.0: return {"ok": false, "error": "invalid_share_accumulation"}
    var owners: Dictionary = target.get("owners", {})
    var current: Variant = float(owners.get(acquirer_id, 0.0))
    var new_percent: Variant = min(100.0, current + shares)
    if price > 0.0:
        var spend := state_adapter.spend(int(ceil(price)), "share accumulation: %s" % target_id)
        if not bool(spend.get("ok", false)): return {"ok": false, "error": "insufficient_cash", "cash": int(state_adapter.get_value("economy", "cash", 0)), "required": int(ceil(price))}
    owners[acquirer_id] = new_percent
    if new_percent >= 50.1: target["status"] = "controlled"
    target["owners"] = owners
    targets[target_id] = target
    return _record_transaction(TYPE_SHARE_ACCUMULATION, acquirer_id, target_id, price, {"shares_percent": shares, "new_control_percent": new_percent, "assets": [], "debt_assumed": 0.0, "liabilities_assumed": 0.0, "employees_transferred": 0, "contracts_transferred": [], "reputation_transfer": 0.0, "hidden_risks": []})

## Comprehensive merger. The target is absorbed into the surviving company while
## preserving an auditable resolution of ownership, value, debt and operations.
func merge_entities(acquirer_id: String, target_id: String, price: float, share_exchange: float = 0.0, terms: Dictionary = {}) -> Dictionary:
    var target: Variant = targets.get(target_id, {})
    if target.is_empty(): return {"ok": false, "error": "target_not_found"}
    if acquirer_id.is_empty() or acquirer_id == target_id: return {"ok": false, "error": "invalid_merger_parties"}
    if price < 0.0 or share_exchange < 0.0 or share_exchange > 100.0: return {"ok": false, "error": "invalid_merger_terms"}

    var diligence: Variant = due_diligence(target_id)
    var valuation_data: Variant = _resolve_valuation(target, price, terms)
    # Finance is settled before ownership mutation. This prevents a failed
    # affordability check from leaving the ownership ledger partially changed.
    var finance_result: Variant = _resolve_merger_finance(target, price, terms)
    if not bool(finance_result.get("ok", false)): return finance_result
    var ownership_result: Variant = _resolve_merger_ownership(acquirer_id, target_id, target, share_exchange, terms)
    if not bool(ownership_result.get("ok", false)):
        _rollback_merger_finance(finance_result)
        return ownership_result

    var employee_result: Variant = _resolve_merger_employees(target, terms)
    var management_result: Variant = _resolve_management(target, terms)
    var property_result: Variant = _combine_collection("properties", target, terms)
    var branch_result: Variant = _combine_collection("branches", target, terms)
    var contract_result: Variant = _combine_collection("contracts", target, terms)
    var brand_result: Variant = _combine_collection("brands", target, terms)
    var technology_result: Variant = _combine_collection("technology", target, terms)

    var reputation_before: Variant = _surviving_reputation(acquirer_id, terms)
    var reputation_after: Variant = _resolve_reputation(reputation_before, float(target.get("reputation", 0.0)), terms)

    var consolidated_assets: Array = []
    var source_assets: Variant = target.get("assets", [])
    for asset in source_assets: consolidated_assets.append(asset.duplicate(true) if asset is Dictionary else asset)

    var resolution: Variant = {
        "valuation": valuation_data,
        "ownership": ownership_result,
        "debt": finance_result,
        "employees": employee_result,
        "management": management_result,
        "properties": property_result,
        "branches": branch_result,
        "contracts": contract_result,
        "brands": brand_result,
        "technology": technology_result,
        "reputation": {"surviving_before": reputation_before, "target": float(target.get("reputation", 0.0)), "surviving_after": reputation_after},
        "assets": {"transferred": consolidated_assets, "asset_value": float(diligence.get("asset_value", 0.0))},
        "hidden_risks": target.get("hidden_risks", []).duplicate(true),
        "status": "completed"
    }

    var merged_target: Variant = target.duplicate(true)
    merged_target["status"] = "merged_into:%s" % acquirer_id
    merged_target["merged_into"] = acquirer_id
    merged_target["merger_resolution"] = resolution.duplicate(true)
    targets[target_id] = merged_target

    var merger_entry: Variant = {"id": next_id, "type": TYPE_MERGER, "surviving_company": acquirer_id, "target_id": target_id, "cash_consideration": price, "share_exchange_percent": share_exchange, "terms": terms.duplicate(true), "resolution": resolution.duplicate(true), "timestamp": Time.get_unix_time_from_system()}
    next_id += 1
    mergers.append(merger_entry)
    if mergers.size() > 500: mergers.pop_front()
    acquisitions.append(merger_entry.duplicate(true))
    if acquisitions.size() > 1000: acquisitions.pop_front()

    return {"ok": true, "merger": merger_entry.duplicate(true), "due_diligence": diligence, "resolution": resolution.duplicate(true)}

func get_merger_history(target_id: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in mergers:
        if target_id.is_empty() or str(entry.get("target_id", "")) == target_id: result.append(entry.duplicate(true))
    return result

func get_acquisition_history(target_id: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in acquisitions:
        if target_id.is_empty() or str(entry.get("target_id", "")) == target_id: result.append(entry.duplicate(true))
    return result

func capture_state() -> Dictionary:
    return {"system_version": 2, "next_id": next_id, "targets": targets.duplicate(true), "acquisitions": acquisitions.duplicate(true), "mergers": mergers.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    next_id = int(snapshot.get("next_id", 1)); targets = snapshot.get("targets", {}).duplicate(true); acquisitions = snapshot.get("acquisitions", []).duplicate(true); mergers = snapshot.get("mergers", []).duplicate(true)

func _resolve_valuation(target: Dictionary, price: float, terms: Dictionary) -> Dictionary:
    var assets: Variant = 0.0
    for asset in target.get("assets", []):
        if asset is Dictionary: assets += float(asset.get("value", asset.get("cost", 0.0)))
    var debt: Variant = float(target.get("debt", 0.0)) + float(target.get("liabilities", 0.0))
    var target_value: Variant = max(0.0, assets - debt)
    var negotiated: Variant = float(terms.get("target_valuation", price if price > 0.0 else target_value))
    var premium: Variant = 0.0 if target_value <= 0.0 else (negotiated - target_value) / target_value * 100.0
    return {"asset_value": assets, "net_asset_value": target_value, "agreed_value": max(0.0, negotiated), "premium_percent": premium, "consideration": price}

func _resolve_merger_ownership(acquirer_id: String, target_id: String, target: Dictionary, share_exchange: float, terms: Dictionary) -> Dictionary:
    var ownership = get_node_or_null("/root/RenewOwnershipSystem")
    if ownership == null: ownership = get_tree().current_scene.get_node_or_null("OwnershipSystem") if get_tree().current_scene != null else null
    var surviving_entity: Variant = str(terms.get("surviving_entity", acquirer_id))
    var target_entity: Variant = str(terms.get("target_entity", target_id))
    var target_percent: Variant = float(terms.get("target_owner_percent", 0.0))
    var transferred_percent: Variant = share_exchange
    if target_percent > 0.0: transferred_percent = target_percent
    if ownership != null and ownership.has_method("has_entity"):
        if not ownership.has_entity(surviving_entity): return {"ok": false, "error": "surviving_ownership_entity_not_found", "entity": surviving_entity}
        if ownership.has_entity(target_entity) and transferred_percent > 0.0:
            var target_owners: Dictionary = target.get("owners", {})
            for owner_id in target_owners.keys():
                var owner: Variant = str(owner_id)
                var pct: Variant = float(target_owners[owner]) * transferred_percent / 100.0
                var holder = ownership.get_entity(target_entity).get("holders", {}).get(owner, {})
                var classes: Dictionary = holder.get("classes", {}) if holder is Dictionary else {}
                var ordinary: Variant = int(classes.get(ownership.VOTE_ORDINARY, 0))
                if ordinary > 0:
                    var amount: Variant = int(round(float(ordinary) * pct / 100.0))
                    if amount > 0:
                        var transfer_result: Dictionary = ownership.transfer_shares(target_entity, owner, surviving_entity, amount, ownership.VOTE_ORDINARY, "merger_absorption")
                        if not bool(transfer_result.get("ok", false)):
                            return {"ok": false, "error": "ownership_share_transfer_failed", "owner": owner, "amount": amount, "details": transfer_result}
        return {"ok": true, "surviving_entity": surviving_entity, "target_entity": target_entity, "share_exchange_percent": transferred_percent, "control_survives": true}
    return {"ok": true, "surviving_entity": surviving_entity, "target_entity": target_entity, "share_exchange_percent": transferred_percent, "control_survives": true, "ledger": "ownership system unavailable; merger resolution recorded"}

func _resolve_merger_finance(target: Dictionary, price: float, terms: Dictionary) -> Dictionary:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if finance == null: return {"ok": true, "cash_consideration": price, "debt_assumed": float(target.get("debt", 0.0)), "liabilities_assumed": float(target.get("liabilities", 0.0)), "ledger": "finance system unavailable; merger resolution recorded"}
    var debt_assumed: Variant = float(target.get("debt", 0.0)) if bool(terms.get("assume_debt", true)) else 0.0
    var liabilities_assumed: Variant = float(target.get("liabilities", 0.0)) if bool(terms.get("assume_liabilities", true)) else 0.0
    var consideration: Variant = int(max(0.0, price))
    if consideration > 0:
        var spend_result: Dictionary = state_adapter.spend(consideration, "merger consideration")
        if not bool(spend_result.get("ok", false)): return {"ok": false, "error": "insufficient_cash_for_merger", "required": consideration, "cash": finance.available_cash()}
    if debt_assumed > 0.0: finance.debt += int(round(debt_assumed))
    if liabilities_assumed > 0.0: finance.other_liabilities += liabilities_assumed
    var asset_value: Variant = 0.0
    for asset in target.get("assets", []):
        if asset is Dictionary: asset_value += float(asset.get("value", asset.get("cost", 0.0)))
    finance.fixed_assets += asset_value
    return {"ok": true, "cash_consideration": consideration, "debt_assumed": debt_assumed, "liabilities_assumed": liabilities_assumed, "assets_added": asset_value, "cash_after": finance.available_cash(), "debt_after": finance.debt}

func _rollback_merger_finance(finance_result: Dictionary) -> void:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if finance == null: return
    var consideration := int(finance_result.get("cash_consideration", 0))
    var debt_assumed := int(round(float(finance_result.get("debt_assumed", 0.0))))
    var liabilities_assumed := float(finance_result.get("liabilities_assumed", 0.0))
    var assets_added := float(finance_result.get("assets_added", 0.0))
    if consideration > 0:
        finance.receive(consideration, "merger rollback refund")
    finance.debt = max(0, finance.debt - debt_assumed)
    finance.other_liabilities = max(0.0, finance.other_liabilities - liabilities_assumed)
    finance.fixed_assets = max(0.0, finance.fixed_assets - assets_added)

func _resolve_merger_employees(target: Dictionary, terms: Dictionary) -> Dictionary:
    var employee_system = get_node_or_null("/root/RenewEmployeeSystem")
    var source: Array = target.get("employee_roster", [])
    var count: Variant = int(target.get("employees", source.size()))
    if employee_system == null: return {"retained": count, "source_roster": source.duplicate(true), "policy": str(terms.get("employee_policy", "retain"))}
    var policy: Variant = str(terms.get("employee_policy", "retain"))
    var retained: Variant = count if policy != "downsize" else int(round(float(count) * float(terms.get("retention_percent", 80.0)) / 100.0)
    var added: Variant = 0
    if not source.is_empty() and employee_system.get("employees") is Array:
        for employee in source:
            if added >= retained: break
            if employee is Dictionary:
                var copy: Variant = employee.duplicate(true)
                copy["id"] = "merged_%s_%s" % [str(target.get("id", "target")), str(copy.get("id", added))]
                copy["status"] = "active"
                employee_system.employees.append(copy)
                added += 1
    return {"retained": retained, "added_to_roster": added, "policy": policy, "target_count": count}

func _resolve_management(target: Dictionary, terms: Dictionary) -> Dictionary:
    var policy: Variant = str(terms.get("management_policy", "survivor_leads"))
    var target_management = target.get("management", target.get("leadership", []))
    var incoming: Variant = target_management.duplicate(true) if target_management is Array else target_management
    return {"policy": policy, "incoming_management": incoming, "successor": terms.get("successor_manager", ""), "integration_period": int(terms.get("management_integration_days", 30))}

func _combine_collection(key: String, target: Dictionary, terms: Dictionary) -> Dictionary:
    var values = target.get(key, [])
    var policy: Variant = str(terms.get("%s_policy" % key, "combine"))
    var items: Array = []
    if values is Array:
        for item in values: items.append(item.duplicate(true) if item is Dictionary else item)
    elif values is Dictionary:
        for item_key in values.keys(): items.append({"id": str(item_key), "value": values[item_key].duplicate(true) if values[item_key] is Dictionary else values[item_key]})
    return {"policy": policy, "items": items, "count": items.size()}

func _surviving_reputation(_acquirer_id: String, terms: Dictionary) -> float:
    if terms.has("surviving_reputation"): return float(terms["surviving_reputation"])
    return 0.0

func _resolve_reputation(surviving: float, target: float, terms: Dictionary) -> float:
    var target_weight: Variant = clamp(float(terms.get("reputation_weight", 0.35)), 0.0, 1.0)
    return clamp(surviving * (1.0 - target_weight) + target * target_weight, 0.0, 100.0)

func _record_transaction(method: String, acquirer_id: String, target_id: String, price: float, transferred: Dictionary) -> Dictionary:
    var entry: Variant = {"id": next_id, "method": method, "acquirer_id": acquirer_id, "target_id": target_id, "price": price, "transferred": transferred.duplicate(true), "timestamp": Time.get_unix_time_from_system()}
    next_id += 1
    acquisitions.append(entry)
    if acquisitions.size() > 1000: acquisitions.pop_front()
    return {"ok": true, "acquisition": entry.duplicate(true)}