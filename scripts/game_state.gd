extends Node

## Canonical persistent state boundary. V1+ authoritative.
const SCHEMA_VERSION := 8
const STATE_VERSION := 17
const DOMAINS := ["player","company","properties","businesses","branches","employees","economy","resources","production","supply_chain","contracts","competitors","ownership","finance","alliances","diplomacy","regions","infrastructure","technology","events","progression","history","news","analytics","acquisition","bankruptcy"]
const DOMAIN_KEYS := {"player":["day","reputation"],"company":["message","log_lines"],"properties":["owned","inspected","restoration","stage","selected_property","catalog"],"businesses":["business_open","business_id","business_name","business_type","business_purpose","industry_id","origin_property_id","origin_property_name","origin_property_type","capacity_level","marketing_level","player_price"],"branches":["selected_expansion","expansion"],"employees":["roster","employee_system"],"economy":["cash","last_sales","last_profit","total_profit"],"resources":["resources"],"production":["finished_goods","system"],"supply_chain":["supplier_choice","transport_level","transport_capacity","resource_sites","transport_cost_multiplier","resource_delivery_multiplier"],"contracts":["contract_days","contract_bonus","contract_system","system"],"competitors":["rivals","selected_rival","relationship","reaction_system"],"ownership":["acquisition_count","valuation","takeover_wins"],"finance":["debt","loan_payment","system"],"alliances":["alliances"],"diplomacy":["diplomacy"],"regions":["selected_district","districts","regional_reputation"],"infrastructure":["management_level","management_overhead"],"technology":["technology","research_points"],"events":["history","active","modifiers","seasonal","market_director"],"progression":["milestones","unlocks","xp","level","claimed_goals"],"history":["history_system"],"news":["news_system"],"analytics":["simulation_system"],"acquisition":["system"],"bankruptcy":["system"]}
const DEFAULT_DOMAINS := {"player":{"day":1,"reputation":0},"company":{"message":"Inspect the abandoned warehouse. Your empire starts here.","log_lines":[]},"properties":{"owned":false,"inspected":false,"restoration":0,"stage":"Neglected","selected_property":0,"catalog":[]},"businesses":{"business_open":false,"business_id":"","business_name":"","business_type":"","business_purpose":"","industry_id":"","origin_property_id":"","origin_property_name":"","origin_property_type":"","capacity_level":1,"marketing_level":0,"player_price":110},"branches":{"selected_expansion":0,"expansion":{}},"employees":{"roster":[],"employee_system":{}},"economy":{"cash":35000,"last_sales":0,"last_profit":0,"total_profit":0},"resources":{"resources":{}},"production":{"finished_goods":0,"system":{}},"supply_chain":{"supplier_choice":0,"transport_level":1,"transport_capacity":40,"resource_sites":{},"transport_cost_multiplier":1.0,"resource_delivery_multiplier":1.0},"contracts":{"contract_days":0,"contract_bonus":0,"contract_system":{},"system":{}},"competitors":{"rivals":[],"selected_rival":0,"relationship":15,"reaction_system":{}},"ownership":{"acquisition_count":0,"valuation":25000,"takeover_wins":0},"finance":{"debt":0,"loan_payment":0,"system":{}},"alliances":{"alliances":{}},"diplomacy":{"diplomacy":{}},"regions":{"selected_district":0,"districts":{"renew_region":{"id":"renew_region","name":"Renew Region","cities":[],"resource_locations":[]}},"regional_reputation":0},"infrastructure":{"management_level":0,"management_overhead":0},"technology":{"technology":{},"research_points":20},"events":{"history":[],"active":{},"modifiers":{},"seasonal":{},"market_director":{}},"progression":{"milestones":[],"unlocks":[],"xp":0,"level":1,"claimed_goals":{}},"history":{"history_system":{}},"news":{"news_system":{}},"analytics":{"simulation_system":{}},"acquisition":{"system":{}},"bankruptcy":{"system":{}}}

var domains: Dictionary = {}
var data: Dictionary = {}

func _ready() -> void:
    _ensure_defaults()

func _ensure_defaults() -> void:
    for domain in DOMAINS:
        if not domains.has(domain): domains[domain] = {}
    for domain in DOMAINS:
        var d: Dictionary = domains[domain]
        var defaults: Dictionary = DEFAULT_DOMAINS.get(domain, {})
        for key in defaults:
            if not d.has(key):
                var value = defaults[key]
                d[key] = value.duplicate(true) if value is Dictionary or value is Array else value
        domains[domain] = d

func get_domain(domain: String) -> Dictionary:
    return domains.get(domain, {}).duplicate(true)
func set_domain(domain: String, value: Dictionary) -> void:
    if DOMAINS.has(domain): domains[domain] = value.duplicate(true)
func get_value(domain: String, key: String, default_value = null):
    return domains.get(domain, {}).get(key, default_value)
func set_value(domain: String, key: String, value) -> void:
    if DOMAINS.has(domain):
        var d: Dictionary = domains[domain]; d[key] = value; domains[domain] = d

func capture() -> Dictionary:
    _capture_domain_systems()
    return {"schema_version": SCHEMA_VERSION, "domains": domains.duplicate(true)}

func restore(snapshot: Dictionary) -> bool:
    if snapshot.is_empty() or not snapshot.has("schema_version"): return false
    var version := int(snapshot["schema_version"])
    if version < 1 or version > SCHEMA_VERSION: return false
    if snapshot.has("domains") and snapshot["domains"] is Dictionary:
        domains = snapshot["domains"].duplicate(true); _ensure_defaults(); _restore_domain_systems(); return true
    return false

