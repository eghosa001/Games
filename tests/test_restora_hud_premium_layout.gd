extends SceneTree
var failed:=0
func _initialize()->void:call_deferred("_run")
func check(label:String,ok:bool)->void:
    if ok:print("PASS: "+label)
    else:failed += 1;push_error("FAIL: "+label)
func _run()->void:
    root.size=Vector2i(390,844)
    var p:=load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads",p!=null)
    if p==null:quit(1);return
    var game:=p.instantiate();root.add_child(game);current_scene=game
    await process_frame;await process_frame
    var hud:=game.get_node("UI/MainHUD")
    var runtime:=hud.get("root") as Control
    check("Figma runtime root",runtime.name=="RestoraFigmaRuntime")
    var content:=hud.get("mobile_content") as Control
    var hero:=content.get_node_or_null("ExecutiveHero") as Control
    check("hero exact size",hero!=null and hero.position==Vector2(18,82) and hero.size==Vector2(354,154))
    var hero_wash:=hero.get_node_or_null("HeroContrastWash") as ColorRect if hero!=null else null
    check("hero art contrast wash",hero_wash!=null and hero_wash.color.a>=0.55 and hero_wash.position.x<=108.0)
    var signals:=content.get_node_or_null("Signals") as Control
    check("signals exact size",signals!=null and signals.position==Vector2(18,494) and signals.size==Vector2(354,192))
    var nav:=hud.get("bottom_nav") as Control
    check("nav exact mobile geometry",nav!=null and nav.position==Vector2(12,758) and nav.size==Vector2(366,70))
    var theme:=root.get_node_or_null("RestoraThemeManager")
    check("graphite dark palette",theme!=null and theme.color("bg").to_html(false)=="0b0d10")
    check("aged brass accent",theme!=null and theme.color("gold").to_html(false)=="c99a4b")
    check("tyrian plum selection",theme!=null and theme.color("plum").to_html(false)=="7a405f")
    root.size=Vector2i(1280,720);await process_frame;hud._layout_responsive();await process_frame
    var desktop:=runtime.get_node_or_null("DesktopExecutive") as Control
    check("desktop exact Figma canvas exists",desktop!=null and desktop.size==Vector2(1280,720))
    check("desktop world panel",desktop!=null and desktop.get_node_or_null("WorldPropertyView")!=null)
    check("desktop quick actions",desktop!=null and desktop.get_node_or_null("QuickActions")!=null)
    var property_meta:=desktop.get_node_or_null("WorldPropertyView/Meta") as Label if desktop!=null else null
    var objective_title:=desktop.get_node_or_null("Objective/Title") as Label if desktop!=null else null
    check("desktop selected building has real market value",property_meta!=null and property_meta.text.contains("$65.0K market value"))
    check("desktop starts with inspection objective",objective_title!=null and objective_title.text.begins_with("Inspect "))
    game.inspect_property();await process_frame;hud._refresh();await process_frame
    check("desktop objective updates after inspection",objective_title.text.begins_with("Acquire "))
    var worth_before:=str((desktop.get_node_or_null("Worth/Value") as Label).text)
    game.acquire_property();await process_frame;hud._refresh();await process_frame
    check("desktop objective updates after acquisition",objective_title.text.begins_with("Restore "))
    check("desktop worth updates from owned property",str((desktop.get_node_or_null("Worth/Value") as Label).text)!=worth_before)
    var strategy:=game.get_node_or_null("UI/StrategyHUD")
    var strategy_panel:=strategy.get("panel") as Panel if strategy!=null else null
    check("duplicate strategy overlay stays hidden",strategy_panel!=null and not strategy_panel.visible)
    game.queue_free();await process_frame
    quit(1 if failed > 0 else 0)
