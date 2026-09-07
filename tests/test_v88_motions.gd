extends SceneTree

## V8.8: alliance motion flow. Weighted votes decide sanction and admit
## motions; passing motions execute through the existing member systems.
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
    var Alliance = load("res://scripts/alliance_v1_system.gd")
    check(Alliance != null, "Alliance system loads")
    if Alliance == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var system: Node = Alliance.new()
    root.add_child(system)
    await process_frame

    check(not bool(system.open_motion("player", "sanction", "ghost").get("ok", false)), "Motions need a pact first")
    check(bool(system.create_alliance("Motion Pact", "player").get("ok", false)), "Alliance created")
    check(not bool(system.open_motion("builder_a", "sanction", "player").get("ok", false)), "Outsiders cannot propose")
    check(bool(system.invite_member(system.get_member_alliance("player").get("id", ""), "player", "builder_a").get("ok", false)), "Founder invites")
    var id := str(system.get_member_alliance("player").get("id", ""))
    check(bool(system.join_alliance(id, "builder_a").get("ok", false)), "Member joins")
    check(bool(system.invite_member(id, "player", "builder_b").get("ok", false)), "Second invite")
    check(bool(system.join_alliance(id, "builder_b").get("ok", false)), "Second member joins")
    check(not bool(system.open_motion("builder_a", "sanction", "builder_b").get("ok", false)), "Plain members cannot propose")
    check(not bool(system.open_motion("player", "censure", "builder_a").get("ok", false)), "Unknown motion kinds rejected")
    var opened: Dictionary = system.open_motion("player", "sanction", "builder_a")
    check(bool(opened.get("ok", false)), "Sanction motion opens")
    check(int(opened.get("index", -1)) == 0, "First motion indexed")
    check(not bool(system.open_motion("player", "sanction", "builder_b").get("ok", false)), "One motion at a time")
    var carried: Dictionary = system.vote_motion("player", 0, true)
    check(str(carried.get("status", "")) == "passed", "Weighted majority carries")
    check(int(system.get_alliance(id).get("member_trust", {}).get("builder_a", 100)) < 50, "Sanction executes on pass")
    check(not bool(system.vote_motion("player", 0, true).get("ok", false)), "Closed motions stay closed")
    var admit: Dictionary = system.open_motion("player", "admit", "outsider_c")
    check(bool(admit.get("ok", false)), "Admit motion opens")
    var refused: Dictionary = system.vote_motion("player", 1, false)
    check(str(refused.get("status", "")) == "rejected", "Founder weight can reject")
    check(not (system.get_alliance(id).get("members", {}) as Dictionary).has("outsider_c"), "Rejected admits join nobody")
    var admit2: Dictionary = system.open_motion("player", "admit", "outsider_c")
    check(bool(admit2.get("ok", false)), "Admit motion reopens")
    var accepted: Dictionary = system.vote_motion("player", 2, true)
    check(str(accepted.get("status", "")) == "passed", "Admit motion carries")
    check((system.get_alliance(id).get("members", {}) as Dictionary).has("outsider_c"), "Admitted member joins")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for govern wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        var panel: Node = game.get_node_or_null("UI/AlliancePanel")
        check(panel != null, "Alliance panel present")
        game.free()
        await process_frame
    system.queue_free()
    await process_frame
    print("V88 MOTIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
