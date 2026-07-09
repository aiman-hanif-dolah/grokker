import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/app_session.dart';

class SessionState extends Equatable {
  const SessionState({
    this.sessions = const [],
    this.activeSessionId,
    this.searchQuery = '',
    this.isLoading = false,
  });

  final List<AppSession> sessions;
  final String? activeSessionId;
  final String searchQuery;
  final bool isLoading;

  AppSession? get activeSession {
    if (activeSessionId == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == activeSessionId);
    } catch (_) {
      return null;
    }
  }

  List<AppSession> get filteredSessions {
    if (searchQuery.isEmpty) return sessions;
    final q = searchQuery.toLowerCase();
    return sessions
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.workspacePath.toLowerCase().contains(q),
        )
        .toList();
  }

  SessionState copyWith({
    List<AppSession>? sessions,
    String? activeSessionId,
    String? searchQuery,
    bool? isLoading,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    activeSessionId,
    searchQuery,
    isLoading,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      super(const SessionState());

  final SessionRepository _repository;
  final Uuid _uuid;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final sessions = await _repository.loadAll();
    emit(
      SessionState(
        sessions: sessions,
        activeSessionId: sessions.isNotEmpty ? sessions.first.id : null,
      ),
    );
  }

  Future<void> createSession({
    required String workspacePath,
    GrokModel model = GrokModel.grokBuild01,
    ThinkingEffort effort = ThinkingEffort.auto,
    String? processCommand,
  }) async {
    final now = DateTime.now();
    final session = AppSession(
      id: _uuid.v4(),
      title: 'New chat',
      workspacePath: workspacePath,
      createdAt: now,
      updatedAt: now,
      selectedModel: model,
      selectedEffort: effort,
      processCommand: processCommand,
    );
    final updated = [session, ...state.sessions];
    await _repository.saveAll(updated);
    emit(state.copyWith(sessions: updated, activeSessionId: session.id));
  }

  Future<void> selectSession(String id) async {
    emit(state.copyWith(activeSessionId: id));
  }

  Future<void> renameSession(String id, String title) async {
    final updated = state.sessions.map((s) {
      if (s.id == id)
        return s.copyWith(title: title, updatedAt: DateTime.now());
      return s;
    }).toList();
    await _repository.saveAll(updated);
    emit(state.copyWith(sessions: updated));
  }

  Future<void> deleteSession(String id) async {
    await _repository.delete(id, state.sessions);
    final updated = state.sessions.where((s) => s.id != id).toList();
    emit(
      state.copyWith(
        sessions: updated,
        activeSessionId: updated.isEmpty
            ? null
            : (state.activeSessionId == id
                  ? updated.first.id
                  : state.activeSessionId),
      ),
    );
  }

  Future<void> updateSession(AppSession session) async {
    final updated = state.sessions
        .map((s) => s.id == session.id ? session : s)
        .toList();
    emit(state.copyWith(sessions: updated));
    await _repository.saveAll(updated);
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  String exportMarkdown(String sessionId) {
    final session = state.sessions.firstWhere((s) => s.id == sessionId);
    return _repository.exportMarkdown(session);
  }
}
