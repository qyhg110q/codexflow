import SwiftUI

struct SessionCard<Actions: View>: View {
  let session: SessionSummary
  let onOpen: (() -> Void)?
  let actions: Actions

  init(session: SessionSummary, onOpen: (() -> Void)? = nil, @ViewBuilder actions: () -> Actions) {
    self.session = session
    self.onOpen = onOpen
    self.actions = actions()
  }

  var body: some View {
    PanelCard(compact: true) {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
              Text(session.displayName)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

              Text(session.cwd)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.mutedInk)
                .lineLimit(1)
                .truncationMode(.middle)

              Text("更新 \(session.updatedAtDisplay)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.mutedInk)
            }

            Spacer()

            StatusPill(status: session.status, waiting: session.hasWaitingState, ended: session.isEnded)
          }

          if !previewText.isEmpty {
            Text(previewText)
              .font(.system(.footnote, design: .rounded))
              .foregroundStyle(Palette.mutedInk)
              .lineLimit(2)
          }

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              CapsuleTag(title: "托管", value: session.loaded ? "已接管" : "未接管")
              if session.isClaudeSession {
                CapsuleTag(title: "链路", value: session.runtimeAvailable ? "Runtime" : "History")
                if session.loaded && !session.runtimeAttachMode.isEmpty {
                  CapsuleTag(title: "接管", value: session.runtimeAttachMode == "resumed_existing" ? "现有 Runtime" : (session.runtimeAttachMode == "opened_from_history" ? "历史新开" : "新建 Runtime"))
                }
              }
              CapsuleTag(title: "来源", value: session.source)
              CapsuleTag(title: "分支", value: session.branch.isEmpty ? "未识别" : session.branch)
              if !session.lastTurnStatus.isEmpty {
                CapsuleTag(title: "最近一轮", value: lastTurnStatusLabel)
              }
            }
          }

        }
        .contentShape(Rectangle())
        .onTapGesture {
          onOpen?()
        }

        Rectangle()
          .fill(Palette.line)
          .frame(height: 1)

        actions
      }
    }
  }

  private var previewText: String {
    session.previewSummary
  }

  private var lastTurnStatusLabel: String {
    switch session.lastTurnStatus {
    case "inProgress":
      return "运行中"
    case "completed":
      return "已完成"
    case "failed":
      return "失败"
    default:
      return session.lastTurnStatus
    }
  }

}
