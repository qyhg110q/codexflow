# Android Mobile UI Convergence Acceptance

Date: 2026-05-05 UTC+08:00

## Coverage Matrix

| Surface | Status | Evidence |
| --- | --- | --- |
| Theme tokens | Covered | `Palette` now maps HTML canvas, shell, surface, ink, muted, line, blue, green, orange, red, terminal colors. `PanelCard`, `CapsuleTag`, `CodexTextField`, nav theme and shared badges use the mobile token baseline. |
| Dashboard first screen | Covered | First screen now presents Agent status, port, date, mobile metrics, inline new-session composer, local preference chips, and compact recent session cards. |
| New session composer | Covered | Dashboard composer creates real sessions through `AppModel.startSession`; Agent / policy / model / reasoning use bottom-sheet selectors. Policy / model / reasoning / speed / local mode are stored as local Flutter preferences until the Agent API supports persistence. |
| Compact session cards | Covered | Session cards preserve lifecycle, Claude History / Runtime, takeover mode, branch, update time, pending approval path, resume/end/archive actions. |
| Session detail | Covered | Detail page now puts session header and turn reading flow before the continue composer; composer carries the same local preference chips and preserves attachments, steer, interrupt, and end actions. |
| Approval center | Covered | Approval center uses a wait-count header and compact risk-first approval cards with kind chips, risk summary, related fields, and primary decision buttons. |
| Settings | Covered | Settings now focuses on Agent URL, connection state, default policy, model, reasoning, speed, local mode, and mobile product principles. |
| Navigation shell | Covered | Bottom `NavigationBar` keeps three global entries and uses mobile token styling. |

## Acceptance Checklist

- [x] Dashboard first screen exposes online state, port, metrics, inline composer, and recent sessions.
- [x] New and continue composers share the same visual grammar: text field, attachment / mode controls, preference chips, and one primary send action.
- [x] Existing real API calls remain in place for start session, resume, archive, end, submit prompt, steer, interrupt, upload image, and approval resolve.
- [x] Claude lifecycle distinctions remain visible: `History`, `Runtime`, existing runtime attach, history-opened runtime, and new runtime.
- [x] Approval cards keep command, file change, permissions, and user input action mappings.
- [x] Settings clearly marks model / policy / reasoning / speed / local mode as local Flutter UI preferences for now.
- [x] Dart formatting completed with project-local SDK.
- [x] `flutter analyze` completed.
- [x] Android debug APK build completed.
- [ ] Automated screenshot capture completed.

## Validation Notes

- `..\..\.tooling\flutter\bin\dart.bat format ...` completed successfully.
- `..\..\.tooling\flutter\bin\flutter.bat analyze` completed successfully in the elevated tooling environment: `No issues found!`.
- `..\..\.tooling\flutter\bin\flutter.bat build apk --debug` completed successfully. APK: `flutter/codexflow/build/app/outputs/flutter-apk/app-debug.apk`.
- Screenshot capture was not completed in this pass; Android compilation now covers the required build validation path.
