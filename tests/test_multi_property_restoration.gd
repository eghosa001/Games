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

func run() -> void:
    var packed = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    game.name = "Renew"
    root.add_child(game)
    await process_frame

    game.cash = 500000
    var property_system = game.command_system.property_system
    check(property_system != null, "property system exists")
    check(property_system.list_properties().size() == 9, "nine core restoration properties are available")

    var first: Dictionary = property_system.list_properties()[0]
    var second: Dictionary = property_system.list_properties()[1]

    property_system.select_property(str(first["id"]))
    game.inspect_property()
    game.acquire_property()
    for _i in range(4):
        game.restore_property()
    check(bool(property_system.get_property(str(first["id"])).get("owned", false)), "first property remains owned")
    check(property_system.is_operational(property_system.get_property(str(first["id"]))), "first property reaches operational restoration")

    property_system.select_property(str(second["id"]))
    check(not game.owned, "legacy selected-property ownership follows second property")
    game.inspect_property()
    game.acquire_property()
    for _i in range(4):
        game.restore_property()
    check(bool(property_system.get_property(str(second["id"])).get("owned", false)), "second property can be owned without selling first")
    check(property_system.is_operational(property_system.get_property(str(second["id"]))), "second property reaches operational restoration")
    check(property_system.owned_property_count() == 2, "portfolio counts two owned properties")
    check(property_system.restored_property_count() == 2, "portfolio counts two restored properties")

    property_system.select_property(str(first["id"]))
    check(game.owned, "legacy ownership sync returns true on first owned property")
    check(game.stage == "Operational", "legacy stage sync returns operational on restored property")

    var status: Dictionary = property_system.restoration_portfolio_status()
    check(int(status.get("total", 0)) == 9, "portfolio status exposes total restoration opportunities")
    check(int(status.get("restored", 0)) == 2, "portfolio status exposes restored count")

    print("MULTI-PROPERTY RESTORATION RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
