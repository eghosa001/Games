extends Node

## RENEW unified finance ledger.
## Tracks operating performance, balance-sheet accounts, financing instruments,
## cash flow, solvency and credit quality. Gameplay systems should use this
## node rather than maintaining independent debt/cash ledgers.

const SYSTEM_VERSION := 2
const INSTRUMENT_LOAN := "loan"
const INSTRUMENT_SECURED_LOAN := "secured_loan"
const INSTRUMENT_BOND := "bond"
const INSTRUMENT_EQUITY := "equity"
const INSTRUMENT_INVESTMENT := "investment"

var cash: int = 25000
var debt: int = 0
var loan_payment: int = 0
var last_sales: int = 0
var last_profit: int = 0
var total_profit: int = 0
var history: Array = []

# Accrual/accounting state.
var revenue: float = 0.0
var operating_expenses: float = 0.0
var depreciation: float = 0.0
var interest_expense: float = 0.0
var taxes: float = 0.0
var accounts_receivable: float = 0.0
var inventory: float = 0.0
var fixed_assets: float = 0.0
var investments: float = 0.0
var accounts_payable: float = 0.0
var other_liabilities: float = 0.0
var retained_earnings: float = 0.0
var equity_contributed: float = 0.0
var financing: Dictionary = {}
var cash_flow_history: Array = []
var credit_rating: String = "BBB"
var credit_score: float = 70.0

func available_cash() -> int: return cash
func can_afford(amount: int) -> bool: return amount >= 0 and cash >= amount

func spend(amount: int, reason: String = "expense") -> Dictionary:
    if amount < 0 or cash < amount: return {"ok": false, "amount": 0, "reason": reason, "message": "Insufficient cash."}
    cash -= amount
    operating_expenses += amount
    _record("spend", amount, reason)
    _record_cash_flow("operating", -amount, reason)
    return {"ok": true, "amount": amount, "cash": cash}

func receive(amount: int, reason: String = "income") -> Dictionary:
    if amount < 0: return {"ok": false, "amount": 0, "reason": reason}
    cash += amount
    revenue += amount
    _record("receive", amount, reason)
    _record_cash_flow("operating", amount, reason)
    return {"ok": true, "amount": amount, "cash": cash}

func settle_sales(sales: int, wages: int, overhead: int, contract_income: int = 0) -> Dictionary:
    var period_revenue: Variant = float(max(0, sales) + max(0, contract_income))
    var costs: Variant = float(max(0, wages) + max(0, overhead))
    revenue += period_revenue
    operating_expenses += costs
    cash += int(round(period_revenue - costs))
    last_sales = int(period_revenue)
    last_profit = int(round(period_revenue - costs))
    total_profit += last_profit
    retained_earnings += last_profit
    _record("settlement", last_profit, "daily operating settlement")
    _record_cash_flow("operating", last_profit, "daily operating settlement")
    return {"sales": max(0, sales), "contract_income": max(0, contract_income), "costs": int(costs), "profit": last_profit, "cash": cash}

func take_loan(amount: int) -> Dictionary:
    return create_loan(amount, 0.12, 20, false, "unsecured loan")

func create_loan(amount: int, annual_rate: float = 0.12, term_periods: int = 20, secured: bool = false, collateral: String = "") -> Dictionary:
    if amount <= 0 or term_periods <= 0 or annual_rate < 0.0: return {"ok": false, "message": "Invalid loan terms."}
    var id: Variant = "loan_%d" % Time.get_unix_time_from_system()
    var instrument_type: Variant = INSTRUMENT_SECURED_LOAN if secured else INSTRUMENT_LOAN
    var principal: Variant = float(amount)
    var rate_per_period: Variant = annual_rate / 365.0
    var payment: Variant = int(round(principal * rate_per_period / max(0.0001, 1.0 - pow(1.0 + rate_per_period, -term_periods)))) if rate_per_period > 0 else int(ceil(principal / term_periods))
    financing[id] = {"id": id, "type": instrument_type, "principal": principal, "balance": principal, "annual_rate": annual_rate, "term": term_periods, "remaining_periods": term_periods, "payment": payment, "collateral": collateral}
    debt += amount
    loan_payment = payment
    cash += amount
    _record("loan", amount, "secured loan issued" if secured else "loan issued")
    _record_cash_flow("financing", amount, "debt issuance")
    return {"ok": true, "id": id, "amount": amount, "payment": payment, "cash": cash, "debt": debt}

