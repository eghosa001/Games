extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")

var state_adapter = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func sign_contract() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open a business before signing contracts."); return
    if int(state_adapter.get_value("contracts", "contract_days", 0)) > 0:
        state_adapter.message("An active customer contract is already running."); return
    var reputation := int(state_adapter.get_value("player", "reputation", 0))
    if reputation < 10:
        state_adapter.message("Major customers need at least 10 reputation."); return
    state_adapter.set_value("contracts", "contract_days", 5)
    state_adapter.set_value("contracts", "contract_bonus", 900 + reputation * 20)
    state_adapter.set_value("player", "reputation", reputation + 2)
    state_adapter.log_message("CONTRACT: customer supply agreement requested.")
    state_adapter.message("Contract requested. The SimulationSystem will execute its deliveries.")
