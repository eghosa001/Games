extends CanvasLayer

## Unified presentation surface for identity, objectives, milestones, notices and empire power.
## Read-only intelligence: gameplay/progression systems remain authoritative.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const SURFACE_3 := Color("132f38")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const GREEN := Color(0.25,0.85,0.45)

var panel: Panel
var title_label: Label
var status_label: Label
var close_button: Button
var summary: Label
var scroll: ScrollContainer
var content: VBoxContainer
var refresh_clock := 0.0
var last_signature := ""

func _ready() -> void:
    layer = 74
    _build()
    _layout()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible or panel == null or not panel.visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _game() -> Node:
    return get_tree().root.get_node_or_null("Renew")

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var s:=StyleBoxFlat.new(); s.bg_color=bg; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s

func _label(text:String,size:int,color:Color)->Label:
    var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; return l

func _button(text:String,cb:Callable)->Button:
    var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(82,46); b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",10); b.add_theme_color_override("font_color",TEXT); b.add_theme_stylebox_override("normal",_style(SURFACE_2,BORDER,8)); b.add_theme_stylebox_override("hover",_style(Color("17343d"),ACCENT,8)); b.add_theme_stylebox_override("pressed",_style(Color("1b3d46"),ACCENT,8)); b.pressed.connect(cb); return b

func _build()->void:
    panel=Panel.new(); panel.name="EmpireIntelligenceSurface"; panel.mouse_filter=Control.MOUSE_FILTER_STOP; panel.add_theme_stylebox_override("panel",_style(SURFACE,BORDER,14)); add_child(panel)
    title_label=_label("EMPIRE INTELLIGENCE",20,TEXT); panel.add_child(title_label)
    status_label=_label("STRATEGY • LIVE",10,ACCENT); panel.add_child(status_label)
    close_button=_button("CLOSE",_close); panel.add_child(close_button)
    summary=_label("",11,MUTED); panel.add_child(summary)
    scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    content=VBoxContainer.new(); content.add_theme_constant_override("separation",9); scroll.add_child(content)

func _card(heading:String,body:String)->void:
    var card:=Panel.new(); card.custom_minimum_size.y=86; card.add_theme_stylebox_override("panel",_style(SURFACE_3,BORDER,10)); content.add_child(card)
    var h:=_label(heading,12,ACCENT); h.position=Vector2(12,9); h.size=Vector2(500,22); card.add_child(h)
    var b:=_label(body,11,TEXT); b.position=Vector2(12,32); b.size=Vector2(500,48); card.add_child(b)

func _refresh(force: bool = false)->void:
    var g:=_game(); if g==null:return
    var goals=g.get_node_or_null("Systems/EmpireGoals")
    var prog=g.get_node_or_null("Systems/Progression")
    var region=g.get_node_or_null("World/RegionController")
    var rivals=g.get_node_or_null("World/Corporate")
    var name:=str(g.get("company_name")) if "company_name" in g else "RENEW COMPANY"
    if name=="<null>" or name=="": name="RENEW COMPANY"
    var cash:=int(g.get("cash")) if "cash" in g else 0
    var rep:=int(g.get("reputation")) if "reputation" in g else 0
    var day:=int(g.get("day")) if "day" in g else 0
    var presence:=0
    if region!=null and "regions" in region and region.regions!=null and "player_presence" in region.regions:
        presence=int(region.regions.player_presence.count(1))
    var rival_count:=0
    if rivals!=null and "rivals" in rivals: rival_count=rivals.rivals.size()
    var goal_title:="EMPIRE MASTERED"
    var goal_text:="Every company objective is complete."
    var done:=0
    var total:=0
    if goals!=null and goals.has_method("current_goal"):
        var goal:Dictionary=goals.current_goal()
        goal_title=str(goal.get("title",goal_title)); goal_text=str(goal.get("text",goal_text))
        done=goals.completed_count() if goals.has_method("completed_count") else 0
        total=goals.goals.size() if "goals" in goals else 0
    var claimed:=0
    var milestone_total:=0
    if prog!=null and "milestones" in prog:
        claimed=int(prog.claimed.size()) if prog.claimed is Dictionary else 0
        milestone_total=prog.milestones.size()
    var message:=str(g.get("message")) if "message" in g else "No recent company notice."
    if message=="": message="No recent company notice."
    var signature:="%s:%d:%d:%d:%d:%d:%s:%d:%d" % [name,day,cash,rep,presence,rival_count,message,done,claimed]
    if not force and signature==last_signature:return
    last_signature=signature
    for child in content.get_children(): child.queue_free()
    summary.text="%s  •  DAY %d  •  CASH $%s  •  REP %d" % [name,day,g._money(cash) if g.has_method("_money") else str(cash),rep]
    _card("NEXT OBJECTIVE  •  %d/%d COMPLETE" % [done,total], "%s\n%s" % [goal_title,goal_text])
    if prog!=null and "milestones" in prog:
        _card("MILESTONE TRACKER", "%d of %d milestones achieved.\nMilestones record major company moments and reinforce long-term progression." % [claimed,milestone_total])
    _card("EMPIRE POWER", "REGIONAL FOOTPRINT  %d\nRIVAL NETWORK  %d corporations\nREPUTATION  %d" % [presence,rival_count,rep])
    _card("LATEST NOTICE",message)
    _card("COMPANY IDENTITY","%s\nYour identity, reputation and strategic history are presented here as the executive record of the company." % name)
    _card("EXECUTIVE GUIDANCE", "Prioritize the next objective while protecting cash, reputation and management capacity. Use the operating surfaces to act; this screen keeps the strategic picture visible." if done<total else "All current objectives are complete. Continue expanding the network, strengthening regional presence and building the economic empire.")
    status_label.text="STRATEGY • %d REGIONS • %d RIVALS" % [presence,rival_count]
    _layout()

func _close()->void:
    var manager=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible=false

func _layout()->void:
    if panel==null:return
    var size:=get_viewport().get_visible_rect().size; var narrow:=size.x<760.0
    var width:=maxf(304.0,size.x-16.0) if narrow else minf(620.0,size.x-36.0)
    var height:=maxf(430.0,size.y-90.0) if narrow else minf(720.0,size.y-120.0)
    panel.position=Vector2(8,70) if narrow else Vector2(maxf(18.0,size.x-width-18.0),90); panel.size=Vector2(width,height)
    title_label.position=Vector2(14,10); title_label.size=Vector2(width-130,30); status_label.position=Vector2(14,39); status_label.size=Vector2(width-28,20); close_button.position=Vector2(width-92,7); close_button.size=Vector2(82,46)
    summary.position=Vector2(14,62); summary.size=Vector2(width-28,38)
    scroll.position=Vector2(12,106); scroll.size=Vector2(width-24,height-114); content.custom_minimum_size.x=width-24
    for child in content.get_children():
        child.custom_minimum_size.y=96 if narrow else 90
        for sub in child.get_children():
            if sub is Label:
                sub.size.x=width-48
