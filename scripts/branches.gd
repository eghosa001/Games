extends RefCounted
class_name RenewBranches

# Each regional branch is a real operating business: staff, inventory,
# local sourcing, pricing, quality and daily profit. The branch layer sits
# above the existing expansion properties and gives regions a reason to matter.
var branches: Variant = [
    {"name":"Old Market Flagship","region":0,"industry":"Consumer Goods","owned":true,"level":1,"employees":3,"stock":12,"price":115,"quality":50,"cashflow":0},
    {"name":"Industrial Works","region":1,"industry":"Building Materials","owned":false,"level":1,"employees":0,"stock":0,"price":145,"quality":50,"cashflow":0},
    {"name":"Port Distribution Hub","region":2,"industry":"Consumer Goods","owned":false,"level":1,"employees":0,"stock":0,"price":120,"quality":50,"cashflow":0},
    {"name":"Plains Food Plant","region":3,"industry":"Food Processing","owned":false,"level":1,"employees":0,"stock":0,"price":105,"quality":50,"cashflow":0},
    {"name":"Northern Retail Center","region":4,"industry":"Consumer Goods","owned":false,"level":1,"employees":0,"stock":0,"price":130,"quality":50,"cashflow":0},
    {"name":"Basin Materials Yard","region":5,"industry":"Building Materials","owned":false,"level":1,"employees":0,"stock":0,"price":150,"quality":50,"cashflow":0}
]
var selected: Variant = 0

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
    b["owned"]=true; b["employees"]=3; b["stock"]=8
    return {"ok":true,"cost":cost,"message":"%s is now part of your operating empire."%b["name"]}

func hire(index:int,cash:int)->Dictionary:
    var b=branches[index]
    if not bool(b["owned"]): return {"ok":false,"message":"Launch the branch first."}
    var cost:=1100+int(b["employees"])*220
    if cash<cost: return {"ok":false,"message":"Branch hiring requires $%s."%_money(cost)}
    b["employees"]+=1
    return {"ok":true,"cost":cost,"message":"Staff increased to %d."%b["employees"]}

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
    for b in branches:
        if not bool(b["owned"]): continue
        active+=1
        var region_index:=int(b["region"])
        var r=region_system.regions[region_index]
        var market:=float(r["demand"])*float(region_system.market_levels[region_index])
        if b["industry"]==r["industry"]: market*=1.15
        if b["industry"]=="Food Processing" and r["special"]=="Food supply abundance": market*=1.12
        var capacity:=max(1,int(b["employees"])*3+int(b["level"])*2)
        var price_factor:=clamp(1.25-(float(b["price"])/150.0),0.35,1.15)
        var pressure:=min(0.35,float(r["competition"])*0.08*int(region_system.rival_presence[region_index]))
        var demand:=max(1,int(round(capacity*market*price_factor*(1.0-pressure)*(0.85+float(b["quality"])/300.0))))
        var units:=min(int(b["stock"]),demand)
        var revenue: int = units*int(b["price"])
        var wages:=int(b["employees"])*190
        var overhead:=450+int(b["level"])*120
        var profit: int = revenue-wages-overhead
        b["stock"]-=units; b["cashflow"]=profit
        total+=profit; sales+=revenue
    return {"profit":total,"businesses":active,"sales":sales}

func _money(value:int)->String:
    return str(value)
