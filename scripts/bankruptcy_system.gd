extends Node

## RENEW Bankruptcy & Restructuring System.
## Models a playable corporate distress lifecycle rather than a single bankruptcy flag:
## stable -> cash crisis -> covenant pressure -> restructuring -> recovery
## or insolvency -> administration -> liquidation/acquisition.

const SYSTEM_VERSION := 2
const STABLE := "stable"
const CASH_CRISIS := "cash_crisis"
const COVENANT_PRESSURE := "covenant_pressure"
const RESTRUCTURING := "restructuring"
const RECOVERY := "recovery"
const INSOLVENT := "insolvent"
const ADMINISTRATION := "administration"
const LIQUIDATION := "liquidation"
const ACQUIRED := "acquired"

const CASH_CRISIS_SCORE := 35.0
const COVENANT_SCORE := 70.0
const RECOVERY_SCORE := 25.0
const DAYS_TO_COVENANT := 2
const DAYS_TO_AUTO_RESTRUCTURE := 2
const DAYS_TO_RECOVERY := 5
const DAYS_TO_STABLE := 5

var state: Variant = STABLE
var previous_state: Variant = STABLE
var distress_score: float = 0.0
var cash_runway: float = INF
var covenant_breaches: Array[String] = []
var restructuring_plan: Dictionary = {}
var asset_sale_history: Array = []
var investment_history: Array = []
var downsizing_history: Array = []
var refinancing_history: Array = []
var administration_history: Array = []
var liquidation_history: Array = []
var events: Array = []
var recovery_days: Variant = 0
var crisis_days: Variant = 0
var covenant_days: Variant = 0
var restructuring_days: Variant = 0
var next_plan_id: Variant = 1
var last_game_day: Variant = -1
var distress_panel: Panel
var distress_status_label: Label

func _ready() -> void:
    last_game_day = _game_day()
    _build_distress_ui()
    _refresh_distress_ui()

func _process(_delta: float) -> void:
    var day: Variant = _game_day()
    if day != last_game_day:
        last_game_day = day
        evaluate_runtime()
    _refresh_distress_ui()

## Evaluates financial health and advances the distress state machine.
func evaluate(finance: Node, daily_cash_burn: float = 0.0) -> Dictionary:
    if finance == null:
        return {"ok": false, "message": "Finance system is required."}
    if state in [LIQUIDATION, ACQUIRED]:
        return status()

    var bs: Dictionary = finance.balance_sheet()
    var solvency: Dictionary = finance.solvency_status()
    var cash: Variant = float(bs.get("cash", 0.0))
    var debt: Variant = float(bs.get("debt", 0.0))
    var liabilities: Variant = float(bs.get("liabilities", 0.0))
    var assets: Variant = float(bs.get("assets", 0.0))
    var equity: Variant = float(bs.get("equity", 0.0))
    var coverage: Variant = float(solvency.get("interest_coverage", INF))
    var leverage: Variant = float(solvency.get("leverage", 0.0))
    var service: Variant = max(0.0, float(finance.debt_service()))

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
    if assets > 0.0 and liabilities / assets > 0.90:
        covenant_breaches.append("high_liability_ratio")

    distress_score = 0.0
    if cash < max(5000.0, service * 3.0):
        distress_score += 25.0
    if cash_runway < 14.0:
        distress_score += 20.0
    if coverage < 1.0:
        distress_score += 25.0
    elif coverage < 2.0:
        distress_score += 10.0
    if leverage > 5.0:
        distress_score += 20.0
    elif leverage > 3.0:
        distress_score += 10.0
    if equity < 0.0:
        distress_score += 35.0
    if assets > 0.0 and liabilities > assets:
        distress_score += 20.0

    # Hard insolvency takes precedence over every recovery path.
    if equity < 0.0 or cash < 0.0:
        crisis_days = 0
        covenant_days = 0
        _transition(INSOLVENT, "balance sheet insolvency detected")
        return status()

    if state == RECOVERY:
        if distress_score >= CASH_CRISIS_SCORE:
            recovery_days = 0
            _transition(CASH_CRISIS, "financial recovery deteriorated")
            return status()
        recovery_days += 1
        if recovery_days >= DAYS_TO_STABLE and distress_score < RECOVERY_SCORE:
            _transition(STABLE, "recovery sustained and distress cleared")
            restructuring_plan["completed_day"] = _game_day()
        return status()

    if state == RESTRUCTURING:
        restructuring_days += 1
        if distress_score < RECOVERY_SCORE and _has_restructuring_actions():
            recovery_days += 1
            if recovery_days >= DAYS_TO_RECOVERY:
                _transition(RECOVERY, "turnaround actions produced sustained improvement")
        else:
            recovery_days = 0
            if distress_score >= COVENANT_SCORE and restructuring_days >= 3:
                _event("restructuring_warning", "Restructuring is failing; insolvency risk is increasing.", {"score": distress_score})
        return status()

    if distress_score >= COVENANT_SCORE or covenant_breaches.size() >= 2:
        covenant_days += 1
        crisis_days = 0
        if state == STABLE:
            _transition(CASH_CRISIS, "liquidity stress detected")
        if covenant_days >= DAYS_TO_AUTO_RESTRUCTURE and state == COVENANT_PRESSURE:
            _transition(RESTRUCTURING, "persistent covenant pressure triggered formal restructuring")
            _start_plan("automatic covenant restructuring")
        elif state == CASH_CRISIS:
            _transition(COVENANT_PRESSURE, "persistent covenant breaches require lender intervention")
        return status()

    covenant_days = 0
    if distress_score >= CASH_CRISIS_SCORE:
        crisis_days += 1
        recovery_days = 0
        if state == STABLE:
            _transition(CASH_CRISIS, "cash liquidity has entered crisis territory")
        elif state == RECOVERY:
            _transition(CASH_CRISIS, "recovery deteriorated")
        if crisis_days >= DAYS_TO_COVENANT:
            _transition(COVENANT_PRESSURE, "cash crisis persisted into covenant pressure")
        return status()

    crisis_days = 0
    recovery_days = 0
    if state == COVENANT_PRESSURE:
        _transition(STABLE, "covenant pressure cleared before restructuring")
    elif state == CASH_CRISIS:
        _transition(STABLE, "cash crisis cleared")
    return status()

