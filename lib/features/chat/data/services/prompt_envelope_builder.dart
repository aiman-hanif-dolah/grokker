import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/path_safety.dart';
import '../../../../shared/models/approval_mode.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../../../shared/models/workspace_info.dart';

class PromptEnvelopeBuilder {
  /// Max binary embed size (~12MB). Larger files keep a path link + summary.
  static const maxBinaryEmbedBytes = 12 * 1024 * 1024;

  String buildTextEnvelope({
    required String userMessage,
    required WorkspaceInfo? workspace,
    required GrokModel model,
    required ThinkingEffort effort,
    required List<AttachmentItem> attachments,
    required ApprovalMode approvalMode,
    String? attachmentSection,
    String? workspaceMemorySection,
  }) {
    final buffer = StringBuffer();
    if (workspace != null) {
      buffer.writeln('Workspace: ${workspace.path}');
      buffer.writeln('Project type: ${workspace.primaryProjectType}');
      if (workspace.gitBranch != null) {
        buffer.writeln('Git branch: ${workspace.gitBranch}');
      }
    }

    if (workspaceMemorySection != null &&
        workspaceMemorySection.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<workspace_context>');
      buffer.writeln(workspaceMemorySection.trim());
      buffer.writeln('</workspace_context>');
    }
    buffer.writeln('Model requested: ${model.displayName}');
    buffer.writeln('Thinking effort requested: ${effort.displayName}');
    buffer.writeln('Approval mode: ${approvalMode.displayName}');

    if (attachments.isNotEmpty || attachmentSection != null) {
      buffer.writeln('Attached files:');
      if (attachmentSection != null && attachmentSection.isNotEmpty) {
        buffer.writeln(attachmentSection);
      } else {
        for (final a in attachments) {
          final label = a.type == AttachmentType.image ? a.fileName : a.path;
          buffer.writeln('* [${a.type.name}] $label (${a.sizeBytes} bytes)');
        }
      }
    }

    buffer.writeln('User request:');
    buffer.writeln(_resolveUserMessage(userMessage, attachments));
    return buffer.toString();
  }

  String _resolveUserMessage(
    String userMessage,
    List<AttachmentItem> attachments,
  ) {
    final trimmed = userMessage.trim();
    if (trimmed.isNotEmpty) return trimmed;

    final imageCount = attachments
        .where((a) => a.type == AttachmentType.image)
        .length;
    final pdfCount = attachments
        .where((a) => a.type == AttachmentType.pdf)
        .length;
    if (imageCount == 1) {
      return 'Please analyze the attached image.';
    }
    if (imageCount > 1) {
      return 'Please analyze the attached images.';
    }
    if (pdfCount == 1) {
      return 'Please read and analyze the attached PDF document.';
    }
    if (pdfCount > 1) {
      return 'Please read and analyze the attached PDF documents.';
    }
    if (attachments.isNotEmpty) {
      return 'Please review the attached files.';
    }
    return trimmed;
  }

