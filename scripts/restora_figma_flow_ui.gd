extends Node

## Functional bridge for the complete RESTORA Figma UX.
## It adds the secondary/detail screens from the approved mobile flow while
## leaving gameplay truth in Main and the existing domain systems.

const CUSTOM_VIEWS := [
    "launch", "new_game", "continue_game", "onboarding",
    "property_overview", "restoration_plan", "restoration_confirm", "before_after",
    "business_list", "business_overview", "production",
    "employee_list", "employee_detail", "hiring", "assign_employee",
    "contract_market", "contract_detail", "active_contracts",
    "supply_chain", "supplier_compare", "inventory",
    "budget", "funding", "region_overview", "property_acquisition",
    "infrastructure_roadmap", "company_progress", "milestones", "alliances",
    "reports", "notifications", "accessibility", "pause", "day_summary",
    "level_up", "restoration_complete", "insufficient_funds",
    "offline_error", "loading", "empty_states"
]

const IMMERSIVE_VIEWS := [
    "launch", "new_game", "continue_game", "onboarding", "pause",
    "day_summary", "level_up", "restoration_complete", "offline_error", "loading"
]

var _auto_launch_pending := false

func supports(view_name: String) -> bool:
    return CUSTOM_VIEWS.has(view_name)

func build_view(view_name: String, hud: Node, content: Control) -> bool:
    if not supports(view_name):
        return false
    var nav := hud.get("bottom_nav") as Control
    if nav != null:
        nav.visible = not IMMERSIVE_VIEWS.has(view_name)
    var spec := _screen_spec(view_name, hud)
    if spec.is_empty():
        return false
    _render_screen(view_name, hud, content, spec)
    if view_name == "launch" and not _auto_launch_pending:
        _auto_launch_pending = true
        call_deferred("_auto_launch", hud)
    return true

func _auto_launch(hud: Node) -> void:
    await get_tree().create_timer(0.75).timeout
    _auto_launch_pending = false
    if not is_instance_valid(hud) or str(hud.get("active_view")) != "launch":
        return
    hud.call("open_figma_view", "continue_game" if FileAccess.file_exists("user://renew_save.json") else "new_game")

