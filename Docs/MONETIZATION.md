# RENEW monetization

RENEW uses an opt-in monetization model. Core restoration, production, selling, expansion, competition and progression must remain playable without ads or purchases.

## Runtime service

`/root/RenewMonetizationSystem` owns monetization policy. The checked-in configuration is `config/monetization.json` and is intentionally disabled with empty production IDs.

The service guarantees:

- no forced/interstitial ad path (`should_show_forced_ads()` always returns false),
- rewarded ads require explicit configuration and a registered provider,
- no reward is granted until the provider callback reports the rewarded presentation was completed,
- at most two rewarded grants per real calendar day,
- each offer can be claimed at most once per real calendar day,
- the Sponsor Grant is capped at $500,
- Premium is never trusted from a local purchase flag alone; a provider must report a verified entitlement,
- expired cached entitlements are deactivated locally,
- the game stays fully playable when monetization is unavailable.

## Rewarded offers

1. **Sponsor Grant** — one optional rewarded presentation for a modest $500 grant, at most once per real calendar day.
2. **Market Research** — one optional rewarded presentation for the expanded market briefing for that real calendar day.

Do not increase these rewards until retention/economy data proves they do not distort the business simulation.

## Provider contract

The Android SDK adapter must register itself with:

```gdscript
RenewMonetizationSystem.register_provider(self)
```

A provider that supports rewarded ads must expose:

```gdscript
func show_rewarded_ad(reward_id: String, callback: Callable) -> void
```

The callback must be invoked as `callback.call(reward_id, earned)` only after the SDK has independently confirmed whether the reward was earned.

A provider that supports Premium must expose:

```gdscript
func purchase_subscription(product_id: String, callback: Callable) -> void
func restore_purchases(callback: Callable) -> void
```

The callback result must be a dictionary containing a verified product ID and entitlement state. RENEW expects the provider or trusted backend to validate the purchase before returning `verified=true`. Do not unlock Premium merely because a client-side purchase dialog returned success.

## Production configuration

Before enabling monetization, fill `config/monetization.json` with the real values created in AdMob/Google Play Console and set the relevant booleans to true. Do not invent IDs.

Required configuration:

- AdMob Android application ID
- rewarded ad unit ID
- Google Play Premium subscription product ID
- public privacy-policy URL
- support email

## Consent and privacy

When the AdMob SDK is integrated, use Google's User Messaging Platform (UMP) consent flow. Consent information must be refreshed on app launch and a privacy-options entry point must be available when required. Do not request an ad until the provider determines that doing so complies with the current consent state.

Update the Play Console Data safety form after the exact advertising/billing SDK versions are chosen, because SDK data collection is part of the app's disclosure obligations.

## Premium policy

Premium is a supporter/convenience entitlement. It must not gate the core game loop. Suitable Premium benefits include cosmetic themes, richer historical analytics, additional cosmetic headquarters customization, and cloud/save conveniences if those services are added later. Avoid stronger production multipliers, exclusive profitable properties, or economic advantages that turn the simulation into pay-to-win.
