extends SceneTree

# Whole-repository architecture and parser integrity gate.
# This remains read-only: it parses every GDScript under scripts/ and tests/,
# loads every scene/theme/shader resource, validates load-bearing res:// references,
# and verifies the complete Main world/system/UI tree.
var passed := 0
var failed := 0
var failures: Array[String] = []
var function_count := 0
var script_count := 0
var resource_count := 0
var reference_count := 0

const LEGACY_IMPORTS := [
    "res://scripts/corporate.gd",
    "res://scripts/corporate_legacy_system.gd",
    "res://scripts/production.gd"
]

const LEGACY_IMPORT_EXCEPTIONS := {
    "res://scripts/production.gd": ["res://scripts/business_system.gd"]
}

const PARSEABLE_RESOURCE_EXTENSIONS := [".gd", ".tscn", ".tres", ".gdshader"]
const REFERENCE_SOURCE_EXTENSIONS := [".gd", ".tscn", ".tres", ".godot", ".cfg"]
const SKIP_DIRECTORIES := [".git", ".godot", "artifacts", "test_artifacts"]

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
    audit_all_scripts()
    audit_parseable_resources()
    audit_resource_references()
    await audit_main_screen()
    print("RENEW ARCHITECTURE INTEGRITY: %d passed, %d failed" % [passed, failed])
    print("Scripts checked: %d | Functions checked: %d | Resources loaded: %d | load-bearing references checked: %d" % [script_count, function_count, resource_count, reference_count])
    for failure in failures:
        print("FAILED: " + failure)
    quit(1 if failed > 0 else 0)

func audit_all_scripts() -> void:
    var paths: Array[String] = []
    _collect_matching_files("res://scripts", [".gd"], paths)
    _collect_matching_files("res://tests", [".gd"], paths)
    paths.sort()
    check(not paths.is_empty(), "repository contains GDScript files")
    for path in paths:
        script_count += 1
        var source := FileAccess.get_file_as_string(path)
        check(not source.is_empty(), "source readable: " + path)
        if path.begins_with("res://scripts/"):
            _audit_legacy_imports(path, source)
        var script := ResourceLoader.load(path) as Script
        check(script != null, "script parses: " + path)
        for method_name in _declared_functions(source):
            function_count += 1
            if script != null and script.can_instantiate():
                var instance = script.new()
                check(instance != null and instance.has_method(method_name), "function structurally present: %s::%s" % [path, method_name])
                if instance is Node:
                    instance.free()

func audit_parseable_resources() -> void:
    var paths: Array[String] = []
    _collect_matching_files("res://", PARSEABLE_RESOURCE_EXTENSIONS, paths)
    paths.sort()
    check(not paths.is_empty(), "parseable Godot resources discovered")
    for path in paths:
        resource_count += 1
        var resource := ResourceLoader.load(path)
        check(resource != null, "resource loads: " + path)

func audit_resource_references() -> void:
    var sources: Array[String] = []
    _collect_matching_files("res://", REFERENCE_SOURCE_EXTENSIONS, sources)
    sources.sort()
    for source_path in sources:
        var text := FileAccess.get_file_as_string(source_path)
        if text.is_empty():
            continue
        for ref_path in _load_bearing_res_paths(source_path, text):
            reference_count += 1
            check(FileAccess.file_exists(ref_path), "load-bearing resource exists: %s -> %s" % [source_path, ref_path])

func _load_bearing_res_paths(source_path: String, text: String) -> Array[String]:
    if source_path.ends_with(".tscn") or source_path.ends_with(".tres") or source_path.ends_with(".godot") or source_path.ends_with(".cfg"):
        return _quoted_res_paths(text)
    var result: Array[String] = []
    for line in text.split("\n"):
        var stripped := line.strip_edges()
        if stripped.begins_with("#"):
            continue
        var load_bearing := stripped.contains("preload(") or stripped.contains("load(") or stripped.contains("ResourceLoader.exists(")
        if not load_bearing:
            continue
        for ref_path in _quoted_res_paths(stripped):
            if not result.has(ref_path):
                result.append(ref_path)
    return result

func _audit_legacy_imports(path: String, source: String) -> void:
    if path in LEGACY_IMPORTS:
        return
    for legacy_path in LEGACY_IMPORTS:
        if not source.contains(legacy_path):
            continue
        var exceptions: Array = LEGACY_IMPORT_EXCEPTIONS.get(legacy_path, [])
        check(path in exceptions, "legacy gameplay import prohibited: %s -> %s" % [path, legacy_path])

