import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

enum MultitaskItemStatus { queued, running, done, failed, cancelled }

class MultitaskItem extends Equatable {
  const MultitaskItem({
    required this.id,
    required this.prompt,
    this.status = MultitaskItemStatus.queued,
    this.error,
  });

  final String id;
  final String prompt;
  final MultitaskItemStatus status;
  final String? error;

  MultitaskItem copyWith({MultitaskItemStatus? status, String? error}) {
    return MultitaskItem(
      id: id,
      prompt: prompt,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [id, prompt, status, error];
}

class MultitaskState extends Equatable {
  const MultitaskState({
    this.enabled = false,
    this.queue = const [],
    this.useSubagents = true,
  });

  /// When true, each send is framed for parallel subagent-style work.
  final bool enabled;

  /// Prefer instructing the agent to spawn subagents for independent work.
  final bool useSubagents;

  final List<MultitaskItem> queue;

  int get queuedCount =>
      queue.where((t) => t.status == MultitaskItemStatus.queued).length;

  MultitaskItem? get nextQueued {
    for (final t in queue) {
      if (t.status == MultitaskItemStatus.queued) return t;
    }
    return null;
  }

  MultitaskState copyWith({
    bool? enabled,
    bool? useSubagents,
    List<MultitaskItem>? queue,
  }) {
    return MultitaskState(
      enabled: enabled ?? this.enabled,
      useSubagents: useSubagents ?? this.useSubagents,
      queue: queue ?? this.queue,
    );
  }

  @override
  List<Object?> get props => [enabled, useSubagents, queue];
}

/// Multitask = subagent-oriented prompting + optional FIFO task queue.
class MultitaskCubit extends Cubit<MultitaskState> {
  MultitaskCubit({Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      super(const MultitaskState());

  final Uuid _uuid;

  void setEnabled(bool value) {
    emit(state.copyWith(enabled: value));
  }

  void toggle() => setEnabled(!state.enabled);

  /// Turn off without clearing the queue (used when Goal takes over).
  void disable() => setEnabled(false);

  void setUseSubagents(bool value) {
    emit(state.copyWith(useSubagents: value));
  }

  void enqueue(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    final item = MultitaskItem(id: _uuid.v4(), prompt: trimmed);
    emit(state.copyWith(queue: [...state.queue, item]));
  }

  void enqueueMany(List<String> prompts) {
    final items = prompts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => MultitaskItem(id: _uuid.v4(), prompt: p))
        .toList();
    if (items.isEmpty) return;
    emit(state.copyWith(queue: [...state.queue, ...items]));
  }

  /// Parse multi-line or `---` separated tasks from a single paste.
  void enqueueFromBulk(String bulk) {
    final parts = bulk
        .split(RegExp(r'\n\s*---\s*\n|\n{2,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length <= 1) {
      enqueue(bulk);
    } else {
      enqueueMany(parts);
    }
  }

  void remove(String id) {
    emit(state.copyWith(queue: state.queue.where((t) => t.id != id).toList()));
  }

  void clearQueue() {
    emit(state.copyWith(queue: const []));
  }

  void clearFinished() {
    emit(
      state.copyWith(
        queue: state.queue
            .where(
              (t) =>
                  t.status == MultitaskItemStatus.queued ||
                  t.status == MultitaskItemStatus.running,
            )
            .toList(),
      ),
    );
  }

  MultitaskItem? markNextRunning() {
    final next = state.nextQueued;
    if (next == null) return null;
    emit(
      state.copyWith(
        queue: state.queue
            .map(
              (t) => t.id == next.id
                  ? t.copyWith(status: MultitaskItemStatus.running)
                  : t,
            )
            .toList(),
      ),
    );
    return next;
  }

  void markDone(String id) {
    _setStatus(id, MultitaskItemStatus.done);
  }

  void markFailed(String id, String error) {
    _setStatus(id, MultitaskItemStatus.failed, error: error);
  }

  void _setStatus(String id, MultitaskItemStatus status, {String? error}) {
    emit(
      state.copyWith(
        queue: state.queue
            .map(
              (t) => t.id == id ? t.copyWith(status: status, error: error) : t,
            )
            .toList(),
      ),
    );
  }

  /// Frame a user prompt for multitask / subagent-friendly execution.
  String framePrompt(String userText) {
    if (!state.enabled) return userText;
    final sub = state.useSubagents
        ? '''
Prefer multitasking:
- Split independent work into parallel subagents when useful (explore / implement / test / review).
- Use spawn_subagent (or equivalent) for concurrent research or implementation streams.
- Keep a clear status of each workstream; synthesize results at the end.
'''
        : '''
Prefer multitasking:
- Break the work into clear parallel tracks and advance them in the same turn where possible.
- Report progress per track before synthesizing a final answer.
''';

    return '''
<multitask_mode>
$sub
User request:
$userText
</multitask_mode>
'''
        .trim();
  }
}
