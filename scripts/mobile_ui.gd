extends CanvasLayer

# Mobile-first control surface. Actions are refreshed after the signal completes.
var parent: Node
var visible_mobile := true
var active_tab := 0
var root: Control
var tabs: HBoxContainer
var actions: GridContainer
var action_scroll: ScrollContainer
var status_label: Label
var feedback_panel: Panel
var feedback_label: Label
var feedback_timer := 0.0
var refresh_pending := false
var tab_names := ["RESTORE", "BUSINESS", "EMPIRE", "WORLD"]

func _ready() -> void:
    parent = get_parent(); _build_ui(); _refresh()
    root.resized.connect(_layout_responsive)
    _layout_responsive()

func _process(delta: float) -> void:
    if parent == null or status_label == null: return
    status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    if feedback_timer > 0.0:
        feedback_timer -= delta
        if feedback_timer <= 0.0 and feedback_panel != null: feedback_panel.hide()

func _build_ui() -> void:
    root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    var top := ColorRect.new(); top.name = "TopBar"; top.color = Color("101820"); top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.position.y = 8; top.size.y = 54; top.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top)
    tabs = HBoxContainer.new(); tabs.position = Vector2(12, 12); tabs.size = Vector2(720, 46); tabs.add_theme_constant_override("separation", 8); tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tabs)
    for i in range(tab_names.size()):
        var button := Button.new(); button.text = tab_names[i]; button.custom_minimum_size = Vector2(150, 44); button.focus_mode = Control.FOCUS_NONE; button.mouse_filter = Control.MOUSE_FILTER_STOP; button.pressed.connect(_set_tab.bind(i)); tabs.add_child(button)
    status_label = Label.new(); status_label.position = Vector2(760, 17); status_label.size = Vector2(500, 44); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; status_label.add_theme_font_size_override("font_size", 15); status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(status_label)
    feedback_panel = Panel.new(); feedback_panel.position = Vector2(24, 245); feedback_panel.size = Vector2(720, 92); feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.hide(); root.add_child(feedback_panel)
    feedback_label = Label.new(); feedback_label.position = Vector2(16, 10); feedback_label.size = Vector2(688, 72); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback_label.add_theme_font_size_override("font_size", 15); feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.add_child(feedback_label)
    var bottom := ColorRect.new(); bottom.color = Color("101820"); bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bottom.position.y = -150; bottom.size.y = 150; bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bottom)
    # Keep actions in the visible middle of the screen. The layout is resized for
    # portrait phones so buttons do not disappear off the right edge.
    action_scroll = ScrollContainer.new(); action_scroll.set_anchors_preset(Control.PRESET_TOP_WIDE); action_scroll.position = Vector2(18, 72); action_scroll.size = Vector2(1240, 160); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; action_scroll.focus_mode = Control.FOCUS_NONE; action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(action_scroll)
    actions = GridContainer.new(); actions.columns = 3; actions.custom_minimum_size = Vector2(720, 0); actions.add_theme_constant_override("h_separation", 10); actions.add_theme_constant_override("v_separation", 8); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE; action_scroll.add_child(actions)

func _layout_responsive() -> void:
    if root == null or tabs == null or action_scroll == null or actions == null: return
    var w := maxf(root.size.x, 320.0)
    var narrow := w < 700.0
    var tab_width := maxf(70.0, (w - 48.0) / 4.0)
    tabs.position = Vector2(12, 12)
    tabs.size = Vector2(w - 24.0, 46)
    for child in tabs.get_children():
        if child is Button: child.custom_minimum_size = Vector2(tab_width, 44)
    if narrow:
        status_label.position = Vector2(12, 60)
        status_label.size = Vector2(w - 24.0, 30)
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        action_scroll.position = Vector2(12, 94)
        action_scroll.size = Vector2(w - 24.0, 150)
        actions.columns = 2
        actions.custom_minimum_size = Vector2(w - 24.0, 0)
        var button_width := maxf(120.0, (w - 34.0) / 2.0)
        for child in actions.get_children():
            if child is Button: child.custom_minimum_size = Vector2(button_width, 48)
        feedback_panel.position = Vector2(12, 252)
        feedback_panel.size = Vector2(w - 24.0, 96)
        feedback_label.size = Vector2(w - 56.0, 76)
    else:
        status_label.position = Vector2(maxf(730.0, w - 520.0), 17)
        status_label.size = Vector2(minf(500.0, w - maxf(730.0, w - 520.0) - 12.0), 44)
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        action_scroll.position = Vector2(18, 72)
        action_scroll.size = Vector2(w - 36.0, 160)
        actions.columns = 3
        actions.custom_minimum_size = Vector2(maxf(720.0, w - 36.0), 0)
        for child in actions.get_children():
            if child is Button: child.custom_minimum_size = Vector2(225, 48)
        feedback_panel.position = Vector2(24, 245)
        feedback_panel.size = Vector2(minf(720.0, w - 48.0), 92)
        feedback_label.size = Vector2(feedback_panel.size.x - 32.0, 72)

