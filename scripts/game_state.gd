extends Node

## Canonical persistent gameplay-state boundary.
## Each gameplay fact has exactly one authoritative domain. Systems own behavior,
## while RenewGameState owns the data that behavior reads and mutates.
const STATE_VERSION := 5

const DOMAINS := [
    "player", "company", "properties", "businesses", "branches", "employees",
    "economy", "resources", "production", "supply_chain", "contracts",
    "competitors", "ownership", "finance", "alliances", "diplomacy", "regions",
    "infrastructure", "technology", "events", "progression", "history", "news", "analytics"
]

## Canonical ownership contract. A key must have one home only.
const DOMAIN_KEYS := {
    "player": ["day", "reputation"],
    "company": ["message", "log_lines"],
    "properties": ["owned", "inspected", "restoration", "stage"],
    "businesses": ["business_open", "capacity_level", "marketing_level", "player_price"],
    "branches": ["selected_expansion", "expansion"],
    "employees": ["roster", "employees", "employee_system"],
    "economy": ["cash", "last_sales", "last_profit", "total_profit"],
    "resources": ["resources"],
    "production": ["finished_goods", "system"],
    "supply_chain": ["supplier_choice", "transport_level", "transport_capacity", "resource_sites"],
    "contracts": ["contract_days", "contract_bonus", "contract_system", "system"],
    "competitors": ["rivals", "selected_rival", "relationship"],
    "ownership": ["acquisition_count"],
    "finance": ["debt", "loan_payment", "system"],
    "alliances": ["alliances"],
    "diplomacy": ["diplomacy"],
    "regions": ["selected_district", "districts"],
    "infrastructure": ["management_level", "management_overhead"],
    "technology": ["technology"],
    "events": ["events"],
    "progression": ["milestones", "unlocks", "xp", "level"],
    "history": ["history_system"],
    "news": ["news_system"],
    "analytics": ["simulation_system"]
}

