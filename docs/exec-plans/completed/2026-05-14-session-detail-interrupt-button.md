# Session Detail Interrupt Button

## Status

Completed on 2026-05-14.

## Goal

Make the Flutter session detail composer behave like Codex while an agent reply is in progress: show a stop button in place of send, switch back to send as soon as the user enters new input, and keep the stop action in a loading state until the interrupt API call succeeds or fails.

## Scope

- Flutter session detail composer state and button behavior.
- Flutter model/API waiting semantics for interrupt.
- Validation through Flutter analysis/tests and Android APK packaging.
- Deployment impact check: APK-only vs server update requirement.

## Progress

- Confirmed the Go agent already exposes `/api/v1/sessions/:id/turns/interrupt`.
- Confirmed the Flutter app already has `ApiClient.interruptTurn()` and `AppModel.interrupt()`.
- Identified the gap as composer UI state only: the session detail page always renders a send button.
- Replaced the single send-only composer action with a send/stop dual-state primary button.
- Updated the interrupt flow to return after the interrupt API accepts the request, while the dashboard/session refresh continues in the background.
- Added a regression test that proves interrupt completion no longer waits on the follow-up refresh request.

## Surprises & Discoveries

- The project already supports steering a live turn. That means the button state must prefer send whenever the draft or attachments are non-empty, even if the turn is still running.

## Decision Log

- Reuse the existing interrupt endpoint rather than changing the server protocol unless validation proves a backend mismatch.
- Treat stop/send as a composer-state decision derived from live turn status plus current draft content and attachments.

## Validation

- `.\.tooling\flutter\bin\flutter.bat analyze flutter\codexflow`
- `..\..\.tooling\flutter\bin\flutter.bat test test\app_model_realtime_test.dart` from `flutter\codexflow`
- `.\build_android_apk.ps1`

## Outcomes & Retrospective

The stop button now matches the intended Codex-style interaction model on the session detail page:

- While a turn is running and the draft is empty, the primary button becomes stop.
- As soon as the user types text or adds an attachment, the primary button becomes send so live steering remains available.
- Stop and send both keep their loading state until their respective API call completes, instead of waiting for the later dashboard refresh.

This change is client-only. No Go agent code or API surface changed, so deployment only needs an updated APK unless the target server is older than the already-existing interrupt endpoint.
