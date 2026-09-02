extends Node

## RENEW acquisition ledger.
## Acquisitions are asset/control transactions, not simple cash transfers.
## Supports asset purchases, negotiated sales, auctions, hostile acquisitions,
## shareholder accumulation and mergers while preserving a due-diligence trail.

const TYPE_ASSET_PURCHASE := "asset_purchase"
const TYPE_NEGOTIATED_SALE := "negotiated_sale"
const TYPE_AUCTION := "auction"
const TYPE_HOSTILE := "hostile_acquisition"
const TYPE_SHARE_ACCUMULATION := "shareholder_accumulation"
const TYPE_MERGER := "merger"

var acquisitions: Array[Dictionary] = []
var targets: Dictionary = {}
var next_id := 1

func register_target(target_id: String, target_name: String = "", assets: Array = [], debt: float = 0.0, employees: int = 0, contracts: Array = [], liabilities: float = 0.0, reputation: float = 0.0, hidden_risks: Array = []) -> Dictionary:
    if target_id.is_empty(): return {"ok": false, "error": "target_id_required"}
    targets[target_id] = {"id": target_id, "name": target_name if not target_name.is_empty() else target_id, "assets": assets.duplicate(true), "debt": max(0.0, debt), "employees": max(0, employees), "contracts": contracts.duplicate(true), "liabilities": max(0.0, liabilities), "reputation": reputation, "hidden_risks": hidden_risks.duplicate(true), "owners": {}, "status": "independent"}
    return {"ok": true, "target": targets[target_id].duplicate(true)}

func get_target(target_id: String) -> Dictionary: return targets.get(target_id, {}).duplicate(true)

func due_diligence(target_id: String) -> Dictionary:
    var target := targets.get(target_id, {})
    if target.is_empty(): return {"ok": false, "error": "target_not_found"}
    var asset_value := 0.0
    for asset in target.get("assets", []):
        if asset is Dictionary: asset_value += float(asset.get("value", asset.get("cost", 0.0)))
    var liabilities := float(target.get("debt", 0.0)) + float(target.get("liabilities", 0.0))
    var risk_score := min(100.0, float(target.get("hidden_risks", []).size()) * 12.0 + liabilities / max(1.0, asset_value) * 35.0)
    return {"ok": true, "asset_value": asset_value, "debt": target.get("debt", 0.0), "liabilities": target.get("liabilities", 0.0), "employees": target.get("employees", 0), "contracts": target.get("contracts", []).size(), "reputation": target.get("reputation", 0.0), "hidden_risk_count": target.get("hidden_risks", []).size(), "risk_score": risk_score, "net_asset_value": asset_value - liabilities}

func acquire_asset(acquirer_id: String, target_id: String, asset_index: int, price: float, cash_available: float) -> Dictionary:
    var target := targets.get(target_id, {})
    if target.is_empty() or asset_index < 0 or asset_index >= target.get("assets", []).size() or price < 0.0: return {"ok": false, "error": "invalid_asset_purchase"}
    if cash_available < price: return {"ok": false, "error": "insufficient_cash"}
    var asset = target["assets"][asset_index]
    target["assets"].remove_at(asset_index)
    targets[target_id] = target
    return _record_transaction(TYPE_ASSET_PURCHASE, acquirer_id, target_id, price, {"assets": [asset], "debt_assumed": 0.0, "liabilities_assumed": 0.0, "employees_transferred": 0, "contracts_transferred": [], "reputation_transfer": 0.0, "hidden_risks": []})

