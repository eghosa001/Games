extends Node

signal monetization_status_changed
signal reward_started(reward_id: String)
signal reward_granted(reward_id: String, details: Dictionary)
signal reward_failed(reward_id: String, reason: String)
signal premium_changed(active: bool)

const CONFIG_PATH := "res://config/monetization.json"
const LOCAL_STATE_PATH := "user://monetization_state.cfg"
const MAX_REWARDED_GRANTS_PER_REAL_DAY := 2
const SPONSOR_GRANT_AMOUNT := 500

var config: Dictionary = {}
var provider: Node = null
var premium_active := false
var premium_verified_until_unix := 0.0
var premium_source := "none"
var _cached_premium_claim := false
var _premium_revalidation_pending := false

func _ready() -> void:
    _load_config()
    _load_local_state()
    process_mode = Node.PROCESS_MODE_ALWAYS

func _state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _load_config() -> void:
    config = {}
    if not FileAccess.file_exists(CONFIG_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
    if parsed is Dictionary:
        config = parsed

func reload_config() -> void:
    _load_config()
    monetization_status_changed.emit()

func is_enabled() -> bool:
    return bool(config.get("enabled", false))

func rewarded_ads_enabled() -> bool:
    return is_enabled() and bool(config.get("rewarded_ads_enabled", false)) and not str(config.get("rewarded_ad_unit_id", "")).is_empty()

func subscriptions_enabled() -> bool:
    return is_enabled() and bool(config.get("subscriptions_enabled", false)) and not str(config.get("premium_subscription_product_id", "")).is_empty()

func privacy_policy_url() -> String:
    return str(config.get("privacy_policy_url", ""))

func register_provider(service: Node) -> void:
    provider = service
    monetization_status_changed.emit()
    # Always ask the billing provider for the authoritative entitlement when
    # subscriptions are enabled. This restores purchases after reinstall or on
    # a new device even when there is no local cache to hint at prior Premium.
    if subscriptions_enabled() and provider_ready_for_billing() and not _premium_revalidation_pending:
        _premium_revalidation_pending = true
        provider.restore_purchases(Callable(self, "_on_restore_result"))

func unregister_provider(service: Node) -> void:
    if provider == service:
        provider = null
        _premium_revalidation_pending = false
        monetization_status_changed.emit()

func provider_ready_for_rewarded() -> bool:
    return provider != null and provider.has_method("show_rewarded_ad")

func provider_ready_for_billing() -> bool:
    return provider != null and provider.has_method("purchase_subscription") and provider.has_method("restore_purchases")

func available_rewarded_offers() -> Array[Dictionary]:
    return [
        {
            "id": "sponsor_grant",
            "title": "Sponsor Grant",
            "description": "Optional sponsored presentation for a modest $%d business grant." % SPONSOR_GRANT_AMOUNT,
            "limit_per_real_day": 1
        },
        {
            "id": "market_research",
            "title": "Market Research",
            "description": "Optional sponsored presentation that unlocks today's expanded demand briefing.",
            "limit_per_real_day": 1
        }
    ]

func can_show_rewarded_offer(reward_id: String) -> Dictionary:
    if not rewarded_ads_enabled():
        return {"ok": false, "reason": "Rewarded ads are disabled."}
    if not provider_ready_for_rewarded():
        return {"ok": false, "reason": "Rewarded ad provider is unavailable."}
    if premium_active:
        return {"ok": false, "reason": "Premium is active. Sponsored rewards are optional and currently hidden."}
    if not _valid_reward_id(reward_id):
        return {"ok": false, "reason": "Unknown rewarded offer."}
    var today := _date_key()
    var total_today := _read_counter(today, "total")
    if total_today >= MAX_REWARDED_GRANTS_PER_REAL_DAY:
        return {"ok": false, "reason": "Today's sponsored reward limit has been reached."}
    var offer_count := _read_counter(today, reward_id)
    if offer_count >= 1:
        return {"ok": false, "reason": "This sponsored reward has already been claimed today."}
    return {"ok": true, "reason": ""}

func request_rewarded_offer(reward_id: String) -> Dictionary:
    var eligibility := can_show_rewarded_offer(reward_id)
    if not bool(eligibility.get("ok", false)):
        reward_failed.emit(reward_id, str(eligibility.get("reason", "Reward unavailable.")))
        return eligibility
    reward_started.emit(reward_id)
    provider.show_rewarded_ad(reward_id, Callable(self, "_on_rewarded_ad_completed"))
    return {"ok": true, "pending": true}

func _on_rewarded_ad_completed(reward_id: String, earned: bool) -> void:
    if not earned:
        reward_failed.emit(reward_id, "Sponsored presentation was not completed.")
        return
    var eligibility := can_show_rewarded_offer(reward_id)
    if not bool(eligibility.get("ok", false)):
        reward_failed.emit(reward_id, str(eligibility.get("reason", "Reward unavailable.")))
        return
    var details := _grant_reward(reward_id)
    if bool(details.get("ok", false)):
        _increment_reward_counters(reward_id)
        reward_granted.emit(reward_id, details)
    else:
        reward_failed.emit(reward_id, str(details.get("message", "Reward could not be granted.")))

func _grant_reward(reward_id: String) -> Dictionary:
    if reward_id == "sponsor_grant":
        var finance = _finance()
        if finance == null:
            return {"ok": false, "message": "Finance service unavailable."}
        var result: Dictionary = finance.receive(SPONSOR_GRANT_AMOUNT, "optional sponsor reward")
        if bool(result.get("ok", false)):
            var state = _state()
            if state != null:
                state.set_value("economy", "cash", int(finance.cash))
            return {"ok": true, "cash": SPONSOR_GRANT_AMOUNT, "message": "Sponsor grant received."}
        return result
    if reward_id == "market_research":
        _write_local_value("rewards", "market_research_date", _date_key())
        return {"ok": true, "message": "Expanded market research unlocked for today."}
    return {"ok": false, "message": "Unknown rewarded offer."}

func has_market_research_today() -> bool:
    return str(_read_local_value("rewards", "market_research_date", "")) == _date_key()

func purchase_premium() -> Dictionary:
    if not subscriptions_enabled():
        return {"ok": false, "message": "Premium subscriptions are disabled."}
    if not provider_ready_for_billing():
        return {"ok": false, "message": "Google Play billing provider is unavailable."}
    var product_id := str(config.get("premium_subscription_product_id", ""))
    provider.purchase_subscription(product_id, Callable(self, "_on_purchase_result"))
    return {"ok": true, "pending": true}

func restore_premium() -> Dictionary:
    if not subscriptions_enabled():
        return {"ok": false, "message": "Premium subscriptions are disabled."}
    if not provider_ready_for_billing():
        return {"ok": false, "message": "Google Play billing provider is unavailable."}
    provider.restore_purchases(Callable(self, "_on_restore_result"))
    return {"ok": true, "pending": true}

func _on_purchase_result(result: Dictionary) -> void:
    _apply_verified_purchase_result(result)

func _on_restore_result(result: Dictionary) -> void:
    _premium_revalidation_pending = false
    _cached_premium_claim = false
    _apply_verified_purchase_result(result)

func _apply_verified_purchase_result(result: Dictionary) -> void:
    var verified := bool(result.get("verified", false))
    var product_id := str(result.get("product_id", ""))
    var expected := str(config.get("premium_subscription_product_id", ""))
    if not verified or product_id.is_empty() or product_id != expected:
        set_verified_premium_entitlement(false, "verification_failed", 0.0)
        return
    set_verified_premium_entitlement(true, str(result.get("source", "google_play")), float(result.get("expiry_unix", 0.0)))

func set_verified_premium_entitlement(active: bool, source: String, expiry_unix: float) -> void:
    _cached_premium_claim = false
    premium_active = active
    premium_source = source
    premium_verified_until_unix = expiry_unix
    if premium_active and premium_verified_until_unix > 0.0 and Time.get_unix_time_from_system() >= premium_verified_until_unix:
        premium_active = false
    _save_local_state()
    premium_changed.emit(premium_active)
    monetization_status_changed.emit()

func is_premium() -> bool:
    if premium_active and premium_verified_until_unix > 0.0 and Time.get_unix_time_from_system() >= premium_verified_until_unix:
        premium_active = false
        _save_local_state()
    return premium_active

func should_show_forced_ads() -> bool:
    # RENEW deliberately has no forced ad path. Monetization stays opt-in.
    return false

func status() -> Dictionary:
    return {
        "enabled": is_enabled(),
        "rewarded_ads_enabled": rewarded_ads_enabled(),
        "subscriptions_enabled": subscriptions_enabled(),
        "provider_rewarded_ready": provider_ready_for_rewarded(),
        "provider_billing_ready": provider_ready_for_billing(),
        "premium": is_premium(),
        "premium_source": premium_source,
        "premium_verified_until_unix": premium_verified_until_unix,
        "forced_ads": should_show_forced_ads(),
        "privacy_policy_url": privacy_policy_url()
    }

func _valid_reward_id(reward_id: String) -> bool:
    return reward_id == "sponsor_grant" or reward_id == "market_research"

func _date_key() -> String:
    var date := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0))]

