extends RefCounted
class_name RenewBranches

# Regional branches are operating units. Workforce truth lives in
# EmployeeController/GameState; the legacy employee field is only a UI/save
# compatibility projection and is refreshed from actual branch assignments.
var branches := [
    {"name":"Old Market Flagship","region":0,"industry":"Consumer Goods","owned":true,"level":1,"employees":3,"stock":12,"price":115,"quality":50,"cashflow":0},
    {"name":"Industrial Works","region":1,"industry":"Building Materials","owned":false,"level":1,"employees":0,"stock":0,"price":145,"quality":50,"cashflow":0},
    {"name":"Port Distribution Hub","region":2,"industry":"Consumer Goods","owned":false,"level":1,"employees":0,"stock":0,"price":120,"quality":50,"cashflow":0},
    {"name":"Plains Food Plant","region":3,"industry":"Food Processing","owned":false,"level":1,"employees":0,"stock":0,"price":105,"quality":50,"cashflow":0},
    {"name":"Northern Retail Center","region":4,"industry":"Consumer Goods","owned":false,"level":1,"employees":0,"stock":0,"price":130,"quality":50,"cashflow":0},
    {"name":"Basin Materials Yard","region":5,"industry":"Building Materials","owned":false,"level":1,"employees":0,"stock":0,"price":150,"quality":50,"cashflow":0}
]
var selected := 0

func _normalize() -> void:
    while branches.size() < 6:
        branches.append({"name":"New Branch","region":branches.size(),"industry":"Consumer Goods","owned":false,"level":1,"employees":0,"stock":0,"price":120,"quality":50,"cashflow":0})
    selected=clamp(selected,0,branches.size()-1)
    for b in branches:
        b["employees"]=max(0,int(b.get("employees",0)))
        b["stock"]=max(0,int(b.get("stock",0)))
        b["level"]=max(1,int(b.get("level",1)))

func current()->Dictionary:
    _normalize()
    return branches[selected]

func select(index:int)->Dictionary:
    _normalize()
    if index<0 or index>=branches.size(): return {"ok":false,"message":"Invalid branch."}
    selected=index
    return {"ok":true,"message":"%s selected."%branches[index]["name"]}

func launch(index:int,cash:int)->Dictionary:
    _normalize()
    var b=branches[index]
    if bool(b["owned"]): return {"ok":false,"message":"This branch is already owned."}
    var cost:=12000+int(b["region"])*5500
    if cash<cost: return {"ok":false,"message":"Branch launch requires $%s."%_money(cost)}
    b["owned"]=true
    b["stock"]=8
    # Staffing is deliberately not created here. BranchController performs the
    # launch transaction and creates real employee records through EmployeeController.
    b["employees"]=0
    return {"ok":true,"cost":cost,"message":"%s is now part of your operating empire."%b["name"]}

# Legacy API retained for compatibility. New UI/controller code should use
# EmployeeController.hire_for_assignment() so every hire becomes a persistent person.
func hire(index:int,cash:int)->Dictionary:
    var b=branches[index]
    if not bool(b["owned"]): return {"ok":false,"message":"Launch the branch first."}
    var cost:=1100+int(b["employees"])*220
    if cash<cost: return {"ok":false,"message":"Branch hiring requires $%s."%_money(cost)}
    b["employees"]+=1
    return {"ok":true,"cost":cost,"message":"Staff increased to %d."%b["employees"]}

func set_staffing_projection(index:int,count:int)->void:
    if index<0 or index>=branches.size(): return
    branches[index]["employees"]=max(0,count)

func stock(index:int,amount:int)->Dictionary:
    var b=branches[index]
    if not bool(b["owned"]): return {"ok":false,"message":"Launch the branch first."}
    if amount<=0: return {"ok":false,"message":"Shipment must contain goods."}
    b["stock"]+=amount
    return {"ok":true,"message":"%d units delivered."%amount}

func change_price(index:int,delta:int)->Dictionary:
    var b=branches[index]
    if not bool(b["owned"]): return {"ok":false,"message":"Launch the branch first."}
    b["price"]=clamp(int(b["price"])+delta,70,220)
    return {"ok":true,"message":"Branch price is now $%d."%b["price"]}

func upgrade(index:int,cash:int)->Dictionary:
    var b=branches[index]
    if not bool(b["owned"]): return {"ok":false,"message":"Launch the branch first."}
    var cost:=7500*int(b["level"])
    if cash<cost: return {"ok":false,"message":"Branch upgrade requires $%s."%_money(cost)}
    b["level"]+=1; b["quality"]=min(100,int(b["quality"])+8)
    return {"ok":true,"cost":cost,"message":"%s upgraded to level %d."%[b["name"],b["level"]]}