func _screen_spec(view_name: String, hud: Node) -> Dictionary:
    var cash := _cash()
    var worth := int(hud.call("_worth")) if hud.has_method("_worth") else cash
    var day := _day()
    var rep := _rep()
    var property_name := str(hud.call("_building_name")) if hud.has_method("_building_name") else "Current Property"
    var property_type := str(hud.call("_building_type")) if hud.has_method("_building_type") else "Property"
    var progress := int(hud.call("_building_progress")) if hud.has_method("_building_progress") else 0
    var stage := str(hud.call("_building_stage_name")) if hud.has_method("_building_stage_name") else "ABANDONED"
    var employees := _roster().size()
    var contracts := _active_contract_count()
    var inputs := int(hud.call("_inputs")) if hud.has_method("_inputs") else 0
    var goods := int(hud.call("_goods")) if hud.has_method("_goods") else 0
    var debt := int(hud.call("_debt")) if hud.has_method("_debt") else 0
    var profit := int(hud.call("_last_profit")) if hud.has_method("_last_profit") else 0

    match view_name:
        "launch":
            return _spec("RESTORA", "RESTORE · OPERATE · GROW", [],
                ["Bring neglected places back to life.", "Build a company whose progress is visible in every property."], [], true)
        "new_game":
            return _spec("New Game", "BUILD VALUE FROM NEGLECTED PLACES",
                [["STARTING CASH", _money(cash)], ["DIFFICULTY", "BALANCED"], ["TUTORIAL", "GUIDED"]],
                ["Heritage challenge · higher prestige, stricter cash decisions.",
                 "Independent planner · live economy with contextual guidance."],
                [["CREATE COMPANY", "create_company", true], ["CONTINUE WITHOUT GUIDE", "start_home", false]], true)
        "continue_game":
            return _spec("Continue Game", "YOUR LOCAL COMPANY",
                [["CASH", _money(cash)], ["VALUE", _money(worth)], ["DAY", str(day)]],
                ["RESTORA save detected.", "Load the authoritative company state and continue from the same context."],
                [["CONTINUE DAY %d" % day, "continue_save", true], ["NEW COMPANY", "new_game", false]], true)
        "onboarding":
            return _spec("Onboarding", "RESTORE · OPERATE · GROW",
                [["STEP", "1 / 4"], ["CASH", _money(cash)], ["GOAL", "SAFE ACCESS"]],
                ["Start with one useful decision.", "Inspect the first property, then follow the restoration plan."],
                [["VIEW THE PROPERTY", "property", true], ["HOW THE LOOP WORKS", "guide", false]], true)
        "property_overview":
            return _spec("Property Overview", "%s · %s" % [property_name, property_type],
                [["CURRENT", _money(_property_value())], ["RESTORED", "%d%%" % progress], ["STAGE", stage]],
                ["Condition · %d/100" % _property_condition(),
                 "Operating status · %s" % ("ready" if stage == "OPERATIONAL" else "restoration required"),
                 "History and compatibility remain attached to this asset."],
                [["OPEN RESTORATION PLAN", "restoration_plan", true], ["BEFORE / AFTER", "before_after", false]])
        "restoration_plan":
            return _spec("Restoration Plan", "CHRONOLOGICAL WORK ROADMAP",
                [["PROGRESS", "%d%%" % progress], ["CASH", _money(cash)], ["NEXT", stage]],
                _restoration_steps(hud),
                [["REVIEW NEXT WORK", "restoration_confirm", true], ["COMPARE BEFORE / AFTER", "before_after", false]])
        "restoration_confirm":
            var cost := _next_property_cost(hud)
            return _spec("Restoration Action", "CONSEQUENCE CHECK",
                [["AVAILABLE", _money(cash)], ["COST", _money(-cost)], ["AFTER", _money(cash - cost)]],
                ["Current stage · %s" % stage,
                 "The real restoration command will execute only after confirmation.",
                 "If cash is insufficient, funding options stay available."],
                [["CONFIRM WORK", "confirm_restore", true], ["NOT YET", "restoration_plan", false]])
        "before_after":
            return _spec("Before / After", "ORIGINAL · CURRENT · TARGET",
                [["ORIGINAL", "0%"], ["CURRENT", "%d%%" % progress], ["TARGET", "100%"]],
                ["%s transformation" % property_name,
                 "Every restoration command updates condition, stage and company value.",
                 "The target state becomes operational rather than merely cosmetic."],
                [["RETURN TO PLAN", "restoration_plan", true], ["OPEN PROPERTY", "property", false]])
        "business_list":
            return _spec("Business List", "OPERATING PORTFOLIO",
                [["BUSINESSES", "1" if _business_open() else "0"], ["GOODS", str(goods)], ["PROFIT", _money(profit)]],
                ["%s · %s" % [property_name, "operating" if _business_open() else "preparing"],
                 "Production, staffing, supply and contracts share the same live economy."],
                [["OPEN BUSINESS", "business_overview", true], ["PRODUCTION", "production", false]])
        "business_overview":
            return _spec("Business Overview", "%s OPERATIONS" % property_name.to_upper(),
                [["INPUTS", str(inputs)], ["GOODS", str(goods)], ["STAFF", str(employees)]],
                ["Demand · %d units remaining" % _demand_remaining(),
                 "Efficiency reflects real staffing, supply and production state.",
                 "Use Operations for production; Team and Supply for bottlenecks."],
                [["MANAGE OPERATIONS", "production", true], ["EMPLOYEES", "employee_list", false], ["SUPPLY", "supply_chain", false]])
        "production":
            return _spec("Production / Operations", "LIVE CYCLE",
                [["INPUTS", str(inputs)], ["OUTPUT", str(goods)], ["STAFF", str(employees)]],
                ["Buy inputs when stock is low.", "Produce through the real command boundary.", "Sell or deliver only inventory that exists."],
                [["PRODUCE BATCH", "produce", true], ["BUY INPUTS", "buy_inputs", false], ["BUSINESS", "operate", false]])
        "employee_list":
            return _spec("Employee List", "WORKFORCE · SUMMARY AND GAPS",
                [["STAFF", str(employees)], ["PAYROLL", _money(_payroll())], ["MORALE", "%d%%" % _morale_percent()]],
                _employee_lines(),
                [["HIRE EMPLOYEE", "hiring", true], ["OPEN TEAM MANAGER", "employee_manager", false]])
        "employee_detail":
            var emp := _first_employee()
            return _spec("Employee Detail", str(emp.get("name", "Employee")),
                [["SKILL", str(emp.get("level", 1))], ["PRODUCTIVITY", "%d%%" % int(float(emp.get("productivity", 0.8)) * 100.0)], ["MORALE", "%d%%" % int(float(emp.get("morale", 0.8)) * 100.0)]],
                ["Role · %s" % str(emp.get("role", "Worker")), "Assignment · %s" % str(emp.get("assignment", "unassigned")), "Use training and assignments to change real capacity."],
                [["TRAIN", "train_employee", true], ["ASSIGN", "assign_employee", false], ["TEAM LIST", "employee_list", false]])
        "hiring":
            return _spec("Hiring", "CANDIDATES AND CAPACITY",
                [["CASH", _money(cash)], ["STAFF", str(employees)], ["NEED", "CAPACITY"]],
                ["Hiring spends real cash and increases recurring wages.", "Candidate traits and progression remain owned by the employee system."],
                [["HIRE BEST AVAILABLE", "hire_employee", true], ["COMPARE TEAM", "employee_list", false]])
        "assign_employee":
            return _spec("Assign Employee", "PUT SKILL WHERE IT CREATES VALUE",
                [["STAFF", str(employees)], ["PROPERTY", property_type], ["STATUS", stage]],
                ["Assign the selected employee to the operating site.", "Assignments feed production productivity and management capacity."],
                [["ASSIGN TO OPERATIONS", "confirm_assign", true], ["NOT YET", "employee_detail", false]])
        "contract_market":
            return _spec("Contract Marketplace", "AVAILABLE · ACTIVE · COMPLETED",
                [["ACTIVE", str(contracts)], ["REPUTATION", str(rep)], ["CAPACITY", "%d%%" % _capacity_percent()]],
                ["Contracts use real production, delivery and penalty rules.", "Review capacity before accepting additional work."],
                [["REVIEW OFFER", "contract_detail", true], ["ACTIVE CONTRACTS", "active_contracts", false]])
        "contract_detail":
            return _spec("Contract Detail", "CAPACITY CHECK",
                [["ACTIVE", str(contracts)], ["GOODS", str(goods)], ["REP", str(rep)]],
                ["Can the company complete this with current stock and capacity?", "Acceptance creates a real active contract; delivery consumes real inventory."],
                [["ACCEPT CONTRACT", "accept_contract", true], ["CAPACITY DETAILS", "production", false]])
        "active_contracts":
            return _spec("Active Contracts", "PROGRESS AND DEADLINES",
                [["ACTIVE", str(contracts)], ["GOODS", str(goods)], ["DAY", str(day)]],
                ["Current commitments are read from the authoritative contract system.", "Delivery is enabled only when a real active contract can settle."],
                [["DELIVER CONTRACT", "deliver_contract", true], ["MARKETPLACE", "contract_market", false]])
        "supply_chain":
            return _spec("Supply Chain", "MATERIALS · ROUTES · SIGNALS",
                [["INPUTS", str(inputs)], ["ROUTES", str(_trade_routes())], ["TRANSPORT", "L%d" % _transport_level()]],
                ["Supplier choice affects procurement.", "Inventory is shared with production.", "Transport upgrades improve logistics capacity."],
                [["COMPARE SUPPLIERS", "supplier_compare", true], ["INVENTORY", "inventory", false], ["UPGRADE TRANSPORT", "upgrade_transport", false]])
        "supplier_compare":
            return _spec("Supplier Comparison", "COST · SPEED · RELIABILITY",
                [["CASH", _money(cash)], ["INPUTS", str(inputs)], ["SUPPLIER", str(_state_value("supply_chain", "supplier_choice", 0) + 1)]],
                ["Cycle to another supplier to compare the live procurement quote.", "Ordering uses the real supply-chain purchase path."],
                [["SELECT NEXT SUPPLIER", "cycle_supplier", false], ["ORDER INPUTS", "buy_inputs", true], ["SUPPLY", "supply_chain", false]])
        "inventory":
            return _spec("Inventory", "STOCK BY USE",
                [["INPUTS", str(inputs)], ["GOODS", str(goods)], ["VALUE", _money(inputs * 25 + goods * 50)]],
                ["Raw materials feed production.", "Finished goods feed sales and contract delivery.", "No inventory is created by the UI."],
                [["CREATE PURCHASE ORDER", "supplier_compare", true], ["PRODUCTION", "production", false]])
        "budget":
            return _spec("Budget", "ALLOCATE THE NEXT OPERATING WINDOW",
                [["AVAILABLE", _money(cash)], ["RESERVE", "25%"], ["DEBT", _money(debt)]],
                ["Restoration · 35%", "Employees · 20%", "Infrastructure · 20%", "Reserve · 25%"],
                [["APPLY BUDGET", "apply_budget", true], ["RESET", "reset_budget", false], ["FINANCE", "finance", false]])
        "funding":
            return _spec("Loans / Funding", "PLAIN-LANGUAGE CASH-FLOW EFFECT",
                [["CASH", _money(cash)], ["DEBT", _money(debt)], ["REP", str(rep)]],
                ["Compare debt, repayment and investor options before committing.", "All accepted funding flows through the existing finance command system."],
                [["TAKE LOAN", "take_loan", true], ["REPAY", "repay_loan", false], ["INVESTOR", "request_investor", false]])
        "region_overview":
            return _spec("Region Overview", _current_region(),
                [["REP", str(rep)], ["PRESENCE", str(_region_presence())], ["ROUTES", str(_trade_routes())]],
                ["Regional demand, infrastructure and presence come from the live world systems.", "Property opportunities remain gated by reputation and capacity."],
                [["REVIEW PROPERTY", "property_acquisition", true], ["REGION MAP", "world", false]])
        "property_acquisition":
            return _spec("Property Acquisition", "DUE DILIGENCE",
                [["CASH", _money(cash)], ["COST", _money(_next_property_cost(hud))], ["VALUE", _money(_property_value())]],
                ["Inspect before purchasing.", "Acquisition, restoration cost and affordability are checked by the property system."],
                [["ACQUIRE / CONTINUE", "property_action", true], ["ARRANGE FUNDING", "funding", false]])
        "infrastructure_roadmap":
            return _spec("Infrastructure", "LONG-TERM DISTRICT SYSTEMS",
                [["LEVEL", str(_state_value("infrastructure", "level", 1))], ["CASH", _money(cash)], ["REGION", _current_region()]],
                ["Electricity · capacity", "Roads · logistics", "Security · risk", "Water · business unlocks", "Communications · contracts"],
                [["UPGRADE REGION", "upgrade_region", true], ["OPEN INFRASTRUCTURE", "infrastructure_manager", false]])
        "company_progress":
            return _spec("Company Progress", "ONE PROPERTY → REGIONAL ENTERPRISE",
                [["LEVEL", str(_company_level())], ["REP", str(rep)], ["VALUE", _money(worth)]],
                ["%d properties owned" % _owned_properties(), "%d staff" % employees, "%d active contracts" % contracts],
                [["REGIONS", "world", true], ["MILESTONES", "milestones", false], ["PROGRESSION DETAIL", "progression_manager", false]])
        "milestones":
            return _spec("Milestones / Collection", "LEGACY AND PRESTIGE",
                [["REP", str(rep)], ["LEVEL", str(_company_level())], ["RESTORED", "%d%%" % progress]],
                ["First Restoration", "Reliable Operator", "Deal Maker", "Regional Builder"],
                [["OPEN COLLECTION", "collection_manager", true], ["COMPANY PROGRESS", "company_progress", false]])
        "alliances":
            return _spec("Alliances", "TRUST · INFLUENCE · CONFLICT",
                [["REP", str(rep)], ["RIVALS", str(_rival_count())], ["STATUS", "ACTIVE"]],
                ["Supplier, civic and competitor relationships affect the same simulation.", "Open the relationship manager for negotiations and alliance actions."],
                [["OPEN RELATIONSHIPS", "alliance_manager", true], ["CORPORATIONS", "corporations_manager", false]])
        "reports":
            return _spec("Reports", "ANSWERS FOR THE NEXT STRATEGIC MOVE",
                [["PROFIT", _money(profit)], ["VALUE", _money(worth)], ["DEBT", _money(debt)]],
                ["Best current asset · %s" % property_name, "Largest operational risk · %s" % ("supply" if inputs < 20 else "capacity"), "Growth signal · company level %d" % _company_level()],
                [["OPEN DASHBOARD", "dashboard_manager", true], ["FINANCE", "finance", false]])
        "notifications":
            return _spec("Notifications", "ONLY MEANINGFUL SIGNALS",
                [["DAY", str(day)], ["CONTRACTS", str(contracts)], ["INPUTS", str(inputs)]],
                _notification_lines(),
                [["OPEN CENTER", "notifications_manager", true], ["HOME", "live", false]])
        "accessibility":
            return _spec("Accessibility", "TUNE RESTORA TO HOW YOU PLAY",
                [["TEXT", "%d%%" % int(round(float(ProjectSettings.get_setting("renew/ui/text_scale", 1.0)) * 100.0))], ["MOTION", "REDUCED" if bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false)) else "FULL"], ["CONTRAST", "HIGH" if bool(ProjectSettings.get_setting("renew/ui/high_contrast", false)) else "STANDARD"]],
                ["Color meaning is always paired with text.", "Important touch targets remain at least 44px.", "Reduced motion affects focused-screen transitions."],
                [["TEXT SIZE", "cycle_text_scale", false], ["REDUCED MOTION", "toggle_motion", false], ["HIGH CONTRAST", "toggle_contrast", false], ["SETTINGS", "settings", true]])
        "pause":
            return _spec("Pause Menu", "DAY %d" % day,
                [["CASH", _money(cash)], ["DAY", str(day)], ["LEVEL", str(_company_level())]],
                ["Save status · local autosave enabled", "Settings and accessibility remain available."],
                [["SAVE & CONTINUE", "save_resume", true], ["SETTINGS", "settings", false], ["RESUME", "live", false]], true)
        "day_summary":
            return _spec("End-of-Day Summary", "DAY %d COMPLETE" % day,
                [["REVENUE", _money(int(hud.call("_last_sales")) if hud.has_method("_last_sales") else 0)], ["PROFIT", _money(profit)], ["REP", str(rep)]],
                ["Property · %d%% restored" % progress, "Contracts · %d active" % contracts, "Tomorrow · review your next objective"],
                [["CONTINUE", "advance_day", true], ["REVIEW", "reports", false]], true)
        "level_up":
            return _spec("Level-Up / Unlock", "COMPANY LEVEL %d" % _company_level(),
                [["LEVEL", str(_company_level())], ["REP", str(rep)], ["VALUE", _money(worth)]],
                ["New systems are unlocked by real progression state.", "Explore the next region or return to the company overview."],
                [["EXPLORE REGIONS", "world", true], ["HOME", "live", false]], true)
        "restoration_complete":
            return _spec("Restoration Complete", property_name,
                [["VALUE", _money(_property_value())], ["RESTORED", "100%"], ["REP", str(rep)]],
                ["The property is operational.", "Business setup and commercial use are now available."],
                [["OPEN PROPERTY", "property", true], ["START BUSINESS", "operate", false]], true)
        "insufficient_funds":
            var required := _next_property_cost(hud)
            return _spec("Insufficient Funds", "FUND THE NEXT DECISION",
                [["AVAILABLE", _money(cash)], ["COST", _money(required)], ["SHORTFALL", _money(maxi(0, required - cash))]],
                ["Use finance rather than silently failing an action.", "Funding and budget planning are always reachable from here."],
                [["FUNDING", "funding", true], ["BUDGET", "budget", false], ["BACK", "property", false]])
        "offline_error":
            return _spec("Offline / Error", "LOCAL PROGRESS IS SAFE",
                [["DAY", str(day)], ["CASH", _money(cash)], ["SAVE", "LOCAL"]],
                ["Continue offline with local gameplay.", "Retry network-dependent services when connectivity returns."],
                [["CONTINUE OFFLINE", "live", true], ["TRY AGAIN", "retry_services", false]], true)
        "loading":
            return _spec("Loading", "SYNCHRONIZING COMPANY STATE",
                [["LOCAL", "SAVED"], ["GAME", "READY"], ["QUEUE", "0"]],
                ["Loading never hides the fact that local progress is safe.", "The game remains playable when optional online services are unavailable."], [], true)
        "empty_states":
            return _spec("Empty States", "WHY · NEXT STEP · ACTION",
                [["STAFF", str(employees)], ["CONTRACTS", str(contracts)], ["BUSINESS", "OPEN" if _business_open() else "NONE"]],
                ["No employees → hire", "No contracts → build reputation", "No business → finish restoration", "No property → inspect an opportunity"],
                [["HIRE", "hiring", true], ["CONTRACTS", "contract_market", false], ["PROPERTY", "property", false]])
    return {}

