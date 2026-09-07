extends SceneTree

## V8.1: dynamic share pricing. Quotes track fundamentals daily and shock
## on wars; the ledger stays the only authority that moves cash.
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
    var Rivals = load("res://scripts/competitors.gd")
    check(Rivals != null, "Competitor model loads")
    if Rivals == null:
        quit(1)
        return
    var rivals = Rivals.new()
    rivals._normalize()
    var base := int(rivals.share_price(0))
    check(base > 0, "Founding quote positive")
    rivals.rivals[0]["market_share"] = 0.55
    rivals.rivals[0]["technology"] = 9
    rivals.rivals[0]["cash"] = 400000
    for i in range(30):
        rivals.daily_update(100 + i)
    var boom := int(rivals.share_price(0))
    check(boom > base, "Strong fundamentals lift the quote")
    rivals.rivals[1]["market_share"] = 0.02
    rivals.rivals[1]["technology"] = 1
    rivals.rivals[1]["cash"] = 1000
    for i in range(30):
        rivals.daily_update(200 + i)
    check(int(rivals.share_price(1)) < boom, "Weak fundamentals quote lower")
    for r in rivals.rivals:
        (r as Dictionary)["cash"] = 50000
    var war: Dictionary = rivals.maybe_corporate_war(36)
    check(not war.is_empty(), "War breaks out")
    var target_name := str(war.get("target", ""))
    var target_index := -1
    for i in range((rivals.rivals as Array).size()):
        if str((rivals.rivals as Array)[i].get("name", "")) == target_name:
            target_index = i
    check(target_index >= 0, "Target located")
    check(bool((rivals.rivals as Array)[target_index].get("war_sale", false)), "Target on fire sale")
    var snapshot: Dictionary = rivals.capture_state()
    var restored = Rivals.new()
    restored.restore_state(snapshot)
    check(int(restored.share_price(0)) == int(rivals.share_price(0)), "Quotes persist across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with dynamic pricing")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    print("V81 SHARE PRICING RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
