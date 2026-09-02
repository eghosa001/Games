extends Node

## RENEW Bankruptcy & Restructuring System.
## Models the full distress lifecycle instead of a binary bankrupt flag:
## healthy -> cash crisis -> covenant pressure -> restructuring -> recovery
## or insolvency -> administration -> liquidation/acquisition.

const STABLE := "stable"
const CASH_CRISIS := "cash_crisis"
const COVENANT_PRESSURE := "covenant_pressure"
const RESTRUCTURING := "restructuring"
const RECOVERY := "recovery"
const INSOLVENT := "insolvent"
const ADMINISTRATION := "administration"
const LIQUIDATION := "liquidation"
const ACQUIRED := "acquired"

var state := STABLE
var previous_state := STABLE
var distress_score: float = 0.0
var cash_runway: float = INF
var covenant_breaches: Array[String] = []
var restructuring_plan: Dictionary = {}
var asset_sale_history: Array[Dictionary] = []
var investment_history: Array[Dictionary] = []
var downsizing_history: Array[Dictionary] = []
var refinancing_history: Array[Dictionary] = []
var administration_history: Array[Dictionary] = []
var liquidation_history: Array[Dictionary] = []
var events: Array[Dictionary] = []
var recovery_days := 0
var next_plan_id := 1

func evaluate(finance: Node, daily_cash_burn: float = 0.0) -> Dictionary:
    if finance == null:
        return {"ok": false, "message": "Finance system is required."}
    var bs: Dictionary = finance.balance_sheet()
    var solvency: Dictionary = finance.solvency_status()
    var cash := float(bs.get("cash", 0.0))
    var debt := float(bs.get("debt", 0.0))
    var liabilities := float(bs.get("liabilities", 0.0))
    var equity := float(bs.get("equity", 0.0))
    var coverage := float(solvency.get("interest_coverage", INF))
    var leverage := float(solvency.get("leverage", 0.0))
    var service := max(0.0, float(finance.debt_service()))
    daily_cash_burn = max(0.0, daily_cash_burn)
    cash_runway = INF if daily_cash_burn <= 0.0 else cash / daily_cash_burn
    covenant_breaches.clear()
    if debt > 0.0 and cash < service:
        covenant_breaches.append("debt_service")
    if leverage > 5.0:
        covenant_breaches.append("leverage")
    if coverage < 1.0:
        covenant_breaches.append("interest_coverage")
    if equity < 0.0:
        covenant_breaches.append("negative_equity")
    if cash < 0.0:
        covenant_breaches.append("negative_cash")

    distress_score = 0.0
    if cash < max(5000.0, service * 3.0): distress_score += 25.0
    if cash_runway < 14.0: distress_score += 20.0
    if coverage < 1.0: distress_score += 25.0
    elif coverage < 2.0: distress_score += 10.0
    if leverage > 5.0: distress_score += 20.0
    elif leverage > 3.0: distress_score += 10.0
    if equity < 0.0: distress_score += 35.0
    if liabilities > max(1.0, float(bs.get("assets", 0.0))): distress_score += 20.0

    if state in [LIQUIDATION, ACQUIRED]:
        return status()
    if equity < 0.0 or cash < 0.0:
        _transition(INSOLVENT, "balance sheet insolvency detected")
    elif distress_score >= 70.0:
        _transition(COVENANT_PRESSURE, "multiple financial covenants under pressure")
    elif distress_score >= 35.0:
        _transition(CASH_CRISIS, "cash liquidity has entered crisis territory")
    elif state in [RESTRUCTURING, RECOVERY] and distress_score < 25.0:
        recovery_days += 1
        if recovery_days >= 5:
            _transition(RECOVERY, "sustained financial improvement")
    else:
        recovery_days = 0
        if state not in [RESTRUCTURING, RECOVERY]: _transition(STABLE, "financial position stabilized")
    return status()

func begin_restructuring(reason: String = "covenant pressure") -> Dictionary:
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, INSOLVENT, RESTRUCTURING]:
        return {"ok": false, "message": "Restructuring is only available during financial distress."}
    state = RESTRUCTURING
    restructuring_plan = {
        "id": "restruct_%d" % next_plan_id,
        "reason": reason,
        "asset_sales": 0,
        "investment": 0,
        "downsizing": 0,
        "refinancing": 0,
        "created_day": _game_day()
    }
    next_plan_id += 1
    _event("restructuring_started", reason, {})
    return {"ok": true, "plan": restructuring_plan.duplicate(true), "state": state}

