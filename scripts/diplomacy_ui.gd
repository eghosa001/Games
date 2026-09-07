extends CanvasLayer

## Lightweight treaty desk for the player. It exposes the full treaty catalogue
## without replacing the existing rival/deal UI.

var panel: PanelContainer
var summary: Label
var rival_label: Label
var selected_index: Variant = 0

func _ready() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(885, 70)
    panel.size = Vector2(360, 560)
    add_child(panel)
    var box: Variant = VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    panel.add_child(box)
    var title: Variant = Label.new(); title.text = "DIPLOMACY / TREATIES"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
    rival_label = Label.new(); box.add_child(rival_label)
    var prev: Variant = Button.new(); prev.text = "‹ Previous Rival"; prev.pressed.connect(_previous_rival); box.add_child(prev)
    var next: Variant = Button.new(); next.text = "Next Rival ›"; next.pressed.connect(_next_rival); box.add_child(next)
    for entry in [["TRADE", "trade"], ["SUPPLY", "supply"], ["RESEARCH", "research"], ["DEFENSE", "defense"], ["NON-AGGRESSION", "non_aggression"], ["INVESTMENT", "investment"], ["TERRITORY", "territory"], ["INFRASTRUCTURE", "infrastructure"], ["JOINT VENTURE", "joint_venture"]]:
        var button: Variant = Button.new(); button.text = "Propose %s (30d)" % entry[0]; button.pressed.connect(_propose.bind(entry[1])); box.add_child(button)
    var accept: Variant = Button.new(); accept.text = "Accept Incoming Treaty"; accept.pressed.connect(_accept_incoming); box.add_child(accept)
    var gift: Variant = Button.new(); gift.text = "Send Envoy Gift"; gift.pressed.connect(_send_gift); box.add_child(gift)
    var cancel: Variant = Button.new(); cancel.text = "Cancel Active Treaty"; cancel.pressed.connect(_cancel_active); box.add_child(cancel)
    var refresh: Variant = Button.new(); refresh.text = "Refresh Treaty Ledger"; refresh.pressed.connect(_refresh); box.add_child(refresh)
    summary = Label.new(); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(summary)
    _refresh()

func _main():
    var tree: Variant = Engine.get_main_loop()
    return tree.get_current_scene() if tree != null else null

func _rival() -> Dictionary:
    var main = _main()
    if main == null or main.get("rivals") == null: return {}
    var list: Array = main.get("rivals").rivals
    if list.is_empty(): return {}
    selected_index = clampi(selected_index, 0, list.size() - 1)
    return list[selected_index]

func _previous_rival() -> void:
    selected_index -= 1; _refresh()
func _next_rival() -> void:
    selected_index += 1; _refresh()

func _propose(treaty_type: String) -> void:
    var rival: Variant = _rival()
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    var terms: Variant = {"obligations": {"good_faith": true}, "benefits": {"trust_per_day": 0.05}, "penalties": {"trust_damage": 8.0, "cancellation_fee": 1000}, "trust_effect": 2.0}
    if treaty_type == "joint_venture":
        terms = {"obligations": {"joint_capital": 6000}, "benefits": {"trust_per_day": 0.12}, "penalties": {"trust_damage": 10.0, "cancellation_fee": 2000}, "party_a_percent": 50.0, "party_b_percent": 50.0, "trust_effect": 3.0}
    var result = diplomacy.propose_treaty("player", str(rival.get("id", "")), treaty_type, terms, 30)
    summary.text = str(result.get("message", "Proposal submitted."))
    _refresh()

func _nudge_rival(rival_id: String, amount: int) -> void:
    var main = _main()
    if main == null or main.get("rivals") == null:
        return
    for i in range(main.get("rivals").rivals.size()):
        if str(main.get("rivals").rivals[i].get("id", "")) == rival_id:
            main.get("rivals").rivals[i]["relationship"] = clamp(int(main.get("rivals").rivals[i].get("relationship", 0)) + amount, -100, 100)
            return

func _accept_incoming() -> void:
    var rival: Variant = _rival()
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    for treaty in diplomacy.get_party_treaties("player", false):
        if treaty.get("status") == "proposed" and treaty.get("party_b") == "player" and treaty.get("party_a") == rival.get("id"):
            var result = diplomacy.accept_treaty(str(treaty["id"]), "player")
            summary.text = str(result.get("message", "Proposal submitted."))
            if bool(result.get("ok", false)):
                _nudge_rival(str(rival.get("id", "")), 3)
            _refresh(); return
    summary.text = "No incoming proposal from this rival."

func _send_gift() -> void:
    var main = _main()
    if main == null or not main.has_method("send_envoy_gift"):
        return
    main.send_envoy_gift()
    _refresh()

func _cancel_active() -> void:
    var rival: Variant = _rival()
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    for treaty in diplomacy.get_party_treaties("player", true):
        var other: Variant = str(treaty.get("party_b", "")) if treaty.get("party_a") == "player" else str(treaty.get("party_a", ""))
        if other == str(rival.get("id", "")):
            var result = diplomacy.cancel_treaty(str(treaty["id"]), "player", "player cancellation")
            summary.text = str(result.get("message", "Treaty cancelled.")); _refresh()
            if bool(result.get("ok", false)):
                _nudge_rival(str(rival.get("id", "")), -8)
            return
    summary.text = "No active treaty with this rival."

func _refresh() -> void:
    var rival: Variant = _rival()
    if rival.is_empty():
        rival_label.text = "No rival selected."
        summary.text = ""
        return
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if diplomacy == null: return
    rival_label.text = "Counterparty: %s" % str(rival.get("name", "Rival"))
    var trust: Variant = diplomacy.get_trust("player", str(rival.get("id", "")))
    var lines: Array[String] = ["Trust: %0.1f / 100" % trust]
    for treaty in diplomacy.get_party_treaties("player", false):
        var other: Variant = str(treaty.get("party_b", "")) if treaty.get("party_a") == "player" else str(treaty.get("party_a", ""))
        if other == str(rival.get("id", "")):
            lines.append("%s: %s until day %s" % [str(treaty.get("type", "treaty")), str(treaty.get("status", "")), str(treaty.get("end_day", "-"))])
            if str(treaty.get("type", "")) == "joint_venture":
                lines.append(_jv_status_line(str(treaty.get("id", ""))))
    summary.text = "\n".join(lines)

func _jv_status_line(treaty_id: String) -> String:
    var bridge = get_node_or_null("/root/RenewDiplomacyControl")
    if bridge == null or not bridge.has_method("get_materialized_state"):
        return "Venture status unavailable."
    var state: Dictionary = bridge.get_materialized_state(treaty_id)
    if state.is_empty() or not bool(state.get("materialized", false)):
        return "Venture forming."
    if not bool(state.get("funded", false)):
        return "Venture awaiting capital."
    return "Venture %s funded $%d, paid out $%d." % [str(state.get("venture_name", "JV")), int(state.get("funded_capital", 0)), int(state.get("total_paid_out", 0))]
