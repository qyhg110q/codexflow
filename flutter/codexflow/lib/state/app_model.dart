import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';

enum ApprovalActionType { choice, decision, submitText }

class AgentEndpoint {
  const AgentEndpoint({
    required this.id,
    required this.name,
    required this.url,
  });

  final String id;
  final String name;
  final String url;

  AgentEndpoint copyWith({String? name, String? url}) {
    return AgentEndpoint(id: id, name: name ?? this.name, url: url ?? this.url);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name, 'url': url};
  }

  factory AgentEndpoint.fromJson(Map<String, dynamic> json) {
    return AgentEndpoint(
      id: asString(json['id']),
      name: asString(json['name']),
      url: asString(json['url']),
    );
  }
}

class ApprovalAction {
  ApprovalAction.choice(this.value) : type = ApprovalActionType.choice;

  ApprovalAction.decision(this.value) : type = ApprovalActionType.decision;

  ApprovalAction.submitText(this.value) : type = ApprovalActionType.submitText;

  final ApprovalActionType type;
  final Object? value;

  String get freeformText => value is String ? value as String : '';

  String get choiceValue {
    switch (type) {
      case ApprovalActionType.choice:
        return asString(value);
      case ApprovalActionType.decision:
        return value is String ? value as String : 'accept';
      case ApprovalActionType.submitText:
        return 'accept';
    }
  }

  Object? get decisionValue => value;
}

class AppModel extends ChangeNotifier {
  AppModel(this._prefs)
    : agentEndpoints = _loadAgentEndpoints(_prefs),
      selectedAgentEndpointId = _loadSelectedAgentEndpointId(_prefs),
      baseUrlString = _loadBaseUrl(_prefs),
      defaultExecutionPolicy =
          _prefs.getString(_defaultExecutionPolicyKey) ?? 'review',
      defaultModel = _prefs.getString(_defaultModelKey) ?? 'GPT-5.4',
      defaultReasoning = _prefs.getString(_defaultReasoningKey) ?? 'medium',
      defaultSpeed = _prefs.getString(_defaultSpeedKey) ?? 'standard',
      languageCode =
          AppLocalizations.isSupported(_prefs.getString(_languageCodeKey) ?? '')
          ? _prefs.getString(_languageCodeKey)!
          : AppLocalizations.defaultCode,
      localMode = _prefs.getBool(_localModeKey) ?? true;

  static const _baseUrlKey = 'codexflow.baseURL';
  static const _agentEndpointsKey = 'codexflow.agentEndpoints';
  static const _selectedAgentEndpointKey = 'codexflow.selectedAgentEndpoint';
  static const _defaultAgentEndpointId = 'local-agent';
  static const _defaultAgentEndpointUrl = 'http://127.0.0.1:4318';
  static const _defaultExecutionPolicyKey = 'codexflow.defaultPolicy';
  static const _defaultModelKey = 'codexflow.defaultModel';
  static const _defaultReasoningKey = 'codexflow.defaultReasoning';
  static const _defaultSpeedKey = 'codexflow.defaultSpeed';
  static const _languageCodeKey = 'codexflow.languageCode';
  static const _localModeKey = 'codexflow.localMode';

  final SharedPreferences _prefs;

  List<AgentEndpoint> agentEndpoints;
  String selectedAgentEndpointId;
  String baseUrlString;
  String defaultExecutionPolicy;
  String defaultModel;
  String defaultReasoning;
  String defaultSpeed;
  String languageCode;
  bool localMode;
  DashboardResponse dashboard = DashboardResponse.placeholder();
  final Map<String, SessionDetail> sessionDetails = <String, SessionDetail>{};
  bool isRefreshing = false;
  bool isBootstrapped = false;
  bool isAgentOnline = false;
  bool isAgentConnecting = false;
  String agentConnectionError = '';
  String connectionError = '';
  String operationNotice = '';
  bool operationNoticeIsError = false;
  String composerDraft = '';
  String selectedStartAgentId = 'codex';
  int _consecutiveDashboardFailures = 0;
  int _connectionGeneration = 0;
  Timer? _noticeTimer;

  ApiClient _client() => ApiClient(baseUrlString: baseUrlString);

  static List<AgentEndpoint> _loadAgentEndpoints(SharedPreferences prefs) {
    final encoded = prefs.getString(_agentEndpointsKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        final parsed = asList(decoded)
            .map((item) => AgentEndpoint.fromJson(asMap(item)))
            .where((item) => item.id.isNotEmpty && item.url.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) {
          return _dedupeAgentEndpoints(parsed);
        }
      } catch (_) {}
    }

