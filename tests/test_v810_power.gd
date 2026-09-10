extends SceneTree

## V8.10: world-power score. Eight weighted dimensions composite live
## systems into one number without replacing individual rankings.
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
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for power wiring")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var services = root.get_node_or_null("RenewServices")
    var ranking = services.get_service("RenewGlobalRankingSystem") if services != null else null
    check(ranking != null, "Ranking system available")
    if ranking == null:
        game.free()
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    if state != null and state.has_method("clear"):
        state.clear()
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        finance.financing = {}
        finance.debt = 0
        finance.cash = 20000
        finance.equity_contributed = 20000.0
        finance.retained_earnings = 0.0
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
    var lean: Dictionary = ranking.world_power()
    check(abs(float(lean.get("total", -1.0)) - 0.18 * float(lean.get("economic", 0.0)) - 0.12 * float(lean.get("resource", 0.0)) - 0.14 * float(lean.get("industrial", 0.0)) - 0.14 * float(lean.get("technology", 0.0)) - 0.10 * float(lean.get("logistics", 0.0)) - 0.10 * float(lean.get("diplomatic", 0.0)) - 0.10 * float(lean.get("alliance", 0.0)) - 0.12 * float(lean.get("cultural", 0.0))) < 0.01, "Total matches weighted parts")
    check(float(lean.get("total", 100.0)) < 25.0, "Foundling scores low")
    finance.revenue = 300000.0
    state.set_value("player", "reputation", 80)
    var strong: Dictionary = ranking.world_power()
    check(float(strong.get("total", 0.0)) > float(lean.get("total", 0.0)), "Growth raises world power")
    check(float(strong.get("economic", 0.0)) == 100.0, "Economic dimension caps")
    check(float(strong.get("cultural", 0.0)) == 80.0, "Culture mirrors reputation")
    check(str(ranking.world_power_text()).find("WORLD POWER") >= 0, "Power renders as text")

    check(game.has_method("world_power"), "Main exposes world_power")
    game.command_system.world_power()
    check(str(game.command_system._state_value("company", "message", "")).find("WORLD POWER") >= 0, "Power command reports")
    game.free()
    await process_frame
    print("V810 POWER RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
