extends CanvasLayer

# Primary mobile control surface. Main/gameplay commands are the authoritative
# action boundary; screen presentation is delegated to RenewUIScreenManager.
var parent: Node
var active_tab: int = 0
var root: Control
var tabs: HBoxContainer
var actions: GridContainer
var action_scroll: ScrollContainer
var status_label: Label
var goal_label: Label
var feedback_panel: Panel
var feedback_label: Label
var feedback_timer := 0.0
var last_seen_day := 1
var observed_milestones: Dictionary = {}
var tab_names: Array[String] = ["RESTORE", "BUSINESS", "EMPIRE", "WORLD"]

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    call_deferred("_initialize")

func _initialize() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    if parent == null: return
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _layout_responsive(); _refresh(); last_seen_day = int(parent.day); _seed_milestones()
    if not get_viewport().size_changed.is_connected(_layout_responsive): get_viewport().size_changed.connect(_layout_responsive)
    _update_panel_visibility()

func _process(delta: float) -> void:
    if parent == null: return
    status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    _update_goal_label(); _detect_milestones()
    if int(parent.day) != last_seen_day: last_seen_day = int(parent.day); _show_day_report()
    if feedback_timer > 0.0:
        feedback_timer -= delta
        if feedback_timer <= 0.0: feedback_panel.hide()

func _build_ui() -> void:
    root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    var top := ColorRect.new(); top.color = Color("101820"); top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.position.y = 8; top.size.y = 54; top.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top)
    tabs = HBoxContainer.new(); tabs.position = Vector2(12, 12); tabs.size = Vector2(700, 46); tabs.add_theme_constant_override("separation", 8); tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tabs)
    for i in range(tab_names.size()):
        var b := Button.new(); b.text = tab_names[i]; b.custom_minimum_size = Vector2(150, 44); b.focus_mode = Control.FOCUS_NONE; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.pressed.connect(_set_tab.bind(i)); tabs.add_child(b)
    status_label = Label.new(); status_label.position = Vector2(760, 17); status_label.size = Vector2(500, 44); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(status_label)
    action_scroll = ScrollContainer.new(); action_scroll.position = Vector2(18, 72); action_scroll.size = Vector2(1240, 160); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.focus_mode = Control.FOCUS_NONE; action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(action_scroll)
    actions = GridContainer.new(); actions.columns = 3; actions.add_theme_constant_override("h_separation", 10); actions.add_theme_constant_override("v_separation", 8); action_scroll.add_child(actions)
    feedback_panel = Panel.new(); feedback_panel.position = Vector2(24, 245); feedback_panel.size = Vector2(720, 92); feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.hide(); root.add_child(feedback_panel)
    feedback_label = Label.new(); feedback_label.position = Vector2(16, 10); feedback_label.size = Vector2(688, 72); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.add_child(feedback_label)
    goal_label = Label.new(); goal_label.position = Vector2(24, 348); goal_label.size = Vector2(900, 48); goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(goal_label)

func _layout_responsive() -> void:
    if root == null: return
    var w := maxf(root.size.x, 320.0); var narrow := w < 700.0
    tabs.size = Vector2(w - 24.0, 46)
    for child in tabs.get_children():
        var b := child as Button
        if b != null: b.custom_minimum_size = Vector2(maxf(70.0, (w - 48.0) / 4.0), 44)
    if narrow:
        status_label.position = Vector2(12, 60); status_label.size = Vector2(w - 24.0, 30); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; action_scroll.position = Vector2(12, 94); action_scroll.size = Vector2(w - 24.0, 150); actions.columns = 2; feedback_panel.position = Vector2(12, 252); feedback_panel.size = Vector2(w - 24.0, 96); feedback_label.size = Vector2(w - 56.0, 76); goal_label.position = Vector2(12, 354); goal_label.size = Vector2(w - 24.0, 58)
    else:
        status_label.position = Vector2(maxf(730.0, w - 520.0), 17); status_label.size = Vector2(minf(500.0, w - 742.0), 44); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; action_scroll.position = Vector2(18, 72); action_scroll.size = Vector2(w - 36.0, 160); actions.columns = 3; feedback_panel.position = Vector2(24, 245); feedback_panel.size = Vector2(minf(720.0, w - 48.0), 92); feedback_label.size = Vector2(feedback_panel.size.x - 32.0, 72); goal_label.position = Vector2(24, 348); goal_label.size = Vector2(minf(900.0, w - 48.0), 48)

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, tab_names.size() - 1); action_scroll.scroll_vertical = 0; _refresh(); _show_feedback("TAB: %s\nChoose an action below." % tab_names[active_tab]); _update_panel_visibility()

func _button(text: String, callback: Callable) -> void:
    if not callback.is_valid(): return
    var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(225, 48); b.focus_mode = Control.FOCUS_NONE; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.pressed.connect(_run_action.bind(text, callback)); actions.add_child(b)

