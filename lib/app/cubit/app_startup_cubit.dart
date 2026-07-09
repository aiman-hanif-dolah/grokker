import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AppStartupPhase { loading, setupRequired, ready }

class AppStartupState extends Equatable {
  const AppStartupState({this.phase = AppStartupPhase.loading, this.error});

  final AppStartupPhase phase;
  final String? error;

  @override
  List<Object?> get props => [phase, error];
}

class AppStartupCubit extends Cubit<AppStartupState> {
  AppStartupCubit() : super(const AppStartupState());

  void setPhase(AppStartupPhase phase, {String? error}) {
    emit(AppStartupState(phase: phase, error: error));
  }
}
