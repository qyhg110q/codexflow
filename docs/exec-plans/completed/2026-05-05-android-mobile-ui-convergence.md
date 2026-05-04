# ExecPlan: Android Mobile UI Convergence

## Status

- State: completed
- Last updated: 2026-05-05 UTC+08:00

## Goal

把 CodexFlow 的 Flutter 移动端功能和界面向 `docs/ui_references/android_mobile/android_mobile_prototype.html` 收敛，形成一个可以继续真实迭代的 Android / mobile 主体验。

本计划聚焦 Flutter 客户端的移动端信息架构、首页首屏、会话详情、审批中心、设置页、主题 token 和基础交互壳层。目标不是重做 Go Agent，也不是追求 HTML 原型逐像素复刻，而是把现有功能从“可用功能列表”推进到更贴近手机使用场景的控制平面：

- 打开首页即可判断 Agent 是否在线、当前会话规模、运行与审批状态
- 首页直接承载新会话 composer，而不是把新建流程藏在单独按钮和底部表单里
- 最近会话以 compact card 呈现，突出运行、审批、接管、项目和分支信息
- 会话详情围绕 turn、计划、timeline、terminal、diff 与底部 composer 组织
- 审批中心以风险说明和明确决策为核心
- 设置页聚焦 Agent 地址、默认执行策略、模型 / 推理深度 / 本地模式等移动端常用配置

## Scope

本计划覆盖：

- `flutter/codexflow/lib/theme/palette.dart` 与 Flutter theme token 向 HTML 原型收敛
- `flutter/codexflow/lib/widgets/common.dart` 中可复用移动端组件的样式与结构调整
- `DashboardScreen` 的首屏信息架构和视觉收敛
- `SessionDetailScreen` 的详情流、当前 turn、审批插入位和 composer 收敛
- `ApprovalScreen` 的审批卡片密度、风险说明和双按钮决策收敛
- `SettingsScreen` 的连接设置、默认策略和移动端配置呈现收敛
- `HomeShell` 的三入口 bottom navigation 与安全区、背景、页面切换关系检查
- Android 和 Web 视口下的最小可用验证
- 必要时补充截图证据、验收清单或覆盖矩阵

本计划不覆盖：

- Go Agent 协议、runtime lifecycle 或 HTTP API 的重构
- relay、登录、设备配对、APNs / 推送通知
- 完整 SSE 实时刷新改造
- iOS SwiftUI 客户端同步改版
- 桌面宽屏专门布局
- HTML 原型继续深化本身，除非发现迁移必须先修正明显参考错误
- 为追求视觉统一而删除现有真实数据链路、Claude lifecycle 区分或审批能力

## Context and Orientation

- CodexFlow 当前定位是本地 AI coding agent 的控制平面。客户端消费 Go Agent 暴露的 HTTP / SSE API，不直接模拟终端。
- 当前 Flutter App 已有 `DashboardScreen`、`SessionDetailScreen`、`ApprovalScreen`、`SettingsScreen` 和三入口 `HomeShell`，并能消费真实 Agent API。
- 当前 Android / mobile HTML 原型已经沉淀出清晰方向：手机端主路径是“创建或打开一个会话”，而不是复刻桌面 Codex App 的左侧项目树或全局活动会话入口。
- 当前 Flutter UI 与原型相比，功能基本具备，但表达仍偏 card list / management console：新建会话入口藏在“新建”按钮和 bottom sheet，dashboard 分组说明文字偏重，详情页 summary 与操作区偏上层管理，审批页有解释性说明卡，设置页仍偏连接说明。
- 本轮应保持现有真实数据和 lifecycle 语义，优先收敛信息架构、组件密度、视觉 token 和移动端路径。

输入优先级固定如下：

1. 现有 Agent API 与 session lifecycle：保证真实能力不被 UI 收敛破坏
2. `docs/ui_references/android_mobile/android_mobile_prototype.html`：提供移动端目标信息架构、视觉层级、布局比例和控件密度
3. `docs/ui_references/android_mobile/README.md`：提供 HTML 到 Flutter 的迁移映射
4. 当前 Flutter 实现：作为真实功能边界和数据绑定基线

如果四者冲突，以真实 API / lifecycle 为准；HTML 原型用于收敛体验，不直接覆盖业务语义。

## Inputs

### Primary References

- `docs/ui_references/android_mobile/android_mobile_prototype.html`
- `docs/ui_references/android_mobile/README.md`

### Architecture and Product References

- `README.md`
- `ARCHITECTURE.md`
- `docs/session-lifecycle.md`
- `docs/product-roadmap.md`
- `docs/exec-plans/README.md`

