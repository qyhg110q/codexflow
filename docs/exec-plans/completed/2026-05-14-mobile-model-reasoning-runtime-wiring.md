## Status

- State: completed
- Last updated: 2026-05-14 UTC+08:00

## Goal

让 Flutter 手机端的模型和推理设置不再只是本地 UI 偏好，而是能真实影响 Codex 会话创建与后续 turn 启动时的 runtime 参数。

## Scope

- Flutter `AppModel` / `ApiClient` 把模型与推理设置随 `startSession` 和 `startTurn` 请求下传
- Go HTTP API 接收并透传模型与推理字段
- Go runtime 把参数绑定到 `thread/start` / `turn/start`
- 补最小测试证明链路生效

## Progress

- 2026-05-14：确认当前 Flutter 只保存 `defaultModel` / `defaultReasoning`，不会下传到 Go Agent。
- 2026-05-14：通过本机 `codex app-server generate-json-schema --experimental` 确认协议支持：
  - `thread/start` 支持 `model`
  - `turn/start` 支持 `model` 和 `effort`
- 2026-05-14：确认 Codex CLI 可接受小写模型 id，例如 `gpt-5.5`；大写 UI 文案 `GPT-5.5` 不能直接作为 runtime model id 使用。
- 2026-05-14：完成 Flutter `AppModel` / `ApiClient` 改造，在 `startSession` / `startTurn` 请求中真实下传 `model` 和 `reasoningEffort`。
- 2026-05-14：完成 Go HTTP API 与 runtime 改造，透传并绑定 `thread/start` 的 `model`、`turn/start` 的 `model` 与 `effort`。
- 2026-05-14：补充 Go 与 Flutter 定向测试，覆盖 canonical model id 映射、HTTP 透传、runtime 参数拼装。

## Surprises & Discoveries

- `thread/start` schema 没有线程级 `reasoning` 字段，因此首个 turn 需要在 `turn/start` 上携带 `effort` 才能让初始推理设置生效。
- `turn/steer` schema 不支持模型 / 推理覆盖，因此运行中的同一 turn 只能沿用当前 turn 已设定的参数。

## Decision Log

- 2026-05-14：保留 Flutter 现有用户可见显示名，例如 `GPT-5.5`，仅在请求发出前映射到 Codex 可接受的 canonical model id。
- 2026-05-14：先做最小闭环，不改设置 UI 结构，不引入动态 model/list 拉取。

## Validation

- `go test ./...`
  - Result: passed.
- `..\..\.tooling\flutter\bin\dart.bat format lib\services\api_client.dart lib\state\app_model.dart test\app_model_realtime_test.dart`
  - Result: passed.
- `..\..\.tooling\flutter\bin\flutter.bat test test\app_model_realtime_test.dart`
  - Result: blocked by local Windows symlink restriction. Flutter reported `Building with plugins requires symlink support` and requested enabling Developer Mode.

## Outcomes & Retrospective

- Flutter 手机上的模型 / 推理设置现在不再只是本地偏好；对 Codex 新建会话和后续新 turn 都会真实传入 runtime。
- UI 显示名继续保持 `GPT-5.5` 这类易读文案，但请求前会映射到 Codex 可接受的 canonical model id，例如 `gpt-5.5`。
- 初始会话链路采用“两段生效”：
  - `thread/start` 绑定 `model`
  - 随后自动触发的首个 `turn/start` 绑定 `model` 与 `effort`
- 已知剩余限制：
  - `turn/steer` 协议本身不支持中途覆盖模型 / 推理，因此运行中的同一 turn 不能在 steer 时切换这些参数。
