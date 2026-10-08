#!/usr/bin/env python3
"""Select the smallest useful Godot test set for iterative RESTORA changes.

Policy:
- Iterative PR updates: run changed tests + tests mapped to changed code areas.
- Unknown code changes: run a compact architecture/release smoke set.
- Full suite is controlled by the workflow for main/final validation.
"""
from __future__ import annotations

import argparse
import fnmatch
import os
from pathlib import Path

SMOKE = {
    "tests/test_architecture_integrity.gd",
    "tests/test_runtime_dependency_resolution.gd",
    "tests/release/test_release_smoke.gd",
}

RESTORA_FLOW_FILES = {
    "scripts/restora_command_ui.gd",
    "scripts/restora_figma_flow_ui.gd",
}

BANKRUPTCY_FILES = {
    "scripts/bankruptcy_system.gd",
}

AUTOSAVE_NAV_FILES = {
    "scripts/autosave.gd",
}

SAVE_LOAD_DYNASTY_FILES = {
    "scripts/save_load_ui.gd",
}

NATIVE_ACCESSIBILITY_FILES = {
    "scripts/premium_ui_skin.gd",
    "scripts/theme_manager.gd",
}

AUDIO_FEEDBACK_FILES = {
    "scripts/audio_manager.gd",
}

SAVE_INTEGRITY_FILES = {
    "scripts/save_system.gd",
}

CONTRACT_UI_REFRESH_FILES = {
    "scripts/contracts_ui.gd",
}

IDENTITY_UI_REFRESH_FILES = {
    "scripts/empire_identity_ui.gd",
}

CORPORATE_UI_REFRESH_FILES = {
    "scripts/corporations_ui.gd",
}

DASHBOARD_UI_REFRESH_FILES = {
    "scripts/dashboard_ui.gd",
}

WORLD_INTELLIGENCE_REFRESH_FILES = {
    "scripts/world_intelligence_ui.gd",
}

PROGRESSION_UI_REFRESH_FILES = {
    "scripts/empire_progression_ui.gd",
}

ARCHIVE_LIVE_REFRESH_FILES = {
    "scripts/history_museum_ui.gd",
    "scripts/collection_ui.gd",
    "scripts/corporate_legacy_system.gd",
    "scripts/collection_system.gd",
}

EXECUTIVE_DESK_UI_FILES = {
    "scripts/management_policy_ui.gd",
}

SCREEN_MANAGER_CLOSE_FILES = {
    "scripts/ui_screen_manager.gd",
}

PORTFOLIO_UI_REFRESH_FILES = {
    "scripts/portfolio_ui.gd",
}

