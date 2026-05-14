import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codexflow_flutter/models/app_models.dart';
import 'package:codexflow_flutter/screens/dashboard_screen.dart';
import 'package:codexflow_flutter/state/app_model.dart';

void main() {
  testWidgets(
    'composer workspace follows the latest session cwd after first agent connect',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final model = _TestAppModel(prefs);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppModel>.value(
          value: model,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('不使用项目'), findsOneWidget);

      model.replaceDashboardForTest(
        _dashboardWithSessions(<SessionSummary>[
          _session(
            id: 'session-a',
            cwd: r'D:\connected\latest-workspace',
            updatedAt: 200,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('latest-workspace'), findsOneWidget);
      expect(find.text('不使用项目'), findsNothing);
    },
  );

  testWidgets(
    'composer workspace resets to the latest session cwd after agent endpoint switch',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final model = _TestAppModel(prefs);

      model.replaceDashboardForTest(
        _dashboardWithSessions(<SessionSummary>[
          _session(
            id: 'session-a',
            cwd: r'D:\agent-a\workspace-one',
            updatedAt: 200,
          ),
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppModel>.value(
          value: model,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('workspace-one'), findsOneWidget);

      model.replaceScopeForTest(
        endpointId: 'remote-agent',
        dashboard: _dashboardWithSessions(<SessionSummary>[
          _session(
            id: 'session-b',
            cwd: r'D:\agent-b\workspace-two',
            updatedAt: 300,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('workspace-two'), findsOneWidget);
      expect(find.text('workspace-one'), findsNothing);
    },
  );

  testWidgets(
    'composer recent workspace only follows the selected start agent',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final model = _TestAppModel(prefs);

      model.replaceDashboardForTest(
        _dashboardWithSessions(<SessionSummary>[
          _session(
            id: 'codex-session',
            agentId: 'codex',
            cwd: r'D:\codex\codex-space',
            updatedAt: 300,
          ),
          _session(
            id: 'claude-session',
            agentId: 'claude',
            cwd: r'D:\claude\claude-space',
            updatedAt: 400,
          ),
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppModel>.value(
          value: model,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('codex-space'), findsOneWidget);
      expect(find.text('claude-space'), findsNothing);

      model.setSelectedStartAgent('claude');
      await tester.pumpAndSettle();

      expect(find.text('claude-space'), findsOneWidget);
      expect(find.text('codex-space'), findsNothing);
    },
  );
}

class _TestAppModel extends AppModel {
  _TestAppModel(super.prefs);

  void replaceDashboardForTest(DashboardResponse dashboardValue) {
    dashboard = dashboardValue;
    notifyListeners();
  }

  void replaceScopeForTest({
    required String endpointId,
    required DashboardResponse dashboard,
  }) {
    selectedAgentEndpointId = endpointId;
    this.dashboard = dashboard;
    notifyListeners();
  }
}

DashboardResponse _dashboardWithSessions(List<SessionSummary> sessions) {
  return DashboardResponse(
    agent: AgentSnapshot(
      connected: true,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0),
      listenAddr: '127.0.0.1:4318',
      codexBinaryPath: 'codex',
    ),
    agents: <AgentOption>[
      AgentOption(
        id: 'codex',
        name: 'Codex',
        available: true,
        isDefault: true,
        capabilities: _capabilities(),
      ),
      AgentOption(
        id: 'claude',
        name: 'Claude Code',
        available: true,
        isDefault: false,
        capabilities: _capabilities(historyImport: true),
      ),
    ],
    defaultAgent: 'codex',
    stats: DashboardStats(
      totalSessions: sessions.length,
      loadedSessions: sessions.length,
      activeSessions: sessions.where((session) => session.isActive).length,
      pendingApprovals: 0,
    ),
    sessions: sessions,
    approvals: const <PendingRequestView>[],
  );
}

SessionSummary _session({
  required String id,
  String agentId = 'codex',
  required String cwd,
  required int updatedAt,
}) {
  return SessionSummary(
    id: id,
    agentId: agentId,
    name: '',
    preview: 'test',
    cwd: cwd,
    source: 'codex',
    status: 'active',
    activeFlags: const <String>[],
    loaded: true,
    updatedAt: updatedAt,
    createdAt: updatedAt,
    modelProvider: 'GPT-5.4',
    branch: '',
    pendingApprovals: 0,
    lastTurnId: '',
    lastTurnStatus: '',
    agentNickname: '',
    agentRole: '',
    lifecycleStage: 'managed',
    historyAvailable: false,
    runtimeAvailable: true,
    runtimeAttachMode: '',
    resumeAvailable: true,
    resumeBlockedReason: '',
    ended: false,
    contextWindowUsage: ContextWindowUsage.empty(),
  );
}

AgentCapabilities _capabilities({bool historyImport = false}) {
  return AgentCapabilities(
    supportsInterruptTurn: true,
    supportsApprovals: true,
    supportsArchive: true,
    supportsResume: true,
    supportsHistoryImport: historyImport,
  );
}
