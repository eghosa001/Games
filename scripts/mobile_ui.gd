extends CanvasLayer

# Mobile-first control surface. Actions are refreshed after the signal completes.
var parent: Node
var visible_mobile: bool = true
var active_tab: int = 0
var root: Control
var tabs: HBoxContainer
var actions: GridContainer
var action_scroll: ScrollContainer
var status_label: Label
var goal_label: Label
var feedback_panel: Panel
var feedback_label: Label
var feedback_timer: float = 0.0
var refresh_pending: bool = false
var tab_names: Array[String] = ["RESTORE", "BUSINESS", "EMPIRE", "WORLD"]
var observed_milestones: Dictionary = {}
var last_seen_day: int = 1

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    call_deferred("_initialize_after_parent_ready")

func _initialize_after_parent_ready() -> void:
    if parent == null: parent = get_tree().root.get_node_or_null("Renew")
    if parent == null: return
    if root != null:
        var vp_size: Vector2 = get_viewport().get_visible_rect().size
        if vp_size.x > 0: root.size = vp_size
    _refresh(); last_seen_day = int(parent.day); _seed_milestones()
    if root != null and not get_viewport().size_changed.is_connected(_layout_responsive): get_viewport().size_changed.connect(_layout_responsive)
    _layout_responsive()

func _process(delta: float) -> void:
    if parent == null or status_label == null: return
    status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    _update_goal_label(); _detect_milestones()
    if int(parent.day) != last_seen_day:
        last_seen_day = int(parent.day); _show_day_report()
    if feedback_timer > 0.0:
        feedback_timer -= delta
        if feedback_timer <= 0.0 and feedback_panel != null: feedback_panel.hide()

func _build_ui() -> void:
    root = Control.new(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    var top: ColorRect = ColorRect.new(); top.name = "TopBar"; top.color = Color("101820"); top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.position.y = 8; top.size.y = 54; top.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top)
    tabs = HBoxContainer.new(); tabs.position = Vector2(12, 12); tabs.size = Vector2(720, 46); tabs.add_theme_constant_override("separation", 8); tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tabs)
    for i: int in range(tab_names.size()):
        var button: Button = Button.new(); button.text = tab_names[i]; button.custom_minimum_size = Vector2(150, 44); button.focus_mode = Control.FOCUS_NONE; button.mouse_filter = Control.MOUSE_FILTER_STOP; button.pressed.connect(_set_tab.bind(i)); tabs.add_child(button)
    status_label = Label.new(); status_label.position = Vector2(760, 17); status_label.size = Vector2(500, 44); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; status_label.add_theme_font_size_override("font_size", 15); status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(status_label)
    goal_label = Label.new(); goal_label.position = Vector2(24, 348); goal_label.size = Vector2(900, 48); goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; goal_label.add_theme_font_size_override("font_size", 14); goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(goal_label)
    feedback_panel = Panel.new(); feedback_panel.position = Vector2(24, 245); feedback_panel.size = Vector2(720, 92); feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.hide(); root.add_child(feedback_panel)
    feedback_label = Label.new(); feedback_label.position = Vector2(16, 10); feedback_label.size = Vector2(688, 72); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback_label.add_theme_font_size_override("font_size", 15); feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.add_child(feedback_label)
    var bottom: ColorRect = ColorRect.new(); bottom.color = Color("101820"); bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bottom.position.y = -150; bottom.size.y = 150; bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bottom)
    action_scroll = ScrollContainer.new(); action_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT); action_scroll.position = Vector2(18, 72); action_scroll.size = Vector2(1240, 160); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; action_scroll.focus_mode = Control.FOCUS_NONE; action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(action_scroll)
    actions = GridContainer.new(); actions.columns = 3; actions.custom_minimum_size = Vector2(720, 0); actions.add_theme_constant_override("h_separation", 10); actions.add_theme_constant_override("v_separation", 8); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE; action_scroll.add_child(actions)

