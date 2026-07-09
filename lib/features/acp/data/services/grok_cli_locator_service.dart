import 'dart:async';
import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';

class GrokCliDetectionResult {
  const GrokCliDetectionResult({
    required this.found,
    this.resolvedPath,
    this.version,
    this.command,
    this.args = const [],
    this.error,
    this.rejectedPaths = const [],
  });

  final bool found;
  final String? resolvedPath;
  final String? version;
  final String? command;
  final List<String> args;
  final String? error;
  final List<String> rejectedPaths;
}

class GrokCliLocatorService {
  Future<GrokCliDetectionResult> detect({
    String customCommandPath = '',
    bool useNpx = false,
  }) async {
    final command = _resolveCommand(customCommandPath, useNpx);
    final args = useNpx
        ? AppConstants.npxGrokArgs
        : AppConstants.defaultGrokArgs;

    try {
      final resolution = await _resolveExecutable(command, useNpx: useNpx);
      if (resolution.path == null) {
        final rejected = resolution.rejected;
        final rejectedNote = rejected.isEmpty
            ? ''
            : ' Rejected non-Grok-Build binaries: ${rejected.join(', ')}.';
        return GrokCliDetectionResult(
          found: false,
          command: command,
          args: args,
          rejectedPaths: rejected,
          error:
              'Grok Build CLI not found.$rejectedNote '
              'Install with: npm install -g @xai-official/grok '
              'Expected: ${officialGrokPath() ?? "~/.grok/bin/grok"}',
        );
      }

      return GrokCliDetectionResult(
        found: true,
        resolvedPath: resolution.path,
        version: resolution.version,
        command: resolution.path,
        args: args,
        rejectedPaths: resolution.rejected,
      );
    } catch (e) {
      AppLogger.error('Grok CLI detection failed', error: e);
      return GrokCliDetectionResult(
        found: false,
        command: command,
        args: args,
        error: e.toString(),
      );
    }
  }

  /// Official xAI Grok Build CLI install location.
  static String? officialGrokPath() {
    final home = resolveHomeDirectory();
    return home != null ? '$home/.grok/bin/grok' : null;
  }

  /// Resolves the real user home directory.
  ///
  /// macOS sandboxed .app bundles set HOME to
  /// ~/Library/Containers/<bundle-id>/Data — not the user's actual home.
  static String? resolveHomeDirectory() {
    final user = _resolveUsername();
    final home = Platform.environment['HOME'];

    if (home != null && home.isNotEmpty && !_isSandboxContainerHome(home)) {
      return home;
    }

    if (user != null && user.isNotEmpty) {
      if (Platform.isMacOS) return '/Users/$user';
      if (Platform.isLinux) return '/home/$user';
    }

    return home?.isNotEmpty == true ? home : null;
  }

  static String? _resolveUsername() {
    return Platform.environment['USER'] ??
        Platform.environment['LOGNAME'] ??
        Platform.environment['USERNAME'];
  }

  static bool _isSandboxContainerHome(String home) {
    return home.contains('/Library/Containers/') && home.endsWith('/Data');
  }

  /// Candidate paths to probe, in priority order.
  static List<String> knownInstallPaths() {
    final paths = <String>{};
    final home = resolveHomeDirectory();
    if (home != null) paths.add('$home/.grok/bin/grok');

    // Always probe the real macOS user home via USER, even when HOME is sandboxed.
    final user = _resolveUsername();
    if (Platform.isMacOS && user != null && user.isNotEmpty) {
      paths.add('/Users/$user/.grok/bin/grok');
    }

    return paths.toList();
  }

  String _resolveCommand(String customPath, bool useNpx) {
    if (customPath.isNotEmpty) return customPath;
    return useNpx
        ? AppConstants.npxGrokCommand
        : AppConstants.defaultGrokCommand;
  }

  Future<({String? path, String? version, List<String> rejected})>
  _resolveExecutable(String command, {required bool useNpx}) async {
    final candidates = <String>[];
    final rejected = <String>[];

    void addCandidate(String? path) {
      if (path == null || path.isEmpty) return;
      if (!candidates.contains(path)) candidates.add(path);
    }

    addCandidate(_isExistingExecutable(command) ? command : null);
    for (final path in knownInstallPaths()) {
      if (_isExistingExecutable(path)) addCandidate(path);
    }

    final whichResult = await _whichOnPath(command);
    addCandidate(whichResult);

    final shellResult = await _whichViaLoginShell(command);
    addCandidate(shellResult);

    for (final candidate in candidates) {
      final normalized = _normalizePath(candidate);
      final validation = await _validateGrokBuildCli(
        normalized,
        useNpx: useNpx,
      );
      if (validation.isValid) {
        return (
          path: normalized,
          version: validation.version,
          rejected: rejected,
        );
      }
      rejected.add('$normalized (${validation.reason})');
      AppLogger.warn(
        'Rejected grok candidate: $normalized — ${validation.reason}',
      );
    }

    return (path: null, version: null, rejected: rejected);
  }

