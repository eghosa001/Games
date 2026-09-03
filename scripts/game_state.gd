extends Node

## Canonical simulation-state boundary.
## Domain systems own runtime behaviour; this node owns the persistent gameplay
## state envelope and system snapshots. Scene controllers must not keep a second
## authoritative copy of gameplay state.
const STATE_VERSION := 4
const DOMAINS := [
    "player", "company", "properties", "businesses", "branches", "employees",
    "economy", "resources", "production", "supply_chain", "contracts",
    "competitors", "ownership", "finance", "alliances", "diplomacy", "regions",
    "infrastructure", "technology", "events", "progression", "history", "news", "analytics"
]

const DEFAULT_STATE := {
    "reputation": 0,
    "day": 1,
    "message": "Inspect the abandoned warehouse. Your empire starts here.",
    "cash": 25000,
    "debt": 0,
    "loan_payment": 0,
    "owned": false,
    "inspected": false,
    "restoration": 0,
    "stage": "Neglected",
    "business_open": false,
    "employees": 3,
    "capacity_level": 1,
    "marketing_level": 0,
    "player_price": 110,
    "finished_goods": 0,
    "last_sales": 0,
    "last_profit": 0,
    "total_profit": 0,
    "relationship": 15,
    "selected_rival": 0,
    "selected_expansion": 0,
    "supplier_choice": 0,
    "contract_days": 0,
    "contract_bonus": 0,
    "acquisition_count": 0,
    "transport_level": 1,
    "transport_capacity": 40,
    "selected_district": 0,
    "log_lines": []
}

var data: Dictionary = {}
var domains: Dictionary = {}

func _ready() -> void:
    _ensure_domains()
    _ensure_defaults()

func _ensure_domains() -> void:
    for domain in DOMAINS:
        if not domains.has(domain) or not (domains[domain] is Dictionary):
            domains[domain] = {}

func _ensure_defaults() -> void:
    _ensure_domains()
    if data.is_empty():
        for key in DEFAULT_STATE:
            var domain := _domain_for_key(key)
            if domain.is_empty():
                continue
            if not domains[domain].has(key):
                domains[domain][key] = DEFAULT_STATE[key]
        _rebuild_data()

func _domain_for_key(key: String) -> String:
    match key:
        "reputation", "day": return "player"
        "message", "log_lines": return "company"
        "owned", "inspected", "restoration", "stage": return "properties"
        "business_open", "capacity_level", "marketing_level", "player_price": return "businesses"
        "employees": return "employees"
        "cash", "last_sales", "last_profit", "total_profit": return "economy"
        "finished_goods": return "production"
        "supplier_choice", "transport_level", "transport_capacity": return "supply_chain"
        "contract_days", "contract_bonus": return "contracts"
        "relationship", "selected_rival": return "competitors"
        "selected_expansion": return "branches"
        "acquisition_count": return "ownership"
        "debt", "loan_payment": return "finance"
        "selected_district": return "regions"
        _: return ""

func capture(core: Dictionary) -> Dictionary:
    _ensure_domains()
    var flat := core.duplicate(true)
    _apply_flat_to_domains(flat)
    _capture_domain_systems()
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": flat}
    return data.duplicate(true)

func restore(snapshot: Dictionary) -> Dictionary:
    _ensure_domains()
    if snapshot.has("domains") and snapshot["domains"] is Dictionary:
        var incoming: Dictionary = snapshot["domains"]
        for domain in DOMAINS:
            if incoming.has(domain) and incoming[domain] is Dictionary:
                domains[domain] = incoming[domain].duplicate(true)
    var flat: Dictionary = {}
    if snapshot.has("legacy") and snapshot["legacy"] is Dictionary:
        flat = snapshot["legacy"].duplicate(true)
    else:
        flat = _domains_to_flat(snapshot)
    _apply_flat_to_domains(flat)
    _restore_domain_systems()
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": flat}
    return flat.duplicate(true)

func restore_state_compat(snapshot: Dictionary) -> Dictionary:
    return restore(snapshot)

func get_domain(domain: String) -> Dictionary:
    _ensure_domains()
    return domains.get(domain, {}).duplicate(true)

