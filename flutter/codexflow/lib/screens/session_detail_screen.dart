import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'approval_screen.dart';

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
  bool _isAtBottom = true;
  bool _showJumpToLatest = false;

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
      await _refreshSessionPage();
      return;
    }
    if (summary.isEnded) {
      return;
    }
    if (approvals.isNotEmpty ||
        summary.hasWaitingState ||
        summary.lastTurnStatus == 'inProgress') {
      await _refreshSessionPage();
      return;
    }
    if (summary.loaded) {
      _tick += 1;
      if (_tick % 2 == 0) {
        await _refreshSessionPage();
      }
    }
  }

  Future<void> _refreshSessionPage({
    bool keepBottomIfPinned = false,
    bool forceBottom = false,
  }) async {
    final wasAtBottom = _isNearBottom();
    final model = context.read<AppModel>();
    await model.refreshDashboard();
    await model.loadSession(widget.sessionId);
    if (mounted && (forceBottom || (keepBottomIfPinned && wasAtBottom))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleScroll() {
    final atBottom = _isNearBottom();
    if (atBottom == _isAtBottom && _showJumpToLatest == !atBottom) {
      return;
    }
    setState(() {
      _isAtBottom = atBottom;
      _showJumpToLatest = !atBottom;
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
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
      if (appliedRealtime && _isNearBottom()) {
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

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
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
    final supportsResume = summary == null
        ? capabilities.supportsResume
        : model.canResumeSession(summary);
    final approvals = supportsApprovals
        ? _sessionApprovals(model)
        : <PendingRequestView>[];
    final activeTurn = detail?.turns.reversed.cast<TurnDetail?>().firstWhere(
      (turn) => turn?.status == 'inProgress',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Palette.canvas,
      appBar: AppBar(
        title: Text(
          summary?.displayName ?? '会话',
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
                    _ContextUsageIndicator(detail: detail, summary: summary),
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
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                      children: <Widget>[
                        if (summary != null)
                          _ThreadHeader(summary: summary)
                        else
                          const _SystemBubble(text: '正在加载会话信息'),
                        const SizedBox(height: 14),
                        if (detail == null)
                          const _LoadingBubble()
                        else
                          ..._buildMessageFlow(detail, summary),
                        if (approvals.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          _ApprovalBubble(approvals: approvals),
                        ],
                        if (activeTurn != null) ...<Widget>[
                          const SizedBox(height: 8),
                          const _SystemBubble(text: 'Agent 正在回复'),
                        ],
                        if (summary != null &&
                            (summary.isEnded || !summary.loaded)) ...<Widget>[
                          const SizedBox(height: 8),
                          _TakeoverBubble(
                            summary: summary,
                            supportsResume: supportsResume,
                            onPressed: () async {
                              await model.resumeSession(summary);
                              await _refreshSessionPage(forceBottom: true);
                            },
                          ),
                        ],
                      ],
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
            if (summary != null && !summary.isEnded && summary.loaded)
              _ChatComposer(
                summary: summary,
                promptController: _promptController,
                attachments: _attachments,
                isUploadingImage: _isUploadingImage,
                onPickImage: _pickAndUploadImage,
                onRemoveAttachment: (String id) {
                  setState(() {
                    _attachments.removeWhere((item) => item.id == id);
                  });
                },
                onSubmit: () async {
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
        final bubble = _bubbleForItem(item);
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
        messages.add(_SystemBubble(text: '执行失败：${turn.error}'));
      }
    }

    if (messages.isEmpty) {
      final empty = summary?.loaded == true
          ? '还没有消息。直接在下面输入，开始第一轮。'
          : '这个会话当前只有历史摘要，接管后才能继续对话。';
      messages.add(_SystemBubble(text: empty));
    }

    return messages;
  }

  String _planText(TurnDetail turn) {
    if (turn.plan.isEmpty && turn.planExplanation.trim().isEmpty) {
      return '';
    }
    final parts = <String>['思考'];
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

  Widget? _bubbleForItem(TurnItem item) {
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
        return _ChatBubble(role: _BubbleRole.agent, text: body);
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
  const _ContextUsageIndicator({required this.detail, required this.summary});

  final SessionDetail? detail;
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final usage = _ContextUsage.from(detail: detail, summary: summary);
    final tone = usage.ratio >= 0.9
        ? Palette.danger
        : usage.ratio >= 0.72
        ? Palette.warning
        : Palette.softBlue;

    return Tooltip(
      message: '上下文使用约 ${usage.percentLabel} · ${usage.tokenLabel}',
      child: Semantics(
        label: '上下文使用约 ${usage.percentLabel}',
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
            painter: _ContextUsagePainter(progress: usage.ratio, tone: tone),
          ),
        ),
      ),
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
  const _ContextUsage({required this.tokens, required this.limit});

  final int tokens;
  final int limit;

  double get ratio {
    if (limit <= 0) {
      return 0;
    }
    return (tokens / limit).clamp(0, 0.98);
  }

  String get percentLabel => '${(ratio * 100).round()}%';

  String get tokenLabel =>
      '${_compactNumber(tokens)} / ${_compactNumber(limit)}';

  static _ContextUsage from({
    required SessionDetail? detail,
    required SessionSummary summary,
  }) {
    final turns = detail?.turns ?? const <TurnDetail>[];
    var tokens = 0;
    for (final turn in turns) {
      tokens += _estimateTokens(turn.planExplanation);
      tokens += _estimateTokens(turn.error);
      for (final step in turn.plan) {
        tokens += _estimateTokens(step.step);
      }
      for (final item in turn.items) {
        tokens += _estimateTokens(item.title);
        tokens += _estimateTokens(item.body);
        tokens += _estimateTokens(item.auxiliary);
      }
    }

    if (tokens == 0) {
      tokens = _estimateTokens(summary.preview);
    }

    return _ContextUsage(
      tokens: tokens,
      limit: _contextLimitFor(summary.modelProvider),
    );
  }
}

int _contextLimitFor(String modelProvider) {
  final provider = modelProvider.trim().toLowerCase();
  if (provider.contains('anthropic') || provider.contains('claude')) {
    return 200000;
  }
  return 200000;
}

int _estimateTokens(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 0;
  }

  var cjkChars = 0;
  var asciiChars = 0;
  for (final rune in trimmed.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF)) {
      cjkChars += 1;
    } else if (String.fromCharCode(rune).trim().isNotEmpty) {
      asciiChars += 1;
    }
  }
  final estimate = (cjkChars * 1.15) + (asciiChars / 4.0);
  return math.max(1, estimate.ceil());
}

String _compactNumber(int value) {
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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AgentMark(agentId: summary.agentId),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                summary.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: roundedTextStyle(size: 16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: roundedTextStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: Palette.mutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _subtitle {
    final agent = summary.isClaudeSession
        ? (summary.runtimeAvailable ? 'Claude Runtime' : 'Claude History')
        : 'Codex';
    final branch = summary.branch.isEmpty ? '未识别分支' : summary.branch;
    return '$agent · $branch';
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
  const _ChatBubble({required this.role, required this.text});

  final _BubbleRole role;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isUser = role == _BubbleRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
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
            border: Border.all(
              color: isUser ? Colors.transparent : Palette.line,
            ),
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
              ? Text(
                  text,
                  style: roundedTextStyle(
                    size: 14,
                    weight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.55,
                  ),
                )
              : MarkdownBodyBlock(raw: text),
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

class _ApprovalBubble extends StatelessWidget {
  const _ApprovalBubble({required this.approvals});

  final List<PendingRequestView> approvals;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.9,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.appOpacity(0.84),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Palette.warning.appOpacity(0.18)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(31, 36, 41, 0.07),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
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
                    '需要审批',
                    style: roundedTextStyle(size: 14, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...approvals.map(
                (approval) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ApprovalCardBody(
                    approval: approval,
                    showSessionLabel: false,
                    embedded: true,
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

class _TakeoverBubble extends StatelessWidget {
  const _TakeoverBubble({
    required this.summary,
    required this.supportsResume,
    required this.onPressed,
  });

  final SessionSummary summary;
  final bool supportsResume;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final blockedReason = summary.resumeBlockedReason.trim();
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.appOpacity(0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              summary.isEnded ? '会话已结束' : '历史会话',
              style: roundedTextStyle(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              blockedReason.isEmpty ? '接管后可以继续发送下一条消息。' : blockedReason,
              style: roundedTextStyle(
                size: 12,
                weight: FontWeight.w500,
                color: Palette.mutedInk,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            ActionButton(
              title: summary.isClaudeSession ? '接管到 CodexFlow' : '重新接管',
              background: Palette.ink,
              foreground: Colors.white,
              icon: Icons.play_arrow_rounded,
              enabled: supportsResume,
              onPressed: () async {
                await onPressed();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.summary,
    required this.promptController,
    required this.attachments,
    required this.isUploadingImage,
    required this.onPickImage,
    required this.onRemoveAttachment,
    required this.onSubmit,
  });

  final SessionSummary summary;
  final TextEditingController promptController;
  final List<_ComposerAttachment> attachments;
  final bool isUploadingImage;
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
                      enabled: canSubmit && !isUploadingImage,
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
        'review': '自动审查',
        'ask': '每次确认',
        'full': '完全使用权限',
      },
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
        return '每次确认';
      case 'full':
        return '完全权限';
      default:
        return '自动审查';
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
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
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
            color: enabled ? Palette.ink : Palette.ink.appOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_upward_rounded,
            size: 22,
            color: Colors.white,
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
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  ? Palette.softBlue.appOpacity(0.10)
                  : Palette.surfaceStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Palette.softBlue.appOpacity(0.28)
                    : Palette.line,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: roundedTextStyle(size: 14, weight: FontWeight.w700),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Palette.softBlue,
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