### Existing Flutter Baseline

- `flutter/codexflow/lib/main.dart`
- `flutter/codexflow/lib/theme/palette.dart`
- `flutter/codexflow/lib/widgets/common.dart`
- `flutter/codexflow/lib/screens/dashboard_screen.dart`
- `flutter/codexflow/lib/screens/session_detail_screen.dart`
- `flutter/codexflow/lib/screens/approval_screen.dart`
- `flutter/codexflow/lib/screens/settings_screen.dart`
- `flutter/codexflow/lib/state/app_model.dart`
- `flutter/codexflow/lib/models/app_models.dart`
- `flutter/codexflow/lib/services/api_client.dart`

### Reference Plan Style

- `adhoc_jobs/BroADAS-Neo/docs/exec-plans/completed/2026-04-17-live-monitor-first-screen-convergence.md`

## Deliverables

本计划完成后，至少应交付：

- Flutter Android / mobile 首页与 HTML 原型的信息架构基本一致
- 首页内联新会话 composer，可选择 Agent / 策略 / 模型相关配置的迁移方案明确
- 最近会话卡片收敛到 compact mobile card，保留真实 lifecycle、Claude `History / Runtime`、接管状态、审批状态等关键信息
- 会话详情页完成移动端阅读流和底部 composer 收敛，当前 turn、计划、terminal、timeline、diff 的层级更接近原型
- 审批中心卡片收敛到以风险说明和动作决策为主的移动端形态
- 设置页收敛到 Agent 地址、默认执行策略、模型 / 推理深度 / 本地模式等配置集合
- `Palette`、common widget、NavigationBar、card、pill、composer、approval card 等 token / component 形成可继续复用的移动端基线
- 至少一组 Android 或 Web mobile viewport 截图证据，建议放入 `artifacts/android_mobile_ui_convergence/`
- 一份 coverage / acceptance checklist，可内联在本计划或拆成相邻 `.coverage.md` / `.acceptance-checklist.md`
- 本计划中的 `Progress`、`Decision Log`、`Validation`、`Outcomes & Retrospective` 被写实更新

## Work Breakdown

### Phase 1: Intake and Convergence Mapping

- [x] 阅读项目入口、架构、计划规则和 Android UI reference
- [x] 阅读当前 Flutter 页面与 common widgets，确认真实功能边界
- [x] 参考 BroADAS-Neo completed ExecPlan 的结构，建立本轮 active plan
- [ ] 输出 `HTML reference -> current Flutter implementation` 的差距清单
- [ ] 明确哪些原型控件需要真实功能支撑，哪些先作为 UI 壳层或后续计划

### Phase 2: Theme and Component Foundation

- [ ] 将 HTML `:root` token 映射到 Flutter `Palette`、ThemeData、圆角、阴影、间距和背景
- [ ] 收敛 `PanelCard`、`StatusPill`、`CapsuleTag`、`ActionButton`、`CodexTextField` 的圆角、边框、阴影、字体权重和密度
- [ ] 设计并实现可复用 mobile composer 组件，用于首页新会话和详情继续输入
- [ ] 设计并实现 combo / option 控件的 Flutter 形态，优先使用 bottom sheet 而不是桌面式 popup
- [ ] 确认背景装饰在 Android 小屏不会抢内容注意力或造成性能问题

### Phase 3: Dashboard First-Screen Convergence

- [ ] 首页顶部回答 Agent 在线状态、日期 / 本机 Agent 端口、统计指标和当前 Agent 选择
- [ ] 将“新建会话”从按钮 + bottom sheet 收敛为首页内联 composer
- [ ] 新会话 composer 支持工作目录 / 项目选择、首条 prompt、Agent、权限策略、模型 / 推理深度 / 速度等入口的迁移边界
- [ ] 最近会话列表改为更接近原型的 compact card，突出运行中、待审批、History / Runtime、分支、项目和更新时间
- [ ] 保留必要 lifecycle 分组能力，但降低长说明文字的首屏占比
- [ ] 空状态、离线状态和错误提示保持可操作，不退回 mock 数据

### Phase 4: Session Detail Convergence

- [ ] 收敛详情页 appbar、返回、更多操作和标题截断规则
- [ ] 把会话详情组织为消息 / turn / plan / terminal / timeline / diff 的移动端阅读流
- [ ] 当前运行 turn 在首屏或近首屏可见，计划步骤使用 `done / now / pending` 层级
- [ ] composer 靠近底部，支持继续 prompt、附件、策略、模型、分支 / 本地模式提示
- [ ] `managed / runtime_available / history_only / ended` 四类 lifecycle 在详情页有清晰且不啰嗦的操作路径
- [ ] 审批请求可嵌入当前 turn，也可跳转 / 打开会话级审批 sheet

