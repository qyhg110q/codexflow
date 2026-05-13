# Session Detail Scroll Follow

## Status

Completed on 2026-05-13.

## Goal

Keep the session detail chat pinned to the latest message only while the user is already at the bottom. When the user scrolls up to inspect history, pause automatic following until they return to the bottom or tap the latest-message control.

## Scope

- Flutter session detail chat scroll state.
- Android APK build validation.

## Progress

- Replaced direction-specific `UserScrollNotification` handling with general `ScrollNotification` handling.
- Added a single bottom-follow state updater for `_stickToBottom`, `_isAtBottom`, and `_showJumpToLatest`.
- Preserved automatic bottom following when the user is near the bottom or explicitly jumps to latest.

## Surprises & Discoveries

- The old logic depended on `ScrollDirection.forward`, which is brittle for a chat list because the direction naming maps to scroll offset movement rather than the user's intent to read older messages.

## Decision Log

- Treat any user-originated scroll away from the bottom as an instruction to pause bottom following.
- Restore bottom following when the scroll position returns near the bottom.

## Validation

- `.\.tooling\flutter\bin\flutter.bat analyze flutter\codexflow`
- `.\build_android_apk.ps1`

## Outcomes & Retrospective

The chat page now has the intended behavior: live updates keep following while the user stays at the bottom, and history reading remains stable once the user scrolls away from the bottom.
