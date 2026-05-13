# ExecPlan: Agent Markdown Contrast

## Status

- Completed

## Goal

- Eliminate low-contrast text inside agent reply bubbles on the Flutter client, especially inline code and markdown fragments that currently render too close to the white chat background.

## Scope

- Flutter shared markdown renderer used by session detail agent messages
- Theme tokens that affect code text and code background contrast
- Validation through static analysis and Android APK build

## Progress

- 2026-05-13: Confirmed the issue path in `SessionDetailScreen` agent bubbles and traced rendering to shared `MarkdownBodyBlock` in `lib/widgets/common.dart`.
- 2026-05-13: Identified the main cause: markdown `code` style used a light foreground intended for dark code blocks, which made inline code nearly invisible on light chat bubbles.
- 2026-05-13: Updated the shared markdown style to use high-contrast code text, a light code surface, and a bordered code block container.

## Surprises & Discoveries

- `flutter_markdown` 0.7.7+1 applies the same `code` text style to inline code and fenced code blocks, so a single dark-theme token choice can silently break inline readability.

## Decision Log

- Use a unified light code surface with dark text instead of keeping dark fenced code blocks. This keeps all markdown code variants above the contrast threshold without introducing a custom markdown builder.
- Tighten link styling in the shared markdown sheet so links stay readable and distinct inside the same bubble.

## Validation

- `flutter analyze`
- `flutter test`
- `.\build_android_apk.ps1`
- Built APK: `flutter/codexflow/build/app/outputs/flutter-apk/app-release.apk`

## Outcomes & Retrospective

- Agent reply markdown now uses a high-contrast code treatment that stays readable inside light chat bubbles.
- The fix stays inside the shared markdown renderer, so future reply surfaces that reuse `MarkdownBodyBlock` inherit the same contrast behavior automatically.
