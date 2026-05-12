import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class ApprovalList extends StatelessWidget {
  const ApprovalList({
    super.key,
    required this.approvals,
    required this.showSessionLabel,
  });

  final List<PendingRequestView> approvals;
  final bool showSessionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: approvals
          .map(
            (approval) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ApprovalCard(
                approval: approval,
                showSessionLabel: showSessionLabel,
              ),
            ),
          )
          .toList(),
    );
  }
}

class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.approval,
    required this.showSessionLabel,
  });

  final PendingRequestView approval;
  final bool showSessionLabel;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      compact: true,
      child: ApprovalCardBody(
        approval: approval,
        showSessionLabel: showSessionLabel,
        embedded: false,
      ),
    );
  }
}

class ApprovalCardBody extends StatefulWidget {
  const ApprovalCardBody({
    super.key,
    required this.approval,
    required this.showSessionLabel,
    required this.embedded,
  });

  final PendingRequestView approval;
  final bool showSessionLabel;
  final bool embedded;

  @override
  State<ApprovalCardBody> createState() => _ApprovalCardBodyState();
}

class _ApprovalCardBodyState extends State<ApprovalCardBody> {
  late final TextEditingController _replyController;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final approval = widget.approval;
    final fields = _fieldRows(model, approval);
    return Container(
      padding: widget.embedded ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: widget.embedded
          ? BoxDecoration(
              color: Palette.warning.appOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.warning.appOpacity(0.18)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _KindChip(kind: approval.kind),
              const Spacer(),
              if (widget.showSessionLabel)
                Flexible(
                  child: Text(
                    _sessionLabel(model, approval),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: roundedTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: Palette.mutedInk,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _kindTitle(approval.kind),
                      style: roundedTextStyle(
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      approval.summary.isEmpty
                          ? _riskSummary(approval)
                          : approval.summary,
                      style: roundedTextStyle(
                        size: 13,
                        weight: FontWeight.w500,
                        color: Palette.mutedInk,
                        height: 1.45,
                      ),
                    ),
                    if (approval.reason.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        approval.reason,
                        style: roundedTextStyle(
                          size: 12,
                          weight: FontWeight.w500,
                          color: Palette.mutedInk,
                        ),
                      ),
                    ],
                    if (_firstQuestion(approval) != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _firstQuestion(approval)!.question,
                        style: roundedTextStyle(
                          size: 12,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (fields.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ApprovalField(label: field.$1, value: field.$2),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (approval.kind == 'userInput')
            _buildUserInputActions(context)
          else
            _buildChoiceButtons(context),
        ],
      ),
    );
  }

  Widget _buildUserInputActions(BuildContext context) {
    final question = _firstQuestion(widget.approval);
    final buttons = question?.options ?? const <ApprovalQuestionOption>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (buttons.isNotEmpty)
          ...buttons.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActionButton(
                title: option.label,
                background: Palette.softBlue.appOpacity(0.15),
                foreground: Palette.softBlue,
                enabled: !_isResolving,
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  await _resolve(
                    context,
                    approval: widget.approval,
                    action: ApprovalAction.submitText(option.label),
                  );
                },
              ),
            ),
          ),
        CodexTextField(
          controller: _replyController,
          hintText: 'Reply',
          autocapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 10),
        ActionButton(
          title: _isResolving ? '提交中' : '提交回复',
          background: Palette.accent,
          foreground: Colors.white,
          enabled: !_isResolving,
          onPressed: () async {
            FocusScope.of(context).unfocus();
            await _resolve(
              context,
              approval: widget.approval,
              action: ApprovalAction.submitText(_replyController.text),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChoiceButtons(BuildContext context) {
    final buttons = _choiceButtons(widget.approval);
    final primaryButtons = buttons.take(2).toList();
    final secondaryButtons = buttons.skip(2).toList();
    return Column(
      children: <Widget>[
        Row(
          children: primaryButtons
              .map(
                (button) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionButton(
                      title: _isResolving ? '处理中' : button.title,
                      background: button.background,
                      foreground: button.foreground,
                      enabled: !_isResolving,
                      onPressed: () async {
                        await _resolve(
                          context,
                          approval: widget.approval,
                          action: button.action,
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (secondaryButtons.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondaryButtons
                .map(
                  (button) => SizedBox(
                    width: 150,
                    child: ActionButton(
                      title: button.title,
                      background: button.background,
                      foreground: button.foreground,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      enabled: !_isResolving,
                      onPressed: () async {
                        await _resolve(
                          context,
                          approval: widget.approval,
                          action: button.action,
                        );
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _resolve(
    BuildContext context, {
    required PendingRequestView approval,
    required ApprovalAction action,
  }) async {
    if (_isResolving) {
      return;
    }
    setState(() {
      _isResolving = true;
    });
    try {
      await context.read<AppModel>().resolve(
        approval: approval,
        action: action,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  String _sessionLabel(AppModel model, PendingRequestView approval) {
    final session = model.dashboard.sessions.cast<SessionSummary?>().firstWhere(
      (item) => item?.id == approval.threadId,
      orElse: () => null,
    );
    if (session != null) {
      return '会话：${session.displayName}';
    }
    return '会话：${approval.threadId}';
  }

  String _kindTitle(String kind) {
    switch (kind) {
      case 'command':
        return '命令审批';
      case 'fileChange':
        return '文件变更审批';
      case 'permissions':
        return '权限审批';
      case 'userInput':
        return '需要你的回复';
      default:
        return kind;
    }
  }

  String _riskSummary(PendingRequestView approval) {
    switch (approval.kind) {
      case 'command':
        return '即将运行本地命令。确认工作目录、命令内容和网络/文件权限后再允许。';
      case 'fileChange':
        return '即将写入或修改文件。确认路径和变更范围后再允许。';
      case 'permissions':
        return 'Agent 请求扩大权限范围。移动端建议按本轮或本会话授权。';
      case 'userInput':
        return 'Agent 需要你补充输入后才能继续。';
      default:
        return '确认风险后再继续。';
    }
  }

  List<(String, String)> _fieldRows(
    AppModel model,
    PendingRequestView approval,
  ) {
    final rows = <(String, String)>[];
    void add(String label, Object? value) {
      final text = asString(value).trim();
      if (text.isNotEmpty) {
        rows.add((label, text));
      }
    }

    add('方法', approval.method);
    add('工作目录', approval.params['cwd']);
    add('命令', approval.params['command']);
    add('路径', approval.params['path']);
    add('文件', approval.params['file']);
    add('权限', approval.params['permissions']);
    if (!widget.showSessionLabel) {
      add('会话', _sessionLabel(model, approval));
    }
    return rows.take(4).toList();
  }

  ApprovalQuestion? _firstQuestion(PendingRequestView approval) {
    final questions = asList(approval.params['questions']);
    for (final value in questions) {
      final object = asMap(value);
      final id = asString(object['id'], UniqueKey().toString());
      final question = asString(object['question']).isNotEmpty
          ? asString(object['question'])
          : asString(object['prompt']);
      final options = asList(object['options'])
          .map((option) => asMap(option))
          .map(
            (option) => ApprovalQuestionOption(
              label: asString(option['label']),
              description: asString(option['description']),
            ),
          )
          .where((option) => option.label.isNotEmpty)
          .toList();
      return ApprovalQuestion(id: id, question: question, options: options);
    }
    return null;
  }

  List<_ApprovalChoiceButton> _choiceButtons(PendingRequestView approval) {
    final availableCommandButtons = _availableDecisionButtons(approval);
    if (approval.kind == 'command' && availableCommandButtons.isNotEmpty) {
      return availableCommandButtons;
    }

    final effectiveChoices = approval.choices.isEmpty
        ? _fallbackChoices(approval.kind)
        : approval.choices;
    return effectiveChoices.map((choice) {
      switch (choice) {
        case 'accept':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '允许一次',
            background: Palette.accent,
            foreground: Colors.white,
          );
        case 'acceptForSession':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '本会话内允许',
            background: Palette.softBlue.appOpacity(0.15),
            foreground: Palette.softBlue,
          );
        case 'decline':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '拒绝',
            background: Palette.danger.appOpacity(0.12),
            foreground: Palette.danger,
          );
        case 'cancel':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '取消',
            background: Palette.shell,
            foreground: Palette.mutedInk,
          );
        case 'session':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '授权到会话',
            background: Palette.softBlue,
            foreground: Colors.white,
          );
        case 'turn':
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: '仅本轮授权',
            background: Palette.accent,
            foreground: Colors.white,
          );
        default:
          return _ApprovalChoiceButton(
            action: ApprovalAction.choice(choice),
            title: choice,
            background: Palette.shell,
            foreground: Palette.ink,
          );
      }
    }).toList();
  }

  List<_ApprovalChoiceButton> _availableDecisionButtons(
    PendingRequestView approval,
  ) {
    return asList(
      approval.params['availableDecisions'],
    ).map(_commandDecisionButton).whereType<_ApprovalChoiceButton>().toList();
  }

  _ApprovalChoiceButton? _commandDecisionButton(dynamic decision) {
    if (decision is String) {
      switch (decision) {
        case 'accept':
          return _ApprovalChoiceButton(
            action: ApprovalAction.decision(decision),
            title: '允许一次',
            background: Palette.accent,
            foreground: Colors.white,
          );
        case 'acceptForSession':
          return _ApprovalChoiceButton(
            action: ApprovalAction.decision(decision),
            title: '本会话内允许',
            background: Palette.softBlue.appOpacity(0.15),
            foreground: Palette.softBlue,
          );
        case 'decline':
          return _ApprovalChoiceButton(
            action: ApprovalAction.decision(decision),
            title: '拒绝',
            background: Palette.danger.appOpacity(0.12),
            foreground: Palette.danger,
          );
        case 'cancel':
          return _ApprovalChoiceButton(
            action: ApprovalAction.decision(decision),
            title: '取消并中断本轮',
            background: Palette.shell,
            foreground: Palette.mutedInk,
          );
        default:
          return _ApprovalChoiceButton(
            action: ApprovalAction.decision(decision),
            title: decision,
            background: Palette.shell,
            foreground: Palette.ink,
          );
      }
    }

    final object = asMap(decision);
    if (object.containsKey('acceptWithExecpolicyAmendment')) {
      return _ApprovalChoiceButton(
        action: ApprovalAction.decision(<String, dynamic>{
          'acceptWithExecpolicyAmendment':
              object['acceptWithExecpolicyAmendment'],
        }),
        title: '允许并记住这类命令',
        background: Palette.softBlue,
        foreground: Colors.white,
      );
    }

    final amendmentWrapper = asMap(object['applyNetworkPolicyAmendment']);
    final amendment = asMap(amendmentWrapper['network_policy_amendment']);
    if (amendment.isNotEmpty) {
      final host = asString(amendment['host'], '该主机');
      final action = asString(amendment['action']);
      final isAllow = action == 'allow';
      return _ApprovalChoiceButton(
        action: ApprovalAction.decision(<String, dynamic>{
          'applyNetworkPolicyAmendment': <String, dynamic>{
            'network_policy_amendment': amendment,
          },
        }),
        title: isAllow ? '允许并记住 $host' : '拒绝并记住 $host',
        background: isAllow
            ? Palette.softBlue.appOpacity(0.15)
            : Palette.danger.appOpacity(0.12),
        foreground: isAllow ? Palette.softBlue : Palette.danger,
      );
    }

    if (object.isNotEmpty) {
      final key = object.keys.first;
      return _ApprovalChoiceButton(
        action: ApprovalAction.decision(object),
        title: key,
        background: Palette.shell,
        foreground: Palette.ink,
      );
    }

    return null;
  }

  List<String> _fallbackChoices(String kind) {
    switch (kind) {
      case 'command':
      case 'fileChange':
        return const <String>[
          'accept',
          'acceptForSession',
          'decline',
          'cancel',
        ];
      case 'permissions':
        return const <String>['session', 'turn', 'decline'];
      default:
        return const <String>['decline'];
    }
  }
}

class _ApprovalChoiceButton {
  _ApprovalChoiceButton({
    required this.action,
    required this.title,
    required this.background,
    required this.foreground,
  });

  final ApprovalAction action;
  final String title;
  final Color background;
  final Color foreground;
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final tone = switch (kind) {
      'command' => Palette.warning,
      'fileChange' => Palette.softBlue,
      'permissions' => Palette.accent,
      'userInput' => Palette.warning,
      _ => Palette.mutedInk,
    };
    final label = switch (kind) {
      'command' => 'Shell 权限',
      'fileChange' => '文件变更',
      'permissions' => '权限',
      'userInput' => '需要回复',
      _ => kind,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.appOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: roundedTextStyle(size: 11, weight: FontWeight.w800, color: tone),
      ),
    );
  }
}

class _ApprovalField extends StatelessWidget {
  const _ApprovalField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Palette.ink.appOpacity(0.055),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: roundedTextStyle(
              size: 10,
              weight: FontWeight.w800,
              color: Palette.faintInk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: roundedTextStyle(
              size: 12,
              weight: FontWeight.w600,
              color: Palette.ink,
              fontFamily: label == '命令' || label == '工作目录' ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
