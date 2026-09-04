extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        _finish()
        return

    var scene: Node = packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame

    var hud := scene.get_node_or_null("UI/MainHUD")
    var manager := get_root().get_node_or_null("RenewUIScreenManager")
    check("MainHUD exists", hud != null)
    check("screen manager exists", manager != null)
    if hud == null or manager == null:
        _finish()
        return

    var expected_screens: Array[String] = [
        "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel",
        "MarketPanel", "EmployeePanel", "CollectionPanel", "LiveOpsPanel",
        "HistoryPanel", "NewsPanel", "RenewDiplomacyUI", "CustomerSegmentsUI"
    ]
    for screen_name in expected_screens:
        check("screen node resolves: %s" % screen_name, _find_screen(scene, screen_name) != null)

    # Screen routing is the contract: exactly one managed screen is rendered
    # after every explicit open.
    for screen_name in ["CustomerSegmentsUI", "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel", "NewsPanel", "RenewDiplomacyUI"]:
        manager.show_screen(screen_name)
        await process_frame
        check("active screen is %s" % screen_name, manager.get_active_screen_name() == screen_name)
        check("only one managed screen visible after %s" % screen_name, _visible_screen_count(manager) == 1)

    manager.hide_all_screens()
    await process_frame
    check("hide_all_screens clears every managed screen", _visible_screen_count(manager) == 0)

    # The world renderer owns the region controller under World; this path was
    # previously wrong and silently removed regional artwork from the renderer.
    var world_view := scene.get_node_or_null("World/WorldView")
    var region_controller := scene.get_node_or_null("World/RegionController")
    check("world renderer exists", world_view != null)
    check("world renderer resolves world-owned RegionController", world_view != null and region_controller != null and world_view.get("game") == scene)

    # Validate the highest-risk UI action boundaries that previously bypassed
    # canonical state or used an invalid parent path.
    var hq := scene.get_node_or_null("UI/HeadquartersPanel")
    check("HQ UI resolves game root", hq != null and hq.get("main") == scene)
    var employee := scene.get_node_or_null("UI/EmployeePanel")
    check("employee UI resolves", employee != null)
    if employee != null:
        check("employee UI exposes action handler", employee.has_method("_action"))

    # Save validation must reject incomplete domain payloads instead of writing
    # a file that can never be restored successfully.
    var save_script: Script = load("res://scripts/save_system.gd")
    check("SaveSystem loads", save_script != null)
    if save_script != null:
        var incomplete := {"schema_version": 8, "domains": {"player": {}}}
        check("SaveSystem rejects incomplete domain payload", not save_script.validate_save(incomplete))

    _finish()

func _find_screen(scene: Node, screen_name: String) -> Node:
    var ui := scene.get_node_or_null("UI")
    if ui != null:
        var child := ui.get_node_or_null(screen_name)
        if child != null:
            return child
    return get_root().get_node_or_null("Renew/" + screen_name)

func _visible_screen_count(manager: Node) -> int:
    var count := 0
    for node in manager._screen_nodes():
        if manager._is_node_visible(node):
            count += 1
    return count

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- UI ARCHITECTURE SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures:
            print("FAILED: %s" % failure)
        quit(1)
    print("UI ARCHITECTURE TEST: PASS")
    quit(0)
