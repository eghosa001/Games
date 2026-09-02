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
    var OwnershipSystem = load("res://scripts/ownership_system.gd")
    check(OwnershipSystem != null, "OwnershipSystem loads")
    if OwnershipSystem == null:
        quit(1)
        return

    var ownership = OwnershipSystem.new()
    var created = ownership.register_entity("renew_co", OwnershipSystem.ENTITY_COMPANY, 1000000)
    check(bool(created["ok"]), "Company entity registers")
    check(ownership.has_entity("renew_co"), "Registered company is addressable")

    check(bool(ownership.issue_shares("renew_co", "founder", 600000).get("ok", false)), "Founder shares issue")
    check(bool(ownership.issue_shares("renew_co", "fund_a", 200000).get("ok", false)), "Investor shares issue")
    check(bool(ownership.issue_shares("renew_co", "fund_b", 200000).get("ok", false)), "Second investor shares issue")
    check(abs(ownership.get_ownership_percent("renew_co", "founder") - 60.0) < 0.01, "Ownership percentage is calculated")
    check(ownership.has_control("renew_co", "founder"), "Founder has ordinary control")
    check(abs(ownership.get_voting_percent("renew_co", "founder") - 60.0) < 0.01, "Voting percentage is calculated")

    var diluted = ownership.issue_for_percent("renew_co", "fund_c", 10.0)
    check(bool(diluted["ok"]), "Post-issue percentage issuance succeeds")
    check(ownership.get_ownership_percent("renew_co", "founder") < 60.0, "New issuance dilutes existing holders")
    check(ownership.get_ownership_percent("renew_co", "fund_c") > 9.0, "New holder receives target post-issue stake")

    var transfer = ownership.transfer_shares("renew_co", "fund_a", "founder", 50000)
    check(bool(transfer["ok"]), "Share transfer succeeds")
    check(ownership.get_ownership_percent("renew_co", "founder") > 50.0, "Transfer updates founder ownership")

    var buyback = ownership.buyback("renew_co", "fund_b", 25000, 12.0)
    check(bool(buyback["ok"]), "Buyback succeeds")
    check(int(ownership.get_entity("renew_co")["treasury_shares"]) == 25000, "Buyback moves shares to treasury")

    var board = ownership.set_board_size("renew_co", 5)
    check(bool(board["ok"]), "Board size can be configured")
    check(bool(ownership.appoint_board_seat("renew_co", "founder", "seat_1")["ok"]), "Founder can receive board seat")
    check(bool(ownership.appoint_board_seat("renew_co", "fund_a", "seat_2")["ok"]), "Investor can receive board seat")
    check(ownership.get_board_seats("renew_co", "founder") == 1, "Board seat count is tracked")

    var dividend = ownership.distribute_dividend("renew_co", 10000.0)
    check(bool(dividend["ok"]), "Dividend distribution succeeds")
    check(float(dividend["paid"]) > 0.0, "Dividend creates holder payouts")

    check(bool(ownership.adjust_investor_confidence("renew_co", 15.0, "strong earnings")["ok"]), "Investor confidence is adjustable")
    check(float(ownership.get_entity("renew_co")["investor_confidence"]) == 65.0, "Investor confidence remains bounded and persisted")
    check(bool(ownership.set_defense("renew_co", 2, true)["ok"]), "Takeover defense can be configured")
    check(int(ownership.get_entity("renew_co")["defense_level"]) == 2, "Defense level is stored")

    var asset = ownership.register_entity("warehouse_01", OwnershipSystem.ENTITY_ASSET, 100000)
    check(bool(asset["ok"]), "Asset entity registers independently")
    var joint_venture = ownership.register_entity("renew_partner_jv", OwnershipSystem.ENTITY_JV, 1000000)
    check(bool(joint_venture["ok"]), "JV entity registers independently")
    check(bool(ownership.issue_shares("renew_partner_jv", "renew_co", 500000).get("ok", false)), "Company can own a JV")
    check(abs(ownership.get_ownership_percent("renew_partner_jv", "renew_co") - 50.0) < 0.01, "JV ownership is independent from company ownership")

    var snapshot = ownership.save_state()
    var restored = OwnershipSystem.new()
    restored.load_state(snapshot)
    check(restored.has_entity("renew_co") and restored.has_entity("warehouse_01") and restored.has_entity("renew_partner_jv"), "Ownership state persists across save/load")
    check(restored.transaction_log.size() == ownership.transaction_log.size(), "Ownership transaction history persists")
    check(restored.get_ownership_percent("renew_partner_jv", "renew_co") == ownership.get_ownership_percent("renew_partner_jv", "renew_co"), "Restored ownership percentages match")

    var control = restored.takeover_control("renew_co", "founder", 50.0)
    check(bool(control["ok"]), "Control check succeeds for controlling holder")
    var non_control = restored.takeover_control("renew_co", "fund_b", 50.0)
    check(not bool(non_control["ok"]), "Control check rejects non-controlling holder")

    print("OWNERSHIP SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