func refinance_loan(instrument_id: String, new_rate: float, new_term_periods: int) -> Dictionary:
    if not financing.has(instrument_id): return {"ok": false, "message": "Financing instrument not found."}
    if new_rate < 0.0 or new_term_periods <= 0: return {"ok": false, "message": "Invalid refinancing terms."}
    var instrument: Dictionary = financing[instrument_id]
    var balance: Variant = float(instrument.get("balance", 0.0))
    instrument["annual_rate"] = new_rate
    instrument["term"] = new_term_periods
    instrument["remaining_periods"] = new_term_periods
    var rate: Variant = new_rate / 365.0
    instrument["payment"] = int(round(balance * rate / max(0.0001, 1.0 - pow(1.0 + rate, -new_term_periods)))) if rate > 0 else int(ceil(balance / new_term_periods))
    financing[instrument_id] = instrument
    _record("refinance", int(balance), "loan refinanced")
    return {"ok": true, "id": instrument_id, "balance": balance, "payment": instrument["payment"], "rate": new_rate}

func issue_bond(principal: int, annual_rate: float = 0.08, term_periods: int = 30) -> Dictionary:
    if principal <= 0 or annual_rate < 0.0 or term_periods <= 0: return {"ok": false, "message": "Invalid bond terms."}
    var id: Variant = "bond_%d" % Time.get_unix_time_from_system()
    financing[id] = {"id": id, "type": INSTRUMENT_BOND, "principal": float(principal), "balance": float(principal), "annual_rate": annual_rate, "term": term_periods, "remaining_periods": term_periods, "payment": int(round(principal * annual_rate / 365.0))}
    debt += principal
    cash += principal
    _record("bond", principal, "bond issued")
    _record_cash_flow("financing", principal, "bond issuance")
    return {"ok": true, "id": id, "principal": principal, "debt": debt, "cash": cash}

func invest(amount: int, asset_name: String = "investment") -> Dictionary:
    if amount <= 0 or cash < amount: return {"ok": false, "message": "Insufficient cash for investment."}
    cash -= amount
    investments += amount
    _record("investment", amount, asset_name)
    _record_cash_flow("investing", -amount, asset_name)
    return {"ok": true, "amount": amount, "cash": cash, "investments": investments}

func record_equity(amount: int, source: String = "equity issuance") -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Invalid equity amount."}
    cash += amount
    equity_contributed += amount
    _record("equity", amount, source)
    _record_cash_flow("financing", amount, source)
    return {"ok": true, "amount": amount, "equity": equity_contributed, "cash": cash}

func buyback_equity(amount: int) -> Dictionary:
    if amount <= 0 or cash < amount: return {"ok": false, "message": "Insufficient cash for buyback."}
    cash -= amount
    equity_contributed = max(0.0, equity_contributed - amount)
    retained_earnings = max(0.0, retained_earnings - amount)
    _record("buyback", amount, "equity buyback")
    _record_cash_flow("financing", -amount, "equity buyback")
    return {"ok": true, "amount": amount, "cash": cash}

func repay(amount: int) -> Dictionary:
    if debt <= 0: return {"ok": false, "message": "No outstanding debt."}
    var payment: Variant = min(debt, max(1, amount))
    if cash < payment: return {"ok": false, "message": "Insufficient cash for repayment."}
    cash -= payment
    debt -= payment
    _reduce_financing_balance(payment)
    if debt == 0: loan_payment = 0
    _record("repayment", payment, "loan repayment")
    _record_cash_flow("financing", -payment, "loan repayment")
    return {"ok": true, "amount": payment, "cash": cash, "debt": debt}