GROUPS = {
    "tutorial": {
        "patterns": [
            "scripts/tutorial.gd", "scripts/tutorial_overlay.gd",
            "scripts/game_state.gd", "scripts/restora_command_ui.gd",
        ],
        "tests": {
            "tests/test_tutorial_completion.gd",
            "tests/mobile_qa_test.gd",
            "tests/release/test_full_new_game_flow.gd",
        },
    },
    "ui": {
        "patterns": [
            "scripts/*_ui.gd", "scripts/ui_*.gd", "scripts/*theme*.gd",
            "scripts/premium_ui_skin.gd", "scripts/dashboard_*.gd",
            "Assets/Themes/**", "Assets/Art/**", "scenes/Main.tscn",
        ],
        "tests": {
            "tests/test_command_deck_ui.gd",
            "tests/test_figma_runtime_parity.gd",
            "tests/test_commercial_ux_gate.gd",
            "tests/test_responsive_ui_shell.gd",
            "tests/test_restora_hud_premium_layout.gd",
            "tests/test_ui_architecture.gd",
            "tests/test_ui_bottom_navigation.gd",
            "tests/test_ui_region_coordinator.gd",
            "tests/test_ui_scene_contract.gd",
            "tests/test_v1_presentation_assets.gd",
            "tests/test_v51_ux_parity.gd",
            "tests/test_v88_motions.gd",
            "tests/test_v95_containment.gd",
            "tests/test_v97_modal_focus.gd",
            "tests/test_v9x_panels.gd",
            "tests/test_resource_art_assets.gd",
            "tests/test_premium_art_direction.gd",
        },
    },
    "economy_finance": {
        "patterns": [
            "scripts/*econom*.gd", "scripts/*finance*.gd", "scripts/*bank*.gd",
            "scripts/*market*.gd", "scripts/*transaction*.gd",
        ],
        "tests": {
            "tests/test_economy_transactions.gd",
            "tests/test_finance_amortization.gd",
            "tests/test_finance_authority_paths.gd",
            "tests/test_finance_regressions.gd",
            "tests/test_market_director_transactions.gd",
            "tests/test_real_start_economy_flow.gd",
            "tests/test_real_time_economy_contract.gd",
            "tests/test_diplomacy_investment_finance.gd",
            "tests/test_diplomacy_research_finance.gd",
        },
    },
    "production": {
        "patterns": ["scripts/*production*.gd", "scripts/*equipment*.gd"],
        "tests": {
            "tests/test_production_system.gd",
            "tests/test_production_finance_authority.gd",
            "tests/test_production_transaction_boundary.gd",
            "tests/test_v1_industry_production.gd",
        },
    },
    "employees": {
        "patterns": ["scripts/*employee*.gd", "scripts/*culture*.gd"],
        "tests": {
            "tests/test_employee_system.gd",
            "tests/test_employee_dismissal_cascade.gd",
            "tests/test_employee_transaction_safety.gd",
            "tests/integration/test_employee_integration.gd",
            "tests/test_company_culture_system.gd",
            "tests/test_demand_culture_integration.gd",
        },
    },
    "supply": {
        "patterns": ["scripts/*supply*.gd", "scripts/*scarcity*.gd", "scripts/*resource*.gd"],
        "tests": {
            "tests/test_supply_chain_system.gd",
            "tests/test_supply_receipt_atomicity.gd",
            "tests/test_scarcity_system.gd",
        },
    },
    "property_restoration": {
        "patterns": ["scripts/*property*.gd", "scripts/*restoration*.gd"],
        "tests": {
            "tests/test_restoration_mechanics.gd",
            "tests/test_multi_property_restoration.gd",
            "tests/test_phase19_property_business.gd",
            "tests/test_v82_property_market.gd",
            "tests/test_v96_property_map.gd",
        },
    },
    "state_save": {
        "patterns": [
            "scripts/game_state.gd", "scripts/*save*.gd", "scripts/*persistence*.gd",
            "scripts/*migration*.gd", "scripts/service_persistence.gd",
        ],
        "tests": {
            "tests/test_game_state.gd",
            "tests/test_corporate_save_boundary.gd",
            "tests/test_service_persistence.gd",
            "tests/test_v33_migrations.gd",
            "tests/test_v72_save_repair.gd",
            "tests/test_v94_save_edges.gd",
            "tests/release/test_release_smoke.gd",
        },
    },
    "world_events": {
        "patterns": [
            "scripts/*liveops*.gd", "scripts/*event*.gd", "scripts/*news*.gd",
            "scripts/*season*.gd", "scripts/*opportunit*.gd",
        ],
        "tests": {
            "tests/test_news_system.gd",
            "tests/test_phase26_dynamic_events.gd",
            "tests/test_phase30_history_news.gd",
            "tests/test_v41_world_events.gd",
            "tests/test_v42_event_effects.gd",
            "tests/test_v43_seasonal_arc.gd",
            "tests/test_v44_verified_news.gd",
        },
    },
    "corporate_empire": {
        "patterns": [
            "scripts/*corporat*.gd", "scripts/*alliance*.gd", "scripts/*diplom*.gd",
            "scripts/*region*.gd", "scripts/*acquisition*.gd", "scripts/*ownership*.gd",
            "scripts/*headquarter*.gd", "scripts/*research*.gd", "scripts/*technology*.gd",
        ],
        "tests": {
            "tests/test_competitor_ai.gd",
            "tests/test_expansion_api.gd",
            "tests/test_headquarters_integration.gd",
            "tests/test_ownership_system.gd",
            "tests/test_research_capacity.gd",
            "tests/test_v15_acquisitions.gd",
            "tests/test_v15_alliances.gd",
            "tests/test_v15_ownership_finance.gd",
            "tests/test_v15_regions.gd",
            "tests/test_v23_diplomacy.gd",
            "tests/test_v24_joint_ventures.gd",
            "tests/test_v28_corporations.gd",
        },
    },
    "android_release": {
        "patterns": ["export_presets.cfg", "android/**", ".github/workflows/android*.yml"],
        "tests": {
            "tests/test_android_release_config.gd",
            "tests/release/test_release_smoke.gd",
            "tests/release/test_full_new_game_flow.gd",
        },
    },
}

