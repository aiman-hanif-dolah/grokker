import 'package:equatable/equatable.dart';

class ChatImageAttachment extends Equatable {
  const ChatImageAttachment({
    required this.id,
    required this.path,
    this.mimeType = 'image/png',
    this.width,
    this.height,
  });

  final String id;
  final String path;
  final String mimeType;
  final int? width;
  final int? height;

  ChatImageAttachment copyWith({
    String? path,
    String? mimeType,
    int? width,
    int? height,
  }) {
    return ChatImageAttachment(
      id: id,
      path: path ?? this.path,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'mimeType': mimeType,
    'width': width,
    'height': height,
  };

  factory ChatImageAttachment.fromJson(Map<String, dynamic> json) {
    return ChatImageAttachment(
      id: json['id'] as String,
      path: json['path'] as String,
      mimeType: json['mimeType'] as String? ?? 'image/png',
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, path, mimeType, width, height];
}