func _spec(title: String, subtitle: String, metrics: Array, details: Array, actions: Array, immersive := false) -> Dictionary:
    return {"title": title, "subtitle": subtitle, "metrics": metrics, "details": details, "actions": actions, "immersive": immersive}

func back_target(view_name: String) -> String:
    match view_name:
        "property_overview", "restoration_plan": return "property"
        "restoration_confirm", "before_after": return "restoration_plan"
        "business_list": return "operate"
        "business_overview": return "business_list"
        "production": return "business_overview"
        "employee_list", "contract_market", "supply_chain", "infrastructure_roadmap", "company_progress", "milestones", "alliances", "reports", "notifications": return "more"
        "employee_detail", "hiring": return "employee_list"
        "assign_employee": return "employee_detail"
        "contract_detail", "active_contracts": return "contract_market"
        "supplier_compare", "inventory": return "supply_chain"
        "budget", "funding": return "finance"
        "region_overview": return "world"
        "property_acquisition": return "region_overview"
        "accessibility": return "settings"
        "new_game", "continue_game": return "launch"
        "onboarding": return "new_game"
        "insufficient_funds": return "property"
        "empty_states": return "more"
    return "live"

func _render_screen(view_name: String, hud: Node, content: Control, spec: Dictionary) -> void:
    var w := content.size.x if content.size.x > 0 else 382.0
    var inner_w := w - 36.0
    hud.call("_header", str(spec.get("title", "RESTORA")), str(spec.get("subtitle", "")))
    if not bool(spec.get("immersive", false)) and view_name != "launch":
        var back := back_target(view_name)
        hud.call("_frame_button", content, "FlowBack", "‹", Rect2(w - 62.0, 18.0, 44.0, 40.0), Callable(self, "_dispatch").bind(back, hud), false, false, 16)
    var y := 84.0
    var metrics: Array = spec.get("metrics", [])
    if not metrics.is_empty():
        var gap := 6.0
        var cols := mini(3, metrics.size())
        var tile_w := (inner_w - gap * float(cols - 1)) / float(cols)
        for i in range(metrics.size()):
            var m = metrics[i]
            var col := i % cols
            var row := floori(float(i) / float(cols))
            var tile = hud.call("_panel", content, "FlowMetric%d" % i, Rect2(18.0 + float(col) * (tile_w + gap), y + float(row) * 84.0, tile_w, 74.0), "surface_2", "border", 12)
            hud.call("_label", tile, "Label", str(m[0]), Rect2(10, 10, tile_w - 20, 14), 9, "muted", 600)
            hud.call("_label", tile, "Value", str(m[1]), Rect2(10, 30, tile_w - 20, 26), 16, "text", 700)
        y += float(ceili(float(metrics.size()) / float(cols))) * 84.0 + 10.0

    var details: Array = spec.get("details", [])
    var detail_h := maxf(112.0, 48.0 + float(details.size()) * 44.0)
    var detail = hud.call("_panel", content, "FlowDetails", Rect2(18, y, inner_w, detail_h), "surface", "border", 18)
    hud.call("_label", detail, "Head", "DECISION CONTEXT", Rect2(14, 13, inner_w - 28, 14), 10, "gold", 700)
    for i in range(details.size()):
        var row_y := 42.0 + float(i) * 44.0
        var row = hud.call("_panel", detail, "Detail%d" % i, Rect2(10, row_y, inner_w - 20, 36), "surface_2", "border", 10)
        hud.call("_label", row, "Text", str(details[i]), Rect2(10, 9, inner_w - 40, 18), 9, "text", 500)
    y += detail_h + 14.0

    var actions: Array = spec.get("actions", [])
    for i in range(actions.size()):
        var action = actions[i]
        var primary := bool(action[2])
        var button = hud.call("_frame_button", content, "FlowAction%d" % i, str(action[0]), Rect2(18, y, inner_w, 48), Callable(self, "_dispatch").bind(str(action[1]), hud), false, primary, 10)
        if button is Button:
            (button as Button).tooltip_text = str(action[0])
        y += 58.0

    content.custom_minimum_size.y = maxf(content.custom_minimum_size.y, y + 26.0)
    content.size.y = maxf(content.size.y, y + 26.0)

