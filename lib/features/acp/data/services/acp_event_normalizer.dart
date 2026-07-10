import '../../domain/models/acp_models.dart';

class AcpEventNormalizer {
  AcpEvent normalizeNotification(AcpJsonRpcNotification notification) {
    final params = notification.params ?? {};
    final timestamp = DateTime.now();

    if (notification.method == 'session/update') {
      return _normalizeSessionUpdate(params, timestamp);
    }

    return AcpEvent(
      type: AcpEventType.unknown,
      timestamp: timestamp,
      rawPayload: {'method': notification.method, 'params': params},
    );
  }

  AcpEvent normalizeClientRequest(String method, Map<String, dynamic> params) {
    final timestamp = DateTime.now();
    switch (method) {
      case 'fs/read_text_file':
        return AcpEvent(
          type: AcpEventType.fileReadRequested,
          timestamp: timestamp,
          rawPayload: params,
          title: params['path'] as String?,
        );
      case 'fs/write_text_file':
        return AcpEvent(
          type: AcpEventType.fileWriteRequested,
          timestamp: timestamp,
          rawPayload: params,
          title: params['path'] as String?,
        );
      case 'session/request_permission':
        return AcpEvent(
          type: AcpEventType.permissionRequested,
          timestamp: timestamp,
          rawPayload: params,
          title: params['title'] as String?,
          toolCallId: params['toolCallId'] as String?,
        );
      case 'terminal/create':
        return AcpEvent(
          type: AcpEventType.terminalCommandRequested,
          timestamp: timestamp,
          rawPayload: params,
        );
      default:
        return AcpEvent(
          type: AcpEventType.unknown,
          timestamp: timestamp,
          rawPayload: {'method': method, 'params': params},
        );
    }
  }

  AcpEvent _normalizeSessionUpdate(
    Map<String, dynamic> params,
    DateTime timestamp,
  ) {
    final sessionId = params['sessionId'] as String?;
    final update = params['update'] as Map<String, dynamic>? ?? {};
    final sessionUpdate = update['sessionUpdate'] as String? ?? '';

    switch (sessionUpdate) {
      case 'agent_message_chunk':
        return _normalizeContentChunk(
          update: update,
          timestamp: timestamp,
          sessionId: sessionId,
          textType: AcpEventType.assistantTextChunk,
          imageType: AcpEventType.assistantImageChunk,
        );
      case 'user_message_chunk':
        return _normalizeContentChunk(
          update: update,
          timestamp: timestamp,
          sessionId: sessionId,
          textType: AcpEventType.unknown,
          imageType: AcpEventType.unknown,
        );
      case 'tool_call':
        return AcpEvent(
          type: AcpEventType.toolStarted,
          timestamp: timestamp,
          sessionId: sessionId,
          toolCallId: update['toolCallId'] as String?,
          title: update['title'] as String?,
          status: update['status'] as String? ?? 'pending',
          rawPayload: update,
        );
      case 'tool_call_update':
        return _normalizeToolCallUpdate(update, timestamp, sessionId);
      case 'usage_update':
        final cost = update['cost'] as Map<String, dynamic>?;
        return AcpEvent(
          type: AcpEventType.usageUpdate,
          timestamp: timestamp,
          sessionId: sessionId,
          usageUsed: update['used'] as int?,
          usageSize: update['size'] as int?,
          costAmount: (cost?['amount'] as num?)?.toDouble(),
          costCurrency: cost?['currency'] as String?,
          rawPayload: update,
        );
      case 'plan':
        return AcpEvent(
          type: AcpEventType.planUpdate,
          timestamp: timestamp,
          sessionId: sessionId,
          rawPayload: update,
        );
      case 'current_mode_update':
        return AcpEvent(
          type: AcpEventType.modelChanged,
          timestamp: timestamp,
          sessionId: sessionId,
          text: update['modeId'] as String?,
          rawPayload: update,
        );
      default:
        return AcpEvent(
          type: AcpEventType.unknown,
          timestamp: timestamp,
          sessionId: sessionId,
          rawPayload: update,
        );
    }
  }

  AcpEvent _normalizeContentChunk({
    required Map<String, dynamic> update,
    required DateTime timestamp,
    required String? sessionId,
    required AcpEventType textType,
    required AcpEventType imageType,
  }) {
    final content = update['content'] as Map<String, dynamic>? ?? {};
    final contentType = content['type'] as String? ?? 'text';

    if (contentType == 'image') {
      return AcpEvent(
        type: imageType,
        timestamp: timestamp,
        sessionId: sessionId,
        messageId: update['messageId'] as String?,
        imageData: content['data'] as String?,
        imageMimeType: content['mimeType'] as String?,
        rawPayload: update,
      );
    }

    return AcpEvent(
      type: textType,
      timestamp: timestamp,
      sessionId: sessionId,
      text: content['text'] as String? ?? '',
      messageId: update['messageId'] as String?,
      rawPayload: update,
    );
  }

  AcpEvent _normalizeToolCallUpdate(
    Map<String, dynamic> update,
    DateTime timestamp,
    String? sessionId,
  ) {
    final status = update['status'] as String? ?? '';
    final title = update['title'] as String? ?? '';
    final imagePayload = _extractImageFromToolUpdate(update);

    if (status == 'completed' && imagePayload != null) {
      return AcpEvent(
        type: AcpEventType.toolImageCompleted,
        timestamp: timestamp,
        sessionId: sessionId,
        toolCallId: update['toolCallId'] as String?,
        title: title,
        status: status,
        imageData: imagePayload.data,
        imagePath: imagePayload.path,
        imageMimeType: imagePayload.mimeType,
        rawPayload: update,
      );
    }

    final type = status == 'failed'
        ? AcpEventType.toolFailed
        : status == 'completed'
        ? AcpEventType.toolCompleted
        : AcpEventType.toolStarted;

    return AcpEvent(
      type: type,
      timestamp: timestamp,
      sessionId: sessionId,
      toolCallId: update['toolCallId'] as String?,
      title: title,
      status: status,
      rawPayload: update,
    );
  }

  _ImagePayload? _extractImageFromToolUpdate(Map<String, dynamic> update) {
    final rawOutput = update['rawOutput'];
    if (rawOutput is Map<String, dynamic>) {
      final outputType = rawOutput['type'] as String?;
      if (outputType == 'ImageGen') {
        final path = rawOutput['path'] as String?;
        if (path != null && path.isNotEmpty) {
          return _ImagePayload(path: path);
        }
      }
    }

    final content = update['content'];
    if (content is! List<dynamic>) return null;

    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;
      final inner = item['content'];
      if (inner is! Map<String, dynamic>) continue;
      if (inner['type'] == 'image') {
        final data = inner['data'] as String?;
        if (data != null && data.isNotEmpty) {
          return _ImagePayload(
            data: data,
            mimeType: inner['mimeType'] as String?,
          );
        }
      }
    }

    return null;
  }
}

class _ImagePayload {
  const _ImagePayload({this.data, this.path, this.mimeType});

  final String? data;
  final String? path;
  final String? mimeType;
}