func sell_asset(finance: Node, asset_name: String, sale_value: int, book_value: int = 0) -> Dictionary:
    if finance == null or sale_value <= 0: return {"ok": false, "message": "Invalid asset sale."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT, ADMINISTRATION]:
        return {"ok": false, "message": "Asset sales are a distress action and require financial pressure."}
    var fixed := float(finance.fixed_assets)
    if fixed < float(book_value) and book_value > 0:
        return {"ok": false, "message": "Book value exceeds available fixed assets."}
    finance.fixed_assets = max(0.0, fixed - float(max(0, book_value)))
    finance.cash += sale_value
    finance._record("asset_sale", sale_value, asset_name)
    finance._record_cash_flow("investing", sale_value, "distress asset sale")
    var entry := {"asset": asset_name, "sale_value": sale_value, "book_value": book_value, "gain_loss": sale_value - book_value, "day": _game_day()}
    asset_sale_history.append(entry)
    if restructuring_plan.is_empty(): begin_restructuring("emergency asset sale")
    restructuring_plan["asset_sales"] = int(restructuring_plan.get("asset_sales", 0)) + sale_value
    _event("asset_sale", "Sold %s for $%d" % [asset_name, sale_value], entry)
    return {"ok": true, "cash": finance.cash, "entry": entry}