func _dispatch(action: String, hud: Node) -> void:
    match action:
        "live", "operate", "property", "finance", "more", "world", "settings", "guide",
        "new_game", "continue_game", "onboarding", "property_overview", "restoration_plan",
        "restoration_confirm", "before_after", "business_list", "business_overview", "production",
        "employee_list", "employee_detail", "hiring", "assign_employee", "contract_market",
        "contract_detail", "active_contracts", "supply_chain", "supplier_compare", "inventory",
        "budget", "funding", "region_overview", "property_acquisition", "infrastructure_roadmap",
        "company_progress", "milestones", "alliances", "reports", "notifications", "accessibility",
        "pause", "day_summary", "level_up", "restoration_complete", "insufficient_funds",
        "offline_error", "loading", "empty_states":
            hud.call("open_figma_view", action)
        "create_company":
            _state_set("company", "name", "Hearth & Beam Restoration Co.")
            _state_set("tutorial", "figma_onboarding_seen", true)
            hud.call("open_figma_view", "onboarding")
        "start_home":
            hud.call("open_figma_view", "live")
        "continue_save":
            _game_call("load_game")
            hud.call("open_figma_view", "live")
        "confirm_restore":
            var cost := _next_property_cost(hud)
            if cost > _cash():
                hud.call("open_figma_view", "insufficient_funds")
                return
            _game_call("restore_property")
            if str(hud.call("_building_stage_name")) == "OPERATIONAL":
                hud.call("open_figma_view", "restoration_complete")
            else:
                hud.call("open_figma_view", "restoration_plan")
        "property_action":
            if not bool(hud.call("_inspected")):
                _game_call("inspect_property")
            elif not bool(hud.call("_owned")):
                if _next_property_cost(hud) > _cash():
                    hud.call("open_figma_view", "insufficient_funds")
                    return
                _game_call("acquire_property")
            else:
                hud.call("open_figma_view", "restoration_plan")
                return
            hud.call("open_figma_view", "property")
        "produce":
            _game_call("produce_goods")
            hud.call("open_figma_view", "production")
        "buy_inputs":
            _game_call("buy_inputs")
            hud.call("open_figma_view", "inventory")
        "hire_employee":
            _game_call("hire_employee")
            hud.call("open_figma_view", "employee_list")
        "train_employee":
            var id := str(_first_employee().get("id", ""))
            if not id.is_empty():
                _game_call("train_employee", [id])
            hud.call("open_figma_view", "employee_detail")
        "confirm_assign":
            var id := str(_first_employee().get("id", ""))
            if not id.is_empty():
                _game_call("assign_employee", [id, "factory_001"])
            hud.call("open_figma_view", "employee_list")
        "accept_contract":
            _game_call("sign_contract")
            hud.call("open_figma_view", "active_contracts")
        "deliver_contract":
            _game_call("deliver_contract")
            hud.call("open_figma_view", "active_contracts")
        "cycle_supplier":
            _game_call("cycle_supplier")
            hud.call("open_figma_view", "supplier_compare")
        "upgrade_transport":
            _game_call("upgrade_transport")
            hud.call("open_figma_view", "supply_chain")
        "apply_budget":
            _state_set("finance", "budget_plan", {"restoration":35, "employees":20, "infrastructure":20, "reserve":25})
            _message("Budget plan applied: 35% restoration, 20% employees, 20% infrastructure, 25% reserve.")
            hud.call("open_figma_view", "budget")
        "reset_budget":
            _state_set("finance", "budget_plan", {})
            _message("Budget plan reset.")
            hud.call("open_figma_view", "budget")
        "take_loan":
            _game_call("take_loan")
            hud.call("open_figma_view", "funding")
        "repay_loan":
            _game_call("repay_loan")
            hud.call("open_figma_view", "funding")
        "request_investor":
            _game_call("request_investment")
            hud.call("open_figma_view", "funding")
        "upgrade_region":
            _game_call("upgrade_regional_infrastructure")
            hud.call("open_figma_view", "infrastructure_roadmap")
        "advance_day":
            _game_call("advance_day")
            _game_call("save_game")
            hud.call("open_figma_view", "live")
        "save_resume":
            _game_call("save_game")
            hud.call("open_figma_view", "live")
        "retry_services":
            hud.call("open_figma_view", "live")
        "toggle_motion":
            hud.call("_toggle_motion")
            hud.call("open_figma_view", "accessibility")
        "toggle_contrast":
            var next := not bool(ProjectSettings.get_setting("renew/ui/high_contrast", false))
            ProjectSettings.set_setting("renew/ui/high_contrast", next)
            _message("High contrast %s." % ("enabled" if next else "disabled"))
            hud.call("open_figma_view", "accessibility")
        "cycle_text_scale":
            var current := float(ProjectSettings.get_setting("renew/ui/text_scale", 1.0))
            var next := 1.15 if current < 1.1 else (1.3 if current < 1.25 else 1.0)
            ProjectSettings.set_setting("renew/ui/text_scale", next)
            _message("Text scale set to %d%%." % int(round(next * 100.0)))
            hud.call("open_figma_view", "accessibility")
        "employee_manager":
            hud.call("_open_screen", "EmployeePanel")
        "infrastructure_manager":
            hud.call("_open_screen", "InfrastructurePanel")
        "progression_manager":
            hud.call("_open_screen", "EmpireProgressionPanel")
        "collection_manager":
            hud.call("_open_screen", "CollectionPanel")
        "alliance_manager":
            hud.call("_open_screen", "AlliancePanel")
        "corporations_manager":
            hud.call("_open_screen", "CorporationsPanel")
        "dashboard_manager":
            hud.call("_open_screen", "DashboardPanel")
        "notifications_manager":
            hud.call("_open_screen", "NotificationsCenterPanel")

