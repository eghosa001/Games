extends SceneTree

## V1.5: acquisition battles. Rival assets are contested through opening bids,
## raises and walk-aways; victories charge once, trigger retaliation, count
## toward the empire and enter corporate history.
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

    var gated: Dictionary = rivals.start_acquisition_battle(0, 1000000, 10)
    check(not bool(gated.get("ok", false)), "Battle requires 35 reputation")
    var poor: Dictionary = rivals.start_acquisition_battle(0, 1, 100)
    check(not bool(poor.get("ok", false)), "Battle requires capital for the opening ask")

    var opened: Dictionary = rivals.start_acquisition_battle(0, 1000000, 100)
    check(bool(opened.get("ok", false)), "Bidding battle opens")
    check(int(opened.get("rounds", 0)) == 3, "Battle runs three rounds")
    check(int(opened.get("rival_bid", 0)) > int(opened.get("player_bid", 0)), "A rival buyer opens above the player")
    var status: Dictionary = rivals.battle_status(0)
    check(bool(status.get("active", false)), "Battle status reports active bidding")
    var again: Dictionary = rivals.start_acquisition_battle(0, 1000000, 100)
    check(not bool(again.get("ok", false)), "A second battle cannot open mid-bidding")

    var broke: Dictionary = rivals.raise_acquisition_bid(0, 1)
    check(not bool(broke.get("ok", false)), "Raise fails without capital")
    var raised: Dictionary = rivals.raise_acquisition_bid(0, 1000000)
    check(bool(raised.get("ok", false)), "Raise counters within rounds")
    check(int(raised.get("rounds", -1)) == 2, "Raise consumes a round")

    var walk: Dictionary = rivals.walk_away_acquisition(0)
    check(bool(walk.get("ok", false)), "Walking away ends the battle")
    var quiet: Dictionary = rivals.battle_status(0)
    check(not bool(quiet.get("active", false)), "Battle status clears after walking away")
    var nothing: Dictionary = rivals.raise_acquisition_bid(0, 1000000)
    check(not bool(nothing.get("ok", false)), "Raise fails with no active battle")

    var opened2: Dictionary = rivals.start_acquisition_battle(1, 1000000, 100)
    check(bool(opened2.get("ok", false)), "Second battle opens")
    rivals.rivals[1]["battle_rival_bid"] = 1
    rivals.rivals[1]["battle_rounds"] = 1
    var won: Dictionary = rivals.raise_acquisition_bid(1, 1000000)
    check(bool(won.get("ok", false)) and bool(won.get("won", false)), "Higher bid wins the battle")
    check(int(won.get("cost", 0)) > 0, "Victory reports the closing cost")
    check(int(rivals.rivals[1].get("offer_cooldown", 0)) >= 20, "Victory sets a negotiation cooldown")
    var retaliated: Dictionary = rivals.retaliation_after_acquisition(1)
    check(bool(retaliated.get("ok", false)), "Victory triggers rival retaliation")
    check(int(rivals.rivals[1].get("retaliation", 0)) > 0, "Retaliation pressure is recorded")

    var opened3: Dictionary = rivals.start_acquisition_battle(2, 5000000, 100)
    check(bool(opened3.get("ok", false)), "Third battle opens")
    rivals.rivals[2]["battle_rival_bid"] = 5000000
    rivals.rivals[2]["battle_rounds"] = 1
    var lost: Dictionary = rivals.raise_acquisition_bid(2, 100000)
    check(not bool(lost.get("ok", false)) and not bool(lost.get("won", true)), "Lost battle reports defeat without charging")
    var calm: Dictionary = rivals.battle_status(2)
    check(not bool(calm.get("active", false)), "Battle status clears after defeat")

    var snapshot: Dictionary = rivals.capture_state()
    var restored = Rivals.new()
    restored.restore_state(snapshot)
    check(restored.battle_status(1).get("active", true) == false, "Battle state survives save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for acquisition commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        game.cash = 500000
        game.reputation = 100
        game.select_rival(0)
        var before_count := int(game.acquisition_count)
        game.negotiate_selected_acquisition()
        check(int(game.acquisition_count) == before_count + 1, "Instant acquisition counts toward the empire")
        check(int(game.command_system.relationship_system.rivals.rivals[0].get("retaliation", 0)) > 0, "Instant acquisition provokes retaliation")
        game.start_acquisition_battle()
        check(bool(game.command_system.relationship_system.rivals.rivals[0].get("battle_active", false)) or game.command_system.relationship_system.rivals.rivals[0].get("offer_cooldown", 0) > 0, "Instant win triggers battle cooldown")
        game.select_rival(1)
        game.start_acquisition_battle()
        check(bool(game.command_system.relationship_system.rivals.rivals[game.selected_rival].get("battle_active", false)), "Battle command opens bidding")
        game.walk_away_acquisition()
        check(not bool(game.command_system.relationship_system.rivals.rivals[game.selected_rival].get("battle_active", false)), "Walk-away command ends bidding")
        var services = root.get_node_or_null("RenewServices")
        var history = services.get_service("RenewHistorySystem") if services != null else null
        check(history != null, "History system is available")
        game.free()
        await process_frame
    print("V15 ACQUISITIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
