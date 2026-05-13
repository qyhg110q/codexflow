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

## Surprises & Discoveries

- The dashboard already groups sessions by cwd, but empty cwd was treated as an unknown workspace rather than a first-level conversation bucket.
- The Go Agent already sends `cwd: nil` to Codex when empty, but the HTTP layer rejected empty cwd before the runtime call.

## Decision Log

- Keep the change focused on Flutter dashboard and HTTP validation, avoiding unrelated generated platform files currently modified in the working tree.

## Validation

- Pending.

## Outcomes & Retrospective

- Pending.
