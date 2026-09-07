extends SceneTree

## V2.1: treasury bills. Idle cash locks into term deposits that mature with
## interest through the canonical finance ledger and daily settlement.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _finance() -> Node:
    var script = load("res://scripts/finance_system_fixed.gd")
    var finance = Node.new()
    finance.set_script(script)
    root.add_child(finance)
    return finance

func _fund(finance: Node, target_cash: int) -> void:
    var current := int(finance.get("cash"))
    if target_cash > current:
        finance.record_equity(target_cash - current, "test capitalization")
    elif target_cash < current:
        finance.spend(current - target_cash, "test capitalization drain")

func run() -> void:
    var finance = _finance()
    _fund(finance, 50000)
    var bad: Dictionary = finance.place_term_deposit(-100, 30, 0.05)
    check(not bool(bad.get("ok", false)), "Negative deposit rejected")
    var broke: Dictionary = finance.place_term_deposit(99999999, 30, 0.05)
    check(not bool(broke.get("ok", false)), "Unfunded deposit rejected")
    var placed: Dictionary = finance.place_term_deposit(10000, 30, 0.05)
    check(bool(placed.get("ok", false)), "Term deposit placed")
    check(int(finance.cash) == 40000, "Placement locks cash")
    check(int(finance.investments) == 10000, "Placement books investments")
    check(bool(finance.validate_invariants().get("ok", false)), "Books balance after placement")
    var early: Dictionary = finance.break_term_deposit(str(placed.get("id", "")))
    check(bool(early.get("ok", false)), "Early withdrawal returns principal")
    check(int(early.get("amount", 0)) == 10000, "Early withdrawal pays no interest")
    check(int(finance.cash) == 50000, "Broken deposit restores cash")
    check(bool(finance.validate_invariants().get("ok", false)), "Books balance after break")

    var placed2: Dictionary = finance.place_term_deposit(10000, 3, 0.10)
    check(bool(placed2.get("ok", false)), "Short bill placed")
    var id := str(placed2.get("id", ""))
    finance.settle_debt_day()
    check(int(finance.term_deposits[id].get("days_left", -1)) == 2, "Deposit term counts down")
    finance.settle_debt_day()
    finance.settle_debt_day()
    check(not finance.term_deposits.has(id), "Matured deposit clears")
    var expected_interest := int(round(10000.0 * 0.10 * 3.0 / 365.0))
    check(int(finance.cash) == 50000 + expected_interest, "Maturity pays principal plus interest")
    check(bool(finance.validate_invariants().get("ok", false)), "Books balance after maturity")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for invest command")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.cash = 100000
        var before := int(game.cash)
        game.invest_term()
        check(int(game.cash) == before - 5000, "Invest command locks a bill")
        check(game.message != "", "Invest command reports")
        game.free()
        await process_frame
    finance.free()
    await process_frame
    print("V21 INVESTMENT RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
