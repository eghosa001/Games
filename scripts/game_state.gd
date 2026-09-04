extends Node

## Canonical persistent state boundary. New saves contain only schema_version and domains.
## Legacy flat state is accepted by restore() only to migrate older save files.
const SCHEMA_VERSION := 8
const STATE_VERSION := 17
const DOMAINS := ["player","company","properties","businesses","branches","employees","economy","resources","production","supply_chain","contracts","competitors","ownership","finance","alliances","diplomacy","regions","infrastructure","technology","events","progression","history","news","analytics"]
const DOMAIN_KEYS := {"player":["day","reputation"],"company":["message","log_lines"],"properties":["owned","inspected","restoration","stage","selected_property","catalog"],"businesses":["business_open","business_id","business_name","business_type","business_purpose","industry_id","origin_property_id","origin_property_name","origin_property_type","capacity_level","marketing_level","player_price"],"branches":["selected_expansion","expansion"],"employees":["roster","employee_system"],"economy":["cash","last_sales","last_profit","total_profit"],"resources":["resources"],"production":["finished_goods","system"],"supply_chain":["supplier_choice","transport_level","transport_capacity","resource_sites","transport_cost_multiplier","resource_delivery_multiplier"],"contracts":["contract_days","contract_bonus","contract_system","system"],"competitors":["rivals","selected_rival","relationship"],"ownership":["acquisition_count"],"finance":["debt","loan_payment","system"],"alliances":["alliances"],"diplomacy":["diplomacy"],"regions":["selected_district","districts","regional_reputation"],"infrastructure":["management_level","management_overhead"],"technology":["technology","research_points"],"events":["history","active","modifiers","seasonal"],"progression":["milestones","unlocks","xp","level"],"history":["history_system"],"news":["news_system"],"analytics":["simulation_system"]}
const DEFAULT_DOMAINS := {"player":{"day":1,"reputation":0},"company":{"message":"Inspect the abandoned warehouse. Your empire starts here.","log_lines":[]},"properties":{"owned":false,"inspected":false,"restoration":0,"stage":"Neglected","selected_property":0,"catalog":[]},"businesses":{"business_open":false,"business_id":"","business_name":"","business_type":"","business_purpose":"","industry_id":"","origin_property_id":"","origin_property_name":"","origin_property_type":"","capacity_level":1,"marketing_level":0,"player_price":110},"branches":{"selected_expansion":0,"expansion":{}},"employees":{"roster":[],"employee_system":{}},"economy":{"cash":30000,"last_sales":0,"last_profit":0,"total_profit":0},"resources":{"resources":{}},"production":{"finished_goods":0,"system":{}},"supply_chain":{"supplier_choice":0,"transport_level":1,"transport_capacity":40,"resource_sites":{},"transport_cost_multiplier":1.0,"resource_delivery_multiplier":1.0},"contracts":{"contract_days":0,"contract_bonus":0,"contract_system":{},"system":{}},"competitors":{"rivals":[],"selected_rival":0,"relationship":15},"ownership":{"acquisition_count":0},"finance":{"debt":0,"loan_payment":0,"system":{}},"alliances":{"alliances":{}},"diplomacy":{"diplomacy":{}},"regions":{"selected_district":0,"districts":{"renew_region":{"id":"renew_region","name":"Renew Region","cities":[],"resource_locations":[]}},"regional_reputation":0},"infrastructure":{"management_level":0,"management_overhead":0},"technology":{"technology":{},"research_points":20},"events":{"history":[],"active":{},"modifiers":{},"seasonal":{}},"progression":{"milestones":[],"unlocks":[],"xp":0,"level":1},"history":{"history_system":{}},"news":{"news_system":{}},"analytics":{"simulation_system":{}}}
var domains:Dictionary={}
var data:Dictionary={}

func _ready()->void:_ensure_defaults()
func _ensure_domains()->void:
    for domain in DOMAINS:
        if not domains.has(domain) or not (domains[domain] is Dictionary):domains[domain]={}
func _ensure_defaults()->void:
    _ensure_domains()
    for domain in DOMAINS:
        var defaults:Dictionary=DEFAULT_DOMAINS.get(domain,{})
        var bucket:Dictionary=domains[domain]
        for key in defaults.keys():
            if not bucket.has(key):bucket[key]=defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
        domains[domain]=bucket
    _capture_domain_systems()
    _rebuild_data()
func capture(_legacy_input:Dictionary={})->Dictionary:
    _ensure_defaults();_capture_domain_systems()
    data={"schema_version":SCHEMA_VERSION,"domains":domains.duplicate(true)}
    return data.duplicate(true)
func restore(snapshot:Dictionary)->Dictionary:
    _ensure_domains()
    var incoming:Dictionary={}
    if snapshot.get("domains",null) is Dictionary:
        incoming=snapshot["domains"].duplicate(true)
    else:
        incoming=_migrate_legacy_flat(snapshot)
    for domain in DOMAINS:
        if incoming.has(domain) and incoming[domain] is Dictionary:domains[domain]=incoming[domain].duplicate(true)
    _ensure_defaults();_restore_domain_systems();_rebuild_data()
    return _domains_to_flat()
func restore_state_compat(snapshot:Dictionary)->Dictionary:return restore(snapshot)
func get_domain(domain:String)->Dictionary:_ensure_domains();return domains.get(domain,{}).duplicate(true)
func set_domain(domain:String,value:Dictionary)->void:
    if not DOMAINS.has(domain):return
    domains[domain]=value.duplicate(true);_rebuild_data()
