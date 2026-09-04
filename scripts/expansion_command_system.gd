extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Expansion = preload("res://scripts/expansion.gd")
const Districts = preload("res://scripts/districts.gd")

var state_adapter = DomainSystem.new()
var expansion = Expansion.new()
var districts = Districts.new()

func _ready() -> void:
    add_child(state_adapter)

func initialize() -> void:
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    expansion.unlock_from_reputation(reputation)
    districts.update_unlocks(reputation)

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

func buy_expansion() -> void:
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    expansion.unlock_from_reputation(reputation)
    var selected: Variant = int(state_adapter.get_value("branches", "selected_expansion", 0))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    var result = expansion.buy(selected, cash)
    if not result["ok"]: state_adapter.message(result["message"]); return
    var spend:=state_adapter.spend(int(result["cost"]),"expansion purchase")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Insufficient cash."))); return
    state_adapter.set_value("player", "reputation", reputation + int(result.get("rep", 0)))
    state_adapter.log_message("EXPANSION: %s (-$%s)." % [result.get("name", "Asset"), state_adapter.money(int(result["cost"]))])
    state_adapter.message(result["message"])

func upgrade_expansion() -> void:
    var selected: Variant = int(state_adapter.get_value("branches", "selected_expansion", 0))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    var result = expansion.upgrade(selected, cash)
    if not result["ok"]: state_adapter.message(result["message"]); return
    var spend:=state_adapter.spend(int(result["cost"]),"expansion upgrade")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Insufficient cash."))); return
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + int(result.get("rep", 0)))
    state_adapter.log_message("EMPIRE UPGRADE: %s." % result.get("name", "Asset"))
    state_adapter.message(result["message"])