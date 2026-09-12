extends SceneTree

## V1.5: regional chartering with authoritative finance. Reputation gates access,
## payment must commit before geography/resources unlock, and UI commands must not
## charge a second time.
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
        finance.receive(target - current, "region test seed")
    elif current > target:
        finance.spend(current - target, "region test normalization")

func run() -> void:
    var RegionSystem = load("res://scripts/region_system.gd")
    check(RegionSystem != null, "Region system loads")
    if RegionSystem == null:
        quit(1)
        return
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(finance != null, "Authoritative finance system is available")
    if finance == null:
        quit(1)
        return
    _set_finance_cash(finance, 50000)

    var catalog = RegionSystem.new()
    root.add_child(catalog)
    await process_frame
    var regions: Array = catalog.list_regions()
    check(regions.size() == 3, "Canonical catalog holds three regions")
    check(str(catalog.get_region_by_id("renew_region").get("name", "")) == "Renew Region", "Renew Region resolves by id")
    var basin: Dictionary = catalog.get_region_by_id("iron_basin")
    check(str(basin.get("name", "")) == "Iron Basin", "Iron Basin resolves by id")
    check(catalog.get_region_by_id("nowhere").is_empty(), "Unknown region resolves empty")
    var locations: Array = basin.get("resource_locations", [])
    var iron_sites := 0
    for location in locations:
        if location is Dictionary and str(location.get("resource", "")) == "iron":
            iron_sites += 1
    check(iron_sites >= 1, "Basin geography is iron-rich")
    check(catalog.get_resource_location("technology_hub").get("resource", "") == "electronics", "Tech hub yields canonical electronics")

    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    catalog._ensure_region_state()
    var districts: Dictionary = state.get_value("regions", "districts", {})
    check(districts.has("renew_region") and districts.has("iron_basin"), "Both regions persist in GameState")
    check(not bool(districts.get("iron_basin", {}).get("chartered", true)), "Basin starts unchartered")
    var sites: Dictionary = state.get_value("supply_chain", "resource_sites", {})
    check(not sites.has("deep_iron_seam"), "Basin sites stay locked before charter")

    var poor: Dictionary = catalog.charter_basin(5)
    check(not bool(poor.get("ok", false)), "Charter requires 30 reputation")
    check(not catalog.is_basin_chartered(), "Failed reputation gate changes nothing")

    _set_finance_cash(finance, 1)
    var unaffordable: Dictionary = catalog.charter_basin(40)
    check(not bool(unaffordable.get("ok", false)), "Charter fails without capital")
    check(not catalog.is_basin_chartered(), "Failed payment does not unlock the basin")
    check(not state.get_value("supply_chain", "resource_sites", {}).has("deep_iron_seam"), "Failed payment does not create basin resources")

    _set_finance_cash(finance, 50000)
    var before_basin := int(finance.available_cash())
    var chartered: Dictionary = catalog.charter_basin(40)
    check(bool(chartered.get("ok", false)), "Charter succeeds at standing and capital")
    check(int(chartered.get("cost", 0)) == 15000, "Charter names its price")
    check(int(finance.available_cash()) == before_basin - 15000, "Basin charter debits authoritative finance exactly once")
    check(catalog.is_basin_chartered(), "Charter unlocks the basin")
    var unlocked_sites: Dictionary = state.get_value("supply_chain", "resource_sites", {})
    check(bool(unlocked_sites.has("deep_iron_seam")), "Charter opens basin resource sites")
    check(int(unlocked_sites.get("deep_iron_seam", {}).get("capacity", 0)) == 160, "Deep seam capacity persists")
    var repeat_cash := int(finance.available_cash())
    var repeat: Dictionary = catalog.charter_basin(99)
    check(not bool(repeat.get("ok", false)), "Charter is single-use")
    check(int(finance.available_cash()) == repeat_cash, "Repeated charter does not charge again")

    var before_valley := int(finance.available_cash())
    var valley: Dictionary = catalog.charter_valley(60)
    check(bool(valley.get("ok", false)), "Energy Valley can be chartered at sufficient reputation and capital")
    check(int(finance.available_cash()) == before_valley - 25000, "Energy Valley charter debits authoritative finance exactly once")
    check(state.get_value("supply_chain", "resource_sites", {}).has("geothermal_vent"), "Energy Valley payment opens geothermal resources")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for region commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        for method in ["next_region", "previous_region", "establish_region", "upgrade_regional_infrastructure", "establish_trade_route", "dispatch_goods", "charter_basin"]:
            check(game.has_method(method), "Main exposes %s" % method)
        var controller = game.get_node_or_null("World/RegionController")
        check(controller != null, "Region controller is scene-owned")
        game.next_region()
        game.previous_region()
        check(game.message != "", "Region selection reports through commands")
        game.free()
        await process_frame
    catalog.queue_free()
    await process_frame
    print("V15 REGIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
