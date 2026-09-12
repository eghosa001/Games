extends SceneTree

## Regression: service-owned advanced systems must survive the canonical save/load path.
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

func _set_finance_cash(finance: Node, target: int) -> void:
    var current := int(finance.available_cash())
    if current < target:
        finance.receive(target - current, "service persistence seed")
    elif current > target:
        finance.spend(current - target, "service persistence normalization")

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

    var registry = root.get_node_or_null("RenewServices")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var hq = registry.get_service("RenewHeadquartersSystem") if registry != null else null
    var research = registry.get_service("RenewResearchSystem") if registry != null else null
    var diplomacy = registry.get_service("RenewDiplomacySystem") if registry != null else null
    check(registry != null and finance != null and hq != null and research != null and diplomacy != null, "Persistent service stack resolves")
    if registry == null or finance == null or hq == null or research == null or diplomacy == null:
        game.free()
        quit(1)
        return

    _set_finance_cash(finance, 250000)
    var hq_result: Dictionary = hq.upgrade_with_finance(finance, int(game.day))
    check(bool(hq_result.get("ok", false)), "HQ state changes before save")
    var research_result: Dictionary = research.start_research("process_automation", "founder")
    check(bool(research_result.get("ok", false)), "Research project starts before save")
    var project_id := str(research_result.get("project", {}).get("id", ""))

    var proposal: Dictionary = diplomacy.propose_treaty("player", "northstar_logistics", "trade", {"tariff_multiplier":0.9}, 20)
    check(bool(proposal.get("ok", false)), "Diplomacy treaty proposes before save")
    var treaty_id := str(proposal.get("treaty", {}).get("id", ""))
    var accepted: Dictionary = diplomacy.accept_treaty(treaty_id, "northstar_logistics")
    check(bool(accepted.get("ok", false)), "Diplomacy treaty activates before save")

    var expected_hq_stage := int(hq.get_stage_index())
    var expected_project_count: int = int(research.list_projects("founder").size())
    var expected_treaty_count: int = int(diplomacy.list_treaties("").size())
    game.save_game()

    hq.restore_state({})
    research.restore_state({})
    diplomacy.restore_state({})
    check(int(hq.get_stage_index()) == 0, "HQ runtime is deliberately cleared")
    check(research.list_projects("founder").is_empty(), "Research runtime is deliberately cleared")
    check(diplomacy.list_treaties("").is_empty(), "Diplomacy runtime is deliberately cleared")

    game.load_game()
    await process_frame
    await process_frame

    check(int(hq.get_stage_index()) == expected_hq_stage, "HQ runtime survives save/load")
    check(research.list_projects("founder").size() == expected_project_count, "Research project list survives save/load")
    check(not research.get_project(project_id).is_empty(), "Specific active research project survives save/load")
    check(diplomacy.list_treaties("").size() == expected_treaty_count, "Diplomacy treaties survive save/load")
    var restored_treaty: Dictionary = diplomacy.get_treaty(treaty_id) if diplomacy.has_method("get_treaty") else {}
    check(not restored_treaty.is_empty(), "Specific treaty survives save/load")
    check(bool(finance.validate_invariants().get("ok", false)), "Service persistence keeps finance valid")

    print("SERVICE PERSISTENCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
