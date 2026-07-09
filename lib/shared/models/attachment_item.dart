import 'package:equatable/equatable.dart';

enum AttachmentType { image, pdf, text, code, markdown, config, unknown }

class AttachmentItem extends Equatable {
  const AttachmentItem({
    required this.id,
    required this.path,
    required this.type,
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
    this.pageCount,
    this.isPinned = false,
    this.warning,
  });

  final String id;
  final String path;
  final AttachmentType type;
  final String fileName;
  final int sizeBytes;
  final String mimeType;
  final int? pageCount;
  final bool isPinned;
  final String? warning;

  AttachmentItem copyWith({bool? isPinned, String? warning, int? pageCount}) {
    return AttachmentItem(
      id: id,
      path: path,
      type: type,
      fileName: fileName,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      pageCount: pageCount ?? this.pageCount,
      isPinned: isPinned ?? this.isPinned,
      warning: warning ?? this.warning,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'type': type.name,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'mimeType': mimeType,
    'pageCount': pageCount,
    'isPinned': isPinned,
    'warning': warning,
  };

  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      id: json['id'] as String,
      path: json['path'] as String,
      type: AttachmentType.values.byName(json['type'] as String),
      fileName: json['fileName'] as String,
      sizeBytes: json['sizeBytes'] as int,
      mimeType: json['mimeType'] as String,
      pageCount: json['pageCount'] as int?,
      isPinned: json['isPinned'] as bool? ?? false,
      warning: json['warning'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    path,
    type,
    fileName,
    sizeBytes,
    mimeType,
    pageCount,
    isPinned,
    warning,
  ];
}
