import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/widgets/file_drop_scope.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_typography.dart';
import '../../../attachments/presentation/cubit/attachment_cubit.dart';
import 'terminal_palette.dart';
import 'terminal_prompt.dart';
import 'terminal_scrollback.dart';

/// Full interactive terminal surface: title bar + scrollback + prompt + drop.
class TerminalView extends StatelessWidget {
  const TerminalView({
    super.key,
    required this.messages,
    required this.controller,
    required this.focusNode,
    required this.attachments,
    required this.isStreaming,
    required this.isDraggingFiles,
    required this.settings,
    required this.onDraggingChanged,
    required this.onFilesDropped,
    required this.onSend,
    required this.onStop,
    required this.onAttachFiles,
    required this.onAttachImages,
    required this.onPaste,
    required this.onRemoveAttachment,
    required this.onTogglePin,
    this.cwdLabel,
    this.sessionTitle,
    this.hasWorkspace = true,
    this.onOpenWorkspace,
    this.errorBanner,
    this.isGoalActive = false,
    this.goalIteration = 0,
    this.goalStatus,
    this.onToggleGoal,
    this.isMultitaskActive = false,
    this.multitaskQueued = 0,
    this.onToggleMultitask,
    this.attachmentStatus,
  });

  final List<ChatMessage> messages;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<AttachmentItem> attachments;
  final bool isStreaming;
  final bool isDraggingFiles;
  final AppSettings settings;
  final ValueChanged<bool> onDraggingChanged;
  final void Function(List<DropItem> files) onFilesDropped;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttachFiles;
  final VoidCallback onAttachImages;
  final Future<AttachmentPasteResult> Function() onPaste;
  final void Function(String id) onRemoveAttachment;
  final void Function(String id) onTogglePin;
  final String? cwdLabel;
  final String? sessionTitle;
  final bool hasWorkspace;
  final VoidCallback? onOpenWorkspace;
  final Widget? errorBanner;
  final bool isGoalActive;
  final int goalIteration;
  final String? goalStatus;
  final VoidCallback? onToggleGoal;
  final bool isMultitaskActive;
  final int multitaskQueued;
  final VoidCallback? onToggleMultitask;
  final String? attachmentStatus;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);
    return FileDropScope(
      onDraggingChanged: onDraggingChanged,
      onFilesDropped: onFilesDropped,
      child: Container(
        color: theme.canvas,
        child: Column(
          children: [
            _TerminalTitleBar(
              sessionTitle: sessionTitle,
              cwdLabel: cwdLabel,
              isStreaming: isStreaming,
            ),
            ?errorBanner,
            Expanded(
              child: !hasWorkspace
                  ? _TerminalEmptyState(
                      title: 'no workspace',
                      body: 'Open a folder to start.\nCtrl+O · Cmd+O',
                      actionLabel: 'open folder',
                      onAction: onOpenWorkspace,
                    )
                  : TerminalScrollback(
                      messages: messages,
                      emptyChild: _TerminalEmptyState(
                        title: sessionTitle ?? 'new session',
                        body:
                            'Type a prompt below.\nPaste or drop images/files · Enter to send · Esc cancel',
                      ),
                    ),
            ),
            TerminalPrompt(
              controller: controller,
              focusNode: focusNode,
              attachments: attachments,
              isStreaming: isStreaming,
              isDraggingFiles: isDraggingFiles,
              settings: settings,
              cwdLabel: null, // path shown in title bar
              onSend: onSend,
              onStop: onStop,
              onAttachFiles: onAttachFiles,
              onAttachImages: onAttachImages,
              onPaste: onPaste,
              onRemoveAttachment: onRemoveAttachment,
              onTogglePin: onTogglePin,
              isGoalActive: isGoalActive,
              goalIteration: goalIteration,
              goalStatus: goalStatus,
              onToggleGoal: onToggleGoal,
              isMultitaskActive: isMultitaskActive,
              multitaskQueued: multitaskQueued,
              onToggleMultitask: onToggleMultitask,
              attachmentStatus: attachmentStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalTitleBar extends StatelessWidget {
  const _TerminalTitleBar({
    this.sessionTitle,
    this.cwdLabel,
    required this.isStreaming,
  });

  final String? sessionTitle;
  final String? cwdLabel;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border(bottom: BorderSide(color: theme.panelBorder)),
      ),
      child: Row(
        children: [
          Text(
            '●',
            style: GrokkerTypography.mono(
              size: 10,
              color: isStreaming
                  ? TerminalPalette.grok
                  : TerminalPalette.success,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              sessionTitle == null || sessionTitle!.isEmpty
                  ? 'grokker'
                  : sessionTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GrokkerTypography.mono(size: 12, color: theme.headingText),
            ),
          ),
          if (cwdLabel != null && cwdLabel!.isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: Text(
                cwdLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GrokkerTypography.mono(
                  size: 11,
                  color: GrokkerColors.fog,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerminalEmptyState extends StatelessWidget {
  const _TerminalEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'grokker › $title',
              style: GrokkerTypography.mono(
                size: 13,
                color: GrokkerColors.emberBright,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GrokkerTypography.mono(size: 12, color: GrokkerColors.fog),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: GrokkerColors.emberBright,
                ),
                child: Text(
                  '❯ $actionLabel',
                  style: GrokkerTypography.mono(
                    size: 13,
                    color: GrokkerColors.emberBright,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
