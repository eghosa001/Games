extends Node

# Shared infrastructure for domain systems. Domain systems mutate only their
# owning GameState bucket and communicate results back to the command layer.
#
# Finance is the canonical cash/debt ledger. Legacy domain buckets are kept as
# compatibility mirrors because the current UI and older gameplay systems read
# those values directly.

func game_state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func get_value(domain: String, key: String, default_value):
    var state = game_state()
    return default_value if state == null else state.get_value(domain, key, default_value)

func set_value(domain: String, key: String, value) -> void:
    var state = game_state()
    if state != null:
        state.set_value(domain, key, value)
    # Keep the legacy GameState mirrors and the canonical finance ledger aligned
    # whenever a domain command changes cash/debt. This prevents old command
    # paths from silently creating a second, divergent money ledger.
    var finance = _finance()
    if finance == null:
        return
    if domain == "economy" and key == "cash":
        finance.set("cash", int(value))
    elif domain == "finance" and key == "debt":
        finance.set("debt", int(value))
    elif domain == "finance" and key == "loan_payment":
        finance.set("loan_payment", int(value))

func log_message(text: String) -> void:
    var logs = get_value("company", "log_lines", [])
    if not logs is Array:
        logs = []
    logs = logs.duplicate(true)
    logs.append(text)
    if logs.size() > 100:
        logs.pop_front()
    set_value("company", "log_lines", logs)

func message(text: String) -> void:
    set_value("company", "message", text)

func money(value: int) -> String:
    return "%d" % value
