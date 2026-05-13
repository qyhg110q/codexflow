# CodexFlow

CodexFlow 是一个面向 Codex CLI 的控制台客户端。

它的目标不是“远程看终端”，而是把 Codex 的会话、turn、diff、审批、状态流，整理成一套适合手机和轻量客户端管理的控制平面。

当前已经支持两条主要 Agent 链路：

- `Codex`
- `Claude Code`

当前仓库包含三部分：

- `Go Agent`：运行在本地电脑上的服务，负责接入 Codex CLI
- `iOS App`：运行在 iPhone 上的 SwiftUI 客户端，负责监控、审批和继续指挥
- `Flutter App`：新的跨平台客户端，负责 Android / Web / 桌面端接入同一套 Agent API

## 工作原理

CodexFlow 不依赖 OCR，也不是去截图识别终端。

它直接接在 `codex app-server` 之上，通过结构化协议拿到真实的会话和执行状态，再转成适合移动端消费的 API。

整体链路如下：

```text
Codex CLI / codex app-server
        │
        │ JSON-RPC over stdio
        ▼
Go Agent
  - 启动并持有本地 codex app-server
  - 发现已有 session / loaded session
  - 接收通知、diff、plan、审批请求
  - 暴露 HTTP API + SSE
        │
        │ HTTP / SSE
        ▼
Client Apps
  - iOS SwiftUI App
  - Flutter App
  - 会话总览 / 会话详情 / 审批中心
  - 继续下一步 / steer / interrupt
```

这套设计的核心点是：

- `Go Agent` 负责把 Codex 的原始协议适配成稳定的应用层接口
- 客户端不直接操纵终端，而是操纵会话本身
- “自动发现已有会话”和“受控管理新会话”可以同时存在
- 对 `Claude Code` 会额外区分 `历史导入` 和 `可接管 runtime`

## 当前已实现的功能

### Go Agent

- 直接启动并连接本机 `codex app-server`
- 自动发现真实的 Codex 历史会话
- 自动发现 Claude 历史 transcript 与本机 live runtime
- 读取 `thread/list`、`thread/read`、`thread/loaded/list`
- 支持新建受控会话
- 支持重新接管历史会话
- 支持开始新 turn、steer 当前 turn、interrupt 当前 turn
- 支持结束会话、归档会话
- 捕获命令审批、文件变更审批、权限审批、结构化用户输入请求
- 对外提供 HTTP API 和 SSE 事件流

### iOS App

- 会话总览页
- 已接管 / 已结束 / 可接管 Runtime / 历史导入分组
- 总会话、已加载、运行中、待审批统计
- 会话详情页
- plan / diff / timeline 展示
- 继续下一步、steer、interrupt
- 审批中心
- Agent 地址配置
- 只显示真实数据，不再回退 mock 数据

### Flutter App

- 复用同一套 Agent HTTP API
- 会话总览页
- 会话详情页
- 审批中心
- 设置页 / Agent 地址配置
- Claude 会话显示 `History / Runtime` 与 `现有 Runtime / 历史新开 / 新建 Runtime` 状态
- Android / Web / 桌面端 runner 已补齐
- 已适配浏览器跨域访问本地 Agent

## 当前支持的端

- `Go Agent`：Windows、Linux、macOS (go原生支持多端)
- `客户端支持平台`：Windows、Linux、macOS、iOS、Android、Web
- `iOS SwiftUI App`：iOS
- `Flutter App`：Windows、Linux、macOS、iOS、Android、Web

## 当前已验证可用的端

- `Go Agent`（macOS）
- `iOS SwiftUI App`
- `Flutter Web (Chrome)`
- `Flutter Android`（MuMu 模拟器）

## 发布产物

- GitHub Release 推荐包含这几个资产：
- `codexflow-windows-host-vX.Y.Z.zip`
- `codexflow-android-vX.Y.Z.apk`
- `codexflow-web-vX.Y.Z.zip`
- `SHA256SUMS.txt`

