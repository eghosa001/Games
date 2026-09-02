extends Node
class_name RenewGameState

# Canonical simulation-state boundary. Domain systems own runtime behaviour;
# this node owns the persistent state envelope and system snapshots.
const STATE_VERSION := 4
const DOMAINS := [
    "player", "company", "properties", "businesses", "branches", "employees",
    "economy", "resources", "production", "supply_chain", "contracts",
    "competitors", "ownership", "finance", "alliances", "diplomacy", "regions",
    "infrastructure", "technology", "events", "progression", "history", "news", "analytics"
]
var data: Dictionary = {}
var domains: Dictionary = {}

func _ready() -> void: _ensure_domains()

func _ensure_domains() -> void:
    for domain in DOMAINS:
        if not domains.has(domain) or not (domains[domain] is Dictionary): domains[domain] = {}

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
            if incoming.has(domain) and incoming[domain] is Dictionary: domains[domain] = incoming[domain].duplicate(true)
    var flat: Dictionary = {}
    if snapshot.has("legacy") and snapshot["legacy"] is Dictionary: flat = snapshot["legacy"].duplicate(true)
    else: flat = _domains_to_flat(snapshot)
    _apply_flat_to_domains(flat)
    _restore_domain_systems()
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": flat}
    return flat.duplicate(true)

func restore_state_compat(snapshot: Dictionary) -> Dictionary: return restore(snapshot)
func get_domain(domain: String) -> Dictionary:
    _ensure_domains(); return domains.get(domain, {}).duplicate(true)
func set_domain(domain: String, value: Dictionary) -> void:
    if not DOMAINS.has(domain): return
    domains[domain] = value.duplicate(true); _rebuild_data()
func get_value(domain: String, key: String, default_value = null):
    _ensure_domains(); return domains.get(domain, {}).get(key, default_value)
func set_value(domain: String, key: String, value) -> void:
    if not DOMAINS.has(domain): return
    var bucket: Dictionary = domains[domain]; bucket[key] = value; domains[domain] = bucket; _rebuild_data()
func has_state() -> bool: return not data.is_empty()
func clear() -> void: data.clear(); domains.clear(); _ensure_domains()

func _apply_flat_to_domains(flat: Dictionary) -> void:
    _ensure_domains()
    _put("player", flat, ["reputation", "day"])
    _put("company", flat, ["message", "log_lines"])
    _put("properties", flat, ["owned", "inspected", "restoration", "stage"])
    _put("businesses", flat, ["business_open", "capacity_level", "marketing_level", "player_price"])
    _put("branches", flat, ["expansion"])
    _put("employees", flat, ["employees", "employee_system"])
    _put("economy", flat, ["cash", "last_sales", "last_profit", "total_profit"])
    _put("resources", flat, ["resources"])
    _put("production", flat, ["finished_goods"])
    _put("supply_chain", flat, ["supplier_choice", "transport_level", "transport_capacity", "resource_sites"])
    _put("contracts", flat, ["contract_days", "contract_bonus"])
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
        if flat.has(key): bucket[key] = flat[key]
    domains[domain] = bucket

func _domains_to_flat(snapshot: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var incoming: Dictionary = snapshot.get("domains", {})
    if not (incoming is Dictionary): return result
    for domain in incoming.keys():
        var bucket = incoming[domain]
        if bucket is Dictionary:
            for key in bucket.keys(): result[key] = bucket[key]
    result["state_version"] = STATE_VERSION
    return result

func _capture_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null: domains["finance"]["system"] = finance.capture_state()
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null: domains["production"]["system"] = production.capture_state()
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null: domains["analytics"]["simulation_system"] = simulation.capture_state()

func _restore_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null and domains["finance"].get("system", {}) is Dictionary: finance.restore_state(domains["finance"]["system"])
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null and domains["production"].get("system", {}) is Dictionary: production.restore_state(domains["production"]["system"])
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null and domains["analytics"].get("simulation_system", {}) is Dictionary: simulation.restore_state(domains["analytics"]["simulation_system"])

func _rebuild_data() -> void:
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": _domains_to_flat({"domains": domains})}
