extends Node
## RENEW service registry. Domain systems are ordinary scene Nodes under Systems;
## only ten infrastructure services remain true autoloads.

var _services: Dictionary = {}

const SERVICE_PATHS := {
    "RenewAutosave": "res://scripts/autosave.gd",
    "RenewUIRegionCoordinator": "res://scripts/ui_region_coordinator.gd",
    "RenewIdentitySystem": "res://scripts/identity_system.gd",
    "RenewReputationSystem": "res://scripts/reputation_system.gd",
    "RenewAllianceControl": "res://scripts/alliance_control_system.gd",
    "RenewDiplomacySystem": "res://scripts/diplomacy_system.gd",
    "RenewDiplomacyAI": "res://scripts/diplomacy_ai.gd",
    "RenewDiplomacyEffects": "res://scripts/diplomacy_effects.gd",
    "RenewDiplomacyControl": "res://scripts/diplomacy_control_bridge.gd",
    "RenewInfrastructureSystem": "res://scripts/infrastructure_system.gd",
    "RenewCollectionSystem": "res://scripts/collection_system.gd",
    "RenewLiveOpsSystem": "res://scripts/liveops_system.gd",
    "RenewHeadquartersSystem": "res://scripts/headquarters_system.gd",
    "RenewCorporateLegacy": "res://scripts/corporate_legacy_system.gd",
    "RenewEmployeeSystem": "res://scripts/employee_system.gd",
    "RenewCompanyCultureSystem": "res://scripts/company_culture_system.gd",
    "RenewGlobalRankingSystem": "res://scripts/global_ranking_system.gd",
    "RenewWorldEventSystem": "res://scripts/world_event_system.gd",
    "RenewAnalyticsSystem": "res://scripts/analytics_system.gd",
    "RenewCompetitorStateBridge": "res://scripts/competitor_state_bridge.gd",
    "RenewCompetitorReactionSystem": "res://scripts/competitor_reaction_system.gd",
    "RenewTechnologySystem": "res://scripts/technology_system.gd",
    "RenewResearchSystem": "res://scripts/research_system.gd",
    "RenewProgressionSystem": "res://scripts/progression_system.gd",
    "RenewRegionSystem": "res://scripts/region_system.gd",
    "RenewDynamicEventController": "res://scripts/dynamic_event_controller.gd",
    "RenewSeasonalRestorationSystem": "res://scripts/seasonal_restoration_system.gd",
    "RenewHistorySystem": "res://scripts/history_system.gd",
    "RenewHistoryEventBridge": "res://scripts/history_event_bridge.gd",
    "RenewNewsSystem": "res://scripts/news_system.gd",
    "RenewAmbientAudio": "res://scripts/ambient_audio.gd",
    "RenewUIScreenManager": "res://scripts/ui_screen_manager.gd"
}

func _ready() -> void:
    call_deferred("_boot_services")

func _boot_services() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var systems := scene.get_node_or_null("Systems")
    if systems == null:
        systems = Node.new()
        systems.name = "Systems"
        scene.add_child(systems)
    for service_name in SERVICE_PATHS.keys():
        var existing := systems.get_node_or_null(service_name)
        if existing != null:
            _services[service_name] = existing
            continue
        var path: String = SERVICE_PATHS[service_name]
        if not ResourceLoader.exists(path):
            push_warning("RENEW service script missing: %s" % path)
            continue
        var node := Node.new()
        node.name = service_name
        node.set_script(load(path))
        systems.add_child(node)
        _services[service_name] = node

func get_service(service_name: String) -> Node:
    var node: Node = _services.get(service_name)
    if node != null and is_instance_valid(node):
        return node
    var scene := get_tree().current_scene
    if scene != null:
        node = scene.get_node_or_null("Systems/" + service_name)
        if node != null:
            _services[service_name] = node
            return node
    return null
