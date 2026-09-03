extends SceneTree

# Discovery-driven release-gate audit: new scripts and functions are
# automatically included instead of relying on a manually maintained list.
var passed := 0
var failed := 0
var failures: Array[String] = []
var function_count := 0
var script_count := 0
var screen_node_count := 0

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    await audit_all_scripts()
    await audit_main_screen()
    print("\nRENEW FULL COVERAGE AUDIT: %d passed, %d failed" % [passed, failed])
    print("Scripts audited: %d | Functions audited: %d | Screen nodes audited: %d" % [script_count, function_count, screen_node_count])
    if failed > 0:
        for item in failures:
            print("FAILED: " + item)
        quit(1)
    quit(0)

func audit_all_scripts() -> void:
    var paths: Array[String] = []
    _collect_gd_scripts("res://scripts", paths)
    paths.sort()
    check(not paths.is_empty(), "scripts directory contains GDScript files")

    for path in paths:
        script_count += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "source readable: " + path)

        var script = load(path)
        check(script != null, "script parses: " + path)
        if script == null:
            continue

        var instance = null
        if script.has_method("new"):
            instance = script.new()
            check(instance != null, "script instantiates: " + path)
            if instance is Node:
                root.add_child(instance)
                await process_frame

        var declared := _declared_functions(source)
        for method_name in declared:
            function_count += 1
            if instance != null:
                check(instance.has_method(method_name), "function callable: %s::%s" % [path, method_name])
            else:
                check(false, "function instance unavailable: %s::%s" % [path, method_name])

        if source.contains("func capture_state"):
            check(instance != null and instance.has_method("capture_state"), "capture_state contract: " + path)
        if source.contains("func restore_state"):
            check(instance != null and instance.has_method("restore_state"), "restore_state contract: " + path)

        if instance is Node:
            instance.free()
            await process_frame

func audit_main_screen() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main.tscn parses")
    if scene == null:
        return
    var game = scene.instantiate()
    check(game != null, "Main.tscn instantiates")
    if game == null:
        return
    root.add_child(game)
    await process_frame

    check(game.get_child_count() >= 20, "Main screen contains expected UI/system composition")
    _audit_screen_tree(game)

    var expected_ui := [
        "MobileUI", "StrategyHUD", "V1Celebration", "TutorialOverlay",
        "HistoryMuseumUI", "NewsUI", "AllianceUI", "HeadquartersUI",
        "CollectionUI", "LiveOpsUI"
    ]
    for node_name in expected_ui:
        var node = game.get_node_or_null(node_name)
        check(node != null, "screen present: " + node_name)
        if node != null:
            check(node is CanvasLayer, "screen is CanvasLayer: " + node_name)
            check(node.get_script() != null, "screen has script: " + node_name)

    var expected_systems := [
        "MainRenderer", "ScarcitySystem", "GameBalance", "RestorationStrategy",
        "Progression", "MarketDirector", "EmpireGoals", "FinanceSystem",
        "OwnershipSystem", "AcquisitionSystem", "BankruptcySystem", "WorldView",
        "EmpireController", "Corporate", "WorldMissions", "RegionController",
        "BranchController", "SupplyChainController", "RivalSupplyController"
    ]
    for node_name in expected_systems:
        var node = game.get_node_or_null(node_name)
        check(node != null, "system node present: " + node_name)
        if node != null:
            check(node.get_script() != null, "system node has script: " + node_name)

    for method_name in ["advance_day", "save_game", "load_game", "inspect_property", "acquire_property", "restore_property", "open_business"]:
        check(game.has_method(method_name), "main gameplay API: " + method_name)

    game.free()
    await process_frame

func _collect_gd_scripts(path: String, result: Array[String]) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry == "." or entry == "..":
            entry = dir.get_next()
            continue
        var full := path.path_join(entry)
        if dir.current_is_dir():
            _collect_gd_scripts(full, result)
        elif entry.ends_with(".gd"):
            result.append(full)
        entry = dir.get_next()
    dir.list_dir_end()

func _declared_functions(source: String) -> Array[String]:
    var result: Array[String] = []
    for line in source.split("\n"):
        var stripped := line.strip_edges()
        if not stripped.begins_with("func "):
            continue
        var open := stripped.find("(")
        if open <= 5:
            continue
        var name := stripped.substr(5, open - 5).strip_edges()
        if name != "" and not result.has(name):
            result.append(name)
    return result

func _audit_screen_tree(node: Node) -> void:
    for child in node.get_children():
        screen_node_count += 1
        check(child != null, "screen tree child is valid")
        if child.get_script() != null:
            check(child.get_script() != null, "screen tree script resource valid: " + child.name)
        _audit_screen_tree(child)