func _layout_responsive() -> void:
    if root == null or tabs == null or action_scroll == null or actions == null: return
    var w: float = maxf(root.size.x, 320.0); var narrow: bool = w < 700.0; var tab_width: float = maxf(70.0, (w - 48.0) / 4.0)
    tabs.position = Vector2(12, 12); tabs.size = Vector2(w - 24.0, 46)
    for child: Node in tabs.get_children():
        var tab: Button = child as Button
        if tab != null: tab.custom_minimum_size = Vector2(tab_width, 44)
    if narrow:
        status_label.position = Vector2(12, 60); status_label.size = Vector2(w - 24.0, 30); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        action_scroll.position = Vector2(12, 94); action_scroll.size = Vector2(w - 24.0, 150); actions.columns = 2; actions.custom_minimum_size = Vector2(w - 24.0, 0)
        var button_width: float = maxf(120.0, (w - 34.0) / 2.0)
        for child: Node in actions.get_children():
            var action_button: Button = child as Button
            if action_button != null: action_button.custom_minimum_size = Vector2(button_width, 48)
        feedback_panel.position = Vector2(12, 252); feedback_panel.size = Vector2(w - 24.0, 96); feedback_label.size = Vector2(w - 56.0, 76); goal_label.position = Vector2(12, 354); goal_label.size = Vector2(w - 24.0, 58)
    else:
        status_label.position = Vector2(maxf(730.0, w - 520.0), 17); status_label.size = Vector2(minf(500.0, w - maxf(730.0, w - 520.0) - 12.0), 44); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        action_scroll.position = Vector2(18, 72); action_scroll.size = Vector2(w - 36.0, 160); actions.columns = 3; actions.custom_minimum_size = Vector2(maxf(720.0, w - 36.0), 0)
        for child: Node in actions.get_children():
            var action_button: Button = child as Button
            if action_button != null: action_button.custom_minimum_size = Vector2(225, 48)
        feedback_panel.position = Vector2(24, 245); feedback_panel.size = Vector2(minf(720.0, w - 48.0), 92); feedback_label.size = Vector2(feedback_panel.size.x - 32.0, 72); goal_label.position = Vector2(24, 348); goal_label.size = Vector2(minf(900.0, w - 48.0), 48)

func _set_tab(index: int) -> void:
    var target: int = clampi(index, 0, tab_names.size() - 1)
    active_tab = target; action_scroll.scroll_vertical = 0; _refresh(); _show_feedback("TAB: %s\nChoose an action below." % tab_names[active_tab])
func _clear_actions() -> void:
    for child: Node in actions.get_children(): actions.remove_child(child); child.queue_free()
func _button(text: String, callback: Callable) -> void:
    var b: Button = Button.new(); b.text = text; b.custom_minimum_size = Vector2(225, 48); b.focus_mode = Control.FOCUS_NONE; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.pressed.connect(_run_action.bind(text, callback)); actions.add_child(b)
func _run_action(label: String, callback: Callable) -> void:
    if not callback.is_valid(): _show_feedback("%s\nAction is currently unavailable." % label); return
    var before_cash: int = int(parent.cash); var before_rep: int = int(parent.reputation); var before_day: int = int(parent.day); var before_goods: int = int(parent.finished_goods); var before_message: String = String(parent.message)
    var result: Variant = callback.call(); var message: String = ""
    if result is Dictionary and result.has("message"): message = String(result["message"])
    if message.is_empty(): message = _callback_message(callback, before_message)
    if message.is_empty(): message = "%s completed." % label
    var changes: Array[String] = []; var cash_change: float = float(int(parent.cash) - before_cash); var rep_change: int = int(parent.reputation) - before_rep; var goods_change: int = int(parent.finished_goods) - before_goods
    if cash_change != 0: changes.append("Cash %s$%s" % [("+" if cash_change > 0 else "-"), _money(abs(int(cash_change)))])
    if rep_change != 0: changes.append("REP %s%d" % [("+" if rep_change > 0 else ""), rep_change])
    if goods_change != 0: changes.append("Goods %s%d" % [("+" if goods_change > 0 else ""), goods_change])
    if int(parent.day) != before_day: changes.append("Day %d" % int(parent.day))
    if changes.size() > 0: message += "\n" + "  |  ".join(changes)
    _show_feedback(message); _pulse_feedback(); _refresh(); _detect_milestones()
func _callback_message(callback: Callable, before_parent_message: String) -> String:
    var parent_message: String = String(parent.message)
    if not parent_message.is_empty() and parent_message != before_parent_message: return parent_message
    var target: Object = callback.get_object()
    if target != null and "message" in target:
        var controller_message: String = String(target.message)
        if not controller_message.is_empty(): return controller_message
    return ""
func _queue_refresh() -> void:
    if refresh_pending: return
    refresh_pending = true; call_deferred("_deferred_refresh")
func _deferred_refresh() -> void:
    refresh_pending = false; _refresh()
