# Session Home Project Picker

## Status

In progress.

## Goal

Adjust the Flutter session home so new Codex sessions can start with a recent workspace, a manually added workspace, or no workspace, while simplifying session cards to only show live activity.

## Scope

- Flutter session dashboard composer and session grouping.
- Flutter session row presentation.
- Go Agent session start validation for optional Codex cwd.
- Android APK build validation.

## Progress

- Created plan after locating the dashboard, API client, AppModel, and HTTP start-session validation paths.
- Confirmed native Codex remote thread parameters can omit cwd.
- Commit `f59350f` added the project picker, no-workspace start support, and the top-level `对话` group for empty cwd sessions.
- Removed the session row agent mark and replaced lifecycle/status pills with a running-only spinner.

## Surprises & Discoveries

- The dashboard already groups sessions by cwd, but empty cwd was treated as an unknown workspace rather than a first-level conversation bucket.
- The Go Agent already sends `cwd: nil` to Codex when empty, but the HTTP layer rejected empty cwd before the runtime call.

## Decision Log

- Keep the change focused on Flutter dashboard and HTTP validation, avoiding unrelated generated platform files currently modified in the working tree.
- Treat card activity as `lastTurnStatus == inProgress`; idle sessions render no right-side status.

## Validation

- `go test ./internal/httpapi`
- `flutter analyze`

## Outcomes & Retrospective

- Pending.
