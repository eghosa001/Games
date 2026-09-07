extends SceneTree

## V8.5: public listing. A 20 percent non-voting float lists once gates
## pass; the cap table always reflects the ledger.
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
    check(scene != null, "Main scene loads for listing")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var corporate = game.get_node_or_null("World/Corporate")
    check(corporate != null, "Corporate controller resolves")
    if corporate == null:
        game.free()
        quit(1)
        return
    game.go_public()
    check(str(game.message).find("250K") >= 0 or str(game.message).find("40 reputation") >= 0, "Listing gated early")
    game.cash = 300000
    await process_frame
    game.go_public()
    check(str(game.message).find("40 reputation") >= 0, "Reputation gate holds")
    var state = root.get_node_or_null("RenewGameState")
    state.set_value("player", "reputation", 60)
    var cash_before := int(game.cash)
    game.go_public()
    check(str(game.message).find("IPO") >= 0, "IPO lists")
    check(int(game.cash) > cash_before, "Offering raises capital")
    var table: String = corporate.cap_table_text()
    check(table.find("public_float") >= 0, "Cap table names the public float")
    check(table.find("founder") >= 0, "Cap table names the founder")
    check(table.find("listed") >= 0, "Cap table shows listed status")
    game.go_public()
    check(str(game.message).find("already listed") >= 0, "Listing happens once")
    var price_before: float = float(corporate.public_share_price())
    game.cash = cash_before + 200000
    await process_frame
    check(corporate.public_share_price() >= price_before, "Public price tracks valuation")
    game.free()
    await process_frame
    print("V85 LISTING RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
