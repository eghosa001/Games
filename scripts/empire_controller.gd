extends Node2D

var selected: Variant = 0
var selected_resource: Variant = 0
var parent: Node
var last_processed_day: Variant = 1
var strategic_news: Array[String] = []

func _ready() -> void:
    parent = get_parent()
    if parent != null: last_processed_day = parent.day
    queue_redraw()

func _process(_delta: float) -> void:
    # Strategic rival simulation is advanced by main.gd as part of the atomic
    # end-of-day transaction. Keeping this controller presentation-only avoids
    # running the same strategic tick twice on fast/mobile sessions.
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo: return
    match event.keycode:
        KEY_7: select_business(0)
        KEY_8: select_business(1)
        KEY_9: select_business(2)
        KEY_4: select_resource(0)
        KEY_5: select_resource(1)
        KEY_6: select_resource(2)
        KEY_Z: produce_selected()
        KEY_Y: sell_selected()
        KEY_G: hire_selected()
        KEY_COMMA: price_selected(-10)
        KEY_PERIOD: price_selected(10)
        KEY_0: toggle_selected()
        KEY_W: harvest_selected_resource()
        KEY_D: dispatch_internal_supply()
        KEY_F: buy_selected_resource_site()
        KEY_BRACKETLEFT: upgrade_selected_resource_site()
        KEY_BRACKETRIGHT: management_upgrade()
        KEY_TAB: district_cycle()
        KEY_BACKSPACE: upgrade_transport()
    queue_redraw()

func select_business(index:int)->void:
    if parent==null or index<0 or index>=parent.expansion.properties.size(): return
    selected=index; parent.selected_expansion=index
    var p=parent.expansion.properties[index]
    parent.message="Managing %s — %s."%[p["name"],p["industry"]]; parent._log("BUSINESS SELECTED: %s."%p["name"])
func select_resource(index:int)->void:
    if parent==null or index<0 or index>=parent.expansion.resource_sites.size(): return
    selected_resource=index; var site=parent.expansion.resource_sites[index]
    parent.message="Resource site selected: %s (%s)."%[site["name"],site["resource"]]
func produce_selected()->void:
    var result=parent.expansion.produce(selected); parent.message=result["message"]
    if result["ok"]: parent.reputation+=1; parent._log(result["message"])
func sell_selected()->void:
    var result=parent.expansion.sell(selected); parent.message=result["message"]
    if result["ok"]: parent.cash+=int(result["profit"]); parent.total_profit+=int(result["profit"]); parent.last_profit=int(result["profit"]); parent.last_sales=int(result["revenue"]); parent._log("%s Net $%s."%[result["message"],parent._money(int(result["profit"]))])
func hire_selected()->void:
    var result=parent.expansion.hire(selected,parent.cash)
    if result["ok"]: parent.cash-=int(result["cost"]); parent.reputation+=1
    parent.message=result["message"]
func price_selected(delta:int)->void:
    var result=parent.expansion.change_price(selected,delta); parent.message=result["message"]
func toggle_selected()->void:
    var result=parent.expansion.toggle_active(selected); parent.message=result["message"]
func harvest_selected_resource()->void:
    var result=parent.expansion.harvest_resource(selected_resource); parent.message=result["message"]
    if result["ok"]: parent.reputation+=1; parent._log("RESOURCE: "+result["message"])
func buy_selected_resource_site()->void:
    var result=parent.expansion.buy_resource_site(selected_resource,parent.cash)
    if result["ok"]: parent.cash-=int(result["cost"]); parent.reputation+=4
    parent.message=result["message"]
func upgrade_selected_resource_site()->void:
    var result=parent.expansion.upgrade_resource_site(selected_resource,parent.cash)
    if result["ok"]: parent.cash-=int(result["cost"]); parent.reputation+=2
    parent.message=result["message"]
func dispatch_internal_supply()->void:
    if selected<0 or selected>=parent.expansion.properties.size(): parent.message="No business selected."; return
    var p=parent.expansion.properties[selected]; var moved_total:=0; var messages:Array[String]=[]
    for resource in p["inputs"]:
        var need:=int(p["input_need"].get(resource,0)); var current:=int(p["inputs"].get(resource,0)); var amount:=max(0,need*2-current)
        if amount<=0: continue
        var result=parent.expansion.supply_business(selected,resource,amount)
        if result["ok"]: moved_total+=int(result["moved"]); messages.append("%d %s"%[result["moved"],resource])
    if p["inputs"].has("goods"):
        var goods_result=parent.expansion.transfer_core_goods(selected,20,parent.finished_goods)
        if goods_result["ok"]: parent.finished_goods-=int(goods_result["moved"]); moved_total+=int(goods_result["moved"]); messages.append("%d finished goods"%goods_result["moved"])
    parent.message="Internal logistics moved "+", ".join(messages)+"." if moved_total>0 else "No internal supply was available."
