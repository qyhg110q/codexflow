import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
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
  int _tick = 0;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSessionPage());
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollIfNeeded(),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  Future<void> _refreshSessionPage() async {
    final model = context.read<AppModel>();
    await model.refreshDashboard();
    await model.loadSession(widget.sessionId);
    if (mounted) {
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
                child: StatusPill(
                  status: summary.status,
                  waiting: summary.hasWaitingState,
                  ended: summary.isEnded,
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
              child: RefreshIndicator(
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
                          await _refreshSessionPage();
                        },
                      ),
                    ],
                  ],
                ),
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
                    await _refreshSessionPage();
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
    final accentTone = activeTurn ? Palette.warning : Palette.accent;

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
                _ComposerChip(
                  text: activeTurn ? 'steer' : 'next',
                  tone: accentTone,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.branch.isEmpty ? summary.source : summary.branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: roundedTextStyle(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Palette.mutedInk,
                    ),
                  ),
                ),
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

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tone.appOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: roundedTextStyle(size: 11, weight: FontWeight.w700, color: tone),
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
