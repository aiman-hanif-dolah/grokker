import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/models/chat_image_attachment.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_components.dart';
import '../../../../styles/grokker_typography.dart';

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);
    final isUser = message.role == ChatMessageRole.user;
    final isError = message.role == ChatMessageRole.error;
    final isTool = message.role == ChatMessageRole.tool;
    final hasImages = message.images.isNotEmpty;
    final hasText = message.content.trim().isNotEmpty;
    final isStreaming = message.status == ChatMessageStatus.streaming;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GrokkerSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _RoleAvatar(message: message),
            const SizedBox(width: GrokkerSpacing.s12),
          ],
          Flexible(
            child: _MessageBubble(
              message: message,
              theme: theme,
              isUser: isUser,
              isError: isError,
              isTool: isTool,
              hasImages: hasImages,
              hasText: hasText,
              isStreaming: isStreaming,
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: GrokkerSpacing.s12),
            const GrokkerAvatar(
              icon: Icons.person_rounded,
              color: GrokkerColors.signalBlue,
              size: 32,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (message.role) {
      ChatMessageRole.assistant => (Icons.auto_awesome_rounded, GrokkerColors.signalBlue),
      ChatMessageRole.tool => (Icons.build_circle_outlined, GrokkerColors.warningAmber),
      ChatMessageRole.error => (Icons.error_outline_rounded, GrokkerColors.errorRed),
      ChatMessageRole.system => (Icons.info_outline_rounded, GrokkerColors.slate),
      ChatMessageRole.user => (Icons.person_rounded, GrokkerColors.signalBlue),
    };

    return GrokkerAvatar(icon: icon, color: color, size: 32);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.theme,
    required this.isUser,
    required this.isError,
    required this.isTool,
    required this.hasImages,
    required this.hasText,
    required this.isStreaming,
  });

  final ChatMessage message;
  final GrokkerThemeExtension theme;
  final bool isUser;
  final bool isError;
  final bool isTool;
  final bool hasImages;
  final bool hasText;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final accentColor = isUser
        ? GrokkerColors.signalBlue
        : isError
            ? GrokkerColors.errorRed
            : isTool
                ? GrokkerColors.warningAmber
                : GrokkerColors.pewter;

    final bg = isUser
        ? GrokkerColors.signalBlue.withValues(alpha: 0.08)
        : isError
            ? GrokkerColors.errorRedMuted.withValues(alpha: 0.3)
            : GrokkerSurfaces.deepPanel;

    final borderColor = isUser
        ? GrokkerColors.signalBlue.withValues(alpha: 0.25)
        : isError
            ? GrokkerColors.errorRed.withValues(alpha: 0.35)
            : GrokkerColors.gunmetal;

    return Container(
      constraints: const BoxConstraints(maxWidth: GrokkerSpacing.chatMaxWidth),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(GrokkerRadius.card),
          topRight: const Radius.circular(GrokkerRadius.card),
          bottomLeft: Radius.circular(isUser ? GrokkerRadius.card : GrokkerRadius.badge),
          bottomRight: Radius.circular(isUser ? GrokkerRadius.badge : GrokkerRadius.card),
        ),
        border: Border.all(color: borderColor),
        boxShadow: isUser
            ? GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 8)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(GrokkerRadius.card),
          topRight: const Radius.circular(GrokkerRadius.card),
          bottomLeft: Radius.circular(isUser ? GrokkerRadius.card : GrokkerRadius.badge),
          bottomRight: Radius.circular(isUser ? GrokkerRadius.badge : GrokkerRadius.card),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(GrokkerSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isTool)
                            const Padding(
                              padding: EdgeInsets.only(right: GrokkerSpacing.s8),
                              child: GrokkerBadge(
                                label: 'Tool',
                                variant: GrokkerBadgeVariant.neutral,
                                icon: Icons.build_outlined,
                              ),
                            ),
                          if (isError)
                            const Padding(
                              padding: EdgeInsets.only(right: GrokkerSpacing.s8),
                              child: GrokkerBadge(
                                label: 'Error',
                                variant: GrokkerBadgeVariant.error,
                                icon: Icons.error_outline,
                              ),
                            ),
                          Text(
                            _roleLabel(message),
                            style: GrokkerTypography.caption(
                              color: isUser
                                  ? GrokkerColors.signalBlueBright
                                  : theme.subtleText,
                            ),
                          ),

                          const Spacer(),
                          if (!isUser && (hasText || hasImages))
                            GrokkerIconFrameButton(
                              icon: Icons.copy_outlined,
                              tooltip: 'Copy',
                              size: 28,
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: message.content),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: GrokkerSpacing.s8),
                      if (hasImages) ...[
                        ...message.images.map(
                          (image) => Padding(
                            padding: const EdgeInsets.only(bottom: GrokkerSpacing.s8),
                            child: _ChatImagePreview(image: image),
                          ),
                        ),
                      ],
                      if (hasText)
                        if (isUser || isError || isTool)
                          SelectableText(
                            message.content,
                            style: GrokkerTypography.bodySm(
                              color: isError ? GrokkerColors.ash : theme.bodyText,
                            ),
                          )
                        else
                          MarkdownBody(
                            data: message.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: GrokkerTypography.body(color: theme.bodyText),
                              h1: GrokkerTypography.headingSm(color: theme.headingText),
                              h2: GrokkerTypography.label(color: theme.headingText),
                              h3: GrokkerTypography.label(color: theme.headingText),
                              code: GrokkerTypography.mono(size: 12),
                              codeblockDecoration: BoxDecoration(
                                color: GrokkerSurfaces.voidFloor,
                                borderRadius: BorderRadius.circular(GrokkerRadius.input),
                                border: Border.all(color: GrokkerColors.gunmetal),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: GrokkerColors.signalBlue.withValues(alpha: 0.5),
                                    width: 3,
                                  ),
                                ),
                              ),
                              blockquotePadding: const EdgeInsets.only(left: GrokkerSpacing.s12),
                            ),
                          )

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(ChatMessage message) {
    switch (message.role) {
      case ChatMessageRole.user:
        return 'YOU';
      case ChatMessageRole.assistant:
        return 'GROK';
      case ChatMessageRole.tool:
        return (message.title ?? 'Tool').toUpperCase();
      case ChatMessageRole.system:
        return 'SYSTEM';
      case ChatMessageRole.error:
        return 'ERROR';
    }
  }
}

class _ChatImagePreview extends StatelessWidget {
  const _ChatImagePreview({required this.image});

  final ChatImageAttachment image;

  @override
  Widget build(BuildContext context) {
    final file = File(image.path);
    if (!file.existsSync()) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(GrokkerSpacing.s16),
        decoration: BoxDecoration(
          color: GrokkerSurfaces.voidFloor,
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          border: Border.all(color: GrokkerColors.gunmetal),
        ),
        child: Text(
          'Image unavailable',
          style: GrokkerTypography.caption(color: GrokkerColors.pewter),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openImage(image.path),
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Container(
                padding: const EdgeInsets.all(GrokkerSpacing.s16),
                color: GrokkerSurfaces.voidFloor,
                child: Text(
                  'Failed to load image',
                  style: GrokkerTypography.caption(color: GrokkerColors.pewter),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImage(String path) async {
    if (!Platform.isMacOS) return;
    await Process.run('open', [path]);
  }
}