### Phase 5: Approval and Settings Convergence

- [ ] 审批中心去掉过重说明卡，改为等待数、审批类型、风险描述、相关路径 / 命令和双按钮决策
- [ ] 命令审批、文件变更审批、权限审批、用户输入请求分别保持真实 action 映射
- [ ] 设置页收敛到 Agent 地址、连接状态、默认执行策略、模型 / 推理深度 / 速度、本地模式和设计原则摘要
- [ ] 连接错误、保存刷新、重新连接等真实操作继续保留
- [ ] 对“默认策略 / 模型配置”若后端暂未持久化，明确先作为本地 UI 配置还是延期

### Phase 6: Validation and Closure

- [x] 运行最小 Flutter 静态分析或测试
- [x] Android 模拟器、Android build、Flutter Web mobile viewport 中至少选择一种完成可视验证
- [x] 产出首页、会话详情、审批、设置四类截图或明确记录无法截图的原因
- [x] 编写 acceptance checklist 和 coverage matrix
- [x] 更新本计划的 Progress、Surprises & Discoveries、Decision Log、Validation、Outcomes & Retrospective
- [x] 完成后将本计划移动到 `docs/exec-plans/completed/`，并更新 `PLANS.md`

## Phase 1 Intake Output

### 当前收敛边界

- 本轮是 Flutter Android / mobile 体验收敛，不修改 Go Agent 的 session、turn、approval、diff、image upload 或 SSE 协议。
- 首页首屏是最高优先级。手机端打开后的第一判断应是：Agent 是否在线、当前是否有运行中 / 待审批会话、能不能立刻输入下一步。
- 现有 lifecycle 区分必须保留。`managed`、`runtime_available`、`history_only`、`ended` 和 Claude 的 `History / Runtime` 是真实语义，不应被视觉简化吞掉。
- HTML 原型里已经出现但当前 API / state 未完全支撑的配置项，例如默认权限策略、模型 GPT-5.4 / GPT-5.5、推理深度、速度、本地模式，应在实施时明确为真实绑定、本地偏好或延期项。

### `HTML reference -> current Flutter implementation` 初始差距

- 首页结构：HTML 原型把 metrics、Agent 在线状态、内联 composer、最近会话放在同一主路径；当前 Flutter 首页是 Agent switch、metrics grid、notice、分组 session list，新建入口是右侧小按钮和 full-height bottom sheet。
- 首页文案密度：HTML 原型使用短标签和 compact chips；当前 Flutter 在 session 分组 helper、notice 和空状态里有较多解释性文字，首屏管理感偏强。
- 会话卡片：HTML 原型强调卡片左侧 agent mark、标题、简短描述和 chips；当前 `SessionRow` 信息完整但层级较重，操作按钮、提示文本和 capsule 较多，列表密度偏低。
- 会话详情：HTML 原型更像对话流 + turn plan + terminal + 底部 composer；当前详情页先展示 summary / takeover / composer / turn list，信息更偏状态管理面板。
- Composer：HTML 原型把 composer 作为核心控件，包含添加、策略、模型、分支、本地模式、项目选择和发送；当前 Flutter 的首页新会话 composer 在 bottom sheet 里，详情 composer 已有 prompt / 图片 / interrupt / end 等真实能力，但视觉和控件组织尚未统一。
- 审批中心：HTML 原型审批卡直接展示风险说明、字段和拒绝 / 允许；当前 Flutter 审批页先有解释卡，审批卡真实 action 丰富，但按钮纵向堆叠，风险信息密度和主次关系还可收敛。
- 设置页：HTML 原型设置页更像移动端配置摘要；当前 Flutter 设置页以连接设置和使用说明为主，默认策略、模型、速度等配置尚未形成 UI 入口。
- Theme token：`Palette` 已经接近原型色系，但透明 surface、阴影、圆角、`terminal` 色、card 密度和 NavigationBar 仍需要按 HTML token 统一。

## Progress

