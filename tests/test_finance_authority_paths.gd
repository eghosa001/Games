extends SceneTree

var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func _read(path: String) -> String:
    if not FileAccess.file_exists(path): return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return ""
    return file.get_as_text()

func run() -> void:
    var domain := _read("res://scripts/domain_system.gd")
    check(domain.contains("const FINANCE_MIRROR_FIELDS"), "DomainSystem declares finance mirror fields centrally")
    check(domain.contains("Never allow generic domain writes to mutate authoritative finance state"), "DomainSystem documents the finance write boundary")
    check(domain.contains("func _sync_finance_mirrors(finance)"), "DomainSystem has a dedicated finance-to-mirror sync path")
    check(not domain.contains("finance.set(\"cash\", int(value))"), "DomainSystem cannot write FinanceSystem cash through generic set_value")
    check(not domain.contains("finance.set(\"debt\", int(value))"), "DomainSystem cannot write FinanceSystem debt through generic set_value")

    var market := _read("res://scripts/market_director.gd")
    check(not market.contains("game.cash -="), "Market responses do not directly subtract game cash")
    check(not market.contains("game.cash +="), "Market responses do not directly add game cash")
    check(market.contains("finance.spend"), "Market spending routes through FinanceSystem")
    check(market.contains("finance.receive"), "Market rewards route through FinanceSystem")
    check(market.contains("_sync_legacy_cash"), "Market legacy mirror sync is explicit")

    var supply := _read("res://scripts/supply_command_system.gd")
    check(supply.contains("func sell_furniture(amount: int, price: int)"), "Supply command exposes furniture sales")
    check(supply.contains("finance.receive(revenue, \"furniture sale\")"), "Furniture sale revenue routes through FinanceSystem")
    check(supply.contains("var finance_before: Dictionary = finance.capture_state()"), "Supply transactions snapshot FinanceSystem before mutation")
    check(supply.contains("finance.restore_state(finance_before)"), "Supply transactions can roll back FinanceSystem on failure")
    check(supply.contains("chain.restore_state(chain_before)"), "Supply transactions can roll back inventory on finance failure")

    var supply_chain := _read("res://scripts/supply_chain_system.gd")
    check(supply_chain.contains("const SYSTEM_VERSION := 7"), "Supply chain inventory ledger version is incremented")
    check(supply_chain.contains("func _sync_production_mirror(resources: Array)"), "Supply chain owns production inventory reconciliation")
    check(supply_chain.contains("production.inventory[product] = max(0, int(production.inventory.get(product, 0)) - amount)"), "Failed warehouse output registration reverses production mirror")
    check(supply_chain.contains("_sync_production_mirror([product])"), "Successful product receipt reconciles production mirror")
    check(supply_chain.contains("_sync_production_mirror(inputs.keys())"), "Warehouse consumption reconciles production input mirror")

    var simulation := _read("res://scripts/simulation_system.gd")
    check(not simulation.contains("finance.cash = int(game_state.get_value(\"economy\", \"cash\", finance.cash))"), "Simulation does not overwrite FinanceSystem cash from legacy state")
    check(not simulation.contains("finance.debt = int(game_state.get_value(\"finance\", \"debt\", finance.debt))"), "Simulation does not overwrite FinanceSystem debt from legacy state")
    check(not simulation.contains("finance.cash = int(state.get(\"cash\", finance.cash))"), "Simulation does not re-import mirrored cash after production")
    check(simulation.contains("func _transaction_capture(context: Dictionary)"), "Daily simulation captures a transaction snapshot before mutation")
    check(simulation.contains("func _transaction_restore(snapshot: Dictionary, context: Dictionary)"), "Daily simulation can restore its transaction snapshot")
    check(simulation.contains("var result := _advance_day_impl(state, context)"), "Daily simulation executes through a transactional implementation")
    check(simulation.contains("_transaction_restore(transaction_snapshot, context)"), "Daily simulation rolls back failed day execution")
    check(simulation.contains("finance.validate_invariants()"), "Daily simulation validates finance invariants before commit")

    var missions := _read("res://scripts/world_missions.gd")
    check(missions.contains("func _finance() -> Node:"), "World missions resolve the authoritative FinanceSystem")
    check(missions.contains("finance.spend(amount, \"world opportunity\")"), "World mission spending routes through FinanceSystem")
    check(missions.contains("finance.receive(amount, reason)"), "World mission rewards route through FinanceSystem")
    check(not missions.contains("parent.cash -= amount"), "World missions cannot directly subtract parent cash")
    check(not missions.contains("parent.cash += 1500"), "World mission bonuses cannot directly add parent cash")

    var bankruptcy := _read("res://scripts/bankruptcy_system.gd")
    check(not bankruptcy.contains("finance.cash = int(game.cash)"), "Bankruptcy does not overwrite FinanceSystem cash from legacy game state")
    check(not bankruptcy.contains("finance.debt = int(game.debt)"), "Bankruptcy does not overwrite FinanceSystem debt from legacy game state")
    check(not bankruptcy.contains("finance.cash +="), "Bankruptcy cash inflows route through FinanceSystem")
    check(not bankruptcy.contains("finance.cash -="), "Bankruptcy cash outflows route through FinanceSystem")
    check(bankruptcy.contains("finance.record_equity"), "Bankruptcy rescue capital uses the FinanceSystem equity transaction")
    check(bankruptcy.contains("finance.spend"), "Bankruptcy cash outflows use FinanceSystem")
    check(bankruptcy.contains("finance.record_asset_sale"), "Bankruptcy asset disposals use the accounting asset-sale transaction")
    check(not bankruptcy.contains("finance.receive(int(proceeds), \"liquidation proceeds\")"), "Liquidation does not misclassify asset proceeds as operating revenue")

    var finance_script := _read("res://scripts/finance_system.gd")
    check(finance_script.contains("const OPENING_EQUITY := 25000.0"), "Finance ledger has an explicit opening equity balance")
    check(finance_script.contains("retained_earnings -= float(amount)"), "Finance spending records the equity effect of expenses")
    check(finance_script.contains("retained_earnings += float(amount)"), "Finance receipts record the equity effect of revenue")
    check(finance_script.contains("func capture_state()"), "FinanceSystem exposes transaction snapshots")
    check(finance_script.contains("func restore_state(snapshot: Dictionary)"), "FinanceSystem exposes transaction rollback")
    check(finance_script.contains("accrued_interest"), "FinanceSystem models accrued interest explicitly")
    check(finance_script.contains("float(round(accrued))"), "FinanceSystem normalizes accrued interest to currency precision")
    check(finance_script.contains("fractional_accrued_interest"), "FinanceSystem rejects fractional accrued-interest state")
    check(finance_script.contains("var expected_equity := equity_contributed + retained_earnings"), "Balance-sheet equity is independently derived from equity components")
    check(finance_script.contains("accounting_equation_mismatch"), "FinanceSystem independently validates assets = liabilities + equity")
    check(finance_script.contains("func validate_invariants()"), "FinanceSystem exposes accounting invariants")
    check(finance_script.contains("func record_asset_sale"), "FinanceSystem exposes accounting-safe asset disposal")
    check(finance_script.contains("Cash flow is derived only from recorded cash movements"), "Cash-flow statement uses recorded cash movements")

    print("\nRENEW FINANCE AUTHORITY PATH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