推荐下载顺序：

1. 大多数用户先下载 `codexflow-windows-host-vX.Y.Z.zip`
2. Android 用户再下载 `codexflow-android-vX.Y.Z.apk`
3. 只有在你要自建静态托管或非 Windows 宿主时，再下载 `codexflow-web-vX.Y.Z.zip`

关于 APK：建议和 Windows host bundle 放在同一个 GitHub Release 里一起发布。

原因很简单：

- 它们属于同一套终端产品，而不是独立项目
- GitHub Release 本来就适合多资产分发
- 用户只需要记住一个 release 页面
- AI 代理在自动部署时也更容易做资产选择

当前不建议把 iOS 安装包作为同层级 release 资产公开发布，因为 iOS 还有签名和分发链路问题，和 APK 的直接下载安装不是一个复杂度

## 当前状态

项目已经能跑通真实链路：

- Agent 可以连上本机 Codex CLI
- `dashboard` API 能返回真实会话数据
- Claude 会话生命周期已经拆分为 `managed / runtime_available / history_only / ended`
- iOS 客户端可以消费真实数据并进行操作
- Flutter Web 客户端可以通过浏览器访问本地 Agent
- Flutter Android 客户端可以在模拟器中访问局域网 Agent

最近这次更新主要包括：

- Claude 会话分层：把 `历史导入` 和 `可接管 runtime` 正式拆开
- 新建 / 接管 / 结束会话统一进入明确的生命周期阶段
- 审批中心已经接入自动审批策略
- SSE 事件流已经打通，客户端支持实时刷新
- Agent 三端打包、Flutter Web / Android 打包、iOS `unsigned ipa` 导出流程验证

当前还没有做的部分：

- 远程 relay
- 登录与设备配对
- APNs 推送
- macOS 菜单栏 Launcher

## 快速开始

### 路径 A：直接使用 GitHub Release

这是最适合最终用户的方式。

#### Windows 宿主机

下载并解压：

- `codexflow-windows-host-vX.Y.Z.zip`

解压后目录里应至少有：

- `codexflow-agent.exe`
- `start_codexflow.ps1`
- `stop_codexflow.ps1`
- `web/`

宿主机前置要求：

- Windows
- 已安装并登录 `codex` CLI
- `python` 在 `PATH` 里可用
- 如果要跨局域网外访问，安装并登录 `Tailscale`

启动：

```powershell
.\start_codexflow.ps1
```

脚本会：

- 启动本地 Agent
- 启动 bundled Flutter Web
- 自动尝试配置 Tailscale Serve
- 打印可以直接填进 CodexFlow `Settings > Agent Address` 的地址

典型输出：

```text
LAN:       http://192.168.31.147:4318
Tailscale: https://your-machine.your-tailnet.ts.net
```

停止：

```powershell
.\stop_codexflow.ps1
```

#### Android 客户端

下载：

- `codexflow-android-vX.Y.Z.apk`

然后在 Android 设备上安装 APK，并在设置页填入上面脚本打印的地址。

#### Web 资产

如果你只是通过 Windows host bundle 使用 CodexFlow，其实不需要单独下载 Web 资产。

`codexflow-web-vX.Y.Z.zip` 的用途是：

- 你想把 Web UI 放到自己的静态站点
- 你不用 Windows bundle，而是自己托管 Agent 和静态站点
- 你想让 AI 代理在服务器上自动部署一份 Web 前端

### 路径 B：从源码构建

适合开发者和要二次改造的人。

### 1. 环境要求

- Windows / Linux / macOS（运行 Agent）
- 已安装并可用的 `codex` CLI
- 已完成 Codex 登录
- Go 1.26+
- Xcode（仅在运行 iOS App 时需要）
- Flutter（仅在运行 Flutter App 时需要）

### 2. 启动 Go Agent（源码模式）

在仓库根目录执行：

```bash
go run ./cmd/codexflow-agent
```

如果你是在源码树里直接给自己用，Windows 下也可以运行：