func _game() -> Node:
    return get_tree().root.get_node_or_null("Renew")

func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")

func _game_call(method: String, args: Array = []):
    var game := _game()
    if game != null and game.has_method(method):
        return game.callv(method, args)
    return null

func _state_value(domain: String, key: String, default_value):
    var state := _state()
    return state.get_value(domain, key, default_value) if state != null and state.has_method("get_value") else default_value

func _state_set(domain: String, key: String, value) -> void:
    var state := _state()
    if state != null and state.has_method("set_value"):
        state.set_value(domain, key, value)

func _message(value: String) -> void:
    _state_set("company", "message", value)

func _cash() -> int:
    return int(_state_value("economy", "cash", 0))

func _day() -> int:
    return int(_state_value("player", "day", 1))

func _rep() -> int:
    return int(_state_value("player", "reputation", 0))

func _business_open() -> bool:
    return bool(_state_value("businesses", "business_open", false))

func _company_level() -> int:
    return int(_state_value("progression", "level", 1))

func _roster() -> Array:
    var value = _state_value("employees", "roster", [])
    return value if value is Array else []

func _first_employee() -> Dictionary:
    var roster := _roster()
    return roster[0] if not roster.is_empty() and roster[0] is Dictionary else {}

func _employee_lines() -> Array:
    var out: Array = []
    var roster := _roster()
    for i in range(mini(4, roster.size())):
        var e: Dictionary = roster[i] if roster[i] is Dictionary else {}
        out.append("%s · %s · productivity %d%%" % [str(e.get("name", "Employee")), str(e.get("role", "Worker")), int(float(e.get("productivity", 0.8)) * 100.0)])
    if out.is_empty():
        out.append("No employees yet · hiring unlocks more capacity.")
    return out

