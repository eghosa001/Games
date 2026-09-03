extends SceneTree

# Regression runner boundary:
# - This file is an INTEGRATION test suite.
# - It instantiates Main and exercises the composed command boundary.
# - Unit/system tests belong in their dedicated test files.
# - Player-facing first-session behavior belongs in test_new_game_flow.gd.
#
# Do not add direct system construction (Economy.new(), Expansion.new(), etc.)
# here. That would mix test layers again.

var passed := 0
var failed := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    await test_main_composition()
    await test_main_command_integration()
    print("\nRENEW INTEGRATION TEST RESULT: %d passed, %d failed" % [passed, failed])
    if failed > 0:
        for item in failures:
            print("FAILED: " + item)
        quit(1)
    quit(0)

func _new_game() -> Node:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "integration Main scene loads")
    if scene == null:
        return null
    var game = scene.instantiate()
    check(game != null, "integration Main scene instantiates")
    if game == null:
        return null
    root.add_child(game)
    await process_frame
    # Main.initialize() intentionally randomizes the live game. Re-seed only
    # after composition is ready so this deterministic integration fixture is
    # repeatable without changing runtime randomness.
    seed(123456)
    return game

func test_main_composition() -> void:
    var game = await _new_game()
    if game == null:
        return

    check(game.has_method("inspect_property"), "integration Main inspect command")
    check(game.has_method("advance_day"), "integration Main advance-day command")
    check(game.has_method("buy_expansion"), "integration Main expansion command")
    check(game.has_method("upgrade_transport"), "integration Main transport command")
    check(game.has_method("save_game"), "integration Main save command")
    check(game.has_method("load_game"), "integration Main load command")
    check(game.command_system != null, "integration command system attached")
    check(game.economy != null, "integration economy wired")
    check(game.expansion != null, "integration expansion wired")
    check(game.command_system.supply_system != null, "integration supply system wired")
    check(game.command_system.business_system != null, "integration business system wired")
    check(game.command_system.business_system.production != null, "integration production owned by business system")

    game.free()
    await process_frame

func test_main_command_integration() -> void:
    var game = await _new_game()
    if game == null:
        return

    # Controlled fixture setup is allowed at the integration layer. This is not
    # an end-to-end test; player-facing starting-economy behavior is covered by
    # test_new_game_flow.gd without injecting cash.
    game.cash = 500000
    game.reputation = 100

    game.inspect_property()
    check(game.inspected, "integration inspect property through Main")
    game.acquire_property()
    check(game.owned, "integration acquire property through Main")

    for _i in range(5):
        game.restore_property()
    check(game.stage == "Operational" and int(game.restoration) >= 100, "integration restoration through Main")

    game.choose_business_purpose(0)
    game.open_business()
    check(game.business_open, "integration open furniture business through Main")

    game.cycle_supplier()
    check(game.supplier_choice == 1, "integration cycle supplier through Main")
    game.buy_inputs()
    check(game.economy.resources.has("timber"), "integration canonical timber resource wired")
    check(game.economy.resources.has("iron"), "integration canonical iron resource wired")
    check(game.economy.resources.has("energy"), "integration canonical energy resource wired")

    game.produce_goods()
    check(game.finished_goods > 0, "integration production command reaches authoritative production")

    game.hire_employee()
    check(game.employees >= 4, "integration employee command")
    game.upgrade_business()
    check(game.capacity_level >= 2, "integration business upgrade command")
    game.marketing_campaign()
    check(game.marketing_level >= 1, "integration marketing command")

    var old_price = game.player_price
    game.change_price()
    check(game.player_price != old_price, "integration pricing command")

    game.sign_contract()
    check(game.contract_days > 0, "integration contract command")

    while game.finished_goods < 5:
        game.produce_goods()
    var old_day = game.day
    var old_profit = game.total_profit
    game.advance_day()
    check(game.day == old_day + 1, "integration advance-day command")
    check(game.total_profit != old_profit or game.last_profit != 0, "integration daily economy flow")

    game.select_expansion(0)
    check(game.selected_expansion == 0, "integration select expansion command")
    game.buy_expansion()
    check(bool(game.expansion.properties[0].get("owned", false)), "integration expansion acquisition command")
    game.upgrade_expansion()
    check(int(game.expansion.properties[0].get("level", 0)) >= 2, "integration expansion upgrade command")

    game.select_rival(0)
    check(game.selected_rival == 0, "integration select rival command")
    game.improve_alliance()
    game.make_alliance_offer()
    game.propose_supply_deal()
    game.propose_customer_partnership()
    check(game.message != "", "integration rival commands")

    game.take_loan()
    check(game.debt > 0, "integration loan command")
    var debt_before = game.debt
    game.repay_loan()
    check(game.debt < debt_before, "integration repayment command")

    game.upgrade_transport()
    check(game.transport_level >= 2, "integration transport upgrade command")
    check(game.transport_capacity >= 60, "integration transport capacity updated")

    game.cash = 123456
    game.save_game()
    game.cash = 1
    game.load_game()
    check(game.cash == 123456, "integration save/load command boundary")
    check(game.expansion.properties.size() == 3, "integration expansion state restored")

    game.free()
    await process_frame
