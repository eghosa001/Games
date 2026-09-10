extends Node
## RENEW service registry. Domain systems are ordinary scene Nodes under Systems;
## only infrastructure services remain true autoloads.

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
    "RenewAmbientAudio": "res://scripts/ambient_audio.gd"
}

func _ready() -> void:
    call_deferred("_boot_services")

func _scene_root() -> Node:
    var tree := get_tree()
    if tree == null:
        return null
    var scene := tree.current_scene
    if scene != null:
        return scene
    # Headless/integration runners may attach Main directly to the SceneTree
    # instead of assigning current_scene. Production lookups should remain
    # resilient to that lifecycle ordering as well.
    return tree.root.get_node_or_null("Renew")

func _systems_root(create_if_missing: bool = false) -> Node:
    var scene := _scene_root()
    if scene == null:
        return null
    var systems := scene.get_node_or_null("Systems")
    if systems == null and create_if_missing:
        systems = Node.new()
        systems.name = "Systems"
        scene.add_child(systems)
    return systems

func _create_service(service_name: String, systems: Node) -> Node:
    if systems == null or not SERVICE_PATHS.has(service_name):
        return null
    var existing := systems.get_node_or_null(service_name)
    if existing != null:
        _services[service_name] = existing
        return existing
    var path: String = SERVICE_PATHS[service_name]
    if not ResourceLoader.exists(path):
        push_warning("RENEW service script missing: %s" % path)
        return null
    var node := Node.new()
    node.name = service_name
    node.set_script(load(path))
    systems.add_child(node)
    _services[service_name] = node
    return node

func _boot_services() -> void:
    var systems := _systems_root(true)
    if systems == null:
        return
    for service_name in SERVICE_PATHS.keys():
        _create_service(service_name, systems)

func get_service(service_name: String) -> Node:
    # Keep cached values untyped until validity is checked: assigning a freed
    # Object directly into a typed Node local raises before is_instance_valid()
    # can run. Scene replacement in tests and normal game restarts can free the
    # old Systems tree while this infrastructure autoload stays alive.
    var cached = _services.get(service_name)
    if is_instance_valid(cached):
        return cached as Node
    if _services.has(service_name):
        _services.erase(service_name)

    var systems := _systems_root(false)
    if systems != null:
        var node := systems.get_node_or_null(service_name)
        if node != null:
            _services[service_name] = node
            return node

    # If the initial deferred boot ran before Main existed, or a prior Main was
    # freed, recover lazily on first lookup rather than leaving domain services
    # unavailable for the lifetime of the process.
    systems = _systems_root(true)
    return _create_service(service_name, systems)