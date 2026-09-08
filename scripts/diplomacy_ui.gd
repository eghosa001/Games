extends CanvasLayer

## Responsive treaty desk. Gameplay mutations remain owned by DiplomacySystem.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const TREATIES := [["TRADE","trade"],["SUPPLY","supply"],["RESEARCH","research"],["DEFENSE","defense"],["NON-AGGRESSION","non_aggression"],["INVESTMENT","investment"],["TERRITORY","territory"],["INFRASTRUCTURE","infrastructure"],["JOINT VENTURE","joint_venture"]]

var dimmer: ColorRect
var panel: Panel
var summary: Label
var rival_label: Label
var treaty_scroll: ScrollContainer
var treaty_list: VBoxContainer
var selected_index: Variant = 0
var visible_width := 1280.0

func _ready() -> void:
    layer = 58
    _build()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and visible:
        _close()
        get_viewport().set_input_as_handled()

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s

func _button_style(bg: Color = SURFACE_2, border: Color = BORDER) -> StyleBoxFlat:
    var s := _style(bg, border, 8); s.content_margin_left = 10; s.content_margin_right = 10; s.content_margin_top = 6; s.content_margin_bottom = 6; return s

func _style_button(b: Button, bg: Color = SURFACE_2, border: Color = BORDER) -> void:
    b.add_theme_stylebox_override("normal", _button_style(bg, border)); b.add_theme_stylebox_override("hover", _button_style(Color("17343d"), ACCENT)); b.add_theme_stylebox_override("pressed", _button_style(Color("1b454c"), ACCENT)); b.add_theme_color_override("font_color", TEXT); b.add_theme_color_override("font_hover_color", Color.WHITE); b.add_theme_font_size_override("font_size", 9 if visible_width < 390.0 else 10)

func _build() -> void:
    dimmer = ColorRect.new(); dimmer.name = "DiplomacyScrim"; dimmer.color = Color(0.015,0.055,0.07,0.76); dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dimmer.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(dimmer)
    panel = Panel.new(); panel.name = "DiplomacyPanel"; panel.mouse_filter = Control.MOUSE_FILTER_STOP; panel.add_theme_stylebox_override("panel", _style(SURFACE,BORDER,14)); add_child(panel)
    var title := Label.new(); title.name = "Title"; title.text = "DIPLOMACY COUNCIL"; title.add_theme_font_size_override("font_size",20); title.add_theme_color_override("font_color",TEXT); panel.add_child(title)
    var subtitle := Label.new(); subtitle.name = "Subtitle"; subtitle.text = "Treaties • trust • long-term corporate relations"; subtitle.add_theme_font_size_override("font_size",10); subtitle.add_theme_color_override("font_color",MUTED); panel.add_child(subtitle)
    var close := Button.new(); close.name = "CloseButton"; close.text = "CLOSE"; close.custom_minimum_size = Vector2(80,46); close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(_close); _style_button(close); panel.add_child(close)
    rival_label = Label.new(); rival_label.name = "Rival"; rival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rival_label.add_theme_font_size_override("font_size",12); rival_label.add_theme_color_override("font_color",TEXT); panel.add_child(rival_label)
    _nav_button("PreviousRival","‹  PREVIOUS RIVAL",_previous_rival); _nav_button("NextRival","NEXT RIVAL  ›",_next_rival)
    treaty_scroll = ScrollContainer.new(); treaty_scroll.name = "TreatyScroll"; treaty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; treaty_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(treaty_scroll)
    treaty_list = VBoxContainer.new(); treaty_list.add_theme_constant_override("separation",6); treaty_scroll.add_child(treaty_list)
    for entry in TREATIES:
        var b := Button.new(); b.text = "PROPOSE %s  •  30 DAYS" % entry[0]; b.custom_minimum_size = Vector2(0,44); b.focus_mode = Control.FOCUS_NONE; b.tooltip_text = "Propose a 30-day %s treaty." % entry[0].to_lower(); b.pressed.connect(_propose.bind(entry[1])); _style_button(b); treaty_list.add_child(b)
    var action_title := Label.new(); action_title.name = "ActionsTitle"; action_title.text = "TREATY ACTIONS"; action_title.add_theme_font_size_override("font_size",10); action_title.add_theme_color_override("font_color",MUTED); panel.add_child(action_title)
    _action_button("AcceptIncoming","ACCEPT INCOMING TREATY",_accept_incoming)
    _action_button("SendGift","SEND ENVOY GIFT",_send_gift)
    _action_button("CancelTreaty","CANCEL ACTIVE TREATY",_cancel_active,Color("301d22"),Color("75424a"))
    _action_button("RefreshTreatyLedger","REFRESH TREATY LEDGER",_refresh)
    summary = Label.new(); summary.name = "Summary"; summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size",10); summary.add_theme_color_override("font_color",MUTED); panel.add_child(summary)