func acquire_company(acquirer_id: String, target_id: String, price: float, method: String = TYPE_NEGOTIATED_SALE, assume_debt: bool = true, retain_employees: bool = true, assume_liabilities: bool = true, transfer_contracts: bool = true, reputation_transfer: float = 1.0) -> Dictionary:
    var target := targets.get(target_id, {})
    if target.is_empty() or price < 0.0: return {"ok": false, "error": "invalid_company_acquisition"}
    if not [TYPE_NEGOTIATED_SALE, TYPE_AUCTION, TYPE_HOSTILE, TYPE_SHARE_ACCUMULATION, TYPE_MERGER].has(method): return {"ok": false, "error": "invalid_acquisition_method"}
    var diligence := due_diligence(target_id)
    var transferred := {"assets": target.get("assets", []).duplicate(true), "debt_assumed": float(target.get("debt", 0.0)) if assume_debt else 0.0, "liabilities_assumed": float(target.get("liabilities", 0.0)) if assume_liabilities else 0.0, "employees_transferred": int(target.get("employees", 0)) if retain_employees else 0, "contracts_transferred": target.get("contracts", []).duplicate(true) if transfer_contracts else [], "reputation_transfer": float(target.get("reputation", 0.0)) * reputation_transfer, "hidden_risks": target.get("hidden_risks", []).duplicate(true)}
    var result := _record_transaction(method, acquirer_id, target_id, price, transferred)
    if bool(result.get("ok", false)):
        target["status"] = "merged" if method == TYPE_MERGER else "acquired"
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
    var target := targets.get(target_id, {})
    if target.is_empty(): return {"ok": false, "error": "target_not_found"}
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    var control_bridge = get_node_or_null("/root/RenewDiplomacyControl")
    if diplomacy != null and control_bridge != null:
        for owner_id in target.get("owners", {}).keys():
            var owner := str(owner_id)
            if owner != acquirer_id and control_bridge.has_defense_treaty(owner, acquirer_id):
                return {"ok": false, "error": "defense_treaty_blocks_hostile_acquisition", "owner": owner, "target_id": target_id, "treaty": control_bridge.get_defense_treaty(owner, acquirer_id)}
    var result := acquire_company(acquirer_id, target_id, offer, TYPE_HOSTILE)
    if bool(result.get("ok", false)): result["control_percent"] = control_percent
    return result

func accumulate_shares(acquirer_id: String, target_id: String, shares: float, price: float) -> Dictionary:
    var target := targets.get(target_id, {})
    if target.is_empty() or shares <= 0.0 or price < 0.0: return {"ok": false, "error": "invalid_share_accumulation"}
    var owners: Dictionary = target.get("owners", {})
    var current := float(owners.get(acquirer_id, 0.0))
    owners[acquirer_id] = min(100.0, current + shares)
    target["owners"] = owners
    if owners[acquirer_id] >= 50.1: target["status"] = "controlled"
    targets[target_id] = target
    return _record_transaction(TYPE_SHARE_ACCUMULATION, acquirer_id, target_id, price, {"shares_percent": shares, "new_control_percent": owners[acquirer_id], "assets": [], "debt_assumed": 0.0, "liabilities_assumed": 0.0, "employees_transferred": 0, "contracts_transferred": [], "reputation_transfer": 0.0, "hidden_risks": []})

func merge_entities(acquirer_id: String, target_id: String, price: float, share_exchange: float = 0.0) -> Dictionary:
    var result := acquire_company(acquirer_id, target_id, price, TYPE_MERGER)
    if bool(result.get("ok", false)): result["share_exchange_percent"] = share_exchange
    return result

func get_acquisition_history(target_id: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in acquisitions:
        if target_id.is_empty() or str(entry.get("target_id", "")) == target_id: result.append(entry.duplicate(true))
    return result

func capture_state() -> Dictionary:
    return {"system_version": 1, "next_id": next_id, "targets": targets.duplicate(true), "acquisitions": acquisitions.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    next_id = int(snapshot.get("next_id", 1)); targets = snapshot.get("targets", {}).duplicate(true); acquisitions = snapshot.get("acquisitions", []).duplicate(true)

func _record_transaction(method: String, acquirer_id: String, target_id: String, price: float, transferred: Dictionary) -> Dictionary:
    var entry := {"id": next_id, "method": method, "acquirer_id": acquirer_id, "target_id": target_id, "price": price, "transferred": transferred.duplicate(true), "timestamp": Time.get_unix_time_from_system()}
    next_id += 1
    acquisitions.append(entry)
    if acquisitions.size() > 1000: acquisitions.pop_front()
    return {"ok": true, "acquisition": entry.duplicate(true)}
