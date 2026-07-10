import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/workspace_info.dart';
import '../../data/services/workspace_memory_service.dart';
import '../../data/services/workspace_service.dart';
import '../../domain/models/workspace_memory.dart';

class WorkspaceState extends Equatable {
  const WorkspaceState({
    this.workspace,
    this.memory,
    this.isLoading = false,
    this.isLearning = false,
    this.learningStatus,
    this.error,
    this.fromCache = false,
  });

  final WorkspaceInfo? workspace;
  final WorkspaceMemory? memory;
  final bool isLoading;
  final bool isLearning;
  final String? learningStatus;
  final String? error;
  final bool fromCache;

  WorkspaceState copyWith({
    WorkspaceInfo? workspace,
    WorkspaceMemory? memory,
    bool? isLoading,
    bool? isLearning,
    String? learningStatus,
    String? error,
    bool? fromCache,
    bool clearError = false,
    bool clearLearning = false,
  }) {
    return WorkspaceState(
      workspace: workspace ?? this.workspace,
      memory: memory ?? this.memory,
      isLoading: isLoading ?? this.isLoading,
      isLearning: clearLearning ? false : (isLearning ?? this.isLearning),
      learningStatus: clearLearning
          ? null
          : (learningStatus ?? this.learningStatus),
      error: clearError ? null : (error ?? this.error),
      fromCache: fromCache ?? this.fromCache,
    );
  }

  @override
  List<Object?> get props => [
    workspace,
    memory,
    isLoading,
    isLearning,
    learningStatus,
    error,
    fromCache,
  ];
}

class WorkspaceCubit extends Cubit<WorkspaceState> {
  WorkspaceCubit(this._service, this._memoryService)
    : super(const WorkspaceState()) {
    _restoreLastWorkspace();
  }

  final WorkspaceService _service;
  final WorkspaceMemoryService _memoryService;

  Future<void> openFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    await setWorkspace(result);
  }

  Future<void> setWorkspace(String path, {bool forceRescan = false}) async {
    emit(
      state.copyWith(isLoading: true, clearError: true, clearLearning: true),
    );
    try {
      final info = await _service.analyze(path);
      emit(
        state.copyWith(
          workspace: info,
          isLoading: false,
          isLearning: true,
          learningStatus: 'Learning workspace…',
        ),
      );

      final hadCache = !forceRescan && await _memoryService.hasValidCache(path);
      final memory = await _memoryService.loadOrScan(
        workspacePath: path,
        workspaceInfo: info,
        forceRescan: forceRescan,
      );

      emit(
        WorkspaceState(workspace: info, memory: memory, fromCache: hadCache),
      );
      await _memoryService.saveLastWorkspacePath(path);
    } catch (e) {
      emit(
        WorkspaceState(
          workspace: state.workspace,
          memory: state.memory,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> refreshMemory() async {
    final workspace = state.workspace;
    if (workspace == null) return;
    await setWorkspace(workspace.path, forceRescan: true);
  }

  Future<void> _restoreLastWorkspace() async {
    final lastPath = await _memoryService.loadLastWorkspacePath();
    if (lastPath != null && lastPath.isNotEmpty) {
      await setWorkspace(lastPath);
    }
  }
}