func _nav_button(id: String, text: String, callback: Callable) -> void:
    var b := Button.new(); b.name = id; b.text = text; b.custom_minimum_size = Vector2(0,44); b.focus_mode = Control.FOCUS_NONE; b.pressed.connect(callback); _style_button(b); panel.add_child(b)

func _action_button(id: String, text: String, callback: Callable, bg: Color = SURFACE_2, border: Color = BORDER) -> void:
    var b := Button.new(); b.name = id; b.text = text; b.custom_minimum_size = Vector2(0,44); b.focus_mode = Control.FOCUS_NONE; b.pressed.connect(callback); _style_button(b,bg,border); panel.add_child(b)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible = false

func _main():
    var tree: Variant = Engine.get_main_loop(); return tree.get_current_scene() if tree != null else null

func _rival() -> Dictionary:
    var main = _main()
    if main == null or main.get("rivals") == null: return {}
    var list: Array = main.get("rivals").rivals
    if list.is_empty(): return {}
    selected_index = clampi(selected_index,0,list.size()-1); return list[selected_index]

func _previous_rival() -> void: selected_index -= 1; _refresh()
func _next_rival() -> void: selected_index += 1; _refresh()

func _propose(treaty_type: String) -> void:
    var rival := _rival(); var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    var terms: Variant = {"obligations":{"good_faith":true},"benefits":{"trust_per_day":0.05},"penalties":{"trust_damage":8.0,"cancellation_fee":1000},"trust_effect":2.0}
    if treaty_type == "joint_venture": terms = {"obligations":{"joint_capital":6000},"benefits":{"trust_per_day":0.12},"penalties":{"trust_damage":10.0,"cancellation_fee":2000},"party_a_percent":50.0,"party_b_percent":50.0,"trust_effect":3.0}
    var result = diplomacy.propose_treaty("player",str(rival.get("id","")),treaty_type,terms,30); summary.text = str(result.get("message","Proposal submitted.")); _refresh()

func _nudge_rival(rival_id: String, amount: int) -> void:
    var main = _main()
    if main == null or main.get("rivals") == null: return
    for i in range(main.get("rivals").rivals.size()):
        if str(main.get("rivals").rivals[i].get("id","")) == rival_id:
            main.get("rivals").rivals[i]["relationship"] = clamp(int(main.get("rivals").rivals[i].get("relationship",0))+amount,-100,100); return

func _accept_incoming() -> void:
    var rival := _rival(); var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    for treaty in diplomacy.get_party_treaties("player",false):
        if treaty.get("status") == "proposed" and treaty.get("party_b") == "player" and treaty.get("party_a") == rival.get("id"):
            var result = diplomacy.accept_treaty(str(treaty["id"]),"player"); summary.text = str(result.get("message","Proposal submitted.")); if bool(result.get("ok",false)): _nudge_rival(str(rival.get("id","")),3); _refresh(); return
    summary.text = "No incoming proposal from this rival."

func _send_gift() -> void:
    var main = _main()
    if main == null or not main.has_method("send_envoy_gift"): summary.text = "Envoy service is unavailable."; return
    main.send_envoy_gift(); _refresh()

func _cancel_active() -> void:
    var rival := _rival(); var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if rival.is_empty() or diplomacy == null: return
    for treaty in diplomacy.get_party_treaties("player",true):
        var other: Variant = str(treaty.get("party_b","")) if treaty.get("party_a") == "player" else str(treaty.get("party_a",""))
        if other == str(rival.get("id","")):
            var result = diplomacy.cancel_treaty(str(treaty["id"]),"player","player cancellation"); summary.text = str(result.get("message","Treaty cancelled.")); _refresh(); if bool(result.get("ok",false)): _nudge_rival(str(rival.get("id","")),-8); return
    summary.text = "No active treaty with this rival."

