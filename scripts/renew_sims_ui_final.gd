extends "res://scripts/renew_sims_ui.gd"

# Production entry point for the layered RESTORA shell. Adds live-economy context,
# progression-driven discovery and premium mobile composition without flattening
# secondary systems back onto the home screen.

var tabs: HBoxContainer
var _last_decision_signature := ""
var _presentation_poll_elapsed := 0.0
const PRESENTATION_POLL_INTERVAL := 0.25

func _build_ui() -> void:
    super._build_ui()
    background.name = "MainHUDBackground"
    brand.text = "RESTORA"
    location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tabs = bottom_nav

func _world_3d_active() -> bool:
    var world_3d := get_node_or_null("/root/Renew/World3D")
    if world_3d == null:
        return false
    return bool(world_3d.get("presentation_enabled")) if "presentation_enabled" in world_3d else world_3d.visible

func world_backdrop_alpha(using_3d: bool) -> float:
    return 0.0 if using_3d else 1.0

func _sync_world_presentation() -> void:
    var using_3d := _world_3d_active()
    if background != null:
        background.color.a = world_backdrop_alpha(using_3d)
    if hero_art != null:
        var width := root.size.x if root != null and root.size.x > 0.0 else get_viewport().get_visible_rect().size.x
        hero_art.visible = not using_3d and width >= 360.0

func _layout_responsive() -> void:
    super._layout_responsive()
    var size := root.size if root != null and root.size.x > 0.0 else get_viewport().get_visible_rect().size
    var mobile := size.x < 700.0
    var short_phone := mobile and size.y < 700.0
    var using_3d := _world_3d_active()
    if stat_grid != null:
        stat_grid.visible = not short_phone
    shell.add_theme_constant_override("margin_left", 10 if mobile else 86)
    brand.add_theme_font_size_override("font_size", 24 if mobile else 28)
    location_label.add_theme_font_size_override("font_size", 12 if mobile else 13)
    hero_caption.add_theme_font_size_override("font_size", 12 if mobile else 13)
    hero_value.add_theme_font_size_override("font_size", 30 if mobile else 34)
    hero_meta.add_theme_font_size_override("font_size", 12 if mobile else 13)
    hero_goal.add_theme_font_size_override("font_size", 14 if mobile else 15)
    hero_progress_label.add_theme_font_size_override("font_size", 12 if mobile else 13)
    section_title.add_theme_font_size_override("font_size", 22 if mobile else 24)
    section_caption.add_theme_font_size_override("font_size", 13 if mobile else 14)
    status_label.add_theme_font_size_override("font_size", 13)
    feedback_label.add_theme_font_size_override("font_size", 13)
    for label in stat_names:
        label.add_theme_font_size_override("font_size", 11 if mobile else 12)
    for label in stat_values:
        label.add_theme_font_size_override("font_size", 18 if mobile else 19)
    action_grid.columns = 2
    for child in action_grid.get_children():
        if child is Button:
            var action_button := child as Button
            action_button.clip_text = true
            action_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            action_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
            var primary := str(action_button.get_meta("renew_primary_text", action_button.text.split("\n")[0]))
            var subtitle := str(action_button.get_meta("renew_subtitle", ""))
            action_button.text = primary if short_phone or subtitle == "" else primary + "\n" + subtitle
            if short_phone:
                action_button.custom_minimum_size.y = 54
            elif mobile:
                action_button.custom_minimum_size.y = 84 if size.x < 360.0 else 78
            else:
                action_button.custom_minimum_size.y = 68
            action_button.add_theme_font_size_override("font_size", 12 if mobile else 14)
    for button in mode_buttons:
        button.custom_minimum_size.y = 50 if mobile else 52
        button.add_theme_font_size_override("font_size", 11 if mobile else 12)
    alerts_button.custom_minimum_size.y = 48
    theme_button.custom_minimum_size.y = 48
    hero_action.custom_minimum_size.y = 54
    hero_action.add_theme_font_size_override("font_size", 12 if mobile else 13)
    if status_label != null:
        status_label.visible = (not using_3d) and (not mobile) and size.y >= 720.0
    _sync_world_presentation()

func _open_tutorial() -> void:
    var tutorial_overlay := get_tree().root.get_node_or_null("Renew/UI/TutorialOverlay")
    if tutorial_overlay == null:
        tutorial_overlay = get_tree().root.get_node_or_null("UI/TutorialOverlay")
    if tutorial_overlay != null and tutorial_overlay.has_method("_expand"):
        tutorial_overlay.call("_expand")
        return
    show_feedback("Guided tutorial is temporarily unavailable.")