func settle_debt_day() -> Dictionary:
    var interest: Variant = 0
    var payment: Variant = 0
    var missed: Variant = false
    if debt > 0:
        for id in financing:
            var instrument: Dictionary = financing[id]
            var balance: Variant = float(instrument.get("balance", 0.0))
            if balance <= 0.0: continue
            interest += max(0, int(round(balance * float(instrument.get("annual_rate", 0.12)) / 365.0)))
            instrument["balance"] = balance + float(interest)
            financing[id] = instrument
        if interest == 0: interest = max(1, int(round(debt * 0.012)))
        cash -= interest
        interest_expense += interest
        _record("interest", interest, "daily financing interest")
        _record_cash_flow("financing", -interest, "daily financing interest")
    if loan_payment > 0 and debt > 0:
        payment = min(loan_payment, debt)
        if cash >= payment:
            cash -= payment
            debt -= payment
            _reduce_financing_balance(payment)
            _record("scheduled_payment", payment, "scheduled debt payment")
            _record_cash_flow("financing", -payment, "scheduled debt payment")
        else: missed = true
    if debt == 0: loan_payment = 0
    _update_credit_score(missed)
    return {"interest": interest, "payment": payment, "missed": missed, "cash": cash, "debt": debt, "credit_rating": credit_rating}

func balance_sheet() -> Dictionary:
    var assets: Variant = float(cash) + accounts_receivable + inventory + fixed_assets + investments
    var liabilities: Variant = float(debt) + accounts_payable + other_liabilities
    var equity: Variant = assets - liabilities
    return {"assets": assets, "cash": cash, "accounts_receivable": accounts_receivable, "inventory": inventory, "fixed_assets": fixed_assets, "investments": investments, "liabilities": liabilities, "debt": debt, "accounts_payable": accounts_payable, "other_liabilities": other_liabilities, "equity": equity}

func income_statement() -> Dictionary:
    var operating_profit: Variant = revenue - operating_expenses - depreciation
    var net_profit: Variant = operating_profit - interest_expense - taxes
    return {"revenue": revenue, "operating_expenses": operating_expenses, "depreciation": depreciation, "operating_profit": operating_profit, "interest": interest_expense, "taxes": taxes, "net_profit": net_profit}

func cash_flow_statement() -> Dictionary:
    var operating: Variant = revenue - operating_expenses - interest_expense - taxes
    var investing: Variant = -investments
    var financing_flow: Variant = 0.0
    for entry in history:
        if str(entry.get("kind", "")).to_lower() in ["loan", "bond", "equity", "buyback", "repayment", "scheduled_payment", "refinance"]:
            financing_flow += float(entry.get("amount", 0)) * (-1.0 if str(entry.get("kind")) in ["buyback", "repayment", "scheduled_payment"] else 1.0)
    return {"operating": operating, "investing": investing, "financing": financing_flow, "net_change": operating + investing + financing_flow, "cash": cash}

func debt_service() -> float:
    var total: Variant = 0.0
    for id in financing: total += float(financing[id].get("payment", 0))
    return total

func valuation(earnings_multiple: float = 6.0) -> float:
    var net_profit: Variant = float(income_statement()["net_profit"])
    return max(0.0, net_profit * max(1.0, earnings_multiple)) + max(0.0, float(balance_sheet()["assets"]) - float(balance_sheet()["liabilities"]))

func leverage() -> float:
    var equity: Variant = float(balance_sheet()["equity"])
    if equity <= 0.0: return INF if debt > 0 else 0.0
    return float(debt) / equity

func interest_coverage() -> float:
    var interest: Variant = float(interest_expense)
    if interest <= 0.0: return INF
    return float(income_statement()["operating_profit"]) / interest

func solvency_status() -> Dictionary:
    var bs: Variant = balance_sheet()
    var leverage_ratio: Variant = leverage()
    var coverage: Variant = interest_coverage()
    var insolvent: Variant = float(bs["equity"]) < 0.0 or (debt > 0 and cash < 0)
    var stressed: Variant = insolvent or leverage_ratio > 5.0 or coverage < 1.0
    return {"solvent": not insolvent, "stressed": stressed, "leverage": leverage_ratio, "interest_coverage": coverage, "equity": bs["equity"], "credit_rating": credit_rating}

func get_credit_rating() -> String:
    return credit_rating

func get_credit_score() -> float:
    return credit_score

