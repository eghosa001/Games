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
    "3d": {
        "patterns": [
            "scripts/*3d*.gd", "scripts/rich_world_scenery.gd",
            "scenes/*3D*.tscn", "scenes/*3d*.tscn",
        ],
        "tests": {
            "tests/test_property_3d_presenter.gd",
            "tests/test_restora_3d_live_visibility.gd",
            "tests/test_restora_3d_scene_integration.gd",
            "tests/test_restora_3d_visual_state.gd",
            "tests/test_restora_district_3d.gd",
            "tests/test_restora_world_3d_controller.gd",
            "tests/test_v98_performance.gd",
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

    for name, cfg in GROUPS.items():
        if any(any(matches(path, pat) for pat in cfg["patterns"]) for path in changed):
            groups.append(name)
            tests.update(cfg["tests"])

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
