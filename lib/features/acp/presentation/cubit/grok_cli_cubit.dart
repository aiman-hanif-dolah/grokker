import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/grok_cli_locator_service.dart';

class GrokCliState extends Equatable {
  const GrokCliState({
    this.isChecking = true,
    this.found = false,
    this.resolvedPath,
    this.version,
    this.command,
    this.args = const [],
    this.error,
  });

  final bool isChecking;
  final bool found;
  final String? resolvedPath;
  final String? version;
  final String? command;
  final List<String> args;
  final String? error;

  @override
  List<Object?> get props => [
    isChecking,
    found,
    resolvedPath,
    version,
    command,
    args,
    error,
  ];
}

class GrokCliCubit extends Cubit<GrokCliState> {
  GrokCliCubit(this._locator) : super(const GrokCliState());

  final GrokCliLocatorService _locator;

  Future<void> detect({
    String customCommandPath = '',
    bool useNpx = false,
  }) async {
    emit(const GrokCliState(isChecking: true));
    final result = await _locator.detect(
      customCommandPath: customCommandPath,
      useNpx: useNpx,
    );
    emit(
      GrokCliState(
        isChecking: false,
        found: result.found,
        resolvedPath: result.resolvedPath,
        version: result.version,
        command: result.command,
        args: result.args,
        error: result.error,
      ),
    );
  }
}