```powershell
.\start_agent_user.ps1
```

这个脚本适合开发态使用，它会：

- 自动启动或重编译 `codexflow-agent.exe`
- 启动 Flutter Web 静态站点
- 自动配置 Tailscale Serve（如果本机已安装并登录 Tailscale）
- 直接打印可以填进 CodexFlow `Settings > Agent 地址` 的地址

典型输出会包含：

```text
LAN:       http://192.168.31.147:4318
Tailscale: https://laptop-g84e45ma.tailfa6379.ts.net
```

默认监听地址：

```text
127.0.0.1:4318
```

可选环境变量：

- `CODEXFLOW_LISTEN_ADDR`
- `CODEXFLOW_CODEX_PATH`
- `CODEXFLOW_REFRESH_INTERVAL`
- `CODEXFLOW_STATE_DB_PATH`

如果你的 `codex` 不在系统 `PATH` 里，可以显式指定它：

```bash
CODEXFLOW_CODEX_PATH=/path/to/codex go run ./cmd/codexflow-agent
```

例如：

- macOS / Linux：`CODEXFLOW_CODEX_PATH=/usr/local/bin/codex`
- Windows：`CODEXFLOW_CODEX_PATH=C:\path\to\codex.exe`

如果你想先编译再运行：

```bash
go build -o codexflow-agent ./cmd/codexflow-agent
./codexflow-agent
```

在 Windows 上可执行文件会是：

```text
codexflow-agent.exe
```

### 3. 推荐部署方式

推荐的部署方式是：

1. 在安装了 `codex` CLI 的那台主机上运行 `Go Agent`
2. 让 Agent 暴露一个本机、局域网，或者 tailnet 内可访问的 HTTP 地址
3. 用 iOS / Android / Web / 桌面客户端去连接这个地址

同机使用：

```text
Agent: 127.0.0.1:4318
Client: http://127.0.0.1:4318
```

局域网跨设备使用：

```bash
CODEXFLOW_LISTEN_ADDR=0.0.0.0:4318 go run ./cmd/codexflow-agent
```

然后在客户端里填写运行 Agent 那台机器的局域网 IP，例如：

```text
http://192.168.1.10:4318
```

#### 通过 Tailscale Service 远程访问

如果你希望在局域网外用 Android / iOS / Web 客户端访问 CodexFlow，可以把 Agent 和 Web 客户端只绑定到本机回环地址，再通过 Tailscale Service 暴露一个 tailnet 内部 HTTPS 入口。这样不需要把 CodexFlow 直接暴露到公网，也不需要在手机上记端口。

示例拓扑：

```text
https://codexflow.<tailnet>.ts.net/
  /healthz -> http://127.0.0.1:4318/healthz
  /api     -> http://127.0.0.1:4318/api
  /        -> http://127.0.0.1:8088
```

源码模式下，先启动 Agent：

```bash
CODEXFLOW_LISTEN_ADDR=127.0.0.1:4318 go run ./cmd/codexflow-agent
```

再启动一个静态文件服务承载 Flutter Web 构建产物，例如：

```bash
cd flutter/codexflow/build/web
python3 -m http.server 8088 --bind 127.0.0.1
```

然后配置 Tailscale Serve：

```bash
tailscale serve --bg --https 443 http://127.0.0.1:8088
tailscale serve --bg --https 443 --set-path /api http://127.0.0.1:4318/api
tailscale serve --bg --https 443 --set-path /healthz http://127.0.0.1:4318/healthz
```

如果 Tailscale 提示需要管理员批准，需要先在 Tailscale 控制台批准这台机器的 serve 配置。批准后，在客户端里填写：

```text
https://your-machine.your-tailnet.ts.net
```

安全提醒：当前 CodexFlow Agent 还没有内置登录和设备配对机制。远程访问时建议只使用 tailnet 内部的 Tailscale Service，并配合 Tailscale ACL 限制可访问设备；不要用 Funnel 或公网反向代理直接公开 CodexFlow。

