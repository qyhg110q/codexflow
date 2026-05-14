# Status

Completed.

# Goal

Add a Settings entry point that checks the latest GitHub Release for CodexFlow Android, compares it with the installed app version, shows release notes when a newer version exists, and opens the APK download link in the system browser.

# Scope

- Add Flutter-side release check state and GitHub Release client logic.
- Surface current version, latest release, and update status in the Settings screen.
- Show release notes and provide an APK download action that launches the browser.
- Rebuild Flutter dependencies and validate with analyze, test, and APK packaging.

Out of scope:

- In-app APK download management or install orchestration.
- Delta patching, background downloads, or silent install flows.
- iOS / desktop auto-update support.

# Progress

- 2026-05-14: Read workspace and project routing files, then inspected Flutter Settings UI, release packaging scripts, and the existing GitHub Release publishing flow.
- 2026-05-14: Confirmed release assets already publish the Android APK into the same GitHub Release, so the app only needs a latest-release lookup plus external browser handoff.
- 2026-05-14: Implemented release data models, a GitHub Release client, AppModel update-check state, and a Settings update panel with release-notes bottom sheet plus APK browser launch action.
- 2026-05-14: Replaced the initial plugin-based browser/version approach with a native Android `MethodChannel` bridge after confirming `flutter pub get` on this Windows machine fails desktop plugin symlink generation without Developer Mode.
- 2026-05-14: Updated `build_android_apk.ps1` to use `dart pub get` plus `flutter build apk --no-pub`, then rebuilt the release APK successfully.

# Surprises & Discoveries

- The existing Flutter app already depends on `http`, so release lookup can stay lightweight without adding a more complex networking stack.
- The repo already hardcodes the GitHub repository in `publish_github_release.ps1` as `qyhg110q/codexflow`, which provides a stable source of truth for the mobile update check.
- Flutter desktop plugin symlink generation is a hidden constraint on this Windows environment even for Android-only work. Avoiding new plugin dependencies keeps the packaging flow stable.

# Decision Log

- Use the public GitHub REST endpoint `releases/latest` instead of a custom backend API because release hosting already lives on GitHub and the mobile client only needs read-only metadata.
- Keep APK download outside the app and launch the system browser rather than implementing in-app download/install. This matches Android platform expectations and the requested user flow.
- Compare semantic core versions while ignoring build metadata such as `+1`, so `v0.1.0` and `0.1.0+1` resolve to the same product version.
- Use a native Android `MethodChannel` for app-version lookup and external browser launch instead of adding Flutter plugins, because the repo must still build from this Windows environment without requiring Developer Mode.
- Change the APK build script from `flutter pub get` to `dart pub get` followed by `flutter build apk --no-pub` so Android packaging remains reproducible even when desktop plugin symlink creation is unavailable.

# Validation

- `flutter analyze --no-pub`
- `flutter test --no-pub test/github_release_client_test.dart test/app_model_realtime_test.dart test/widget_test.dart`
- `.\build_android_apk.ps1`
- Additional note: full `flutter test --no-pub` still reports two existing failures in `test/dashboard_screen_test.dart` related to workspace picker assertions. They are outside this update-check change set.

# Outcomes & Retrospective

- Settings now includes a release-aware update panel that checks GitHub Releases, compares versions, and shows release notes before handing APK download off to the system browser.
- Android version lookup and browser opening are handled inside the existing Runner, so the feature works without introducing new Flutter plugin dependencies.
- The APK build script is more robust on this machine because it no longer depends on Windows Developer Mode for desktop plugin symlink generation.