## Evaluates the live game economy after every completed day.
## FinanceSystem remains the accounting ledger; legacy main values are mirrored so
## existing gameplay remains compatible while distress decisions use FinanceSystem.
func evaluate_runtime() -> Dictionary:
    var game: Variant = _game()
    var finance: Variant = _finance()
    if game == null or finance == null:
        return {"ok": false, "message": "Runtime finance dependencies are unavailable."}

    finance.cash = int(game.cash)
    finance.debt = int(game.debt)
    finance.loan_payment = int(game.loan_payment)

    var daily_burn: Variant = _estimate_daily_burn(game, finance)
    var result: Variant = evaluate(finance, daily_burn)
    if game != null:
        if state == INSOLVENT:
            game.message = "INSOLVENCY: enter administration, liquidate assets, or accept a distressed acquisition."
        elif state == ADMINISTRATION:
            game.message = "ADMINISTRATION: creditors control the turnaround. Liquidation or acquisition is available."
        elif state == COVENANT_PRESSURE:
            game.message = "COVENANT PRESSURE: restructure, refinance, sell assets, downsize, or raise rescue capital."
        elif state == CASH_CRISIS:
            game.message = "CASH CRISIS: liquidity is tightening. Protect cash before covenants fail."
        elif state == RESTRUCTURING:
            game.message = "RESTRUCTURING: execute asset sales, investment, downsizing and refinancing to recover."
        elif state == RECOVERY:
            game.message = "RECOVERY: keep positive cash flow for %d more healthy day(s)." % max(0, DAYS_TO_STABLE - recovery_days)
    return result

func begin_restructuring(reason: String = "covenant pressure") -> Dictionary:
    if state not in [COVENANT_PRESSURE, RESTRUCTURING]:
        return {"ok": false, "message": "Formal restructuring begins after covenant pressure."}
    if state != RESTRUCTURING:
        _transition(RESTRUCTURING, reason)
        _start_plan(reason)
    return {"ok": true, "plan": restructuring_plan.duplicate(true), "state": state}

func sell_asset(finance: Node, asset_name: String, sale_value: int, book_value: int = 0) -> Dictionary:
    if finance == null or sale_value <= 0:
        return {"ok": false, "message": "Invalid asset sale."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT, ADMINISTRATION]:
        return {"ok": false, "message": "Asset sales are a distress action."}
    if book_value > 0 and float(finance.fixed_assets) < float(book_value):
        return {"ok": false, "message": "Book value exceeds available fixed assets."}
    finance.fixed_assets = max(0.0, float(finance.fixed_assets) - float(max(0, book_value)))
    finance.cash += sale_value
    var entry: Variant = {"asset": asset_name, "sale_value": sale_value, "book_value": book_value, "gain_loss": sale_value - book_value, "day": _game_day()}
    asset_sale_history.append(entry)
    _ensure_plan("emergency asset sale")
    restructuring_plan["asset_sales"] = int(restructuring_plan.get("asset_sales", 0)) + sale_value
    restructuring_plan["actions"] = int(restructuring_plan.get("actions", 0)) + 1
    _event("asset_sale", "Sold %s for $%d" % [asset_name, sale_value], entry)
    _sync_game_cash(finance)
    return {"ok": true, "cash": finance.cash, "entry": entry, "message": "Asset sold for $%d." % sale_value}