func _load_local_state() -> void:
    premium_active = false
    premium_source = "none"
    premium_verified_until_unix = 0.0
    _cached_premium_claim = false
    var file := ConfigFile.new()
    if file.load(LOCAL_STATE_PATH) != OK:
        return
    var cached_active := bool(file.get_value("premium", "active", false))
    var cached_expiry := float(file.get_value("premium", "verified_until_unix", 0.0))
    var unexpired := cached_expiry <= 0.0 or Time.get_unix_time_from_system() < cached_expiry
    # Local storage is editable and therefore cannot establish entitlement.
    # Keep only a hint that tells the billing provider to revalidate on startup.
    _cached_premium_claim = cached_active and unexpired

func _save_local_state() -> void:
    var file := ConfigFile.new()
    file.load(LOCAL_STATE_PATH)
    file.set_value("premium", "active", premium_active)
    file.set_value("premium", "source", premium_source)
    file.set_value("premium", "verified_until_unix", premium_verified_until_unix)
    file.save(LOCAL_STATE_PATH)

func _read_local_value(section: String, key: String, default_value):
    var file := ConfigFile.new()
    if file.load(LOCAL_STATE_PATH) != OK:
        return default_value
    return file.get_value(section, key, default_value)

func _write_local_value(section: String, key: String, value) -> void:
    var file := ConfigFile.new()
    file.load(LOCAL_STATE_PATH)
    file.set_value(section, key, value)
    file.save(LOCAL_STATE_PATH)

func _read_counter(day_key: String, reward_id: String) -> int:
    return int(_read_local_value("rewarded_" + day_key, reward_id, 0))

func _increment_reward_counters(reward_id: String) -> void:
    var day_key := _date_key()
    var file := ConfigFile.new()
    file.load(LOCAL_STATE_PATH)
    var section := "rewarded_" + day_key
    file.set_value(section, reward_id, int(file.get_value(section, reward_id, 0)) + 1)
    file.set_value(section, "total", int(file.get_value(section, "total", 0)) + 1)
    file.save(LOCAL_STATE_PATH)
