# Documentation Principles

## Goal

CodexFlow documentation should reduce context load for humans and agents.
The structure should make the next useful file obvious without forcing a full repository read.

## Root Files

- `AGENTS.md` is the project entry and routing file.
- `ARCHITECTURE.md` is the stable system overview.
- `PLANS.md` is the plan routing and active work index.
- `README.md` is the user-facing project overview and quick start.

Keep root files compact.
Move durable details into `docs/`.

## Docs Directory

`docs/` is the knowledge base.
Each directory should have one primary responsibility:

- architecture and lifecycle notes
- product direction
- UI references
- execution plans
- standards and conventions

Avoid mixing temporary task progress into stable architecture or product documents.

## ExecPlans

Use `docs/exec-plans/` for multi-step work that spans several areas or sessions.
Plans should record progress, decisions, validation, and outcomes.

After a plan is completed, move only long-lived conclusions back into stable docs.

## UI References

Use `docs/ui_references/` for HTML prototypes, screenshots, and visual reference material.
Reference files should be named by surface and role, such as `android_mobile_prototype.html`.

UI reference docs should explain how to preview the asset and how it maps to implementation code.

