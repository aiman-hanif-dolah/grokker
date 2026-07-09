import 'package:equatable/equatable.dart';

enum GrokProcessState { stopped, starting, running, restarting, failed }

class GrokProcessStatus extends Equatable {
  const GrokProcessStatus({
    required this.state,
    this.pid,
    this.command,
    this.args = const [],
    this.lastError,
    this.exitCode,
  });

  final GrokProcessState state;
  final int? pid;
  final String? command;
  final List<String> args;
  final String? lastError;
  final int? exitCode;

  bool get isRunning => state == GrokProcessState.running;

  GrokProcessStatus copyWith({
    GrokProcessState? state,
    int? pid,
    String? command,
    List<String>? args,
    String? lastError,
    int? exitCode,
  }) {
    return GrokProcessStatus(
      state: state ?? this.state,
      pid: pid ?? this.pid,
      command: command ?? this.command,
      args: args ?? this.args,
      lastError: lastError,
      exitCode: exitCode ?? this.exitCode,
    );
  }

  @override
  List<Object?> get props => [state, pid, command, args, lastError, exitCode];
}