func secure_investment(finance: Node, amount: int, source: String = "distress investor") -> Dictionary:
    if finance == null or amount <= 0:
        return {"ok": false, "message": "Invalid investment."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Emergency investment requires financial distress."}
    var result: Dictionary = finance.record_equity(amount, source)
    if not bool(result.get("ok", false)):
        return result
    var entry: Variant = {"amount": amount, "source": source, "day": _game_day()}
    investment_history.append(entry)
    _ensure_plan("new rescue investment")
    restructuring_plan["investment"] = int(restructuring_plan.get("investment", 0)) + amount
    restructuring_plan["actions"] = int(restructuring_plan.get("actions", 0)) + 1
    _event("rescue_investment", "$%d rescue equity received" % amount, entry)
    _sync_game_cash(finance)
    return {"ok": true, "cash": finance.cash, "entry": entry, "message": "Rescue investment of $%d received." % amount}

func downsize(finance: Node, employees_reduced: int, daily_savings: int, severance: int = 0) -> Dictionary:
    if finance == null or employees_reduced <= 0 or daily_savings < 0 or severance < 0:
        return {"ok": false, "message": "Invalid downsizing terms."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Downsizing requires financial distress."}
    var game: Variant = _game()
    if game == null or int(game.employees) <= employees_reduced:
        return {"ok": false, "message": "The workforce cannot be reduced below one employee."}
    if finance.cash < severance:
        return {"ok": false, "message": "Insufficient cash for severance."}
    finance.cash -= severance
    game.employees = max(1, int(game.employees) - employees_reduced)
    var entry: Variant = {"employees_reduced": employees_reduced, "daily_savings": daily_savings, "severance": severance, "day": _game_day()}
    downsizing_history.append(entry)
    _ensure_plan("emergency downsizing")
    restructuring_plan["downsizing"] = int(restructuring_plan.get("downsizing", 0)) + employees_reduced
    restructuring_plan["daily_savings"] = int(restructuring_plan.get("daily_savings", 0)) + daily_savings
    restructuring_plan["actions"] = int(restructuring_plan.get("actions", 0)) + 1
    _event("downsizing", "Reduced workforce by %d" % employees_reduced, entry)
    _sync_game_cash(finance)
    return {"ok": true, "cash": finance.cash, "entry": entry, "message": "Downsized by %d employee(s)." % employees_reduced}

func refinance(finance: Node, instrument_id: String, new_rate: float, new_term_periods: int) -> Dictionary:
    if finance == null:
        return {"ok": false, "message": "Finance system is required."}
    if state not in [CASH_CRISIS, COVENANT_PRESSURE, RESTRUCTURING, INSOLVENT]:
        return {"ok": false, "message": "Refinancing requires financial distress."}
    var result: Dictionary = finance.refinance_loan(instrument_id, new_rate, new_term_periods)
    if not bool(result.get("ok", false)):
        return result
    var game: Variant = _game()
    if game != null:
        game.loan_payment = int(result.get("payment", game.loan_payment))
    var entry: Variant = {"instrument": instrument_id, "new_rate": new_rate, "new_term": new_term_periods, "payment": result.get("payment", 0), "day": _game_day()}
    refinancing_history.append(entry)
    _ensure_plan("debt refinancing")
    restructuring_plan["refinancing"] = int(restructuring_plan.get("refinancing", 0)) + 1
    restructuring_plan["actions"] = int(restructuring_plan.get("actions", 0)) + 1
    _event("refinancing", "Debt refinanced", entry)
    return {"ok": true, "entry": entry, "message": "Debt refinanced: rate %.1f%%, payment $%d." % [new_rate * 100.0, int(result.get("payment", 0))]}

func enter_administration(reason: String = "insolvency") -> Dictionary:
    if state != INSOLVENT:
        return {"ok": false, "message": "Administration requires insolvency."}
    _transition(ADMINISTRATION, reason)
    var entry: Variant = {"reason": reason, "day": _game_day()}
    administration_history.append(entry)
    _event("administration", "Company entered administration", entry)
    _log_game("ADMINISTRATION: creditor protection and asset disposition are now active.")
    return {"ok": true, "state": state, "entry": entry, "message": "Company entered administration. Liquidation or acquisition is possible."}

func liquidate(finance: Node, assets_to_liquidate: Array = []) -> Dictionary:
    if finance == null:
        return {"ok": false, "message": "Finance system is required."}
    if state != ADMINISTRATION:
        return {"ok": false, "message": "Liquidation requires administration."}
    var proceeds: Variant = 0
    for asset in assets_to_liquidate:
        if asset is Dictionary:
            var value: Variant = int(asset.get("liquidation_value", asset.get("value", 0)))
            if value > 0:
                proceeds += value
                liquidation_history.append({"asset": asset.get("name", "asset"), "sale_value": value, "book_value": int(asset.get("book_value", 0)), "day": _game_day()})
    finance.cash += proceeds
    _sync_game_cash(finance)
    var entry: Variant = {"proceeds": proceeds, "assets": assets_to_liquidate.duplicate(true), "day": _game_day()}
    liquidation_history.append(entry)
    _transition(LIQUIDATION, "administration completed; assets liquidated")
    _event("liquidation", "Company liquidated", entry)
    _log_game("LIQUIDATION: $%d in asset proceeds recovered." % proceeds)
    return {"ok": true, "proceeds": proceeds, "state": state, "entry": entry, "message": "Liquidation completed. $%d recovered." % proceeds}

## Uses the AcquisitionSystem as the transaction authority for a distressed sale.
func acquire_or_restructure(acquirer_id: String, target_id: String, acquisition_system: Node, price: int = 0) -> Dictionary:
    if acquisition_system == null:
        return {"ok": false, "message": "Acquisition system is required."}
    if state not in [INSOLVENT, ADMINISTRATION]:
        return {"ok": false, "message": "Distressed acquisition is available after insolvency or administration."}
    var result: Dictionary = acquisition_system.acquire_company(acquirer_id, target_id, float(price), acquisition_system.TYPE_HOSTILE, true, true, true, true, 1.0)
    if bool(result.get("ok", false)):
        _transition(ACQUIRED, "distressed company acquired")
        _event("distressed_acquisition", "Company acquired during distress", {"acquirer": acquirer_id, "target": target_id, "price": price})
    return result

func mark_recovery() -> Dictionary:
    if state != RESTRUCTURING or not _has_restructuring_actions():
        return {"ok": false, "message": "Recovery requires an active restructuring with at least one turnaround action."}
    recovery_days = DAYS_TO_RECOVERY
    _transition(RECOVERY, "restructuring actions restored financial stability")
    return {"ok": true, "state": state, "message": "Company entered recovery. Maintain healthy cash flow."}

func runtime_restructure() -> Dictionary:
    return begin_restructuring("player initiated formal turnaround plan")

func runtime_sell_selected_asset() -> Dictionary:
    var game: Variant = _game()
    var finance: Variant = _finance()
    if game == null or finance == null:
        return {"ok": false, "message": "Runtime dependencies unavailable."}
    var selected: Variant = int(game.selected_expansion)
    if selected >= 0 and selected < game.expansion.properties.size():
        var asset: Dictionary = game.expansion.properties[selected]
        if bool(asset.get("owned", false)):
            var cost: Variant = int(asset.get("cost", 5000))
            var value: Variant = max(1000, int(round(float(cost) * 0.65)))
            asset["owned"] = false
            return sell_asset(finance, str(asset.get("name", "Expansion Asset")), value, cost)
    return {"ok": false, "message": "Select an owned expansion asset before selling."}

func runtime_rescue_investment() -> Dictionary:
    var finance: Variant = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    return secure_investment(finance, 10000, "Emergency rescue investor")

func runtime_downsize() -> Dictionary:
    var finance: Variant = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    return downsize(finance, 1, 180, 500)

func runtime_refinance() -> Dictionary:
    var finance: Variant = _finance()
    if finance == null:
        return {"ok": false, "message": "FinanceSystem unavailable."}
    for id in finance.financing:
        var instrument: Dictionary = finance.financing[id]
        var balance: Variant = float(instrument.get("balance", 0.0))
        var instrument_type: Variant = str(instrument.get("type", ""))
        if balance > 0.0 and instrument_type != "equity":
            return refinance(finance, str(id), max(0.04, float(instrument.get("annual_rate", 0.12)) - 0.025), int(instrument.get("remaining_periods", 20)) + 15)
    return {"ok": false, "message": "No FinanceSystem debt instrument is available to refinance."}

func runtime_administration() -> Dictionary:
    return enter_administration("player entered administration after insolvency")

func runtime_liquidation() -> Dictionary:
    var game: Variant = _game()
    var finance: Variant = _finance()
    if game == null or finance == null:
        return {"ok": false, "message": "Runtime dependencies unavailable."}
    var assets: Array = []
    for p in game.expansion.properties:
        if bool(p.get("owned", false)):
            assets.append({"name": p.get("name", "property"), "value": int(p.get("cost", 0)), "liquidation_value": int(round(float(p.get("cost", 0)) * 0.55)), "book_value": int(p.get("cost", 0))})
    for r in game.expansion.resource_sites:
        if bool(r.get("owned", false)):
            assets.append({"name": r.get("name", "resource site"), "value": int(r.get("cost", 0)), "liquidation_value": int(round(float(r.get("cost", 0)) * 0.55)), "book_value": int(r.get("cost", 0))})
    return liquidate(finance, assets)

func runtime_distressed_acquisition() -> Dictionary:
    var acquisition: Variant = get_node_or_null("../AcquisitionSystem")
    if acquisition == null:
        return {"ok": false, "message": "AcquisitionSystem unavailable."}
    for target_id in acquisition.targets:
        var target: Dictionary = acquisition.targets[target_id]
        if str(target.get("status", "independent")) not in ["acquired", "merged"]:
            var diligence: Variant = acquisition.due_diligence(str(target_id))
            var price: Variant = max(1, int(round(max(0.0, float(diligence.get("net_asset_value", 10000.0))) * 0.65)))
            return acquire_or_restructure("renew_co", str(target_id), acquisition, price)
    return {"ok": false, "message": "No registered acquisition target is available for a distressed sale."}

func status() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "state": state, "previous_state": previous_state, "distress_score": distress_score, "cash_runway": cash_runway, "covenant_breaches": covenant_breaches.duplicate(), "restructuring_plan": restructuring_plan.duplicate(true), "recovery_days": recovery_days, "crisis_days": crisis_days, "covenant_days": covenant_days, "restructuring_days": restructuring_days, "event_count": events.size()}

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "state": state, "previous_state": previous_state, "distress_score": distress_score, "cash_runway": cash_runway, "covenant_breaches": covenant_breaches.duplicate(), "restructuring_plan": restructuring_plan.duplicate(true), "asset_sale_history": asset_sale_history.duplicate(true), "investment_history": investment_history.duplicate(true), "downsizing_history": downsizing_history.duplicate(true), "refinancing_history": refinancing_history.duplicate(true), "administration_history": administration_history.duplicate(true), "liquidation_history": liquidation_history.duplicate(true), "events": events.duplicate(true), "recovery_days": recovery_days, "crisis_days": crisis_days, "covenant_days": covenant_days, "restructuring_days": restructuring_days, "next_plan_id": next_plan_id}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
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
    crisis_days = int(snapshot.get("crisis_days", crisis_days))
    covenant_days = int(snapshot.get("covenant_days", covenant_days))
    restructuring_days = int(snapshot.get("restructuring_days", restructuring_days))
    next_plan_id = int(snapshot.get("next_plan_id", next_plan_id))