func secure_investment(finance: Node, amount: int, source: String = "distress investor") -> Dictionary:
    if finance == null or amount <= 0: return {"ok": false, "message": "Invalid investment."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Emergency investment is only available during distress."}
    var result: Dictionary = finance.record_equity(amount, source)
    if not bool(result.get("ok", false)): return result
    var entry := {"amount": amount, "source": source, "day": _game_day()}
    investment_history.append(entry)
    if restructuring_plan.is_empty(): begin_restructuring("new rescue investment")
    restructuring_plan["investment"] = int(restructuring_plan.get("investment", 0)) + amount
    _event("rescue_investment", "$%d rescue equity received" % amount, entry)
    return {"ok": true, "cash": finance.cash, "entry": entry}

func downsize(finance: Node, employees_reduced: int, daily_savings: int, severance: int = 0) -> Dictionary:
    if finance == null or employees_reduced <= 0 or daily_savings < 0 or severance < 0:
        return {"ok": false, "message": "Invalid downsizing terms."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Downsizing is only available during distress."}
    if finance.cash < severance:
        return {"ok": false, "message": "Insufficient cash for severance."}
    finance.cash -= severance
    finance.operating_expenses = max(0.0, finance.operating_expenses - float(daily_savings))
    var entry := {"employees_reduced": employees_reduced, "daily_savings": daily_savings, "severance": severance, "day": _game_day()}
    downsizing_history.append(entry)
    if restructuring_plan.is_empty(): begin_restructuring("emergency downsizing")
    restructuring_plan["downsizing"] = int(restructuring_plan.get("downsizing", 0)) + employees_reduced
    _event("downsizing", "Reduced workforce by %d" % employees_reduced, entry)
    return {"ok": true, "cash": finance.cash, "entry": entry}

func refinance(finance: Node, instrument_id: String, new_rate: float, new_term_periods: int) -> Dictionary:
    if finance == null: return {"ok": false, "message": "Finance system is required."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Refinancing is intended for financial distress."}
    var result: Dictionary = finance.refinance_loan(instrument_id, new_rate, new_term_periods)
    if not bool(result.get("ok", false)): return result
    var entry := {"instrument": instrument_id, "new_rate": new_rate, "new_term": new_term_periods, "payment": result.get("payment", 0), "day": _game_day()}
    refinancing_history.append(entry)
    if restructuring_plan.is_empty(): begin_restructuring("debt refinancing")
    restructuring_plan["refinancing"] = int(restructuring_plan.get("refinancing", 0)) + 1
    _event("refinancing", "Debt refinanced to %s" % str(new_rate), entry)
    return {"ok": true, "entry": entry}

func enter_administration(reason: String = "insolvency") -> Dictionary:
    if state != INSOLVENT:
        return {"ok": false, "message": "Administration requires insolvency."}
    _transition(ADMINISTRATION, reason)
    var entry := {"reason": reason, "day": _game_day()}
    administration_history.append(entry)
    return {"ok": true, "state": state, "entry": entry}

func liquidate(finance: Node, assets_to_liquidate: Array = []) -> Dictionary:
    if finance == null: return {"ok": false, "message": "Finance system is required."}
    if state != ADMINISTRATION: return {"ok": false, "message": "Liquidation requires administration."}
    var proceeds := 0
    for asset in assets_to_liquidate:
        var value := int(asset.get("liquidation_value", asset.get("value", 0))) if asset is Dictionary else 0
        if value > 0:
            proceeds += value
            asset_sale_history.append({"asset": asset.get("name", "asset"), "sale_value": value, "book_value": int(asset.get("book_value", 0)), "day": _game_day()})
    finance.cash += proceeds
    if proceeds > 0:
        finance._record("liquidation", proceeds, "administration liquidation")
        finance._record_cash_flow("investing", proceeds, "liquidation proceeds")
    _transition(LIQUIDATION, "administration completed; assets liquidated")
    var entry := {"proceeds": proceeds, "assets": assets_to_liquidate.duplicate(true), "day": _game_day()}
    liquidation_history.append(entry)
    return {"ok": true, "proceeds": proceeds, "state": state, "entry": entry}

func acquire_or_restructure(acquirer_id: String, target_id: String, acquisition_system: Node, price: int = 0) -> Dictionary:
    if acquisition_system == null: return {"ok": false, "message": "Acquisition system is required."}
    if state not in [INSOLVENT, ADMINISTRATION, LIQUIDATION]:
        return {"ok": false, "message": "Distressed acquisition is only available after insolvency."}
    var result: Dictionary = acquisition_system.acquire_company(acquirer_id, target_id, price, acquisition_system.TYPE_HOSTILE, {"assume_debt": true, "retain_employees": true, "assume_liabilities": true, "transfer_contracts": true, "transfer_reputation": true})
    if bool(result.get("ok", false)):
        _transition(ACQUIRED, "distressed company acquired")
        _event("distressed_acquisition", "Company acquired during distress", {"acquirer": acquirer_id, "target": target_id, "price": price})
    return result

func mark_recovery() -> Dictionary:
    if state not in [RESTRUCTURING, CASH_CRISIS, COVENANT_PRESSURE]:
        return {"ok": false, "message": "Recovery requires an active restructuring."}
    recovery_days = 5
    _transition(RECOVERY, "restructuring actions restored financial stability")
    return {"ok": true, "state": state}

func status() -> Dictionary:
    return {"state": state, "previous_state": previous_state, "distress_score": distress_score, "cash_runway": cash_runway, "covenant_breaches": covenant_breaches.duplicate(), "restructuring_plan": restructuring_plan.duplicate(true), "recovery_days": recovery_days, "event_count": events.size()}

func capture_state() -> Dictionary:
    return {"state": state, "previous_state": previous_state, "distress_score": distress_score, "cash_runway": cash_runway, "covenant_breaches": covenant_breaches.duplicate(), "restructuring_plan": restructuring_plan.duplicate(true), "asset_sale_history": asset_sale_history.duplicate(true), "investment_history": investment_history.duplicate(true), "downsizing_history": downsizing_history.duplicate(true), "refinancing_history": refinancing_history.duplicate(true), "administration_history": administration_history.duplicate(true), "liquidation_history": liquidation_history.duplicate(true), "events": events.duplicate(true), "recovery_days": recovery_days, "next_plan_id": next_plan_id}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    state = str(snapshot.get("state", state))
    previous_state = str(snapshot.get("previous_state", previous_state))
    distress_score = float(snapshot.get("distress_score", distress_score))
    cash_runway = float(snapshot.get("cash_runway", cash_runway))
    covenant_breaches = snapshot.get("covenant_breaches", covenant_breaches).duplicate()
    restructuring_plan = snapshot.get("restructuring_plan", {}).duplicate(true)
    asset_sale_history = snapshot.get("asset_sale_history", []).duplicate(true)
    investment_history = snapshot.get("investment_history", []).duplicate(true)
    downsizing_history = snapshot.get("downsizing_history", []).duplicate(true)
    refinancing_history = snapshot.get("refinancing_history", []).duplicate(true)
    administration_history = snapshot.get("administration_history", []).duplicate(true)
    liquidation_history = snapshot.get("liquidation_history", []).duplicate(true)
    events = snapshot.get("events", []).duplicate(true)
    recovery_days = int(snapshot.get("recovery_days", recovery_days))
    next_plan_id = int(snapshot.get("next_plan_id", next_plan_id))

func _transition(new_state: String, reason: String) -> void:
    if state == new_state: return
    previous_state = state
    state = new_state
    _event("state_transition", "%s -> %s: %s" % [previous_state, new_state, reason], {"from": previous_state, "to": new_state})

func _event(kind: String, message: String, data: Dictionary) -> void:
    events.append({"kind": kind, "message": message, "data": data.duplicate(true), "day": _game_day()})

func _game_day() -> int:
    var parent := get_parent()
    return int(parent.day) if parent != null and "day" in parent else 0
