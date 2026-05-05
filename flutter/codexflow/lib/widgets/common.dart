import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme/palette.dart';

extension AppColorAlpha on Color {
  Color appOpacity(double value) => withValues(alpha: value);
}

TextStyle roundedTextStyle({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Palette.ink,
  double? height,
  String? fontFamily,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontFamily: fontFamily,
  );
}

class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(gradient: Palette.dashboardGradient),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color.fromRGBO(53, 116, 183, 0.08),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const AtmosphereBackground(),
        SafeArea(child: child),
      ],
    );
  }
}

class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 16.0 : 22.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Palette.panelStrong,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Palette.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(31, 36, 41, 0.08),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.tone,
  });

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: roundedTextStyle(
              size: 12,
              weight: FontWeight.w600,
              color: Palette.mutedInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: roundedTextStyle(size: 24, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 6,
              color: tone.appOpacity(0.16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 28, color: tone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CapsuleTag extends StatelessWidget {
  const CapsuleTag({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.ink.appOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: roundedTextStyle(
              size: 11,
              weight: FontWeight.w600,
              color: Palette.mutedInk,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: roundedTextStyle(size: 12, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    required this.waiting,
    this.ended = false,
  });

  final String status;
  final bool waiting;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.appOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _label,
        style: roundedTextStyle(size: 11, weight: FontWeight.w700, color: tone),
      ),
    );
  }

  String get _label {
    if (ended) {
      return '已结束';
    }
    if (waiting) {
      return '待处理';
    }

    switch (status) {
      case 'active':
      case 'inProgress':
        return '运行中';
      case 'completed':
        return '已完成';
      case 'notLoaded':
        return '未接管';
      case 'failed':
      case 'systemError':
        return '失败';
      case 'idle':
        return '空闲';
      default:
        return status;
    }
  }

  Color get _tone {
    if (ended) {
      return Palette.mutedInk;
    }
    if (waiting) {
      return Palette.warning;
    }

    switch (status) {
      case 'active':
      case 'inProgress':
        return Palette.accent;
      case 'completed':
      case 'idle':
        return Palette.success;
      case 'notLoaded':
        return Palette.softBlue;
      case 'failed':
      case 'systemError':
        return Palette.danger;
      default:
        return Palette.mutedInk;
    }
  }
}

class AgentStatusBadge extends StatelessWidget {
  const AgentStatusBadge({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final tone = connected ? Palette.accent : Palette.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.appOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? '在线' : '离线',
            style: roundedTextStyle(
              size: 11,
              weight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.title,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.borderColor = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
    this.enabled = true,
    this.icon,
    this.fontSize = 12,
  });

  final String title;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final Color borderColor;
  final EdgeInsets padding;
  final bool enabled;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12).add(padding),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: fontSize + 1, color: foreground),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: roundedTextStyle(
                      size: fontSize,
                      weight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CodexTextField extends StatelessWidget {
  const CodexTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.maxLines = 1,
    this.minLines,
    this.autocorrect = true,
    this.autocapitalization = TextCapitalization.none,
    this.monospaced = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int? minLines;
  final int maxLines;
  final bool autocorrect;
  final TextCapitalization autocapitalization;
  final bool monospaced;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      autocorrect: autocorrect,
      textCapitalization: autocapitalization,
      style: roundedTextStyle(
        size: 14,
        weight: FontWeight.w500,
        color: Palette.ink,
        fontFamily: monospaced ? 'monospace' : null,
      ),
      cursorColor: Palette.softBlue,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: roundedTextStyle(
          size: 14,
          weight: FontWeight.w500,
          color: Palette.mutedInk,
        ),
        filled: true,
        fillColor: Palette.surfaceStrong,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.softBlue.appOpacity(0.35)),
        ),
      ),
    );
  }
}

class OptionChipButton extends StatelessWidget {
  const OptionChipButton({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? value : '$label $value';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Palette.ink.appOpacity(0.055),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: Palette.mutedInk),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: roundedTextStyle(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Palette.mutedInk,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: Palette.faintInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgentMark extends StatelessWidget {
  const AgentMark({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context) {
    final isClaude = agentId == 'claude';
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isClaude
            ? Palette.warning.appOpacity(0.13)
            : Palette.softBlue.appOpacity(0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isClaude
              ? Palette.warning.appOpacity(0.18)
              : Palette.softBlue.appOpacity(0.18),
        ),
      ),
      child: Text(
        isClaude ? 'CL' : 'CX',
        style: roundedTextStyle(
          size: 12,
          weight: FontWeight.w800,
          color: isClaude ? Palette.warning : Palette.softBlue,
        ),
      ),
    );
  }
}

class HeadTailExcerptBlock extends StatelessWidget {
  const HeadTailExcerptBlock({
    super.key,
    required this.raw,
    required this.head,
    required this.tail,
    required this.style,
  });

  final String raw;
  final int head;
  final int tail;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final excerpt = headTailExcerpt(raw: raw, head: head, tail: tail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(excerpt.head, style: style),
        if (excerpt.tail != null) ...<Widget>[
          Text('…', style: style),
          Text(excerpt.tail!, style: style),
        ],
      ],
    );
  }
}

class HeadTailExcerpt {
  const HeadTailExcerpt({required this.head, required this.tail});

  final String head;
  final String? tail;
}

HeadTailExcerpt headTailExcerpt({
  required String raw,
  required int head,
  required int tail,
}) {
  final normalized = normalizedDisplayText(raw);
  final runes = normalized.runes.toList();
  if (runes.length <= head + tail + 12) {
    return HeadTailExcerpt(head: normalized, tail: null);
  }

  final safeHead = head.clamp(0, runes.length);
  final safeTail = tail.clamp(0, runes.length - safeHead);
  if (safeHead <= 0 || safeTail <= 0 || safeHead + safeTail >= runes.length) {
    return HeadTailExcerpt(head: normalized, tail: null);
  }

  final headText = String.fromCharCodes(runes.take(safeHead));
  final tailText = String.fromCharCodes(runes.skip(runes.length - safeTail));
  return HeadTailExcerpt(head: headText, tail: tailText);
}

String normalizedDisplayText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ')
      .trim();
}

class MarkdownBodyBlock extends StatelessWidget {
  const MarkdownBodyBlock({super.key, required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: raw,
      selectable: false,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: roundedTextStyle(
          size: 12,
          weight: FontWeight.w500,
          color: Palette.ink,
          height: 1.5,
        ),
        h1: roundedTextStyle(
          size: 17,
          weight: FontWeight.w700,
          color: Palette.ink,
        ),
        h2: roundedTextStyle(
          size: 16,
          weight: FontWeight.w600,
          color: Palette.ink,
        ),
        h3: roundedTextStyle(
          size: 14,
          weight: FontWeight.w600,
          color: Palette.ink,
        ),
        blockquote: roundedTextStyle(
          size: 12,
          weight: FontWeight.w500,
          color: Palette.mutedInk,
        ),
        listBullet: roundedTextStyle(
          size: 12,
          weight: FontWeight.w700,
          color: Palette.accent,
        ),
        code: roundedTextStyle(
          size: 11,
          weight: FontWeight.w500,
          color: Palette.codeText,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Palette.codeBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        blockquoteDecoration: BoxDecoration(
          color: Palette.softBlue.appOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: Palette.softBlue, width: 3)),
        ),
      ),
    );
  }
}
