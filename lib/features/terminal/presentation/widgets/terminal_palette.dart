import 'package:flutter/material.dart';

import '../../../../shared/models/chat_message.dart';

/// Terminal role colors — high-contrast so you can scan who said what.
abstract final class TerminalPalette {
  // User — ember (your prompts)
  static const user = Color(0xFFFF7A33);
  static const userBody = Color(0xFFFFE8D6);
  static const userBg = Color(0x14FF5A00);

  // Grok assistant — cyan/teal
  static const grok = Color(0xFF22D3EE);
  static const grokBody = Color(0xFFE2F9FC);
  static const grokMuted = Color(0xFF67E8F9);
  static const grokBg = Color(0x1022D3EE);

  // Tools — amber
  static const tool = Color(0xFFFBBF24);
  static const toolBody = Color(0xFFFEF3C7);
  static const toolBg = Color(0x14F59E0B);

  // Errors — red
  static const error = Color(0xFFF87171);
  static const errorBody = Color(0xFFFECACA);
  static const errorBg = Color(0x1AEF4444);

  // System — violet
  static const system = Color(0xFFA78BFA);
  static const systemBody = Color(0xFFDDD6FE);
  static const systemBg = Color(0x148B5CF6);

  static const warning = Color(0xFFFB923C);
  static const warningBody = Color(0xFFFED7AA);
  static const success = Color(0xFF4ADE80);
  static const code = Color(0xFFF0ABFC);
  static const heading = Color(0xFF67E8F9);
  static const bullet = Color(0xFF94A3B8);
  static const boldish = Color(0xFFFFFFFF);
  static const dim = Color(0xFF94A3B8);

  static Color prefix(ChatMessageRole role) => switch (role) {
    ChatMessageRole.user => user,
    ChatMessageRole.assistant => grok,
    ChatMessageRole.tool => tool,
    ChatMessageRole.error => error,
    ChatMessageRole.system => system,
  };

  static Color body(ChatMessageRole role) => switch (role) {
    ChatMessageRole.user => userBody,
    ChatMessageRole.assistant => grokBody,
    ChatMessageRole.tool => toolBody,
    ChatMessageRole.error => errorBody,
    ChatMessageRole.system => systemBody,
  };

  static Color? background(ChatMessageRole role) => switch (role) {
    ChatMessageRole.user => userBg,
    ChatMessageRole.assistant => null,
    ChatMessageRole.tool => toolBg,
    ChatMessageRole.error => errorBg,
    ChatMessageRole.system => systemBg,
  };

  static String label(ChatMessage message) => switch (message.role) {
    ChatMessageRole.user => 'you',
    ChatMessageRole.assistant => 'grok',
    ChatMessageRole.tool =>
      (message.title?.trim().isNotEmpty ?? false)
          ? _toolLabel(message.title!)
          : 'tool',
    ChatMessageRole.error => 'err',
    ChatMessageRole.system => 'sys',
  };

  static String glyph(ChatMessageRole role) => switch (role) {
    ChatMessageRole.user => '❯',
    ChatMessageRole.assistant => '✦',
    ChatMessageRole.tool => '⚙',
    ChatMessageRole.error => '✖',
    ChatMessageRole.system => '#',
  };

  /// Full tool name for the stacked header (ellipsis applied by the widget).
  static String _toolLabel(String title) {
    final t = title.trim();
    // Prefer the bare tool id before a colon / space payload.
    final cut = t.indexOf(RegExp(r'[:\s]'));
    final head = cut > 0 ? t.substring(0, cut) : t;
    return head.isEmpty ? 'tool' : head;
  }

  static Color? statusTint(ChatMessageStatus status) => switch (status) {
    ChatMessageStatus.streaming => grok,
    ChatMessageStatus.failed => error,
    ChatMessageStatus.cancelled => warning,
    ChatMessageStatus.pending => dim,
    ChatMessageStatus.completed => null,
  };
}
