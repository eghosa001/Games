extends "res://scripts/finance_system_core.gd"

## Canonical RENEW finance system.
## Extends the ledger/accounting core with corrected debt-service lifecycle:
## interest follows current principal, scheduled payments consume a period only
## when paid, and maturity remains explicit until the instrument is settled.

func settle_debt_day() -> Dictionary:
    var interest := 0
    var payment := 0
    var missed := false

    if debt > 0:
        for id in financing:
            var instrument: Dictionary = financing[id]
            var principal := float(instrument.get("principal", instrument.get("balance", 0.0)))
            var accrued := float(instrument.get("accrued_interest", max(0.0, float(instrument.get("balance", 0.0)) - principal)))
            if principal <= 0.0:
                continue
            var annual_rate := float(instrument.get("annual_rate", 0.0))
            if annual_rate <= 0.0:
                continue
            var instrument_interest := max(0, int(round(principal * annual_rate / 365.0)))
            accrued = float(round(accrued + instrument_interest))
            instrument["principal"] = float(round(principal))
            instrument["accrued_interest"] = accrued
            instrument["balance"] = instrument["principal"] + accrued
            financing[id] = instrument
            interest += instrument_interest

        if interest > 0:
            interest_expense += interest
            retained_earnings -= interest
            _record("interest", interest, "daily financing interest")

    # Respect the instruments' currently configured scheduled payments. This is
    # important for accrual-only periods where callers intentionally set payment
    # to zero; settlement must not manufacture a new payment and move cash.
    _recalculate_loan_payment()
    if loan_payment > 0 and debt > 0:
        payment = min(loan_payment, debt + _total_accrued_interest())
        if cash >= payment:
            var allocation := _allocate_repayment(payment)
            cash -= payment
            debt -= int(allocation["principal_paid"])
            _recalculate_loan_payment()
            _record("scheduled_payment", payment, "scheduled debt payment")
            _record_cash_flow("financing", -payment, "scheduled debt payment")
        else:
            missed = true

    if debt == 0 and _total_financing_balance() <= 0.01:
        loan_payment = 0
    _update_credit_score(missed)
    var matured_investments: Array = settle_term_deposits()
    return {"interest": interest, "payment": payment, "missed": missed, "cash": cash, "debt": debt, "accrued_interest": _total_accrued_interest(), "credit_rating": credit_rating, "matured_investments": matured_investments}
