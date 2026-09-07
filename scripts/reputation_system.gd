extends Node

## V8.7: five-dimension reputation. The headline score stays authoritative;
## dimensions track character in parallel and nudge the headline at half rate.
const DIMS := ["public", "employee", "business", "investor", "environmental"]
const DIM_TITLES := {"public": "Public", "employee": "Workplace", "business": "Trade", "investor": "Investor", "environmental": "Green"}

func _state() -> Variant:
    return get_node_or_null("/root/RenewGameState")

func dimensions() -> Dictionary:
    var state: Variant = _state()
    var fallback := 0
    if state != null:
        fallback = int(state.get_value("player", "reputation", 0))
    var stored: Variant = state.get_value("company", "reputation", {}) if state != null else {}
    var out := {}
    for dim in DIMS:
        if stored is Dictionary and (stored as Dictionary).has(dim):
            out[dim] = clampi(int((stored as Dictionary)[dim]), 0, 100)
        else:
            out[dim] = clampi(fallback, 0, 100)
    return out

func adjust(dim: String, delta: int) -> Dictionary:
    if not DIMS.has(dim):
        return {"ok": false, "error": "unknown_dimension"}
    if delta == 0:
        return {"ok": true, "dim": dim, "value": int(dimensions().get(dim, 0)), "headline": _headline()}
    var state: Variant = _state()
    if state == null:
        return {"ok": false, "error": "state_unavailable"}
    var dims := dimensions()
    dims[dim] = clampi(int(dims[dim]) + delta, 0, 100)
    state.set_value("company", "reputation", dims)
    var nudge := int(round(float(delta) / 2.0))
    if nudge != 0:
        state.set_value("player", "reputation", maxi(0, _headline() + nudge))
    return {"ok": true, "dim": dim, "value": int(dims[dim]), "headline": _headline()}

func status_text() -> String:
    var dims := dimensions()
    var bits: Array = []
    for dim in DIMS:
        bits.append("%s %d" % [str(DIM_TITLES[dim]), int(dims[dim])])
    return "REPUTE (headline %d) — %s." % [_headline(), ", ".join(bits)]

func _headline() -> int:
    var state: Variant = _state()
    return int(state.get_value("player", "reputation", 0)) if state != null else 0

func capture_state() -> Dictionary:
    return {}

func restore_state(_state_data: Dictionary) -> void:
    pass