func set_domain(domain: String, value: Dictionary) -> void:
    if not DOMAINS.has(domain):
        return
    domains[domain] = value.duplicate(true)
    _rebuild_data()

func get_value(domain: String, key: String, default_value = null):
    _ensure_domains()
    return domains.get(domain, {}).get(key, default_value)

func set_value(domain: String, key: String, value) -> void:
    if not DOMAINS.has(domain):
        return
    var bucket: Dictionary = domains[domain]
    bucket[key] = value
    domains[domain] = bucket
    _rebuild_data()

func has_state() -> bool:
    return not data.is_empty()

func get_flat_state() -> Dictionary:
    _ensure_defaults()
    return _domains_to_flat({"domains": domains})

func clear() -> void:
    data.clear()
    domains.clear()
    _ensure_domains()
    _ensure_defaults()

func _apply_flat_to_domains(flat: Dictionary) -> void:
    _ensure_domains()
    _put("player", flat, ["reputation", "day"])
    _put("company", flat, ["message", "log_lines"])
    _put("properties", flat, ["owned", "inspected", "restoration", "stage"])
    _put("businesses", flat, ["business_open", "capacity_level", "marketing_level", "player_price"])
    _put("branches", flat, ["selected_expansion", "expansion"])
    _put("employees", flat, ["employees", "employee_system"])
    _put("economy", flat, ["cash", "last_sales", "last_profit", "total_profit"])
    _put("resources", flat, ["resources"])
    _put("production", flat, ["finished_goods"])
    _put("supply_chain", flat, ["supplier_choice", "transport_level", "transport_capacity", "resource_sites"])
    _put("contracts", flat, ["contract_days", "contract_bonus", "contract_system"])
    _put("competitors", flat, ["rivals", "selected_rival", "relationship"])
    _put("ownership", flat, ["acquisition_count"])
    _put("finance", flat, ["debt", "loan_payment"])
    _put("alliances", flat, ["relationship"])
    _put("diplomacy", flat, ["relationship", "selected_rival"])
    _put("regions", flat, ["selected_district", "districts"])
    _put("infrastructure", flat, ["management_level", "management_overhead"])
    _put("technology", flat, ["technology"])
    _put("events", flat, ["events"])
    _put("progression", flat, ["reputation", "day", "acquisition_count"])
    _put("history", flat, ["history_system"])
    _put("news", flat, ["news_system"])
    _put("analytics", flat, ["last_sales", "last_profit", "total_profit"])

func _put(domain: String, flat: Dictionary, keys: Array) -> void:
    var bucket: Dictionary = domains.get(domain, {}).duplicate(true)
    for key in keys:
        if flat.has(key):
            bucket[key] = flat[key]
    domains[domain] = bucket

func _domains_to_flat(snapshot: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var incoming: Dictionary = snapshot.get("domains", {})
    if not (incoming is Dictionary):
        return result
    for domain in incoming.keys():
        var bucket = incoming[domain]
        if bucket is Dictionary:
            for key in bucket.keys():
                result[key] = bucket[key]
    result["state_version"] = STATE_VERSION
    return result

func _capture_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        domains["finance"]["system"] = finance.capture_state()
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null:
        domains["production"]["system"] = production.capture_state()
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null:
        domains["analytics"]["simulation_system"] = simulation.capture_state()
    var contracts = root.get_node_or_null("RenewContractSystem")
    if contracts != null:
        domains["contracts"]["system"] = contracts.capture_state()

func _restore_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null and domains["finance"].get("system", {}) is Dictionary:
        finance.restore_state(domains["finance"]["system"])
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null and domains["production"].get("system", {}) is Dictionary:
        production.restore_state(domains["production"]["system"])
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null and domains["analytics"].get("simulation_system", {}) is Dictionary:
        simulation.restore_state(domains["analytics"]["simulation_system"])
    var contracts = root.get_node_or_null("RenewContractSystem")
    if contracts != null and domains["contracts"].get("system", {}) is Dictionary:
        contracts.restore_state(domains["contracts"]["system"])

func _rebuild_data() -> void:
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": _domains_to_flat({"domains": domains})}
