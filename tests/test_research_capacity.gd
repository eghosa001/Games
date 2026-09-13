extends SceneTree

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

    var research = root.get_node_or_null("RenewResearchSystem")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(research != null, "ResearchSystem resolves")
    check(finance != null, "FinanceSystem resolves")
    if research == null or finance == null:
        game.free()
        quit(1)
        return

    finance.receive(100000, "research capacity test funding")
    var facility: Dictionary = research.register_facility("player", "Capacity Test Lab", 1, 1)
    var facility_id := str(facility.get("id", ""))
    var first: Dictionary = research.start_research("process_automation", "player", research.TYPE_COMPANY, ["engineering", "operations"], 3, 1000.0, facility_id)
    check(bool(first.get("ok", false)), "First project occupies available facility slot")
    var cash_after_first := int(finance.available_cash())
    var next_id_after_first := int(research.next_project_id)
    var second: Dictionary = research.start_research("advanced_materials", "player", research.TYPE_COMPANY, ["engineering", "materials"], 3, 1000.0, facility_id)
    check(not bool(second.get("ok", false)), "Second project is rejected at facility capacity")
    check(str(second.get("error", "")) == "facility_at_capacity", "Capacity rejection reports explicit reason")
    check(int(finance.available_cash()) == cash_after_first, "Rejected capacity request does not spend cash")
    check(int(research.next_project_id) == next_id_after_first, "Rejected capacity request does not allocate project ID")
    check(int(research.facilities[facility_id].get("utilization", 0)) == 1, "Rejected capacity request does not overbook utilization")

    research.restore_state({"facilities": {"bad": {"capacity": 0, "level": 0, "utilization": 9}}, "projects": {}, "university_partners": {}, "next_project_id": 0, "next_facility_id": 0, "events": []})
    check(int(research.facilities["bad"]["capacity"]) == 1, "Restore normalizes invalid facility capacity")
    check(int(research.facilities["bad"]["level"]) == 1, "Restore normalizes invalid facility level")
    check(int(research.facilities["bad"]["utilization"]) == 1, "Restore clamps utilization to capacity")
    check(int(research.next_project_id) == 1 and int(research.next_facility_id) == 1, "Restore normalizes invalid ID counters")

    game.free()
    await process_frame
    print("RESEARCH CAPACITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
