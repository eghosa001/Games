extends "res://scripts/renew_sims_ui.gd"

const ACTIVE_TAB := Color("d7b86f")
const INACTIVE_TAB := Color("102a32")
const TAB_TEXT := Color("e7f2ef")
const TAB_MUTED := Color("78949a")
const HUD_REFRESH_INTERVAL := 0.20
const MAX_PAGE_ACTIONS := 5

var _hud_refresh_accum := 0.0
var _page := [0, 0, 0, 0]

# Every sector has a hub plus deliberately small task pages. No operational page
# exposes more than five task buttons; BACK is the only navigation affordance.
const PAGE_NAMES := [
    ["OVERVIEW", "PROPERTY", "OWNERSHIP", "RECORDS"],
    ["OVERVIEW", "PRODUCTION", "BUSINESS", "PEOPLE", "COMMERCIAL", "CONTRACTS", "FINANCE", "FUNDING"],
    ["OVERVIEW", "RIVALS", "ALLIANCES", "CORPORATE", "GROWTH", "REGIONS", "CAPITAL", "EQUITY", "TECHNOLOGY"],
    ["OVERVIEW", "REGIONAL MANAGEMENT", "OPERATIONS", "EMPIRE MANAGEMENT", "EVENTS"]
]

const PAGE_SUBTITLES := [
    [
        "Company overview and the next essential move.",
        "Inspect, restore and prepare the selected property.",
        "Acquire, sell, lease and open the selected property.",
        "Save, load and review company history and world news."
    ],
    [
        "Choose a focused business command area.",
        "Inputs, imports, production and pricing.",
        "Business upgrades and marketing.",
        "Employees and headquarters management.",
        "Customers and the commercial desk.",
        "Contract signing and negotiation.",
        "Finance, collections and portfolio.",
        "Loans, investors and investment decisions."
    ],
    [
        "Choose a focused empire command area.",
        "Rival selection, competition and reputation.",
        "Alliances, relationships and supply agreements.",
        "Corporate network, victory and world power.",
        "Strategic growth and acquisitions.",
        "Regions, charters and trade routes.",
        "Loans, investors and public-market capital.",
        "Shares, dividends and capitalization.",
        "Technology, progression and corporate identity."
    ],
    [
        "Choose a focused world command area.",
        "Regions and infrastructure are managed here only.",
        "World production and logistics commands.",
        "Empire expansion and intelligence.",
        "Missions and live operations."
    ]
]

func _style_mode_buttons() -> void:
    if mode_buttons.is_empty(): return
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i] as Button
        if button == null: continue
        var normal := StyleBoxFlat.new()
        normal.bg_color = ACTIVE_TAB if i == active_tab else INACTIVE_TAB
        normal.border_color = ACTIVE_TAB if i == active_tab else Color("24434b")
        normal.set_border_width_all(1)
        normal.set_corner_radius_all(8)
        normal.content_margin_left = 6
        normal.content_margin_right = 6
        normal.content_margin_top = 5
        normal.content_margin_bottom = 5
        var hover := normal.duplicate()
        hover.bg_color = Color("183b43")
        hover.border_color = ACTIVE_TAB
        var pressed := hover.duplicate()
        pressed.bg_color = Color("244f50")
        button.add_theme_stylebox_override("normal", normal)
        button.add_theme_stylebox_override("hover", hover)
        button.add_theme_stylebox_override("pressed", pressed)
        button.add_theme_color_override("font_color", TAB_TEXT if i == active_tab else TAB_MUTED)
        button.add_theme_color_override("font_hover_color", Color.WHITE)
        button.add_theme_font_size_override("font_size", 10 if root.size.x < 390.0 else 11)
        button.custom_minimum_size = Vector2(44, 44)

