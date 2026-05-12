# Agent Endpoint Settings

## Status

Completed on 2026-05-12.

## Goal

Update the Flutter Android settings flow so the Agent address section manages named Agent endpoints instead of a single URL field. Users can add, switch, edit, and delete endpoints, with endpoint data persisted on-device through the existing Flutter preferences layer.

## Scope

- Flutter `AppModel` endpoint persistence and selection behavior.
- Flutter `SettingsScreen` endpoint list UI and add/edit/delete flows.
- Connection retry behavior through the app refresh loop.
- Validation by Flutter tests/analyze and Android APK build script.

## Progress

- Replaced the single Agent address text field and the `保存并刷新` / `重新连接` buttons with a named endpoint list and icon `+` add action.
- Added local endpoint persistence through `SharedPreferences`, including migration from the legacy `codexflow.baseURL` value.
- Added add, switch, edit, and delete flows. Adding auto-selects the new endpoint and triggers a dashboard refresh. Switching endpoints saves the selection and triggers a dashboard refresh.
- Changed the app refresh timer to 10 seconds so offline endpoints retry on the requested cadence.

## Surprises & Discoveries

- The current worktree already had unrelated local changes, including generated Flutter plugin files, `session_detail_screen.dart`, `internal/httpapi/server.go`, and local runtime artifacts. This task preserved those and stages only the files touched for endpoint settings.

## Decision Log

- Keep the backend runtime Agent options (`Codex`, `Claude Code`) separate from the client-side Agent address endpoints. The endpoint list controls `baseUrlString`, while `selectedStartAgentId` continues to control which runtime creates sessions.
- Keep at least one endpoint available. Deleting the final endpoint resets the list to the local default so the app always has a valid connection target.

## Validation

- `dart format flutter/codexflow/lib/state/app_model.dart flutter/codexflow/lib/screens/settings_screen.dart flutter/codexflow/lib/main.dart`
- `flutter analyze`
- `flutter test`
- `.\build_android_apk.ps1`, which produced `flutter/codexflow/build/app/outputs/flutter-apk/app-release.apk`

## Outcomes & Retrospective

The settings page now treats Agent addresses as concrete named endpoints stored on the Android device. The implementation keeps API client behavior stable by continuing to route all calls through `baseUrlString`, while endpoint management lives in the Flutter state layer.
