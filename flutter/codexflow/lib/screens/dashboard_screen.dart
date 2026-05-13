import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/app_models.dart';
import '../navigation/app_navigation.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final l10n = AppLocalizations.of(model.languageCode);
    final selectedAgentId = model.selectedStartAgentId;
    final filteredSessions = model.dashboard.sessions
        .where((session) => session.agentId == selectedAgentId)
        .toList();
    final allowedSessionIds = filteredSessions.map((item) => item.id).toSet();
    final filteredApprovals = model.dashboard.approvals
        .where((approval) => allowedSessionIds.contains(approval.threadId))
        .toList();
    final endedCount = filteredSessions
        .where((session) => session.isEnded)
        .length;
    final activeCount = filteredSessions
        .where((session) => session.status == 'active' && !session.isEnded)
        .length;
    final pendingApprovalCount = filteredApprovals.length;
    final workspaceGroups = _workspaceSessionGroups(filteredSessions);

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
                  AgentStatusBadge(
                    connected: model.isAgentOnline,
                    connecting: model.isAgentConnecting,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardHero(
                model: model,
                totalCount: filteredSessions.length,
                endedCount: endedCount,
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
                        l10n.t('dashboard.recentSessions'),
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
                    CapsuleTag(
                      title: l10n.t('nav.approvals'),
                      value: '$pendingApprovalCount',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (filteredSessions.isEmpty)
                PanelCard(
                  compact: true,
                  child: Text(
                    l10n.t('dashboard.noSessions'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Palette.mutedInk,
                    ),
                  ),
                )
              else ...<Widget>[
                ...workspaceGroups.map(
                  (group) => _WorkspaceSessionGroup(
                    key: ValueKey<String>(group.key),
                    group: group,
                  ),
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
    required this.endedCount,
    required this.activeCount,
    required this.pendingApprovalCount,
  });

  final AppModel model;
  final int totalCount;
  final int endedCount;
  final int activeCount;
  final int pendingApprovalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context.watch<AppModel>().languageCode);
    final listenAddr = model.dashboard.agent.listenAddr.isEmpty
        ? model.baseUrlString.replaceFirst(RegExp(r'^https?://'), '')
        : model.dashboard.agent.listenAddr;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AgentStatusBadge(
                connected: model.isAgentOnline,
                connecting: model.isAgentConnecting,
              ),
              const SizedBox(width: 8),
              CapsuleTag(
                title: l10n.t('dashboard.port'),
                value: _portLabel(listenAddr),
              ),
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
            l10n.t('dashboard.heroTitle'),
            style: roundedTextStyle(size: 25, weight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _InlineMetric(
                  label: l10n.t('dashboard.totalSessions'),
                  value: '$totalCount',
                  tone: Palette.softBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: l10n.t('dashboard.ended'),
                  value: '$endedCount',
                  tone: Palette.mutedInk,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: l10n.t('dashboard.running'),
                  value: '$activeCount',
                  tone: Palette.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMetric(
                  label: l10n.t('nav.approvals'),
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
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.ink.appOpacity(0.055),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: color),
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

enum _ProjectPickerMode { recent, custom, none }

class _DashboardComposerState extends State<_DashboardComposer> {
  late final TextEditingController _cwdController;
  late final TextEditingController _promptController;
  final ImagePicker _imagePicker = ImagePicker();
  final List<_DashboardComposerAttachment> _attachments =
      <_DashboardComposerAttachment>[];
  _ProjectPickerMode _projectMode = _ProjectPickerMode.none;
  String _selectedWorkspaceCwd = '';
  late String _lastAgentEndpointId;
  late String _lastStartAgentId;
  bool _isCreating = false;
  bool _isUploadingImage = false;
  String _submitError = '';

  @override
  void initState() {
    super.initState();
    _lastAgentEndpointId = widget.model.selectedAgentEndpointId;
    _lastStartAgentId = widget.model.selectedStartAgentId;
    _resetWorkspaceSelection();
    _cwdController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _DashboardComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final agentEndpointChanged =
        _lastAgentEndpointId != widget.model.selectedAgentEndpointId;
    final startAgentChanged =
        _lastStartAgentId != widget.model.selectedStartAgentId;
    _lastAgentEndpointId = widget.model.selectedAgentEndpointId;
    _lastStartAgentId = widget.model.selectedStartAgentId;

    if (agentEndpointChanged || startAgentChanged) {
      setState(_resetWorkspaceSelection);
      return;
    }

    if (_projectMode == _ProjectPickerMode.custom) {
      return;
    }

    final recentCwds = _recentWorkspaceCwds();
    final hasSelectedRecentWorkspace =
        _projectMode == _ProjectPickerMode.recent &&
        recentCwds.any(
          (cwd) => _workspaceKey(cwd) == _workspaceKey(_selectedWorkspaceCwd),
        );
    if (hasSelectedRecentWorkspace ||
        (_projectMode == _ProjectPickerMode.none &&
            _selectedWorkspaceCwd.isEmpty)) {
      return;
    }

    final cwd = _initialCwd();
    if (cwd != _selectedWorkspaceCwd || _projectMode != _ProjectPickerMode.none) {
      setState(() {
        if (cwd.isEmpty) {
          _projectMode = _ProjectPickerMode.none;
          _selectedWorkspaceCwd = '';
          return;
        }
        _projectMode = _ProjectPickerMode.recent;
        _selectedWorkspaceCwd = cwd;
      });
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
    final l10n = AppLocalizations.of(model.languageCode);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _cwdController,
        _promptController,
      ]),
      builder: (context, _) {
        final cwd = _effectiveCwd;
        final prompt = _promptController.text.trim();
        final canCreate =
            (prompt.isNotEmpty || _attachments.isNotEmpty) &&
            (_projectMode != _ProjectPickerMode.custom || cwd.isNotEmpty) &&
            !_isCreating &&
            !_isUploadingImage;
        return PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CodexTextField(
                controller: _promptController,
                hintText: l10n.t('dashboard.promptHint'),
                minLines: 3,
                maxLines: 6,
                autocapitalization: TextCapitalization.sentences,
              ),
              if (_attachments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final attachment = _attachments[index];
                      return _DashboardAttachmentPreview(
                        attachment: attachment,
                        onRemove: () {
                          setState(() {
                            _attachments.removeWhere(
                              (item) => item.id == attachment.id,
                            );
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OptionChipButton(
                label: '项目',
                value: _projectPickerLabel,
                icon: _projectPickerIcon,
                tone: _projectMode == _ProjectPickerMode.none
                    ? Palette.mutedInk
                    : Palette.softBlue,
                onPressed: () => _showProjectPicker(context),
              ),
              if (_projectMode == _ProjectPickerMode.custom) ...<Widget>[
                const SizedBox(height: 10),
                CodexTextField(
                  controller: _cwdController,
                  hintText: l10n.t('dashboard.cwdHint'),
                  monospaced: true,
                ),
              ],
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
                    label: l10n.t('common.strategy'),
                    value: _policyLabel(model.defaultExecutionPolicy, l10n),
                    icon: _policyIcon(model.defaultExecutionPolicy),
                    tone: _policyTone(model.defaultExecutionPolicy),
                    onPressed: () => _showPolicyPicker(context, model),
                  ),
                  OptionChipButton(
                    label: l10n.t('common.model'),
                    value: model.defaultModel,
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () => _showModelPicker(context, model),
                  ),
                  OptionChipButton(
                    label: l10n.t('common.reasoning'),
                    value: _reasoningLabel(model.defaultReasoning, l10n),
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
                  _RoundIconButton(
                    icon: _isUploadingImage
                        ? Icons.hourglass_empty_rounded
                        : Icons.add_rounded,
                    color: Palette.ink,
                    onPressed: _isUploadingImage || _isCreating
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            await _pickAndUploadImage();
                          },
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: l10n.t('dashboard.switchLocalMode'),
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
    final l10n = AppLocalizations.of(model.languageCode);
    final cwd = _effectiveCwd;
    final prompt = _promptController.text.trim();
    if ((prompt.isEmpty && _attachments.isEmpty) ||
        (_projectMode == _ProjectPickerMode.custom && cwd.isEmpty) ||
        _isCreating ||
        _isUploadingImage) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isCreating = true;
      _submitError = '';
    });
    final createdSession = await model.startSession(
      cwd: cwd,
      prompt: prompt,
      agentId: model.selectedStartAgentId,
      imageUploadIds: _attachments.map((item) => item.uploadId).toList(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isCreating = false;
      if (createdSession == null) {
        _submitError = model.connectionError.isNotEmpty
            ? model.connectionError
            : l10n.t('dashboard.createFailed');
      }
    });
    if (createdSession != null) {
      _promptController.clear();
      _attachments.clear();
      openSessionChatPage(createdSession.id);
    }
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
          _DashboardComposerAttachment(
            id: '${DateTime.now().microsecondsSinceEpoch}-${uploaded.id}',
            uploadId: uploaded.id,
            bytes: bytes,
          ),
        );
        _submitError = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  String _initialCwd() {
    final sessions = widget.model.dashboard.sessions.where(
      (session) => session.agentId == widget.model.selectedStartAgentId,
    );
    for (final session in sessions) {
      if (session.cwd.trim().isNotEmpty) {
        return session.cwd.trim();
      }
    }
    return '';
  }

  void _resetWorkspaceSelection() {
    final initialCwd = _initialCwd();
    _projectMode = initialCwd.isEmpty
        ? _ProjectPickerMode.none
        : _ProjectPickerMode.recent;
    _selectedWorkspaceCwd = initialCwd;
    _submitError = '';
  }

  String get _effectiveCwd {
    switch (_projectMode) {
      case _ProjectPickerMode.recent:
        return _selectedWorkspaceCwd.trim();
      case _ProjectPickerMode.custom:
        return _cwdController.text.trim();
      case _ProjectPickerMode.none:
        return '';
    }
  }

  String get _projectPickerLabel {
    switch (_projectMode) {
      case _ProjectPickerMode.recent:
        return _workspaceTitle(_selectedWorkspaceCwd);
      case _ProjectPickerMode.custom:
        final cwd = _cwdController.text.trim();
        return cwd.isEmpty ? '添加新项目' : _workspaceTitle(cwd);
      case _ProjectPickerMode.none:
        return '不使用项目';
    }
  }

  IconData get _projectPickerIcon {
    switch (_projectMode) {
      case _ProjectPickerMode.recent:
      case _ProjectPickerMode.custom:
        return Icons.folder_open_rounded;
      case _ProjectPickerMode.none:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  List<String> _recentWorkspaceCwds() {
    final seen = <String>{};
    final result = <String>[];
    final sessions = widget.model.dashboard.sessions.where(
      (session) => session.agentId == widget.model.selectedStartAgentId,
    );
    for (final session in sessions) {
      final cwd = session.cwd.trim();
      if (cwd.isEmpty) {
        continue;
      }
      final key = _workspaceKey(cwd);
      if (seen.add(key)) {
        result.add(cwd);
      }
    }
    return result;
  }

  Future<void> _showProjectPicker(BuildContext context) async {
    final recentCwds = _recentWorkspaceCwds();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: '选择项目',
        children: <Widget>[
          ...recentCwds.map(
            (cwd) => _OptionSheetTile(
              title: _workspaceTitle(cwd),
              subtitle: cwd,
              icon: Icons.folder_open_rounded,
              selected:
                  _projectMode == _ProjectPickerMode.recent &&
                  _workspaceKey(_selectedWorkspaceCwd) == _workspaceKey(cwd),
              onTap: () {
                setState(() {
                  _projectMode = _ProjectPickerMode.recent;
                  _selectedWorkspaceCwd = cwd;
                  _submitError = '';
                });
                Navigator.of(context).pop();
              },
            ),
          ),
          _OptionSheetTile(
            title: '添加新项目',
            subtitle: '手动输入工作区路径',
            icon: Icons.create_new_folder_outlined,
            selected: _projectMode == _ProjectPickerMode.custom,
            onTap: () {
              setState(() {
                _projectMode = _ProjectPickerMode.custom;
                _submitError = '';
              });
              Navigator.of(context).pop();
            },
          ),
          _OptionSheetTile(
            title: '不使用项目',
            subtitle: '创建无工作区的对话会话',
            icon: Icons.chat_bubble_outline_rounded,
            selected: _projectMode == _ProjectPickerMode.none,
            onTap: () {
              setState(() {
                _projectMode = _ProjectPickerMode.none;
                _selectedWorkspaceCwd = '';
                _submitError = '';
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAgentPicker(BuildContext context, AppModel model) async {
    final l10n = AppLocalizations.of(model.languageCode);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        title: l10n.t('dashboard.selectAgent'),
        children: model.startAgentOptions
            .map(
              (agent) => _OptionSheetTile(
                title: agent.name,
                subtitle: agent.available
                    ? agent.id
                    : l10n.t('dashboard.unavailable'),
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
    final l10n = AppLocalizations.of(model.languageCode);
    await _showValuePicker(
      context: context,
      title: l10n.t('settings.defaultPolicy'),
      value: model.defaultExecutionPolicy,
      values: <String, String>{
        'ask': l10n.t('policy.ask'),
        'review': l10n.t('policy.review'),
        'full': l10n.t('policy.full'),
      },
      iconForValue: _policyIcon,
      toneForValue: _policyTone,
      onSelected: model.updateDefaultExecutionPolicy,
    );
  }

  Future<void> _showModelPicker(BuildContext context, AppModel model) async {
    final l10n = AppLocalizations.of(model.languageCode);
    await _showValuePicker(
      context: context,
      title: l10n.t('settings.defaultModel'),
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
    final l10n = AppLocalizations.of(model.languageCode);
    await _showValuePicker(
      context: context,
      title: l10n.t('settings.reasoningDepth'),
      value: model.defaultReasoning,
      values: <String, String>{
        'low': l10n.t('reasoning.low'),
        'medium': l10n.t('reasoning.medium'),
        'high': l10n.t('reasoning.high'),
        'xhigh': l10n.t('reasoning.xhigh'),
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

  String _policyLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'ask':
        return l10n.t('policy.ask');
      case 'full':
        return l10n.t('policy.full');
      default:
        return l10n.t('policy.review');
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

  String _reasoningLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'low':
        return l10n.t('reasoning.low');
      case 'high':
        return l10n.t('reasoning.high');
      case 'xhigh':
        return l10n.t('reasoning.xhigh');
      default:
        return l10n.t('reasoning.medium');
    }
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: Palette.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
    this.icon,
    this.tone,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final effectiveTone = tone ?? Palette.softBlue;
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
                  Icon(
                    icon,
                    size: 20,
                    color: enabled
                        ? (tone ?? Palette.mutedInk)
                        : Palette.faintInk,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: roundedTextStyle(
                          size: 14,
                          weight: FontWeight.w700,
                          color: enabled
                              ? (tone ?? Palette.ink)
                              : Palette.faintInk,
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

class _DashboardAttachmentPreview extends StatelessWidget {
  const _DashboardAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final _DashboardComposerAttachment attachment;
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

class _DashboardComposerAttachment {
  _DashboardComposerAttachment({
    required this.id,
    required this.uploadId,
    required this.bytes,
  });

  final String id;
  final String uploadId;
  final Uint8List bytes;
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

class _WorkspaceSessionGroupData {
  const _WorkspaceSessionGroupData({
    required this.key,
    required this.title,
    required this.cwd,
    required this.sessions,
  });

  final String key;
  final String title;
  final String cwd;
  final List<SessionSummary> sessions;

  bool get isConversationGroup => key == _conversationWorkspaceKey;
}

const String _conversationWorkspaceKey = '__conversation_without_workspace__';
const int _initialVisibleSessionCount = 5;
const int _additionalVisibleSessionCount = 20;

List<_WorkspaceSessionGroupData> _workspaceSessionGroups(
  List<SessionSummary> sessions,
) {
  final grouped = <String, List<SessionSummary>>{};
  final cwdByKey = <String, String>{};
  for (final session in sessions) {
    final key = _workspaceKey(session.cwd);
    grouped.putIfAbsent(key, () => <SessionSummary>[]).add(session);
    cwdByKey.putIfAbsent(key, () => session.cwd.trim());
  }

  final groups = grouped.entries
      .map(
        (entry) => _WorkspaceSessionGroupData(
          key: entry.key,
          title: _workspaceTitle(cwdByKey[entry.key] ?? ''),
          cwd: cwdByKey[entry.key] ?? '',
          sessions: entry.value,
        ),
      )
      .toList();
  groups.sort((left, right) {
    final leftUpdated = left.sessions.fold<int>(
      0,
      (value, session) => value > session.updatedAt ? value : session.updatedAt,
    );
    final rightUpdated = right.sessions.fold<int>(
      0,
      (value, session) => value > session.updatedAt ? value : session.updatedAt,
    );
    return rightUpdated.compareTo(leftUpdated);
  });
  return groups;
}

String _workspaceKey(String cwd) {
  final trimmed = cwd.trim();
  if (trimmed.isEmpty) {
    return _conversationWorkspaceKey;
  }
  return trimmed
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '')
      .toLowerCase();
}

String _workspaceTitle(String cwd) {
  final trimmed = cwd.trim();
  if (trimmed.isEmpty) {
    return '对话';
  }
  final normalized = trimmed
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  final parts = normalized.split('/').where((part) => part.trim().isNotEmpty);
  final last = parts.isEmpty ? normalized : parts.last.trim();
  if (last.isEmpty) {
    return '对话';
  }
  final runes = last.runes.toList();
  final first = String.fromCharCode(runes.first).toUpperCase();
  return '$first${String.fromCharCodes(runes.skip(1))}';
}

class _WorkspaceSessionGroup extends StatefulWidget {
  const _WorkspaceSessionGroup({super.key, required this.group});

  final _WorkspaceSessionGroupData group;

  @override
  State<_WorkspaceSessionGroup> createState() => _WorkspaceSessionGroupState();
}

class _WorkspaceSessionGroupState extends State<_WorkspaceSessionGroup> {
  bool _expanded = false;
  int _visibleSessionCount = _initialVisibleSessionCount;

  @override
  void didUpdateWidget(covariant _WorkspaceSessionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.key != widget.group.key) {
      _expanded = false;
      _visibleSessionCount = _initialVisibleSessionCount;
      return;
    }
    if (_visibleSessionCount > widget.group.sessions.length) {
      _visibleSessionCount = widget.group.sessions.length;
    }
    if (_visibleSessionCount < _initialVisibleSessionCount) {
      _visibleSessionCount = _initialVisibleSessionCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final visibleSessions = group.sessions
        .take(_visibleSessionCount)
        .toList(growable: false);
    final hiddenSessionCount = group.sessions.length - visibleSessions.length;
    final icon = group.isConversationGroup
        ? Icons.chat_bubble_outline_rounded
        : Icons.folder_open_rounded;
    final tone = group.isConversationGroup ? Palette.accent : Palette.softBlue;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PanelCard(
        compact: true,
        child: Column(
          children: <Widget>[
            InkWell(
              onTap: () => setState(() {
                _expanded = !_expanded;
                if (_expanded) {
                  _visibleSessionCount = _initialVisibleSessionCount;
                }
              }),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tone.appOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: tone),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            group.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: roundedTextStyle(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (group.cwd.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              group.cwd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: roundedTextStyle(
                                size: 11,
                                weight: FontWeight.w500,
                                color: Palette.mutedInk,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    CapsuleTag(title: '会话', value: '${group.sessions.length}'),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: Palette.mutedInk,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: 10),
              ...visibleSessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SessionRow(session: session),
                ),
              ),
              if (hiddenSessionCount > 0) ...<Widget>[
                const SizedBox(height: 8),
                _ShowMoreSessionsButton(
                  onPressed: () => setState(() {
                    _visibleSessionCount += _additionalVisibleSessionCount;
                  }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ShowMoreSessionsButton extends StatelessWidget {
  const _ShowMoreSessionsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_more_rounded, size: 18),
        label: const Text('展开显示'),
        style: TextButton.styleFrom(
          foregroundColor: Palette.softBlue,
          textStyle: roundedTextStyle(size: 13, weight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
    final capabilities = model.capabilitiesForSession(session);
    final canArchive = capabilities.supportsArchive;
    return PanelCard(
      compact: true,
      child: InkWell(
        onTap: () => _openDetail(context),
        onLongPress: canArchive ? () => _showSessionActions(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _firstMessageLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: roundedTextStyle(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
            ),
            if (_isRunning) ...<Widget>[
              const SizedBox(width: 8),
              const _SessionActivitySpinner(),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    openSessionChatPage(session.id);
  }

  Future<void> _showSessionActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.canvas,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.archive_outlined,
                    color: Palette.danger,
                  ),
                  title: Text(
                    '归档',
                    style: roundedTextStyle(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Palette.danger,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await context.read<AppModel>().archiveSession(session);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _firstMessageLabel {
    final preview = session.previewSummary.trim();
    if (preview.isNotEmpty) {
      return preview;
    }
    final name = session.displayName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return '空会话';
  }

  bool get _isRunning => session.lastTurnStatus == 'inProgress';
}

class _SessionActivitySpinner extends StatelessWidget {
  const _SessionActivitySpinner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '进行中',
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.accent.appOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Palette.accent,
          ),
        ),
      ),
    );
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
