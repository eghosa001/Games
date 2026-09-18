extends SceneTree

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
    var Ranking = load("res://scripts/global_ranking_system.gd")
    check(Ranking != null, "Ranking system loads")
    if Ranking == null:
        quit(1)
        return

    var ranking: Node = Ranking.new()
    root.add_child(ranking)
    await process_frame
    ranking.set_process(false)
    ranking.companies.clear()
    ranking.daily_snapshots.clear()
    ranking.weekly_snapshots.clear()
    ranking.historical.clear()
    ranking.regional_rankings.clear()
    ranking.last_day = -1

    ranking.register_company("alpha", "Alpha", "north")
    ranking.register_company("beta", "Beta", "south")
    ranking.update_company("alpha", {"valuation": 100.0, "profit": 25.0})
    ranking.update_company("beta", {"valuation": 200.0, "profit": 10.0})

    var valuation: Array = ranking.get_ranking("valuation")
    check(valuation.size() == 2 and str(valuation[0].get("id", "")) == "beta", "Ranking sorts highest score first")
    var north: Array = ranking.get_regional_ranking("north", "valuation")
    check(north.size() == 1 and str(north[0].get("id", "")) == "alpha", "Regional ranking filters companies")

    ranking.process_day(7)
    check(not ranking.get_snapshot(7).is_empty(), "Daily ranking snapshot is stored")
    check(ranking.get_weekly_snapshots().size() >= 1, "Weekly ranking snapshot is stored")

    var restored: Node = Ranking.new()
    restored.restore_state(ranking.capture_state())
    check(restored.get_ranking("valuation").size() >= 2, "Ranking state survives restore")
    check(str(restored.get_ranking("valuation")[0].get("id", "")) == "beta", "Restored ranking preserves order")

    ranking.free()
    restored.free()
    print("GLOBAL RANKING RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
