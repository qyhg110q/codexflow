import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showComposer = false

  private let metricsColumns = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10)
  ]

  private var isConnected: Bool {
    model.isAgentOnline
  }

  private var selectedAgentID: String {
    model.selectedStartAgentID
  }

  private var filteredSessions: [SessionSummary] {
    model.dashboard.sessions.filter { $0.agentId == selectedAgentID }
  }

  private var filteredApprovals: [PendingRequestView] {
    let allowedSessionIDs = Set(filteredSessions.map(\.id))
    return model.dashboard.approvals.filter { allowedSessionIDs.contains($0.threadId) }
  }

  private var filteredStats: DashboardStats {
    var loaded = 0
    var active = 0
    for session in filteredSessions {
      if session.loaded {
        loaded += 1
      }
      if session.status == "active" && !session.ended {
        active += 1
      }
    }
    return DashboardStats(
      totalSessions: filteredSessions.count,
      loadedSessions: loaded,
      activeSessions: active,
      pendingApprovals: filteredApprovals.count
    )
  }

  private var continuableSessions: [SessionSummary] {
    filteredSessions
  }

  private var selectedAgentOption: AgentOption? {
    model.startAgentOptions.first { $0.id == model.selectedStartAgentID }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AtmosphereBackground()

        ScrollView {
          VStack(spacing: 12) {
            dashboardStatusRow
            metrics
            if !model.operationNotice.isEmpty {
              noticeBanner
            }
            if !isConnected && !model.agentConnectionError.isEmpty {
              connectionIssueBanner
            }
            if filteredStats.pendingApprovals > 0 {
              approvalsBanner
            }
            sessionSection
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
      }
      .navigationTitle("会话")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showComposer) {
        NewSessionSheet()
      }
      .refreshable {
        await model.refreshDashboard()
      }
    }
  }

  private var connectionIssueBanner: some View {
    Text(model.agentConnectionError)
      .font(.system(.caption, design: .rounded))
      .foregroundStyle(Palette.danger)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.danger.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var noticeBanner: some View {
    Text(model.operationNotice)
      .font(.system(.caption, design: .rounded))
      .foregroundStyle(model.operationNoticeIsError ? Palette.danger : Palette.success)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background((model.operationNoticeIsError ? Palette.danger : Palette.success).opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var dashboardStatusRow: some View {
    HStack {
      agentSwitchButton
      Spacer(minLength: 10)
      AgentStatusBadge(connected: isConnected)
    }
  }

  private var agentSwitchButton: some View {
    Menu {
      ForEach(model.startAgentOptions, id: \.id) { option in
        Button {
          model.setSelectedStartAgent(option.id)
        } label: {
          HStack {
            Text(option.name)
            if option.id == model.selectedStartAgentID {
              Image(systemName: "checkmark")
            }
          }
        }
        .disabled(!option.available)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "person.2.wave.2")
          .font(.system(size: 12, weight: .semibold))
        Text(selectedAgentOption?.name ?? "Codex")
          .font(.system(.caption, design: .rounded, weight: .semibold))
        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundStyle(Palette.ink)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.white.opacity(0.78))
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .stroke(Palette.line, lineWidth: 1)
      }
    }
  }

  private var createSessionButton: some View {
    Button {
      showComposer = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .bold))

        Text("新建")
          .font(.system(.caption, design: .rounded, weight: .bold))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Palette.softBlue)
      .clipShape(Capsule())
    }
  }

  private var metrics: some View {
    LazyVGrid(columns: metricsColumns, spacing: 10) {
      MetricCard(title: "总会话", value: "\(filteredStats.totalSessions)", tone: Palette.softBlue)
      MetricCard(title: "已加载", value: "\(filteredStats.loadedSessions)", tone: Palette.accent)
      MetricCard(title: "运行中", value: "\(filteredStats.activeSessions)", tone: Palette.accent2)
      MetricCard(title: "待审批", value: "\(filteredStats.pendingApprovals)", tone: Palette.warning)
    }
  }

  private var approvalsBanner: some View {
    PanelCard(compact: true) {
      HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(Palette.warning)

        Text("当前有 \(filteredStats.pendingApprovals) 个审批等待处理。")
          .font(.system(.footnote, design: .rounded, weight: .medium))
          .foregroundStyle(Palette.warning)
      }
    }
  }

  private var sessionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("列表")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(Palette.ink)

          Text("\(filteredSessions.count)")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(Palette.mutedInk)
        }

        Spacer()

        createSessionButton
      }

      if filteredSessions.isEmpty {
        PanelCard(compact: true) {
          Text("暂时没有会话。先确认 Agent 已连接，或者点上方“新建”。")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Palette.mutedInk)
        }
      } else {
        if !continuableSessions.isEmpty {
          sessionGroup(
            title: "可继续会话",
            helper: "打开任意会话即可查看历史并发送下一条 prompt。CodexFlow 会在后台准备 runtime。",
            sessions: continuableSessions
          )
        }
      }
    }
  }

  private func sessionGroup(title: String, helper: String, sessions: [SessionSummary]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(title)
          .font(.system(.subheadline, design: .rounded, weight: .semibold))
          .foregroundStyle(Palette.ink)

        Text("\(sessions.count)")
          .font(.system(.caption, design: .rounded, weight: .semibold))
          .foregroundStyle(Palette.mutedInk)
      }

      Text(helper)
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(Palette.mutedInk)

      ForEach(sessions) { session in
        SessionRow(session: session)
      }
    }
  }
}