func _show_feedback(text: String) -> void:
    if feedback_panel == null or feedback_label == null: return
    feedback_label.text = text; feedback_panel.show(); feedback_timer = 5.0
func _pulse_feedback() -> void:
    if feedback_panel == null: return
    feedback_panel.scale = Vector2(0.98, 0.98); var tween: Tween = create_tween(); tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tween.tween_property(feedback_panel, "scale", Vector2.ONE, 0.22)
func _seed_milestones() -> void:
    observed_milestones = {"acquired": bool(parent.owned), "restored": str(parent.stage) == "Operational", "opened": bool(parent.business_open), "profit": int(parent.total_profit) > 0, "regional": _regional_reached(), "empire": _empire_reached()}
func _detect_milestones() -> void:
    var current: Dictionary = {"acquired": bool(parent.owned), "restored": str(parent.stage) == "Operational", "opened": bool(parent.business_open), "profit": int(parent.total_profit) > 0, "regional": _regional_reached(), "empire": _empire_reached()}
    var celebrations: Dictionary = {"acquired":"FIRST ASSET\nYou turned an abandoned property into something you own.", "restored":"REBUILDER\nThe warehouse is fully restored. Your first transformation is complete.", "opened":"FIRST BUSINESS\nRENEW Goods is open. Now prove the business can make money.", "profit":"FIRST PROFIT\nThe model works. Reinvest the profit and keep growing.", "regional":"GOING REGIONAL\nYour company has expanded beyond its original neighborhood.", "empire":"EMPIRE BUILDER\nMultiple assets are now working together."}
    for id: String in current:
        if bool(current[id]) and not bool(observed_milestones.get(id, false)): observed_milestones[id] = true; _show_feedback("★ MILESTONE UNLOCKED\n" + String(celebrations[id])); _pulse_feedback()
func _regional_reached() -> bool:
    var region: Node = parent.get_node_or_null("RegionController")
    if region == null or region.regions == null: return false
    return int(region.regions.player_presence.count(1)) > 1
func _empire_reached() -> bool:
    if parent == null or parent.expansion == null: return false
    var count: int = 0
    for p: Variant in parent.expansion.properties:
        if bool(p.get("owned", false)): count += 1
    for site: Variant in parent.expansion.resource_sites:
        if bool(site.get("owned", false)): count += 1
    return count >= 3
func _show_day_report() -> void:
    var profit: int = int(parent.last_profit); var result: String = "PROFIT" if profit >= 0 else "LOSS"; var sign: String = "+" if profit >= 0 else "-"; var contract_text: String = ""
    if int(parent.contract_days) > 0: contract_text = "\nContract: %d days remaining" % int(parent.contract_days)
    _show_feedback("DAY %d RESULTS\nRevenue $%s  |  %s %s$%s  |  Total profit $%s%s" % [int(parent.day) - 1, _money(int(parent.last_sales)), result, sign, _money(abs(profit)), _money(int(parent.total_profit)), contract_text]); _pulse_feedback()
func _update_goal_label() -> void:
    if goal_label == null: return
    var goal: String = "GOAL: "
    if not bool(parent.owned): goal += "Inspect and acquire the abandoned warehouse."
    elif str(parent.stage) != "Operational": goal += "Finish restoring the warehouse."
    elif not bool(parent.business_open): goal += "Open RENEW Goods with $3,000 working capital."
    elif int(parent.finished_goods) < 5: goal += "Buy inputs and produce at least 5 goods."
    elif int(parent.total_profit) <= 0: goal += "Close a profitable operating day."
    elif int(parent.acquisition_count) < 1: goal += "Expand into your first new asset."
    elif not _regional_reached(): goal += "Establish a foothold in another region."
    else: goal += "Keep scaling: own resources, build alliances and challenge the giants."
    goal_label.text = goal
