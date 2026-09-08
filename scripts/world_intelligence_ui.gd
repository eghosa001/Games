extends CanvasLayer

## World standing, identity paths and notices. Read-only presentation over authoritative systems.
const BG := Color("0b1b22F8")
const CARD := Color("102a33")
const BORDER := Color("2d5059")
const TEXT := Color("edf6f3")
const MUTED := Color("8aa3a8")
const ACCENT := Color("d8b76d")
const GOOD := Color("8ee6a8")

var panel: Panel
var scroll: ScrollContainer
var content: VBoxContainer
var title: Label
var summary: Label
var open := false
var clock := 0.0
var signature := ""

func _ready() -> void:
    layer = 75
    _build()
    _layout()
    close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _game() -> Node: return get_tree().root.get_node_or_null("Renew")
func _ranking() -> Node: return get_node_or_null("/root/RenewGlobalRankingSystem")
func _identity() -> Node: return get_node_or_null("/root/RenewIdentitySystem")
func _news() -> Node: return get_node_or_null("/root/RenewNewsSystem")

func _style(bg:Color,border:Color=BORDER,radius:=12)->StyleBoxFlat:
    var s:=StyleBoxFlat.new(); s.bg_color=bg; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(radius); s.content_margin_left=12; s.content_margin_right=12; s.content_margin_top=10; s.content_margin_bottom=10; return s
func _label(text:String,size:int,color:Color)->Label:
    var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.mouse_filter=Control.MOUSE_FILTER_IGNORE; return l
func _button(text:String,cb:Callable)->Button:
    var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(84,46); b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",10); b.add_theme_stylebox_override("normal",_style(CARD)); b.add_theme_stylebox_override("hover",_style(Color("183840"),ACCENT)); b.pressed.connect(cb); return b

func _build()->void:
    panel=Panel.new(); panel.name="WorldIntelligenceSurface"; panel.mouse_filter=Control.MOUSE_FILTER_STOP; panel.add_theme_stylebox_override("panel",_style(BG)); add_child(panel)
    title=_label("WORLD INTELLIGENCE",21,TEXT); panel.add_child(title)
    var close:=_button("CLOSE",_close); close.name="CloseButton"; panel.add_child(close)
    summary=_label("WORLD STANDING • LIVE",10,ACCENT); panel.add_child(summary)
    scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    content=VBoxContainer.new(); content.add_theme_constant_override("separation",9); scroll.add_child(content)

func _card(head:String,body:String,tint:=ACCENT)->void:
    var card:=PanelContainer.new(); card.add_theme_stylebox_override("panel",_style(CARD)); card.custom_minimum_size.y=82; content.add_child(card)
    var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",5); card.add_child(box)
    box.add_child(_label(head.to_upper(),11,tint)); box.add_child(_label(body,13,TEXT))

func _refresh(force:=false)->void:
    var g:=_game(); if g==null:return
    var rep:=int(g.get("reputation")) if "reputation" in g else 0
    var day:=int(g.get("day")) if "day" in g else 1
    var ranking:=_ranking(); var power:Dictionary=ranking.world_power() if ranking!=null and ranking.has_method("world_power") else {}
    var identity:=_identity(); var rows:Array=identity.progress() if identity!=null and identity.has_method("progress") else []
    var news:=_news(); var issue:Dictionary=news.get_current_issue() if news!=null and news.has_method("get_current_issue") else {}
    var stories:Array=issue.get("stories",[])
    var sig:="%d|%d|%.1f|%d|%d"%[day,rep,float(power.get("total",0.0)),rows.size(),stories.size()]
    if not force and sig==signature:return
    signature=sig
    summary.text="DAY %d  •  WORLD POWER %.0f/100  •  REP %d"%[day,float(power.get("total",0.0)),rep]
    for child in content.get_children():child.queue_free()
    _card("WORLD POWER","Overall %.0f/100\nEconomic %.0f  •  Industrial %.0f  •  Technology %.0f\nLogistics %.0f  •  Diplomatic %.0f  •  Alliance %.0f  •  Cultural %.0f"%[float(power.get("total",0)),float(power.get("economic",0)),float(power.get("industrial",0)),float(power.get("technology",0)),float(power.get("logistics",0)),float(power.get("diplomatic",0)),float(power.get("alliance",0)),float(power.get("cultural",0))],GOOD)
    _card("GLOBAL POSITION","World standing is calculated from the existing ranking system. Strengthen weaker dimensions instead of chasing a single metric.")
    if identity!=null:
        var completed:=0
        for row in rows: completed+=int(row.get("claimed",0))
        _card("IDENTITY PATHS","%d identity tiers achieved across %d strategic paths.\nBuilder • Tycoon • Industrialist • Diplomat • Innovator • Collector • Magnate • Competitor"%[completed,rows.size()])
        for row in rows:
            var next=row.get("next",null); var progress_text:="%d/%d tiers"%[int(row.get("claimed",0)),int(row.get("total",0))]
            if next!=null: progress_text+="  •  next %.0f"%float(next)
            _card(str(row.get("title","Identity")),progress_text)
    if stories.is_empty():
        _card("NOTICES","No verified world developments are currently published.",MUTED)
    else:
        var limit:=mini(4,stories.size())
        for i in range(limit):
            var story:Dictionary=stories[i]
            _card("NOTICE • "+str(story.get("section","WORLD")),str(story.get("headline","Development"))+"\n"+str(story.get("body","")),ACCENT)
    _card("EXECUTIVE PRIORITY","Use World Power to identify strategic weaknesses, Identity Paths to shape long-term specialization, and Notices to react to changing conditions.",ACCENT)

func _close()->void:
    var manager:=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("hide_all_screens"):manager.hide_all_screens()
    else:close_screen()
func open_screen()->void:open=true; panel.visible=true; _refresh(true)
func close_screen()->void:open=false; if panel!=null:panel.visible=false
func _unhandled_input(event:InputEvent)->void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and open:_close();get_viewport().set_input_as_handled()
func _process(delta:float)->void:
    if not open:return
    clock+=delta
    if clock>=1.0:clock=0.0;_refresh()
func _layout()->void:
    if panel==null:return
    var size:=get_viewport().get_visible_rect().size;var narrow:=size.x<760.0
    var width:=maxf(304.0,size.x-16.0) if narrow else minf(760.0,size.x-36.0)
    var height:=maxf(430.0,size.y-82.0) if narrow else minf(720.0,size.y-90.0)
    panel.position=Vector2(8,66) if narrow else Vector2((size.x-width)*0.5,54);panel.size=Vector2(width,height)
    title.position=Vector2(14,10);title.size=Vector2(width-125,30)
    var close:=panel.get_node("CloseButton") as Button;close.position=Vector2(width-94,7);close.size=Vector2(84,46)
    summary.position=Vector2(14,44);summary.size=Vector2(width-28,24)
    scroll.position=Vector2(12,72);scroll.size=Vector2(width-24,height-82);content.custom_minimum_size.x=width-24