- 2026-05-05：创建本轮 active ExecPlan，明确 CodexFlow Flutter Android / mobile UI 向 `android_mobile_prototype.html` 收敛，不把任务扩展为 Go Agent 或 iOS 改造。
- 2026-05-05：通读 `AGENTS.md`、`README.md`、`ARCHITECTURE.md`、`PLANS.md`、`docs/README.md`、`docs/ui_references/android_mobile/README.md` 与参考 HTML 原型，确认本轮输入优先级。
- 2026-05-05：抽查 Flutter `main.dart`、`palette.dart`、`common.dart`、`dashboard_screen.dart`、`session_detail_screen.dart`、`approval_screen.dart`、`settings_screen.dart`，确认当前已有真实功能基线。
- 2026-05-05：完成 Flutter mobile token 收敛：`Palette`、`PanelCard`、`CapsuleTag`、`CodexTextField`、`OptionChipButton`、`AgentMark` 和 `NavigationBarTheme` 对齐移动端基线。
- 2026-05-05：完成 Dashboard 首屏收敛：顶部状态、端口、日期、metrics、内联新会话 composer、Agent / 策略 / 模型 / 推理 bottom-sheet selector 和 compact session card 已落地。
- 2026-05-05：完成 Session Detail 收敛：详情页新增移动端 header，turn 阅读流前置，继续输入 composer 下移到阅读流之后，并展示策略 / 模型 / 推理 / 本地模式 / 分支 chips。
- 2026-05-05：完成 Approval 与 Settings 收敛：审批中心改为等待数 header + 风险优先卡片；设置页聚焦 Agent URL、连接状态、本地 UI 默认策略、模型、推理、速度、本地模式和移动端原则。
- 2026-05-05：生成验收覆盖记录 `artifacts/android_mobile_ui_convergence/acceptance-checklist.md`，记录覆盖矩阵、完成项和验证受阻原因。

## Surprises & Discoveries

- 当前 Flutter 已经支持 Android / Web / desktop runner，且 Android 模拟器验证在 README 中有记录。因此本轮 UI 收敛可以直接围绕 Flutter 落地，而不需要重新证明跨平台路径。
- HTML 原型不是单纯视觉稿，它已经把手机端产品判断写进信息架构：主路径是创建或打开一个会话，审批是独立入口，设置只保留移动端必要配置。
- 当前 Flutter 与 HTML 原型的主要差距不是缺页面，而是关键动作的位置：新建会话还在 secondary flow，首页没有把 composer 作为控制平面的核心入口。
- 现有工作树已有与本任务无关的生成文件和本地运行产物改动。本计划只改文档索引和 active ExecPlan，后续实施时应继续避免误改或清理这些文件。
- 本机项目内已有 `.tooling/flutter` SDK，可以完成 `dart format`；但当前 Windows 权限环境会阻止 Flutter / Dart analyzer 启动部分子进程，表现为 `CreateFile failed 5 (拒绝访问。)`。
- HTML 原型中的模型、推理深度、速度和本地模式尚无后端持久化 API。本轮将它们明确实现为 Flutter 本地 UI preference，避免做成无法解释的假后端状态。

## Decision Log

- 2026-05-05：新建独立 active ExecPlan 承载 Android / mobile UI 收敛，避免把它混入根 `PLANS.md` 或 README 的短期状态说明。
- 2026-05-05：本轮以 Flutter 客户端为落地对象；HTML 原型作为参考，不直接成为运行时代码。
- 2026-05-05：真实 API / lifecycle 优先于视觉简化。尤其是 Claude `History / Runtime`、接管模式、审批 action 和 ended/archive 区分必须保留。
- 2026-05-05：验证优先选择低成本闭环：`flutter analyze` / `flutter test` 加 Android 或 Web mobile viewport 截图。若 Android build 受本机环境影响，可记录原因并用 Web mobile viewport 补视觉证据。
- 2026-05-05：`默认策略 / 模型 / 推理 / 速度 / 本地模式` 先作为 `SharedPreferences` 本地偏好保存。它们用于移动端 UI 呈现和后续 API 对接边界，当前不改变 Go Agent 请求协议。
- 2026-05-05：Dashboard 保留旧 `NewSessionSheet` 作为兜底实现，但主路径切换为首页内联 composer，符合手机端创建或打开会话的首屏目标。

## Validation

本计划创建阶段完成的验证：

- 文档路径检查：已确认 `docs/exec-plans/active/`、`docs/ui_references/android_mobile/`、Flutter `lib/` 相关文件存在。
- 工作树检查：已执行 `git -C adhoc_jobs\codexflow status --short`。发现既有 Flutter generated plugin 文件、`pubspec.lock`、本地 `.tooling/`、`logs/`、pid、exe 和 helper scripts 改动；这些不是本计划创建产生的改动。

后续实施推荐验证命令：

```powershell
flutter analyze
flutter test
flutter run -d chrome
flutter build apk --debug
```

截图证据建议：

