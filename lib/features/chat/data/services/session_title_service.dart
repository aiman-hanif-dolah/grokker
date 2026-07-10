/// Helpers for Grok-generated session titles.
class SessionTitleService {
  static const placeholderPattern =
      r'^(Session \d+|New chat|Untitled session)$';

  bool isPlaceholderTitle(String title) {
    return RegExp(
      placeholderPattern,
      caseSensitive: false,
    ).hasMatch(title.trim());
  }

  String buildTitlePrompt({
    required String userMessage,
    String? assistantPreview,
  }) {
    final preview = assistantPreview == null || assistantPreview.isEmpty
        ? ''
        : '\nAssistant reply (summary context): '
              '${_clip(assistantPreview, 280)}';

    return '[Grokker metadata — respond with a session title only]\n'
        'Create a concise session title (3–6 words) that summarizes the '
        "user's intent below. Rules:\n"
        '- Reply with ONLY the title text\n'
        '- No quotes, no punctuation at the end\n'
        '- No explanation or preamble\n'
        '- Title case preferred\n\n'
        'User message: ${_clip(userMessage, 500)}'
        '$preview';
  }

  String? parseTitle(String raw) {
    var title = raw.trim();
    if (title.isEmpty) return null;

    // Take first non-empty line if Grok added extra text.
    title = title
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => title);

    title = title.replaceAll(RegExp(r'^["\x27`]+|["\x27`]+$'), '');
    title = title.replaceAll(
      RegExp(r'^(Title:|Session:)\s*', caseSensitive: false),
      '',
    );
    title = title.replaceAll(RegExp(r'[.!?]+$'), '');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (title.isEmpty) return null;
    if (title.length > 60) title = '${title.substring(0, 57)}…';
    return title;
  }

  String _clip(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}