func _payroll() -> int:
    var total := 0
    for e in _roster():
        if e is Dictionary:
            total += int(e.get("wage", e.get("salary", 0)))
    return total

func _morale_percent() -> int:
    var roster := _roster()
    if roster.is_empty():
        return 100
    var total := 0.0
    for e in roster:
        if e is Dictionary:
            total += float(e.get("morale", 0.8))
    return int(round(total / float(roster.size()) * 100.0))

func _active_contract_count() -> int:
    var contracts = _state_value("contracts", "active", [])
    if contracts is Array:
        return contracts.size()
    return 1 if int(_state_value("contracts", "contract_days", 0)) > 0 else 0

func _capacity_percent() -> int:
    var staff := maxi(1, _roster().size())
    return clampi(55 + staff * 5, 0, 100)

func _demand_remaining() -> int:
    var realtime := get_node_or_null("/root/RenewRealTimeEconomySystem")
    if realtime != null and realtime.has_method("status"):
        return int((realtime.status() as Dictionary).get("consumer_demand_remaining", 0))
    return 0

func _trade_routes() -> int:
    var routes = _state_value("regions", "trade_routes", [])
    return routes.size() if routes is Array else int(_state_value("regions", "trade_route_count", 0))

func _transport_level() -> int:
    return int(_state_value("supply_chain", "transport_level", 1))

