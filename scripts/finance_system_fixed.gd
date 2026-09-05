extends "res://scripts/finance_system.gd"

## Corrective finance layer.
## Keeps the established ledger/accounting implementation while fixing the
## debt-service lifecycle: interest follows current principal, scheduled
## payments consume one period only when actually paid, and maturity clears
## the instrument instead of leaving an orphaned balance.

func settle_debt_day() -> Dictionary:
    var interest := 0
    var payment := 0
    var missed := false
    var scheduled_due := 0

    # Accrue interest from current outstanding principal. The original ledger
    # stored principal separately from accrued interest, so using the current
    # principal here prevents repayments from continuing to generate interest
    # on principal that has already been paid.
    for id in financing:
        var instrument: Dictionary = financing[id]
        var principal := max(0.0, float(instrument.get("principal", 0.0)))
        var remaining_periods := int(instrument.get("remaining_periods", instrument.get("term", 0)))
        if principal <= 0.0 or remaining_periods <= 0:
            instrument["payment"] = 0
            financing[id] = instrument
            continue

        var annual_rate := max(0.0, float(instrument.get("annual_rate", 0.0)))
        var accrued := max(0.0, float(instrument.get("accrued_interest", 0.0)))
        var instrument_interest := max(0, int(round(principal * annual_rate / 365.0)))
        accrued = float(round(accrued + instrument_interest))
        interest += instrument_interest

        instrument["principal"] = float(round(principal))
        instrument["accrued_interest"] = accrued
        instrument["balance"] = instrument["principal"] + accrued

        var instrument_type := str(instrument.get("type", INSTRUMENT_LOAN))
        var due := 0
        if remaining_periods == 1:
            # Final period: retire the entire remaining instrument balance.
            due = int(round(principal + accrued))
        elif instrument_type == INSTRUMENT_BOND:
            # Bonds are interest-only until maturity.
            due = int(round(accrued))
        else:
            # Re-amortize against the current principal and remaining term.
            var rate_per_period := annual_rate / 365.0
            if rate_per_period > 0.0:
                due = int(round(principal * rate_per_period / max(0.0001, 1.0 - pow(1.0 + rate_per_period, -remaining_periods))))
            else:
                due = int(ceil(principal / float(remaining_periods)))
            due = max(due, int(round(accrued)))
        instrument["payment"] = max(0, due)
        financing[id] = instrument
        scheduled_due += max(0, due)

    if interest > 0:
        interest_expense += interest
        retained_earnings -= interest
        _record("interest", interest, "daily financing interest")

    _recalculate_loan_payment()
    scheduled_due = 0
    for id in financing:
        var instrument: Dictionary = financing[id]
        var principal := max(0.0, float(instrument.get("principal", 0.0)))
        var remaining_periods := int(instrument.get("remaining_periods", instrument.get("term", 0)))
        if principal > 0.0 and remaining_periods > 0:
            scheduled_due += max(0, int(instrument.get("payment", 0)))

    if scheduled_due > 0 and debt > 0:
        payment = min(scheduled_due, debt + _total_accrued_interest())
        if cash >= payment:
            var remaining_cash_payment := payment
            var principal_paid_total := 0
            var interest_paid_total := 0

            # Pay each instrument's scheduled amount independently so a mature
            # instrument cannot be starved by another instrument's allocation.
            for id in financing:
                if remaining_cash_payment <= 0:
                    break
                var instrument: Dictionary = financing[id]
                var principal := max(0.0, float(instrument.get("principal", 0.0)))
                var accrued := max(0.0, float(instrument.get("accrued_interest", 0.0)))
                var remaining_periods := int(instrument.get("remaining_periods", instrument.get("term", 0)))
                var due := max(0, int(instrument.get("payment", 0)))
                if principal <= 0.0 or remaining_periods <= 0 or due <= 0:
                    continue

                var instrument_payment := min(remaining_cash_payment, due)
                var interest_paid := min(instrument_payment, int(round(accrued)))
                var principal_paid := min(instrument_payment - interest_paid, int(round(principal)))
                var actual_payment := interest_paid + principal_paid
                if actual_payment <= 0:
                    continue

                accrued = max(0.0, accrued - interest_paid)
                principal = max(0.0, principal - principal_paid)
                remaining_cash_payment -= actual_payment
                interest_paid_total += interest_paid
                principal_paid_total += principal_paid

                # A scheduled payment advances the term only when it actually
                # paid. A missed payment therefore remains in the same period.
                remaining_periods = max(0, remaining_periods - 1)
                instrument["principal"] = float(round(principal))
                instrument["accrued_interest"] = float(round(accrued))
                instrument["balance"] = instrument["principal"] + instrument["accrued_interest"]
                instrument["remaining_periods"] = remaining_periods
                if principal <= 0.0 and accrued <= 0.0:
                    instrument["payment"] = 0
                    instrument["remaining_periods"] = 0
                elif remaining_periods <= 0:
                    # A non-zero balance at exhausted maturity is still due;
                    # keep it visible rather than silently deleting debt.
                    instrument["payment"] = int(round(principal + accrued))
                financing[id] = instrument

            var actual_payment := interest_paid_total + principal_paid_total
            payment = actual_payment
            cash -= actual_payment
            debt = max(0, debt - principal_paid_total)
            _record("scheduled_payment", actual_payment, "scheduled debt payment")
            _record_cash_flow("financing", -actual_payment, "scheduled debt payment")
            _recalculate_loan_payment()
        else:
            missed = true

    if debt == 0 and _total_financing_balance() <= 0.01:
        loan_payment = 0
    _update_credit_score(missed)
    return {"interest": interest, "payment": payment, "missed": missed, "cash": cash, "debt": debt, "accrued_interest": _total_accrued_interest(), "credit_rating": credit_rating}
