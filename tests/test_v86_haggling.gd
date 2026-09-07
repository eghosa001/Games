extends SceneTree

## V8.6: contract haggling. Standing converts into price: high reputation
## wins discounts, low reputation pays a premium for the insult.
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

func _setup(state: Variant, rep: int) -> void:
    state.set_value("businesses", "business_open", true)
    state.set_value("businesses", "industry_id", "furniture")
    state.set_value("contracts", "contract_days", 0)
    state.set_value("player", "reputation", rep)
    state.set_value("player", "day", 5)

func _haggled_price(contracts: Node) -> int:
    var active: Dictionary = contracts.active_contract()
    return int(active.get("price", 0))

func run() -> void:
    var Command = load("res://scripts/contract_command_system.gd")
    check(Command != null, "Contract command system loads")
    if Command == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var contracts = root.get_node_or_null("RenewContractSystem")
    check(contracts != null, "Contract system available")
    if contracts == null:
        quit(1)
        return
    var command: Node = Command.new()
    root.add_child(command)
    await process_frame

    _setup(state, 5)
    command.haggle_contract()
    check(contracts.active_contract().is_empty(), "Haggling needs standing")
    _setup(state, 40)
    var offer: Dictionary = contracts.get_future_contract_offer(40)
    var ask := int(offer.get("price", 0))
    check(ask > 0, "Supplier quotes a price")
    command.haggle_contract()
    var settled := _haggled_price(contracts)
    check(settled > 0 and settled < ask, "Standing wins a discount")
    var msg := str(state.get_value("company", "message", ""))
    check(msg.find("Haggled") >= 0, "Haggle reports the deal")
    command.haggle_contract()
    check(str(state.get_value("company", "message", "")).find("active contract") >= 0, "One contract at a time")

    if state.has_method("clear"):
        state.clear()
    _setup(state, 12)
    var ask2 := int(contracts.get_future_contract_offer(12).get("price", 0))
    command.haggle_contract()
    var insulted := _haggled_price(contracts)
    check(insulted > ask2, "Weak haggling pays a premium")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for haggle wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("haggle_contract"), "Main exposes haggle_contract")
        game.free()
        await process_frame
    command.queue_free()
    await process_frame
    print("V86 HAGGLING RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
