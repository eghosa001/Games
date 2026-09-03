extends SceneTree

# Discovery-driven release gate updated for the Phase 37 Main -> World/Systems/UI tree.
var passed := 0
var failed := 0
var failures: Array[String] = []
var function_count := 0
var script_count := 0

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition: passed += 1
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    await audit_all_scripts()
    await audit_main_screen()
    print("RENEW FULL COVERAGE AUDIT: %d passed, %d failed" % [passed, failed])
    print("Scripts audited: %d | Functions audited: %d" % [script_count, function_count])
    for failure in failures: print("FAILED: " + failure)
    quit(1 if failed > 0 else 0)

func audit_all_scripts() -> void:
    var paths: Array[String] = []
    _collect_gd_scripts("res://scripts", paths)
    check(not paths.is_empty(), "scripts directory contains GDScript files")
    for path in paths:
        script_count += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "source readable: " + path)
        var script = load(path)
        check(script != null, "script parses: " + path)
        for method_name in _declared_functions(source):
            function_count += 1
            if script != null and script.has_method("new"):
                var instance = script.new()
                check(instance != null and instance.has_method(method_name), "function callable: %s::%s" % [path, method_name])
                if instance is Node: instance.free()

func audit_main_screen() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main.tscn parses")
    if scene == null: return
    var game = scene.instantiate()
    check(game != null, "Main.tscn instantiates")
    if game == null: return
    root.add_child(game)
    await process_frame
    var world_nodes := ["MainRenderer","PropertyVisual","WorldView","EmpireController","Corporate","WorldMissions","RegionController","BranchController","SupplyChainController","RivalSupplyController"]
    var system_nodes := ["ScarcitySystem","GameBalance","RestorationStrategy","Progression","MarketDirector","EmpireGoals","FinanceSystem","OwnershipSystem","AcquisitionSystem","BankruptcySystem"]
    var ui_nodes := ["MainHUD","StrategyHUD","TutorialOverlay","V1Celebration","TechnologyPanel","HistoryPanel","NewsPanel","AlliancePanel","HeadquartersPanel","CollectionPanel","LiveOpsPanel","MarketPanel","ContractPanel","EmployeePanel"]
    for node_name in world_nodes: check(game.get_node_or_null("World/" + node_name) != null, "World node: " + node_name)
    for node_name in system_nodes: check(game.get_node_or_null("Systems/" + node_name) != null, "System node: " + node_name)
    for node_name in ui_nodes: check(game.get_node_or_null("UI/" + node_name) != null, "UI node: " + node_name)
    check(game.has_method("advance_day"), "Main gameplay API: advance_day")
    check(game.has_method("save_game"), "Main gameplay API: save_game")
    check(game.has_method("load_game"), "Main gameplay API: load_game")
    game.free()

func _collect_gd_scripts(path: String, result: Array[String]) -> void:
    var dir := DirAccess.open(path)
    if dir == null: return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry == "." or entry == "..":
            entry = dir.get_next(); continue
        var full := path.path_join(entry)
        if dir.current_is_dir(): _collect_gd_scripts(full, result)
        elif entry.ends_with(".gd"): result.append(full)
        entry = dir.get_next()
    dir.list_dir_end()

func _declared_functions(source: String) -> Array[String]:
    var result: Array[String] = []
    for line in source.split("\n"):
        var stripped := line.strip_edges()
        if stripped.begins_with("func "):
            var open := stripped.find("(")
            if open > 5:
                var name := stripped.substr(5, open - 5).strip_edges()
                if not result.has(name): result.append(name)
    return result
