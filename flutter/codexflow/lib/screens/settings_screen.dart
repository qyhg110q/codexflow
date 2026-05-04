import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  bool _didBindController = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didBindController) {
      _controller.text = context.read<AppModel>().baseUrlString;
      _didBindController = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final connectionTone = model.isAgentOnline
        ? Palette.accent
        : Palette.danger;

    return Scaffold(
      backgroundColor: Palette.canvas,
      appBar: AppBar(
        title: Text(
          '设置',
          style: roundedTextStyle(size: 17, weight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: PageScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '设置',
                  style: roundedTextStyle(size: 19, weight: FontWeight.w700),
                ),
                const Spacer(),
                AgentStatusBadge(connected: model.isAgentOnline),
              ],
            ),
            const SizedBox(height: 14),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Agent 地址',
                    style: roundedTextStyle(size: 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  CodexTextField(
                    controller: _controller,
                    hintText: 'http://192.168.1.4:4318',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Android 真机建议填写电脑的局域网地址。模拟器、Web 和桌面端按各自网络映射处理。',
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ActionButton(
                          title: '保存并刷新',
                          background: Palette.accent,
                          foreground: Colors.white,
                          fontSize: 14,
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            model.updateBaseUrlString(_controller.text);
                            await model.saveBaseUrl();
                            await model.refreshDashboard();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ActionButton(
                          title: '重新连接',
                          background: Palette.softBlue.appOpacity(0.14),
                          foreground: Palette.softBlue,
                          fontSize: 14,
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            model.updateBaseUrlString(_controller.text);
                            await model.refreshDashboard();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (model.dashboard.agent.connected &&
                      model.dashboard.agent.listenAddr.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Agent 当前监听：${model.dashboard.agent.listenAddr}',
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
            const SizedBox(height: 12),
            PanelCard(
              compact: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '当前连接',
                        style: roundedTextStyle(
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: connectionTone.appOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: connectionTone,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              model.isAgentOnline ? '在线' : '离线',
                              style: roundedTextStyle(
                                size: 12,
                                weight: FontWeight.w700,
                                color: connectionTone,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SettingsInfoRow(title: '入口地址', value: _controller.text),
                  const SizedBox(height: 8),
                  _SettingsInfoRow(
                    title: '监听地址',
                    value: model.dashboard.agent.listenAddr.isEmpty
                        ? '未发现'
                        : model.dashboard.agent.listenAddr,
                  ),
                  const SizedBox(height: 8),
                  _SettingsInfoRow(
                    title: 'Codex 路径',
                    value: model.dashboard.agent.codexBinaryPath,
                  ),
                  if (model.agentConnectionError.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            PanelCard(
              compact: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '默认执行策略',
                    style: roundedTextStyle(size: 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这些配置先作为 Flutter 本地 UI 偏好保存。后端未持久化前，创建会话仍按现有 Agent API 执行。',
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsChoiceRow(
                    title: '权限策略',
                    value: _policyLabel(model.defaultExecutionPolicy),
                    onTap: () => _showValuePicker(
                      title: '默认执行策略',
                      current: model.defaultExecutionPolicy,
                      values: const <String, String>{
                        'review': '自动审查',
                        'ask': '每次确认',
                        'full': '完全使用权限',
                      },
                      onSelected: model.updateDefaultExecutionPolicy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: '模型',
                    value: model.defaultModel,
                    onTap: () => _showValuePicker(
                      title: '默认模型',
                      current: model.defaultModel,
                      values: const <String, String>{
                        'GPT-5.4': 'GPT-5.4',
                        'GPT-5.5': 'GPT-5.5',
                      },
                      onSelected: model.updateDefaultModel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: '推理深度',
                    value: _reasoningLabel(model.defaultReasoning),
                    onTap: () => _showValuePicker(
                      title: '推理深度',
                      current: model.defaultReasoning,
                      values: const <String, String>{
                        'low': '低',
                        'medium': '中',
                        'high': '高',
                        'xhigh': '超高',
                      },
                      onSelected: model.updateDefaultReasoning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: '速度',
                    value: _speedLabel(model.defaultSpeed),
                    onTap: () => _showValuePicker(
                      title: '默认速度',
                      current: model.defaultSpeed,
                      values: const <String, String>{
                        'standard': '标准',
                        'fast': '快速',
                      },
                      onSelected: model.updateDefaultSpeed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: model.localMode,
                    activeThumbColor: Palette.accent,
                    title: Text(
                      '本地模式',
                      style: roundedTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      model.localMode
                          ? '优先连接局域网 Agent'
                          : '保留给后续 relay / pairing',
                      style: roundedTextStyle(
                        size: 12,
                        weight: FontWeight.w500,
                        color: Palette.mutedInk,
                      ),
                    ),
                    onChanged: model.updateLocalMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const PanelCard(
              compact: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '移动端原则',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Palette.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '首页用于创建或打开会话，审批集中处理风险动作，设置只保留连接与默认偏好。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showValuePicker({
    required String title,
    required String current,
    required Map<String, String> values,
    required Future<void> Function(String value) onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                ...values.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SettingsOptionTile(
                      title: entry.value,
                      selected: entry.key == current,
                      onTap: () async {
                        await onSelected(entry.key);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  String _speedLabel(String value) {
    switch (value) {
      case 'fast':
        return '快速';
      default:
        return '标准';
    }
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.shell,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: roundedTextStyle(
              size: 11,
              weight: FontWeight.w700,
              color: Palette.mutedInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: roundedTextStyle(
              size: 12,
              weight: FontWeight.w500,
              color: Palette.ink,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsChoiceRow extends StatelessWidget {
  const _SettingsChoiceRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Palette.surfaceStrong,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: roundedTextStyle(size: 13, weight: FontWeight.w700),
                ),
              ),
              Text(
                value,
                style: roundedTextStyle(
                  size: 12,
                  weight: FontWeight.w700,
                  color: Palette.softBlue,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Palette.faintInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}
