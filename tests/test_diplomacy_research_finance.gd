extends SceneTree

## Regression: research treaties must settle their contribution before sharing
## technology, and the technology benefit must not compound every active day.
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
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var services = root.get_node_or_null("RenewServices")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var production = root.get_node_or_null("RenewProductionSystem")
    var diplomacy = services.get_service("RenewDiplomacySystem") if services != null else null
    var effects = services.get_service("RenewDiplomacyEffects") if services != null else null
    check(finance != null and production != null and diplomacy != null and effects != null, "Research treaty stack resolves")
    if finance == null or production == null or diplomacy == null or effects == null:
        game.free()
        quit(1)
        return

    var terms := {
        "obligations": {"research_contribution": 1500},
        "benefits": {"technology_share": 0.10, "trust_per_day": 0.12}
    }
    var proposed: Dictionary = diplomacy.propose_treaty("player", "northstar_logistics", "research", terms, 30)
    check(bool(proposed.get("ok", false)), "Research treaty proposes")
    var treaty_id := str(proposed.get("treaty", {}).get("id", ""))
    check(bool(diplomacy.accept_treaty(treaty_id, "northstar_logistics").get("ok", false)), "Research treaty activates")
    var treaty: Dictionary = diplomacy.get_treaty(treaty_id)
    var baseline_level := int(production.technologies.get("logistics", 0))

    game.cash = 100
    var blocked_cash := int(finance.cash)
    effects._apply(treaty, int(game.day))
    var blocked_state: Dictionary = effects.applied.get(treaty_id, {})
    check(bool(blocked_state.get("funding_blocked", false)), "Unaffordable research treaty is blocked")
    check(not bool(blocked_state.get("funded", false)), "Blocked research treaty remains unfunded")
    check(int(production.technologies.get("logistics", 0)) == baseline_level, "Blocked treaty grants no technology")
    check(int(finance.cash) == blocked_cash, "Blocked research treaty consumes no cash")

    game.cash = 5000
    var before_funding := int(finance.cash)
    effects._apply(treaty, int(game.day) + 1)
    var funded_state: Dictionary = effects.applied.get(treaty_id, {})
    var shared_level := int(production.technologies.get("logistics", 0))
    check(bool(funded_state.get("funded", false)), "Research treaty funds when capital is available")
    check(int(funded_state.get("research_contribution", 0)) == 1500, "Research contribution is recorded")
    check(int(finance.cash) == before_funding - 1500, "Research contribution debits authoritative finance exactly once")
    check(shared_level == baseline_level + 1, "Funded research treaty shares one technology level")

    effects._apply(treaty, int(game.day) + 2)
    effects._apply(treaty, int(game.day) + 3)
    check(int(finance.cash) == before_funding - 1500, "Research contribution is not charged again")
    check(int(production.technologies.get("logistics", 0)) == shared_level, "Research treaty benefit does not compound every day")
    check(bool(finance.validate_invariants().get("ok", false)), "Research treaty keeps finance invariants valid")

    print("DIPLOMACY RESEARCH FINANCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
