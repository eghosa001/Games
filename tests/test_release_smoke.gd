extends SceneTree

# Lightweight release gate: catches missing scene/controller wiring before a
# mobile build is handed to a tester. This intentionally avoids mutating game
# state so it can run safely in CI.
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
    check(FileAccess.file_exists("res://project.godot"), "Project configuration exists")
    check(FileAccess.file_exists("res://scenes/Main.tscn"), "Main scene exists")
    check(FileAccess.file_exists("res://README.md"), "README exists")
    check(FileAccess.file_exists("res://Docs/V1_IMPLEMENTATION.md"), "V1 implementation document exists")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame

        for node_name in [
            "GameBalance",
            "RestorationStrategy",
            "Progression",
            "MarketDirector",
            "EmpireGoals",
            "WorldView",
            "EmpireController",
            "Corporate",
            "WorldMissions",
            "RegionController",
            "BranchController",
            "SupplyChainController",
            "RivalSupplyController",
            "GameStateBridge",
            "MobileUI",
            "StrategyHUD",
            "V1Celebration",
            "TutorialOverlay"
        ]:
            check(game.get_node_or_null(node_name) != null, "Main scene node: " + node_name)

        var mobile = game.get_node_or_null("MobileUI")
        if mobile != null:
            check(mobile.has_method("_layout_responsive"), "Mobile responsive layout API")

        var bridge = game.get_node_or_null("GameStateBridge")
        if bridge != null:
            check(bridge.has_method("_state"), "Save-state bridge API")

        game.free()
        await process_frame

    print("RELEASE SMOKE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