### 4. 验证 Agent 是否正常

```bash
curl http://127.0.0.1:4318/healthz
curl http://127.0.0.1:4318/api/v1/dashboard
```

如果正常，你会拿到健康检查结果和真实会话列表。

### 5. 在客户端里配置 Agent 地址

推荐填写规则：

- 同机调试：`http://127.0.0.1:4318`
- 局域网设备：`http://<宿主机局域网IP>:4318`
- Tailscale 设备：`https://<machine>.<tailnet>.ts.net`

补充说明：

- `Flutter Web / Chrome`：如果页面和 Agent 在同一台机器上，通常可直接使用 `http://127.0.0.1:4318`
- `Android 模拟器 / 真机`：不要填 `127.0.0.1`，要填宿主机局域网 IP 或 Tailscale 地址
- 当前 Agent 已加入浏览器跨域支持，Flutter Web 可以直接访问本地 Agent
- 如果 Android release APK 报 `ClientException with SocketException: Failed host lookup`，请确认 `android/app/src/main/AndroidManifest.xml` 声明了 `android.permission.INTERNET`

### 6. 给 AI 代理的部署提示词

如果你希望让 AI 直接帮你部署 release，可以把下面这段作为起点：

```text
请帮我部署 CodexFlow。目标是：
1. 使用 GitHub Release 里的 Windows host bundle
2. 在这台 Windows 机器上启动 codexflow-agent 和 bundled web
3. 如果机器安装了 Tailscale，就顺手配置 tailnet 内访问
4. 最后告诉我两个可直接填进 CodexFlow Settings > Agent Address 的地址：
   - LAN 地址
   - Tailscale 地址
5. 如果缺少 codex、python 或 tailscale，请明确指出缺什么
```

### 7. 运行 iOS App

用 Xcode 打开：

```text
ios/CodexFlow/CodexFlow.xcodeproj
```

然后运行 `CodexFlow` target。

### 8. 运行 Flutter App

Flutter 项目目录：

```text
flutter/codexflow
```

在该目录执行：

```bash
cd flutter/codexflow
flutter pub get
flutter run
```

如果要指定设备，例如：

```bash
flutter run -d chrome
flutter run -d emulator-5554
```

### 9. 运行 Web 版本

先构建 Web：

```bash
cd flutter/codexflow
flutter build web --release
```

构建产物目录：

```text
flutter/codexflow/build/web
```

本地运行最推荐直接用 Python：

```bash
cd flutter/codexflow/build/web
python3 -m http.server 8080
```

然后浏览器打开：

```text
http://127.0.0.1:8080
```

其他方式也可以，例如：

- `npx serve build/web`
- `busybox httpd`
- `Nginx / Caddy / Apache`
- 任意静态站点托管服务

### 10. 构建 release 资产

仓库内已经提供了 release 打包脚本：

```powershell
.\build_release_assets.ps1
```

它会产出：

- Windows host bundle zip
- Web 静态资源 zip
- Android APK
- `SHA256SUMS.txt`
- `release-notes.md`

产物目录：

```text
artifacts/release/vX.Y.Z/
```

如果你只想重打包，不想重新构建 APK 或 Web，可以用：

```powershell
.\build_release_assets.ps1 -SkipApk
.\build_release_assets.ps1 -SkipWeb
```

### 11. 发布到 GitHub Release

仓库内还提供了发布脚本：

```powershell
.\publish_github_release.ps1 -Tag vX.Y.Z
```

这个脚本会：

- 读取 `artifacts/release/vX.Y.Z/`
- 用 `release-notes.md` 作为 release body
- 创建 GitHub Release
- 上传 zip、apk、校验文件等资产

可用的凭据来源：

- `GITHUB_TOKEN`
- `GH_TOKEN`
- Git Credential Manager 中已经可用的 GitHub 凭据

## 基本使用方式