func _start_plan(reason: String) -> void:
    restructuring_plan = {"id": "restruct_%d" % next_plan_id, "reason": reason, "asset_sales": 0, "investment": 0, "downsizing": 0, "daily_savings": 0, "refinancing": 0, "actions": 0, "created_day": _game_day()}
    next_plan_id += 1
    restructuring_days = 0
    recovery_days = 0
    _event("restructuring_started", reason, restructuring_plan)
    _log_game("RESTRUCTURING: recovery plan %s opened." % restructuring_plan["id"])

func _ensure_plan(reason: String) -> void:
    if restructuring_plan.is_empty():
        if state in [CASH_CRISIS, COVENANT_PRESSURE]:
            _transition(RESTRUCTURING, reason)
        _start_plan(reason)

func _has_restructuring_actions() -> bool:
    return not restructuring_plan.is_empty() and int(restructuring_plan.get("actions", 0)) > 0

func _estimate_daily_burn(game: Node, finance: Node) -> float:
    var profit: Variant = float(finance.last_profit)
    var wage_burn: Variant = float(max(0, int(game.employees))) * 180.0
    var overhead: Variant = 650.0 + float(max(0, int(game.capacity_level))) * 100.0
    var debt_burn: Variant = max(0.0, float(finance.debt_service()))
    return max(0.0, -profit) + wage_burn + overhead + debt_burn

