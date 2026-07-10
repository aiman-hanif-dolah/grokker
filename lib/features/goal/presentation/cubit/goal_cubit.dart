import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GoalState extends Equatable {
  const GoalState({
    this.isActive = false,
    this.text,
    this.iteration = 0,
    this.maxIterations = 12,
    this.isComplete = false,
    this.lastStatus,
  });

  final bool isActive;
  final String? text;
  final int iteration;
  final int maxIterations;
  final bool isComplete;
  final String? lastStatus;

  GoalState copyWith({
    bool? isActive,
    String? text,
    int? iteration,
    int? maxIterations,
    bool? isComplete,
    String? lastStatus,
    bool clearText = false,
    bool clearStatus = false,
  }) {
    return GoalState(
      isActive: isActive ?? this.isActive,
      text: clearText ? null : (text ?? this.text),
      iteration: iteration ?? this.iteration,
      maxIterations: maxIterations ?? this.maxIterations,
      isComplete: isComplete ?? this.isComplete,
      lastStatus: clearStatus ? null : (lastStatus ?? this.lastStatus),
    );
  }

  @override
  List<Object?> get props => [
    isActive,
    text,
    iteration,
    maxIterations,
    isComplete,
    lastStatus,
  ];
}

/// Autopilot loop: keep prompting until the model signals success or the
/// iteration budget is exhausted.
class GoalCubit extends Cubit<GoalState> {
  GoalCubit() : super(const GoalState());

  /// Arm goal mode. [text] may be empty — next send becomes the goal.
  void arm({String? text, int maxIterations = 12}) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      emit(
        GoalState(
          isActive: true,
          text: null,
          iteration: 0,
          maxIterations: maxIterations.clamp(1, 50),
          isComplete: false,
          lastStatus: 'Goal ON — type the goal and press Enter',
        ),
      );
      return;
    }
    startGoal(trimmed, maxIterations: maxIterations);
  }

  void startGoal(String text, {int maxIterations = 12}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      arm(maxIterations: maxIterations);
      return;
    }
    emit(
      GoalState(
        isActive: true,
        text: trimmed,
        iteration: 0,
        maxIterations: maxIterations.clamp(1, 50),
        isComplete: false,
        lastStatus: 'Goal armed — press Enter to start',
      ),
    );
  }

  void stopGoal({String status = 'Goal stopped'}) {
    emit(GoalState(lastStatus: status));
  }

  void markComplete({String status = '✅ Goal achieved'}) {
    emit(
      GoalState(
        isActive: false,
        text: state.text,
        iteration: state.iteration,
        maxIterations: state.maxIterations,
        isComplete: true,
        lastStatus: status,
      ),
    );
  }

  void markFailed(String reason) {
    emit(
      GoalState(
        isActive: false,
        text: state.text,
        iteration: state.iteration,
        maxIterations: state.maxIterations,
        isComplete: false,
        lastStatus: reason,
      ),
    );
  }

  void ensureGoalText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state.text != null && state.text!.isNotEmpty) return;
    emit(state.copyWith(text: trimmed, lastStatus: 'Goal set — running…'));
  }

  void incrementIteration() {
    final next = state.iteration + 1;
    emit(
      state.copyWith(
        iteration: next,
        lastStatus: 'Goal running · step $next / ${state.maxIterations}',
      ),
    );
  }

  void markRunning() {
    emit(
      state.copyWith(
        lastStatus:
            'Goal running · step ${state.iteration.clamp(1, state.maxIterations)} / ${state.maxIterations}',
      ),
    );
  }

  /// True only after at least one goal turn has started (iteration >= 1).
  bool get canContinue =>
      state.isActive &&
      !state.isComplete &&
      (state.text?.trim().isNotEmpty ?? false) &&
      state.iteration >= 1 &&
      state.iteration < state.maxIterations;

  bool get isArmed => state.isActive && !state.isComplete;

  /// Prompt used for auto-continue turns.
  String buildContinuationPrompt() {
    final goal = state.text ?? '';
    final n = state.iteration + 1;
    return '''
Continue the GOAL (step $n of ${state.maxIterations}).

GOAL:
$goal

Rules:
- Make concrete progress this turn (edit files, run tools, fix errors).
- Do not stop early with only a plan unless blocked.
- When the goal is fully done, end your final message with exactly this line:
✅ Goal achieved
- If blocked, state the blocker clearly and keep trying if possible.
'''
        .trim();
  }

  /// First-turn framing when the user enables goal + sends.
  String frameInitialPrompt(String userText) {
    final goal = (state.text?.trim().isNotEmpty ?? false)
        ? state.text!.trim()
        : userText.trim();
    return '''
You are in GOAL MODE. Keep working across multiple turns until the goal is done.

GOAL:
$goal

First instruction from the user:
$userText

Rules:
- Execute, don't only plan.
- Use tools as needed.
- When fully complete, end with exactly:
✅ Goal achieved
'''
        .trim();
  }

  static bool responseSignalsComplete(String content) {
    final c = content.toLowerCase();
    return content.contains('✅ Goal achieved') ||
        content.contains('✅ goal achieved') ||
        c.contains('goal achieved') ||
        c.contains('goal complete') ||
        c.contains('goal completed') ||
        c.contains('successfully completed the goal');
  }
}
