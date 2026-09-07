extends SceneTree

## V1.5: alliances as economic organizations - trust, governance roles,
## levels, treasury allocation and atomic finance flows.
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
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        finance.financing = {}
        finance.debt = 0
        finance.loan_payment = 0
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
        finance.retained_earnings = 0.0
        finance.equity_contributed = 200000.0
        finance.cash = 200000
    var system: Node = Alliance.new()
    root.add_child(system)
    await process_frame

    var created: Dictionary = system.create_alliance("Trust Consortium", "player")
    check(bool(created.get("ok", false)), "Alliance created")
    var id := str(created.get("alliance", {}).get("id", ""))
    var founded: Dictionary = system.get_alliance(id)
    check(str(founded.get("members", {}).get("player", {}).get("role", "")) == "founder", "Founder holds the founder role")
    check(int(founded.get("member_trust", {}).get("player", 0)) == 75, "Founder starts trusted")
    check(int(founded.get("level", 0)) == 1, "Alliance starts at level 1")
    check(founded.has("trust") and founded.has("reputation"), "Alliance tracks trust and reputation")

    check(bool(system.invite_member(id, "player", "builder_a").get("ok", false)), "Founder invites")
    check(bool(system.join_alliance(id, "builder_a").get("ok", false)), "Member joins")
    check(int(system.get_alliance(id).get("member_trust", {}).get("builder_a", 0)) == 50, "Joiners start neutral")
    var member_invite: Dictionary = system.invite_member(id, "builder_a", "builder_b")
    check(not bool(member_invite.get("ok", false)), "Plain members cannot invite")
    check(bool(system.promote_to_director(id, "player", "builder_a").get("ok", false)), "Founder promotes a director")
    check(str(system.get_alliance(id).get("members", {}).get("builder_a", {}).get("role", "")) == "director", "Director role recorded")
    check(bool(system.invite_member(id, "builder_a", "builder_b").get("ok", false)), "Directors can invite")
    var outsider: Dictionary = system.promote_to_director(id, "builder_a", "builder_b")
    check(not bool(outsider.get("ok", false)), "Only the founder appoints directors")
    check(bool(system.demote_to_member(id, "player", "builder_a").get("ok", false)), "Founder demotes directors")
    check(str(system.get_alliance(id).get("members", {}).get("builder_a", {}).get("role", "")) == "member", "Demotion recorded")

    var trust_before := int(system.get_alliance(id).get("member_trust", {}).get("builder_a", 0))
    check(bool(system.donate_money("builder_a", 1000).get("ok", false)), "Member donates")
    check(int(system.get_alliance(id).get("member_trust", {}).get("builder_a", 0)) > trust_before, "Donations build trust")
    check(bool(system.sanction_member(id, "player", "builder_a", "missed contributions").get("ok", false)), "Founder sanctions")
    check(bool(system.sanction_member(id, "player", "builder_a", "missed deadlines").get("ok", false)), "Repeat sanctions stack")
    check(bool(system.sanction_member(id, "player", "builder_a", "ignored votes").get("ok", false)), "Persistent defiance compounds")
    check(int(system.get_alliance(id).get("member_trust", {}).get("builder_a", 100)) < 25, "Sanctions burn trust")
    var low_start: Dictionary = system.start_cooperative_project("builder_a")
    check(not bool(low_start.get("ok", false)), "Low-trust members cannot start projects")
    check(bool(system.start_cooperative_project("player").get("ok", false)), "Founder starts the railway")

    var big: Dictionary = system.donate_money("player", 60000)
    check(bool(big.get("ok", false)), "Major donation lands")
    check(int(system.get_alliance(id).get("level", 1)) >= 2, "Contributions level the alliance")
    var alloc_denied: Dictionary = system.allocate_treasury_to_railway("builder_a", 1000)
    check(not bool(alloc_denied.get("ok", false)), "Members cannot allocate treasury funds")
    var alloc: Dictionary = system.allocate_treasury_to_railway("player", 5000)
    check(bool(alloc.get("ok", false)), "Founder allocates treasury to the railway")
    check(int(alloc.get("allocated", 0)) == 5000, "Allocation moves the requested amount")
    check(int(system.get_alliance(id).get("treasury", -1)) == 56000, "Treasury reflects donation plus allocation")

    var infra: Dictionary = system.add_infrastructure(id, "Shared Depot", 1, 5000)
    check(bool(infra.get("ok", false)), "Alliance builds shared infrastructure")
    check(int(system.get_alliance(id).get("infrastructure", []).size()) == 1, "Infrastructure recorded")
    var poor_infra: Dictionary = system.add_infrastructure(id, "Mega Port", 1, 99999999)
    check(not bool(poor_infra.get("ok", false)), "Infrastructure respects treasury limits")
    var research: Dictionary = system.fund_research(id, "Joint Logistics Study", 2000)
    check(bool(research.get("ok", false)), "Alliance funds joint research")

    if finance != null:
        var cash_before := int(finance.cash)
        var fail_fund: Dictionary = system.create_alliance_with_finance(finance, "lonely_founder", "Nowhere Club", cash_before + 50000)
        check(not bool(fail_fund.get("ok", false)), "Unfunded founding is rejected")
        check(int(finance.cash) == cash_before, "Rejected founding charges nothing")

    var persisted: Dictionary = system.get_alliance(id)
    check(persisted.get("members", {}).get("builder_a", {}).get("role", "") == "member", "Roles persist")
    check(persisted.has("member_trust") and persisted.has("level"), "Trust and level persist")
    print("V15 ALLIANCES RESULT: %d passed, %d failed" % [passed, failed])
    system.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
