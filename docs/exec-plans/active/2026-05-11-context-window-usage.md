# Context Window Usage

## Status

In progress.

## Goal

Polish the dashboard pill context ring so it fits the current Flutter visual system, then replace token-count estimation with a real context window usage value from the Go Agent API.

## Scope

- Flutter session pill context usage indicator visuals.
- Go Agent data model, runtime transform, HTTP API surface, and Flutter client model consumption for real context window usage.
- Validation through targeted formatting/tests and `build_android_apk.ps1`.

## Progress

- 2026-05-11: Started task and confirmed repository routing plus active surfaces.
- 2026-05-11: Adjusted the Flutter session detail app bar context ring from a dark block to a light, bordered indicator using existing palette tones.

## Surprises & Discoveries

- Existing worktree contains unrelated local runtime artifacts and generated Flutter platform files. These are excluded from this task's commits.

## Decision Log

- Keep changes scoped to the existing dashboard/session data flow unless the current Codex app-server protocol requires a new endpoint.

## Validation

- Pending.

## Outcomes & Retrospective

- Pending.