func _current_region() -> String:
    var regions = _state_value("regions", "regions", [])
    var selected := int(_state_value("regions", "selected_region", 0))
    if regions is Array and selected >= 0 and selected < regions.size() and regions[selected] is Dictionary:
        return str((regions[selected] as Dictionary).get("name", "Current Region"))
    return "Current Region"

func _region_presence() -> int:
    var presence = _state_value("regions", "player_presence", [])
    var selected := int(_state_value("regions", "selected_region", 0))
    if presence is Array and selected >= 0 and selected < presence.size():
        return int(presence[selected])
    return 0

func _property_value() -> int:
    var catalog = _state_value("properties", "catalog", [])
    var selected := int(_state_value("properties", "selected_property", 0))
    if catalog is Array and selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary:
        return int((catalog[selected] as Dictionary).get("value", 0))
    return int(_state_value("properties", "value", 0))

func _property_condition() -> int:
    var catalog = _state_value("properties", "catalog", [])
    var selected := int(_state_value("properties", "selected_property", 0))
    if catalog is Array and selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary:
        return int((catalog[selected] as Dictionary).get("condition", 0))
    return int(_state_value("properties", "condition", 0))

func _next_property_cost(hud: Node) -> int:
    if hud.has_method("_property_action_cost"):
        return int(hud.call("_property_action_cost"))
    return 0

