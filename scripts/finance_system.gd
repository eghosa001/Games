extends Node

const SYSTEM_VERSION := 1

# Finance owns cash, debt and daily financial settlement. Gameplay code should
# request transactions here instead of editing money directly.
var cash: int = 25000
var debt: int = 0
var loan_payment: int = 0
var last_sales: int = 0
var last_profit: int = 0
var total_profit: int = 0
var history: Array[Dictionary] = []

func available_cash() -> int:
    return cash

func can_afford(amount: int) -> bool:
    return amount >= 0 and cash >= amount

func spend(amount: int, reason: String = "expense") -> Dictionary:
    if amount < 0 or cash < amount: return {"ok": false, "amount": 0, "reason": reason, "message": "Insufficient cash."}
    cash -= amount; _record("spend", amount, reason)
    return {"ok": true, "amount": amount, "cash": cash}

func receive(amount: int, reason: String = "income") -> Dictionary:
    if amount < 0: return {"ok": false, "amount": 0, "reason": reason}
    cash += amount; _record("receive", amount, reason)
    return {"ok": true, "amount": amount, "cash": cash}

func settle_sales(sales: int, wages: int, overhead: int, contract_income: int = 0) -> Dictionary:
    var revenue = max(0, sales) + max(0, contract_income)
    var costs = max(0, wages) + max(0, overhead)
    var profit = revenue - costs
    cash += profit; last_sales = revenue; last_profit = profit; total_profit += profit
    _record("settlement", profit, "daily operating settlement")
    return {"sales": max(0, sales), "contract_income": max(0, contract_income), "costs": costs, "profit": profit, "cash": cash}

func take_loan(amount: int) -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Invalid loan amount."}
    if debt > 0: return {"ok": false, "message": "An outstanding loan already exists."}
    debt = amount; loan_payment = int(ceil(float(amount) / 20.0)); cash += amount
    _record("loan", amount, "loan issued")
    return {"ok": true, "amount": amount, "payment": loan_payment, "cash": cash, "debt": debt}

func repay(amount: int) -> Dictionary:
    if debt <= 0: return {"ok": false, "message": "No outstanding debt."}
    var payment = min(debt, max(1, amount))
    if cash < payment: return {"ok": false, "message": "Insufficient cash for repayment."}
    cash -= payment; debt -= payment
    if debt == 0: loan_payment = 0
    _record("repayment", payment, "loan repayment")
    return {"ok": true, "amount": payment, "cash": cash, "debt": debt}

func settle_debt_day() -> Dictionary:
    var interest := 0; var payment := 0; var missed := false
    if debt > 0:
        interest = max(100, int(round(debt * 0.012))); cash -= interest
        _record("interest", interest, "daily loan interest")
    if loan_payment > 0 and debt > 0:
        payment = min(loan_payment, debt)
        if cash >= payment:
            cash -= payment; debt -= payment; _record("scheduled_payment", payment, "scheduled loan payment")
        else: missed = true
    if debt == 0: loan_payment = 0
    return {"interest": interest, "payment": payment, "missed": missed, "cash": cash, "debt": debt}

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "cash": cash, "debt": debt, "loan_payment": loan_payment, "last_sales": last_sales, "last_profit": last_profit, "total_profit": total_profit, "history": history.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    cash = int(snapshot.get("cash", cash)); debt = int(snapshot.get("debt", debt)); loan_payment = int(snapshot.get("loan_payment", loan_payment))
    last_sales = int(snapshot.get("last_sales", 0)); last_profit = int(snapshot.get("last_profit", 0)); total_profit = int(snapshot.get("total_profit", 0))
    history = snapshot.get("history", []).duplicate(true)

func _record(kind: String, amount: int, reason: String) -> void:
    history.append({"kind": kind, "amount": amount, "reason": reason, "timestamp": Time.get_unix_time_from_system()})
    if history.size() > 500: history.pop_front()