  /// Build ACP prompt content blocks with file contents actually embedded
  /// (text / base64 blob), not just path links.
  Future<List<Map<String, dynamic>>> buildAcpPrompt({
    required String text,
    required List<AttachmentItem> attachments,
    required bool supportsImages,
    required bool supportsEmbeddedContext,
    String? inlineTextContent,
  }) async {
    final blocks = <Map<String, dynamic>>[
      {'type': 'text', 'text': text},
    ];

    // Fallback: when embedded resources aren't advertised, append readable
    // content into an extra text block so the model still sees file bodies.
    final fallbackText = StringBuffer();

    for (final attachment in attachments) {
      if (attachment.type == AttachmentType.image) {
        final encoded = await _readImagePayload(attachment);
        if (encoded == null) {
          fallbackText.writeln(
            '\n[image missing: ${attachment.fileName} at ${attachment.path}]',
          );
          continue;
        }
        blocks.add(_imagePromptBlock(encoded: encoded));
        continue;
      }

      final payload = await _readFilePayload(attachment);
      if (payload == null) {
        blocks.add(_resourceLinkBlock(attachment));
        fallbackText.writeln(
          '\n[could not read attachment: ${attachment.fileName}]',
        );
        continue;
      }

      if (supportsEmbeddedContext) {
        if (payload.kind == _PayloadKind.text) {
          blocks.add({
            'type': 'resource',
            'resource': {
              'uri': PathSafety.toFileUri(attachment.path),
              'mimeType': attachment.mimeType,
              'text': payload.text,
            },
          });
        } else {
          blocks.add({
            'type': 'resource',
            'resource': {
              'uri': PathSafety.toFileUri(attachment.path),
              'mimeType': attachment.mimeType,
              'blob': payload.base64,
            },
          });
        }
        // Always include a link too for agent fs tools.
        blocks.add(_resourceLinkBlock(attachment));
      } else {
        // No embedded-context capability: put content in text + link.
        blocks.add(_resourceLinkBlock(attachment));
        if (payload.kind == _PayloadKind.text) {
          fallbackText.writeln();
          fallbackText.writeln('--- BEGIN FILE: ${attachment.fileName} ---');
          fallbackText.writeln(payload.text);
          fallbackText.writeln('--- END FILE: ${attachment.fileName} ---');
        } else {
          // Binary (e.g. PDF): still embed as resource blob when possible —
          // many agents accept resource even without the capability flag.
          if (attachment.sizeBytes <= maxBinaryEmbedBytes &&
              payload.base64 != null) {
            blocks.add({
              'type': 'resource',
              'resource': {
                'uri': PathSafety.toFileUri(attachment.path),
                'mimeType': attachment.mimeType,
                'blob': payload.base64,
              },
            });
            fallbackText.writeln(
              '\n[binary attachment embedded: ${attachment.fileName} '
              '(${attachment.mimeType}, ${attachment.sizeBytes} bytes)]',
            );
          } else {
            fallbackText.writeln(
              '\n[binary attachment too large to embed: ${attachment.fileName} '
              'at ${attachment.path} — open via path]',
            );
          }
        }
      }
    }

    // Legacy single inline blob (if caller still passes it).
    if (inlineTextContent != null &&
        inlineTextContent.isNotEmpty &&
        supportsEmbeddedContext) {
      blocks.add({'type': 'text', 'text': inlineTextContent});
    }

    if (fallbackText.isNotEmpty) {
      blocks.add({'type': 'text', 'text': fallbackText.toString()});
    }

    return blocks;
  }

  Map<String, dynamic> _resourceLinkBlock(AttachmentItem attachment) {
    return {
      'type': 'resource_link',
      'uri': PathSafety.toFileUri(attachment.path),
      'name': attachment.fileName,
      'mimeType': attachment.mimeType,
      'size': attachment.sizeBytes,
    };
  }

  Map<String, dynamic> _imagePromptBlock({
    required Map<String, String> encoded,
  }) {
    return {
      'type': 'image',
      'mimeType': encoded['mimeType']!,
      'data': encoded['data']!,
      'uri': encoded['uri']!,
    };
  }

  Future<Map<String, String>?> _readImagePayload(
    AttachmentItem attachment,
  ) async {
    final file = File(attachment.path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    return {
      'mimeType': attachment.mimeType,
      'data': base64Encode(bytes),
      'uri': PathSafety.toFileUri(attachment.path),
    };
  }

  Future<_FilePayload?> _readFilePayload(AttachmentItem attachment) async {
    final file = File(attachment.path);
    if (!await file.exists()) return null;

    final size = attachment.sizeBytes > 0
        ? attachment.sizeBytes
        : (await file.stat()).size;

    // Prefer text for known text-like types under size limit.
    if (_isTextLike(attachment) &&
        size <= AppConstants.inlineTextMaxBytes * 8) {
      try {
        final text = await file.readAsString();
        if (text.isNotEmpty) {
          return _FilePayload.text(text);
        }
      } catch (_) {
        // Fall through to binary.
      }
    }

    // Binary / PDF / oversized text → base64 blob (with size guard).
    if (size > maxBinaryEmbedBytes) {
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return _FilePayload.binary(base64Encode(bytes));
    } catch (_) {
      return null;
    }
  }

  bool _isTextLike(AttachmentItem attachment) {
    switch (attachment.type) {
      case AttachmentType.text:
      case AttachmentType.code:
      case AttachmentType.markdown:
      case AttachmentType.config:
        return true;
      case AttachmentType.pdf:
      case AttachmentType.image:
      case AttachmentType.binary:
      case AttachmentType.unknown:
        return false;
    }
  }
}

enum _PayloadKind { text, binary }

class _FilePayload {
  const _FilePayload._({required this.kind, this.text, this.base64});

  factory _FilePayload.text(String text) =>
      _FilePayload._(kind: _PayloadKind.text, text: text);

  factory _FilePayload.binary(String base64) =>
      _FilePayload._(kind: _PayloadKind.binary, base64: base64);

  final _PayloadKind kind;
  final String? text;
  final String? base64;
}