func get_value(domain:String,key:String,default_value=null):_ensure_domains();return domains.get(domain,{}).get(key,default_value)
func set_value(domain:String,key:String,value)->void:
    if not DOMAINS.has(domain) or not DOMAIN_KEYS.get(domain,[]).has(key):return
    var bucket:Dictionary=domains[domain];bucket[key]=value;domains[domain]=bucket;_rebuild_data()
func has_state()->bool:return not domains.is_empty()
func get_flat_state()->Dictionary:return _domains_to_flat()
func clear()->void:domains.clear();data.clear();_ensure_defaults()
func _migrate_legacy_flat(flat:Dictionary)->Dictionary:
    var incoming:Dictionary=flat.duplicate(true)
    if incoming.has("game_state") and incoming["game_state"] is Dictionary and incoming["game_state"].has("domains"):
        return incoming["game_state"]["domains"].duplicate(true)
    var result:Dictionary={}
    for domain in DOMAINS:result[domain]={}
    var mappings={"player":["day","reputation"],"company":["message","log_lines"],"properties":["owned","inspected","restoration","stage","selected_property","catalog"],"businesses":["business_open","business_id","business_name","business_type","business_purpose","industry_id","origin_property_id","origin_property_name","origin_property_type","capacity_level","marketing_level","player_price"],"branches":["selected_expansion","expansion"],"employees":["roster","employee_system"],"economy":["cash","last_sales","last_profit","total_profit"],"resources":["resources"],"production":["finished_goods","system"],"supply_chain":["supplier_choice","transport_level","transport_capacity","resource_sites","transport_cost_multiplier","resource_delivery_multiplier"],"contracts":["contract_days","contract_bonus","contract_system","system"],"competitors":["rivals","selected_rival","relationship"],"ownership":["acquisition_count"],"finance":["debt","loan_payment","system"],"alliances":["alliances"],"diplomacy":["diplomacy"],"regions":["selected_district","districts","regional_reputation"],"infrastructure":["management_level","management_overhead"],"technology":["technology","research_points"],"events":["history","active","modifiers","seasonal"],"progression":["milestones","unlocks","xp","level"]}
    for domain in mappings:
        for key in mappings[domain]:
            if incoming.has(key):result[domain][key]=incoming[key]
    if incoming.has("history_system"):result["history"]["history_system"]=incoming["history_system"]
    if incoming.has("news_system"):result["news"]["news_system"]=incoming["news_system"]
    return result
func _domains_to_flat()->Dictionary:
    var result:Dictionary={}
    for domain in domains:
        var bucket=domains[domain]
        if bucket is Dictionary:
            for key in bucket:
                if DOMAIN_KEYS.get(domain,[]).has(str(key)):result[key]=bucket[key]
    result["state_version"]=STATE_VERSION;return result
func _capture_domain_systems()->void:
    var root:=get_tree().root
    var history=root.get_node_or_null("RenewHistorySystem");if history!=null and history.has_method("capture_state"):domains["history"]["history_system"]=history.capture_state()
    var news=root.get_node_or_null("RenewNewsSystem");if news!=null and news.has_method("capture_state"):domains["news"]["news_system"]=news.capture_state()
    var finance=root.get_node_or_null("RenewFinanceSystem");if finance!=null and finance.has_method("capture_state"):domains["finance"]["system"]=finance.capture_state()
    var production=root.get_node_or_null("RenewProductionSystem");if production!=null and production.has_method("capture_state"):domains["production"]["system"]=production.capture_state()
    var simulation=root.get_node_or_null("RenewSimulationSystem");if simulation!=null and simulation.has_method("capture_state"):domains["analytics"]["simulation_system"]=simulation.capture_state()
    var contracts=root.get_node_or_null("RenewContractSystem");if contracts!=null and contracts.has_method("capture_state"):domains["contracts"]["system"]=contracts.capture_state()
func _restore_domain_systems()->void:
    var root:=get_tree().root
    var history=root.get_node_or_null("RenewHistorySystem");if history!=null and history.has_method("restore_state") and domains["history"].get("history_system",{}) is Dictionary:history.restore_state(domains["history"]["history_system"])
    var news=root.get_node_or_null("RenewNewsSystem");if news!=null and news.has_method("restore_state") and domains["news"].get("news_system",{}) is Dictionary:news.restore_state(domains["news"]["news_system"])
    var finance=root.get_node_or_null("RenewFinanceSystem");if finance!=null and finance.has_method("restore_state") and domains["finance"].get("system",{}) is Dictionary:finance.restore_state(domains["finance"]["system"])
    var production=root.get_node_or_null("RenewProductionSystem");if production!=null and production.has_method("restore_state") and domains["production"].get("system") is Dictionary:production.restore_state(domains["production"]["system"])
    var simulation=root.get_node_or_null("RenewSimulationSystem");if simulation!=null and simulation.has_method("restore_state") and domains["analytics"].get("simulation_system",{}) is Dictionary:simulation.restore_state(domains["analytics"]["simulation_system"])
    var contracts=root.get_node_or_null("RenewContractSystem");if contracts!=null and contracts.has_method("restore_state") and domains["contracts"].get("system",{}) is Dictionary:contracts.restore_state(domains["contracts"]["system"])
func _rebuild_data()->void:data={"schema_version":SCHEMA_VERSION,"domains":domains.duplicate(true)}
