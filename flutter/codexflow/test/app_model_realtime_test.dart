import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codexflow_flutter/models/app_models.dart';
import 'package:codexflow_flutter/services/api_client.dart';
import 'package:codexflow_flutter/state/app_model.dart';

void main() {
  test('merges completed agent message into live delta placeholder', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final model = AppModel(prefs);
    model.sessionDetails['thread-1'] = SessionDetail(
      summary: _summary(),
      turns: <TurnDetail>[_turn()],
    );

    model.applyRealtimeEvent(
      AgentEvent(
        type: 'turn.agentMessage.delta',
        payload: <String, dynamic>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'delta': 'hello',
        },
      ),
    );
    model.applyRealtimeEvent(
      AgentEvent(
        type: 'turn.item.completed',
        payload: <String, dynamic>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': <String, dynamic>{
            'id': 'item-1',
            'type': 'agentMessage',
            'text': 'hello',
            'status': 'completed',
          },
        },
      ),
    );

    final items = model.sessionDetails['thread-1']!.turns.single.items;
    expect(items, hasLength(1));
    expect(items.single.id, 'item-1');
    expect(items.single.body, 'hello');
  });

  test('keeps longer live delta text when item update is behind', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final model = AppModel(prefs);
    model.sessionDetails['thread-1'] = SessionDetail(
      summary: _summary(),
      turns: <TurnDetail>[_turn()],
    );

    model.applyRealtimeEvent(
      AgentEvent(
        type: 'turn.agentMessage.delta',
        payload: <String, dynamic>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'delta': 'hello world',
        },
      ),
    );
    model.applyRealtimeEvent(
      AgentEvent(
        type: 'turn.item.completed',
        payload: <String, dynamic>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': <String, dynamic>{
            'id': 'item-1',
            'type': 'agentMessage',
            'text': 'hello',
            'status': 'inProgress',
          },
        },
      ),
    );

    final items = model.sessionDetails['thread-1']!.turns.single.items;
    expect(items, hasLength(1));
    expect(items.single.id, 'item-1');
    expect(items.single.body, 'hello world');
  });

  test(
    'keeps live agent text and context usage when session snapshot is behind',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final model = AppModel(prefs);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      unawaited(
        server.forEach((request) async {
          request.response.headers.contentType = ContentType.json;
          if (request.method == 'GET' &&
              request.uri.path == '/api/v1/sessions/thread-1') {
            request.response.write(
              jsonEncode(
                _sessionDetailJson(
                  summary: _summaryJson(usedTokens: 1000),
                  turns: <dynamic>[],
                ),
              ),
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode(<String, Object>{'error': 'no'}));
          }
          await request.response.close();
        }),
      );

      model.baseUrlString = 'http://${server.address.host}:${server.port}';
      model.sessionDetails['thread-1'] = SessionDetail(
        summary: _summary(usedTokens: 2000),
        turns: <TurnDetail>[_turn()],
      );
      model.applyRealtimeEvent(
        AgentEvent(
          type: 'turn.agentMessage.delta',
          payload: <String, dynamic>{
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'delta': 'already visible',
          },
        ),
      );

      await model.loadSession('thread-1');
      await server.close(force: true);

      final detail = model.sessionDetails['thread-1']!;
      expect(detail.summary.contextWindowUsage.usedTokens, 2000);
      expect(detail.turns.single.items.single.body, 'already visible');
    },
  );

  test(
    'submit prompt returns after agent accepts message before refresh completes',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final model = AppModel(prefs);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dashboardGate = Completer<void>();
      var steerCount = 0;

      unawaited(
        server.forEach((request) async {
          request.response.headers.contentType = ContentType.json;
          if (request.method == 'POST' &&
              request.uri.path == '/api/v1/sessions/thread-1/turns/steer') {
            steerCount += 1;
            request.response.write(jsonEncode(<String, Object>{'ok': true}));
          } else if (request.method == 'GET' &&
              request.uri.path == '/api/v1/dashboard') {
            await dashboardGate.future;
            request.response.write(jsonEncode(_dashboardJson()));
          } else if (request.method == 'GET' &&
              request.uri.path == '/api/v1/sessions/thread-1') {
            request.response.write(jsonEncode(_sessionDetailJson()));
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode(<String, Object>{'error': 'no'}));
          }
          await request.response.close();
        }),
      );

      model.baseUrlString = 'http://${server.address.host}:${server.port}';
      final sent = await model
          .submitPrompt(session: _summary(), prompt: 'follow up')
          .timeout(const Duration(milliseconds: 250));

      expect(sent, isTrue);
      expect(steerCount, 1);

      dashboardGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await server.close(force: true);
    },
  );

  test('removes resolved approval from local dashboard immediately', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final model = AppModel(prefs);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var resolveCount = 0;

    unawaited(
      server.forEach((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/approvals/req-1/resolve') {
          resolveCount += 1;
          request.response.write(jsonEncode(<String, Object>{'ok': true}));
        } else if (request.method == 'GET' &&
            request.uri.path == '/api/v1/dashboard') {
          request.response.write(jsonEncode(_dashboardJson()));
        } else if (request.method == 'GET' &&
            request.uri.path == '/api/v1/sessions/thread-1') {
          request.response.write(jsonEncode(_sessionDetailJson()));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode(<String, Object>{'error': 'no'}));
        }
        await request.response.close();
      }),
    );

    model.baseUrlString = 'http://${server.address.host}:${server.port}';
    model.dashboard = DashboardResponse(
      agent: AgentSnapshot.fromJson(const <String, dynamic>{}),
      agents: const <AgentOption>[],
      defaultAgent: 'codex',
      stats: DashboardStats(
        totalSessions: 1,
        loadedSessions: 1,
        activeSessions: 1,
        pendingApprovals: 1,
      ),
      sessions: <SessionSummary>[_summary(pendingApprovals: 1)],
      approvals: <PendingRequestView>[
        PendingRequestView(
          id: 'req-1',
          method: 'item/commandExecution/requestApproval',
          kind: 'command',
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'item-1',
          reason: '',
          summary: 'git status',
          choices: const <String>['accept', 'decline'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          params: const <String, dynamic>{'command': 'git status'},
        ),
      ],
    );

    await model.resolve(
      approval: model.dashboard.approvals.single,
      action: ApprovalAction.choice('accept'),
    );
    await server.close(force: true);

    expect(resolveCount, 1);
    expect(model.dashboard.approvals, isEmpty);
    expect(model.dashboard.stats.pendingApprovals, 0);
    expect(model.dashboard.sessions.single.pendingApprovals, 0);
  });
}