EXCLUDED_HEAVY = {
    "tests/test_long_soak.gd",
    "tests/test_extreme_soak.gd",
    "tests/test_exhaustive_ui_matrix.gd",
    "tests/test_visual_ui_matrix.gd",
    "tests/test_quality_gate.gd",
    "tests/test_master_game_plan_coverage.gd",
    "tests/long_running/test_30_60_180_365_day_balance.gd",
}


def matches(path: str, pattern: str) -> bool:
    return fnmatch.fnmatch(path, pattern)


def existing(paths: set[str]) -> set[str]:
    return {p for p in paths if Path(p).is_file()}


def select(changed: list[str]) -> tuple[list[str], list[str]]:
    tests: set[str] = set()
    groups: list[str] = []

    # Directly changed tests always run, except intentionally exhaustive suites.
    for path in changed:
        if path.startswith("tests/") and path.endswith(".gd") and path not in EXCLUDED_HEAVY:
            tests.add(path)

    restora_flow_changed = any(path in RESTORA_FLOW_FILES for path in changed)
    other_ui_code_changed = any(
        path.startswith("scripts/")
        and path.endswith("_ui.gd")
        and path not in RESTORA_FLOW_FILES
        and path not in SAVE_LOAD_DYNASTY_FILES
        and path not in NATIVE_ACCESSIBILITY_FILES
        and path not in CONTRACT_UI_REFRESH_FILES
        and path not in IDENTITY_UI_REFRESH_FILES
        and path not in CORPORATE_UI_REFRESH_FILES
        and path not in DASHBOARD_UI_REFRESH_FILES
        and path not in WORLD_INTELLIGENCE_REFRESH_FILES
        and path not in PROGRESSION_UI_REFRESH_FILES
        and path not in ARCHIVE_LIVE_REFRESH_FILES
        and path not in EXECUTIVE_DESK_UI_FILES
        and path not in SCREEN_MANAGER_CLOSE_FILES
        and path not in PORTFOLIO_UI_REFRESH_FILES
        for path in changed
    )
    tutorial_code_changed = any(
        path in {"scripts/tutorial.gd", "scripts/tutorial_overlay.gd", "scripts/game_state.gd"}
        for path in changed
    )
    bankruptcy_changed = any(path in BANKRUPTCY_FILES for path in changed)
    other_economy_finance_changed = any(
        path not in BANKRUPTCY_FILES
        and any(matches(path, pat) for pat in GROUPS["economy_finance"]["patterns"])
        for path in changed
    )
    autosave_nav_changed = any(path in AUTOSAVE_NAV_FILES for path in changed)
    save_load_dynasty_changed = any(path in SAVE_LOAD_DYNASTY_FILES for path in changed)
    native_accessibility_changed = any(path in NATIVE_ACCESSIBILITY_FILES for path in changed)
    audio_feedback_changed = any(path in AUDIO_FEEDBACK_FILES for path in changed)
    save_integrity_changed = any(path in SAVE_INTEGRITY_FILES for path in changed)
    contract_ui_refresh_changed = any(path in CONTRACT_UI_REFRESH_FILES for path in changed)
    identity_ui_refresh_changed = any(path in IDENTITY_UI_REFRESH_FILES for path in changed)
    corporate_ui_refresh_changed = any(path in CORPORATE_UI_REFRESH_FILES for path in changed)
    dashboard_ui_refresh_changed = any(path in DASHBOARD_UI_REFRESH_FILES for path in changed)
    world_intelligence_refresh_changed = any(path in WORLD_INTELLIGENCE_REFRESH_FILES for path in changed)
    progression_ui_refresh_changed = any(path in PROGRESSION_UI_REFRESH_FILES for path in changed)
    archive_live_refresh_changed = any(path in ARCHIVE_LIVE_REFRESH_FILES for path in changed)
    other_corporate_empire_changed = any(
        path not in ARCHIVE_LIVE_REFRESH_FILES
        and any(matches(path, pat) for pat in GROUPS["corporate_empire"]["patterns"])
        for path in changed
    )
    executive_desk_ui_changed = any(path in EXECUTIVE_DESK_UI_FILES for path in changed)
    screen_manager_close_changed = any(path in SCREEN_MANAGER_CLOSE_FILES for path in changed)
    portfolio_ui_refresh_changed = any(path in PORTFOLIO_UI_REFRESH_FILES for path in changed)
    other_state_save_changed = any(
        path not in AUTOSAVE_NAV_FILES
        and path not in SAVE_LOAD_DYNASTY_FILES
        and path not in SAVE_INTEGRITY_FILES
        and any(matches(path, pat) for pat in GROUPS["state_save"]["patterns"])
        for path in changed
    )

    for name, cfg in GROUPS.items():
        # RESTORA's mobile/Figma command layer has a dedicated end-to-end flow
        # regression. Do not fan these two files out into generic UI/tutorial
        # suites unless those implementations also changed in the same task.
        if name == "ui" and restora_flow_changed and not other_ui_code_changed:
            continue
        if name == "ui" and save_load_dynasty_changed and not other_ui_code_changed:
            continue
        if name == "ui" and native_accessibility_changed and not other_ui_code_changed:
            continue
        if name == "ui" and contract_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and identity_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and corporate_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and dashboard_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and world_intelligence_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and progression_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and archive_live_refresh_changed and not other_ui_code_changed:
            continue
        if name == "ui" and executive_desk_ui_changed and not other_ui_code_changed:
            continue
        if name == "ui" and screen_manager_close_changed and not other_ui_code_changed:
            continue
        if name == "ui" and portfolio_ui_refresh_changed and not other_ui_code_changed:
            continue
        if name == "tutorial" and restora_flow_changed and not tutorial_code_changed:
            continue
        if name == "corporate_empire" and corporate_ui_refresh_changed:
            continue
        if name == "corporate_empire" and archive_live_refresh_changed and not other_corporate_empire_changed:
            continue
        if name == "economy_finance" and bankruptcy_changed and not other_economy_finance_changed:
            continue
        if name == "state_save" and autosave_nav_changed and not other_state_save_changed:
            continue
        if name == "state_save" and save_load_dynasty_changed and not other_state_save_changed:
            continue
        if name == "state_save" and save_integrity_changed and not other_state_save_changed:
            continue
        if any(any(matches(path, pat) for pat in cfg["patterns"]) for path in changed):
            groups.append(name)
            tests.update(cfg["tests"])

    if restora_flow_changed:
        groups.append("restora_flow")
        tests.add("tests/test_figma_flow_wiring.gd")

    # Stage-specific property artwork and constrained hero text belong to the
    # small RESTORA HUD geometry test, not an unrelated exhaustive UI matrix.
    if any(path in {"scripts/restora_figma_enhancer.gd", "scripts/restora_figma_flow_ui.gd"} for path in changed):
        groups.append("restora_art_layout")
        tests.add("tests/test_restora_hud_premium_layout.gd")

    if bankruptcy_changed:
        groups.append("bankruptcy")
        tests.add("tests/test_bankruptcy_system.gd")

    if autosave_nav_changed:
        groups.append("android_back_navigation")
        tests.add("tests/test_android_release_config.gd")

    if save_load_dynasty_changed:
        groups.append("save_load_dynasty")
        tests.add("tests/test_save_load_dynasty_ui.gd")

    if native_accessibility_changed:
        groups.append("native_accessibility")
        tests.add("tests/test_theme_settings.gd")

    if audio_feedback_changed:
        groups.append("audio_feedback")
        tests.add("tests/test_audio_feedback_throttle.gd")

    if save_integrity_changed:
        groups.append("save_integrity")
        tests.add("tests/test_v94_save_edges.gd")

    if contract_ui_refresh_changed:
        groups.append("contract_ui_refresh")
        tests.add("tests/test_contract_ui_refresh.gd")

    if identity_ui_refresh_changed:
        groups.append("identity_ui_refresh")
        tests.add("tests/test_identity_ui_refresh.gd")

    if corporate_ui_refresh_changed:
        groups.append("corporate_ui_refresh")
        tests.add("tests/test_corporations_refresh.gd")

    if dashboard_ui_refresh_changed:
        groups.append("dashboard_ui_refresh")
        tests.add("tests/test_dashboard_refresh.gd")

    if world_intelligence_refresh_changed:
        groups.append("world_intelligence_refresh")
        tests.add("tests/test_world_intelligence_refresh.gd")

    if progression_ui_refresh_changed:
        groups.append("progression_ui_refresh")
        tests.add("tests/test_empire_progression_refresh.gd")

    if archive_live_refresh_changed:
        groups.append("archive_live_refresh")
        tests.add("tests/test_archive_live_refresh.gd")

    if executive_desk_ui_changed:
        groups.append("executive_desk_ui")
        tests.add("tests/test_figma_flow_wiring.gd")

    if screen_manager_close_changed:
        groups.append("native_screen_close_sync")
        tests.add("tests/test_native_screen_close_sync.gd")

    if portfolio_ui_refresh_changed:
        groups.append("portfolio_ui_refresh")
        tests.add("tests/test_portfolio_refresh.gd")

    code_changed = any(
        p.endswith((".gd", ".tscn", ".tres", ".cfg", ".svg"))
        or p.startswith(("Assets/", "scenes/", "scripts/"))
        for p in changed
    )
    if code_changed:
        tests.update(SMOKE)

    # Workflow/docs-only edits do not need the game suite.
    if not tests and any(p.startswith(".github/") or p.startswith("ci/") for p in changed):
        tests.add("tests/test_test_quality_integrity.gd")
        groups.append("ci")

    tests.difference_update(EXCLUDED_HEAVY)
    return sorted(existing(tests)), groups


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--changed-file-list", help="Optional newline-delimited changed-file list")
    parser.add_argument("--output", help="Optional file to write selected test paths")
    args = parser.parse_args()

    files = [p.strip() for p in args.files if p.strip()]
    if args.changed_file_list:
        files.extend(p.strip() for p in Path(args.changed_file_list).read_text(encoding="utf-8").splitlines() if p.strip())
    selected, groups = select(files)

    print("Changed files:")
    for p in files:
        print(f"  - {p}")
    print("Matched groups:", ", ".join(groups) if groups else "none")
    print("Selected tests:")
    for p in selected:
        print(f"  - {p}")

    if args.output:
        Path(args.output).write_text("\n".join(selected) + ("\n" if selected else ""), encoding="utf-8")
    else:
        print("\n".join(selected))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
# World Intelligence final validation scope: content-sensitive cache invalidation.
# Archive live-refresh final validation scope: service signals, debounced visible refresh, hidden-screen inactivity, and focused CI.
