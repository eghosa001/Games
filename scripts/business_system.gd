extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Production = preload("res://scripts/production.gd")

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var production = Production.new()

func _ready() -> void:
    add_child(state_adapter)

func open_business() -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":
        state_adapter.message("Finish restoration first."); return
    if bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("RENEW Goods is already open."); return
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < 3000:
        state_adapter.message("Need $3,000 working capital."); return
    state_adapter.set_value("economy", "cash", cash - 3000)
    state_adapter.set_value("businesses", "business_open", true)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.message("RENEW Goods is open. Build inventory, win customers and reinvest.")
    state_adapter.log_message("OPENED: RENEW Goods with 3 employees.")

func upgrade_business() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var level := int(state_adapter.get_value("businesses", "capacity_level", 1))
    var cost := 4500 * level
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Capacity upgrade requires $%s." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("businesses", "capacity_level", level + 1)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("UPGRADE: RENEW Goods capacity level %d." % (level + 1))
    state_adapter.message("Production capacity upgraded to level %d." % (level + 1))

func marketing_campaign() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var level := int(state_adapter.get_value("businesses", "marketing_level", 0))
    var cost := 1800 + level * 700
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Marketing requires $%s." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("businesses", "marketing_level", level + 1)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("MARKETING: campaign %d launched (-$%s)." % [level + 1, state_adapter.money(cost)])
    state_adapter.message("Brand strength increased.")

func change_price() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var price := int(state_adapter.get_value("businesses", "player_price", 110)) + 10
    if price > 160: price = 80
    state_adapter.set_value("businesses", "player_price", price)
    state_adapter.message("Selling price is now $%s." % state_adapter.money(price))

func produce_goods() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var employee_count := int(state_adapter.get_value("employees", "employees", 3))
    var capacity := int(state_adapter.get_value("businesses", "capacity_level", 1))
    var result = production.produce(economy, employee_count + capacity - 1)
    if not result["ok"]:
        state_adapter.message("Production stopped: inputs are too low."); return
    state_adapter.set_value("production", "finished_goods", int(result["finished_goods"] if result.has("finished_goods") else production.finished_goods))
    state_adapter.message("Produced %d goods at quality %d." % [result["output"], result["quality"]])
    state_adapter.log_message("PRODUCTION: %d goods; quality %d." % [result["output"], result["quality"]])