1. 打开 `会话` 页面，查看当前真实会话。
2. 对历史会话点击“接管到 CodexFlow”，将其转为受控会话。
3. 在受控会话详情页查看 plan、diff、timeline。
4. 在受控会话详情页发送下一轮 prompt，或 steer 当前执行中的 turn。
5. 对正在执行的 turn，可以直接 interrupt。
6. 打开 `Approvals` 页面，处理等待中的审批请求。
7. 对不再需要的会话，可以结束或归档。

补充说明：

- `Codex` 会话可以直接按 `已接管 / 已结束 / 历史会话` 理解。
- `Claude Code` 会话会进一步区分：
  - `可接管 Runtime`：当前本机还能接入 live runtime
  - `历史导入`：当前只发现 transcript，可查看历史
  - `已接管`：已经由 CodexFlow 托管

## API 概览

- `GET /healthz`
- `GET /api/v1/dashboard`
- `GET /api/v1/sessions`
- `POST /api/v1/sessions`
- `GET /api/v1/sessions/:id`
- `GET /api/v1/sessions/:id/context-window`
- `POST /api/v1/sessions/:id/resume`
- `POST /api/v1/sessions/:id/end`
- `POST /api/v1/sessions/:id/archive`
- `POST /api/v1/sessions/:id/turns/start`
- `POST /api/v1/sessions/:id/turns/steer`
- `POST /api/v1/sessions/:id/turns/interrupt`
- `GET /api/v1/approvals`
- `POST /api/v1/approvals/:id/resolve`
- `GET /api/v1/events`

## 仓库结构

```text
cmd/codexflow-agent        Go Agent 启动入口
internal/codex            Codex app-server 协议适配
internal/runtime          会话管理、统计、审批编排
internal/httpapi          HTTP API 与 SSE
internal/store            本地状态存储
ios/CodexFlow             iOS SwiftUI 客户端
flutter/codexflow         Flutter 跨平台客户端
docs                      架构与路线文档
assets                    README 截图资源
```

## 截图

### iOS

<table>
  <tr>
    <td><img src="assets/screenshot-01.jpeg" alt="Screenshot 01" width="240"></td>
    <td><img src="assets/screenshot-02.jpeg" alt="Screenshot 02" width="240"></td>
  </tr>
  <tr>
    <td><img src="assets/screenshot-03.jpeg" alt="Screenshot 03" width="240"></td>
    <td><img src="assets/screenshot-04.jpeg" alt="Screenshot 04" width="240"></td>
  </tr>
  <tr>
    <td><img src="assets/screenshot-05.jpeg" alt="Screenshot 05" width="240"></td>
    <td><img src="assets/screenshot-06.jpeg" alt="Screenshot 06" width="240"></td>
  </tr>
  <tr>
    <td><img src="assets/screenshot-07.jpeg" alt="Screenshot 07" width="240"></td>
    <td><img src="assets/screenshot-08.jpeg" alt="Screenshot 08" width="240"></td>
  </tr>
  <tr>
    <td><img src="assets/screenshot-09.jpeg" alt="Screenshot 09" width="240"></td>
    <td></td>
  </tr>
</table>

### Claude

<table>
  <tr>
    <td><img src="assets/screenshot_claude_01.jpeg" alt="Claude Screenshot 01" width="240"></td>
    <td><img src="assets/screenshot_claude_02.jpeg" alt="Claude Screenshot 02" width="240"></td>
  </tr>
</table>

### Android

<table>
  <tr>
    <td><img src="assets/screenshot_android_01.png" alt="Android Screenshot 01" width="240"></td>
    <td><img src="assets/screenshot_android_02.png" alt="Android Screenshot 02" width="240"></td>
  </tr>
</table>

### Web

<table>
  <tr>
    <td><img src="assets/screenshot_web_01.png" alt="Web Screenshot 01" width="240"></td>
    <td><img src="assets/screenshot_web_02.png" alt="Web Screenshot 02" width="240"></td>
  </tr>
</table>

## 说明

下一阶段计划：

- macOS Launcher
- 局域网外的安全 relay
- 推送通知
- 登录与设备配对