  /// Returns true only for xAI Grok Build CLI (supports `agent` subcommand).
  static Future<({bool isValid, String? version, String reason})>
  validateGrokBuildCli(String executable, {bool useNpx = false}) {
    return GrokCliLocatorService()._validateGrokBuildCli(
      executable,
      useNpx: useNpx,
    );
  }

  Future<({bool isValid, String? version, String reason})>
  _validateGrokBuildCli(String executable, {required bool useNpx}) async {
    try {
      final versionResult = await Process.run(
        executable,
        useNpx
            ? [...AppConstants.npxGrokArgs.take(2), '--version']
            : ['--version'],
        environment: augmentedEnvironment(),
      ).timeout(const Duration(seconds: 5));

      final versionOut = '${versionResult.stdout}${versionResult.stderr}'
          .trim();

      // Homebrew log grok prints e.g. "grok 1.20250912.1" — not Grok Build CLI.
      if (RegExp(r'grok 1\.\d{8}').hasMatch(versionOut)) {
        return (
          isValid: false,
          version: null,
          reason: 'Homebrew log grok, not Grok Build CLI',
        );
      }

      final agentHelp = await Process.run(
        executable,
        useNpx
            ? [...AppConstants.npxGrokArgs.take(2), 'agent', '--help']
            : ['agent', '--help'],
        environment: augmentedEnvironment(),
      ).timeout(const Duration(seconds: 5));

      final agentOut = '${agentHelp.stdout}${agentHelp.stderr}'.trim();
      if (agentHelp.exitCode == 0 ||
          agentOut.toLowerCase().contains('agent') ||
          agentOut.toLowerCase().contains('stdio')) {
        final version = versionOut.isNotEmpty
            ? versionOut.split('\n').first
            : null;
        return (isValid: true, version: version, reason: 'ok');
      }

      return (
        isValid: false,
        version: null,
        reason: 'missing agent subcommand (not Grok Build CLI)',
      );
    } on TimeoutException {
      return (isValid: false, version: null, reason: 'validation timed out');
    } catch (e) {
      return (isValid: false, version: null, reason: e.toString());
    }
  }

  bool _isExistingExecutable(String path) => File(path).existsSync();

  String _normalizePath(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } catch (_) {
      return path;
    }
  }

  Future<String?> _whichOnPath(String command) async {
    final whichCmd = Platform.isWindows ? 'where' : 'which';
    final result = await Process.run(whichCmd, [
      command,
    ], environment: augmentedEnvironment());
    if (result.exitCode != 0) return null;
    final output = (result.stdout as String).trim().split(RegExp(r'[\r\n]+'));
    final candidate = output.isNotEmpty ? output.first.trim() : null;
    if (candidate != null && _isExistingExecutable(candidate)) {
      return _normalizePath(candidate);
    }
    return null;
  }

  Future<String?> _whichViaLoginShell(String command) async {
    if (Platform.isWindows) return null;

    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    try {
      final result = await Process.run(
        shell,
        ['-l', '-c', 'command -v ${_shellQuote(command)}'],
        environment: augmentedEnvironment(),
      ).timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return null;
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty && _isExistingExecutable(path)) {
        return _normalizePath(path);
      }
    } on TimeoutException {
      AppLogger.warn('Login shell PATH lookup timed out for $command');
    } catch (_) {}
    return null;
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  /// Ensures spawned processes can find grok when launched from a macOS .app.
  static Map<String, String> augmentedEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final home = resolveHomeDirectory();
    final extra = <String>[
      if (home != null) '$home/.grok/bin',
      if (home != null) '$home/.local/bin',
      '/usr/local/bin',
      // homebrew last — often has the wrong "grok" package
      '/opt/homebrew/bin',
    ];

    final current = env['PATH'] ?? '';
    final parts = current.split(':').where((p) => p.isNotEmpty).toList();
    for (final segment in extra.reversed) {
      if (!parts.contains(segment)) {
        parts.insert(0, segment);
      }
    }
    if (home != null) env['HOME'] = home;
    env['PATH'] = parts.join(':');
    return env;
  }
}