func _restoration_steps(hud: Node) -> Array:
    var result: Array = []
    var catalog = _state_value("properties", "catalog", [])
    var selected := int(_state_value("properties", "selected_property", 0))
    var property: Dictionary = catalog[selected] if catalog is Array and selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary else {}
    for item in [["Cleaning", "cleaning"], ["Structural repair", "repair"], ["Finishing", "painting"], ["Fit-out", "furnishing"]]:
        var value := int(property.get(item[1], 0))
        result.append("%s · %d%% · %s" % [item[0], value, "complete" if value >= 100 else ("current" if value > 0 else "queued")])
    if result.is_empty():
        result.append("Inspect the property to reveal the restoration plan.")
    return result

func _owned_properties() -> int:
    var total := 0
    var catalog = _state_value("properties", "catalog", [])
    if catalog is Array:
        for p in catalog:
            if p is Dictionary and bool((p as Dictionary).get("owned", false)):
                total += 1
    return total

func _rival_count() -> int:
    var rivals = _state_value("competitors", "rivals", [])
    return rivals.size() if rivals is Array else 0

func _notification_lines() -> Array:
    var lines: Array = []
    var message := str(_state_value("company", "message", ""))
    if not message.is_empty():
        lines.append(message)
    if _active_contract_count() > 0:
        lines.append("%d active contract%s need attention." % [_active_contract_count(), "" if _active_contract_count() == 1 else "s"])
    if int(_state_value("production", "inputs", 0)) <= 0:
        lines.append("Production inputs are low.")
    if lines.is_empty():
        lines.append("No urgent decisions right now.")
    return lines

func _money(value: int) -> String:
    var n := abs(value)
    var prefix := "-$" if value < 0 else "$"
    if n >= 1000000:
        return "%s%.2fM" % [prefix, float(n) / 1000000.0]
    if n >= 1000:
        return "%s%.1fK" % [prefix, float(n) / 1000.0]
    return "%s%d" % [prefix, n]