func audit_main_screen() -> void:
    var scene := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
    check(scene != null, "Main.tscn parses")
    if scene == null:
        return
    var game := scene.instantiate()
    check(game != null, "Main.tscn instantiates")
    if game == null:
        return
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    var world_nodes := [
        "PremiumWorldBackdrop", "PremiumIndustrialScene", "PremiumRestorationScene",
        "RichWorldScenery", "PropertyVisual", "WorldView", "PropertyMap",
        "EmpireController", "Corporate", "WorldMissions", "RegionController",
        "BranchController", "SupplyChainController", "RivalSupplyController"
    ]
    var system_nodes := [
        "ScarcitySystem", "GameBalance", "RestorationStrategy", "Progression",
        "MarketDirector", "EmpireGoals", "FinanceSystem", "OwnershipSystem",
        "AcquisitionSystem", "BankruptcySystem"
    ]
    var ui_nodes := [
        "MainHUD", "StrategyHUD", "TutorialOverlay", "V1Celebration",
        "TechnologyPanel", "HistoryPanel", "NewsPanel", "AlliancePanel",
        "HeadquartersPanel", "CollectionPanel", "LiveOpsPanel", "CustomerSegmentsUI",
        "RenewDiplomacyUI", "InfrastructurePanel", "ContractPanel", "EmployeePanel",
        "DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel",
        "RegionsPanel", "WorldOpportunitiesPanel", "ProductionControlPanel",
        "SupplyChainPanel", "EmpireExpansionPanel", "EmpireIntelligencePanel",
        "SaveLoadPanel", "BusinessOperationsPanel", "EmpireProgressionPanel",
        "EmpireIdentityPanel", "NotificationsCenterPanel"
    ]
    for node_name in world_nodes:
        check(game.get_node_or_null("World/" + node_name) != null, "World node: " + node_name)
    for node_name in system_nodes:
        check(game.get_node_or_null("Systems/" + node_name) != null, "System node: " + node_name)
    for node_name in ui_nodes:
        check(game.get_node_or_null("UI/" + node_name) != null, "UI node: " + node_name)

    for method_name in [
        "inspect_property", "acquire_property", "restore_property", "sell_property",
        "lease_property", "open_business", "choose_business_purpose", "create_business",
        "buy_inputs", "produce_goods", "hire_employee", "upgrade_business",
        "marketing_campaign", "change_price", "cycle_supplier", "sign_contract",
        "take_loan", "repay_loan", "advance_day", "save_game", "load_game"
    ]:
        check(game.has_method(method_name), "Main gameplay API: " + method_name)

    var hq := game.get_node_or_null("UI/HeadquartersPanel")
    check(hq != null and hq.get("headquarters_visual") != null, "Headquarters screen owns staged visual")
    if hq != null and hq.get("headquarters_visual") != null:
        var visual: Node = hq.get("headquarters_visual")
        check(visual.has_method("set_headquarters_state"), "Headquarters staged visual exposes update contract")

    game.free()
    current_scene = null
    await process_frame

func _collect_matching_files(path: String, extensions: Array, result: Array[String]) -> void:
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
            if not SKIP_DIRECTORIES.has(entry):
                _collect_matching_files(full, extensions, result)
        else:
            for extension in extensions:
                if entry.ends_with(str(extension)):
                    result.append(full)
                    break
        entry = dir.get_next()
    dir.list_dir_end()

func _quoted_res_paths(text: String) -> Array[String]:
    var result: Array[String] = []
    var cursor := 0
    while true:
        var start := text.find("res://", cursor)
        if start < 0:
            break
        var finish := start
        while finish < text.length():
            var ch := text[finish]
            if ch == "\"" or ch == "'" or ch == ")" or ch == "]" or ch == "}" or ch == " " or ch == "\t" or ch == "\r" or ch == "\n":
                break
            finish += 1
        var path := text.substr(start, finish - start).strip_edges()
        while path.ends_with(",") or path.ends_with(";"):
            path = path.left(path.length() - 1)
        if path != "res://" and not result.has(path):
            result.append(path)
        cursor = maxi(finish + 1, start + 6)
    return result

func _declared_functions(source: String) -> Array[String]:
    var result: Array[String] = []
    for line in source.split("\n"):
        var stripped := line.strip_edges()
        if stripped.begins_with("func "):
            var open := stripped.find("(")
            if open > 5:
                var name := stripped.substr(5, open - 5).strip_edges()
                if not result.has(name):
                    result.append(name)
    return result