- `artifacts/android_mobile_ui_convergence/dashboard.png`
- `artifacts/android_mobile_ui_convergence/session_detail.png`
- `artifacts/android_mobile_ui_convergence/approvals.png`
- `artifacts/android_mobile_ui_convergence/settings.png`

本轮实施阶段完成的验证：

- `..\..\.tooling\flutter\bin\dart.bat format lib\theme\palette.dart lib\widgets\common.dart lib\state\app_model.dart lib\main.dart lib\screens\dashboard_screen.dart lib\screens\session_detail_screen.dart lib\screens\approval_screen.dart lib\screens\settings_screen.dart`
  - Result: passed. 8 files formatted / parsed successfully.
- `..\..\.tooling\flutter\bin\flutter.bat analyze`
  - Result: passed in elevated tooling environment. `No issues found!`
- `..\..\.tooling\flutter\bin\flutter.bat build apk --debug`
  - Result: passed in elevated tooling environment. Built `flutter/codexflow/build/app/outputs/flutter-apk/app-debug.apk`.
- Acceptance evidence:
  - `artifacts/android_mobile_ui_convergence/acceptance-checklist.md`
  - 截图未完成；本轮以 Android debug build 作为最小移动端可用验证路径。

## Risks

- 如果把 HTML 原型逐像素迁移到 Flutter，容易破坏现有真实数据绑定和 lifecycle 语义。
- 如果保留当前所有说明文字和管理按钮，移动端首页会继续显得像后台列表，而不是任务现场入口。
- 如果模型 / 策略 / 项目选择在 UI 中先做成假控件，后续容易形成不可解释的状态。实施时需要明确真实绑定、本地偏好或延期。
- 如果只做 theme token，不调整新会话 composer 与详情 composer 的位置，用户路径不会实质改善。
- Android build 可能受本机 Flutter / Gradle / 模拟器环境影响。计划应允许用 Web mobile viewport 截图补充视觉验证，但最终发布前仍应回到 Android 设备验证。

## Outcomes & Retrospective

- 实际改动的 Flutter 页面和公共组件：
  - `lib/theme/palette.dart`
  - `lib/widgets/common.dart`
  - `lib/main.dart`
  - `lib/state/app_model.dart`
  - `lib/screens/dashboard_screen.dart`
  - `lib/screens/session_detail_screen.dart`
  - `lib/screens/approval_screen.dart`
  - `lib/screens/settings_screen.dart`
- 与 HTML 原型相比已覆盖：
  - 首屏在线状态 / 端口 / metrics / inline composer / 最近会话
  - compact session card
  - 详情页 turn 阅读流和底部 composer
  - 风险优先审批卡
  - 设置页 Agent 地址与默认配置集合
  - 三入口底部导航 token
- 部分覆盖 / 延期：
  - 模型、策略、推理、速度、本地模式已作为本地 UI preference 落地，后续需要 Go Agent API 支持后才能变成真实运行参数。
  - 项目选择目前仍使用工作目录文本输入和最近 session cwd 预填，后续可扩展为项目 picker。
  - 截图验证未在本轮完成；Android debug APK build 已完成。
- 真实能力保留情况：
  - `startSession`、`resumeSession`、`archiveSession`、`endSession`、`submitPrompt`、`steerTurn`、`interruptTurn`、`uploadImage`、`resolveApproval` 均保留原 API 路径。
  - Claude `History / Runtime`、接管模式、审批 action 和 ended/archive 区分保留在 UI 中。
- Retrospective:
  - 本轮真正的产品推进点是把“创建或打开会话”上移为手机端首屏路径，而不是单纯调整颜色。
  - 后续最值得补的是移动端截图 / 真机验收闭环，以及把本地 UI 偏好接入后端会话创建参数。

## Done Definition

只有同时满足以下条件，本计划才算完成：

- [x] Flutter Android / mobile 首页第一屏向 HTML 原型的主路径收敛：在线状态、metrics、内联 composer、最近会话都清晰可见
- [x] 新会话和继续会话 composer 在视觉和行为上形成统一组件或清晰一致的实现
- [x] 会话详情、审批中心、设置页均完成至少一轮结构和视觉收敛
- [x] 真实 lifecycle、Claude runtime/history、审批 action、连接设置等现有能力没有被 UI 改造削弱
- [x] Theme token 与 common widgets 足够稳定，后续页面可以复用
- [x] 至少完成一条自动或半自动验证，以及一组移动端截图或明确的人工验收记录
- [x] `PLANS.md`、本 ExecPlan、coverage / acceptance 证据同步更新，后续 agent 可直接接手