private struct SessionRow: View {
  @EnvironmentObject private var model: AppModel
  let session: SessionSummary
  @State private var showDetail = false
  @State private var showApprovals = false

  private var sessionApprovals: [PendingRequestView] {
    model.approvals(for: session.id)
  }

  private var capabilities: AgentCapabilities {
    model.capabilities(for: session)
  }

  var body: some View {
    SessionCard(session: session, onOpen: {
      showDetail = true
    }) {
      VStack(spacing: 10) {
        HStack(spacing: 10) {
          NavigationLink {
            SessionDetailView(sessionID: session.id)
          } label: {
            rowButtonLabel(
              "查看并继续",
              background: Color.white,
              foreground: Palette.softBlue,
              border: Palette.softBlue.opacity(0.24)
            )
          }
          .buttonStyle(.plain)
        }

        if capabilities.supportsApprovals && session.pendingApprovals > 0 {
          Button {
            showApprovals = true
          } label: {
            rowButtonLabel(
              "快速处理审批 (\(session.pendingApprovals))",
              background: Palette.warning.opacity(0.14),
              foreground: Palette.warning,
              border: Palette.warning.opacity(0.22)
            )
          }
          .buttonStyle(.plain)
        }

        if capabilities.supportsArchive && (!session.loaded || session.isEnded) {
          Button {
            Task { await model.archiveSession(session) }
          } label: {
            rowButtonLabel(
              session.isEnded ? "归档已结束会话" : "从列表移除",
              background: Color.white,
              foreground: Palette.danger,
              border: Palette.danger.opacity(0.20)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationDestination(isPresented: $showDetail) {
      SessionDetailView(sessionID: session.id)
    }
    .sheet(isPresented: $showApprovals) {
      SessionApprovalSheet(title: session.displayName, approvals: sessionApprovals)
        .environmentObject(model)
    }
  }

  private func rowButtonLabel(_ title: String, background: Color, foreground: Color, border: Color) -> some View {
    Text(title)
      .font(.system(.caption, design: .rounded, weight: .semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 11)
      .background(background)
      .foregroundStyle(foreground)
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(border, lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

private struct NewSessionSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var cwd = ""
  @State private var prompt = ""
  @State private var isCreating = false
  @State private var submitError = ""
  @FocusState private var focusedField: NewSessionField?

  private var trimmedCWD: String {
    cwd.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedPrompt: String {
    prompt.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canCreate: Bool {
    !trimmedCWD.isEmpty && !trimmedPrompt.isEmpty
  }

  private var promptPlaceholder: String {
    "例如：继续实现剩余部分，并补上验证。"
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AtmosphereBackground()

        ScrollView {
          VStack(spacing: 12) {
            PanelCard {
              VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                  HStack {
                    Text("受控会话")
                      .font(.system(.caption2, design: .rounded, weight: .bold))
                      .foregroundStyle(Palette.softBlue)
                      .padding(.horizontal, 9)
                      .padding(.vertical, 6)
                      .background(Palette.softBlue.opacity(0.12))
                      .clipShape(Capsule())

                    Spacer()

                    Text("2 项必填")
                      .font(.system(.caption2, design: .rounded, weight: .bold))
                      .foregroundStyle(Palette.mutedInk)
                  }

                  Text("新建会话")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)

                  Text("填写目录和首条提示，CodexFlow 会立即建立一个可继续的会话。")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.mutedInk)
                }

                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text("工作目录")
                      .font(.system(.subheadline, design: .rounded, weight: .semibold))
                      .foregroundStyle(Palette.ink)

                    Spacer()

                    Text("绝对路径或 ~/repo")
                      .font(.system(.caption2, design: .rounded, weight: .medium))
                      .foregroundStyle(Palette.mutedInk)
                  }

                  TextField("/Users/hebicheng/workspace/aicoding-helper", text: $cwd)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .cwd)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(Palette.ink)
                    .tint(Palette.softBlue)
                    .padding(13)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(focusedField == .cwd ? Palette.softBlue.opacity(0.35) : Palette.line, lineWidth: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text("首条提示")
                      .font(.system(.subheadline, design: .rounded, weight: .semibold))
                      .foregroundStyle(Palette.ink)

                    Spacer()

                    Text(trimmedPrompt.isEmpty ? "未填写" : "\(trimmedPrompt.count) 字")
                      .font(.system(.caption2, design: .rounded, weight: .medium))
                      .foregroundStyle(trimmedPrompt.isEmpty ? Palette.mutedInk : Palette.softBlue)
                  }

                  ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                      .fill(Color.clear)
                      .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .stroke(focusedField == .prompt ? Palette.softBlue.opacity(0.35) : Palette.line, lineWidth: 1)
                      }

                    if trimmedPrompt.isEmpty {
                      Text(promptPlaceholder)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.mutedInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                    }

                    TextEditor(text: $prompt)
                      .frame(minHeight: 126)
                      .padding(.horizontal, 10)
                      .padding(.vertical, 8)
                      .scrollContentBackground(.hidden)
                      .background(Color.clear)
                      .focused($focusedField, equals: .prompt)
                      .foregroundColor(Palette.ink)
                      .tint(Palette.softBlue)
                  }
                }

                HStack(spacing: 8) {
                  Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.softBlue)

                  Text("支持 `~/...` 路径，创建后会立即出现在会话列表。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.mutedInk)
                }

                if !submitError.isEmpty {
                  Text(submitError)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                  guard !isCreating else { return }
                  focusedField = nil
                  Task {
                    isCreating = true
                    submitError = ""
                    if await model.startSession(cwd: trimmedCWD, prompt: trimmedPrompt, agentID: model.selectedStartAgentID) {
                      isCreating = false
                      dismiss()
                    } else {
                      isCreating = false
                      submitError = model.connectionError.isEmpty ? "创建会话失败，请检查 Agent 状态和输入内容。" : model.connectionError
                    }
                  }
                } label: {
                  HStack(spacing: 8) {
                    if isCreating {
                      ProgressView()
                        .tint(.white)
                    } else {
                      Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    }

                    Text(isCreating ? "创建中…" : "创建会话")
                      .font(.system(.subheadline, design: .rounded, weight: .semibold))
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 14)
                  .background(Palette.accent)
                  .foregroundStyle(.white)
                  .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canCreate || isCreating)
                .opacity((canCreate && !isCreating) ? 1 : 0.45)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 20)
          .contentShape(Rectangle())
          .onTapGesture {
            focusedField = nil
          }
        }
        .scrollDismissesKeyboard(.immediately)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("新建会话")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundColor(Palette.ink)
        }

        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") {
            dismiss()
          }
        }
      }
    }
  }
}

private enum NewSessionField: Hashable {
  case cwd
  case prompt
}
