import 'dart:convert';
import 'dart:io';

import '../../../../core/utils/path_safety.dart';
import '../../../../shared/models/approval_mode.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../../../shared/models/workspace_info.dart';

class PromptEnvelopeBuilder {
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
      if (attachmentSection != null) {
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

    final imageCount =
        attachments.where((a) => a.type == AttachmentType.image).length;
    if (imageCount == 1) {
      return 'Please analyze the attached image.';
    }
    if (imageCount > 1) {
      return 'Please analyze the attached images.';
    }
    if (attachments.isNotEmpty) {
      return 'Please review the attached files.';
    }
    return trimmed;
  }

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

    for (final attachment in attachments) {
      if (attachment.type == AttachmentType.image) {
        final encoded = await _readImagePayload(attachment);
        if (encoded == null) continue;
        blocks.add(_imagePromptBlock(encoded: encoded));
      } else if (supportsEmbeddedContext &&
          inlineTextContent != null &&
          attachment.type != AttachmentType.image &&
          attachment.type != AttachmentType.pdf) {
        blocks.add({
          'type': 'resource',
          'resource': {
            'uri': PathSafety.toFileUri(attachment.path),
            'mimeType': attachment.mimeType,
            'text': inlineTextContent,
          },
        });
      } else {
        blocks.add({
          'type': 'resource_link',
          'uri': PathSafety.toFileUri(attachment.path),
          'name': attachment.fileName,
          'mimeType': attachment.mimeType,
        });
      }
    }

    return blocks;
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

  Future<Map<String, String>?> _readImagePayload(AttachmentItem attachment) async {
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
}
