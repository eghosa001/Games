extends SceneTree
var failed:=0

func _initialize()->void:
    call_deferred("_run")

func check(label:String,ok:bool)->void:
    if ok:
        print("PASS: "+label)
    else:
        failed += 1
        push_error("FAIL: "+label)

func _run()->void:
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size=Vector2i(390,844)
    var p:=load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads",p!=null)
    if p==null:
        quit(1)
        return
    var game:=p.instantiate()
    root.add_child(game)
    current_scene=game
    await process_frame
    await process_frame
    var hud:=game.get_node("UI/MainHUD")
    var runtime:=hud.get("root") as Control
    check("management runtime root",runtime!=null and runtime.name=="RestoraFigmaRuntime")
    var content:=hud.get("mobile_content") as Control
    var hero:=content.get_node_or_null("ExecutiveHero") as Control
    check("home hero exists",hero!=null)
    check("home hero is readable size",hero!=null and hero.size.y>=170.0)
    for _frame in range(3):
        await process_frame
    var stage_art := hero.get_node_or_null("ActiveRestorationArt") as TextureRect if hero!=null else null
    var title := hero.get_node_or_null("HeroTitle") as Label if hero!=null else null
    var goal := hero.get_node_or_null("HeroGoal") as Label if hero!=null else null
    var action := hero.get_node_or_null("PrimaryNextMove") as Button if hero!=null else null
    check("mobile shows stage-correct property artwork",stage_art!=null and stage_art.texture is AtlasTexture)
    check("mobile artwork cannot draw beyond its card",stage_art!=null and stage_art.stretch_mode==TextureRect.STRETCH_SCALE and stage_art.clip_contents)
    if stage_art!=null and action!=null:
        print("STAGE ART GEOMETRY: art=%s action=%s" % [stage_art.get_global_rect(), action.get_global_rect()])
    check("mobile image leaves next-step action unobstructed",stage_art!=null and action!=null and not stage_art.get_global_rect().intersects(action.get_global_rect()))
    if stage_art!=null and stage_art.texture is AtlasTexture:
        check("warehouse uses warehouse sprite sheet",(stage_art.texture as AtlasTexture).atlas.resource_path.ends_with("building_warehouse_progression.svg"))
    for item in [[3,"Workshop","building_factory_progression.svg"],[6,"Commercial Building","building_office_progression.svg"]]:
        hud._select_building(int(item[0]))
        for _frame in range(3):
            await process_frame
        var staged_content:=hud.get("mobile_content") as Control
        var staged_art:=staged_content.find_child("ActiveRestorationArt",true,false) as TextureRect
        check("selected %s uses correct stage art" % str(item[1]),staged_art!=null and staged_art.texture is AtlasTexture and (staged_art.texture as AtlasTexture).atlas.resource_path.ends_with(str(item[2])))
    hud._select_building(0)
    for _frame in range(3):
        await process_frame
    content=hud.get("mobile_content") as Control
    hero=content.get_node_or_null("ExecutiveHero") as Control
    stage_art=hero.get_node_or_null("ActiveRestorationArt") as TextureRect
    title=hero.get_node_or_null("HeroTitle") as Label
    goal=hero.get_node_or_null("HeroGoal") as Label
    action=hero.get_node_or_null("PrimaryNextMove") as Button
    check("mobile objective retains actual property",title!=null and title.text.contains("Riverside Warehouse"))
    check("mobile image clears objective title",stage_art!=null and title!=null and not stage_art.get_global_rect().intersects(title.get_global_rect()))
    check("mobile image clears objective description",stage_art!=null and goal!=null and not stage_art.get_global_rect().intersects(goal.get_global_rect()))
    if goal!=null and goal.get_visible_line_count()<goal.get_line_count():
        print("GOAL OVERFLOW: %d of %d lines visible in %s" % [goal.get_visible_line_count(),goal.get_line_count(),goal.size])
    check("mobile goal has readable 11px type on regular phones",goal!=null and goal.get_theme_font_size("font_size")>=11)
    check("mobile goal retains expanded three-line height",goal!=null and goal.size.y>=80.0 and goal.custom_maximum_size.y>=80.0)
    check("mobile objective wraps rather than clips its explanation",goal!=null and goal.get_line_count()>=3 and goal.get_visible_line_count()>=goal.get_line_count())
    check("mobile primary action fits inside hero",action!=null and hero.get_global_rect().encloses(action.get_global_rect()))
    check("mobile primary action retains true destination copy",action!=null and action.text=="OPEN NEXT STEP")
    var cash_icon:=content.get_node_or_null("Stat_cash/StatIcon") as TextureRect
    check("small metric icon uses bounded texture rendering",cash_icon!=null and cash_icon.texture!=null and cash_icon.stretch_mode==TextureRect.STRETCH_SCALE and cash_icon.clip_contents and cash_icon.size.x<=22.0 and cash_icon.size.y<=22.0)
    check("compact command overview exists",content.get_node_or_null("CommandOverview")!=null)
    check("property overview link exists",content.find_child("OpenHomeProperties",true,false) is Button)
    var nav:=hud.get("bottom_nav") as Control
    check("mobile nav stays inside viewport",nav!=null and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(nav.get_global_rect()))
    var home_tab:=nav.get_node_or_null("ProductionTabs/Nav_HOME/NavLabel") as Label if nav!=null else null
    check("phone bottom navigation type remains legible",home_tab!=null and home_tab.get_theme_font_size("font_size")>=10)
    var home_nav:=nav.get_node_or_null("ProductionTabs/Nav_HOME") as Button if nav!=null else null
    var home_icon:=home_nav.get_node_or_null("NavIcon") as TextureRect if home_nav!=null else null
    check("bottom nav icon remains inside its actual button slot",home_icon!=null and home_icon.stretch_mode==TextureRect.STRETCH_SCALE and home_icon.clip_contents and home_icon.get_global_rect().size.x<=22.0 and home_icon.get_global_rect().size.y<=22.0)
    var finance_nav:=nav.get_node_or_null("ProductionTabs/Nav_FINANCE") as Button if nav!=null else null
    var level_state:=root.get_node_or_null("RenewGameState")
    if level_state!=null and finance_nav!=null:
        var starting_level:=int(level_state.get_value("progression","level",1))
        var starting_unlocks:=level_state.get_value("progression","unlocks",[]).duplicate(true)
        check("Finance starts locked at level one",starting_level==1 and finance_nav.disabled)
        var previous_signature:=str(hud.call("_state_signature"))
        level_state.set_value("progression","level",2)
        check("level-only progression invalidates HUD state",str(hud.call("_state_signature"))!=previous_signature)
        hud._process(0.6)
        check("phone Finance unlocks with level-only progression",not finance_nav.disabled)
        var level_tag:=finance_nav.get_node_or_null("UnlockLevel") as Label
        check("unlocked Finance removes its level badge",level_tag!=null and not level_tag.visible)
        finance_nav.pressed.emit()
        check("newly unlocked Finance opens real finance view",str(hud.get("active_view"))=="finance")
        hud.open_figma_view("live")
        await process_frame
        finance_nav=hud.get("bottom_nav").get_node_or_null("ProductionTabs/Nav_FINANCE") as Button
        level_state.set_value("progression","level",starting_level)
        level_state.set_value("progression","unlocks",starting_unlocks)
        hud._process(0.6)
        check("phone Finance relocks when authority returns to level one",finance_nav!=null and finance_nav.disabled)
        hud._set_tab(3)
        check("a locked primary route refuses navigation",str(hud.get("active_view"))=="live")
    var theme:=root.get_node_or_null("RestoraThemeManager")
    if theme!=null:
        theme.set_mode("light")
        await process_frame
    check("warm limestone palette",theme!=null and theme.color("bg").to_html(false)=="f1ece1")
    check("aged brass accent",theme!=null and theme.color("gold").to_html(false)=="9a6728")
    check("plum selection",theme!=null and theme.color("plum").to_html(false)=="74465a")
    for detail_view in ["property_overview", "before_after"]:
        hud.open_figma_view(detail_view)
        await process_frame
        var detail_content:=hud.get("mobile_content") as Control
        var detail_art:=detail_content.find_child("FlowArtwork",true,false) as TextureRect
        check(detail_view+" uses selected real stage artwork",detail_art!=null and detail_art.texture is AtlasTexture and (detail_art.texture as AtlasTexture).atlas.resource_path.ends_with("building_warehouse_progression.svg"))
    hud.open_figma_view("property")
    await process_frame
    content=hud.get("mobile_content") as Control
    check("property catalog shows nine rows",content.find_children("BuildingRow*","Panel",true,false).size()==9)
    check("property view includes restoration artwork",content.find_child("PropertyVisual",true,false) is TextureRect)
    hud.open_figma_view("live")
    await process_frame
    root.size=Vector2i(320,568)
    await process_frame
    hud._layout_responsive()
    for _frame in range(3):
        await process_frame
    var small_content:=hud.get("mobile_content") as Control
    var small_goal:=small_content.get_node_or_null("ExecutiveHero/HeroGoal") as Label
    check("320px Home keeps full instructions visible",small_goal!=null and small_goal.get_visible_line_count()==small_goal.get_line_count() and small_goal.get_theme_font_size("font_size")>=10)

    for viewport in [Vector2i(700,900),Vector2i(768,1024),Vector2i(834,1194)]:
        root.size=viewport
        for _frame in range(2):
            await process_frame
        hud._layout_responsive()
        await process_frame
        var tablet:=runtime.get_node_or_null("TabletLive") as Control
        check("tablet canvas exists and fits %s" % viewport,tablet!=null and Rect2(Vector2.ZERO,Vector2(viewport)).grow(1.0).encloses(tablet.get_global_rect()))
        var tablet_nav:=tablet.get_node_or_null("Nav") as Panel if tablet!=null else null
        check("tablet bottom navigation exists",tablet_nav!=null)
        if tablet_nav!=null:
            for label in ["HOME","BUSINESS","PROPERTY","FINANCE","MORE"]:
                var button:=tablet_nav.get_node_or_null("TabletNav_"+label) as Button
                check("tablet "+label+" is a contained actionable target at %s" % viewport,button!=null and Rect2(Vector2.ZERO,Vector2(viewport)).grow(1.0).encloses(button.get_global_rect()) and button.get_global_rect().size.y>=48.0 and button.pressed.get_connections().size()>0)
                if label=="FINANCE" and button!=null:
                    check("tablet finance respects unlock level",button.disabled==not bool(hud.call("_has_unlock","finance")))
    var tablet_now:=runtime.get_node_or_null("TabletLive") as Control
    var prop_tab:=tablet_now.get_node_or_null("Nav/TabletNav_PROPERTY") as Button if tablet_now!=null else null
    check("tablet property route is enabled",prop_tab!=null and not prop_tab.disabled)
    if prop_tab!=null:
        prop_tab.pressed.emit()
        await process_frame
        check("tablet property button opens correct destination",str(hud.get("active_view"))=="property")
        check("tablet property Back succeeds",hud.handle_system_back())
        await process_frame
        check("tablet Back restores Home",str(hud.get("active_view"))=="live")
    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var desktop:=runtime.get_node_or_null("DesktopExecutive") as Control
    check("desktop management canvas exists",desktop!=null)
    root.size=Vector2i(1100,760)
    await process_frame
    hud._layout_responsive()
    await process_frame
    desktop=runtime.get_node_or_null("DesktopExecutive") as Control
    check("same-class desktop resize re-fits canvas",desktop!=null and Rect2(Vector2.ZERO,Vector2(1100,760)).grow(1.0).encloses(desktop.get_global_rect()))
    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    check("desktop property summary exists",desktop!=null and desktop.get_node_or_null("WorldPropertyView")!=null)
    check("desktop quick actions exist",desktop!=null and desktop.get_node_or_null("QuickActions")!=null)
    var desktop_objective_copy:=desktop.get_node_or_null("Objective/Body") as Label if desktop!=null else null
    var desktop_signal_copy:=desktop.get_node_or_null("Signals/Body") as Label if desktop!=null else null
    check("desktop main objective is readable and unclipped",desktop_objective_copy!=null and desktop_objective_copy.get_theme_font_size("font_size")>=15 and desktop_objective_copy.get_visible_line_count()==desktop_objective_copy.get_line_count())
    check("desktop signal text has readable type",desktop_signal_copy!=null and desktop_signal_copy.get_theme_font_size("font_size")>=15)
    var desktop_finance:=desktop.get_node_or_null("QuickActions/OpenFinance") as Button if desktop!=null else null
    check("desktop Finance obeys the canonical unlock",desktop_finance!=null and desktop_finance.disabled==not bool(hud.call("_has_unlock","finance")))
    var next_button:=desktop.get_node_or_null("Objective/OpenNextObjective") as Button if desktop!=null else null
    check("desktop next-step action is reachable",next_button!=null and next_button.pressed.get_connections().size()>0 and next_button.size.y>=36.0)
    var desktop_world:=desktop.get_node_or_null("WorldPropertyView") as Control if desktop!=null else null
    if desktop_world!=null:
        for phase in ["cleaning","repair","painting","furnishing"]:
            var meter:=desktop_world.get_node_or_null("PhaseTrack_"+phase+"/Fill") as Panel
            check("desktop %s progress meter fits inside property card" % phase,meter!=null and desktop_world.get_global_rect().grow(1.0).encloses(meter.get_global_rect()))
    var tutorial := game.get_node_or_null("UI/TutorialOverlay")
    var tutorial_panel := tutorial.get("panel") as Panel if tutorial!=null else null
    var tutorial_chip := tutorial.get("collapsed_button") as Button if tutorial!=null else null
    check("first-session guide is not covering desktop metrics",tutorial_panel!=null and not tutorial_panel.visible)
    check("desktop guide remains discoverable",tutorial_chip!=null and tutorial_chip.visible)
    var objective_title:=desktop.get_node_or_null("Objective/Title") as Label if desktop!=null else null
    check("desktop starts with inspection objective",objective_title!=null and objective_title.text.begins_with("Inspect "))
    game.inspect_property()
    await process_frame
    hud._refresh()
    await process_frame
    check("desktop objective updates after inspection",objective_title!=null and objective_title.text.begins_with("Acquire "))
    var preview := desktop.get_node_or_null("WorldPropertyView/Scene/RestorationPreview") as TextureRect
    check("desktop renders actual restoration-stage artwork",preview!=null and preview.texture is AtlasTexture)
    game.acquire_property()
    await process_frame
    hud._refresh()
    var progress := desktop.get_node_or_null("WorldPropertyView/Scene/Progress") as Label
    check("desktop restoration starts in sync",progress!=null and progress.text=="%d%% RESTORED" % int(hud.call("_building_progress")))
    var before_stage := int(hud.call("_building_progress"))
    game.restore_property()
    await process_frame
    hud._refresh()
    var after_stage := int(hud.call("_building_progress"))
    check("real restoration action progresses",after_stage>before_stage)
    check("desktop restoration updates without reopening",progress!=null and progress.text=="%d%% RESTORED" % after_stage)
    var phase_sum:=0
    for phase in ["cleaning","repair","painting","furnishing"]:
        var value:=clampi(int((hud.call("_selected_building") as Dictionary).get(phase,0)),0,100)
        phase_sum+=value
        var meter:=desktop_world.get_node_or_null("PhaseTrack_"+phase+"/Fill") as Panel if desktop_world!=null else null
        var percent_label:=desktop_world.get_node_or_null("PhaseValue_"+phase) as Label if desktop_world!=null else null
        check("desktop %s meter follows real restoration" % phase,meter!=null and is_equal_approx(meter.size.x,220.0*float(value)/100.0) and percent_label!=null and percent_label.text=="%d%%" % value)
    check("restoration progress is meaningful",phase_sum>0)
    if next_button!=null:
        next_button.pressed.emit()
        await process_frame
        check("desktop next-step opens current authoritative destination",str(hud.get("active_view"))==str(hud.call("_objective_view")))
    if preview!=null and preview.texture is AtlasTexture:
        var crop := preview.texture as AtlasTexture
        check("desktop art shows authoritative stage",is_equal_approx(crop.region.position.y,float(clampi(int(hud.call("_building_stage_slot")),0,5)*144)))
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
