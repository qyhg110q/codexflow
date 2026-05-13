# CodexFlow Plans

## Active Index

- Current active ExecPlans:
  - None.
- Most recently completed:
  - `docs/exec-plans/completed/2026-05-13-session-home-lazy-load.md`
  - `docs/exec-plans/completed/2026-05-13-agent-markdown-contrast.md`
  - `docs/exec-plans/completed/2026-05-13-session-home-project-picker.md`
  - `docs/exec-plans/completed/2026-05-12-session-text-selection.md`
  - `docs/exec-plans/completed/2026-05-12-inline-session-approvals.md`
  - `docs/exec-plans/completed/2026-05-12-agent-endpoint-settings.md`
  - `docs/exec-plans/completed/2026-05-11-context-window-usage.md`
  - `docs/exec-plans/completed/2026-05-05-android-mobile-ui-convergence.md`

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
  - None.

## Recent Completed Plans

- `docs/exec-plans/completed/2026-05-13-session-home-lazy-load.md`
  - Goal: limited expanded session home groups to 5 initial rows with a `展开显示` control that adds up to 20 more rows per tap.
  - Primary surfaces: Flutter `DashboardScreen`.
  - Validation: `flutter analyze` and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-13-agent-markdown-contrast.md`
  - Goal: raised markdown reply contrast in Flutter agent chat bubbles so inline code and other styled text remain readable on light backgrounds.
  - Primary surfaces: shared `MarkdownBodyBlock`, Flutter palette tokens, Android APK packaging validation.
  - Validation: `flutter analyze`, `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-13-session-home-project-picker.md`
  - Goal: added recent workspace / new project / no-project session start options and simplified session row activity display.
  - Primary surfaces: Flutter `DashboardScreen`, Go Agent session start validation.
  - Validation: `go test ./internal/httpapi`, `flutter analyze`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-12-session-text-selection.md`
  - Goal: enabled native text selection for Flutter session detail chat content.
  - Primary surfaces: Flutter `SessionDetailScreen` chat bubbles and shared `MarkdownBodyBlock`.
  - Validation: `flutter analyze`, `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-12-inline-session-approvals.md`
  - Goal: moved Flutter approval handling into the session detail composer and removed the standalone Approval tab.
  - Primary surfaces: Flutter `HomeShell`, `DashboardScreen`, `SessionDetailScreen`, approval card widgets.
  - Validation: `flutter analyze`, `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-12-agent-endpoint-settings.md`
  - Goal: replaced the single Flutter Agent address field with named on-device Agent endpoints.
  - Primary surfaces: Flutter `AppModel`, `SettingsScreen`, app refresh cadence.
  - Validation: `flutter analyze`, `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-11-context-window-usage.md`
  - Goal: polished the session detail context usage ring and replaced client-side estimation with real Codex transcript token-count usage.
  - Primary surfaces: Go Agent context usage parser/API, Flutter session model, session detail app bar indicator.
  - Validation: `go test ./...`, `flutter analyze`, `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-05-android-mobile-ui-convergence.md`
  - Goal: converged Flutter Android / mobile UI and user flows toward `docs/ui_references/android_mobile/android_mobile_prototype.html`
  - Primary surfaces: `DashboardScreen`, `SessionDetailScreen`, `ApprovalScreen`, `SettingsScreen`, shared theme / common widgets
  - Validation: `dart format`, `flutter analyze`, and `flutter build apk --debug`

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