func _open_decision_center() -> void:
    var desk := get_node_or_null("/root/RenewManagementPolicyUI")
    if desk != null and desk.has_method("_toggle"):
        desk._toggle()
        return
    show_feedback("Decision center is temporarily unavailable.")

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        var opened = manager.show_screen(screen_name)
        if opened == false:
            show_feedback("That management screen is not available yet.")
        return
    show_feedback("Management screens are temporarily unavailable.")

func _run_parent_method(method_name: String) -> Dictionary:
    if parent == null or not parent.has_method(method_name):
        return {"ok": false, "message": "That strategic action is unavailable."}
    var result = parent.call(method_name)
    if result is Dictionary:
        return result
    return {"ok": true, "message": str(parent.message)}

func _property_system():
    if parent == null or parent.get("command_system") == null:
        return null
    return parent.command_system.get("property_system")

func _management_policy(): return get_node_or_null("/root/RenewManagementPolicySystem")
func _real_time_economy(): return get_node_or_null("/root/RenewRealTimeEconomySystem")
func _strategic_progression(): return get_node_or_null("/root/Renew/Systems/StrategicProgression")

func _feature_available(feature_id: String) -> bool:
    var progression = _strategic_progression()
    if progression == null or not progression.has_method("has_unlock"):
        return true
    return bool(progression.has_unlock(feature_id))

func _progression_level() -> int:
    var progression = _strategic_progression()
    if progression != null and progression.has_method("get_level"):
        return int(progression.get_level())
    return 1

func _set_action_visible(label_text: String, visible: bool) -> void:
    var wanted := label_text.to_lower()
    for child in action_grid.get_children():
        if child is Button:
            var button := child as Button
            var primary_text := button.text.split("\n")[0].strip_edges().to_lower()
            if primary_text == wanted:
                button.visible = visible
                button.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED

func _apply_progression_discovery() -> void:
    match active_tab:
        0:
            var viewport_width := get_viewport().get_visible_rect().size.x
            if viewport_width < 700.0:
                _action("Guided tutorial", Callable(self, "_open_tutorial"), "Open the next objective without covering gameplay")
        1:
            _set_action_visible("People & demand", _feature_available("employees"))
            _set_action_visible("Finance & contracts", _feature_available("finance"))
            if _feature_available("contracts") and bool(parent.business_open):
                _screen("Contracts", "ContractPanel", "Obligations, delivery and commercial commitments")
                if int(parent.contract_days) > 0:
                    _action("Deliver contract", Callable(self, "_deliver_contract_now"), "Settle today's active contract delivery", true)
        2:
            _set_action_visible("Expansion", _feature_available("regions"))
            _set_action_visible("Competition", _feature_available("competitors"))
            _set_action_visible("HQ & technology", false)
            if _feature_available("alliances"):
                _screen("Alliances", "AlliancePanel", "Partnerships, leverage and strategic cooperation")
            if _feature_available("diplomacy"):
                _screen("Diplomacy", "RenewDiplomacyUI", "Treaties, relations and joint strategic moves")
            if _feature_available("infrastructure"):
                _screen("Infrastructure", "InfrastructurePanel", "Build logistics, energy and operating capacity")
            if _feature_available("technology"):
                _screen("Technology & research", "TechnologyPanel", "Research capabilities and operating advantages")
            if _feature_available("acquisitions"):
                _screen("Acquisitions & mergers", "CorporationsPanel", "Due diligence, ownership and corporate expansion", true)
            if _feature_available("headquarters"):
                _screen("Headquarters", "HeadquartersPanel", "Strategic capacity, leadership and world-scale growth", true)
        3:
            _set_action_visible("Regions", _feature_available("regions"))
            _set_action_visible("Supply network", _feature_available("supply_chain"))
            _set_action_visible("Intelligence", _feature_available("competitors"))
            if _feature_available("regions"):
                _screen("Market news", "NewsPanel", "Company and world signals")
            if _feature_available("world_power"):
                _screen("World power", "EmpireIntelligencePanel", "Rankings, influence and global competitive position", true)
            if _feature_available("legacy"):
                _screen("History & legacy", "HistoryPanel", "Milestones, company history and long-term impact", true)
                _screen("Collections", "CollectionPanel", "Preserve major achievements and legacy items")
            if _feature_available("prestige"):
                _action("Victory progress", Callable(self, "_run_parent_method").bind("victory_progress"), "Review the requirements for completing this corporate era", true)
                _action("Found new dynasty", Callable(self, "_run_parent_method").bind("found_new_company"), "Begin a new company only after the endgame conditions are satisfied")
    _restyle_actions()
    _layout_responsive()