func update_credit_rating() -> String:
    var leverage_ratio: Variant = leverage()
    var coverage: Variant = interest_coverage()
    var score: Variant = 70.0
    score -= min(35.0, max(0.0, leverage_ratio - 1.0) * 8.0)
    if coverage < 1.0: score -= 25.0
    elif coverage < 2.0: score -= 12.0
    elif coverage >= 5.0: score += 10.0
    if float(balance_sheet()["equity"]) < 0.0: score -= 30.0
    credit_score = clamp(score, 0.0, 100.0)
    if credit_score >= 90: credit_rating = "AAA"
    elif credit_score >= 80: credit_rating = "AA"
    elif credit_score >= 70: credit_rating = "A"
    elif credit_score >= 60: credit_rating = "BBB"
    elif credit_score >= 50: credit_rating = "BB"
    elif credit_score >= 40: credit_rating = "B"
    elif credit_score >= 30: credit_rating = "CCC"
    else: credit_rating = "D"
    return credit_rating

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "cash": cash, "debt": debt, "loan_payment": loan_payment, "last_sales": last_sales, "last_profit": last_profit, "total_profit": total_profit, "history": history.duplicate(true), "revenue": revenue, "operating_expenses": operating_expenses, "depreciation": depreciation, "interest_expense": interest_expense, "taxes": taxes, "accounts_receivable": accounts_receivable, "inventory": inventory, "fixed_assets": fixed_assets, "investments": investments, "accounts_payable": accounts_payable, "other_liabilities": other_liabilities, "retained_earnings": retained_earnings, "equity_contributed": equity_contributed, "financing": financing.duplicate(true), "cash_flow_history": cash_flow_history.duplicate(true), "credit_rating": credit_rating, "credit_score": credit_score}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    cash = int(snapshot.get("cash", cash)); debt = int(snapshot.get("debt", debt)); loan_payment = int(snapshot.get("loan_payment", loan_payment))
    last_sales = int(snapshot.get("last_sales", 0)); last_profit = int(snapshot.get("last_profit", 0)); total_profit = int(snapshot.get("total_profit", 0))
    history.clear()
    for entry in snapshot.get("history", []):
        if entry is Dictionary: history.append(entry.duplicate(true))
    revenue = float(snapshot.get("revenue", 0.0)); operating_expenses = float(snapshot.get("operating_expenses", 0.0)); depreciation = float(snapshot.get("depreciation", 0.0)); interest_expense = float(snapshot.get("interest_expense", 0.0)); taxes = float(snapshot.get("taxes", 0.0))
    accounts_receivable = float(snapshot.get("accounts_receivable", 0.0)); inventory = float(snapshot.get("inventory", 0.0)); fixed_assets = float(snapshot.get("fixed_assets", 0.0)); investments = float(snapshot.get("investments", 0.0)); accounts_payable = float(snapshot.get("accounts_payable", 0.0)); other_liabilities = float(snapshot.get("other_liabilities", 0.0)); retained_earnings = float(snapshot.get("retained_earnings", 0.0)); equity_contributed = float(snapshot.get("equity_contributed", 0.0))
    financing = snapshot.get("financing", {}).duplicate(true)
    cash_flow_history.clear()
    for entry in snapshot.get("cash_flow_history", []):
        if entry is Dictionary: cash_flow_history.append(entry.duplicate(true))
    credit_rating = str(snapshot.get("credit_rating", "BBB")); credit_score = float(snapshot.get("credit_score", 70.0))

func _reduce_financing_balance(amount: int) -> void:
    var remaining: Variant = float(amount)
    for id in financing:
        if remaining <= 0: break
        var instrument: Dictionary = financing[id]
        var reduction: Variant = min(remaining, float(instrument.get("balance", 0.0)))
        instrument["balance"] = max(0.0, float(instrument.get("balance", 0.0)) - reduction)
        financing[id] = instrument
        remaining -= reduction

func _update_credit_score(missed: bool) -> void:
    if missed: credit_score = max(0.0, credit_score - 8.0)
    else: credit_score = min(100.0, credit_score + 0.5)
    update_credit_rating()

func _record_cash_flow(category: String, amount: float, reason: String) -> void:
    cash_flow_history.append({"category": category, "amount": amount, "reason": reason, "timestamp": Time.get_unix_time_from_system()})
    if cash_flow_history.size() > 500: cash_flow_history.pop_front()

func _record(kind: String, amount: int, reason: String) -> void:
    history.append({"kind": kind, "amount": amount, "reason": reason, "timestamp": Time.get_unix_time_from_system()})
    if history.size() > 500: history.pop_front()
