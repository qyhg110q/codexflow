# Context Window Usage

## Status

Completed.

## Goal

Polish the dashboard pill context ring so it fits the current Flutter visual system, then replace token-count estimation with a real context window usage value from the Go Agent API.

## Scope

- Flutter session pill context usage indicator visuals.
- Go Agent data model, runtime transform, HTTP API surface, and Flutter client model consumption for real context window usage.
- Validation through targeted formatting/tests and `build_android_apk.ps1`.

## Progress

- 2026-05-11: Started task and confirmed repository routing plus active surfaces.
- 2026-05-11: Adjusted the Flutter session detail app bar context ring from a dark block to a light, bordered indicator using existing palette tones.
- 2026-05-11: Found real Codex usage in transcript `event_msg` records with payload type `token_count`; implemented a Go parser and API model that exposes latest `last_token_usage` against `model_context_window`.
- 2026-05-11: Committed visual polish and real context window usage separately, then completed Android APK validation.

## Surprises & Discoveries

- Existing worktree contains unrelated local runtime artifacts and generated Flutter platform files. These are excluded from this task's commits.

## Decision Log

- Keep changes scoped to the existing dashboard/session data flow unless the current Codex app-server protocol requires a new endpoint.
- Use `last_token_usage.total_tokens / model_context_window` for the ring percentage, because `total_token_usage` is cumulative billing-style usage across calls while `last_token_usage` reflects the latest context window request.

## Validation

- `go test ./internal/runtime` passed.
- `flutter analyze` passed.
- `go test ./...` passed.
- `flutter test` passed.
- `.\build_android_apk.ps1` passed and produced `flutter/codexflow/build/app/outputs/flutter-apk/app-release.apk`.

## Outcomes & Retrospective

- The app bar context ring now matches the light CodexFlow UI palette.
- Context window usage now comes from Codex transcript `token_count` records instead of client-side token estimation.
- The Go Agent exposes usage in session summaries/details and through `GET /api/v1/sessions/:id/context-window`.
