import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/app_models.dart';
import '../navigation/app_navigation.dart';
import '../services/api_client.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'approval_widgets.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final TextEditingController _promptController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_ComposerAttachment> _attachments = <_ComposerAttachment>[];
  Timer? _timer;
  Timer? _eventRefreshDebounce;
  StreamSubscription<AgentEvent>? _eventSubscription;
  int _tick = 0;
  bool _isUploadingImage = false;
  bool _isSubmittingPrompt = false;
  bool _isAtBottom = true;
  bool _stickToBottom = true;
  bool _showJumpToLatest = false;
  String _contentSignature = '';

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSessionPage(forceBottom: true));
      _startEventStream();
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollIfNeeded(),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventRefreshDebounce?.cancel();
    final eventSubscription = _eventSubscription;
    if (eventSubscription != null) {
      unawaited(eventSubscription.cancel());
    }
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  SessionDetail? _detail(AppModel model) =>
      model.sessionDetails[widget.sessionId];

  SessionSummary? _summary(AppModel model) {
    final detail = _detail(model);
    if (detail != null) {
      return detail.summary;
    }
    return model.dashboard.sessions.cast<SessionSummary?>().firstWhere(
      (session) => session?.id == widget.sessionId,
      orElse: () => null,
    );
  }

  List<PendingRequestView> _sessionApprovals(AppModel model) =>
      model.approvalsFor(widget.sessionId);

  Future<void> _pollIfNeeded() async {
    if (!mounted) {
      return;
    }
    final model = context.read<AppModel>();
    final summary = _summary(model);
    final approvals = _sessionApprovals(model);
    if (summary == null) {
      await _refreshSessionPage(keepBottomIfPinned: true);
      return;
    }
    if (summary.isEnded) {
      return;
    }
    if (approvals.isNotEmpty ||
        summary.hasWaitingState ||
        summary.lastTurnStatus == 'inProgress') {
      await _refreshSessionPage(keepBottomIfPinned: true);
      return;
    }
    _tick += 1;
    if (_tick % 2 == 0) {
      await _refreshSessionPage(keepBottomIfPinned: true);
    }
  }

  Future<void> _refreshSessionPage({
    bool keepBottomIfPinned = false,
    bool forceBottom = false,
  }) async {
    final wasPinned = _stickToBottom || _isNearBottom();
    final model = context.read<AppModel>();
    await model.refreshDashboard();
    await model.loadSession(widget.sessionId);
    if (mounted && (forceBottom || (keepBottomIfPinned && wasPinned))) {
      _stickToBottom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _stickToBottom = true;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleScroll() {
    final atBottom = _isNearBottom();
    if (atBottom) {
      _stickToBottom = true;
    }
    final showJumpToLatest = !_stickToBottom && !atBottom;
    if (atBottom == _isAtBottom && _showJumpToLatest == showJumpToLatest) {
      return;
    }
    setState(() {
      _isAtBottom = atBottom;
      _showJumpToLatest = showJumpToLatest;
    });
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.forward && !_isNearBottom()) {
      _stickToBottom = false;
      if (!_showJumpToLatest && mounted) {
        setState(() {
          _showJumpToLatest = true;
        });
      }
    } else if (_isNearBottom()) {
      _stickToBottom = true;
      if (_showJumpToLatest && mounted) {
        setState(() {
          _showJumpToLatest = false;
        });
      }
    }
    return false;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
  }

  void _syncBottomPin(SessionDetail? detail, TurnDetail? activeTurn) {
    final signature = _buildContentSignature(detail, activeTurn);
    if (signature == _contentSignature) {
      return;
    }
    _contentSignature = signature;
    if (!_stickToBottom) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _buildContentSignature(SessionDetail? detail, TurnDetail? activeTurn) {
    if (detail == null) {
      return 'loading';
    }
    final parts = <String>[
      detail.turns.length.toString(),
      activeTurn?.id ?? '',
      activeTurn?.status ?? '',
    ];
    for (final turn in detail.turns) {
      parts.add(turn.id);
      parts.add(turn.status);
      parts.add(turn.items.length.toString());
      for (final item in turn.items) {
        parts.add(item.id);
        parts.add(item.status);
        parts.add(item.body.length.toString());
        parts.add(item.auxiliary.length.toString());
      }
    }
    return parts.join('|');
  }

  void _startEventStream() {
    final model = context.read<AppModel>();
    final baseUrl = model.baseUrlString;
    _eventSubscription = ApiClient(baseUrlString: baseUrl).events().listen((
      event,
    ) {
      if (!_eventTouchesSession(event, widget.sessionId)) {
        return;
      }
      final appliedRealtime = model.applyRealtimeEvent(event);
      if (appliedRealtime && (_stickToBottom || _isNearBottom())) {
        _stickToBottom = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      if (appliedRealtime && _isStreamingTextEvent(event.type)) {
        return;
      }
      if (_isStreamingTextNotification(event)) {
        return;
      }
      _eventRefreshDebounce?.cancel();
      _eventRefreshDebounce = Timer(const Duration(milliseconds: 80), () {
        if (mounted) {
          unawaited(_refreshSessionPage(keepBottomIfPinned: true));
        }
      });
    }, onError: (_) {});
  }

  bool _isStreamingTextEvent(String eventType) {
    return eventType == 'turn.agentMessage.delta' ||
        eventType == 'turn.agentMessage.updated';
  }

  bool _isStreamingTextNotification(AgentEvent event) {
    if (event.type != 'codex.notification') {
      return false;
    }
    final method = asString(
      event.payload['method'],
    ).replaceAll('_', '').toLowerCase();
    return method.contains('agentmessage') && method.contains('delta');
  }

  bool _eventTouchesSession(AgentEvent event, String sessionId) {
    final eventType = event.type;
    if (eventType == 'sessions.refreshed') {
      return true;
    }
    return _payloadTouchesSession(event.payload, sessionId);
  }

  bool _payloadTouchesSession(Map<String, dynamic> payload, String sessionId) {
    for (final key in const <String>['threadId', 'sessionId']) {
      if (asString(payload[key]) == sessionId) {
        return true;
      }
    }
    if (asString(payload['id']) == sessionId &&
        payload.containsKey('agentId')) {
      return true;
    }
    final params = asMap(payload['params']);
    if (params.isNotEmpty && _payloadTouchesSession(params, sessionId)) {
      return true;
    }
    return false;
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) {
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });
    try {
      final model = context.read<AppModel>();
      final uploaded = await model.uploadImage(
        bytes: bytes,
        fileName: image.name.isEmpty ? 'attachment.jpg' : image.name,
      );
      if (!mounted || uploaded == null) {
        return;
      }
      setState(() {
        _attachments.add(
          _ComposerAttachment(
            id: '${DateTime.now().microsecondsSinceEpoch}-${uploaded.id}',
            uploadId: uploaded.id,
            bytes: bytes,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _branchFromSession(SessionSummary summary, String turnId) async {
    final model = context.read<AppModel>();
    final branchedSession = await model.branchSession(
      session: summary,
      turnId: turnId,
    );
    if (!mounted || branchedSession == null) {
      return;
    }
    openSessionChatPage(branchedSession.id);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final l10n = AppLocalizations.of(model.languageCode);
    final detail = _detail(model);
    final summary = _summary(model);
    final capabilities = summary == null
        ? AgentCapabilities(
            supportsInterruptTurn: true,
            supportsApprovals: true,
            supportsArchive: true,
            supportsResume: true,
            supportsHistoryImport: false,
          )
        : model.capabilitiesForSession(summary);
    final supportsApprovals = capabilities.supportsApprovals;
    final approvals = supportsApprovals
        ? _sessionApprovals(model)
        : <PendingRequestView>[];
    final activeTurn = detail?.turns.reversed.cast<TurnDetail?>().firstWhere(
      (turn) => turn?.status == 'inProgress',
      orElse: () => null,
    );
    _syncBottomPin(detail, activeTurn);

    return Scaffold(
      backgroundColor: Palette.canvas,
      appBar: AppBar(
        title: Text(
          summary?.displayName ?? l10n.t('session.fallbackTitle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: roundedTextStyle(size: 17, weight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: <Widget>[
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ContextUsageIndicator(summary: summary),
                    const SizedBox(width: 8),
                    StatusPill(
                      status: summary.status,
                      waiting: summary.hasWaitingState,
                      ended: summary.isEnded,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: PageScaffold(
        child: Column(
          children: <Widget>[
            if (model.operationNotice.isNotEmpty)
              _NoticeBanner(
                text: model.operationNotice,
                isError: model.operationNoticeIsError,
              ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  RefreshIndicator(
                    color: Palette.accent,
                    onRefresh: _refreshSessionPage,
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: _handleUserScroll,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                        children: <Widget>[
                          if (summary == null) ...<Widget>[
                            _SystemBubble(text: l10n.t('session.loadingInfo')),
                            const SizedBox(height: 14),
                          ],
                          if (detail == null)
                            const _LoadingBubble()
                          else
                            ..._buildMessageFlow(detail, summary),
                          if (activeTurn != null) ...<Widget>[
                            const SizedBox(height: 8),
                            _SystemBubble(
                              text: l10n.t('session.agentReplying'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_showJumpToLatest)
                    Positioned(
                      right: 18,
                      bottom: 14,
                      child: _JumpToLatestButton(onPressed: _scrollToBottom),
                    ),
                ],
              ),
            ),
            if (summary != null && !summary.isEnded)
              _ChatComposer(
                summary: summary,
                approvals: approvals,
                promptController: _promptController,
                attachments: _attachments,
                isUploadingImage: _isUploadingImage,
                isSubmittingPrompt: _isSubmittingPrompt,
                onPickImage: _pickAndUploadImage,
                onRemoveAttachment: (String id) {
                  setState(() {
                    _attachments.removeWhere((item) => item.id == id);
                  });
                },
                onSubmit: () async {
                  if (_isSubmittingPrompt) {
                    return;
                  }
                  setState(() {
                    _isSubmittingPrompt = true;
                  });
                  try {
                    final sent = await model.submitPrompt(
                      session: summary,
                      prompt: _promptController.text.trim(),
                      imageUploadIds: _attachments
                          .map((item) => item.uploadId)
                          .toList(),
                    );
                    if (sent) {
                      _promptController.clear();
                      setState(() {
                        _attachments.clear();
                      });
                      await _refreshSessionPage(forceBottom: true);
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSubmittingPrompt = false;
                      });
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMessageFlow(
    SessionDetail detail,
    SessionSummary? summary,
  ) {
    final l10n = AppLocalizations.of(context.read<AppModel>().languageCode);
    final messages = <Widget>[];
    for (final turn in detail.turns) {
      final planText = _planText(turn);
      if (planText.isNotEmpty) {
        if (messages.isNotEmpty) {
          messages.add(const SizedBox(height: 10));
        }
        messages.add(
          _CompactEventBubble(
            icon: Icons.psychology_alt_outlined,
            tone: Palette.softBlue,
            text: planText,
          ),
        );
      }
      for (final item in turn.items) {
        final bubble = _bubbleForItem(
          item,
          summary,
          turn,
          showAgentActions: _shouldShowAgentActions(item, summary, turn),
        );
        if (bubble == null) {
          continue;
        }
        if (messages.isNotEmpty) {
          messages.add(const SizedBox(height: 10));
        }
        messages.add(bubble);
      }
      if (turn.error.isNotEmpty) {
        if (messages.isNotEmpty) {
          messages.add(const SizedBox(height: 10));
        }
        messages.add(
          _SystemBubble(
            text: AppLocalizations.of(
              context.read<AppModel>().languageCode,
            ).t('session.executionFailed', {'error': turn.error}),
          ),
        );
      }
    }

    if (messages.isEmpty) {
      messages.add(_SystemBubble(text: l10n.t('session.noMessagesManaged')));
    }

    return messages;
  }

  String _planText(TurnDetail turn) {
    if (turn.plan.isEmpty && turn.planExplanation.trim().isEmpty) {
      return '';
    }
    final l10n = AppLocalizations.of(context.read<AppModel>().languageCode);
    final parts = <String>[l10n.t('session.thinking')];
    final explanation = turn.planExplanation.trim();
    if (explanation.isNotEmpty) {
      parts.add(
        _compactPreview(explanation, maxLength: 70, head: 50, tail: 16),
      );
    }
    final currentSteps = turn.plan
        .where(
          (step) => step.status == 'in_progress' || step.status == 'inProgress',
        )
        .map((step) => step.step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
    final fallbackSteps = turn.plan
        .map((step) => step.step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
    final visibleSteps = currentSteps.isNotEmpty ? currentSteps : fallbackSteps;
    if (visibleSteps.isNotEmpty) {
      parts.add(
        _compactPreview(visibleSteps.first, maxLength: 88, head: 64, tail: 18),
      );
    }
    return parts.join(' · ');
  }

  Widget? _bubbleForItem(
    TurnItem item,
    SessionSummary? summary,
    TurnDetail turn, {
    required bool showAgentActions,
  }) {
    final body = item.body.trim();
    switch (item.type) {
      case 'userMessage':
        if (body.isEmpty) {
          return null;
        }
        return _ChatBubble(role: _BubbleRole.user, text: body);
      case 'agentMessage':
        if (body.isEmpty) {
          return null;
        }
        return _ChatBubble(
          role: _BubbleRole.agent,
          text: body,
          showAgentActions: showAgentActions,
          onBranch:
              showAgentActions && summary != null && !summary.isClaudeSession
              ? () => _branchFromSession(summary, turn.id)
              : null,
        );
      case 'reasoning':
      case 'plan':
        if (body.isEmpty) {
          return null;
        }
        return _CompactEventBubble(
          icon: Icons.psychology_alt_outlined,
          tone: Palette.softBlue,
          text: _eventText('思考', body, item.status),
        );
      case 'fileChange':
        return _CompactEventBubble(
          icon: Icons.description_outlined,
          tone: Palette.accent2,
          text: _eventText('文件变更', body, item.status),
        );
      case 'commandExecution':
        return _CompactEventBubble(
          icon: Icons.terminal_rounded,
          tone: Palette.warning,
          text: _eventText('命令执行', body, item.status),
        );
      case 'dynamicToolCall':
        return _CompactEventBubble(
          icon: Icons.build_circle_outlined,
          tone: Palette.softBlue,
          text: _eventText(
            item.title.isEmpty ? '工具调用' : item.title,
            body,
            item.status,
          ),
        );
      case 'collabAgentToolCall':
        return _CompactEventBubble(
          icon: Icons.call_split_rounded,
          tone: Palette.warning,
          text: _eventText('委托 Agent', body, item.status),
        );
      default:
        if (body.isEmpty && item.title.isEmpty && item.status.isEmpty) {
          return null;
        }
        return _CompactEventBubble(
          icon: Icons.more_horiz_rounded,
          tone: Palette.mutedInk,
          text: _eventText(
            item.title.isEmpty ? item.type : item.title,
            body,
            item.status,
          ),
        );
    }
  }

  bool _shouldShowAgentActions(
    TurnItem item,
    SessionSummary? summary,
    TurnDetail turn,
  ) {
    if (summary == null ||
        item.type != 'agentMessage' ||
        item.body.trim().isEmpty ||
        turn.status != 'completed') {
      return false;
    }

    for (var index = turn.items.length - 1; index >= 0; index -= 1) {
      final candidate = turn.items[index];
      if (candidate.type == 'agentMessage' &&
          candidate.body.trim().isNotEmpty) {
        return identical(candidate, item) ||
            (candidate.id.isNotEmpty && candidate.id == item.id);
      }
    }
    return false;
  }

  String _eventText(String title, String body, String status) {
    final parts = <String>[title.trim()];
    if (status.trim().isNotEmpty) {
      parts.add(_statusLabel(status));
    }
    final preview = _compactPreview(
      normalizedDisplayText(body),
      maxLength: 120,
      head: 82,
      tail: 30,
    );
    if (preview.isNotEmpty) {
      parts.add(preview);
    }
    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      case 'inProgress':
        return '进行中';
      default:
        return status;
    }
  }

  String _compactPreview(
    String value, {
    required int maxLength,
    required int head,
    required int tail,
  }) {
    if (value.runes.length <= maxLength) {
      return value;
    }
    final values = value.runes.toList();
    final safeHead = head.clamp(0, values.length);
    final safeTail = tail.clamp(0, values.length - safeHead);
    if (safeHead + safeTail >= values.length) {
      return value;
    }
    return '${String.fromCharCodes(values.take(safeHead))}...${String.fromCharCodes(values.skip(values.length - safeTail))}';
  }
}

class _ContextUsageIndicator extends StatelessWidget {
  const _ContextUsageIndicator({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final usage = _ContextUsage.from(summary: summary);
    final tone = !usage.available
        ? Palette.faintInk
        : usage.ratio >= 0.9
        ? Palette.danger
        : usage.ratio >= 0.72
        ? Palette.warning
        : Palette.softBlue;
    final tooltip = usage.available
        ? '上下文使用 ${usage.percentLabel} · ${usage.tokenLabel}'
        : '上下文用量暂未上报';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showContextUsageSheet(context, summary),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Palette.line),
              ),
              child: CustomPaint(
                size: const Size.square(18),
                painter: _ContextUsagePainter(
                  progress: usage.ratio,
                  tone: tone,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextUsageSheet(BuildContext context, SessionSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextUsageSheet(summary: summary),
    );
  }
}

class _ContextUsagePainter extends CustomPainter {
  const _ContextUsagePainter({required this.progress, required this.tone});

  final double progress;
  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 4) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = Palette.ink.appOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final arc = Paint()
      ..color = tone
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, track);
    final safeProgress = progress.clamp(0.02, 0.98);
    canvas.drawArc(rect, -math.pi / 2, safeProgress * math.pi * 2, false, arc);
  }

  @override
  bool shouldRepaint(covariant _ContextUsagePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tone != tone;
  }
}

class _ContextUsage {
  const _ContextUsage({
    required this.available,
    required this.ratio,
    required this.percentLabel,
    required this.tokenLabel,
  });

  final bool available;
  final double ratio;
  final String percentLabel;
  final String tokenLabel;

  static _ContextUsage from({required SessionSummary summary}) {
    final usage = summary.contextWindowUsage;
    if (!usage.available) {
      return const _ContextUsage(
        available: false,
        ratio: 0,
        percentLabel: '未上报',
        tokenLabel: '无真实用量',
      );
    }
    return _ContextUsage(
      available: true,
      ratio: usage.ratio.clamp(0, 0.98),
      percentLabel: usage.percentLabel,
      tokenLabel: usage.tokenLabel,
    );
  }
}

class _ContextUsageSheet extends StatelessWidget {
  const _ContextUsageSheet({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final usage = summary.contextWindowUsage;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: Palette.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Text(
                  '上下文用量',
                  style: roundedTextStyle(size: 18, weight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '关闭',
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Palette.softBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (usage.available)
              _ContextUsageDetails(usage: usage)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.ink.appOpacity(0.045),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.line),
                ),
                child: Text(
                  '当前会话还没有真实 token_count 记录。完成一次 Codex turn 后会显示上下文用量和上限。',
                  style: roundedTextStyle(
                    size: 13,
                    weight: FontWeight.w500,
                    color: Palette.mutedInk,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextUsageDetails extends StatelessWidget {
  const _ContextUsageDetails({required this.usage});

  final ContextWindowUsage usage;

  @override
  Widget build(BuildContext context) {
    final ratio = usage.ratio.clamp(0, 1).toDouble();
    final tone = ratio >= 0.9
        ? Palette.danger
        : ratio >= 0.72
        ? Palette.warning
        : Palette.softBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ContextMetricTile(
                label: '当前用量',
                value: _formatTokenCount(usage.usedTokens),
                tone: tone,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ContextMetricTile(
                label: '上下文上限',
                value: _formatTokenCount(usage.contextWindow),
                tone: Palette.softBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Palette.ink.appOpacity(0.08),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(color: tone),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            CapsuleTag(title: '比例', value: usage.percentLabel),
            CapsuleTag(
              title: '剩余',
              value: _formatTokenCount(usage.remainingTokens),
            ),
            CapsuleTag(
              title: '累计',
              value: _formatTokenCount(usage.totalTokenUsage.totalTokens),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContextMetricTile extends StatelessWidget {
  const _ContextMetricTile({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.ink.appOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: roundedTextStyle(
              size: 11,
              weight: FontWeight.w700,
              color: Palette.mutedInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: roundedTextStyle(
              size: 20,
              weight: FontWeight.w800,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTokenCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).round()}K';
  }
  return value.toString();
}

class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.ink,
            shape: BoxShape.circle,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(31, 36, 41, 0.18),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tone = isError ? Palette.danger : Palette.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tone.appOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: roundedTextStyle(
            size: 12,
            weight: FontWeight.w600,
            color: tone,
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return const _SystemBubble(text: '正在同步历史消息');
  }
}

enum _BubbleRole { user, agent }

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.role,
    required this.text,
    this.showAgentActions = false,
    this.onBranch,
  });

  final _BubbleRole role;
  final String text;
  final bool showAgentActions;
  final Future<void> Function()? onBranch;

  @override
  Widget build(BuildContext context) {
    final isUser = role == _BubbleRole.user;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.84,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Palette.ink : Colors.white.appOpacity(0.82),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 7),
            bottomRight: Radius.circular(isUser ? 7 : 20),
          ),
          border: Border.all(color: isUser ? Colors.transparent : Palette.line),
          boxShadow: isUser
              ? null
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(31, 36, 41, 0.07),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: isUser
            ? SelectableText(
                text,
                style: roundedTextStyle(
                  size: 14,
                  weight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.55,
                ),
              )
            : MarkdownBodyBlock(raw: text, selectable: true),
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          bubble,
          if (showAgentActions) ...<Widget>[
            const SizedBox(height: 4),
            _AgentMessageActions(
              onBranch: onBranch,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '已复制回复',
                      style: roundedTextStyle(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1300),
                    backgroundColor: Palette.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentMessageActions extends StatelessWidget {
  const _AgentMessageActions({required this.onCopy, this.onBranch});

  final Future<void> Function() onCopy;
  final Future<void> Function()? onBranch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AgentMessageActionButton(
            icon: Icons.content_copy_rounded,
            tooltip: '复制回复',
            onPressed: () => unawaited(onCopy()),
          ),
          if (onBranch != null)
            _AgentMessageActionButton(
              icon: Icons.call_split_rounded,
              tooltip: '创建分支',
              onPressed: () => unawaited(onBranch!()),
            ),
        ],
      ),
    );
  }
}

class _AgentMessageActionButton extends StatelessWidget {
  const _AgentMessageActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 19,
                color: Palette.mutedInk.appOpacity(0.74),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.ink.appOpacity(0.055),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: roundedTextStyle(
            size: 12,
            weight: FontWeight.w600,
            color: Palette.mutedInk,
          ),
        ),
      ),
    );
  }
}

class _CompactEventBubble extends StatelessWidget {
  const _CompactEventBubble({
    required this.icon,
    required this.tone,
    required this.text,
  });

  final IconData icon;
  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.appOpacity(0.62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 15, color: tone),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: roundedTextStyle(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Palette.mutedInk,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerApprovalPanel extends StatelessWidget {
  const _ComposerApprovalPanel({required this.approvals});

  final List<PendingRequestView> approvals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.warning.appOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.warning.appOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.verified_user_outlined,
                size: 17,
                color: Palette.warning,
              ),
              const SizedBox(width: 8),
              Text(
                approvals.length == 1 ? '需要审批' : '需要审批 (${approvals.length})',
                style: roundedTextStyle(size: 14, weight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '当前会话',
                style: roundedTextStyle(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Palette.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              child: Column(
                children: approvals
                    .map(
                      (approval) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ApprovalCardBody(
                          approval: approval,
                          showSessionLabel: false,
                          embedded: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.summary,
    required this.approvals,
    required this.promptController,
    required this.attachments,
    required this.isUploadingImage,
    required this.isSubmittingPrompt,
    required this.onPickImage,
    required this.onRemoveAttachment,
    required this.onSubmit,
  });

  final SessionSummary summary;
  final List<PendingRequestView> approvals;
  final TextEditingController promptController;
  final List<_ComposerAttachment> attachments;
  final bool isUploadingImage;
  final bool isSubmittingPrompt;
  final Future<void> Function() onPickImage;
  final void Function(String id) onRemoveAttachment;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final activeTurn = summary.lastTurnStatus == 'inProgress';
    final model = context.watch<AppModel>();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white.appOpacity(0.9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Palette.ink.appOpacity(0.10)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(31, 36, 41, 0.16),
              blurRadius: 40,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (approvals.isNotEmpty) ...<Widget>[
              _ComposerApprovalPanel(approvals: approvals),
              const SizedBox(height: 10),
            ],
            if (attachments.isNotEmpty) ...<Widget>[
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return _AttachmentPreview(
                      attachment: attachment,
                      onRemove: () => onRemoveAttachment(attachment.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: promptController,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              style: roundedTextStyle(size: 15, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: activeTurn ? '补充要求' : '继续会话',
                hintStyle: roundedTextStyle(
                  size: 15,
                  weight: FontWeight.w500,
                  color: Palette.faintInk,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _RoundIconButton(
                  icon: isUploadingImage
                      ? Icons.hourglass_empty_rounded
                      : Icons.add_rounded,
                  color: Palette.ink,
                  onPressed: isUploadingImage
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          await onPickImage();
                        },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: <Widget>[
                        OptionChipButton(
                          label: '',
                          value: _policyLabel(model.defaultExecutionPolicy),
                          icon: _policyIcon(model.defaultExecutionPolicy),
                          tone: _policyTone(model.defaultExecutionPolicy),
                          onPressed: () => _showPolicyPicker(context, model),
                        ),
                        const SizedBox(width: 6),
                        OptionChipButton(
                          label: '',
                          value: model.defaultModel,
                          onPressed: () => _showModelPicker(context, model),
                        ),
                        const SizedBox(width: 6),
                        OptionChipButton(
                          label: '',
                          value: _reasoningLabel(model.defaultReasoning),
                          onPressed: () => _showReasoningPicker(context, model),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: promptController,
                  builder: (context, value, _) {
                    final canSubmit =
                        value.text.trim().isNotEmpty || attachments.isNotEmpty;
                    return _SendButton(
                      enabled:
                          canSubmit && !isUploadingImage && !isSubmittingPrompt,
                      loading: isSubmittingPrompt,
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        await onSubmit();
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPolicyPicker(BuildContext context, AppModel model) async {
    await _showValuePicker(
      context: context,
      title: '默认执行策略',
      value: model.defaultExecutionPolicy,
      values: const <String, String>{
        'ask': '默认权限',
        'review': '自动审查',
        'full': '完全权限',
      },
      iconForValue: _policyIcon,
      toneForValue: _policyTone,
      onSelected: model.updateDefaultExecutionPolicy,
    );
  }

  Future<void> _showModelPicker(BuildContext context, AppModel model) async {
    await _showValuePicker(
      context: context,
      title: '默认模型',
      value: model.defaultModel,
      values: const <String, String>{
        'GPT-5.3-Codex': 'GPT-5.3-Codex',
        'GPT-5.4': 'GPT-5.4',
        'GPT-5.4-Mini': 'GPT-5.4-Mini',
        'GPT-5.5': 'GPT-5.5',
      },
      onSelected: model.updateDefaultModel,
    );
  }

  Future<void> _showReasoningPicker(
    BuildContext context,
    AppModel model,
  ) async {
    await _showValuePicker(
      context: context,
      title: '推理深度',
      value: model.defaultReasoning,
      values: const <String, String>{
        'low': '低',
        'medium': '中',
        'high': '高',
        'xhigh': '超高',
      },
      onSelected: model.updateDefaultReasoning,
    );
  }

  Future<void> _showValuePicker({
    required BuildContext context,
    required String title,
    required String value,
    required Map<String, String> values,
    IconData Function(String value)? iconForValue,
    Color? Function(String value)? toneForValue,
    required Future<void> Function(String value) onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: title,
        children: values.entries
            .map(
              (entry) => _OptionSheetTile(
                title: entry.value,
                selected: entry.key == value,
                icon: iconForValue?.call(entry.key),
                tone: toneForValue?.call(entry.key),
                onTap: () async {
                  await onSelected(entry.key);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String _policyLabel(String value) {
    switch (value) {
      case 'ask':
        return '默认权限';
      case 'full':
        return '完全权限';
      default:
        return '自动审查';
    }
  }

  IconData _policyIcon(String value) {
    switch (value) {
      case 'review':
        return Icons.rate_review_outlined;
      case 'full':
        return Icons.shield_outlined;
      default:
        return Icons.pan_tool_alt_outlined;
    }
  }

  Color? _policyTone(String value) {
    switch (value) {
      case 'review':
        return Palette.softBlue;
      case 'full':
        return Palette.warning;
      default:
        return null;
    }
  }

  String _reasoningLabel(String value) {
    switch (value) {
      case 'low':
        return '低';
      case 'high':
        return '高';
      case 'xhigh':
        return '超高';
      default:
        return '中';
    }
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.ink.appOpacity(0.055),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled || loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => unawaited(onPressed()) : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Palette.ink : Palette.ink.appOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: loading
                ? const SizedBox(
                    key: ValueKey<String>('sending'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    key: const ValueKey<String>('send'),
                    size: 22,
                    color: enabled ? Colors.white : Palette.mutedInk,
                  ),
          ),
        ),
      ),
    );
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: Palette.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Palette.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: roundedTextStyle(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OptionSheetTile extends StatelessWidget {
  const _OptionSheetTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tone,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? Palette.mutedInk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? effectiveTone.appOpacity(0.10)
                  : Palette.surfaceStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? effectiveTone.appOpacity(0.28) : Palette.line,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: effectiveTone),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: roundedTextStyle(
                      size: 14,
                      weight: FontWeight.w700,
                      color: tone ?? Palette.ink,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: effectiveTone,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.onRemove});

  final _ComposerAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            attachment.bytes,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Palette.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComposerAttachment {
  _ComposerAttachment({
    required this.id,
    required this.uploadId,
    required this.bytes,
  });

  final String id;
  final String uploadId;
  final Uint8List bytes;
}
