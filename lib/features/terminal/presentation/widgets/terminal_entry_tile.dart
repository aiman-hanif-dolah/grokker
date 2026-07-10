import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/models/chat_image_attachment.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../styles/grokker_typography.dart';
import 'terminal_markdown.dart';
import 'terminal_palette.dart';

/// Color-coded scrollback block — role glyph, accent bar, tinted body.
class TerminalEntryTile extends StatelessWidget {
  const TerminalEntryTile({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isStreaming = message.status == ChatMessageStatus.streaming;
    final hasImages = message.images.isNotEmpty;
    final hasText = message.content.trim().isNotEmpty;
    final role = message.role;
    final prefixColor = TerminalPalette.prefix(role);
    final bg = TerminalPalette.background(role);
    final statusColor = TerminalPalette.statusTint(message.status);
    final label = TerminalPalette.label(message);
    final glyph = TerminalPalette.glyph(role);
    // Tool titles often duplicate the start of content — prefer a stacked
    // layout so long tool names never bleed into the body column.
    final stackedPrefix = role == ChatMessageRole.tool;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border:
              statusColor != null &&
                  message.status != ChatMessageStatus.streaming
              ? Border.all(color: statusColor.withValues(alpha: 0.35))
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: prefixColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: stackedPrefix
                      ? _StackedBody(
                          glyph: glyph,
                          label: label,
                          prefixColor: prefixColor,
                          message: message,
                          hasText: hasText,
                          hasImages: hasImages,
                          isStreaming: isStreaming,
                        )
                      : _InlineBody(
                          glyph: glyph,
                          label: label,
                          prefixColor: prefixColor,
                          message: message,
                          hasText: hasText,
                          hasImages: hasImages,
                          isStreaming: isStreaming,
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

class _InlineBody extends StatelessWidget {
  const _InlineBody({
    required this.glyph,
    required this.label,
    required this.prefixColor,
    required this.message,
    required this.hasText,
    required this.hasImages,
    required this.isStreaming,
  });

  final String glyph;
  final String label;
  final Color prefixColor;
  final ChatMessage message;
  final bool hasText;
  final bool hasImages;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final role = message.role;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                '$glyph $label',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: GrokkerTypography.mono(
                  size: 12,
                  color: prefixColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: hasText
                  ? TerminalMarkdown(
                      data: message.content,
                      role: role,
                      streaming: isStreaming,
                    )
                  : isStreaming
                  ? Text(
                      '▌',
                      style: GrokkerTypography.mono(
                        size: 13,
                        color: TerminalPalette.grok,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_showStatusBadge(message))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _StatusBadge(status: message.status),
              ),
            if (!isStreaming && role != ChatMessageRole.user && hasText)
              _CopyButton(text: message.content, color: prefixColor),
          ],
        ),
        if (hasImages)
          Padding(
            padding: const EdgeInsets.only(left: 72, top: 8),
            child: _ImageRow(images: message.images, borderColor: prefixColor),
          ),
      ],
    );
  }
}

class _StackedBody extends StatelessWidget {
  const _StackedBody({
    required this.glyph,
    required this.label,
    required this.prefixColor,
    required this.message,
    required this.hasText,
    required this.hasImages,
    required this.isStreaming,
  });

  final String glyph;
  final String label;
  final Color prefixColor;
  final ChatMessage message;
  final bool hasText;
  final bool hasImages;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final body = _toolBodyWithoutRedundantTitle(message);
    final showBody = body.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$glyph $label',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: GrokkerTypography.mono(
                  size: 12,
                  color: prefixColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_showStatusBadge(message))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _StatusBadge(status: message.status),
              ),
            if (!isStreaming && (showBody || hasImages))
              _CopyButton(
                text: message.content.isNotEmpty
                    ? message.content
                    : (message.title ?? label),
                color: prefixColor,
              ),
          ],
        ),
        if (showBody) ...[
          const SizedBox(height: 4),
          TerminalMarkdown(
            data: body,
            role: message.role,
            streaming: isStreaming,
          ),
        ] else if (isStreaming)
          Text(
            '▌',
            style: GrokkerTypography.mono(
              size: 13,
              color: TerminalPalette.grok,
            ),
          ),
        if (hasImages)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ImageRow(images: message.images, borderColor: prefixColor),
          ),
      ],
    );
  }

  /// Drop leading title duplication like "run_terminal_command: pending"
  /// when the prefix already shows that tool name.
  static String _toolBodyWithoutRedundantTitle(ChatMessage message) {
    final content = message.content.trim();
    if (content.isEmpty) return content;
    final title = message.title?.trim();
    if (title == null || title.isEmpty) return content;

    final lowerContent = content.toLowerCase();
    final lowerTitle = title.toLowerCase();
    if (lowerContent == lowerTitle) return '';
    if (lowerContent.startsWith('$lowerTitle:')) {
      return content.substring(title.length + 1).trimLeft();
    }
    if (lowerContent.startsWith('$lowerTitle ')) {
      return content.substring(title.length).trimLeft();
    }
    // Content is only a status suffix like ": pending"
    if (content.startsWith(':')) {
      return content.substring(1).trimLeft();
    }
    return content;
  }
}

bool _showStatusBadge(ChatMessage message) {
  return message.status == ChatMessageStatus.failed ||
      message.status == ChatMessageStatus.cancelled ||
      (message.role == ChatMessageRole.tool &&
          message.content.toLowerCase().contains('fail'));
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ChatMessageStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChatMessageStatus.failed => ('failed', TerminalPalette.error),
      ChatMessageStatus.cancelled => ('cancelled', TerminalPalette.warning),
      ChatMessageStatus.streaming => ('live', TerminalPalette.grok),
      ChatMessageStatus.pending => ('pending', TerminalPalette.dim),
      ChatMessageStatus.completed => ('ok', TerminalPalette.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GrokkerTypography.mono(
          size: 10,
          color: color,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('terminal_copy'),
      tooltip: 'Copy',
      iconSize: 14,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => Clipboard.setData(ClipboardData(text: text)),
      icon: Icon(
        Icons.copy_outlined,
        size: 14,
        color: color.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.images, required this.borderColor});

  final List<ChatImageAttachment> images;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images
          .map(
            (img) => _TerminalImageThumb(image: img, borderColor: borderColor),
          )
          .toList(),
    );
  }
}

class _TerminalImageThumb extends StatelessWidget {
  const _TerminalImageThumb({required this.image, required this.borderColor});

  final ChatImageAttachment image;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final file = File(image.path);
    if (!file.existsSync()) {
      return Text(
        '[image missing: ${image.path}]',
        style: GrokkerTypography.mono(size: 11, color: TerminalPalette.error),
      );
    }

    return Tooltip(
      message: image.path,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 180),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Text(
                '[failed to load image]',
                style: GrokkerTypography.mono(
                  size: 11,
                  color: TerminalPalette.error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