func _set_tab(index: int) -> void:
    active_tab = index; action_scroll.scroll_vertical = 0; _refresh(); _show_feedback("TAB: %s\nChoose an action below." % tab_names[index])

func _clear_actions() -> void:
    for child in actions.get_children(): child.queue_free()

func _button(text: String, callback: Callable) -> void:
    var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(225, 48); b.focus_mode = Control.FOCUS_NONE; b.mouse_filter = Control.MOUSE_FILTER_STOP; b.pressed.connect(_run_action.bind(text, callback)); actions.add_child(b)

func _run_action(label: String, callback: Callable) -> void:
    if not callback.is_valid(): _show_feedback("%s\nAction is currently unavailable." % label); return
    var before_cash := int(parent.cash); var before_rep := int(parent.reputation); var before_day := int(parent.day); var before_goods := int(parent.finished_goods); var before_message := String(parent.message)
    var result = callback.call(); var message := ""
    if result is Dictionary and result.has("message"): message = String(result["message"])
    if message.is_empty(): message = _callback_message(callback, before_message)
    if message.is_empty(): message = "%s completed." % label
    var changes: Array[String] = []; var cash_change := int(parent.cash) - before_cash; var rep_change := int(parent.reputation) - before_rep; var goods_change := int(parent.finished_goods) - before_goods
    if cash_change != 0: changes.append("Cash %s$%s" % [("+" if cash_change > 0 else "-"), _money(abs(cash_change))])
    if rep_change != 0: changes.append("REP %s%d" % [("+" if rep_change > 0 else ""), rep_change])
    if goods_change != 0: changes.append("Goods %s%d" % [("+" if goods_change > 0 else ""), goods_change])
    if int(parent.day) != before_day: changes.append("Day %d" % int(parent.day))
    if changes.size() > 0: message += "\n" + "  |  ".join(changes)
    _show_feedback(message); _queue_refresh()

func _callback_message(callback: Callable, before_parent_message: String) -> String:
    var parent_message := String(parent.message)
    if not parent_message.is_empty() and parent_message != before_parent_message: return parent_message
    var target = callback.get_object()
    if target != null and "message" in target:
        var controller_message := String(target.message)
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

