import 'package:equatable/equatable.dart';

enum DiffStatus { pending, approved, rejected, applied }

class DiffFile extends Equatable {
  const DiffFile({
    required this.id,
    required this.path,
    required this.unifiedDiff,
    required this.status,
    this.beforeContent,
    this.afterContent,
  });

  final String id;
  final String path;
  final String unifiedDiff;
  final DiffStatus status;
  final String? beforeContent;
  final String? afterContent;

  DiffFile copyWith({
    String? unifiedDiff,
    DiffStatus? status,
    String? afterContent,
  }) {
    return DiffFile(
      id: id,
      path: path,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      status: status ?? this.status,
      beforeContent: beforeContent,
      afterContent: afterContent ?? this.afterContent,
    );
  }

  @override
  List<Object?> get props => [
    id,
    path,
    unifiedDiff,
    status,
    beforeContent,
    afterContent,
  ];
}
