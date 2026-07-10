import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/sessions/domain/models/app_session.dart';
import 'package:grokker/features/sessions/presentation/cubit/session_cubit.dart';
import 'package:grokker/shared/models/chat_message.dart';
import 'package:grokker/shared/models/grok_model.dart';
import 'package:grokker/shared/models/thinking_effort.dart';
import 'package:mocktail/mocktail.dart';
import 'package:grokker/features/sessions/data/repositories/session_repository.dart';

class _MockRepo extends Mock implements SessionRepository {}

void main() {
  late _MockRepo repo;
  late SessionCubit cubit;

  AppSession session({String id = 's1', String content = ''}) {
    final now = DateTime.utc(2026, 1, 1);
    return AppSession(
      id: id,
      title: 't',
      workspacePath: r'C:\proj',
      createdAt: now,
      updatedAt: now,
      selectedModel: GrokModel.grok45,
      selectedEffort: ThinkingEffort.auto,
      messages: [
        ChatMessage(
          id: 'm1',
          role: ChatMessageRole.assistant,
          content: content,
          createdAt: now,
          status: ChatMessageStatus.streaming,
        ),
      ],
    );
  }

  setUp(() {
    repo = _MockRepo();
    when(() => repo.saveAll(any())).thenAnswer((_) async {});
    when(() => repo.loadAll()).thenAnswer((_) async => []);
    cubit = SessionCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('updateSessionInMemory does not write disk', () async {
    final s = session(content: 'hello');
    cubit.emit(SessionState(sessions: [s], activeSessionId: s.id));

    cubit.updateSessionInMemory(session(content: 'hello world'));

    verifyNever(() => repo.saveAll(any()));
    expect(cubit.state.activeSession?.messages.first.content, 'hello world');
  });

  test('updateSession with persist writes disk', () async {
    final s = session(content: 'done');
    cubit.emit(SessionState(sessions: [s], activeSessionId: s.id));

    await cubit.updateSession(session(content: 'final'), persist: true);

    verify(() => repo.saveAll(any())).called(1);
  });

  test('updateSession persist:false skips disk', () async {
    final s = session(content: 'x');
    cubit.emit(SessionState(sessions: [s], activeSessionId: s.id));

    await cubit.updateSession(session(content: 'y'), persist: false);

    verifyNever(() => repo.saveAll(any()));
  });
}