func _layout_responsive() -> void:
    super._layout_responsive()
    if root == null: return
    var s := root.size
    var w := maxf(s.x, 320.0)
    var h := maxf(s.y, 480.0)
    _style_mode_buttons()
    if mode_rail != null:
        mode_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for child in mode_rail.get_children():
            if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for button in mode_buttons:
            if button is Control: button.mouse_filter = Control.MOUSE_FILTER_STOP
    if not narrow: return
    mode_rail.visible = true
    mode_rail.position = Vector2(8, 64)
    mode_rail.size = Vector2(w - 16, 44)
    var dock_height := clampf(h * 0.40, 218.0, 250.0)
    var dock_top := maxf(114.0, h - dock_height - 8.0)
    action_dock.visible = true
    action_dock.position = Vector2(8, dock_top)
    action_dock.size = Vector2(w - 16, h - dock_top - 8.0)
    action_title.position = Vector2(10, 7)
    action_title.size = Vector2(w - 36, 20)
    action_subtitle.position = Vector2(10, 27)
    action_subtitle.size = Vector2(w - 36, 20)
    action_scroll.position = Vector2(8, 50)
    action_scroll.size = Vector2(w - 32, maxf(132.0, action_dock.size.y - 58.0))
    action_grid.columns = 2
    var gap := 8.0
    var button_width := maxf(0.0, (action_scroll.size.x - gap - 8.0) / 2.0)
    for child in action_grid.get_children():
        if child is Button:
            child.custom_minimum_size = Vector2(button_width, 44.0)
            child.size_flags_horizontal = Control.SIZE_FILL
    bottom_mobile.visible = false
    mobile_actions.visible = false
    mobile_objective.visible = false
    left_rail.visible = false
    selected_card.visible = false
    objective_card.visible = false
    if right_card != null: right_card.visible = false
    network_strip.visible = false
    top_strip.position = Vector2(8, 8)
    top_strip.size = Vector2(w - 16, 50)
    brand.position = Vector2(9, 3)
    brand.size = Vector2(70, 30)
    brand.add_theme_font_size_override("font_size", 18 if w >= 380.0 else 16)
    location_label.visible = false
    day_label.visible = true
    var compact := w < 390.0
    cash_label.position = Vector2(w - (205.0 if compact else 230.0), 5)
    cash_label.size = Vector2(68.0 if compact else 80.0, 28)
    rep_label.position = Vector2(w - (130.0 if compact else 150.0), 5)
    rep_label.size = Vector2(62.0 if compact else 70.0, 28)
    day_label.position = Vector2(w - 62.0, 5)
    day_label.size = Vector2(58.0, 28)
    cash_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    rep_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    day_label.add_theme_font_size_override("font_size", 10)

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3)
    _page[active_tab] = 0
    _refresh()
    _style_mode_buttons()

func _action(text: String, callback: Callable) -> void:
    super._action(text, callback)
    if action_grid == null or action_grid.get_child_count() == 0: return
    var button := action_grid.get_child(action_grid.get_child_count() - 1) as Button
    if button == null: return
    button.tooltip_text = _action_hint(text)
    button.add_theme_font_size_override("font_size", 10 if narrow else 11)

