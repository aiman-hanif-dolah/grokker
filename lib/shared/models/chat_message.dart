import 'package:equatable/equatable.dart';

import 'chat_image_attachment.dart';

enum ChatMessageRole { user, assistant, tool, system, error }

enum ChatMessageStatus { pending, streaming, completed, failed, cancelled }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = ChatMessageStatus.completed,
    this.messageId,
    this.toolCallId,
    this.title,
    this.images = const [],
  });

  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime createdAt;
  final ChatMessageStatus status;
  final String? messageId;
  final String? toolCallId;
  final String? title;
  final List<ChatImageAttachment> images;

  ChatMessage copyWith({
    String? content,
    ChatMessageStatus? status,
    String? messageId,
    String? title,
    List<ChatImageAttachment>? images,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      status: status ?? this.status,
      messageId: messageId ?? this.messageId,
      toolCallId: toolCallId,
      title: title ?? this.title,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'messageId': messageId,
    'toolCallId': toolCallId,
    'title': title,
    'images': images.map((i) => i.toJson()).toList(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List<dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      role: ChatMessageRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: ChatMessageStatus.values.byName(
        json['status'] as String? ?? 'completed',
      ),
      messageId: json['messageId'] as String?,
      toolCallId: json['toolCallId'] as String?,
      title: json['title'] as String?,
      images: rawImages == null
          ? const []
          : rawImages
                .map(
                  (e) => ChatImageAttachment.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    role,
    content,
    createdAt,
    status,
    messageId,
    toolCallId,
    title,
    images,
  ];
}