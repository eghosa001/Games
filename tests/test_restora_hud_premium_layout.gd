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
    check("compact command overview exists",content.get_node_or_null("CommandOverview")!=null)
    check("property overview link exists",content.find_child("OpenHomeProperties",true,false) is Button)

    var nav:=hud.get("bottom_nav") as Control
    check("mobile nav stays inside viewport",nav!=null and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(nav.get_global_rect()))

    var theme:=root.get_node_or_null("RestoraThemeManager")
    check("graphite dark palette",theme!=null and theme.color("bg").to_html(false)=="0b0d10")
    check("aged brass accent",theme!=null and theme.color("gold").to_html(false)=="c99a4b")
    check("plum selection",theme!=null and theme.color("plum").to_html(false)=="7a405f")

    hud.open_figma_view("property")
    await process_frame
    content=hud.get("mobile_content") as Control
    check("property catalog shows nine rows",content.find_children("BuildingRow*","Panel",true,false).size()==9)
    check("property view is status-only",content.find_child("BuildingStageArt",true,false)==null and content.find_child("PropertyVisual",true,false)==null)

    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var desktop:=runtime.get_node_or_null("DesktopExecutive") as Control
    check("desktop management canvas exists",desktop!=null)
    check("desktop property summary exists",desktop!=null and desktop.get_node_or_null("WorldPropertyView")!=null)
    check("desktop quick actions exist",desktop!=null and desktop.get_node_or_null("QuickActions")!=null)
    var objective_title:=desktop.get_node_or_null("Objective/Title") as Label if desktop!=null else null
    check("desktop starts with inspection objective",objective_title!=null and objective_title.text.begins_with("Inspect "))
    game.inspect_property()
    await process_frame
    hud._refresh()
    await process_frame
    check("desktop objective updates after inspection",objective_title!=null and objective_title.text.begins_with("Acquire "))

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