func _build_distress_ui() -> void:
    var layer: Variant = CanvasLayer.new()
    layer.name = "BankruptcyControls"
    layer.layer = 80
    add_child(layer)
    distress_panel = Panel.new()
    distress_panel.name = "DistressPanel"
    distress_panel.position = Vector2(20, 430)
    distress_panel.size = Vector2(680, 325)
    layer.add_child(distress_panel)
    var box: Variant = VBoxContainer.new()
    box.position = Vector2(12, 10)
    box.size = Vector2(656, 305)
    distress_panel.add_child(box)
    distress_status_label = Label.new()
    distress_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    distress_status_label.custom_minimum_size = Vector2(650, 90)
    box.add_child(distress_status_label)
    var row1: Variant = HBoxContainer.new()
    box.add_child(row1)
    _distress_button(row1, "RESTRUCTURE", runtime_restructure)
    _distress_button(row1, "SELL ASSET", runtime_sell_selected_asset)
    _distress_button(row1, "RESCUE $10K", runtime_rescue_investment)
    var row2: Variant = HBoxContainer.new()
    box.add_child(row2)
    _distress_button(row2, "DOWNSIZE", runtime_downsize)
    _distress_button(row2, "REFINANCE", runtime_refinance)
    _distress_button(row2, "ADMINISTRATION", runtime_administration)
    _distress_button(row2, "LIQUIDATE", runtime_liquidation)
    var row3: Variant = HBoxContainer.new()
    box.add_child(row3)
    _distress_button(row3, "DISTRESSED ACQUISITION", runtime_distressed_acquisition)
    _distress_button(row3, "MARK RECOVERY", mark_recovery)

