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
    check("mobile objective retains actual property",title!=null and title.text.contains("Riverside Warehouse"))
    check("mobile image clears objective title",stage_art!=null and title!=null and not stage_art.get_global_rect().intersects(title.get_global_rect()))
    check("mobile image clears objective description",stage_art!=null and goal!=null and not stage_art.get_global_rect().intersects(goal.get_global_rect()))
    check("mobile primary action fits inside hero",action!=null and hero.get_global_rect().encloses(action.get_global_rect()))
    check("mobile primary action retains true destination copy",action!=null and action.text=="OPEN NEXT STEP")
    check("compact command overview exists",content.get_node_or_null("CommandOverview")!=null)
    check("property overview link exists",content.find_child("OpenHomeProperties",true,false) is Button)
    var nav:=hud.get("bottom_nav") as Control
    check("mobile nav stays inside viewport",nav!=null and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(nav.get_global_rect()))
    var theme:=root.get_node_or_null("RestoraThemeManager")
    if theme!=null:
        theme.set_mode("light")
        await process_frame
    check("warm limestone palette",theme!=null and theme.color("bg").to_html(false)=="f1ece1")
    check("aged brass accent",theme!=null and theme.color("gold").to_html(false)=="9a6728")
    check("plum selection",theme!=null and theme.color("plum").to_html(false)=="74465a")
    hud.open_figma_view("property")
    await process_frame
    content=hud.get("mobile_content") as Control
    check("property catalog shows nine rows",content.find_children("BuildingRow*","Panel",true,false).size()==9)
    check("property view includes restoration artwork",content.find_child("PropertyVisual",true,false) is TextureRect)
    hud.open_figma_view("live")
    await process_frame
    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var desktop:=runtime.get_node_or_null("DesktopExecutive") as Control
    check("desktop management canvas exists",desktop!=null)
    check("desktop property summary exists",desktop!=null and desktop.get_node_or_null("WorldPropertyView")!=null)
    check("desktop quick actions exist",desktop!=null and desktop.get_node_or_null("QuickActions")!=null)
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
    if preview!=null and preview.texture is AtlasTexture:
        var crop := preview.texture as AtlasTexture
        check("desktop art shows authoritative stage",is_equal_approx(crop.region.position.y,float(clampi(int(hud.call("_building_stage_slot")),0,5)*144)))
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
