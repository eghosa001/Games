extends SceneTree

## V2.4: treaty-backed joint ventures. Co-founded ventures split ownership,
## require real capital from both sides and pay daily profit shares.
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
    check(scene != null, "Main scene loads for joint ventures")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var services = root.get_node_or_null("RenewServices")
    var diplomacy = services.get_service("RenewDiplomacySystem") if services != null else null
    var bridge = services.get_service("RenewDiplomacyControl") if services != null else null
    check(state != null and finance != null and diplomacy != null and bridge != null, "Diplomacy stack resolves")
    if state == null or finance == null or diplomacy == null or bridge == null:
        game.free()
        quit(1)
        return
    game.cash = 100000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    for _i in range(5):
        game.restore_property()
    game.choose_business_purpose(0)
    game.open_business()
    check(game.business_open, "Business operates before the venture")

    var terms := {"joint_capital": 6000, "party_a_percent": 50.0, "party_b_percent": 50.0, "trust_effect": 3.0}
    var proposed: Dictionary = diplomacy.propose_treaty("player", "northstar_logistics", "joint_venture", terms, 30)
    check(bool(proposed.get("ok", false)), "Joint venture proposes")
    var treaty_id := str(proposed.get("treaty", {}).get("id", ""))
    var accepted: Dictionary = diplomacy.accept_treaty(treaty_id, "northstar_logistics")
    check(bool(accepted.get("ok", false)), "Counterparty accepts the venture")
    game.advance_day()
    await process_frame
    await process_frame
    var venture_id := "jv:%s" % treaty_id
    var ownership = game.get_node_or_null("Systems/OwnershipSystem")
    check(ownership != null and ownership.has_entity(venture_id), "Venture entity materializes")
    check(abs(ownership.get_ownership_percent(venture_id, "player") - 50.0) < 0.01, "Player holds half the venture")
    check(abs(ownership.get_ownership_percent(venture_id, "northstar_logistics") - 50.0) < 0.01, "Partner holds half the venture")
    var material: Dictionary = bridge.get_materialized_state(treaty_id)
    check(bool(material.get("funded", false)), "Venture funds from both sides")
    check(int(material.get("funded_capital", 0)) == 6000, "Full joint capital lands")
    var paid_before := int(material.get("total_paid_out", 0))
    game.advance_day()
    await process_frame
    await process_frame
    material = bridge.get_materialized_state(treaty_id)
    check(int(material.get("total_paid_out", 0)) > paid_before, "Venture pays daily profit shares")
    check(bool(finance.validate_invariants().get("ok", false)), "Venture books balance")

    diplomacy.cancel_treaty(treaty_id, "player", "strategic refocus")
    var paid_at_cancel := int(bridge.get_materialized_state(treaty_id).get("total_paid_out", 0))
    game.advance_day()
    await process_frame
    await process_frame
    check(int(bridge.get_materialized_state(treaty_id).get("total_paid_out", 0)) == paid_at_cancel, "Cancelled venture stops paying")

    # Regression: an accepted JV must not create ownership before both-side funding succeeds.
    var blocked_terms := {"joint_capital": 2000, "party_a_percent": 50.0, "party_b_percent": 50.0}
    var blocked_proposal: Dictionary = diplomacy.propose_treaty("player", "northstar_logistics", "joint_venture", blocked_terms, 30)
    check(bool(blocked_proposal.get("ok", false)), "Second venture proposes for funding regression")
    var blocked_id := str(blocked_proposal.get("treaty", {}).get("id", ""))
    check(bool(diplomacy.accept_treaty(blocked_id, "northstar_logistics").get("ok", false)), "Second venture is accepted")
    game.cash = 100
    var cash_before_block := int(finance.cash)
    game.advance_day()
    await process_frame
    await process_frame
    var blocked_venture_id := "jv:%s" % blocked_id
    var blocked_state: Dictionary = bridge.get_materialized_state(blocked_id)
    check(not bool(blocked_state.get("funded", false)), "Underfunded player blocks venture funding")
    check(not bool(blocked_state.get("materialized", false)), "Underfunded venture does not materialize ownership")
    check(not ownership.has_entity(blocked_venture_id), "Underfunded venture leaves no ghost ownership entity")
    check(int(finance.cash) == cash_before_block, "Failed venture funding does not consume player cash")

    game.cash = 100000
    game.advance_day()
    await process_frame
    await process_frame
    blocked_state = bridge.get_materialized_state(blocked_id)
    check(bool(blocked_state.get("funded", false)), "Blocked venture retries funding on a later day")
    check(bool(blocked_state.get("materialized", false)), "Funded retry materializes the venture")
    check(ownership.has_entity(blocked_venture_id), "Funded retry creates venture ownership exactly when capital lands")
    check(bool(finance.validate_invariants().get("ok", false)), "Retry keeps finance invariants valid")

    print("V24 JOINT VENTURES RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