func _refresh() -> void:
    var rival := _rival()
    if rival.is_empty(): rival_label.text = "NO RIVAL SELECTED"; summary.text = "No rival is available."; return
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if diplomacy == null: rival_label.text = "DIPLOMACY SYSTEM UNAVAILABLE"; summary.text = "The treaty ledger cannot be loaded right now."; return
    rival_label.text = "COUNTERPARTY  •  %s" % str(rival.get("name","Rival"))
    var trust: Variant = diplomacy.get_trust("player",str(rival.get("id",""))); var state := "STRONG" if float(trust)>=70.0 else ("STABLE" if float(trust)>=45.0 else "FRAGILE")
    var lines: Array[String] = ["Trust  %0.1f / 100  •  %s" % [trust,state]]; var active_count := 0
    for treaty in diplomacy.get_party_treaties("player",false):
        var other: Variant = str(treaty.get("party_b","")) if treaty.get("party_a") == "player" else str(treaty.get("party_a",""))
        if other == str(rival.get("id","")):
            active_count += 1; lines.append("%s  •  %s  •  until day %s" % [str(treaty.get("type","treaty")).replace("_"," ").to_upper(),str(treaty.get("status","")).to_upper(),str(treaty.get("end_day","-"))])
            if str(treaty.get("type","")) == "joint_venture": lines.append(_jv_status_line(str(treaty.get("id",""))))
    if active_count == 0: lines.append("No active treaties with this rival.")
    summary.text = "\n".join(lines)

func _jv_status_line(treaty_id: String) -> String:
    var bridge = get_node_or_null("/root/RenewDiplomacyControl")
    if bridge == null or not bridge.has_method("get_materialized_state"): return "Venture status unavailable."
    var state: Dictionary = bridge.get_materialized_state(treaty_id)
    if state.is_empty() or not bool(state.get("materialized",false)): return "Venture forming."
    if not bool(state.get("funded",false)): return "Venture awaiting capital."
    return "Venture %s funded $%d, paid out $%d." % [str(state.get("venture_name","JV")),int(state.get("funded_capital",0)),int(state.get("total_paid_out",0))]

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; visible_width = size.x; var narrow := size.x < 760.0; var phone := size.x < 390.0
    var width := maxf(304.0,size.x-16.0) if narrow else minf(560.0,size.x-36.0); var height := maxf(500.0,size.y-78.0) if narrow else minf(680.0,size.y-100.0)
    panel.position = Vector2(8,70) if narrow else Vector2(maxf(18.0,(size.x-width)*0.5),76); panel.size = Vector2(width,height)
    var title := panel.get_node_or_null("Title") as Label; if title != null: title.position=Vector2(14,10); title.size=Vector2(width-108,30); title.add_theme_font_size_override("font_size",18 if phone else 20)
    var subtitle := panel.get_node_or_null("Subtitle") as Label; if subtitle != null: subtitle.position=Vector2(14,38); subtitle.size=Vector2(width-28,20)
    var close := panel.get_node_or_null("CloseButton") as Button; if close != null: close.position=Vector2(width-88,7); close.size=Vector2(80,46)
    rival_label.position=Vector2(14,62); rival_label.size=Vector2(width-28,34)
    var prev := panel.get_node_or_null("PreviousRival") as Button; var next := panel.get_node_or_null("NextRival") as Button; var nav_w: float=(width-35.0)*0.5
    if prev != null: prev.position=Vector2(14,96); prev.size=Vector2(nav_w,44)
    if next != null: next.position=Vector2(21+nav_w,96); next.size=Vector2(nav_w,44)
    treaty_scroll.position=Vector2(14,148); treaty_scroll.size=Vector2(width-28,maxf(150.0,height-360.0)); treaty_list.custom_minimum_size.x=width-28
    for child in treaty_list.get_children():
        if child is Button: child.custom_minimum_size=Vector2(width-28,44); child.add_theme_font_size_override("font_size",9 if phone else 10)
    var actions_title := panel.get_node_or_null("ActionsTitle") as Label; var actions_y := height-198.0
    if actions_title != null: actions_title.position=Vector2(14,actions_y); actions_title.size=Vector2(width-28,18)
    var names := ["AcceptIncoming","SendGift","CancelTreaty","RefreshTreatyLedger"]; var bw: float=(width-35.0)*0.5
    for i in range(names.size()):
        var b := panel.get_node_or_null(names[i]) as Button
        if b != null: b.position=Vector2(14+(i%2)*(bw+7),actions_y+24+(i/2)*50); b.size=Vector2(bw,44); b.add_theme_font_size_override("font_size",9 if phone else 10)
    summary.position=Vector2(14,height-72); summary.size=Vector2(width-28,62)