func _button_if_method(text: String, node: Node, method_name: String) -> void:
    if node != null and node.has_method(method_name): _button(text, Callable(node, method_name))

func _screen_button(text: String, screen_name: String) -> void:
    _button(text, Callable(self, "_open_screen").bind(screen_name))

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
        _show_feedback("OPENED: %s" % screen_name.replace("Panel", "").replace("UI", ""))
    else:
        _show_feedback("Screen manager is unavailable.")

func _run_action(label: String, callback: Callable) -> void:
    if parent == null or not callback.is_valid(): _show_feedback("%s\nAction is unavailable." % label); return
    var before_cash := int(parent.cash); var before_rep := int(parent.reputation); var before_day := int(parent.day); var before_goods := int(parent.finished_goods); var before_message := String(parent.message); var result: Variant = callback.call(); var message := ""
    if result is Dictionary and result.has("message"): message = String(result["message"])
    if message.is_empty() and String(parent.message) != before_message: message = String(parent.message)
    if message.is_empty(): message = "%s completed." % label
    var changes: Array[String] = []; var cash_change := int(parent.cash) - before_cash; var rep_change := int(parent.reputation) - before_rep; var goods_change := int(parent.finished_goods) - before_goods
    if cash_change != 0: changes.append("Cash %s$%s" % [("+" if cash_change > 0 else "-"), _money(abs(cash_change))])
    if rep_change != 0: changes.append("REP %s%d" % [("+" if rep_change > 0 else ""), rep_change])
    if goods_change != 0: changes.append("Goods %s%d" % [("+" if goods_change > 0 else ""), goods_change])
    if int(parent.day) != before_day: changes.append("Day %d" % int(parent.day))
    if not changes.is_empty(): message += "\n" + "  |  ".join(changes)
    _show_feedback(message); _refresh(); _detect_milestones()

func _set_world_visible(node: Node, value: bool) -> void:
    if node == null: return
    if node is CanvasItem:
        node.visible = value
    else:
        for child in node.get_children(): _set_world_visible(child, value)

func _update_panel_visibility() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
        match active_tab:
            1: manager.show_screen("CustomerSegmentsUI")
            2: manager.show_screen("AlliancePanel")
            3: manager.show_screen("CollectionPanel")

    var renew := get_tree().root.get_node_or_null("Renew")
    if renew != null:
        var world := renew.get_node_or_null("World")
        if world != null:
            _set_world_visible(world.get_node_or_null("WorldView"), active_tab == 3)
            _set_world_visible(world.get_node_or_null("PropertyVisual"), active_tab == 0)
            _set_world_visible(world.get_node_or_null("RegionController"), active_tab == 3)
            _set_world_visible(world.get_node_or_null("EmpireController"), active_tab == 2)
            _set_world_visible(world.get_node_or_null("Corporate"), active_tab == 2)
            _set_world_visible(world.get_node_or_null("WorldMissions"), active_tab == 3)
            _set_world_visible(world.get_node_or_null("RivalSupplyController"), active_tab == 3)
            _set_world_visible(world.get_node_or_null("BranchController"), active_tab in [1, 3])
            # MainRenderer is a legacy world overlay and would duplicate the
            # current presentation, so keep it disabled while the modern UI is active.
            _set_world_visible(world.get_node_or_null("MainRenderer"), false)

func _clear_actions() -> void:
    for child in actions.get_children(): child.queue_free()