func _action_hint(text: String) -> String:
    match text:
        "END DAY": return "Advance the simulation by one in-game day."
        "BACK": return "Return to this sector's command hub."
        "DASHBOARD": return "Open the company overview."
        "PROPERTY MAP": return "Focus the property and district map."
        "INSPECT": return "Inspect the selected property."
        "ACQUIRE": return "Acquire the selected property."
        "RESTORE": return "Continue restoring the selected property."
        "SELL": return "Sell the selected property."
        "LEASE": return "Lease the selected property."
        "OPEN BUSINESS": return "Open the business at the selected property."
        "SAVE": return "Save your current company state."
        "LOAD": return "Load the latest saved company state."
        "PAST": return "Review company history."
        "NEWS": return "Review current world news."
        "BUY INPUTS": return "Purchase production inputs."
        "IMPORT": return "Purchase international inputs."
        "PRODUCE": return "Run the production command."
        "UPGRADE": return "Upgrade the current business."
        "MARKETING": return "Run a marketing campaign."
        "PRICE": return "Change the current product price."
        "STAFF": return "Manage employees."
        "HIRE": return "Hire an employee."
        "HQ": return "Manage headquarters upgrades and services."
        "CUSTOMERS": return "Review customer segments and demand."
        "DEALS": return "Review contracts and commercial deals."
        "CONTRACT": return "Sign a commercial contract."
        "HAGGLE": return "Negotiate the selected contract."
        "EXCLUSIVE": return "Sign an exclusive contract."
        "GOVT DEAL": return "Sign a government contract."
        "BUILD DEAL": return "Sign a construction contract."
        "EXPORT DEAL": return "Sign an export contract."
        "FINANCE": return "Open financing tools."
        "COLLECTIONS": return "Open collections management."
        "PORTFOLIO": return "Review investments and holdings."
        "NEXT RIVAL": return "Select the next rival."
        "ALLIANCE": return "Make an alliance offer."
        "RELATION": return "Improve an alliance relationship."
        "COMPETE": return "Compete against an alliance."
        "GOALS": return "Review victory progress."
        "REPUTE": return "Review reputation status."
        "SUPPLY DEAL": return "Propose a supply deal."
        "NETWORK": return "Open the corporate network."
        "PACT": return "Open alliance management."
        "CORPORATIONS": return "Open corporation management."
        "REGIONS": return "Open regional management."
        "EXPANSION": return "Manage expansion businesses."
        "ACQUISITIONS": return "Review and negotiate acquisitions."
        "UPGRADE EXPANSION": return "Upgrade an expansion business."
        "TRANSPORT": return "Upgrade empire transport."
        "NEXT REGION": return "Select the next region."
        "ESTABLISH": return "Establish regional presence."
        "CHARTER BASIN": return "Charter the basin region."
        "CHARTER VALLEY": return "Charter the valley region."
        "TRADE ROUTE": return "Establish a trade route."
        "INTELLIGENCE": return "Review empire intelligence."
        "LOAN": return "Take a company loan."
        "REPAY": return "Repay a company loan."
        "INVESTOR": return "Request an investment."
        "ACCEPT DEAL": return "Accept an investment deal."
        "DECLINE DEAL": return "Decline an investment deal."
        "INVEST BILL": return "Invest in a term opportunity."
        "DIVIDEND": return "Pay a dividend."
        "BUY SHARES": return "Buy rival shares."
        "SELL SHARES": return "Sell rival shares."
        "GO PUBLIC": return "Take the company public."
        "CAP TABLE": return "Review the capitalization table."
        "POWER": return "Review world corporate power."
        "TECH": return "Open technology management."
        "PROGRESSION": return "Review empire progression."
        "IDENTITY": return "Review corporate identity."
        "PRODUCTION": return "Open production command center."
        "LOGISTICS": return "Manage supply chain and logistics."
        "INFRASTRUCTURE": return "Build and repair regional infrastructure."
        "MISSIONS": return "Review world opportunities and missions."
        "LIVE OPS": return "Review seasonal events and live operations."
        _:
            return "Execute %s." % text.to_lower()

func _tab_subtitle() -> String:
    return PAGE_SUBTITLES[active_tab][_page[active_tab]]

func _mobile_context() -> String:
    if parent == null: return "PROPERTY • INITIALIZING"
    var ownership := "OWNED" if bool(parent.owned) else "AVAILABLE"
    var business := "OPEN" if bool(parent.business_open) else "CLOSED"
    return "PROPERTY %s • %d%% RESTORED • BUSINESS %s" % [ownership, int(parent.restoration), business]

func _page_button(text: String, page: int) -> void:
    _action(text, Callable(self, "_set_page").bind(page))

func _back_button() -> void:
    _action("BACK", Callable(self, "_set_page").bind(0))

func _screen(text: String, screen_name: String) -> void:
    _action(text, Callable(self, "_open_screen").bind(screen_name))

