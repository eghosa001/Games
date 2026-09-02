extends RefCounted
class_name RenewSupplyContracts

# Negotiated access to rival-controlled commodities. Contracts are deliberately
# temporary: the player must keep relationships healthy or build ownership.
var active_rival := -1
var active_resource := ""
var days_remaining := 0
var discount := 0.0
var player_resource_rights := {"materials":0,"packaging":0,"fuel":0,"food":0}

func _normalize() -> void:
    days_remaining=max(0,days_remaining)
    discount=clamp(float(discount),0.0,0.35)
    for resource in ["materials","packaging","fuel","food"]:
        player_resource_rights[resource]=max(0,int(player_resource_rights.get(resource,0)))
    if days_remaining==0:
        active_rival=-1
        active_resource=""
        discount=0.0

func negotiate(rival_index:int, resource:String, parent)->Dictionary:
    _normalize()
    if rival_index<0 or rival_index>=parent.rivals.rivals.size(): return {"ok":false,"message":"Unknown supplier."}
    if resource not in player_resource_rights: return {"ok":false,"message":"Unknown resource."}
    if days_remaining>0: return {"ok":false,"message":"A supplier contract is already active."}
    var rival=parent.rivals.rivals[rival_index]
    var relationship=int(rival.get("relationship",0))
    var requirement:=20 if rival_index!=2 else 15
    if relationship<requirement:
        return {"ok":false,"message":"%s requires relationship %d before offering this contract."%[rival["name"],requirement]}
    var cost: int = 2500+max(0,25-relationship)*100
    if rival_index==2: cost+=1000
    if int(parent.cash)<cost: return {"ok":false,"message":"Contract signing requires $%d."%cost}
    parent.cash-=cost
    active_rival=rival_index
    active_resource=resource
    days_remaining=12
    discount=0.12 if rival_index==2 else 0.06
    rival["relationship"]=min(100,relationship+3)
    rival["supplier_pressure"]=max(0,int(rival.get("supplier_pressure",0))-1)
    return {"ok":true,"cost":cost,"message":"12-day %s supply contract signed with %s at %.0f%% preferred pricing."%[resource,rival["name"],discount*100.0]}

func secure_resource(resource:String, parent)->Dictionary:
    _normalize()
    if resource not in player_resource_rights: return {"ok":false,"message":"Unknown resource."}
    if int(player_resource_rights[resource])>=2: return {"ok":false,"message":"You already control this resource market."}
    var cost:=18000+int(player_resource_rights[resource])*14000+int(parent.reputation)*100
    if int(parent.cash)<cost: return {"ok":false,"message":"Permanent resource rights require $%d."%cost}
    if int(parent.reputation)<30: return {"ok":false,"message":"Build at least 30 reputation before buying permanent resource rights."}
    parent.cash-=cost
    player_resource_rights[resource]=int(player_resource_rights[resource])+1
    return {"ok":true,"cost":cost,"message":"Permanent %s supply rights secured. Rival pressure on this resource is reduced."%resource}

func resource_discount(resource:String)->float:
    _normalize()
    var permanent=float(player_resource_rights.get(resource,0))*0.10
    var contract=discount if resource==active_resource and days_remaining>0 else 0.0
    return clamp(permanent+contract,0.0,0.35)

func pressure_reduction(resource:String)->int:
    _normalize()
    return int(player_resource_rights.get(resource,0))*2 + (1 if resource==active_resource and days_remaining>0 else 0)

func daily_update()->String:
    if days_remaining<=0: return ""
    days_remaining-=1
    if days_remaining==0:
        var name:=active_resource
        active_rival=-1
        active_resource=""
        discount=0.0
        return "SUPPLY CONTRACT EXPIRED: %s access must be renegotiated."%name
    return ""

func snapshot()->Dictionary:
    _normalize()
    return {"active_rival":active_rival,"active_resource":active_resource,"days_remaining":days_remaining,"discount":discount,"player_resource_rights":player_resource_rights.duplicate(true)}

func load_snapshot(state:Dictionary)->void:
    if state is Dictionary:
        active_rival=int(state.get("active_rival",-1))
        active_resource=str(state.get("active_resource",""))
        days_remaining=int(state.get("days_remaining",0))
        discount=float(state.get("discount",0.0))
        player_resource_rights=state.get("player_resource_rights",player_resource_rights).duplicate(true)
    _normalize()
