import 'package:flutter/material.dart';

import '../../../../shared/models/chat_message.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_typography.dart';
import 'terminal_entry_tile.dart';

/// Fast terminal-style scrollback. Auto-scrolls when near the bottom.
class TerminalScrollback extends StatefulWidget {
  const TerminalScrollback({
    super.key,
    required this.messages,
    this.header,
    this.emptyChild,
  });

  final List<ChatMessage> messages;
  final Widget? header;
  final Widget? emptyChild;

  @override
  State<TerminalScrollback> createState() => _TerminalScrollbackState();
}

class _TerminalScrollbackState extends State<TerminalScrollback> {
  final _controller = ScrollController();
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant TerminalScrollback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stickToBottom && widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } else if (_stickToBottom &&
        widget.messages.isNotEmpty &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.last.content != oldWidget.messages.last.content) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final nearBottom = pos.pixels >= pos.maxScrollExtent - 48;
    if (nearBottom != _stickToBottom) {
      _stickToBottom = nearBottom;
    }
  }

  void _jumpToBottom() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return widget.emptyChild ??
          Center(
            child: Text(
              'Grokker terminal ready.\nType a prompt below.',
              textAlign: TextAlign.center,
              style: GrokkerTypography.mono(
                size: 13,
                color: GrokkerColors.slate,
              ),
            ),
          );
    }

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: widget.messages.length + (widget.header != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: widget.header!,
          );
        }
        final i = widget.header != null ? index - 1 : index;
        return TerminalEntryTile(message: widget.messages[i]);
      },
    );
  }
}
