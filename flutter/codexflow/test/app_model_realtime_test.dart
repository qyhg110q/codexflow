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
}

SessionSummary _summary() {
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
    pendingApprovals: 0,
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
    contextWindowUsage: ContextWindowUsage.empty(),
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