func _refresh() -> void:
    if parent == null or actions == null: return
    _clear_actions(); status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    match active_tab:
        0:
            var restoration_strategy: Node = get_node_or_null("../RestorationStrategy")
            if restoration_strategy != null: _button("BUDGET RESTORE", restoration_strategy.choose_budget); _button("STANDARD RESTORE", restoration_strategy.choose_standard); _button("PREMIUM RESTORE", restoration_strategy.choose_premium)
            _button("INSPECT", parent.inspect_property); _button("ACQUIRE", parent.acquire_property); _button("RESTORE", parent.restore_property); _button("OPEN BUSINESS", parent.open_business); _button("END DAY", parent.advance_day)
        1:
            _button("BUY INPUTS", parent.buy_inputs); _button("PRODUCE", parent.produce_goods); _button("HIRE", parent.hire_employee); _button("UPGRADE", parent.upgrade_business); _button("MARKETING", parent.marketing_campaign); _button("PRICE", parent.change_price); _button("SUPPLIER", parent.cycle_supplier); _button("CONTRACT", parent.sign_contract); _button("END DAY", parent.advance_day)
        2:
            _button("NEXT RIVAL", _next_rival); _button("NEXT ASSET", _next_asset); _button("EXPANSION", parent.buy_expansion); _button("UPGRADE BUSINESS", parent.upgrade_expansion); _button("ALLIANCE", parent.make_alliance_offer); _button("IMPROVE RELATION", parent.improve_alliance); _button("SUPPLY DEAL", parent.propose_supply_deal); _button("CUSTOMER DEAL", parent.propose_customer_partnership); _button("ACQUIRE ASSET", parent.negotiate_selected_acquisition)
            var supply_controller: Node = get_node_or_null("../SupplyChainController")
            if supply_controller != null: _button("MOVE RESOURCE", supply_controller.supply_resource_to_network); _button("SUPPLY ASSET", supply_controller.supply_selected_expansion); _button("SUPPLIER CONTRACT", supply_controller.negotiate_supplier_contract); _button("SECURE RESOURCE", supply_controller.secure_resource_rights); _button("BUY IRON", supply_controller.market_buy.bind("iron")); _button("BUY TIMBER", supply_controller.market_buy.bind("timber"))
            var corporate: Node = get_node_or_null("../Corporate")
            if corporate != null: _button("CORPORATE STATUS", corporate.show_status); _button("RAISE CAPITAL", corporate.raise_capital); _button("BUY BACK SHARES", corporate.buyback_shares); _button("DIVIDEND", corporate.pay_dividend); _button("DEFENSE", corporate.strengthen_defense); _button("ALLY DEFENSE", corporate.strategic_ally_defense); _button("BOARD INFLUENCE", corporate.influence_board); _button("HOSTILE TAKEOVER", corporate.hostile_takeover)
            _button("LOAN", parent.take_loan); _button("REPAY LOAN", parent.repay_loan); _button("END DAY", parent.advance_day)
        3:
            var region_controller: Node = get_node_or_null("../RegionController")
            if region_controller != null: _button("NEXT REGION", _next_region); _button("PREVIOUS REGION", _previous_region); _button("ESTABLISH", region_controller.establish_region); _button("INFRASTRUCTURE", region_controller.upgrade_infrastructure); _button("TRADE CORRIDOR", region_controller.establish_trade_route); _button("DISPATCH GOODS", region_controller.dispatch_goods)
            var missions: Node = get_node_or_null("../WorldMissions")
            if missions != null: _button("TAKE OPPORTUNITY", missions.choose_a); _button("DECLINE OPPORTUNITY", missions.choose_b)
            var market: Node = get_node_or_null("../MarketDirector")
            if market != null: _button("MARKET AGGRESSIVE", market.respond_aggressively); _button("MARKET BALANCED", market.respond_balanced); _button("MARKET DEFENSIVE", market.respond_defensively)
            _button("DISTRICT", _next_district); _button("SAVE GAME", parent.save_game); _button("LOAD GAME", parent.load_game); _button("END DAY", parent.advance_day)
func _next_rival() -> void:
    var count: int = int(parent.rivals.rivals.size())
    if count > 0: parent.select_rival((int(parent.selected_rival) + 1) % count)
func _next_asset() -> void:
    var count: int = int(parent.expansion.properties.size())
    if count > 0: parent.select_expansion((int(parent.selected_expansion) + 1) % count)
func _next_region() -> void:
    var controller: Node = get_node_or_null("../RegionController")
    if controller != null: controller.select_region((int(controller.regions.selected) + 1) % int(controller.regions.regions.size()))
func _previous_region() -> void:
    var controller: Node = get_node_or_null("../RegionController")
    if controller != null:
        var count: int = int(controller.regions.regions.size())
        if count > 0: controller.select_region((int(controller.regions.selected) - 1 + count) % count)
func _next_district() -> void:
    var count: int = int(parent.districts.districts.size())
    if count > 0: parent.select_district((int(parent.selected_district) + 1) % count)
func _money(value: int) -> String: return str(value)
