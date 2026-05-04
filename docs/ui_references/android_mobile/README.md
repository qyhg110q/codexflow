# CodexFlow Android UI Reference

这个目录是 CodexFlow Android / mobile 端的高保真界面参考。当前用 HTML/CSS/JS 实现，目的是先把移动端信息架构和视觉语言定下来，再迁移到 Flutter。

## 为什么先用 HTML

HTML 适合这个阶段：打开快、改动快、可以直接在手机浏览器或桌面浏览器的移动视口里预览。它也适合沉淀设计 token：颜色、圆角、阴影、间距都在 `:root` 里，后续迁移到 Flutter 的 `Palette`、`ThemeData` 和 common widgets 时很直接。

不建议这个阶段直接用原生 Android XML 或 Compose 起稿。原因是 CodexFlow 现在已有 Flutter 跨平台客户端，真正落地应优先改 Flutter；HTML 原型负责快速试错，Flutter 负责产品实现。

## 预览

直接打开：

```powershell
start .\docs\ui_references\android_mobile\android_mobile_prototype.html
```

或者用本地静态服务：

```powershell
python -m http.server 8089 -d .\docs\ui_references\android_mobile
```

然后访问：

```text
http://127.0.0.1:8089
```

## 设计方向

这版没有照搬桌面 Codex App 的左侧栏。桌面侧栏适合项目树和历史列表，手机端更适合任务现场优先：

- 首页回答：Agent 是否在线、如何直接输入第一条要求创建会话、哪些已有会话可打开、哪里卡审批。
- 打开的会话回答：这个会话的 turn 在做什么、计划推进到哪一步、下一条指令在哪里输入。
- 审批中心回答：哪些动作需要拍板、风险是什么、允许或拒绝。
- 设置页回答：Agent 地址、默认策略、模型和本地模式。

## 迁移到 Flutter 的对应关系

- `:root` token -> `lib/theme/palette.dart` 与间距/圆角常量。
- `.hero` -> `DashboardScreen` 顶部状态卡。
- `.session-card` -> `SessionRow` 或新的 compact session card。
- `.composer.in-flow` -> 首页新会话输入框，发送后调用创建会话接口并进入详情页。
- `.combo` -> Flutter 里建议实现为 `showModalBottomSheet`。权限三档为默认权限、自动审查、完全使用权限；模型配置包含智能深度低/中/高/超高、模型 GPT-5.4/GPT-5.5、速度标准/快速。
- 项目 combo -> 默认读取上一次会话项目；没有历史项目时显示新增项目，点击后进入项目路径填写。
- `.composer` -> `SessionDetailScreen` 的 `_ComposerCard`，作为打开会话后的继续输入框。
- `.approval-card` -> `ApprovalList` item，保留风险说明和双按钮决策。
- `.bottom-nav` -> Flutter `NavigationBar`，仅保留会话、审批、设置三个全局入口。

## 下一步建议

先用这个 HTML 原型继续做 2 到 3 轮视觉与交互迭代。确定信息架构后，再把 token 和组件迁到 Flutter，避免在 Dart 里反复调 UI 细节。
