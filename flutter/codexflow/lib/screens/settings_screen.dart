import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../state/app_model.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final l10n = AppLocalizations.of(model.languageCode);
    final connectionTone = model.isAgentConnecting
        ? Palette.warning
        : (model.isAgentOnline ? Palette.accent : Palette.danger);
    final connectionLabel = model.isAgentConnecting
        ? l10n.t('status.connecting')
        : (model.isAgentOnline
              ? l10n.t('status.online')
              : l10n.t('status.offline'));

    return Scaffold(
      backgroundColor: Palette.canvas,
      appBar: AppBar(
        title: Text(
          l10n.t('settings.title'),
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
                  l10n.t('settings.title'),
                  style: roundedTextStyle(size: 19, weight: FontWeight.w700),
                ),
                const Spacer(),
                AgentStatusBadge(
                  connected: model.isAgentOnline,
                  connecting: model.isAgentConnecting,
                ),
              ],
            ),
            const SizedBox(height: 14),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.t('settings.agentAddress'),
                          style: roundedTextStyle(
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: l10n.t('settings.addAgent'),
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Palette.softBlue.appOpacity(0.12),
                            foregroundColor: Palette.softBlue,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () => _showAgentEndpointEditor(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('settings.agentHelp'),
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...model.agentEndpoints.map(
                    (endpoint) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AgentEndpointTile(
                        endpoint: endpoint,
                        selected: model.isSelectedAgentEndpoint(endpoint.id),
                        connected:
                            model.isSelectedAgentEndpoint(endpoint.id) &&
                            model.isAgentOnline,
                        connecting:
                            model.isSelectedAgentEndpoint(endpoint.id) &&
                            model.isAgentConnecting,
                        onTap: () => model.selectAgentEndpoint(endpoint.id),
                        onLongPress: () => _showAgentEndpointActions(endpoint),
                      ),
                    ),
                  ),
                  if (model.isAgentOnline &&
                      model.dashboard.agent.listenAddr.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('settings.currentListen', {
                        'addr': model.dashboard.agent.listenAddr,
                      }),
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
                        l10n.t('settings.currentConnection'),
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
                              connectionLabel,
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
                  _SettingsInfoRow(
                    title: l10n.t('common.agent'),
                    value: model.selectedAgentEndpoint.name,
                  ),
                  const SizedBox(height: 8),
                  _SettingsInfoRow(
                    title: l10n.t('settings.entryAddress'),
                    value: model.baseUrlString,
                  ),
                  const SizedBox(height: 8),
                  _SettingsInfoRow(
                    title: l10n.t('settings.listenAddress'),
                    value:
                        model.isAgentOnline &&
                            model.dashboard.agent.listenAddr.isNotEmpty
                        ? model.dashboard.agent.listenAddr
                        : l10n.t('settings.notFound'),
                  ),
                  const SizedBox(height: 8),
                  _SettingsInfoRow(
                    title: l10n.t('settings.codexPath'),
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
                    l10n.t('settings.defaultPolicy'),
                    style: roundedTextStyle(size: 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('settings.localPreferenceNote'),
                    style: roundedTextStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsChoiceRow(
                    title: l10n.t('settings.permissionPolicy'),
                    value: _policyLabel(model.defaultExecutionPolicy, l10n),
                    onTap: () => _showValuePicker(
                      title: l10n.t('settings.defaultPolicy'),
                      current: model.defaultExecutionPolicy,
                      values: <String, String>{
                        'ask': l10n.t('policy.ask'),
                        'review': l10n.t('policy.review'),
                        'full': l10n.t('policy.full'),
                      },
                      onSelected: model.updateDefaultExecutionPolicy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: l10n.t('common.model'),
                    value: model.defaultModel,
                    onTap: () => _showValuePicker(
                      title: l10n.t('settings.defaultModel'),
                      current: model.defaultModel,
                      values: const <String, String>{
                        'GPT-5.3-Codex': 'GPT-5.3-Codex',
                        'GPT-5.4': 'GPT-5.4',
                        'GPT-5.4-Mini': 'GPT-5.4-Mini',
                        'GPT-5.5': 'GPT-5.5',
                      },
                      onSelected: model.updateDefaultModel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: l10n.t('settings.reasoningDepth'),
                    value: _reasoningLabel(model.defaultReasoning, l10n),
                    onTap: () => _showValuePicker(
                      title: l10n.t('settings.reasoningDepth'),
                      current: model.defaultReasoning,
                      values: <String, String>{
                        'low': l10n.t('reasoning.low'),
                        'medium': l10n.t('reasoning.medium'),
                        'high': l10n.t('reasoning.high'),
                        'xhigh': l10n.t('reasoning.xhigh'),
                      },
                      onSelected: model.updateDefaultReasoning,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: l10n.t('settings.defaultSpeed'),
                    value: _speedLabel(model.defaultSpeed, l10n),
                    onTap: () => _showValuePicker(
                      title: l10n.t('settings.defaultSpeed'),
                      current: model.defaultSpeed,
                      values: <String, String>{
                        'standard': l10n.t('speed.standard'),
                        'fast': l10n.t('speed.fast'),
                      },
                      onSelected: model.updateDefaultSpeed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsChoiceRow(
                    title: l10n.t('settings.language'),
                    value: AppLocalizations.languageName(model.languageCode),
                    onTap: () => _showValuePicker(
                      title: l10n.t('settings.selectLanguage'),
                      current: model.languageCode,
                      values: <String, String>{
                        for (final language in AppLocalizations.languages)
                          language.code: language.nativeName,
                      },
                      onSelected: model.updateLanguageCode,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('settings.languageHelp'),
                    style: roundedTextStyle(
                      size: 12,
                      weight: FontWeight.w500,
                      color: Palette.mutedInk,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: model.localMode,
                    activeThumbColor: Palette.accent,
                    title: Text(
                      l10n.t('settings.localMode'),
                      style: roundedTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      model.localMode
                          ? l10n.t('settings.localModeOn')
                          : l10n.t('settings.localModeOff'),
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
          ],
        ),
      ),
    );
  }

  Future<void> _showAgentEndpointActions(AgentEndpoint endpoint) async {
    final l10n = AppLocalizations.of(context.read<AppModel>().languageCode);
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
              children: <Widget>[
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Palette.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.edit_rounded,
                    color: Palette.softBlue,
                  ),
                  title: Text(
                    l10n.t('common.edit'),
                    style: roundedTextStyle(size: 15, weight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showAgentEndpointEditor(endpoint: endpoint);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Palette.danger,
                  ),
                  title: Text(
                    l10n.t('common.delete'),
                    style: roundedTextStyle(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Palette.danger,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await context.read<AppModel>().deleteAgentEndpoint(
                      endpoint.id,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAgentEndpointEditor({AgentEndpoint? endpoint}) async {
    final l10n = AppLocalizations.of(context.read<AppModel>().languageCode);
    final nameController = TextEditingController(text: endpoint?.name ?? '');
    final urlController = TextEditingController(text: endpoint?.url ?? '');
    try {
      final result = await showDialog<_AgentEndpointFormResult>(
        context: context,
        builder: (dialogContext) {
          String? errorText;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Palette.canvas,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  endpoint == null
                      ? l10n.t('settings.addAgent')
                      : l10n.t('settings.editAgent'),
                  style: roundedTextStyle(size: 17, weight: FontWeight.w700),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CodexTextField(
                      controller: nameController,
                      hintText: l10n.t('settings.agentName'),
                    ),
                    const SizedBox(height: 10),
                    CodexTextField(
                      controller: urlController,
                      hintText: 'http://192.168.1.4:4318',
                      monospaced: true,
                    ),
                    if (errorText != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: roundedTextStyle(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Palette.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      l10n.t('common.cancel'),
                      style: roundedTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Palette.mutedInk,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final url = _normalizedEndpointUrl(urlController.text);
                      if (name.isEmpty) {
                        setDialogState(
                          () => errorText = l10n.t('settings.enterAgentName'),
                        );
                        return;
                      }
                      if (!_isValidEndpointUrl(url)) {
                        setDialogState(
                          () => errorText = l10n.t('settings.enterValidHttp'),
                        );
                        return;
                      }
                      Navigator.of(
                        dialogContext,
                      ).pop(_AgentEndpointFormResult(name: name, url: url));
                    },
                    child: Text(
                      endpoint == null
                          ? l10n.t('common.add')
                          : l10n.t('common.save'),
                      style: roundedTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Palette.softBlue,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || result == null) {
        return;
      }
      final model = context.read<AppModel>();
      if (endpoint == null) {
        await model.addAgentEndpoint(name: result.name, url: result.url);
      } else {
        await model.updateAgentEndpoint(
          id: endpoint.id,
          name: result.name,
          url: result.url,
        );
      }
    } finally {
      nameController.dispose();
      urlController.dispose();
    }
  }

  String _normalizedEndpointUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
    return hasScheme ? trimmed : 'http://$trimmed';
  }

  bool _isValidEndpointUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
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

  String _speedLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'fast':
        return l10n.t('speed.fast');
      default:
        return l10n.t('speed.standard');
    }
  }
}

class _AgentEndpointFormResult {
  const _AgentEndpointFormResult({required this.name, required this.url});

  final String name;
  final String url;
}

class _AgentEndpointTile extends StatelessWidget {
  const _AgentEndpointTile({
    required this.endpoint,
    required this.selected,
    required this.connected,
    required this.connecting,
    required this.onTap,
    required this.onLongPress,
  });

  final AgentEndpoint endpoint;
  final bool selected;
  final bool connected;
  final bool connecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context.watch<AppModel>().languageCode);
    final tone = connecting
        ? Palette.warning
        : (connected ? Palette.accent : Palette.danger);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? Palette.softBlue.appOpacity(0.10)
                : Palette.surfaceStrong,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Palette.softBlue.appOpacity(0.32)
                  : Palette.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Palette.softBlue.appOpacity(0.13)
                      : Palette.ink.appOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  size: 20,
                  color: selected ? Palette.softBlue : Palette.mutedInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      endpoint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: roundedTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endpoint.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: roundedTextStyle(
                        size: 12,
                        weight: FontWeight.w500,
                        color: Palette.mutedInk,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tone.appOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        connecting
                            ? l10n.t('status.connecting')
                            : (connected
                                  ? l10n.t('status.connected')
                                  : l10n.t('status.retrying')),
                        style: roundedTextStyle(
                          size: 11,
                          weight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Palette.faintInk,
                ),
            ],
          ),
        ),
      ),
    );
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