func _refresh() -> void:
    if parent == null or actions == null: return
    _clear_actions(); status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    match active_tab:
        0:
            var restoration_strategy = get_node_or_null("../RestorationStrategy")
            if restoration_strategy != null:
                _button("BUDGET RESTORE", restoration_strategy.choose_budget); _button("STANDARD RESTORE", restoration_strategy.choose_standard); _button("PREMIUM RESTORE", restoration_strategy.choose_premium)
            _button("INSPECT", parent.inspect_property); _button("ACQUIRE", parent.acquire_property); _button("RESTORE", parent.restore_property); _button("OPEN BUSINESS", parent.open_business); _button("END DAY", parent.advance_day)
        1:
            _button("BUY INPUTS", parent.buy_inputs); _button("PRODUCE", parent.produce_goods); _button("HIRE", parent.hire_employee); _button("UPGRADE", parent.upgrade_business); _button("MARKETING", parent.marketing_campaign); _button("PRICE", parent.change_price); _button("SUPPLIER", parent.cycle_supplier); _button("CONTRACT", parent.sign_contract); _button("END DAY", parent.advance_day)
        2:
            _button("NEXT RIVAL", _next_rival); _button("NEXT ASSET", _next_asset); _button("EXPANSION", parent.buy_expansion); _button("UPGRADE BUSINESS", parent.upgrade_expansion); _button("ALLIANCE", parent.make_alliance_offer); _button("IMPROVE RELATION", parent.improve_alliance); _button("SUPPLY DEAL", parent.propose_supply_deal); _button("CUSTOMER DEAL", parent.propose_customer_partnership); _button("ACQUIRE ASSET", parent.negotiate_selected_acquisition)
            var supply_controller = get_node_or_null("../SupplyChainController")
            if supply_controller != null:
                _button("MOVE RESOURCE", supply_controller.supply_resource_to_network); _button("SUPPLY ASSET", supply_controller.supply_selected_expansion); _button("SUPPLIER CONTRACT", supply_controller.negotiate_supplier_contract); _button("SECURE RESOURCE", supply_controller.secure_resource_rights); _button("BUY MATERIALS", supply_controller.market_buy.bind("materials")); _button("BUY PACKAGING", supply_controller.market_buy.bind("packaging"))
            var corporate = get_node_or_null("../Corporate")
            if corporate != null:
                _button("CORPORATE STATUS", corporate.show_status); _button("RAISE CAPITAL", corporate.raise_capital); _button("BUY BACK SHARES", corporate.buyback_shares); _button("DIVIDEND", corporate.pay_dividend); _button("DEFENSE", corporate.strengthen_defense); _button("ALLY DEFENSE", corporate.strategic_ally_defense); _button("BOARD INFLUENCE", corporate.influence_board); _button("HOSTILE TAKEOVER", corporate.hostile_takeover)
            _button("LOAN", parent.take_loan); _button("REPAY LOAN", parent.repay_loan); _button("END DAY", parent.advance_day)
        3:
            var region_controller = get_node_or_null("../RegionController")
            if region_controller != null:
                _button("NEXT REGION", _next_region); _button("PREVIOUS REGION", _previous_region); _button("ESTABLISH", region_controller.establish_region); _button("INFRASTRUCTURE", region_controller.upgrade_infrastructure); _button("TRADE CORRIDOR", region_controller.establish_trade_route); _button("DISPATCH GOODS", region_controller.dispatch_goods)
            var missions = get_node_or_null("../WorldMissions")
            if missions != null: _button("TAKE OPPORTUNITY", missions.choose_a); _button("DECLINE OPPORTUNITY", missions.choose_b)
            var market = get_node_or_null("../MarketDirector")
            if market != null: _button("MARKET AGGRESSIVE", market.respond_aggressively); _button("MARKET BALANCED", market.respond_balanced); _button("MARKET DEFENSIVE", market.respond_defensively)
            _button("DISTRICT", _next_district); _button("SAVE GAME", parent.save_game); _button("LOAD GAME", parent.load_game); _button("END DAY", parent.advance_day)

func _next_rival() -> void:
    var count: int = int(parent.rivals.rivals.size())
    if count > 0: parent.select_rival((int(parent.selected_rival) + 1) % count)
func _next_asset() -> void:
    var count: int = int(parent.expansion.properties.size())
    if count > 0: parent.select_expansion((int(parent.selected_expansion) + 1) % count)
func _next_region() -> void:
    var controller = get_node_or_null("../RegionController")
    if controller != null: controller.select_region((int(controller.regions.selected) + 1) % int(controller.regions.regions.size()))
func _previous_region() -> void:
    var controller = get_node_or_null("../RegionController")
    if controller != null:
        var count: int = int(controller.regions.regions.size())
        if count > 0: controller.select_region((int(controller.regions.selected) - 1 + count) % count)
func _next_district() -> void:
    var count: int = int(parent.districts.districts.size())
    if count > 0: parent.select_district((int(parent.selected_district) + 1) % count)
func _money(value: int) -> String: return str(value)