func _sell_goods_now() -> Dictionary:
    var economy = _real_time_economy()
    if economy == null or not economy.has_method("sell_goods"):
        return {"ok": false, "message": "Active market is unavailable."}
    return economy.sell_goods()

func _deliver_contract_now() -> Dictionary:
    var economy = _real_time_economy()
    if economy == null or not economy.has_method("deliver_contract"):
        return {"ok": false, "message": "Contract delivery is unavailable."}
    return economy.deliver_contract()

func _primary_move() -> Dictionary:
    if parent == null: return {"label": "NEXT MOVE", "call": Callable()}
    if not bool(parent.inspected): return {"label": "INSPECT", "call": parent.inspect_property}
    if not bool(parent.owned): return {"label": "ACQUIRE", "call": parent.acquire_property}
    if str(parent.stage) != "Operational": return {"label": "RESTORE", "call": parent.restore_property}
    if not bool(parent.business_open): return {"label": "CHOOSE BUSINESS", "call": Callable(self, "_open_business_choices")}
    if int(parent.finished_goods) <= 0: return {"label": "PRODUCE", "call": parent.produce_goods}
    return {"label": "SELL GOODS", "call": Callable(self, "_sell_goods_now")}

func _refresh_metrics() -> void:
    super._refresh_metrics()
    if active_tab != 0 or stat_names.size() < 4 or stat_values.size() < 4: return
    var properties = _property_system()
    if properties != null and properties.has_method("restoration_portfolio_status"):
        var status: Dictionary = properties.restoration_portfolio_status()
        stat_names[3].text = "PORTFOLIO"
        stat_values[3].text = "%d / %d" % [int(status.get("restored", 0)), int(status.get("total", 0))]

func _refresh() -> void:
    super._refresh()
    if parent == null: return
    _apply_progression_discovery()
    var clock := Time.get_datetime_dict_from_system()
    var hh := "%02d" % int(clock.get("hour", 0))
    var mm := "%02d" % int(clock.get("minute", 0))
    var level := _progression_level()
    var economy = _real_time_economy()
    if economy != null and economy.has_method("status"):
        var rt: Dictionary = economy.status()
        var hourly := int(round(float(rt.get("hourly_net", 0.0))))
        var demand_left := int(rt.get("consumer_demand_remaining", 0))
        hero_meta.text = "%s:%s • LV %d • %s • %s$%s/hr • demand %d" % [hh, mm, level, "OPERATING" if bool(parent.business_open) else str(parent.stage).to_upper(), "+" if hourly >= 0 else "-", String.num_int64(abs(hourly)), demand_left]
    else:
        hero_meta.text = "%s:%s • LV %d • %s" % [hh, mm, level, "OPERATING" if bool(parent.business_open) else str(parent.stage).to_upper()]

func _decision_signature() -> String:
    if parent == null:
        return ""
    return "%s|%s|%s|%s|%s|%s|%s" % [
        str(parent.inspected),
        str(parent.owned),
        str(parent.stage),
        str(parent.restoration),
        str(parent.business_open),
        str(parent.finished_goods),
        str(_progression_level())
    ]

func _process(delta: float) -> void:
    super._process(delta)
    var decision_signature := _decision_signature()
    if decision_signature != _last_decision_signature:
        _last_decision_signature = decision_signature
        _refresh()
    _presentation_poll_elapsed += delta
    if _presentation_poll_elapsed < PRESENTATION_POLL_INTERVAL:
        return
    _presentation_poll_elapsed = 0.0
    _sync_world_presentation()
    if location_label == null: return
    var policies = _management_policy()
    if policies == null:
        location_label.text = "ACQUIRE • RESTORE • OPERATE • EXPAND"
        return
    var alerts = policies.get_alerts()
    var critical := 0
    for alert in alerts:
        if alert is Dictionary and str(alert.get("severity", "")) == "critical": critical += 1
    if critical > 0:
        location_label.text = "RESTORA • %d CRITICAL DECISION%s" % [critical, "" if critical == 1 else "S"]
    elif alerts.size() > 0:
        location_label.text = "RESTORA • %d ACTIVE SIGNAL%s" % [alerts.size(), "" if alerts.size() == 1 else "S"]
    else:
        location_label.text = "ACQUIRE • RESTORE • OPERATE • EXPAND"
