extends SceneTree

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var Script = load("res://scripts/competitors.gd")
    check(Script != null, "Competitor system loads")
    if Script == null:
        quit(1)
        return
    var ai = Script.new()
    ai._normalize()
    check(ai.rivals.size() >= 3, "Persistent corporate agents exist")
    var status = ai.ai_status(0)
    for key in ["id", "personality", "cash", "debt", "assets", "businesses", "employees", "technology", "districts", "suppliers", "customers", "risk_tolerance", "strategic_priorities", "last_strategy", "last_action", "memory_size"]:
        check(status.has(key), "AI status has " + key)
    var before = ai.rivals[0].duplicate(true)
    var news = ai.strategic_ai_update(1, {"cash": 25000, "reputation": 50, "player_price": 110, "selected_district": 0, "acquisition_count": 1})
    check(news is Array, "AI executes a decision cycle")
    check(not str(ai.rivals[0]["last_strategy"]).is_empty(), "AI selects strategy")
    check(not str(ai.rivals[0]["last_action"]).is_empty(), "AI executes action")
    check(ai.rivals[0]["memory"].size() == 1, "AI records result in memory")
    check(ai.rivals[0].has("last_observation") and ai.rivals[0]["last_observation"].has("player_threat"), "AI records observation")
    check(ai.rivals[0].has("last_evaluation") and ai.rivals[0]["last_evaluation"].has("liquidity"), "AI records evaluation")
    var changed := false
    for key in ["cash", "assets", "businesses", "employees", "production", "inventory", "technology", "price", "market_share", "reputation", "presence", "supplier_pressure", "retaliation", "strategy_cooldown"]:
        if ai.rivals[0].get(key) != before.get(key):
            changed = true
            break
    check(changed, "AI changes corporate state after executing strategy")
    var snapshot = ai.rivals.duplicate(true)
    var restored = Script.new()
    restored.rivals = snapshot
    restored._normalize()
    check(restored.ai_status(0)["memory_size"] == 1, "AI memory persists through state snapshot")
    print("COMPETITOR AI RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
