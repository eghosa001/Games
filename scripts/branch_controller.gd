extends Node2D

const Branches = preload("res://scripts/branches.gd")
var parent
var branches=Branches.new()
var last_day:=0
var message:=""
var workforce_bound:=false

func _ready()->void:
    parent=get_parent()
    last_day=parent.day
    queue_redraw()

func _process(_delta:float)->void:
    if parent==null: return
    if not workforce_bound:
        var employee_controller=_employee_controller()
        if employee_controller!=null and bool(employee_controller.get("initialized")):
            _bind_existing_workforce()
            workforce_bound=true
    if parent.day!=last_day:
        var region_controller=parent.get_node_or_null("RegionController")
        if region_controller!=null:
            var result=branches.operate_day(region_controller.regions)
            parent.cash+=int(result["profit"])
            if int(result["businesses"])>0:
                parent._log("BRANCHES: %d regional businesses generated $%s contribution."%[result["businesses"],_money(int(result["profit"]))])
        last_day=parent.day
    queue_redraw()

func _input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo or not event.ctrl_pressed: return
    match event.keycode:
        KEY_F6: select_branch(branches.selected+1)
        KEY_F7: launch_selected()
        KEY_F8: stock_selected()
        KEY_F10: hire_selected()
        KEY_F11: upgrade_selected()
        KEY_F12: price_selected()

func select_branch(index:int)->void:
    if branches.branches.is_empty(): return
    var result=branches.select((index%branches.branches.size()+branches.branches.size())%branches.branches.size())
    message=result["message"]

func launch_selected()->void:
    var b=branches.current()
    var region_controller=parent.get_node_or_null("RegionController")
    if region_controller==null: return
    var region=int(b["region"])
    if region<0 or region>=region_controller.regions.player_presence.size() or region_controller.regions.player_presence[region]<=0:
        message="Establish a regional presence before opening this branch."
        return
    var result=branches.launch(branches.selected,parent.cash)
    message=result["message"]
    if not result["ok"]: return
    var cost:=int(result["cost"])
    var employee_controller=_employee_controller()
    if employee_controller==null or not bool(employee_controller.get("initialized")):
        branches.branches[branches.selected]["owned"]=false
        message="Employee system is not ready; branch launch cancelled."
        return
    parent.cash-=cost
    var created:=0
    for _i in range(3):
        var hire_result=employee_controller.hire_for_assignment("Worker","branch","branch_%d" % branches.selected)
        if bool(hire_result.get("ok",false)): created+=1
    branches.set_staffing_projection(branches.selected,created)
    parent.reputation+=4
    parent._log("BRANCH OPENED: %s (-$%s, %d staff assigned)."%[b["name"],_money(cost),created])
    message="%s opened with %d persistent employees."%[b["name"],created]

func stock_selected()->void:
    var b=branches.current()
    if not bool(b["owned"]): message="Launch the branch first."; return
    var region_controller=parent.get_node_or_null("RegionController")
    if region_controller==null: return
    var amount:=min(10,parent.finished_goods)
    if amount<=0: message="Produce core goods before stocking a branch."; return
    var origin:=0
    var destination:=int(b["region"])
    if destination<0 or destination>=region_controller.regions.regions.size():
        message="Branch region is invalid."
        return
    var cost:=int(round(region_controller.regions.logistics_cost(amount*45.0,origin,destination)))
    if parent.cash<cost: message="Shipment requires $%s freight."%_money(cost); return
    parent.cash-=cost; parent.finished_goods-=amount
    branches.stock(branches.selected,amount)
    parent._log("BRANCH SUPPLY: %d goods delivered to %s for $%s."%[amount,b["name"],_money(cost)])
    message="Branch stocked with %d goods."%amount

func hire_selected()->void:
    var b=branches.current()
    if not bool(b["owned"]): message="Launch the branch first."; return
    var employee_controller=_employee_controller()
    if employee_controller==null or not bool(employee_controller.get("initialized")):
        message="Employee system is not ready."; return
    var branch_id:="branch_%d" % branches.selected
    var current_staff:=employee_controller.assigned_count("branch",branch_id)
    var cost:=1100+current_staff*220
    if parent.cash<cost:
        message="Branch hiring requires $%s."%_money(cost)
        return
    var result=employee_controller.hire_for_assignment("Worker","branch",branch_id)
    if not bool(result.get("ok",false)):
        message=str(result.get("message","Hiring failed."))
        return
    parent.cash-=cost
    branches.set_staffing_projection(branches.selected,employee_controller.assigned_count("branch",branch_id))
    parent.reputation+=1
    message="%s hired and assigned to %s. Staff: %d."%[str(result["employee"]["name"]),b["name"],employee_controller.assigned_count("branch",branch_id)]
    parent._log("BRANCH HIRE: %s assigned to %s (-$%s)."%[str(result["employee"]["name"]),b["name"],_money(cost)])

func upgrade_selected()->void:
    var result=branches.upgrade(branches.selected,parent.cash)
    message=result["message"]
    if result["ok"]:
        parent.cash-=int(result["cost"]); parent.reputation+=2

func price_selected()->void:
    var result=branches.change_price(branches.selected,10)
    message=result["message"]

func _employee_controller():
    if parent==null: return null
    return parent.get_node_or_null("EmployeeController")

func _bind_existing_workforce()->void:
    var employee_controller=_employee_controller()
    if employee_controller==null: return
    # Migration bridge: employees created by older saves used renew_goods.
    # Bind those people to the existing flagship once, without creating duplicates.
    var flagship_id:="branch_0"
    if not bool(branches.branches[0]["owned"]): return
    for employee in employee_controller.employees.active_employees():
        if str(employee.get("assignment_type",""))=="renew_goods":
            employee_controller.assign(str(employee["id"]),"branch",flagship_id)
    branches.set_staffing_projection(0,employee_controller.assigned_count("branch",flagship_id))

func _money(value:int)->String:
    return str(value)

func _draw()->void:
    if parent==null: return
    draw_rect(Rect2(25,510,800,180),Color("111b23"),true)
    draw_string(ThemeDB.fallback_font,Vector2(45,538),"REGIONAL BRANCHES",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("7891a5"))
    var b=branches.current()
    var staff:=int(b["employees"])
    var employee_controller=_employee_controller()
    if employee_controller!=null and bool(b["owned"]):
        staff=employee_controller.assigned_count("branch","branch_%d" % branches.selected)
        branches.set_staffing_projection(branches.selected,staff)
    draw_string(ThemeDB.fallback_font,Vector2(45,565),"CTRL+F6 select | %s | %s"%[b["name"],b["industry"]],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(45,590),"Status: %s | Staff %d | Stock %d | Level %d"%["OPEN" if b["owned"] else "CLOSED",staff,b["stock"],b["level"]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,613),"Price $%d | Quality %d | Last P&L $%s"%[b["price"],b["quality"],_money(int(b["cashflow"]))],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f2d27a"))
    draw_string(ThemeDB.fallback_font,Vector2(45,637),"CTRL+F7 launch | CTRL+F8 stock | CTRL+F10 hire | CTRL+F11 upgrade | CTRL+F12 price +" ,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font,Vector2(45,663),message,HORIZONTAL_ALIGNMENT_LEFT,750,12,Color("b7d7ff"))
