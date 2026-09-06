extends SceneTree

var failures: Array[String] = []
var checks := 0
const Resolver := preload("res://scripts/runtime_dependency_resolver.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        _finish()
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame

    check("scene-local OwnershipSystem resolves through canonical path", Resolver.resolve("MissingOwnershipAutoload", "Systems/OwnershipSystem") == scene.get_node_or_null("Systems/OwnershipSystem"))
    check("scene-local InfrastructureSystem resolves through canonical path", Resolver.resolve("MissingInfrastructureAutoload", "Systems/InfrastructureSystem") == scene.get_node_or_null("Systems/InfrastructureSystem"))
    check("missing dependency returns null instead of creating a duplicate", Resolver.resolve("MissingDependency", "Missing/System") == null)

    var game_state := root.get_node_or_null("RenewGameState")
    check("GameState autoload resolves", game_state != null)
    if game_state != null:
        check("GameState is the canonical autoload instance", Resolver.resolve("RenewGameState", "GameState") == game_state)

    _finish()

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- RUNTIME DEPENDENCY SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures:
            print("FAILED: %s" % failure)
        quit(1)
    print("RUNTIME DEPENDENCY TEST: PASS")
    quit(0)
