import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/models/grok_process_status.dart';
import 'grok_cli_locator_service.dart';

class GrokProcessService {
  GrokProcessService();

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final _stdoutController = StreamController<String>.broadcast();
  final _stderrController = StreamController<String>.broadcast();
  final _statusController = StreamController<GrokProcessStatus>.broadcast();

  Stream<String> get stdoutLines => _stdoutController.stream;
  Stream<String> get stderrLines => _stderrController.stream;
  Stream<GrokProcessStatus> get statusStream => _statusController.stream;

  GrokProcessStatus _status = const GrokProcessStatus(
    state: GrokProcessState.stopped,
  );
  GrokProcessStatus get currentStatus => _status;

  Future<void> start({
    String command = AppConstants.defaultGrokCommand,
    List<String> args = AppConstants.defaultGrokArgs,
  }) async {
    if (_process != null) await stop();

    _updateStatus(
      _status.copyWith(
        state: GrokProcessState.starting,
        command: command,
        args: args,
        lastError: null,
      ),
    );

    try {
      _process = await Process.start(
        command,
        args,
        runInShell: true,
        mode: ProcessStartMode.normal,
        environment: GrokCliLocatorService.augmentedEnvironment(),
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _stdoutController.add,
            onError: (Object e) => AppLogger.error('stdout error', error: e),
          );

      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _stderrController.add,
            onError: (Object e) => AppLogger.error('stderr error', error: e),
          );

      _process!.exitCode.then((code) {
        _updateStatus(
          _status.copyWith(
            state: GrokProcessState.failed,
            exitCode: code,
            lastError: 'Process exited with code $code',
          ),
        );
        _process = null;
      });

      _updateStatus(
        _status.copyWith(state: GrokProcessState.running, pid: _process!.pid),
      );
    } catch (e) {
      _updateStatus(
        _status.copyWith(
          state: GrokProcessState.failed,
          lastError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> restart({String? command, List<String>? args}) async {
    _updateStatus(_status.copyWith(state: GrokProcessState.restarting));
    await stop();
    await start(
      command: command ?? _status.command ?? AppConstants.defaultGrokCommand,
      args: args ?? _status.args,
    );
  }

  Future<void> stop() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
        await _process!.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            _process?.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (e) {
        AppLogger.warn('Error stopping process: $e');
      }
      _process = null;
    }

    _updateStatus(const GrokProcessStatus(state: GrokProcessState.stopped));
  }

  void writeLine(String line) {
    final process = _process;
    if (process == null) {
      throw StateError('Grok process is not running');
    }
    process.stdin.writeln(line);
  }

  void _updateStatus(GrokProcessStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    await stop();
    await _stdoutController.close();
    await _stderrController.close();
    await _statusController.close();
  }
}