func operate_day(region_system)->Dictionary:
    _normalize()
    var total:=0
    var active:=0
    var sales:=0
    var operations:=_employee_metrics()
    var employee_controller:=_employee_controller()
    for index in range(branches.size()):
        var b=branches[index]
        if not bool(b["owned"]): continue
        active+=1
        var region_index:=int(b["region"])
        if region_index<0 or region_index>=region_system.regions.size(): continue
        # Refresh the visible staffing projection from actual persistent assignments.
        if employee_controller!=null:
            b["employees"]=employee_controller.assigned_count("branch", "branch_%d" % index)
        var r=region_system.regions[region_index]
        var market:=float(r["demand"])*float(region_system.market_levels[region_index])
        if b["industry"]==r["industry"]: market*=1.15
        if b["industry"]=="Food Processing" and r["special"]=="Food supply abundance": market*=1.12
        var branch_staff:=max(0,int(b["employees"]))
        if branch_staff<=0:
            b["cashflow"]=-450-int(b["level"])*120
            total+=int(b["cashflow"])
            continue
        var staffing_share:=clampf(float(branch_staff)/float(max(1,active*3)),0.35,1.35)
        var sales_eff:=float(operations["sales_efficiency"])
        var logistics_eff:=float(operations["logistics_efficiency"])
        var management_eff:=float(operations["management_efficiency"])
        var capacity:=max(1,int(float(branch_staff*3+int(b["level"])*2)*staffing_share))
        var price_factor:=clamp(1.25-(float(b["price"])/150.0),0.35,1.15)
        var pressure:=min(0.35,float(r["competition"])*0.08*int(region_system.rival_presence[region_index]))
        var conversion:=clampf(0.72+sales_eff*0.18,0.70,1.20)
        var supply_protection:=clampf(0.85+logistics_eff*0.10,0.80,1.10)
        var demand:=max(1,int(round(capacity*market*price_factor*(1.0-pressure)*conversion*(0.85+float(b["quality"])/300.0))))
        var units:=min(int(b["stock"]),int(round(float(demand)*supply_protection)))
        var revenue: int = units*int(b["price"])
        # Payroll is charged once by EmployeeController at company level. Keep
        # branch P&L fully loaded with wage expense, but only return the cash
        # contribution before payroll so parent cash is not double-charged.
        var wages:=0
        if employee_controller!=null:
            for employee_id in employee_controller.assigned_employee_ids("branch", "branch_%d" % index):
                var record=employee_controller.employees.employees.get(employee_id,{})
                wages+=int(record.get("salary",180))
        else:
            wages=int(b["employees"])*190
        var overhead_base:=450+int(b["level"])*120
        var overhead:=max(100,int(round(float(overhead_base)*(1.12-management_eff*0.10))))
        var profit: int = revenue-wages-overhead
        var cash_contribution: int = revenue-overhead
        b["stock"]-=units; b["cashflow"]=profit
        total+=cash_contribution; sales+=revenue
    return {"profit":total,"businesses":active,"sales":sales,"employee_metrics":operations}

func _employee_controller():
    var tree=Engine.get_main_loop()
    if tree==null: return null
    var root=tree.get_root()
    if root==null: return null
    return root.get_node_or_null("Main/EmployeeController")

func _employee_metrics()->Dictionary:
    var tree=Engine.get_main_loop()
    if tree==null: return {"sales_efficiency":1.0,"logistics_efficiency":1.0,"management_efficiency":1.0}
    var root=tree.get_root()
    if root==null: return {"sales_efficiency":1.0,"logistics_efficiency":1.0,"management_efficiency":1.0}
    var state=root.get_node_or_null("RenewGameState")
    if state==null: return {"sales_efficiency":1.0,"logistics_efficiency":1.0,"management_efficiency":1.0}
    return {
        "sales_efficiency":clampf(float(state.get_value(["analytics","employee_sales_efficiency"],1.0)),0.25,2.5),
        "logistics_efficiency":clampf(float(state.get_value(["analytics","employee_logistics_efficiency"],1.0)),0.25,2.5),
        "management_efficiency":clampf(float(state.get_value(["analytics","employee_management_efficiency"],1.0)),0.25,2.5)
    }

func _money(value:int)->String:
    return str(value)
