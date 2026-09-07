extends SceneTree

## V4.2: event effects bite safely. Active crises publish world modifiers
## that scale real procurement quotes; expiry clears them.
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

func run() -> void:
    var World = load("res://scripts/world_event_system.gd")
    var Economy = load("res://scripts/economy.gd")
    check(World != null and Economy != null, "World and economy load")
    if World == null or Economy == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var world: Node = World.new()
    root.add_child(world)
    await process_frame
    var economy = Economy.new()
    await process_frame

    check(abs(float(economy.world_cost_multiplier("energy")) - 1.0) < 0.001, "Calm markets multiply by one")
    var calm_energy: Dictionary = economy.quote("energy", 10)
    var calm_timber: Dictionary = economy.quote("timber", 10)
    check(bool(calm_energy.get("ok", false)), "Energy quotes in calm markets")
    check(world.trigger("energy_crisis", {}, 17).get("ok", false), "Energy crisis triggers")
    check(abs(float(state.get_world_modifier("energy_price", 0.0)) - 1.35) < 0.001, "Crisis publishes energy modifier")
    check(abs(float(economy.world_cost_multiplier("energy")) - 1.35 * 1.12) < 0.001, "Energy stacks price and factory effects")
    check(abs(float(economy.world_cost_multiplier("timber")) - 1.12) < 0.001, "Timber feels factory costs only")
    var shock_energy: Dictionary = economy.quote("energy", 10)
    var ratio := float(shock_energy.get("cost", 0)) / float(maxi(1, int(calm_energy.get("cost", 0))))
    check(ratio > 1.4 and ratio < 1.65, "Crisis raises real energy quotes")
    var shock_timber: Dictionary = economy.quote("timber", 10)
    var timber_ratio := float(shock_timber.get("cost", 0)) / float(maxi(1, int(calm_timber.get("cost", 0))))
    check(timber_ratio > 1.05 and timber_ratio < 1.2, "Crisis raises timber quotes modestly")
    check(world.trigger("supply_disruption", {}, 19).get("ok", false), "Supply crisis stacks")
    check(abs(float(economy.world_cost_multiplier("energy")) - 1.35 * 1.12 * 1.18 * 1.30) < 0.02, "Stacked crises multiply")
    world.process_day(21)
    check(abs(float(economy.world_cost_multiplier("energy")) - 1.18 * 1.30 * 1.50 * 1.20) < 0.02, "Expiry chains into follow-up effects")
    var ids: Array = []
    for e in world.active():
        ids.append(str((e as Dictionary).get("id", "")))
    check(not ids.has("energy_crisis"), "Spent crisis leaves the board")

    world.active_events.clear()
    world._sync_modifiers()
    var Chain = load("res://scripts/supply_chain_system.gd")
    var chain: Node = Chain.new()
    chain.set_economy(economy)
    root.add_child(chain)
    await process_frame
    var limit_calm := float(chain._effective_warehouse_limit())
    var freight_calm := int(chain._freight_cost("energy", 10.0, 1))
    check(world.trigger("energy_investment_boom", {}, 50).get("ok", false), "Investment boom triggers")
    var boom_id := ""
    for e in world.active():
        if str((e as Dictionary).get("id", "")) == "energy_investment_boom":
            boom_id = str((e as Dictionary).get("instance_id", ""))
    check(world.choose(boom_id, "build").get("ok", false), "Boom investment chosen")
    check(float(chain._effective_warehouse_limit()) > limit_calm, "Chosen boom expands warehouse room")
    check(world.trigger("supply_disruption", {}, 50).get("ok", false), "Supply shock triggers")
    check(int(chain._freight_cost("energy", 10.0, 1)) > freight_calm, "Shocks raise freight")
    chain.queue_free()
    await process_frame

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with modifier pricing")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    world.queue_free()
    await process_frame
    print("V42 EVENT EFFECTS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
