extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Expansion = preload("res://scripts/expansion.gd")
const Districts = preload("res://scripts/districts.gd")

var state_adapter = DomainSystem.new()
var expansion = Expansion.new()
var districts = Districts.new()

func _ready() -> void:
    # Node helpers must have an owner so they are released with this controller.
    # Districts is intentionally RefCounted and must not be added to the tree.
    if state_adapter is Node and (state_adapter as Node).get_parent() == null:
        add_child(state_adapter)
    if expansion is Node and (expansion as Node).get_parent() == null:
        add_child(expansion)

func initialize() -> void:
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    expansion.unlock_from_reputation(reputation)
    districts.update_unlocks(reputation)

func capture_state() -> Dictionary:
    return {
        "system_version": 1,
        "properties": expansion.properties.duplicate(true),
        "resource_sites": expansion.resource_sites.duplicate(true),
        "day": expansion.day,
        "cash": expansion.cash,
        "reputation": expansion.reputation,
        "population": expansion.population,
        "restored_count": expansion.restored_count,
        "management_level": expansion.management_level,
        "management_overhead": expansion.management_overhead,
        "selected_index": expansion.selected_index
    }

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    if snapshot.get("properties") is Array: expansion.properties = snapshot["properties"].duplicate(true)
    if snapshot.get("resource_sites") is Array: expansion.resource_sites = snapshot["resource_sites"].duplicate(true)
    expansion.day = int(snapshot.get("day", expansion.day))
    expansion.cash = int(snapshot.get("cash", expansion.cash))
    expansion.reputation = int(snapshot.get("reputation", expansion.reputation))
    expansion.population = int(snapshot.get("population", expansion.population))
    expansion.restored_count = int(snapshot.get("restored_count", expansion.restored_count))
    expansion.management_level = int(snapshot.get("management_level", expansion.management_level))
    expansion.management_overhead = int(snapshot.get("management_overhead", expansion.management_overhead))
    expansion.selected_index = int(snapshot.get("selected_index", expansion.selected_index))
    expansion._normalize_all()

func select_expansion(index: int) -> void:
    if index < 0 or index >= expansion.properties.size(): return
    state_adapter.set_value("branches", "selected_expansion", index)
    state_adapter.message("Selected expansion: %s." % expansion.properties[index]["name"])
    state_adapter.log_message("EXPANSION SELECTED: %s." % expansion.properties[index]["name"])

func select_district(index: int) -> void:
    var result = districts.select(index)
    state_adapter.message(result["message"])
    if result["ok"]:
        state_adapter.set_value("regions", "selected_district", index)
        state_adapter.log_message("DISTRICT: %s selected." % districts.current()["name"])

func management_capacity() -> Dictionary:
    var headquarters = state_adapter.service("RenewHeadquartersSystem", "Systems/RenewHeadquartersSystem")
    var office_capacity := 0
    if headquarters != null and headquarters.has_method("executive_capacity"):
        office_capacity = int(headquarters.executive_capacity())
    var executive_count := state_adapter.executive_seats().size()
    var capacity := 2 + office_capacity + executive_count * 2
    var used := 0
    for item in expansion.properties:
        if item is Dictionary and bool(item.get("owned", false)):
            used += 1
    for item in expansion.resource_sites:
        if item is Dictionary and bool(item.get("owned", false)):
            used += 1
    return {"capacity": capacity, "used": used, "executives": executive_count, "office_capacity": office_capacity, "ok": used < capacity}

func buy_expansion() -> void:
    var capacity_check := management_capacity()
    if not bool(capacity_check.get("ok", false)):
        state_adapter.message("Management is overstretched (%d/%d). Appoint executives or expand headquarters offices to manage more assets." % [int(capacity_check.get("used", 0)), int(capacity_check.get("capacity", 0))])
        return
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    expansion.unlock_from_reputation(reputation)
    var selected: Variant = int(state_adapter.get_value("branches", "selected_expansion", 0))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    var properties_before: Array = expansion.properties.duplicate(true)
    var restored_before: int = int(expansion.restored_count)
    var expansion_rep_before: int = int(expansion.reputation)
    var result = expansion.buy(selected, cash)
    if not result["ok"]: state_adapter.message(result["message"]); return
    var spend: Dictionary = state_adapter.spend(int(result["cost"]),"expansion purchase")
    if not bool(spend.get("ok",false)):
        expansion.properties = properties_before
        expansion.restored_count = restored_before
        expansion.reputation = expansion_rep_before
        state_adapter.message(str(spend.get("message","Insufficient cash.")))
        return
    state_adapter.set_value("player", "reputation", reputation + int(result.get("rep", 0)))
    state_adapter.log_message("EXPANSION: %s (-$%s)." % [result.get("name", "Asset"), state_adapter.money(int(result["cost"]))])
    state_adapter.message(result["message"])

func upgrade_expansion() -> void:
    var selected: Variant = int(state_adapter.get_value("branches", "selected_expansion", 0))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    var properties_before: Array = expansion.properties.duplicate(true)
    var management_before: int = int(expansion.management_level)
    var expansion_rep_before: int = int(expansion.reputation)
    var result = expansion.upgrade(selected, cash)
    if not result["ok"]: state_adapter.message(result["message"]); return
    var spend: Dictionary = state_adapter.spend(int(result["cost"]),"expansion upgrade")
    if not bool(spend.get("ok",false)):
        expansion.properties = properties_before
        expansion.management_level = management_before
        expansion.reputation = expansion_rep_before
        state_adapter.message(str(spend.get("message","Insufficient cash.")))
        return
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + int(result.get("rep", 0)))
    state_adapter.log_message("EMPIRE UPGRADE: %s." % result.get("name", "Asset"))
    state_adapter.message(result["message"])
