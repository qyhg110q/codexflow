import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'approval_screen.dart';
import 'session_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final selectedAgentId = model.selectedStartAgentId;
    final filteredSessions = model.dashboard.sessions
        .where((session) => session.agentId == selectedAgentId)
        .toList();
    final allowedSessionIds = filteredSessions.map((item) => item.id).toSet();
    final filteredApprovals = model.dashboard.approvals
        .where((approval) => allowedSessionIds.contains(approval.threadId))
        .toList();
    final loadedCount = filteredSessions
        .where((session) => session.loaded)
        .length;
    final activeCount = filteredSessions
        .where((session) => session.status == 'active' && !session.isEnded)
        .length;
    final pendingApprovalCount = filteredApprovals.length;

    final managedSessions = filteredSessions
        .where((session) => session.lifecycleStage == 'managed')
        .toList();
    final endedSessions = filteredSessions
        .where((session) => session.lifecycleStage == 'ended')
        .toList();
    final runtimeSessions = filteredSessions
        .where((session) => session.lifecycleStage == 'runtime_available')
        .toList();
    final historySessions = filteredSessions
        .where((session) => session.lifecycleStage == 'history_only')
        .toList();

    return Scaffold(
      backgroundColor: Palette.canvas,
      body: PageScaffold(
        child: RefreshIndicator(
          color: Palette.accent,
          onRefresh: model.refreshDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'CodexFlow',
                    style: roundedTextStyle(size: 19, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  _AgentSwitchButton(model: model),
                  const Spacer(),
                  AgentStatusBadge(connected: model.isAgentOnline),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardHero(
                model: model,
                totalCount: filteredSessions.length,
                loadedCount: loadedCount,
                activeCount: activeCount,
                pendingApprovalCount: pendingApprovalCount,
              ),
              if (model.operationNotice.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (model.operationNoticeIsError
                                ? Palette.danger
                                : Palette.success)
                            .appOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    model.operationNotice,
                    style: roundedTextStyle(
                      size: 12,
                      weight: FontWeight.w500,
                      color: model.operationNoticeIsError
                          ? Palette.danger
                          : Palette.success,
                    ),
                  ),
                ),
              ],
              if (!model.isAgentOnline &&
                  model.agentConnectionError.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.danger.appOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    model.agentConnectionError,
                    style: roundedTextStyle(
                      size: 12,
                      weight: FontWeight.w500,
                      color: Palette.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _DashboardComposer(model: model),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '最近会话',
                        style: roundedTextStyle(
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${filteredSessions.length}',
                        style: roundedTextStyle(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Palette.mutedInk,
                        ),
                      ),
                    ],
                  ),
                  if (pendingApprovalCount > 0) ...<Widget>[
                    const Spacer(),
                    CapsuleTag(title: '审批', value: '$pendingApprovalCount'),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (filteredSessions.isEmpty)
                const PanelCard(
                  compact: true,
                  child: Text(
                    '暂时没有会话。确认 Agent 连接后，可以直接在上方输入第一条要求。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Palette.mutedInk,
                    ),
                  ),
                )
              else ...<Widget>[
                if (managedSessions.isNotEmpty)
                  _SessionGroup(
                    title: '已接管',
                    helper: '',
                    sessions: managedSessions,
                  ),
                if (endedSessions.isNotEmpty)
                  _SessionGroup(
                    title: '已结束',
                    helper: '',
                    sessions: endedSessions,
                  ),
                if (runtimeSessions.isNotEmpty)
                  _SessionGroup(
                    title: selectedAgentId == 'claude' ? '可接管 Runtime' : '待接管',
                    helper: '',
                    sessions: runtimeSessions,
                  ),
                if (historySessions.isNotEmpty)
                  _SessionGroup(
                    title: selectedAgentId == 'claude' ? '历史导入' : '历史会话',
                    helper: '',
                    sessions: historySessions,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.model,
    required this.totalCount,
    required this.loadedCount,
    required this.activeCount,
    required this.pendingApprovalCount,
  });

  final AppModel model;
  final int totalCount;
  final int loadedCount;
  final int activeCount;
  final int pendingApprovalCount;

  @override
  Widget build(BuildContext context) {
    final listenAddr = model.dashboard.agent.listenAddr.isEmpty
        ? model.baseUrlString.replaceFirst(RegExp(r'^https?://'), '')
        : model.dashboard.agent.listenAddr;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AgentStatusBadge(connected: model.isAgentOnline),
              const SizedBox(width: 8),
              CapsuleTag(title: '端口', value: _portLabel(listenAddr)),
              const Spacer(),
              Text(
                _todayLabel(),
                style: roundedTextStyle(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Palette.faintInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '创建或接管一个会话',
            style: roundedTextStyle(size: 25, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '当前入口：${_agentName(model)}，${model.localMode ? '本地模式' : '远程模式'}，默认 ${model.defaultModel} / ${_reasoningLabel(model.defaultReasoning)}。',
            style: roundedTextStyle(
              size: 13,
              weight: FontWeight.w500,
              color: Palette.mutedInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _InlineMetric(
                  label: '总会话',
                  value: '$totalCount',
                  tone: Palette.softBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: '已接管',
                  value: '$loadedCount',
                  tone: Palette.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: '运行',
                  value: '$activeCount',
                  tone: Palette.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: '审批',
                  value: '$pendingApprovalCount',
                  tone: pendingApprovalCount > 0
                      ? Palette.warning
                      : Palette.mutedInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _agentName(AppModel model) {
    final selected = model.selectedAgentOption;
    return selected?.name ?? model.selectedStartAgentId;
  }

  String _portLabel(String listenAddr) {
    final match = RegExp(r':(\d+)(?:/)?$').firstMatch(listenAddr.trim());
    if (match != null) {
      return match.group(1)!;
    }
    return '4318';
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.month}/${now.day}';
  }

  String _reasoningLabel(String value) {
    switch (value) {
      case 'low':
        return '低推理';
      case 'high':
        return '高推理';
      case 'xhigh':
        return '超高推理';
      default:
        return '中推理';
    }
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.ink.appOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: roundedTextStyle(
              size: 21,
              weight: FontWeight.w800,
              color: tone,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: roundedTextStyle(
              size: 11,
              weight: FontWeight.w700,
              color: Palette.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () async => onPressed() : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? Palette.ink : Palette.ink.appOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  size: 22,
                  color: enabled ? Colors.white : Palette.mutedInk,
                ),
        ),
      ),
    );
  }
}

class _DashboardComposer extends StatefulWidget {
  const _DashboardComposer({required this.model});

  final AppModel model;

  @override
  State<_DashboardComposer> createState() => _DashboardComposerState();
}

class _DashboardComposerState extends State<_DashboardComposer> {
  late final TextEditingController _cwdController;
  late final TextEditingController _promptController;
  bool _isCreating = false;
  String _submitError = '';

  @override
  void initState() {
    super.initState();
    _cwdController = TextEditingController(text: _initialCwd());
    _promptController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _DashboardComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cwdController.text.trim().isNotEmpty) {
      return;
    }
    final cwd = _initialCwd();
    if (cwd.isNotEmpty) {
      _cwdController.text = cwd;
    }
  }

  @override
  void dispose() {
    _cwdController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _cwdController,
        _promptController,
      ]),
      builder: (context, _) {
        final cwd = _cwdController.text.trim();
        final prompt = _promptController.text.trim();
        final canCreate = cwd.isNotEmpty && prompt.isNotEmpty && !_isCreating;
        return PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CodexTextField(
                controller: _promptController,
                hintText: '可向 Codex 询问任何事。输入第一条要求创建会话。',
                minLines: 3,
                maxLines: 6,
                autocapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 10),
              CodexTextField(
                controller: _cwdController,
                hintText: '工作目录，例如 D:\\repo\\project',
                monospaced: true,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  OptionChipButton(
                    label: 'Agent',
                    value:
                        model.selectedAgentOption?.name ??
                        model.selectedStartAgentId,
                    icon: Icons.memory_rounded,
                    onPressed: () => _showAgentPicker(context, model),
                  ),
                  OptionChipButton(
                    label: '策略',
                    value: _policyLabel(model.defaultExecutionPolicy),
                    icon: Icons.verified_user_rounded,
                    onPressed: () => _showPolicyPicker(context, model),
                  ),
                  OptionChipButton(
                    label: '模型',
                    value: model.defaultModel,
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () => _showModelPicker(context, model),
                  ),
                  OptionChipButton(
                    label: '推理',
                    value: _reasoningLabel(model.defaultReasoning),
                    onPressed: () => _showReasoningPicker(context, model),
                  ),
                ],
              ),
              if (_submitError.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _submitError,
                  style: roundedTextStyle(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Palette.danger,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: '切换本地模式',
                    style: IconButton.styleFrom(
                      backgroundColor: model.localMode
                          ? Palette.accent.appOpacity(0.12)
                          : Palette.ink.appOpacity(0.06),
                    ),
                    onPressed: () => model.updateLocalMode(!model.localMode),
                    icon: Icon(
                      model.localMode
                          ? Icons.lan_rounded
                          : Icons.public_rounded,
                      color: model.localMode
                          ? Palette.accent
                          : Palette.mutedInk,
                    ),
                  ),
                  const Spacer(),
                  _ComposerSendButton(
                    enabled: canCreate,
                    loading: _isCreating,
                    onPressed: () => _createSession(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final model = context.read<AppModel>();
    final cwd = _cwdController.text.trim();
    final prompt = _promptController.text.trim();
    if (cwd.isEmpty || prompt.isEmpty || _isCreating) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isCreating = true;
      _submitError = '';
    });
    final navigator = Navigator.of(context);
    final createdSession = await model.startSession(
      cwd: cwd,
      prompt: prompt,
      agentId: model.selectedStartAgentId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isCreating = false;
      if (createdSession == null) {
        _submitError = model.connectionError.isNotEmpty
            ? model.connectionError
            : '创建会话失败，请检查 Agent 状态和输入内容。';
      }
    });
    if (createdSession != null) {
      _promptController.clear();
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(sessionId: createdSession.id),
        ),
      );
    }
  }

  String _initialCwd() {
    final sessions = widget.model.dashboard.sessions;
    for (final session in sessions) {
      if (session.cwd.trim().isNotEmpty) {
        return session.cwd.trim();
      }
    }
    return '';
  }

  Future<void> _showAgentPicker(BuildContext context, AppModel model) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '选择 Agent',
        children: model.startAgentOptions
            .map(
              (agent) => _OptionSheetTile(
                title: agent.name,
                subtitle: agent.available ? agent.id : '当前不可用',
                selected: agent.id == model.selectedStartAgentId,
                enabled: agent.available,
                onTap: () {
                  model.setSelectedStartAgent(agent.id);
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
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
    this.subtitle = '',
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: roundedTextStyle(
                          size: 14,
                          weight: FontWeight.w700,
                          color: enabled ? Palette.ink : Palette.faintInk,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: roundedTextStyle(
                            size: 12,
                            weight: FontWeight.w500,
                            color: Palette.mutedInk,
                          ),
                        ),
                      ],
                    ],
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

class _AgentSwitchButton extends StatelessWidget {
  const _AgentSwitchButton({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    AgentOption? selected;
    for (final option in model.startAgentOptions) {
      if (option.id == model.selectedStartAgentId) {
        selected = option;
        break;
      }
    }
    final selectedName = selected?.name ?? 'Codex';

    return PopupMenuButton<String>(
      tooltip: '切换 Agent',
      onSelected: (String value) {
        model.setSelectedStartAgent(value);
      },
      itemBuilder: (BuildContext context) {
        return model.startAgentOptions.map((option) {
          final isSelected = option.id == model.selectedStartAgentId;
          return PopupMenuItem<String>(
            value: option.id,
            enabled: option.available,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    option.name,
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w600,
                      color: option.available ? Palette.ink : Palette.mutedInk,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Palette.softBlue,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.account_tree_rounded,
              size: 14,
              color: Palette.ink,
            ),
            const SizedBox(width: 6),
            Text(
              selectedName,
              style: roundedTextStyle(size: 12, weight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 14, color: Palette.ink),
          ],
        ),
      ),
    );
  }
}

class _SessionGroup extends StatelessWidget {
  const _SessionGroup({
    required this.title,
    required this.helper,
    required this.sessions,
  });

  final String title;
  final String helper;
  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: roundedTextStyle(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '${sessions.length}',
                style: roundedTextStyle(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Palette.mutedInk,
                ),
              ),
            ],
          ),
          if (helper.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              helper,
              style: roundedTextStyle(
                size: 13,
                weight: FontWeight.w500,
                color: Palette.mutedInk,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SessionRow(session: session),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final sessionApprovals = model.approvalsFor(session.id);
    final capabilities = model.capabilitiesForSession(session);
    final canPrimaryAction = (session.isEnded || !session.loaded)
        ? model.canResumeSession(session)
        : true;
    return PanelCard(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => _openDetail(context),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AgentMark(agentId: session.agentId),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  session.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: roundedTextStyle(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusPill(
                                status: session.status,
                                waiting: session.hasWaitingState,
                                ended: session.isEnded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            session.previewSummary.isEmpty
                                ? session.cwd
                                : session.previewSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: roundedTextStyle(
                              size: 12,
                              weight: FontWeight.w500,
                              color: Palette.mutedInk,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      CapsuleTag(
                        title: '托管',
                        value: session.loaded ? '已接管' : '未接管',
                      ),
                      if (session.isClaudeSession) ...<Widget>[
                        const SizedBox(width: 8),
                        CapsuleTag(
                          title: '链路',
                          value: session.runtimeAvailable
                              ? 'Runtime'
                              : 'History',
                        ),
                        if (session.loaded &&
                            session.runtimeAttachMode.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          CapsuleTag(
                            title: '接管',
                            value:
                                session.runtimeAttachMode == 'resumed_existing'
                                ? '现有 Runtime'
                                : (session.runtimeAttachMode ==
                                          'opened_from_history'
                                      ? '历史新开'
                                      : '新建 Runtime'),
                          ),
                        ],
                      ],
                      const SizedBox(width: 8),
                      CapsuleTag(
                        title: '分支',
                        value: session.branch.isEmpty ? '未识别' : session.branch,
                      ),
                      const SizedBox(width: 8),
                      CapsuleTag(title: '更新', value: session.updatedAtDisplay),
                      if (session.lastTurnStatus.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        CapsuleTag(
                          title: '最近',
                          value: _lastTurnStatusLabel(session.lastTurnStatus),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _compactHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: roundedTextStyle(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _hintTone,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 108,
                child: ActionButton(
                  title: _primaryButtonTitle,
                  background: _primaryBackground,
                  foreground: _primaryForeground,
                  borderColor: _primaryBorder,
                  enabled: canPrimaryAction,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  onPressed: () => _handlePrimaryAction(context),
                ),
              ),
            ],
          ),
          if (capabilities.supportsApprovals &&
              session.pendingApprovals > 0) ...<Widget>[
            const SizedBox(height: 10),
            ActionButton(
              title: '处理审批 (${session.pendingApprovals})',
              background: Palette.warning.appOpacity(0.14),
              foreground: Palette.warning,
              borderColor: Palette.warning.appOpacity(0.22),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SessionApprovalSheet(
                    title: session.displayName,
                    approvals: sessionApprovals,
                  ),
                );
              },
            ),
          ],
          if (capabilities.supportsArchive && session.isEnded) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await context.read<AppModel>().archiveSession(session);
              },
              icon: const Icon(Icons.archive_outlined, size: 15),
              label: const Text('归档'),
              style: TextButton.styleFrom(
                foregroundColor: Palette.danger,
                textStyle: roundedTextStyle(size: 12, weight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailScreen(sessionId: session.id),
      ),
    );
  }

  Future<void> _handlePrimaryAction(BuildContext context) async {
    final model = context.read<AppModel>();
    if (session.isEnded || !session.loaded) {
      await model.resumeSession(session);
      return;
    }
    await model.endSession(session);
  }

  String get _primaryButtonTitle {
    if (session.isEnded) {
      return '重新接管';
    }
    if (!session.loaded) {
      if (session.isClaudeSession && !session.runtimeAvailable) {
        return '当前无 Runtime';
      }
      return '接管到 CodexFlow';
    }
    return session.lastTurnStatus == 'inProgress' ? '中断并结束' : '结束会话';
  }

  Color get _primaryBackground {
    if (session.isEnded || !session.loaded) {
      return Palette.softBlue;
    }
    return Palette.danger.appOpacity(0.12);
  }

  Color get _primaryForeground {
    if (session.isEnded || !session.loaded) {
      return Colors.white;
    }
    return Palette.danger;
  }

  Color get _primaryBorder {
    if (session.isEnded || !session.loaded) {
      return Colors.transparent;
    }
    return Palette.danger.appOpacity(0.20);
  }

  String get _compactHint {
    if (session.isEnded) {
      return '历史保留，可重新接管';
    }
    if (session.pendingApprovals > 0) {
      return '${session.pendingApprovals} 个审批等待处理';
    }
    if (session.lastTurnStatus == 'inProgress') {
      return '运行中，可进入继续 steer';
    }
    if (session.loaded) {
      return '可直接发送下一轮';
    }
    if (session.isClaudeSession && session.runtimeAvailable) {
      return 'Runtime 可接管';
    }
    if (session.isClaudeSession && session.historyAvailable) {
      return 'History 可查看';
    }
    return '历史会话，可接管';
  }

  Color get _hintTone {
    if (session.isEnded) {
      return Palette.mutedInk;
    }
    if (session.pendingApprovals > 0) {
      return Palette.warning;
    }
    if (session.lastTurnStatus == 'inProgress') {
      return Palette.accent;
    }
    if (session.loaded) {
      return Palette.success;
    }
    return Palette.softBlue;
  }

  String _lastTurnStatusLabel(String status) {
    switch (status) {
      case 'inProgress':
        return '运行中';
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }
}

class NewSessionSheet extends StatefulWidget {
  const NewSessionSheet({super.key});

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  late final TextEditingController _cwdController;
  late final TextEditingController _promptController;
  bool _isCreating = false;
  String _submitError = '';

  @override
  void initState() {
    super.initState();
    _cwdController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _cwdController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _cwdController,
        _promptController,
      ]),
      builder: (BuildContext context, Widget? child) {
        final trimmedCwd = _cwdController.text.trim();
        final trimmedPrompt = _promptController.text.trim();
        final canCreate = trimmedCwd.isNotEmpty && trimmedPrompt.isNotEmpty;

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.7,
          maxChildSize: 0.96,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Palette.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Palette.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        centerTitle: true,
                        title: Text(
                          '新建会话',
                          style: roundedTextStyle(
                            size: 17,
                            weight: FontWeight.w600,
                          ),
                        ),
                        leading: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            '关闭',
                            style: roundedTextStyle(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Palette.softBlue,
                            ),
                          ),
                        ),
                      ),
                      body: PageScaffold(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                          children: <Widget>[
                            PanelCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Palette.softBlue.appOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '受控会话',
                                          style: roundedTextStyle(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: Palette.softBlue,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '2 项必填',
                                        style: roundedTextStyle(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: Palette.mutedInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '新建会话',
                                    style: roundedTextStyle(
                                      size: 26,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '填写目录和首条提示，CodexFlow 会立即建立一个可继续的会话。',
                                    style: roundedTextStyle(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: Palette.mutedInk,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        '工作目录',
                                        style: roundedTextStyle(
                                          size: 14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '绝对路径或 ~/repo',
                                        style: roundedTextStyle(
                                          size: 11,
                                          weight: FontWeight.w500,
                                          color: Palette.mutedInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  CodexTextField(
                                    controller: _cwdController,
                                    hintText:
                                        '/Users/hebicheng/workspace/aicoding-helper',
                                    monospaced: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        '首条提示',
                                        style: roundedTextStyle(
                                          size: 14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        trimmedPrompt.isEmpty
                                            ? '未填写'
                                            : '${trimmedPrompt.length} 字',
                                        style: roundedTextStyle(
                                          size: 11,
                                          weight: FontWeight.w500,
                                          color: trimmedPrompt.isEmpty
                                              ? Palette.mutedInk
                                              : Palette.softBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  CodexTextField(
                                    controller: _promptController,
                                    hintText: '例如：继续实现剩余部分，并补上验证。',
                                    maxLines: 7,
                                    minLines: 7,
                                    autocapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.auto_awesome,
                                        size: 14,
                                        color: Palette.softBlue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '支持 `~/...` 路径，创建后会立即出现在会话列表。',
                                          style: roundedTextStyle(
                                            size: 12,
                                            weight: FontWeight.w500,
                                            color: Palette.mutedInk,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_submitError.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Palette.danger.appOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _submitError,
                                        style: roundedTextStyle(
                                          size: 13,
                                          weight: FontWeight.w500,
                                          color: Palette.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  ActionButton(
                                    title: _isCreating ? '创建中…' : '创建会话',
                                    background: Palette.accent,
                                    foreground: Colors.white,
                                    fontSize: 14,
                                    icon: _isCreating ? null : Icons.add,
                                    enabled: canCreate && !_isCreating,
                                    onPressed: () async {
                                      if (!canCreate || _isCreating) {
                                        return;
                                      }
                                      final appModel = context.read<AppModel>();
                                      final navigator = Navigator.of(context);
                                      FocusScope.of(context).unfocus();
                                      setState(() {
                                        _isCreating = true;
                                        _submitError = '';
                                      });

                                      final createdSession = await appModel
                                          .startSession(
                                            cwd: trimmedCwd,
                                            prompt: trimmedPrompt,
                                            agentId:
                                                appModel.selectedStartAgentId,
                                          );

                                      if (!mounted) {
                                        return;
                                      }

                                      if (createdSession != null) {
                                        navigator.pop();
                                      } else {
                                        setState(() {
                                          _isCreating = false;
                                          final connectionError =
                                              appModel.connectionError;
                                          _submitError = connectionError.isEmpty
                                              ? '创建会话失败，请检查 Agent 状态和输入内容。'
                                              : connectionError;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
