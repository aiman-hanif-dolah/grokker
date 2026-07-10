import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_typography.dart';
import '../../../attachments/presentation/cubit/attachment_cubit.dart';
import '../../../attachments/presentation/widgets/attachment_chips.dart';
import 'terminal_palette.dart';

/// Bottom prompt line — terminal style, with attach / paste / drop support.
class TerminalPrompt extends StatefulWidget {
  const TerminalPrompt({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.attachments,
    required this.isStreaming,
    this.isDraggingFiles = false,
    required this.settings,
    required this.onSend,
    required this.onStop,
    required this.onAttachFiles,
    required this.onAttachImages,
    required this.onPaste,
    required this.onRemoveAttachment,
    required this.onTogglePin,
    this.cwdLabel,
    this.isGoalActive = false,
    this.goalIteration = 0,
    this.goalStatus,
    this.onToggleGoal,
    this.isMultitaskActive = false,
    this.multitaskQueued = 0,
    this.onToggleMultitask,
    this.attachmentStatus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<AttachmentItem> attachments;
  final bool isStreaming;
  final bool isDraggingFiles;
  final AppSettings settings;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttachFiles;
  final VoidCallback onAttachImages;
  final Future<AttachmentPasteResult> Function() onPaste;
  final void Function(String id) onRemoveAttachment;
  final void Function(String id) onTogglePin;
  final String? cwdLabel;
  final bool isGoalActive;
  final int goalIteration;
  final String? goalStatus;
  final VoidCallback? onToggleGoal;
  final bool isMultitaskActive;
  final int multitaskQueued;
  final VoidCallback? onToggleMultitask;
  final String? attachmentStatus;

  @override
  State<TerminalPrompt> createState() => _TerminalPromptState();
}

class _TerminalPromptState extends State<TerminalPrompt> {
  bool _hasText = false;

  bool get _enterSends =>
      widget.settings.composerEnterBehavior == ComposerEnterBehavior.send;

  bool get _canSend =>
      !widget.isStreaming && (_hasText || widget.attachments.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_syncHasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncHasText);
    super.dispose();
  }

  void _syncHasText() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  Future<void> _handlePaste() async {
    final result = await widget.onPaste();
    if (!mounted) return;
    if (result.attached) return;
    final text = result.insertedText;
    if (text == null || text.isEmpty) return;
    _insertText(text);
  }

  void _insertText(String text) {
    final controller = widget.controller;
    final selection = controller.selection;
    final start = selection.start >= 0
        ? selection.start
        : controller.text.length;
    final end = selection.end >= 0 ? selection.end : controller.text.length;
    final newText = controller.text.replaceRange(start, end, text);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isPaste =
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (isPaste) {
      unawaited(_handlePaste());
      return KeyEventResult.handled;
    }

    if (!_enterSends) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (_canSend) {
      widget.onSend();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);
    final dragging = widget.isDraggingFiles;
    final border = dragging ? GrokkerColors.ember : theme.panelBorder;

    return Container(
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border(
          top: BorderSide(color: border, width: dragging ? 1.5 : 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.attachments.isNotEmpty) ...[
            AttachmentChips(
              attachments: widget.attachments,
              onRemove: widget.onRemoveAttachment,
              onTogglePin: widget.onTogglePin,
            ),
            const SizedBox(height: 8),
          ],
          if (widget.attachmentStatus != null &&
              widget.attachmentStatus!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.attachmentStatus!,
                style: GrokkerTypography.mono(
                  size: 11,
                  color: GrokkerColors.emberBright,
                ),
              ),
            ),
          if (dragging)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '↓ drop files / images to attach',
                style: GrokkerTypography.mono(
                  size: 12,
                  color: GrokkerColors.emberBright,
                ),
              ),
            ),
          if (widget.onToggleGoal != null || widget.onToggleMultitask != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.onToggleGoal != null)
                    _ModeChip(
                      key: const ValueKey('toggle_goal'),
                      icon: widget.isGoalActive
                          ? Icons.flag
                          : Icons.outlined_flag,
                      label: widget.isGoalActive
                          ? (widget.goalIteration > 0
                                ? 'Goal · ${widget.goalIteration}'
                                : 'Goal ON')
                          : 'Goal',
                      active: widget.isGoalActive,
                      tooltip: widget.isGoalActive
                          ? 'Stop goal autopilot'
                          : 'Goal mode — type a goal (or use current text), tap Goal, auto-continues until ✅ Goal achieved',
                      onTap: widget.onToggleGoal!,
                    ),
                  if (widget.onToggleMultitask != null)
                    _ModeChip(
                      key: const ValueKey('toggle_multitask'),
                      icon: Icons.hub_outlined,
                      label: widget.multitaskQueued > 0
                          ? 'Multitask (${widget.multitaskQueued})'
                          : 'Multitask',
                      active: widget.isMultitaskActive,
                      tooltip: widget.isMultitaskActive
                          ? 'Multitask on — prefer parallel subagents'
                          : 'Multitask — split work across parallel tracks / subagents',
                      onTap: widget.onToggleMultitask!,
                    ),
                  if (widget.isGoalActive &&
                      (widget.goalStatus?.isNotEmpty ?? false))
                    Text(
                      widget.goalStatus!,
                      style: GrokkerTypography.mono(
                        size: 11,
                        color: TerminalPalette.user,
                      ),
                    ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: theme.canvas,
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              border: Border.all(
                color: dragging ? GrokkerColors.ember : theme.panelBorder,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 8),
                  child: Text(
                    '❯',
                    style: GrokkerTypography.mono(
                      size: 15,
                      color: widget.isStreaming
                          ? TerminalPalette.dim
                          : TerminalPalette.user,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Shortcuts(
                    shortcuts: {
                      LogicalKeySet(
                        Platform.isMacOS
                            ? LogicalKeyboardKey.meta
                            : LogicalKeyboardKey.control,
                        LogicalKeyboardKey.enter,
                      ): const _SendIntent(),
                    },
                    child: Actions(
                      actions: {
                        _SendIntent: CallbackAction<_SendIntent>(
                          onInvoke: (_) {
                            if (_canSend) widget.onSend();
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        onKeyEvent: _handleKeyEvent,
                        child: TextField(
                          key: const ValueKey('composer_input'),
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          maxLines: 6,
                          minLines: 1,
                          enabled: !widget.isStreaming,
                          style: GrokkerTypography.mono(
                            size: 13,
                            color: TerminalPalette.userBody,
                          ),
                          cursorColor: TerminalPalette.user,
                          cursorWidth: 2,
                          textInputAction: _enterSends
                              ? TextInputAction.send
                              : TextInputAction.newline,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.isStreaming
                                ? 'streaming… (Esc to stop)'
                                : 'type a prompt…',
                            hintStyle: GrokkerTypography.mono(
                              size: 13,
                              color: GrokkerColors.fog,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: _enterSends && _canSend
                              ? (_) => widget.onSend()
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                _MiniIcon(
                  key: const ValueKey('attach_images'),
                  icon: Icons.image_outlined,
                  tooltip: 'Attach images',
                  onPressed: widget.onAttachImages,
                ),
                _MiniIcon(
                  key: const ValueKey('attach_files'),
                  icon: Icons.attach_file,
                  tooltip: 'Attach files',
                  onPressed: widget.onAttachFiles,
                ),
                if (widget.isStreaming)
                  _MiniIcon(
                    key: const ValueKey('stop_generation'),
                    icon: Icons.stop_circle_outlined,
                    tooltip: 'Stop (Esc)',
                    color: GrokkerColors.errorRed,
                    onPressed: widget.onStop,
                  )
                else
                  _MiniIcon(
                    key: const ValueKey('send_prompt'),
                    icon: Icons.keyboard_return,
                    tooltip: 'Send',
                    color: _canSend
                        ? GrokkerColors.emberBright
                        : GrokkerColors.fog,
                    onPressed: _canSend ? widget.onSend : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, color: color ?? GrokkerColors.fog, size: 18),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? GrokkerColors.emberBright : GrokkerColors.fog;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? GrokkerColors.ember.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GrokkerRadius.chip),
              border: Border.all(
                color: active
                    ? GrokkerColors.ember.withValues(alpha: 0.45)
                    : GrokkerColors.iron,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 6),
                Text(label, style: GrokkerTypography.caption(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}
