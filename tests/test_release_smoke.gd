extends SceneTree

var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error("FAIL: " + label)

func run() -> void:
    for path in ["res://project.godot","res://scenes/Main.tscn","res://scripts/game_state.gd","res://scripts/save_system.gd","res://scripts/employee_ui.gd","res://scripts/finance_scene_bridge.gd"]:
        check(FileAccess.file_exists(path), "Required release file: " + path)
    for path in ["res://data/properties.json","res://data/industries.json","res://data/resources.json","res://data/employees.json","res://data/competitors.json","res://data/technologies.json","res://data/events.json","res://data/balance.json"]:
        check(FileAccess.file_exists(path), "Balancing data exists: " + path)
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads")
    if scene != null:
        var game = scene.instantiate(); root.add_child(game); await process_frame
        for path in ["World/MainRenderer","World/WorldView","World/RegionController","Systems/GameBalance","Systems/Progression","Systems/FinanceSystem","UI/MainHUD","UI/TechnologyPanel","UI/HistoryPanel","UI/NewsPanel","UI/AlliancePanel","UI/ContractPanel","UI/EmployeePanel"]:
            check(game.get_node_or_null(path) != null, "Current architecture node: " + path)
        var finance_scene_node = game.get_node_or_null("Systems/FinanceSystem")
        check(finance_scene_node != null and finance_scene_node.get_script() != null and str(finance_scene_node.get_script().resource_path).ends_with("finance_scene_bridge.gd"), "Scene FinanceSystem is a bridge, not a second ledger")
        check(game.has_method("advance_day"), "Main advance_day API")
        check(game.has_method("save_game"), "Main save_game API")
        check(game.has_method("load_game"), "Main load_game API")
        game.free()
    print("RELEASE SMOKE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)