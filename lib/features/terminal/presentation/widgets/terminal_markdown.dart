import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../shared/models/chat_message.dart';
import 'terminal_palette.dart';

/// Renders markdown (bold, italic, code, lists, headers) in terminal colors.
class TerminalMarkdown extends StatelessWidget {
  const TerminalMarkdown({
    super.key,
    required this.data,
    required this.role,
    this.streaming = false,
  });

  final String data;
  final ChatMessageRole role;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final base = TerminalPalette.body(role);
    final sheet = _styleSheet(base, role);

    // Streaming: fast TextSpan path (partial markdown).
    // Completed: full Markdown so **bold**, *italic*, lists, etc. render.
    if (streaming) {
      return SelectableText.rich(
        TerminalMarkdownParser.parse(
          data,
          base: base,
          role: role,
          streaming: true,
        ),
      );
    }

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: sheet,
      // Shrink-wrap inside list rows / flexible parents.
      shrinkWrap: true,
      fitContent: true,
    );
  }

  MarkdownStyleSheet _styleSheet(Color base, ChatMessageRole role) {
    final mono = const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: [
        'Cascadia Mono',
        'Cascadia Code',
        'Consolas',
        'Menlo',
        'monospace',
      ],
    );

    TextStyle t(Color c, {FontWeight w = FontWeight.w400, double size = 13}) =>
        mono.copyWith(color: c, fontWeight: w, fontSize: size, height: 1.5);

    final heading = TerminalPalette.heading;
    final code = TerminalPalette.code;
    final bold = role == ChatMessageRole.user
        ? TerminalPalette.userBody
        : TerminalPalette.boldish;

    return MarkdownStyleSheet(
      p: t(base),
      pPadding: EdgeInsets.zero,
      h1: t(heading, w: FontWeight.w700, size: 18),
      h2: t(heading, w: FontWeight.w700, size: 16),
      h3: t(heading, w: FontWeight.w700, size: 14),
      h4: t(heading, w: FontWeight.w600, size: 13),
      h5: t(heading, w: FontWeight.w600, size: 13),
      h6: t(heading, w: FontWeight.w600, size: 12),
      strong: t(bold, w: FontWeight.w800),
      em: t(base, w: FontWeight.w400).copyWith(fontStyle: FontStyle.italic),
      del: t(
        TerminalPalette.dim,
      ).copyWith(decoration: TextDecoration.lineThrough),
      code: t(
        code,
        w: FontWeight.w600,
        size: 12,
      ).copyWith(backgroundColor: const Color(0x22FFFFFF)),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquote: t(TerminalPalette.dim).copyWith(fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: TerminalPalette.prefix(role).withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 10),
      listBullet: t(TerminalPalette.bullet),
      listIndent: 20,
      a: t(
        TerminalPalette.grokMuted,
      ).copyWith(decoration: TextDecoration.underline),
      tableHead: t(heading, w: FontWeight.w700, size: 12),
      tableBody: t(base, size: 12),
      tableBorder: TableBorder.all(color: const Color(0xFF3F3F46), width: 0.5),
      tableHeadAlign: TextAlign.left,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: TerminalPalette.dim.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

/// Inline markdown parser for streaming / fallback (no full AST).
class TerminalMarkdownParser {
  static TextSpan parse(
    String content, {
    required Color base,
    required ChatMessageRole role,
    bool streaming = false,
  }) {
    final spans = <InlineSpan>[];
    final lines = content.split('\n');
    var inFence = false;

    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(TextSpan(text: '\n', style: _base(base)));
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('```')) {
        inFence = !inFence;
        spans.add(
          TextSpan(
            text: line,
            style: _base(TerminalPalette.code, w: FontWeight.w600),
          ),
        );
        continue;
      }
      if (inFence) {
        spans.add(TextSpan(text: line, style: _base(TerminalPalette.code)));
        continue;
      }

      // Headings — strip # markers for cleaner look
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (h != null) {
        final indent = line.length - line.trimLeft().length;
        spans.add(
          TextSpan(
            text: '${' ' * indent}${h.group(2)}',
            style: _base(TerminalPalette.heading, w: FontWeight.w700, size: 14),
          ),
        );
        continue;
      }

      spans.addAll(_inline(line, base: base));
    }

    if (streaming) {
      spans.add(
        TextSpan(
          text: ' ▌',
          style: _base(TerminalPalette.grok, w: FontWeight.w700),
        ),
      );
    }

    return TextSpan(style: _base(base), children: spans);
  }

  /// Parse **bold**, *italic*, ***both***, `code`, ~~strike~~, __bold__, _italic_
  static List<InlineSpan> _inline(String text, {required Color base}) {
    // Order matters: triple markers before double/single; code first.
    final re = RegExp(
      r'(`+)([^`]+)\1' // `code` or ``code``
      r'|\*\*\*([^*]+)\*\*\*' // ***bold italic***
      r'|\*\*([^*]+)\*\*' // **bold**
      r'|__([^_]+)__' // __bold__
      r'|\*([^*]+)\*' // *italic*
      r'|_([^_]+)_' // _italic_
      r'|~~([^~]+)~~', // ~~strike~~
      multiLine: true,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in re.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, m.start), style: _base(base)),
        );
      }

      if (m.group(2) != null) {
        // code
        spans.add(
          TextSpan(
            text: m.group(2),
            style: _base(
              TerminalPalette.code,
              w: FontWeight.w600,
            ).copyWith(backgroundColor: const Color(0x22FFFFFF)),
          ),
        );
      } else if (m.group(3) != null) {
        // bold italic
        spans.add(
          TextSpan(
            text: m.group(3),
            style: _base(
              TerminalPalette.boldish,
              w: FontWeight.w800,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(4) != null || m.group(5) != null) {
        // bold
        spans.add(
          TextSpan(
            text: m.group(4) ?? m.group(5),
            style: _base(TerminalPalette.boldish, w: FontWeight.w800),
          ),
        );
      } else if (m.group(6) != null || m.group(7) != null) {
        // italic
        spans.add(
          TextSpan(
            text: m.group(6) ?? m.group(7),
            style: _base(base).copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(8) != null) {
        // strike
        spans.add(
          TextSpan(
            text: m.group(8),
            style: _base(
              TerminalPalette.dim,
            ).copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      }

      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: _base(base)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: _base(base)));
    }
    return spans;
  }

  static TextStyle _base(
    Color color, {
    FontWeight w = FontWeight.w400,
    double size = 13,
  }) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const [
        'Cascadia Mono',
        'Cascadia Code',
        'Consolas',
        'Menlo',
        'monospace',
      ],
      fontSize: size,
      height: 1.5,
      fontWeight: w,
      color: color,
    );
  }
}
