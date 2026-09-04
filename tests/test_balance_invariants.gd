extends SceneTree

# Fast invariant pass for economy values that should never become corrupt.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for balance invariants")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    check(game.economy.resources is Dictionary, "Resources are represented by a dictionary")
    for key in ["timber", "iron", "energy", "food", "electronics"]:
        check(game.economy.resources.has(key), "Required resource exists: " + key)
        if game.economy.resources.has(key):
            check(int(game.economy.resources[key]["stock"]) >= 0, "Resource stock is nonnegative: " + key)
            check(int(game.economy.resources[key]["price"]) > 0, "Resource price is positive: " + key)

    check(int(game.reputation) >= 0, "Starting reputation is nonnegative")
    check(int(game.cash) >= 0, "Starting cash is nonnegative")
    check(game.expansion.properties is Array, "Property expansion state is valid")
    check(game.expansion.resource_sites is Array, "Resource-site expansion state is valid")
    check(game.rivals.rivals is Array, "Rival state is valid")

    print("BALANCE INVARIANT RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    quit(1 if failed > 0 else 0)