func _distress_button(row: HBoxContainer, text: String, callback: Callable) -> void:
    var button: Variant = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(150, 44)
    button.pressed.connect(_run_distress_action.bind(callback))
    row.add_child(button)

func _run_distress_action(callback: Callable) -> void:
    var result: Dictionary = callback.call()
    var game: Variant = _game()
    if game != null:
        game.message = str(result.get("message", "Distress action completed."))
        _log_game("BANKRUPTCY: " + game.message)
    _refresh_distress_ui()

func _refresh_distress_ui() -> void:
    if distress_panel == null:
        return
    distress_panel.visible = state != STABLE
    if distress_status_label == null:
        return
    var breach_text: Variant = "none" if covenant_breaches.is_empty() else ", ".join(covenant_breaches)
    var runway: Variant = "∞" if is_inf(cash_runway) else "%.1f days" % cash_runway
    var plan_id: Variant = str(restructuring_plan.get("id", "none"))
    var actions: Variant = int(restructuring_plan.get("actions", 0))
    distress_status_label.text = "FINANCIAL DISTRESS — %s\nScore %.0f | Runway %s | Breaches: %s\nPlan: %s | Actions: %d | Recovery days: %d\nCrisis days: %d | Covenant days: %d | Restructuring days: %d" % [state.to_upper(), distress_score, runway, breach_text, plan_id, actions, recovery_days, crisis_days, covenant_days, restructuring_days]

func _sync_game_cash(finance: Node) -> void:
    var game: Variant = _game()
    if game == null:
        return
    game.cash = int(finance.cash)
    game.debt = int(finance.debt)
    game.loan_payment = int(finance.loan_payment)

func _game() -> Node:
    return get_tree().root.get_node_or_null("Renew")

func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem") if get_node_or_null("/root/RenewFinanceSystem") != null else get_node_or_null("../FinanceSystem")

func _game_day() -> int:
    var game: Variant = _game()
    return 0 if game == null else int(game.day)

func _log_game(text: String) -> void:
    var game: Variant = _game()
    if game != null and game.has_method("_log"):
        game._log(text)

func _transition(new_state: String, reason: String) -> void:
    if state == new_state:
        return
    previous_state = state
    state = new_state
    _event("state_transition", "%s -> %s: %s" % [previous_state, new_state, reason], {"from": previous_state, "to": new_state, "reason": reason})

func _event(kind: String, message: String, data: Dictionary) -> void:
    events.append({"kind": kind, "message": message, "data": data.duplicate(true), "day": _game_day()})
    if events.size() > 1000:
        events.pop_front()