SessionSummary _summary({int pendingApprovals = 0, int usedTokens = 0}) {
  final hasUsage = usedTokens > 0;
  return SessionSummary(
    id: 'thread-1',
    agentId: 'codex',
    name: '',
    preview: '',
    cwd: 'D:\\workspace',
    source: '',
    status: 'active',
    activeFlags: const <String>[],
    loaded: true,
    updatedAt: 0,
    createdAt: 0,
    modelProvider: '',
    branch: '',
    pendingApprovals: pendingApprovals,
    lastTurnId: 'turn-1',
    lastTurnStatus: 'inProgress',
    agentNickname: '',
    agentRole: '',
    lifecycleStage: 'managed',
    historyAvailable: true,
    runtimeAvailable: true,
    runtimeAttachMode: '',
    resumeAvailable: true,
    resumeBlockedReason: '',
    ended: false,
    contextWindowUsage: hasUsage
        ? ContextWindowUsage.fromJson(_contextUsageJson(usedTokens))
        : ContextWindowUsage.empty(),
  );
}

TurnDetail _turn() {
  return TurnDetail(
    id: 'turn-1',
    status: 'inProgress',
    startedAt: 0,
    completedAt: 0,
    durationMs: 0,
    error: '',
    diff: '',
    planExplanation: '',
    plan: const <PlanStep>[],
    items: const <TurnItem>[],
  );
}

Map<String, dynamic> _dashboardJson() {
  return <String, dynamic>{
    'agent': <String, dynamic>{},
    'agents': <dynamic>[],
    'defaultAgent': 'codex',
    'stats': <String, dynamic>{
      'totalSessions': 1,
      'loadedSessions': 1,
      'activeSessions': 1,
      'pendingApprovals': 0,
    },
    'sessions': <dynamic>[
      <String, dynamic>{
        'id': 'thread-1',
        'agentId': 'codex',
        'name': '',
        'preview': '',
        'cwd': 'D:\\workspace',
        'source': '',
        'status': 'active',
        'activeFlags': <dynamic>[],
        'loaded': true,
        'updatedAt': 0,
        'createdAt': 0,
        'modelProvider': '',
        'branch': '',
        'pendingApprovals': 0,
        'lastTurnId': 'turn-1',
        'lastTurnStatus': 'inProgress',
        'agentNickname': '',
        'agentRole': '',
        'lifecycleStage': 'managed',
        'historyAvailable': true,
        'runtimeAvailable': true,
        'runtimeAttachMode': '',
        'resumeAvailable': true,
        'resumeBlockedReason': '',
        'ended': false,
        'contextWindowUsage': <String, dynamic>{},
      },
    ],
    'approvals': <dynamic>[],
  };
}

Map<String, dynamic> _sessionDetailJson({
  Map<String, dynamic>? summary,
  List<dynamic>? turns,
}) {
  return <String, dynamic>{
    'summary': summary ?? _dashboardJson()['sessions'][0],
    'turns': turns ?? <dynamic>[],
  };
}

Map<String, dynamic> _summaryJson({int usedTokens = 0}) {
  final summary = Map<String, dynamic>.from(
    asMap(asList(_dashboardJson()['sessions']).single),
  );
  summary['contextWindowUsage'] = usedTokens > 0
      ? _contextUsageJson(usedTokens)
      : <String, dynamic>{};
  return summary;
}

Map<String, dynamic> _contextUsageJson(int usedTokens) {
  const contextWindow = 10000;
  return <String, dynamic>{
    'available': true,
    'usedTokens': usedTokens,
    'contextWindow': contextWindow,
    'remainingTokens': contextWindow - usedTokens,
    'ratio': usedTokens / contextWindow,
    'percent': (usedTokens / contextWindow * 100).round(),
    'lastTokenUsage': <String, dynamic>{},
    'totalTokenUsage': <String, dynamic>{'totalTokens': usedTokens},
    'updatedAt': '2026-05-13T00:00:00Z',
    'source': 'test',
  };
}
