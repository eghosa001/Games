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

func _text_contrast(fg: Color, bg: Color) -> float:
    var a: float = fg.srgb_to_linear().get_luminance()
    var b: float = bg.srgb_to_linear().get_luminance()
    return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

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
    # City-first HOME replaces the oversized portrait of one selected site.
    var city:=content.get_node_or_null("HomeCity") as Control
    check("Home exposes an open city instead of one warehouse",city!=null)
    check("every property is discoverable on Home",city!=null and city.find_children("CityProperty*","Panel",true,false).size()==9)
    var first_card:=content.find_child("CityProperty0",true,false) as Control
    var workshop:=content.find_child("CityProperty3",true,false) as Control
    var commercial:=content.find_child("CityProperty6",true,false) as Control
    var cards: Array = [first_card,workshop,commercial]
    var expected_art: Array = ["building_warehouse_progression.svg","building_factory_progression.svg","building_office_progression.svg"]
    for i in range(cards.size()):
        var tile:Control=cards[i]
        var art:=tile.get_node_or_null("BuildingArtwork") as TextureRect if tile!=null else null
        check("Home property %d renders the correct building artwork" % i,art!=null and art.texture is AtlasTexture and (art.texture as AtlasTexture).atlas.resource_path.ends_with(expected_art[i]))
        check("Home property %d image remains within its card" % i,art!=null and art.expand_mode==TextureRect.EXPAND_IGNORE_SIZE and art.stretch_mode==TextureRect.STRETCH_SCALE and tile.get_global_rect().encloses(art.get_global_rect()))
    var title:=hero.get_node_or_null("HeroTitle") as Label if hero!=null else null
    var goal:=hero.get_node_or_null("HeroGoal") as Label if hero!=null else null
    var action:=hero.get_node_or_null("PrimaryNextMove") as Button if hero!=null else null
    check("Home next action remains understandable",title!=null and title.text.length()>5 and action!=null and action.size.y>=44)
    check("Home hero leaves room for the city",hero!=null and hero.size.y<=200.0)
    check("multiple building cards appear after cash and worth",city!=null and city.position.y < 400.0)
    check("mobile goal has readable text",goal!=null and goal.get_theme_font_size("font_size")>=11)
    check("mobile primary action fits inside hero",action!=null and hero.get_global_rect().encloses(action.get_global_rect()))
    check("mobile primary action retains true destination copy",action!=null and action.text==str(hud.call("_home_primary_title")))
    var workshop_open:=content.find_child("OpenCityProperty3",true,false) as Button
    if workshop_open!=null:
        workshop_open.pressed.emit()
        await process_frame
    check("a different Home building opens its real property",str(hud.get("active_view"))=="property" and str(hud.call("_building_type"))=="Workshop")
    hud.open_figma_view("live")
    await process_frame
    content=hud.get("mobile_content") as Control
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
        check("Finance is available immediately at level one",starting_level==1 and not finance_nav.disabled)
        var previous_signature:=str(hud.call("_state_signature"))
        level_state.set_value("progression","level",2)
        check("earning a level still invalidates HUD milestone state",str(hud.call("_state_signature"))!=previous_signature)
        hud._process(0.6)
        check("Finance remains usable after leveling up",not finance_nav.disabled)
        finance_nav.pressed.emit()
        check("finance opens without a company level gate",str(hud.get("active_view"))=="finance")
        hud.open_figma_view("live")
        level_state.set_value("progression","level",starting_level)
        hud._process(0.6)
        finance_nav=hud.get("bottom_nav").get_node_or_null("ProductionTabs/Nav_FINANCE") as Button
        check("Finance stays available on returning to level one",finance_nav!=null and not finance_nav.disabled)
    var accessibility_theme:=root.get_node_or_null("RestoraThemeManager")
    check("accessibility theme manager is available",accessibility_theme!=null)
    if accessibility_theme!=null:
        for viewport in [Vector2i(390,844),Vector2i(320,568)]:
            root.size=viewport
            await process_frame
            hud._layout_responsive()
            accessibility_theme.set_text_scale(1.30)
            for _frame in range(4):
                await process_frame
            var accessible_content:=hud.get("mobile_content") as Control
            var accessible_hero:=accessible_content.get_node_or_null("ExecutiveHero") as Control
            var accessible_goal:=accessible_hero.get_node_or_null("HeroGoal") as Label if accessible_hero!=null else null
            var accessible_city:=accessible_content.get_node_or_null("HomeCity") as Control
            var accessible_action:=accessible_hero.get_node_or_null("PrimaryNextMove") as Button if accessible_hero!=null else null
            var cash_tile:=accessible_content.get_node_or_null("Stat_cash") as Control
            var cash_value:=cash_tile.get_node_or_null("Value") as Label if cash_tile!=null else null
            var cash_meta:=cash_tile.get_node_or_null("Meta") as Label if cash_tile!=null else null
            check("large text at %s keeps city visible and description legible" % viewport,accessible_city!=null and accessible_goal!=null and accessible_goal.get_theme_font_size("font_size")>=13)
            check("large text at %s shows all instruction lines" % viewport,accessible_goal!=null and accessible_goal.get_visible_line_count()==accessible_goal.get_line_count())
            check("large text at %s keeps button legible and below copy" % viewport,accessible_action!=null and accessible_goal!=null and accessible_action.get_theme_font_size("font_size")>=15 and accessible_goal.get_global_rect().end.y<=accessible_action.get_global_rect().position.y)
            check("large text at %s separates KPI value and caption" % viewport,cash_value!=null and cash_meta!=null and cash_value.get_global_rect().end.y<cash_meta.get_global_rect().position.y and cash_tile.get_global_rect().grow(1.0).encloses(cash_meta.get_global_rect()))
        accessibility_theme.set_text_scale(1.0)
        root.size=Vector2i(390,844)
        await process_frame
        hud._layout_responsive()
        for _frame in range(3):
            await process_frame
        var standard_city:=(hud.get("mobile_content") as Control).get_node_or_null("HomeCity") as Control
        check("normal text preserves the entire playable city",standard_city!=null and standard_city.find_children("CityProperty*","Panel",true,false).size()==9)
    var theme:=root.get_node_or_null("RestoraThemeManager")
    if theme!=null:
        theme.set_mode("light")
        await process_frame
    check("warm limestone palette",theme!=null and theme.color("bg").to_html(false)=="f1ece1")
    check("aged brass accent",theme!=null and theme.color("gold").to_html(false)=="9a6728")
    check("plum selection",theme!=null and theme.color("plum").to_html(false)=="74465a")
    if theme!=null:
        for mode in ["light","dark"]:
            theme.set_mode(mode)
            for _frame in range(3):
                await process_frame
            var theming_hero:=(hud.get("mobile_content") as Control).get_node_or_null("ExecutiveHero") as Control
            var primary:=theming_hero.get_node_or_null("PrimaryNextMove") as Button if theming_hero!=null else null
            for button_state in ["normal","hover","pressed","focus"]:
                var fill:=primary.get_theme_stylebox(button_state) as StyleBoxFlat if primary!=null else null
                var fg_color:=primary.get_theme_color("font_color") if primary!=null else Color.BLACK
                var ratio:=_text_contrast(fg_color,fill.bg_color) if fill!=null else 0.0
                check("%s primary %s has >=4.5 text contrast" % [mode,button_state],ratio>=4.5 and fill!=null and fill.bg_color.a>=0.99)
        theme.set_mode("light")
        await process_frame
    for detail_view in ["property_overview", "before_after"]:
        hud.open_figma_view(detail_view)
        await process_frame
        var detail_content:=hud.get("mobile_content") as Control
        var detail_art:=detail_content.find_child("FlowArtwork",true,false) as TextureRect
        check(detail_view+" uses selected real stage artwork",detail_art!=null and detail_art.texture is AtlasTexture and (detail_art.texture as AtlasTexture).atlas == hud.call("_property_stage_texture"))
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
    var tablet_art:=tablet_now.get_node_or_null("Hero/TabletRestorationArt") as TextureRect if tablet_now!=null else null
    check("tablet has stage-specific architectural artwork",tablet_art!=null and tablet_art.texture is AtlasTexture and tablet_art.size.x>=200.0)
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
    root.size=Vector2i(1280,577)
    await process_frame
    hud._layout_responsive()
    await process_frame
    desktop=runtime.get_node_or_null("DesktopExecutive") as Control
    check("short desktop uses 560px-native canvas",desktop!=null and is_equal_approx(desktop.size.y,560.0) and desktop.scale.x>=0.99 and desktop.scale.y>=0.99)
    var compact_quick:=desktop.get_node_or_null("QuickActions") as Control if desktop!=null else null
    var compact_world:=desktop.get_node_or_null("WorldPropertyView") as Control if desktop!=null else null
    check("short desktop keeps property and quick actions on-screen",compact_quick!=null and compact_world!=null and Rect2(Vector2.ZERO,Vector2(1280,577)).encloses(compact_quick.get_global_rect()) and Rect2(Vector2.ZERO,Vector2(1280,577)).encloses(compact_world.get_global_rect()))
    var compact_property_title:=desktop.get_node_or_null("WorldPropertyView/Scene/PropertyName") as Label if desktop!=null else null
    var compact_stage_image:=desktop.get_node_or_null("WorldPropertyView/Scene/RestorationPreview") as TextureRect if desktop!=null else null
    check("short desktop does not truncate the selected property name",compact_property_title!=null and compact_property_title.size.x>=400.0 and compact_property_title.get_visible_line_count()==compact_property_title.get_line_count())
    check("short desktop art is below property headline",compact_property_title!=null and compact_stage_image!=null and compact_property_title.get_global_rect().end.y<=compact_stage_image.get_global_rect().position.y)
    var browser_adapter:=FileAccess.get_file_as_string("res://scripts/web_responsive.gd")
    check("browser adapter uses live landscape viewport",browser_adapter.contains("root.content_scale_size = browser") and browser_adapter.contains("Window.CONTENT_SCALE_ASPECT_IGNORE"))
    check("JS viewport bridge returns convertible string dimensions",browser_adapter.contains("String(Math.round(window.innerWidth))") and browser_adapter.contains("parts.size() == 2") and not browser_adapter.contains("result is Array"))
    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    desktop=runtime.get_node_or_null("DesktopExecutive") as Control
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
