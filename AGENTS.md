# Mandatory Fast-Path Directive

Before implementation, investigation, QA, CI, deployment, or repository maintenance, read and follow:

`.agents/skills/fast-production/SKILL.md`

**Default to one direct implementation path and zero subagents.** Add a subagent only when the skill's subagent gate is fully satisfied and parallelism is expected to reduce wall-clock time. Do not weaken or bypass `Fast Policy Guard`.

# Repository Agent Instructions

For implementation, bug fixing, QA, deployment, production hardening, UI/UX, content/data integration, and CI work, read and follow:

`.agents/skills/fast-production/SKILL.md`

Use the shortest safe execution path:
- inspect only the relevant surface;
- use subagents only when genuinely parallel work exists and a real runner is available;
- otherwise parallelize safe tool calls;
- run only risk-relevant focused tests during implementation;
- keep routine validation change-scoped; run broad/full gates only when the owner explicitly requests them;
- avoid repeated CI polling and unnecessary commits/deployments;
- stop code churn once an external configuration blocker is conclusively identified.

Repository-specific business, security, architecture, data, and release rules remain authoritative.