const DEFAULT_DOMAINS := {
    "player": {"day": 1, "reputation": 0},
    "company": {"message": "Inspect the abandoned warehouse. Your empire starts here.", "log_lines": []},
    "properties": {"owned": false, "inspected": false, "restoration": 0, "stage": "Neglected"},
    "businesses": {"business_open": false, "capacity_level": 1, "marketing_level": 0, "player_price": 110},
    "branches": {"selected_expansion": 0, "expansion": {}},
    "employees": {"roster": [], "employees": 3, "employee_system": {}},
    "economy": {"cash": 25000, "last_sales": 0, "last_profit": 0, "total_profit": 0},
    "resources": {"resources": {}},
    "production": {"finished_goods": 0, "system": {}},
    "supply_chain": {"supplier_choice": 0, "transport_level": 1, "transport_capacity": 40, "resource_sites": {}},
    "contracts": {"contract_days": 0, "contract_bonus": 0, "contract_system": {}, "system": {}},
    "competitors": {"rivals": [], "selected_rival": 0, "relationship": 15},
    "ownership": {"acquisition_count": 0},
    "finance": {"debt": 0, "loan_payment": 0, "system": {}},
    "alliances": {"alliances": {}},
    "diplomacy": {"diplomacy": {}},
    "regions": {"selected_district": 0, "districts": {}},
    "infrastructure": {"management_level": 0, "management_overhead": 0},
    "technology": {"technology": {}},
    "events": {"events": []},
    "progression": {"milestones": [], "unlocks": [], "xp": 0, "level": 1},
    "history": {"history_system": {}},
    "news": {"news_system": {}},
    "analytics": {"simulation_system": {}}
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
    for domain in DOMAINS:
        var defaults: Dictionary = DEFAULT_DOMAINS.get(domain, {})
        var bucket: Dictionary = domains[domain]
        for key in defaults.keys():
            if not bucket.has(key):
                bucket[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
        domains[domain] = bucket
    _rebuild_data()

func capture(core: Dictionary = {}) -> Dictionary:
    _ensure_defaults()
    _apply_flat_to_domains(core)
    _capture_domain_systems()
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": _domains_to_flat({"domains": domains})}
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
    _ensure_defaults()
    _restore_domain_systems()
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": _domains_to_flat({"domains": domains})}
    return flat.duplicate(true)

func restore_state_compat(snapshot: Dictionary) -> Dictionary:
    return restore(snapshot)

func get_domain(domain: String) -> Dictionary:
    _ensure_domains()
    return domains.get(domain, {}).duplicate(true)

func set_domain(domain: String, value: Dictionary) -> void:
    if not DOMAINS.has(domain):
        push_warning("GameState: rejected unknown domain '%s'" % domain)
        return
    domains[domain] = value.duplicate(true)
    _rebuild_data()

func get_value(domain: String, key: String, default_value = null):
    _ensure_domains()
    return domains.get(domain, {}).get(key, default_value)

func set_value(domain: String, key: String, value) -> void:
    if not DOMAINS.has(domain):
        push_warning("GameState: rejected unknown domain '%s'" % domain)
        return
    var allowed: Array = DOMAIN_KEYS.get(domain, [])
    if not allowed.has(key):
        push_warning("GameState: '%s' does not belong to domain '%s'" % [key, domain])
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
    if flat.is_empty():
        return
    _migrate_key("player", flat, "reputation")
    _migrate_key("player", flat, "day")
    _migrate_key("company", flat, "message")
    _migrate_key("company", flat, "log_lines")
    for key in ["owned", "inspected", "restoration", "stage"]: _migrate_key("properties", flat, key)
    for key in ["business_open", "capacity_level", "marketing_level", "player_price"]: _migrate_key("businesses", flat, key)
    _migrate_key("branches", flat, "selected_expansion")
    _migrate_key("employees", flat, "employees")
    _migrate_key("employees", flat, "employee_system")
    for key in ["cash", "last_sales", "last_profit", "total_profit"]: _migrate_key("economy", flat, key)
    _migrate_key("resources", flat, "resources")
    _migrate_key("production", flat, "finished_goods")
    for key in ["supplier_choice", "transport_level", "transport_capacity", "resource_sites"]: _migrate_key("supply_chain", flat, key)
    for key in ["contract_days", "contract_bonus", "contract_system"]: _migrate_key("contracts", flat, key)
    for key in ["rivals", "selected_rival", "relationship"]: _migrate_key("competitors", flat, key)
    _migrate_key("ownership", flat, "acquisition_count")
    for key in ["debt", "loan_payment"]: _migrate_key("finance", flat, key)
    _migrate_key("regions", flat, "selected_district")

func _migrate_key(domain: String, flat: Dictionary, key: String) -> void:
    if flat.has(key):
        var bucket: Dictionary = domains.get(domain, {}).duplicate(true)
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
                # Canonical ownership deliberately prevents duplicate facts from
                # being exported from domains such as alliances/diplomacy.
                if not _is_canonical_key(domain, str(key)):
                    continue
                result[key] = bucket[key]
    result["state_version"] = STATE_VERSION
    return result

func _is_canonical_key(domain: String, key: String) -> bool:
    var allowed: Array = DOMAIN_KEYS.get(domain, [])
    return allowed.has(key)

func _capture_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null and finance.has_method("capture_state"):
        domains["finance"]["system"] = finance.capture_state()
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null and production.has_method("capture_state"):
        domains["production"]["system"] = production.capture_state()
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null and simulation.has_method("capture_state"):
        domains["analytics"]["simulation_system"] = simulation.capture_state()
    var contracts = root.get_node_or_null("RenewContractSystem")
    if contracts != null and contracts.has_method("capture_state"):
        domains["contracts"]["system"] = contracts.capture_state()

func _restore_domain_systems() -> void:
    var root := get_tree().root
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null and finance.has_method("restore_state") and domains["finance"].get("system", {}) is Dictionary:
        finance.restore_state(domains["finance"]["system"])
    var production = root.get_node_or_null("RenewProductionSystem")
    if production != null and production.has_method("restore_state") and domains["production"].get("system", {}) is Dictionary:
        production.restore_state(domains["production"]["system"])
    var simulation = root.get_node_or_null("RenewSimulationSystem")
    if simulation != null and simulation.has_method("restore_state") and domains["analytics"].get("simulation_system", {}) is Dictionary:
        simulation.restore_state(domains["analytics"]["simulation_system"])
    var contracts = root.get_node_or_null("RenewContractSystem")
    if contracts != null and contracts.has_method("restore_state") and domains["contracts"].get("system", {}) is Dictionary:
        contracts.restore_state(domains["contracts"]["system"])

func _rebuild_data() -> void:
    data = {"state_version": STATE_VERSION, "domains": domains.duplicate(true), "legacy": _domains_to_flat({"domains": domains})}
