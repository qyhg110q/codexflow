# CodexFlow Plans

## Active Index

- Current active ExecPlans:
  - `docs/exec-plans/active/2026-05-05-android-mobile-ui-convergence.md`
- Most recently completed:
  - None recorded in `docs/exec-plans/completed/` yet.

## Purpose

`PLANS.md` is the plan-layer entry point.
It should stay short and route complex work into `docs/exec-plans/`.

Complex tasks should be written in `docs/exec-plans/active/`, then moved to `docs/exec-plans/completed/` when finished.
Long-lived structural issues that are not being handled immediately should go in `docs/exec-plans/tech-debt/`.

## When To Create Or Update An ExecPlan

Create or update an ExecPlan when any of these are true:

- The task spans multiple areas, such as Go Agent, Flutter UI, iOS UI, docs, packaging, and validation
- The task may continue across several sessions
- The task involves protocol, lifecycle, storage, relay, pairing, approval policy, or security decisions
- The task has meaningful validation evidence that future agents should see
- The task may leave follow-up risks, decisions, or technical debt

## Current Active Plans

- Current active ExecPlan:
  - `docs/exec-plans/active/2026-05-05-android-mobile-ui-convergence.md`
    - Goal: converge Flutter Android / mobile UI and user flows toward `docs/ui_references/android_mobile/android_mobile_prototype.html`
    - Primary surfaces: `DashboardScreen`, `SessionDetailScreen`, `ApprovalScreen`, `SettingsScreen`, shared theme / common widgets

## ExecPlan Minimum Requirements

Each ExecPlan should include these sections or equivalent content:

- `Status`
- `Goal`
- `Scope`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Validation`
- `Outcomes & Retrospective`

Update rules:

- `Progress`: update at each meaningful stopping point
- `Decision Log`: update when a key tradeoff or architecture decision is made
- `Surprises & Discoveries`: update when new facts change assumptions
- `Validation`: record commands, screenshots, acceptance checks, or manual validation
- `Outcomes & Retrospective`: complete when the plan lands or is closed

## Validation Rule

Prefer the smallest validation that proves the changed surface:

- Go Agent changes: targeted `go test` or package-level tests
- HTTP API changes: handler tests or a local API smoke check
- Flutter changes: `flutter test`, build, or targeted manual UI validation
- iOS changes: Xcode build, simulator smoke, or explicit manual validation
- UI reference changes: screenshot, visual check, or acceptance checklist
- Documentation-only changes: link / path review and `git status` sanity check