func _refresh() -> void:
    super._refresh()
    if action_grid == null: return
    _clear_action_grids()
    var page := _page[active_tab]
    action_title.text = ["LIVE", "BUSINESS", "EMPIRE", "WORLD"][active_tab] + " • " + PAGE_NAMES[active_tab][page]

    match active_tab:
        0:
            match page:
                0:
                    _screen("DASHBOARD", "DashboardPanel")
                    _action("PROPERTY MAP", _focus_property_map)
                    _page_button("PROPERTY", 1)
                    _page_button("OWNERSHIP", 2)
                    _page_button("RECORDS", 3)
                    _action("END DAY", parent.advance_day)
                1:
                    _back_button()
                    _action("INSPECT", parent.inspect_property)
                    _action("RESTORE", parent.restore_property)
                2:
                    _back_button()
                    _action("ACQUIRE", parent.acquire_property)
                    _action("SELL", parent.sell_property)
                    _action("LEASE", parent.lease_property)
                    _action("OPEN BUSINESS", parent.open_business)
                3:
                    _back_button()
                    _action("SAVE", parent.save_game)
                    _action("LOAD", parent.load_game)
                    _screen("PAST", "HistoryPanel")
                    _screen("NEWS", "NewsPanel")
        1:
            match page:
                0:
                    _page_button("PRODUCTION", 1)
                    _page_button("BUSINESS", 2)
                    _page_button("PEOPLE", 3)
                    _page_button("COMMERCIAL", 4)
                    _page_button("FINANCE", 6)
                1:
                    _back_button()
                    _action("BUY INPUTS", parent.buy_inputs)
                    _action("IMPORT", parent.buy_international)
                    _action("PRODUCE", parent.produce_goods)
                    _action("PRICE", parent.change_price)
                2:
                    _back_button()
                    _action("UPGRADE", parent.upgrade_business)
                    _action("MARKETING", parent.marketing_campaign)
                3:
                    _back_button()
                    _action("HIRE", parent.hire_employee)
                    _screen("STAFF", "EmployeePanel")
                    _screen("HQ", "HeadquartersPanel")
                4:
                    _page_button("CONTRACTS", 5)
                    _screen("CUSTOMERS", "CustomerSegmentsUI")
                    _screen("DEALS", "ContractPanel")
                5:
                    _back_button()
                    _action("CONTRACT", parent.sign_contract)
                    _action("HAGGLE", parent.haggle_contract)
                    _action("EXCLUSIVE", parent.sign_exclusive_contract)
                    _action("GOVT DEAL", parent.sign_government_contract)
                    _action("BUILD DEAL", parent.sign_construction_contract)
                    _action("EXPORT DEAL", parent.sign_export_contract)
                6:
                    _page_button("FUNDING", 7)
                    _screen("FINANCE", "FinancePanel")
                    _screen("COLLECTIONS", "CollectionPanel")
                    _screen("PORTFOLIO", "PortfolioPanel")
                7:
                    _back_button()
                    _action("LOAN", parent.take_loan)
                    _action("REPAY", parent.repay_loan)
                    _action("INVESTOR", parent.request_investment)
                    _action("ACCEPT DEAL", parent.accept_investment)
                    _action("DECLINE DEAL", parent.decline_investment)
        2:
            match page:
                0:
                    _page_button("RIVALS", 1)
                    _page_button("ALLIANCES", 2)
                    _page_button("CORPORATE", 3)
                    _page_button("GROWTH", 4)
                    _page_button("CAPITAL", 6)
                1:
                    _back_button()
                    _action("NEXT RIVAL", _next_rival)
                    _action("COMPETE", parent.compete_alliance)
                    _action("GOALS", parent.victory_progress)
                    _action("REPUTE", parent.reputation_status)
                2:
                    _back_button()
                    _action("ALLIANCE", parent.make_alliance_offer)
                    _action("RELATION", parent.improve_alliance)
                    _action("SUPPLY DEAL", parent.propose_supply_deal)
                    _screen("PACT", "AlliancePanel")
                3:
                    _back_button()
                    _screen("NETWORK", "CorporationsPanel")
                    _action("POWER", parent.world_power)
                    _action("GOALS", parent.victory_progress)
                    _action("REPUTE", parent.reputation_status)
                4:
                    _page_button("REGIONS", 5)
                    _action("EXPANSION", parent.buy_expansion)
                    _action("UPGRADE EXPANSION", parent.upgrade_expansion)
                    _action("TRANSPORT", parent.upgrade_transport)
                    _action("ACQUISITIONS", parent.negotiate_selected_acquisition)
                5:
                    _back_button()
                    _screen("REGIONS", "RegionsPanel")
                    _action("NEXT REGION", parent.next_region)
                    _action("ESTABLISH", parent.establish_region)
                    _action("CHARTER BASIN", parent.charter_basin)
                    _action("CHARTER VALLEY", parent.charter_valley)
                6:
                    _page_button("EQUITY", 7)
                    _action("LOAN", parent.take_loan)
                    _action("REPAY", parent.repay_loan)
                    _action("INVESTOR", parent.request_investment)
                    _action("INVEST BILL", parent.invest_term)
                7:
                    _back_button()
                    _action("BUY SHARES", parent.buy_rival_shares)
                    _action("SELL SHARES", parent.sell_rival_shares)
                    _action("DIVIDEND", parent.pay_dividend)
                    _action("GO PUBLIC", parent.go_public)
                    _action("CAP TABLE", parent.cap_table)
                8:
                    _back_button()
                    _screen("TECH", "TechnologyPanel")
                    _screen("PROGRESSION", "EmpireProgressionPanel")
                    _screen("IDENTITY", "EmpireIdentityPanel")
        3:
            match page:
                0:
                    _page_button("REGIONAL MANAGEMENT", 1)
                    _page_button("OPERATIONS", 2)
                    _page_button("EMPIRE MANAGEMENT", 3)
                    _page_button("EVENTS", 4)
                1:
                    _back_button()
                    _screen("REGIONS", "RegionsPanel")
                    _screen("INFRASTRUCTURE", "InfrastructurePanel")
                2:
                    _back_button()
                    _screen("PRODUCTION", "ProductionControlPanel")
                    _screen("LOGISTICS", "SupplyChainPanel")
                3:
                    _back_button()
                    _screen("EXPANSION", "EmpireExpansionPanel")
                    _screen("INTELLIGENCE", "EmpireIntelligencePanel")
                4:
                    _back_button()
                    _screen("MISSIONS", "WorldOpportunitiesPanel")
                    _screen("LIVE OPS", "LiveOpsPanel")

func _set_page(page: int) -> void:
    _page[active_tab] = clampi(page, 0, PAGE_NAMES[active_tab].size() - 1)
    _refresh()

func _focus_property_map() -> void:
    var map := get_tree().root.get_node_or_null("Renew/World/PropertyMap")
    if map != null:
        map.show()
        map.queue_redraw()
        if parent != null:
            parent.message = "Property map focused. Select a property on the district map."
            show_feedback(str(parent.message))
    elif parent != null:
        parent.message = "Property map is unavailable."
        show_feedback(str(parent.message))

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
    else:
        var scene := get_tree().current_scene if get_tree() != null else null
        if scene != null:
            var node := scene.get_node_or_null("UI/" + screen_name)
            if node != null: node.show()

func _process(delta: float) -> void:
    _hud_refresh_accum += delta
    if _hud_refresh_accum < HUD_REFRESH_INTERVAL:
        return
    _hud_refresh_accum = 0.0
    if parent == null: return
    if action_subtitle != null: action_subtitle.text = _tab_subtitle()
    if selected_title != null: selected_title.text = _selected_title()
    if selected_meta != null: selected_meta.text = _selected_meta()
    if narrow and status_label != null: status_label.text = _mobile_context()
