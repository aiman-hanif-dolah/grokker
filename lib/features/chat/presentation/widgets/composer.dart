import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/app_settings.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_components.dart';
import '../../../../styles/grokker_typography.dart';
import '../../../attachments/presentation/cubit/attachment_cubit.dart';
import '../../../attachments/presentation/widgets/attachment_chips.dart';

class Composer extends StatefulWidget {
  const Composer({
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
    this.isGoalActive = false,
    this.goalIteration = 0,
    this.onToggleGoal,
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
  final bool isGoalActive;
  final int goalIteration;
  final VoidCallback? onToggleGoal;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  bool _focused = false;
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
    widget.focusNode.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(covariant Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachments.length != widget.attachments.length) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncHasText);
    widget.focusNode.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncHasText() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  void _syncFocus() {
    final next = widget.focusNode.hasFocus;
    if (next != _focused) setState(() => _focused = next);
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

  String get _hintText {
    if (_enterSends) {
      return 'Ask Grok anything…';
    }
    return 'Ask Grok anything… (Enter for newline, ⌘↩ to send)';
  }

  @override
  Widget build(BuildContext context) {
    final dragging = widget.isDraggingFiles;
    final borderColor = _focused
        ? GrokkerColors.signalBlue
        : dragging
        ? GrokkerColors.signalBlue.withValues(alpha: 0.6)
        : GrokkerColors.pewter.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GrokkerSurfaces.voidFloor.withValues(alpha: 0),
            GrokkerSurfaces.deepPanel,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        GrokkerSpacing.s24,
        GrokkerSpacing.s12,
        GrokkerSpacing.s24,
        GrokkerSpacing.s20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: GrokkerSpacing.chatMaxWidth + 48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.attachments.isNotEmpty) ...[
                AttachmentChips(
                  attachments: widget.attachments,
                  onRemove: widget.onRemoveAttachment,
                  onTogglePin: widget.onTogglePin,
                ),
                const SizedBox(height: GrokkerSpacing.s12),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: dragging
                      ? GrokkerColors.signalBlue.withValues(alpha: 0.06)
                      : GrokkerSurfaces.raised,
                  borderRadius: BorderRadius.circular(GrokkerRadius.panel),
                  border: Border.all(
                    color: borderColor,
                    width: _focused ? 1.5 : 1,
                  ),
                  boxShadow: _focused
                      ? GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 16)
                      : const [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                padding: const EdgeInsets.fromLTRB(
                  GrokkerSpacing.s8,
                  GrokkerSpacing.s8,
                  GrokkerSpacing.s8,
                  GrokkerSpacing.s8,
                ),
                child: Column(
                  children: [
                    if (dragging)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: GrokkerSpacing.s8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.file_download_outlined,
                              size: 16,
                              color: GrokkerColors.signalBlueBright,
                            ),
                            const SizedBox(width: GrokkerSpacing.s8),
                            Text(
                              'Drop files to attach',
                              style: GrokkerTypography.caption(
                                color: GrokkerColors.signalBlueBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ComposerIconButton(
                          icon: Icons.image_outlined,
                          tooltip: 'Upload images',
                          onPressed: widget.onAttachImages,
                        ),
                        _ComposerIconButton(
                          icon: Icons.attach_file_rounded,
                          tooltip: 'Upload files',
                          onPressed: widget.onAttachFiles,
                        ),
                        const SizedBox(width: GrokkerSpacing.s4),
                        Expanded(
                          child: Shortcuts(
                            shortcuts: {
                              LogicalKeySet(
                                Platform.isMacOS
                                    ? LogicalKeyboardKey.meta
                                    : LogicalKeyboardKey.control,
                                LogicalKeyboardKey.enter,
                              ): const SendIntent(),
                            },
                            child: Actions(
                              actions: {
                                SendIntent: CallbackAction<SendIntent>(
                                  onInvoke: (_) {
                                    if (_canSend) widget.onSend();
                                    return null;
                                  },
                                ),
                              },
                              child: Focus(
                                onKeyEvent: _handleKeyEvent,
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: widget.focusNode,
                                  maxLines: 8,
                                  minLines: 1,
                                  style: GrokkerTypography.body(),
                                  cursorColor: GrokkerColors.signalBlue,
                                  textInputAction: _enterSends
                                      ? TextInputAction.send
                                      : TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: _hintText,
                                    hintStyle: GrokkerTypography.bodySm(
                                      color: GrokkerColors.slate,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: GrokkerSpacing.s8,
                                      vertical: GrokkerSpacing.s8,
                                    ),
                                    isDense: true,
                                  ),
                                  onSubmitted: _enterSends && _canSend
                                      ? (_) => widget.onSend()
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: GrokkerSpacing.s8),
                        if (widget.isStreaming)
                          _ComposerActionButton(
                            icon: Icons.stop_rounded,
                            tooltip: 'Stop generation',
                            isActive: true,
                            isDestructive: true,
                            onPressed: widget.onStop,
                          )
                        else
                          _ComposerActionButton(
                            icon: Icons.arrow_upward_rounded,
                            tooltip: 'Send message',
                            isActive: _canSend,
                            onPressed: _canSend ? widget.onSend : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GrokkerSpacing.s8),
              _ShortcutBar(
                enterSends: _enterSends,
                isGoalActive: widget.isGoalActive,
                goalIteration: widget.goalIteration,
                onToggleGoal: widget.onToggleGoal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  const _ShortcutBar({
    required this.enterSends,
    this.isGoalActive = false,
    this.goalIteration = 0,
    this.onToggleGoal,
  });

  final bool enterSends;
  final bool isGoalActive;
  final int goalIteration;
  final VoidCallback? onToggleGoal;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      _ShortcutChip(icon: Icons.content_paste, label: '⌘V paste'),
      _ShortcutChip(icon: Icons.file_upload_outlined, label: 'drag files'),
      _ShortcutChip(
        icon: Icons.keyboard_return,
        label: enterSends ? 'Enter send' : 'Enter newline',
      ),
      _ShortcutChip(
        icon: Icons.swap_vert,
        label: enterSends ? '⇧Enter newline' : '⌘↩ send',
      ),
      if (onToggleGoal != null)
        _GoalToggleChip(
          isActive: isGoalActive,
          iteration: goalIteration,
          onPressed: onToggleGoal!,
        ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: GrokkerSpacing.s8,
      runSpacing: GrokkerSpacing.s4,
      children: shortcuts,
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GrokkerMetaChip(
      label: label,
      icon: icon,
      color: GrokkerColors.slate,
    );
  }
}

class _GoalToggleChip extends StatelessWidget {
  const _GoalToggleChip({
    required this.isActive,
    required this.iteration,
    required this.onPressed,
  });

  final bool isActive;
  final int iteration;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isActive
        ? 'Goal${iteration > 0 ? ' #$iteration' : ''}'
        : 'Goal';
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s8,
          vertical: GrokkerSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? GrokkerColors.signalBlue.withValues(alpha: 0.15)
              : GrokkerColors.slate.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          border: Border.all(
            color: isActive
                ? GrokkerColors.signalBlue.withValues(alpha: 0.5)
                : GrokkerColors.slate.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.flag : Icons.outlined_flag,
              size: 12,
              color: isActive
                  ? GrokkerColors.signalBlueBright
                  : GrokkerColors.fog,
            ),
            const SizedBox(width: GrokkerSpacing.s4),
            Text(
              label,
              style: GrokkerTypography.caption(
                color: isActive
                    ? GrokkerColors.signalBlueBright
                    : GrokkerColors.fog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          hoverColor: GrokkerColors.graphite,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              border: Border.all(color: GrokkerColors.gunmetal),
            ),
            child: Icon(icon, size: 18, color: GrokkerColors.fog),
          ),
        ),
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    this.isDestructive = false,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDestructive
        ? GrokkerColors.errorRed
        : GrokkerColors.signalBlue;

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [activeColor, activeColor.withValues(alpha: 0.7)],
                )
              : null,
          color: isActive ? null : GrokkerColors.steel,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? GrokkerShadows.glow(activeColor, blur: 12)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 20,
                color: isActive ? GrokkerColors.white : GrokkerColors.slate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SendIntent extends Intent {
  const SendIntent();
}
