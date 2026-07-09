import 'package:equatable/equatable.dart';

class AcpJsonRpcRequest extends Equatable {
  const AcpJsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final dynamic id;
  final String method;
  final Map<String, dynamic>? params;

  Map<String, dynamic> toJson() => {
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
    if (params != null) 'params': params,
  };

  @override
  List<Object?> get props => [id, method, params];
}

class AcpJsonRpcResponse extends Equatable {
  const AcpJsonRpcResponse({required this.id, this.result, this.error});

  final dynamic id;
  final dynamic result;
  final AcpJsonRpcError? error;

  bool get isError => error != null;

  factory AcpJsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return AcpJsonRpcResponse(
      id: json['id'],
      result: json['result'],
      error: json['error'] != null
          ? AcpJsonRpcError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, result, error];
}

class AcpJsonRpcError extends Equatable {
  const AcpJsonRpcError({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final dynamic data;

  factory AcpJsonRpcError.fromJson(Map<String, dynamic> json) {
    return AcpJsonRpcError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'],
    );
  }

  @override
  List<Object?> get props => [code, message, data];
}

class AcpJsonRpcNotification extends Equatable {
  const AcpJsonRpcNotification({required this.method, this.params});

  final String method;
  final Map<String, dynamic>? params;

  factory AcpJsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return AcpJsonRpcNotification(
      method: json['method'] as String,
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [method, params];
}

enum AcpEventType {
  assistantTextChunk,
  assistantImageChunk,
  assistantMessageCompleted,
  promptTurnCompleted,
  toolStarted,
  toolCompleted,
  toolImageCompleted,
  toolFailed,
  fileReadRequested,
  fileWriteRequested,
  terminalCommandRequested,
  permissionRequested,
  modelChanged,
  sessionError,
  usageUpdate,
  planUpdate,
  unknown,
  raw,
}

class AcpEvent extends Equatable {
  const AcpEvent({
    required this.type,
    required this.timestamp,
    this.sessionId,
    this.text,
    this.toolCallId,
    this.title,
    this.status,
    this.rawPayload,
    this.messageId,
    this.usageUsed,
    this.usageSize,
    this.costAmount,
    this.costCurrency,
    this.imageData,
    this.imagePath,
    this.imageMimeType,
  });

  final AcpEventType type;
  final DateTime timestamp;
  final String? sessionId;
  final String? text;
  final String? toolCallId;
  final String? title;
  final String? status;
  final Map<String, dynamic>? rawPayload;
  final String? messageId;
  final int? usageUsed;
  final int? usageSize;
  final double? costAmount;
  final String? costCurrency;
  final String? imageData;
  final String? imagePath;
  final String? imageMimeType;

  @override
  List<Object?> get props => [
    type,
    timestamp,
    sessionId,
    text,
    toolCallId,
    title,
    status,
    rawPayload,
    messageId,
    usageUsed,
    usageSize,
    costAmount,
    costCurrency,
    imageData,
    imagePath,
    imageMimeType,
  ];
}

class AcpSession extends Equatable {
  const AcpSession({required this.id, this.cwd, this.modes});

  final String id;
  final String? cwd;
  final List<String>? modes;

  factory AcpSession.fromJson(Map<String, dynamic> json) {
    return AcpSession(
      id: json['sessionId'] as String? ?? json['id'] as String? ?? '',
      cwd: json['cwd'] as String?,
      modes: (json['modes'] as List<dynamic>?)?.cast<String>(),
    );
  }

  @override
  List<Object?> get props => [id, cwd, modes];
}

class DiagnosticLogEntry extends Equatable {
  const DiagnosticLogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  final DateTime timestamp;
  final String message;
  final String level;

  @override
  List<Object?> get props => [timestamp, message, level];
}

class PendingPermissionRequest extends Equatable {
  const PendingPermissionRequest({
    required this.id,
    required this.toolCallId,
    required this.title,
    required this.description,
    this.options = const [],
  });

  final String id;
  final String toolCallId;
  final String title;
  final String description;
  final List<String> options;

  @override
  List<Object?> get props => [id, toolCallId, title, description, options];
}
