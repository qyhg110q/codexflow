# CodexFlow Plans

## Active Index

- Current active ExecPlans:
  - None.
- Most recently completed:
  - `docs/exec-plans/completed/2026-05-15-agent-markdown-latex-rendering.md`
  - `docs/exec-plans/completed/2026-05-14-direct-exe-startup.md`
  - `docs/exec-plans/completed/2026-05-14-mobile-model-reasoning-runtime-wiring.md`
  - `docs/exec-plans/completed/2026-05-14-settings-github-release-update-check.md`
  - `docs/exec-plans/completed/2026-05-14-session-detail-interrupt-button.md`
  - `docs/exec-plans/completed/2026-05-13-release-packaging-and-deployment-docs.md`
  - `docs/exec-plans/completed/2026-05-13-session-detail-scroll-follow.md`
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

- `docs/exec-plans/completed/2026-05-14-direct-exe-startup.md`
  - Goal: removed the PowerShell-based startup flow and made the Windows host bundle boot directly from `codexflow-agent.exe`, with bundled web served by the same Go process.
  - Primary surfaces: Go config/runtime startup, HTTP static hosting, release packaging, Windows host docs.
  - Validation: `go test ./internal/config ./internal/httpapi`, `go build -o codexflow-agent.exe ./cmd/codexflow-agent`, `.\build_release_assets.ps1 -SkipApk -SkipWeb -SkipAgentBuild`, and packaged bundle smoke checks for `/healthz` and `/`.
- `docs/exec-plans/completed/2026-05-15-agent-markdown-latex-rendering.md`
  - Goal: rendered math formulas in Flutter agent replies so LaTeX markdown no longer appears as raw source.
  - Primary surfaces: shared `MarkdownBodyBlock`, Flutter markdown dependencies, formula rendering regression coverage.
  - Validation: `flutter analyze --no-pub`, targeted `flutter test --no-pub`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-14-settings-github-release-update-check.md`
  - Goal: added a Settings-based GitHub Release update check for the Android app, showed release notes for new versions, and opened the APK download in the system browser.
  - Primary surfaces: Flutter Settings UI, AppModel update state, GitHub Release client, native Android bridge, APK build script.
  - Validation: `flutter analyze --no-pub`, targeted `flutter test --no-pub`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-14-mobile-model-reasoning-runtime-wiring.md`
  - Goal: made Flutter mobile model and reasoning settings affect real Codex session / turn runtime parameters instead of staying local-only UI preferences.
  - Primary surfaces: Flutter `AppModel` and `ApiClient`, Go HTTP API session / turn start handlers, runtime Codex thread / turn start parameter wiring.
  - Validation: `go test ./...`; Flutter formatting passed; targeted Flutter test was blocked locally by Windows Developer Mode symlink requirements.
- `docs/exec-plans/completed/2026-05-13-release-packaging-and-deployment-docs.md`
  - Goal: prepared GitHub Release assets, added reproducible packaging/publishing scripts, and rewrote deployment guidance for end-user LAN and Tailscale usage.
  - Primary surfaces: release packaging scripts, Windows release launcher templates, README deployment/release docs.
  - Validation: `go test ./internal/httpapi`, `.\build_android_apk.ps1`, `.\build_release_assets.ps1`, and packaged bundle smoke checks for local/Tailscale `/healthz`.
- `docs/exec-plans/completed/2026-05-14-session-detail-interrupt-button.md`
  - Goal: made the session detail composer switch between stop and send while a turn is running, with stop waiting on the interrupt API just like send waits on the send API.
  - Primary surfaces: Flutter `SessionDetailScreen`, `AppModel` interrupt flow, and interrupt waiting regression coverage.
  - Validation: `flutter analyze`, targeted `flutter test`, and `.\build_android_apk.ps1`.
- `docs/exec-plans/completed/2026-05-13-session-detail-scroll-follow.md`
  - Goal: changed Flutter session detail chat so automatic bottom following pauses when the user scrolls up to inspect history and resumes when they return to the bottom.
  - Primary surfaces: Flutter `SessionDetailScreen`.
  - Validation: `flutter analyze` and `.\build_android_apk.ps1`.
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
