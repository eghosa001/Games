extends RefCounted
class_name RenewDaily

## Generates short, contextual newspaper stories from real game state.
## It intentionally consumes dictionaries so it can be wired into the existing
## prototype without coupling the newspaper to every simulation module.

func generate(day: int, state: Dictionary) -> Array[Dictionary]:
    var stories: Array[Dictionary] = []
    var cash := int(state.get("cash", 0))
    var profit := int(state.get("last_profit", 0))
    var reputation := int(state.get("reputation", 0))
    var sales := int(state.get("last_sales", 0))
    var employees := int(state.get("employees", 0))
    var finished_goods := int(state.get("finished_goods", 0))
    var business_open := bool(state.get("business_open", false))
    var stage := String(state.get("stage", "Neglected"))
    var total_profit := int(state.get("total_profit", 0))

    if day <= 2:
        stories.append(_story("YOUR COMPANY", "A new company begins", "Your first restoration is the beginning of a much larger business story."))
    if stage == "Operational":
        stories.append(_story("RESTORATION", "A neglected property has a second life", "The restored property is now productive capital."))
    if business_open and sales > 0:
        stories.append(_story("YOUR COMPANY", "RENEW Goods made today's market", "Sales reached $%s and the business is building momentum." % _money(sales)))
    if profit > 0:
        stories.append(_story("FINANCE", "Another profitable day", "The company closed the day $%s ahead." % _money(profit)))
    elif profit < 0:
        stories.append(_story("FINANCE", "Pressure on margins", "Today's operation lost $%s. Management must respond." % _money(abs(profit))))
    if employees > 3:
        stories.append(_story("PEOPLE", "%d people now work for RENEW", "Your workforce is becoming an important source of capability and loyalty." % employees))
    if finished_goods >= 20:
        stories.append(_story("OPERATIONS", "Inventory is building", "%d finished goods are waiting for customers." % finished_goods))
    if reputation >= 10:
        stories.append(_story("REPUTATION", "The market is taking notice", "RENEW's reputation has reached %d." % reputation))
    if total_profit >= 10000:
        stories.append(_story("MILESTONE", "The first $10,000 profit milestone", "Your company has generated $%s in cumulative operating profit." % _money(total_profit)))
    if cash < 5000 and business_open:
        stories.append(_story("WARNING", "Cash reserves are tightening", "Only $%s remains available. Protect working capital." % _money(cash)))
    if stories.is_empty():
        stories.append(_story("MARKET", "Business continues", "Day %d brought another step in the company's development." % day))
    return stories

func _story(category: String, headline: String, body: String) -> Dictionary:
    return {"category":category, "headline":headline, "body":body}

func _money(value: int) -> String:
    var negative := value < 0
    var n := abs(value)
    var text := str(n)
    var result := ""
    while text.length() > 3:
        result = "," + text.substr(text.length() - 3, 3) + result
        text = text.substr(0, text.length() - 3)
    result = text + result
    return ("-$" if negative else "$") + result
