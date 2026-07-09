import 'package:equatable/equatable.dart';

import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';

enum AppSessionStatus { idle, streaming, error, cancelled }

class AppSession extends Equatable {
  const AppSession({
    required this.id,
    required this.title,
    required this.workspacePath,
    required this.createdAt,
    required this.updatedAt,
    required this.selectedModel,
    required this.selectedEffort,
    this.acpSessionId,
    this.messages = const [],
    this.attachments = const [],
    this.processCommand,
    this.status = AppSessionStatus.idle,
    this.rawEventCount = 0,
    this.modelConfirmed = false,
    this.effortConfirmed = false,
    this.titleGenerated = false,
  });

  final String id;
  final String? acpSessionId;
  final String workspacePath;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GrokModel selectedModel;
  final ThinkingEffort selectedEffort;
  final List<ChatMessage> messages;
  final List<AttachmentItem> attachments;
  final String? processCommand;
  final AppSessionStatus status;
  final int rawEventCount;
  final bool modelConfirmed;
  final bool effortConfirmed;
  final bool titleGenerated;

  AppSession copyWith({
    String? acpSessionId,
    String? title,
    DateTime? updatedAt,
    GrokModel? selectedModel,
    ThinkingEffort? selectedEffort,
    List<ChatMessage>? messages,
    List<AttachmentItem>? attachments,
    String? processCommand,
    AppSessionStatus? status,
    int? rawEventCount,
    bool? modelConfirmed,
    bool? effortConfirmed,
    bool? titleGenerated,
  }) {
    return AppSession(
      id: id,
      acpSessionId: acpSessionId ?? this.acpSessionId,
      workspacePath: workspacePath,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedEffort: selectedEffort ?? this.selectedEffort,
      messages: messages ?? this.messages,
      attachments: attachments ?? this.attachments,
      processCommand: processCommand ?? this.processCommand,
      status: status ?? this.status,
      rawEventCount: rawEventCount ?? this.rawEventCount,
      modelConfirmed: modelConfirmed ?? this.modelConfirmed,
      effortConfirmed: effortConfirmed ?? this.effortConfirmed,
      titleGenerated: titleGenerated ?? this.titleGenerated,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'acpSessionId': acpSessionId,
    'workspacePath': workspacePath,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'selectedModel': selectedModel.name,
    'selectedEffort': selectedEffort.name,
    'messages': messages.map((m) => m.toJson()).toList(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'processCommand': processCommand,
    'status': status.name,
    'rawEventCount': rawEventCount,
    'modelConfirmed': modelConfirmed,
    'effortConfirmed': effortConfirmed,
    'titleGenerated': titleGenerated,
  };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      id: json['id'] as String,
      acpSessionId: json['acpSessionId'] as String?,
      workspacePath: json['workspacePath'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled session',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      selectedModel:
          GrokModelX.fromString(json['selectedModel'] as String?) ??
          GrokModel.grokBuild01,
      selectedEffort:
          ThinkingEffortX.fromString(json['selectedEffort'] as String?) ??
          ThinkingEffort.auto,
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => AttachmentItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      processCommand: json['processCommand'] as String?,
      status: AppSessionStatus.values.byName(
        json['status'] as String? ?? 'idle',
      ),
      rawEventCount: json['rawEventCount'] as int? ?? 0,
      modelConfirmed: json['modelConfirmed'] as bool? ?? false,
      effortConfirmed: json['effortConfirmed'] as bool? ?? false,
      titleGenerated: json['titleGenerated'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    acpSessionId,
    workspacePath,
    title,
    createdAt,
    updatedAt,
    selectedModel,
    selectedEffort,
    messages,
    attachments,
    processCommand,
    status,
    rawEventCount,
    modelConfirmed,
    effortConfirmed,
    titleGenerated,
  ];
}
