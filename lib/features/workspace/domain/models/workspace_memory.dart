import 'package:equatable/equatable.dart';

class WorkspaceMemory extends Equatable {
  const WorkspaceMemory({
    required this.workspacePath,
    required this.fingerprint,
    required this.scannedAt,
    required this.fileCount,
    required this.directoryCount,
    required this.fileTreeSummary,
    this.agentsMd,
    this.readmeMd,
    this.cursorRules,
    this.keyFiles = const [],
    this.truncated = false,
  });

  final String workspacePath;
  final String fingerprint;
  final DateTime scannedAt;
  final int fileCount;
  final int directoryCount;
  final String fileTreeSummary;
  final String? agentsMd;
  final String? readmeMd;
  final String? cursorRules;
  final List<String> keyFiles;
  final bool truncated;

  bool get hasAgentInstructions =>
      (agentsMd?.trim().isNotEmpty ?? false) ||
      (cursorRules?.trim().isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
    'workspacePath': workspacePath,
    'fingerprint': fingerprint,
    'scannedAt': scannedAt.toIso8601String(),
    'fileCount': fileCount,
    'directoryCount': directoryCount,
    'fileTreeSummary': fileTreeSummary,
    'agentsMd': agentsMd,
    'readmeMd': readmeMd,
    'cursorRules': cursorRules,
    'keyFiles': keyFiles,
    'truncated': truncated,
  };

  factory WorkspaceMemory.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemory(
      workspacePath: json['workspacePath'] as String,
      fingerprint: json['fingerprint'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      fileCount: json['fileCount'] as int? ?? 0,
      directoryCount: json['directoryCount'] as int? ?? 0,
      fileTreeSummary: json['fileTreeSummary'] as String? ?? '',
      agentsMd: json['agentsMd'] as String?,
      readmeMd: json['readmeMd'] as String?,
      cursorRules: json['cursorRules'] as String?,
      keyFiles:
          (json['keyFiles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      truncated: json['truncated'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    workspacePath,
    fingerprint,
    scannedAt,
    fileCount,
    directoryCount,
    fileTreeSummary,
    agentsMd,
    readmeMd,
    cursorRules,
    keyFiles,
    truncated,
  ];
}
