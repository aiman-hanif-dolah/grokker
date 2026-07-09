import 'dart:io';

import '../../../../core/utils/path_safety.dart';
import '../../../../shared/models/approval_mode.dart';
import '../../../diff_viewer/data/services/diff_service.dart';

typedef ApprovalCallback = Future<bool> Function({
  required String method,
  required String path,
  required bool isWrite,
  required bool isOutsideWorkspace,
});

/// Handles inbound ACP client methods from Grok Build CLI.
class AcpClientRequestHandler {
  AcpClientRequestHandler({
    required this.diffService,
    this.workspacePath = '',
    this.approvalMode = ApprovalMode.autoApproveReads,
    this.onApprovalRequired,
  });

  final DiffService diffService;
  String workspacePath;
  ApprovalMode approvalMode;
  ApprovalCallback? onApprovalRequired;

  Future<Map<String, dynamic>> handle(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'fs/read_text_file':
        return _readTextFile(params);
      case 'fs/write_text_file':
        return _writeTextFile(params);
      case 'session/request_permission':
        return _handlePermission(params);
      default:
        return _handleUnknown(method, params);
    }
  }

  Map<String, dynamic> _handlePermission(Map<String, dynamic> params) {
    final options = (params['options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    String optionId = 'allow-once';
    for (final option in options) {
      final kind = option['kind'] as String? ?? '';
      if (kind.contains('allow')) {
        optionId = option['optionId'] as String? ?? optionId;
        break;
      }
    }

    if (approvalMode == ApprovalMode.askEveryTime && options.isNotEmpty) {
      // Auto-select first allow option so Grok does not hang waiting for UI.
      optionId = options
              .firstWhere(
                (o) => (o['kind'] as String? ?? '').contains('allow'),
                orElse: () => options.first,
              )['optionId']
          as String? ??
          optionId;
    }

    return {
      'outcome': {
        'outcome': 'selected',
        'optionId': optionId,
      },
    };
  }

  Map<String, dynamic> _handleUnknown(
    String method,
    Map<String, dynamic> params,
  ) {
    return {
      'acknowledged': true,
      'method': method,
      'params': params,
    };
  }

  Future<Map<String, dynamic>> _readTextFile(
    Map<String, dynamic> params,
  ) async {
    final path = PathSafety.normalize(params['path'] as String? ?? '');
    if (PathSafety.isTraversalAttempt(path)) {
      return {'error': 'Path traversal denied'};
    }

    final outside = workspacePath.isNotEmpty &&
        !PathSafety.isInsideWorkspace(
          filePath: path,
          workspacePath: workspacePath,
        );

    if (!_shouldAutoApproveRead(outside)) {
      final approved = await onApprovalRequired?.call(
            method: 'fs/read_text_file',
            path: path,
            isWrite: false,
            isOutsideWorkspace: outside,
          ) ??
          _defaultApproveWhenNoUi(isWrite: false);
      if (!approved) return {'error': 'Read denied by user'};
    }

    final file = File(path);
    if (!await file.exists()) return {'error': 'File not found: $path'};
    return {'content': await file.readAsString()};
  }

  Future<Map<String, dynamic>> _writeTextFile(
    Map<String, dynamic> params,
  ) async {
    final path = PathSafety.normalize(params['path'] as String? ?? '');
    if (PathSafety.isTraversalAttempt(path)) {
      return {'error': 'Path traversal denied'};
    }

    final content = params['content'] as String? ?? '';
    final outside = workspacePath.isNotEmpty &&
        !PathSafety.isInsideWorkspace(
          filePath: path,
          workspacePath: workspacePath,
        );

    if (!_shouldAutoApproveWrite(outside)) {
      final approved = await onApprovalRequired?.call(
            method: 'fs/write_text_file',
            path: path,
            isWrite: true,
            isOutsideWorkspace: outside,
          ) ??
          _defaultApproveWhenNoUi(isWrite: true);
      if (!approved) return {'error': 'Write denied by user'};
    }

    final file = File(path);
    if (await file.exists()) {
      diffService.snapshotBefore(path, await file.readAsString());
    } else {
      diffService.snapshotBefore(path, '');
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    diffService.computeDiff(path: path, afterContent: content);
    return {};
  }

  bool _shouldAutoApproveRead(bool outside) {
    switch (approvalMode) {
      case ApprovalMode.askEveryTime:
        return false;
      case ApprovalMode.autoApproveReads:
        return !outside;
      case ApprovalMode.autoApproveReadsAndWrites:
      case ApprovalMode.fullTrust:
        return true;
    }
  }

  bool _shouldAutoApproveWrite(bool outside) {
    switch (approvalMode) {
      case ApprovalMode.askEveryTime:
        return false;
      case ApprovalMode.autoApproveReads:
        return false;
      case ApprovalMode.autoApproveReadsAndWrites:
        return !outside;
      case ApprovalMode.fullTrust:
        return true;
    }
  }

  /// When no per-file approval UI is wired, defer to session/request_permission
  /// and do not block Grok on fs/* calls (a common cause of hung prompts).
  bool _defaultApproveWhenNoUi({required bool isWrite}) {
    if (onApprovalRequired != null) return isWrite ? false : true;
    return true;
  }
}