    final legacyUrl = prefs.getString(_baseUrlKey) ?? _defaultAgentEndpointUrl;
    return <AgentEndpoint>[
      AgentEndpoint(
        id: _defaultAgentEndpointId,
        name: '本机 Agent',
        url: _normalizeAgentEndpointUrl(legacyUrl),
      ),
    ];
  }

  static List<AgentEndpoint> _dedupeAgentEndpoints(
    List<AgentEndpoint> endpoints,
  ) {
    final seen = <String>{};
    final deduped = <AgentEndpoint>[];
    for (final endpoint in endpoints) {
      final id = endpoint.id.trim();
      final name = endpoint.name.trim();
      final url = _normalizeAgentEndpointUrl(endpoint.url);
      if (id.isEmpty || url.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      deduped.add(
        AgentEndpoint(
          id: id,
          name: name.isEmpty ? 'Agent ${deduped.length + 1}' : name,
          url: url,
        ),
      );
    }
    return deduped.isEmpty
        ? const <AgentEndpoint>[
            AgentEndpoint(
              id: _defaultAgentEndpointId,
              name: '本机 Agent',
              url: _defaultAgentEndpointUrl,
            ),
          ]
        : deduped;
  }

  static String _loadSelectedAgentEndpointId(SharedPreferences prefs) {
    final endpoints = _loadAgentEndpoints(prefs);
    final selected = prefs.getString(_selectedAgentEndpointKey) ?? '';
    if (endpoints.any((item) => item.id == selected)) {
      return selected;
    }
    return endpoints.first.id;
  }

  static String _loadBaseUrl(SharedPreferences prefs) {
    final endpoints = _loadAgentEndpoints(prefs);
    final selectedId = _loadSelectedAgentEndpointId(prefs);
    for (final endpoint in endpoints) {
      if (endpoint.id == selectedId) {
        return endpoint.url;
      }
    }
    return endpoints.first.url;
  }

  static String _normalizeAgentEndpointUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
    return hasScheme ? trimmed : 'http://$trimmed';
  }

  Future<void> bootstrap() async {
    if (isBootstrapped) {
      return;
    }
    isBootstrapped = true;
    notifyListeners();
    await refreshDashboard();
  }

  void updateBaseUrlString(String value) {
    baseUrlString = value;
    notifyListeners();
  }

  Future<void> saveBaseUrl() async {
    await _prefs.setString(_baseUrlKey, baseUrlString);
  }

  AgentEndpoint get selectedAgentEndpoint {
    for (final endpoint in agentEndpoints) {
      if (endpoint.id == selectedAgentEndpointId) {
        return endpoint;
      }
    }
    return agentEndpoints.first;
  }

  bool isSelectedAgentEndpoint(String id) {
    return selectedAgentEndpointId == id;
  }

  Future<void> addAgentEndpoint({
    required String name,
    required String url,
  }) async {
    final endpoint = AgentEndpoint(
      id: _newAgentEndpointId(),
      name: _normalizedAgentEndpointName(name),
      url: _normalizeAgentEndpointUrl(url),
    );
    agentEndpoints = <AgentEndpoint>[...agentEndpoints, endpoint];
    await _selectAgentEndpoint(endpoint.id, refresh: true);
  }

  Future<void> updateAgentEndpoint({
    required String id,
    required String name,
    required String url,
  }) async {
    final normalizedUrl = _normalizeAgentEndpointUrl(url);
    final updated = agentEndpoints
        .map(
          (endpoint) => endpoint.id == id
              ? endpoint.copyWith(
                  name: _normalizedAgentEndpointName(name),
                  url: normalizedUrl,
                )
              : endpoint,
        )
        .toList();
    agentEndpoints = _dedupeAgentEndpoints(updated);
    await _saveAgentEndpoints();
    if (selectedAgentEndpointId == id) {
      baseUrlString = normalizedUrl;
      await saveBaseUrl();
      _markAgentConnecting();
      notifyListeners();
      await refreshDashboard(force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> deleteAgentEndpoint(String id) async {
    if (agentEndpoints.length <= 1) {
      agentEndpoints = const <AgentEndpoint>[
        AgentEndpoint(
          id: _defaultAgentEndpointId,
          name: '本机 Agent',
          url: _defaultAgentEndpointUrl,
        ),
      ];
      await _selectAgentEndpoint(_defaultAgentEndpointId, refresh: true);
      return;
    }

    final remaining = agentEndpoints
        .where((endpoint) => endpoint.id != id)
        .toList();
    if (remaining.length == agentEndpoints.length) {
      return;
    }
    agentEndpoints = remaining;

    if (selectedAgentEndpointId == id) {
      await _selectAgentEndpoint(remaining.first.id, refresh: true);
      return;
    }

    await _saveAgentEndpoints();
    notifyListeners();
  }

  Future<void> selectAgentEndpoint(String id) async {
    await _selectAgentEndpoint(id, refresh: true);
  }

  Future<void> _selectAgentEndpoint(String id, {required bool refresh}) async {
    AgentEndpoint? endpoint;
    for (final candidate in agentEndpoints) {
      if (candidate.id == id) {
        endpoint = candidate;
        break;
      }
    }
    if (endpoint == null) {
      return;
    }

    selectedAgentEndpointId = endpoint.id;
    baseUrlString = endpoint.url;
    _markAgentConnecting();
    await _saveAgentEndpoints();
    await _prefs.setString(_selectedAgentEndpointKey, selectedAgentEndpointId);
    await saveBaseUrl();
    notifyListeners();

    if (refresh) {
      await refreshDashboard(force: true);
    }
  }

  void _markAgentConnecting() {
    _connectionGeneration += 1;
    isAgentOnline = false;
    isAgentConnecting = true;
    agentConnectionError = '';
    connectionError = '';
    _consecutiveDashboardFailures = 0;
  }

  Future<void> _saveAgentEndpoints() async {
    await _prefs.setString(
      _agentEndpointsKey,
      jsonEncode(agentEndpoints.map((endpoint) => endpoint.toJson()).toList()),
    );
  }

  String _newAgentEndpointId() {
    return 'agent-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _normalizedAgentEndpointName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Agent ${agentEndpoints.length + 1}' : trimmed;
  }

  Future<void> updateDefaultExecutionPolicy(String value) async {
    defaultExecutionPolicy = value;
    await _prefs.setString(_defaultExecutionPolicyKey, value);
    notifyListeners();
  }

  Future<void> updateDefaultModel(String value) async {
    defaultModel = value;
    await _prefs.setString(_defaultModelKey, value);
    notifyListeners();
  }

  Future<void> updateDefaultReasoning(String value) async {
    defaultReasoning = value;
    await _prefs.setString(_defaultReasoningKey, value);
    notifyListeners();
  }

  Future<void> updateDefaultSpeed(String value) async {
    defaultSpeed = value;
    await _prefs.setString(_defaultSpeedKey, value);
    notifyListeners();
  }

  Future<void> updateLanguageCode(String value) async {
    if (!AppLocalizations.isSupported(value)) {
      return;
    }
    languageCode = value;
    await _prefs.setString(_languageCodeKey, value);
    notifyListeners();
  }

  Future<void> updateLocalMode(bool value) async {
    localMode = value;
    await _prefs.setBool(_localModeKey, value);
    notifyListeners();
  }

  Future<void> refreshDashboard({bool force = false}) async {
    if (isRefreshing && !force) {
      return;
    }
    final requestGeneration = _connectionGeneration;
    final requestBaseUrl = baseUrlString;
    isRefreshing = true;
    notifyListeners();

    try {
      final latestDashboard = await ApiClient(
        baseUrlString: requestBaseUrl,
      ).dashboard();
      if (!_isCurrentRefresh(requestGeneration, requestBaseUrl)) {
        return;
      }
      dashboard = latestDashboard;
      _syncSelectedAgent(latestDashboard);
      _consecutiveDashboardFailures = 0;
      isAgentOnline = latestDashboard.agent.connected;
      isAgentConnecting = false;
      agentConnectionError = '';
    } catch (error) {
      if (!_isCurrentRefresh(requestGeneration, requestBaseUrl)) {
        return;
      }
      _consecutiveDashboardFailures += 1;
      if (_consecutiveDashboardFailures >= 2 || !isAgentOnline) {
        isAgentOnline = false;
        isAgentConnecting = false;
        agentConnectionError = error.toString();
      }
    } finally {
      if (_isCurrentRefresh(requestGeneration, requestBaseUrl)) {
        isRefreshing = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRefresh(int requestGeneration, String requestBaseUrl) {
    return requestGeneration == _connectionGeneration &&
        requestBaseUrl == baseUrlString;
  }

  List<PendingRequestView> approvalsFor(String sessionId) {
    if (!supportsApprovalsForSessionId(sessionId)) {
      return <PendingRequestView>[];
    }
    final approvals =
        dashboard.approvals.where((item) => item.threadId == sessionId).toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return approvals;
  }

  Future<void> loadSession(String id) async {
    try {
      final detail = await _client().sessionDetail(id);
      sessionDetails[id] = detail;
      connectionError = '';
      notifyListeners();
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
    }
  }

  bool applyRealtimeEvent(AgentEvent event) {
    switch (event.type) {
      case 'turn.agentMessage.delta':
        return _appendAgentMessageDelta(
          threadId: asString(event.payload['threadId']),
          turnId: asString(event.payload['turnId']),
          itemId: asString(event.payload['itemId']),
          delta: asString(event.payload['delta']),
        );
      case 'turn.agentMessage.updated':
        return _upsertAgentMessageText(
          threadId: asString(event.payload['threadId']),
          turnId: asString(event.payload['turnId']),
          itemId: asString(event.payload['itemId']),
          text: asString(event.payload['text']),
        );
      case 'turn.item.started':
      case 'turn.item.completed':
      case 'turn.item.updated':
        return _upsertRealtimeTurnItem(
          threadId: asString(event.payload['threadId']),
          turnId: asString(event.payload['turnId']),
          rawItem: asMap(event.payload['item']),
        );
      case 'turn.plan.updated':
        return _updateTurnPlan(event.payload);
      case 'turn.started':
      case 'turn.completed':
        return _updateTurnStatus(event.type, event.payload);
      default:
        return false;
    }
  }

  bool _appendAgentMessageDelta({
    required String threadId,
    required String turnId,
    required String itemId,
    required String delta,
  }) {
    if (threadId.isEmpty || turnId.isEmpty || delta.isEmpty) {
      return false;
    }

    final changed = _mutateTurn(threadId, turnId, (turn) {
      final items = <TurnItem>[...turn.items];
      var targetIndex = -1;
      if (itemId.isNotEmpty) {
        targetIndex = items.indexWhere((item) => item.id == itemId);
      }
      if (targetIndex < 0) {
        for (var idx = items.length - 1; idx >= 0; idx -= 1) {
          if (items[idx].type == 'agentMessage') {
            targetIndex = idx;
            break;
          }
        }
      }
      if (targetIndex < 0) {
        items.add(
          TurnItem(
            id: itemId.isEmpty ? '$turnId-agent-live' : itemId,
            type: 'agentMessage',
            title: 'Agent',
            body: delta,
            status: 'inProgress',
            auxiliary: '',
            metadata: const <String, String>{},
          ),
        );
      } else {
        final current = items[targetIndex];
        items[targetIndex] = current.copyWith(
          id: current.id.isEmpty ? itemId : current.id,
          type: 'agentMessage',
          title: current.title.isEmpty ? 'Agent' : current.title,
          body: current.body + delta,
          status: current.status.isEmpty ? 'inProgress' : current.status,
        );
      }
      return turn.copyWith(status: 'inProgress', items: items);
    });

    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool _upsertAgentMessageText({
    required String threadId,
    required String turnId,
    required String itemId,
    required String text,
  }) {
    if (threadId.isEmpty || turnId.isEmpty || text.trim().isEmpty) {
      return false;
    }

    final changed = _upsertRealtimeTurnItem(
      threadId: threadId,
      turnId: turnId,
      rawItem: <String, dynamic>{
        'id': itemId.isEmpty ? '$turnId-agent-live' : itemId,
        'type': 'agentMessage',
        'text': text,
        'status': 'inProgress',
      },
      notify: false,
    );
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool _upsertRealtimeTurnItem({
    required String threadId,
    required String turnId,
    required Map<String, dynamic> rawItem,
    bool notify = true,
  }) {
    if (threadId.isEmpty || turnId.isEmpty || rawItem.isEmpty) {
      return false;
    }

    final incoming = _turnItemFromRuntimeItem(rawItem);
    if (incoming == null) {
      return false;
    }

    final changed = _mutateTurn(threadId, turnId, (turn) {
      final items = <TurnItem>[...turn.items];
      final itemId = incoming.id.trim();
      var targetIndex = -1;
      if (itemId.isNotEmpty) {
        targetIndex = items.indexWhere((item) => item.id == itemId);
      }
      if (targetIndex < 0 && incoming.type == 'agentMessage') {
        targetIndex = _liveAgentMessageIndex(items, turnId);
      }
      if (targetIndex < 0) {
        items.add(incoming);
      } else {
        final current = items[targetIndex];
        if (incoming.type == 'agentMessage' &&
            current.type == 'agentMessage' &&
            current.body.length > incoming.body.length) {
          items[targetIndex] = current.copyWith(
            id: incoming.id.isEmpty ? current.id : incoming.id,
            status: incoming.status.isEmpty ? current.status : incoming.status,
          );
        } else {
          items[targetIndex] = incoming;
        }
      }
      return turn.copyWith(status: 'inProgress', items: items);
    });

    if (changed && notify) {
      notifyListeners();
    }
    return changed;
  }

  int _liveAgentMessageIndex(List<TurnItem> items, String turnId) {
    final liveId = '$turnId-agent-live';
    for (var idx = items.length - 1; idx >= 0; idx -= 1) {
      final item = items[idx];
      if (item.type != 'agentMessage') {
        continue;
      }
      if (item.id.isEmpty ||
          item.id == liveId ||
          item.id.endsWith('-agent-live')) {
        return idx;
      }
    }
    return -1;
  }

  bool _updateTurnPlan(Map<String, dynamic> payload) {
    final threadId = asString(payload['threadId']);
    final turnId = asString(payload['turnId']);
    if (threadId.isEmpty || turnId.isEmpty) {
      return false;
    }

    final plan = asList(payload['plan'])
        .map((item) => PlanStep.fromJson(asMap(item)))
        .where((step) => step.step.trim().isNotEmpty)
        .toList();
    final explanation = asString(payload['explanation']);
    final changed = _mutateTurn(threadId, turnId, (turn) {
      return turn.copyWith(
        status: 'inProgress',
        planExplanation: explanation,
        plan: plan,
      );
    });
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  bool _updateTurnStatus(String eventType, Map<String, dynamic> payload) {
    final threadId = asString(payload['threadId']);
    final turnId = asString(payload['turnId']);
    if (threadId.isEmpty || turnId.isEmpty) {
      return false;
    }

    var status = asString(payload['status']);
    if (status.isEmpty) {
      final turn = asMap(payload['turn']);
      status = asString(turn['status']);
    }
    if (status.isEmpty && payload.containsKey('turnId')) {
      status = _eventStatusFromType(eventType);
    }
    if (status.isEmpty) {
      status = 'inProgress';
    }

    final changed = _mutateTurn(threadId, turnId, (turn) {
      return turn.copyWith(status: status);
    });
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  String _eventStatusFromType(String value) {
    return value == 'turn.completed' ? 'completed' : 'inProgress';
  }

  bool _mutateTurn(
    String threadId,
    String turnId,
    TurnDetail Function(TurnDetail turn) mutate,
  ) {
    final detail = sessionDetails[threadId];
    if (detail == null) {
      return false;
    }

    final turns = <TurnDetail>[...detail.turns];
    var index = turns.indexWhere((turn) => turn.id == turnId);
    if (index < 0) {
      turns.add(
        TurnDetail(
          id: turnId,
          status: 'inProgress',
          startedAt: 0,
          completedAt: 0,
          durationMs: 0,
          error: '',
          diff: '',
          planExplanation: '',
          plan: const <PlanStep>[],
          items: const <TurnItem>[],
        ),
      );
      index = turns.length - 1;
    }

    turns[index] = mutate(turns[index]);
    sessionDetails[threadId] = detail.copyWith(turns: turns);
    return true;
  }

  TurnItem? _turnItemFromRuntimeItem(Map<String, dynamic> item) {
    final type = asString(item['type']);
    final id = asString(item['id']);
    final status = asString(item['status']);
    final metadata = <String, String>{};
    switch (type) {
      case 'userMessage':
        final body = _firstUserText(item);
        if (body.isEmpty) {
          return null;
        }
        return TurnItem(
          id: id,
          type: type,
          title: 'User Prompt',
          body: body,
          status: status,
          auxiliary: '',
          metadata: metadata,
        );
      case 'agentMessage':
        final body = asString(item['text']);
        if (body.trim().isEmpty) {
          return null;
        }
        return TurnItem(
          id: id,
          type: type,
          title: 'Agent',
          body: body,
          status: status,
          auxiliary: '',
          metadata: metadata,
        );
      case 'reasoning':
        final body = asList(
          item['summary'],
        ).map((part) => asString(part)).join('\n');
        if (body.trim().isEmpty) {
          return null;
        }
        return TurnItem(
          id: id,
          type: type,
          title: 'Reasoning',
          body: body,
          status: status,
          auxiliary: '',
          metadata: metadata,
        );
      case 'commandExecution':
        metadata['cwd'] = asString(item['cwd']);
        return TurnItem(
          id: id,
          type: type,
          title: 'Command',
          body: asString(item['command']),
          status: status,
          auxiliary: asString(item['aggregatedOutput']),
          metadata: metadata,
        );
      case 'fileChange':
        return TurnItem(
          id: id,
          type: type,
          title: 'File Change',
          body: '文件变更',
          status: status,
          auxiliary: '',
          metadata: metadata,
        );
      case 'dynamicToolCall':
        metadata['tool'] = asString(item['tool']);
        metadata['progress'] = asString(item['progress']);
        return TurnItem(
          id: id,
          type: type,
          title: asString(item['title'], 'Tool Call'),
          body: asString(
            item['summary'],
            '${item['namespace']}:${item['tool']}',
          ),
          status: status,
          auxiliary: asString(item['result']),
          metadata: metadata,
        );
      case 'collabAgentToolCall':
        metadata['title'] = asString(item['title']);
        return TurnItem(
          id: id,
          type: type,
          title: 'Delegation',
          body: asString(item['prompt']),
          status: status,
          auxiliary: asString(item['result']),
          metadata: metadata,
        );
      default:
        final body = asString(item['summary'], asString(item['result']));
        if (type.isEmpty || body.trim().isEmpty) {
          return null;
        }
        return TurnItem(
          id: id,
          type: type,
          title: type,
          body: body,
          status: status,
          auxiliary: '',
          metadata: metadata,
        );
    }
  }

  String _firstUserText(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final entry in asList(item['content'])) {
      final content = asMap(entry);
      if (asString(content['type']) == 'text') {
        final text = asString(content['text']).trim();
        if (text.isNotEmpty) {
          parts.add(text);
        }
      }
    }
    return parts.join('\n');
  }

  Future<SessionSummary?> startSession({
    required String cwd,
    required String prompt,
    required String agentId,
  }) async {
    try {
      final createdSession = await _client().startSession(
        cwd: cwd.trim(),
        prompt: prompt.trim(),
        agentId: agentId.trim().toLowerCase(),
      );
      _upsertSessionSummary(createdSession);
      connectionError = '';
      showNotice('会话已创建。');
      unawaited(_refreshCreatedSession(createdSession.id));
      return createdSession;
    } catch (error) {
      connectionError = error.toString();
      showNotice('创建会话失败：${error.toString()}', isError: true);
      notifyListeners();
      return null;
    }
  }

  Future<void> _refreshCreatedSession(String sessionId) async {
    await refreshDashboard();
    await loadSession(sessionId);
  }

  Future<void> resumeSession(SessionSummary session) async {
    if (!canResumeSession(session)) {
      final message = session.resumeBlockedReason.isNotEmpty
          ? session.resumeBlockedReason
          : '这个会话当前不能重新接管。';
      connectionError = message;
      showNotice(message, isError: true);
      notifyListeners();
      return;
    }
    try {
      final updatedSession = await _client().resumeSession(session.id);
      _upsertSessionSummary(updatedSession);
      connectionError = '';
      showNotice(_resumeSuccessNotice(updatedSession));
      await refreshDashboard();
      await loadSession(session.id);
    } catch (error) {
      connectionError = error.toString();
      showNotice('接管失败：${error.toString()}', isError: true);
      notifyListeners();
    }
  }

  Future<SessionSummary?> branchSession({
    required SessionSummary session,
    required String turnId,
  }) async {
    if (session.isClaudeSession) {
      const message = 'Claude 会话暂不支持分支。';
      connectionError = message;
      showNotice(message, isError: true);
      notifyListeners();
      return null;
    }
    try {
      final branchedSession = await _client().forkSession(
        id: session.id,
        turnId: turnId,
      );
      _upsertSessionSummary(branchedSession);
      connectionError = '';
      showNotice('已创建分支会话。');
      unawaited(_refreshCreatedSession(branchedSession.id));
      return branchedSession;
    } catch (error) {
      connectionError = error.toString();
      showNotice('创建分支失败：${error.toString()}', isError: true);
      notifyListeners();
      return null;
    }
  }

  Future<void> archiveSession(SessionSummary session) async {
    try {
      await _client().archiveSession(session.id);
      sessionDetails.remove(session.id);
      await refreshDashboard();
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
    }
  }

  Future<void> endSession(SessionSummary session) async {
    try {
      await _client().endSession(session.id);
      await refreshDashboard();
      await loadSession(session.id);
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
    }
  }

  Future<bool> submitPrompt({
    required SessionSummary session,
    required String prompt,
    List<String> imageUploadIds = const <String>[],
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty && imageUploadIds.isEmpty) {
      return false;
    }

    try {
      if (session.lastTurnStatus == 'inProgress' &&
          session.lastTurnId.isNotEmpty) {
        await _client().steerTurn(
          sessionId: session.id,
          turnId: session.lastTurnId,
          prompt: trimmed,
          imageUploadIds: imageUploadIds,
        );
      } else {
        await _client().startTurn(
          sessionId: session.id,
          prompt: trimmed,
          imageUploadIds: imageUploadIds,
        );
      }
      await refreshDashboard();
      await loadSession(session.id);
      return true;
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<UploadedImageRef?> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final ref = await _client().uploadImage(bytes: bytes, fileName: fileName);
      return ref;
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> interrupt(SessionSummary session) async {
    if (session.lastTurnId.isEmpty) {
      return;
    }
    try {
      await _client().interruptTurn(
        sessionId: session.id,
        turnId: session.lastTurnId,
      );
      await refreshDashboard();
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
    }
  }

  Future<void> resolve({
    required PendingRequestView approval,
    required ApprovalAction action,
  }) async {
    try {
      await _client().resolveApproval(
        id: approval.id,
        result: _buildResult(approval, action),
      );
      _removeResolvedApproval(approval);
      await refreshDashboard(force: true);
      final session = dashboard.sessions.cast<SessionSummary?>().firstWhere(
        (item) => item?.id == approval.threadId,
        orElse: () => null,
      );
      if (session != null) {
        await loadSession(session.id);
      }
    } catch (error) {
      connectionError = error.toString();
      notifyListeners();
    }
  }

  void _removeResolvedApproval(PendingRequestView approval) {
    final remainingApprovals = dashboard.approvals
        .where((item) => item.id != approval.id)
        .toList();
    if (remainingApprovals.length == dashboard.approvals.length) {
      return;
    }

    dashboard = DashboardResponse(
      agent: dashboard.agent,
      agents: dashboard.agents,
      defaultAgent: dashboard.defaultAgent,
      stats: DashboardStats(
        totalSessions: dashboard.stats.totalSessions,
        loadedSessions: dashboard.stats.loadedSessions,
        activeSessions: dashboard.stats.activeSessions,
        pendingApprovals: remainingApprovals.length,
      ),
      sessions: dashboard.sessions
          .map(
            (session) => session.id == approval.threadId
                ? _sessionWithPendingApprovalCount(
                    session,
                    math.max(0, session.pendingApprovals - 1),
                  )
                : session,
          )
          .toList(),
      approvals: remainingApprovals,
    );
    notifyListeners();
  }

  SessionSummary _sessionWithPendingApprovalCount(
    SessionSummary session,
    int pendingApprovals,
  ) {
    return SessionSummary(
      id: session.id,
      agentId: session.agentId,
      name: session.name,
      preview: session.preview,
      cwd: session.cwd,
      source: session.source,
      status: session.status,
      activeFlags: session.activeFlags,
      loaded: session.loaded,
      updatedAt: session.updatedAt,
      createdAt: session.createdAt,
      modelProvider: session.modelProvider,
      branch: session.branch,
      pendingApprovals: pendingApprovals,
      lastTurnId: session.lastTurnId,
      lastTurnStatus: session.lastTurnStatus,
      agentNickname: session.agentNickname,
      agentRole: session.agentRole,
      lifecycleStage: session.lifecycleStage,
      historyAvailable: session.historyAvailable,
      runtimeAvailable: session.runtimeAvailable,
      runtimeAttachMode: session.runtimeAttachMode,
      resumeAvailable: session.resumeAvailable,
      resumeBlockedReason: session.resumeBlockedReason,
      ended: session.ended,
      contextWindowUsage: session.contextWindowUsage,
    );
  }

  Object? _buildResult(PendingRequestView approval, ApprovalAction action) {
    switch (approval.kind) {
      case 'command':
      case 'fileChange':
        return <String, dynamic>{'decision': action.decisionValue};
      case 'permissions':
        final choice = action.choiceValue;
        Object? permissions;
        switch (choice) {
          case 'session':
          case 'turn':
            permissions = approval.params['permissions'] ?? <String, dynamic>{};
            break;
          default:
            permissions = <String, dynamic>{
              'network': null,
              'fileSystem': null,
            };
        }

        Object? scope;
        switch (choice) {
          case 'session':
          case 'turn':
            scope = choice;
            break;
          default:
            scope = null;
        }

        return <String, dynamic>{'permissions': permissions, 'scope': scope};
      case 'userInput':
        final questionId = _firstQuestionId(approval.params) ?? 'reply';
        return <String, dynamic>{
          'answers': <String, dynamic>{
            questionId: <String, dynamic>{
              'answers': <String>[action.freeformText],
            },
          },
        };
      default:
        return <String, dynamic>{'decision': action.choiceValue};
    }
  }

  String? _firstQuestionId(Map<String, dynamic> params) {
    final questions = asList(params['questions']);
    for (final question in questions) {
      final object = asMap(question);
      final id = asString(object['id']);
      if (id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  void _upsertSessionSummary(SessionSummary session) {
    final sessions = <SessionSummary>[...dashboard.sessions];
    final existingIndex = sessions.indexWhere((item) => item.id == session.id);
    if (existingIndex >= 0) {
      sessions[existingIndex] = session;
    } else {
      sessions.add(session);
    }

    sessions.sort((left, right) {
      if (left.updatedAt == right.updatedAt) {
        return left.id.compareTo(right.id);
      }
      return right.updatedAt.compareTo(left.updatedAt);
    });

    dashboard = DashboardResponse(
      agent: dashboard.agent,
      agents: dashboard.agents,
      defaultAgent: dashboard.defaultAgent,
      stats: dashboard.stats,
      sessions: sessions,
      approvals: dashboard.approvals,
    );
    notifyListeners();
  }

  List<AgentOption> get startAgentOptions => dashboard.agents;

  AgentOption? get selectedAgentOption {
    for (final option in dashboard.agents) {
      if (option.id == selectedStartAgentId) {
        return option;
      }
    }
    return null;
  }

  List<PendingRequestView> get selectedAgentApprovals {
    final allowedSessionIds = dashboard.sessions
        .where((session) => session.agentId == selectedStartAgentId)
        .map((session) => session.id)
        .toSet();
    return dashboard.approvals
        .where((approval) => allowedSessionIds.contains(approval.threadId))
        .toList();
  }

  AgentCapabilities capabilitiesForSession(SessionSummary session) {
    for (final option in dashboard.agents) {
      if (option.id == session.agentId) {
        return option.capabilities;
      }
    }
    return AgentCapabilities(
      supportsInterruptTurn: true,
      supportsApprovals: true,
      supportsArchive: true,
      supportsResume: true,
      supportsHistoryImport: false,
    );
  }

  bool canResumeSession(SessionSummary session) {
    return capabilitiesForSession(session).supportsResume && session.canResume;
  }

  String _resumeSuccessNotice(SessionSummary session) {
    if (!session.isClaudeSession) {
      return '会话已接管，可继续发消息。';
    }
    switch (session.runtimeAttachMode) {
      case 'resumed_existing':
        return '已接入现有 Claude runtime。';
      case 'opened_from_history':
        return '已为这条 Claude 历史会话打开新的 runtime。';
      case 'new_session':
        return '已打开新的 Claude runtime。';
      default:
        return 'Claude 会话已接管。';
    }
  }

  void showNotice(String message, {bool isError = false}) {
    _noticeTimer?.cancel();
    operationNotice = message;
    operationNoticeIsError = isError;
    notifyListeners();
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      operationNotice = '';
      operationNoticeIsError = false;
      notifyListeners();
    });
  }

  bool supportsApprovalsForSessionId(String sessionId) {
    SessionSummary? target;
    for (final session in dashboard.sessions) {
      if (session.id == sessionId) {
        target = session;
        break;
      }
    }
    if (target == null) {
      return true;
    }
    return capabilitiesForSession(target).supportsApprovals;
  }

  void setSelectedStartAgent(String id) {
    final normalized = id.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final exists = dashboard.agents.any(
      (item) => item.id == normalized && item.available,
    );
    if (!exists) {
      return;
    }
    selectedStartAgentId = normalized;
    notifyListeners();
  }

  void _syncSelectedAgent(DashboardResponse latestDashboard) {
    final availableIds = latestDashboard.agents
        .where((item) => item.available)
        .map((item) => item.id)
        .toSet();

    if (availableIds.contains(selectedStartAgentId)) {
      return;
    }

    final normalizedDefault = latestDashboard.defaultAgent.trim().toLowerCase();
    if (availableIds.contains(normalizedDefault)) {
      selectedStartAgentId = normalizedDefault;
      return;
    }

    selectedStartAgentId = availableIds.contains('codex')
        ? 'codex'
        : (availableIds.isNotEmpty ? availableIds.first : 'codex');
  }
}