func _find_system(root_name: String, scene_path: String) -> Node:
    var root := get_tree().root
    var node := root.get_node_or_null(root_name)
    if node != null: return node
    var scene := get_tree().current_scene
    if scene != null:
        node = scene.get_node_or_null(scene_path)
        if node != null: return node
    return null

func _capture_domain_systems() -> void:
    var history := _find_system("RenewHistorySystem", "Systems/HistorySystem")
    if history and history.has_method("capture_state"): domains["history"]["history_system"] = history.capture_state()
    var news := _find_system("RenewNewsSystem", "Systems/NewsSystem")
    if news and news.has_method("capture_state"): domains["news"]["news_system"] = news.capture_state()
    var finance := _find_system("RenewFinanceSystem", "Systems/FinanceSystem")
    if finance and finance.has_method("capture_state"): domains["finance"]["system"] = finance.capture_state()
    var production := _find_system("RenewProductionSystem", "Systems/ProductionSystem")
    if production and production.has_method("capture_state"): domains["production"]["system"] = production.capture_state()
    var simulation := _find_system("RenewSimulationSystem", "Systems/SimulationSystem")
    if simulation and simulation.has_method("capture_state"): domains["analytics"]["simulation_system"] = simulation.capture_state()
    var contracts := _find_system("RenewContractSystem", "Systems/ContractSystem")
    if contracts and contracts.has_method("capture_state"): domains["contracts"]["system"] = contracts.capture_state()
    var acquisition := _find_system("RenewAcquisitionSystem", "Systems/AcquisitionSystem")
    if acquisition and acquisition.has_method("capture_state"): domains["acquisition"]["system"] = acquisition.capture_state()
    var bankruptcy := _find_system("RenewBankruptcySystem", "Systems/BankruptcySystem")
    if bankruptcy and bankruptcy.has_method("capture_state"): domains["bankruptcy"]["system"] = bankruptcy.capture_state()
    var infra := _find_system("RenewInfrastructureSystem", "Systems/InfrastructureSystem")
    if infra and infra.has_method("capture_state"): domains["infrastructure"]["system"] = infra.capture_state()
    var diplomacy := _find_system("RenewDiplomacySystem", "Systems/DiplomacySystem")
    if diplomacy and diplomacy.has_method("capture_state"): domains["diplomacy"]["system"] = diplomacy.capture_state()
    var reactions := _find_system("RenewCompetitorReactionSystem", "Systems/CompetitorReactionSystem")
    if reactions and reactions.has_method("capture_state"): domains["competitors"]["reaction_system"] = reactions.capture_state()

func _restore_domain_systems() -> void:
    var history := _find_system("RenewHistorySystem", "Systems/HistorySystem")
    if history and history.has_method("restore_state") and domains["history"].has("history_system"): history.restore_state(domains["history"]["history_system"])
    var news := _find_system("RenewNewsSystem", "Systems/NewsSystem")
    if news and news.has_method("restore_state") and domains["news"].has("news_system"): news.restore_state(domains["news"]["news_system"])
    var finance := _find_system("RenewFinanceSystem", "Systems/FinanceSystem")
    if finance and finance.has_method("restore_state") and domains["finance"].has("system"): finance.restore_state(domains["finance"]["system"])
    var production := _find_system("RenewProductionSystem", "Systems/ProductionSystem")
    if production and production.has_method("restore_state") and domains["production"].has("system"): production.restore_state(domains["production"]["system"])
    var simulation := _find_system("RenewSimulationSystem", "Systems/SimulationSystem")
    if simulation and simulation.has_method("restore_state") and domains["analytics"].has("simulation_system"): simulation.restore_state(domains["analytics"]["simulation_system"])
    var contracts := _find_system("RenewContractSystem", "Systems/ContractSystem")
    if contracts and contracts.has_method("restore_state") and domains["contracts"].has("system"): contracts.restore_state(domains["contracts"]["system"])
    var acquisition := _find_system("RenewAcquisitionSystem", "Systems/AcquisitionSystem")
    if acquisition and acquisition.has_method("restore_state") and domains["acquisition"].has("system"): acquisition.restore_state(domains["acquisition"]["system"])
    var bankruptcy := _find_system("RenewBankruptcySystem", "Systems/BankruptcySystem")
    if bankruptcy and bankruptcy.has_method("restore_state") and domains["bankruptcy"].has("system"): bankruptcy.restore_state(domains["bankruptcy"]["system"])
    var infra := _find_system("RenewInfrastructureSystem", "Systems/InfrastructureSystem")
    if infra and infra.has_method("restore_state") and domains["infrastructure"].has("system"): infra.restore_state(domains["infrastructure"]["system"])
    var diplomacy := _find_system("RenewDiplomacySystem", "Systems/DiplomacySystem")
    if diplomacy and diplomacy.has_method("restore_state") and domains["diplomacy"].has("system"): diplomacy.restore_state(domains["diplomacy"]["system"])
    var reactions := _find_system("RenewCompetitorReactionSystem", "Systems/CompetitorReactionSystem")
    if reactions and reactions.has_method("restore_state") and domains["competitors"].has("reaction_system"): reactions.restore_state(domains["competitors"]["reaction_system"])

func clear() -> void:
    domains.clear(); _ensure_defaults()
