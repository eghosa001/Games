extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()
var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]

func _ready() -> void:
    add_child(state_adapter)

func inspect_property() -> void:
    state_adapter.set_value("properties", "inspected", true)
    state_adapter.message("Inspection complete: cheap entry, strong demand, moderate renovation risk.")
    state_adapter.log_message("INSPECTION: acquisition $5,000; restoration estimate $26,500.")

func acquire_property() -> void:
    if not bool(state_adapter.get_value("properties", "inspected", false)):
        state_adapter.message("Inspect the property first."); return
    if bool(state_adapter.get_value("properties", "owned", false)):
        state_adapter.message("You already own the warehouse."); return
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < 5000:
        state_adapter.message("Not enough cash."); return
    state_adapter.set_value("economy", "cash", cash - 5000)
    state_adapter.set_value("properties", "owned", true)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.message("Acquired Old Warehouse. Now restore it into an asset.")
    state_adapter.log_message("ACQUIRED: Old Warehouse for $5,000.")

func restore_property() -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)):
        state_adapter.message("Acquire the property first."); return
    var stage := str(state_adapter.get_value("properties", "stage", "Neglected"))
    if stage == "Operational":
        state_adapter.message("Restoration is complete."); return
    var idx := 0
    for i in range(stages.size()):
        if stages[i][0] == stage: idx = i + 1; break
    if idx >= stages.size(): return
    var cost: int = stages[idx][2]
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Need $%s for the next stage." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("properties", "restoration", stages[idx][1])
    state_adapter.set_value("properties", "stage", stages[idx][0])
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("RESTORATION: %s (-$%s)." % [stages[idx][0], state_adapter.money(cost)])
    if int(stages[idx][1]) >= 100:
        state_adapter.set_value("properties", "stage", "Operational")
        state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 8)
        state_adapter.message("RESTORATION COMPLETE. Your neglected property is now productive capital.")
        state_adapter.log_message("The district noticed the transformation.")
    else:
        state_adapter.message("%s complete. The building is visibly improving." % stages[idx][0])
