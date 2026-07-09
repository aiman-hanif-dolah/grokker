import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GoalState extends Equatable {
  const GoalState({
    this.isActive = false,
    this.text,
    this.iteration = 0,
    this.isComplete = false,
  });

  final bool isActive;
  final String? text;
  final int iteration;
  final bool isComplete;

  GoalState copyWith({
    bool? isActive,
    String? text,
    int? iteration,
    bool? isComplete,
    bool clearText = false,
  }) {
    return GoalState(
      isActive: isActive ?? this.isActive,
      text: clearText ? null : (text ?? this.text),
      iteration: iteration ?? this.iteration,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  List<Object?> get props => [isActive, text, iteration, isComplete];
}

class GoalCubit extends Cubit<GoalState> {
  GoalCubit() : super(const GoalState());

  void startGoal(String text) {
    emit(GoalState(
      isActive: true,
      text: text.trim(),
      iteration: 0,
      isComplete: false,
    ));
  }

  void stopGoal() {
    emit(const GoalState());
  }

  void markComplete() {
    emit(state.copyWith(isComplete: true));
  }

  void incrementIteration() {
    emit(state.copyWith(iteration: state.iteration + 1));
  }
}