func _refresh() -> void:
    if parent == null or actions == null: return
    _clear_actions()
    match active_tab:
        0:
            _button("INSPECT", parent.inspect_property); _button("ACQUIRE", parent.acquire_property); _button("RESTORE", parent.restore_property); _button("OPEN BUSINESS", parent.open_business); _button("END DAY", parent.advance_day)
            _screen_button("HEADQUARTERS", "HeadquartersPanel")
        1:
            _button("BUY INPUTS", parent.buy_inputs); _button("PRODUCE", parent.produce_goods); _button("HIRE", parent.hire_employee); _button("UPGRADE", parent.upgrade_business); _button("MARKETING", parent.marketing_campaign); _button("PRICE", parent.change_price); _button("SUPPLIER", parent.cycle_supplier); _button("CONTRACT", parent.sign_contract); _button("END DAY", parent.advance_day)
            _screen_button("CUSTOMERS", "CustomerSegmentsUI"); _screen_button("CONTRACTS", "ContractPanel"); _screen_button("EMPLOYEES", "EmployeePanel"); _screen_button("HEADQUARTERS", "HeadquartersPanel")
        2:
            _button("NEXT RIVAL", _next_rival); _button("NEXT ASSET", _next_asset); _button("EXPANSION", parent.buy_expansion); _button("UPGRADE ASSET", parent.upgrade_expansion); _button("ALLIANCE", parent.make_alliance_offer); _button("IMPROVE RELATION", parent.improve_alliance); _button("SUPPLY DEAL", parent.propose_supply_deal); _button("CUSTOMER DEAL", parent.propose_customer_partnership); _button("ACQUIRE ASSET", parent.negotiate_selected_acquisition); _button("UPGRADE TRANSPORT", parent.upgrade_transport); _button("LOAN", parent.take_loan); _button("REPAY LOAN", parent.repay_loan)
            _screen_button("ALLIANCE COUNCIL", "AlliancePanel"); _screen_button("TECHNOLOGY", "TechnologyPanel"); _screen_button("DIPLOMACY", "RenewDiplomacyUI"); _screen_button("HEADQUARTERS", "HeadquartersPanel")
            var corporate := get_node_or_null("../../World/Corporate"); _button_if_method("CORPORATE STATUS", corporate, "show_status"); _button_if_method("RAISE CAPITAL", corporate, "raise_capital"); _button_if_method("BUY BACK SHARES", corporate, "buyback_shares"); _button_if_method("DIVIDEND", corporate, "pay_dividend"); _button_if_method("DEFENSE", corporate, "strengthen_defense"); _button_if_method("ALLY DEFENSE", corporate, "strategic_ally_defense"); _button_if_method("BOARD INFLUENCE", corporate, "influence_board"); _button_if_method("HOSTILE TAKEOVER", corporate, "hostile_takeover"); _button("END DAY", parent.advance_day)
        3:
            var region := get_node_or_null("../../World/RegionController"); _button_if_method("ESTABLISH REGION", region, "establish_region"); _button_if_method("INFRASTRUCTURE", region, "upgrade_infrastructure"); _button_if_method("TRADE CORRIDOR", region, "establish_trade_route"); _button_if_method("DISPATCH GOODS", region, "dispatch_goods")
            var missions := get_node_or_null("../../World/WorldMissions"); _button_if_method("TAKE OPPORTUNITY", missions, "choose_a"); _button_if_method("DECLINE OPPORTUNITY", missions, "choose_b"); _button("DISTRICT", _next_district); _button("SAVE GAME", parent.save_game); _button("LOAD GAME", parent.load_game); _button("END DAY", parent.advance_day)
            _screen_button("COLLECTION", "CollectionPanel"); _screen_button("LIVE OPS", "LiveOpsPanel"); _screen_button("HISTORY", "HistoryPanel"); _screen_button("NEWS", "NewsPanel")

func _next_rival() -> void:
    if parent.rivals != null and not parent.rivals.rivals.is_empty(): parent.select_rival((int(parent.selected_rival)+1) % parent.rivals.rivals.size())
func _next_asset() -> void:
    if parent.expansion != null and not parent.expansion.properties.is_empty(): parent.select_expansion((int(parent.selected_expansion)+1) % parent.expansion.properties.size())
func _next_district() -> void:
    if parent.districts != null and not parent.districts.districts.is_empty(): parent.select_district((int(parent.selected_district)+1) % parent.districts.districts.size())
func _seed_milestones() -> void:
    observed_milestones = {"acquired":bool(parent.owned),"restored":str(parent.stage)=="Operational","opened":bool(parent.business_open),"profit":int(parent.total_profit)>0}
func _detect_milestones() -> void:
    var current := {"acquired":bool(parent.owned),"restored":str(parent.stage)=="Operational","opened":bool(parent.business_open),"profit":int(parent.total_profit)>0}; var text := {"acquired":"FIRST ASSET\nYou acquired your starting property.","restored":"REBUILDER\nThe warehouse is operational.","opened":"FIRST BUSINESS\nYour business is open.","profit":"FIRST PROFIT\nYour operating model is producing profit."}
    for id in current:
        if bool(current[id]) and not bool(observed_milestones.get(id,false)): observed_milestones[id]=true; _show_feedback("★ MILESTONE UNLOCKED\n"+String(text[id]))
func _show_day_report() -> void:
    var profit := int(parent.last_profit); var sign := "+" if profit >= 0 else "-"; _show_feedback("DAY %d RESULTS\nRevenue $%s  |  Profit %s$%s  |  Total profit $%s" % [int(parent.day)-1,_money(int(parent.last_sales)),sign,_money(abs(profit)),_money(int(parent.total_profit))])
func _update_goal_label() -> void:
    var goal := "GOAL: "
    if not parent.owned: goal += "Inspect and acquire the abandoned warehouse."
    elif str(parent.stage) != "Operational": goal += "Restore the warehouse before expanding."
    elif not parent.business_open: goal += "Open the business and start operating."
    elif int(parent.total_profit) < 10000: goal += "Build the operating model to $10,000 lifetime profit."
    else: goal += "Expand into regions, resources and stronger corporate control."
    goal_label.text = goal
func _show_feedback(text: String) -> void:
    feedback_label.text = text; feedback_panel.show(); feedback_timer = 7.0
func _money(value: int) -> String: return String.num_int64(value)