func management_upgrade()->void:
    var result=parent.expansion.management_upgrade(parent.cash)
    if result["ok"]: parent.cash-=int(result["cost"]); parent.reputation+=3
    parent.message=result["message"]
func district_cycle()->void:
    if parent==null: return
    var next: int = (parent.districts.selected+1)%parent.districts.districts.size()
    parent.select_district(next)
func upgrade_transport()->void:
    parent.upgrade_transport()

func _draw()->void:
    if parent==null or not is_instance_valid(parent): return
    draw_rect(Rect2(855,425,385,245),Color("18242d"),true)
    if selected_resource < 0 or selected_resource >= parent.expansion.resource_sites.size(): return
    var site=parent.expansion.resource_sites[selected_resource]
    draw_string(ThemeDB.fallback_font,Vector2(872,449),"RESOURCE / LOGISTICS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7891a5"))
    draw_string(ThemeDB.fallback_font,Vector2(872,475),"%s • %s"%[site["name"],site["resource"]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(872,497),"%s | LVL %d | STOCK %d"%["OWNED" if site["owned"] else "AVAILABLE",site["level"],site["stock"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font,Vector2(872,519),"OUTPUT %d | RISK %d%%"%[site["output"],site["risk"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(872,541),"[4] Materials [5] Food [6] Fuel",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(872,561),"[W] Generate [F] Acquire [[]] Upgrade",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(872,581),"[D] Supply business   [TAB] Change district",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(872,601),"[BACKSPACE] Upgrade transport",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(872,623),"Fleet L%d • Capacity %d"%[parent.transport_level,parent.transport_capacity],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ee6a8"))
    var d=parent.districts.current()
    var pressure=parent.rivals.district_pressure(parent.districts.selected)
    var supply_pressure=parent.rivals.supplier_pressure(parent.districts.selected)
    draw_string(ThemeDB.fallback_font,Vector2(872,644),"District: %s | Rival pressure %.0f%% | Supply pressure %d"%[d["name"],pressure*100.0,supply_pressure],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f2d27a"))
    if selected>=0 and selected<parent.expansion.properties.size() and parent.expansion.properties[selected]["owned"]:
        var p=parent.expansion.properties[selected]
        draw_rect(Rect2(855,92,385,320),Color("202e38"),true)
        draw_string(ThemeDB.fallback_font,Vector2(872,119),"ACTIVE BUSINESS MANAGEMENT",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7891a5"))
        draw_string(ThemeDB.fallback_font,Vector2(872,147),p["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
        draw_string(ThemeDB.fallback_font,Vector2(872,172),"%s • %s • LEVEL %d"%[p["type"],p["industry"],p["level"]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7d7ff"))
        draw_string(ThemeDB.fallback_font,Vector2(872,198),"STATUS %s STAFF %d"%["OPEN" if p["active"] else "PAUSED",p["employees"]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8ee6a8"))
        draw_string(ThemeDB.fallback_font,Vector2(872,221),"STOCK %d PRICE $%d QUALITY %d"%[p["stock"],p["price"],p["quality"]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
        var input_text:=""
        for resource in p["inputs"]: input_text+="%s:%d/%d "%[resource,int(p["inputs"][resource]),int(p["input_need"].get(resource,0))]
        draw_string(ThemeDB.fallback_font,Vector2(872,243),"INPUTS "+input_text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("d5dee6"))
        draw_string(ThemeDB.fallback_font,Vector2(872,267),"[Z] Produce [Y] Sell [G] Hire",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0d8"))
        draw_string(ThemeDB.fallback_font,Vector2(872,289),"[,] Price -10 [.] Price +10 [0] Pause",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0d8"))
        draw_string(ThemeDB.fallback_font,Vector2(872,311),"[D] Supply   [Q] Upgrade business",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ee6a8"))
        draw_string(ThemeDB.fallback_font,Vector2(872,333),"[7] Retail [8] Factory [9] Warehouse",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0d8"))
        draw_string(ThemeDB.fallback_font,Vector2(872,355),"HQ level %d | Management overhead $%d"%[parent.expansion.management_level,parent.expansion.management_overhead],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0d8"))

    draw_string(ThemeDB.fallback_font,Vector2(872,385),"Rival: %s | Presence %d | Relationship %d"%[parent.rivals.rivals[parent.selected_rival]["name"],parent.rivals.rivals[parent.selected_rival]["presence"],parent.rivals.rivals[parent.selected_rival]["relationship"]],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffad8f"))
    draw_string(ThemeDB.fallback_font,Vector2(872,402),"1-3 select rival | L negotiate | C alliance | X acquire asset",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c6d0d8"))
