import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/app_constants.dart';
import '../core/logging/app_logger.dart';
import '../features/setup/presentation/setup_screen.dart';
import '../features/shell/presentation/main_shell.dart';
import 'app_theme.dart';
import 'cubit/app_startup_cubit.dart';
import 'service_locator.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../styles/design_tokens.dart';
import '../styles/grokker_typography.dart';

class GrokkerApp extends StatefulWidget {
  const GrokkerApp({super.key});

  @override
  State<GrokkerApp> createState() => _GrokkerAppState();
}

class _GrokkerAppState extends State<GrokkerApp> {
  final _locator = ServiceLocator.instance;
  bool _ready = false;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _locator.init().timeout(const Duration(seconds: 15));
      final settings = _locator.settingsCubit.state.settings;

      // Keep model dropdown in sync with CLI-available models.
      unawaited(
        _locator.modelsCubit.load(
          refreshCli: true,
          grokCommand: settings.grokCommandPath.isNotEmpty
              ? settings.grokCommandPath
              : null,
        ),
      );

      await _locator.grokCliCubit
          .detect(
            customCommandPath: settings.grokCommandPath,
            useNpx: settings.useNpxGrok,
          )
          .timeout(const Duration(seconds: 10));

      final cli = _locator.grokCliCubit.state;
      if (!cli.found) {
        _locator.appStartupCubit.setPhase(AppStartupPhase.setupRequired);
        _markReady();
        return;
      }

      // Persist resolved official CLI path so we never pick Homebrew's wrong grok.
      if (cli.resolvedPath != null &&
          settings.grokCommandPath != cli.resolvedPath) {
        await _locator.settingsCubit.update(
          settings.copyWith(grokCommandPath: cli.resolvedPath!),
        );
      }

      _locator.clientRequestHandler.approvalMode = settings.approvalMode;
      _locator.appStartupCubit.setPhase(AppStartupPhase.ready);
      _markReady();

      // Start Grok ACP in the background — never block the UI on this.
      if (settings.autoStartGrokProcess) {
        unawaited(_startGrokInBackground(cli.command!, cli.args));
      }
    } catch (e, st) {
      AppLogger.error('Bootstrap failed', error: e, stackTrace: st);
      _bootstrapError = e.toString();
      _locator.appStartupCubit.setPhase(AppStartupPhase.setupRequired);
      _markReady();
    }
  }

  Future<void> _startGrokInBackground(String command, List<String> args) async {
    try {
      await _locator.acpConnectionCubit
          .start(command: command, args: args)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      AppLogger.warn('Background Grok start failed: $e');
    }
  }

  void _markReady() {
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _locator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.dark(),
        home: Scaffold(
          backgroundColor: GrokkerSurfaces.voidFloor,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(GrokkerRadius.badge),
                  child: Image.asset(
                    'assets/branding/grokker_logo_48.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: GrokkerSpacing.s16),
                const CircularProgressIndicator(
                  color: GrokkerColors.signalBlue,
                ),
                const SizedBox(height: GrokkerSpacing.s16),
                Text('Starting Grokker…', style: GrokkerTypography.body()),
              ],
            ),
          ),
        ),
      );
    }

    return BlocProvider.value(
      value: _locator.appStartupCubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        bloc: _locator.settingsCubit,
        builder: (context, settingsState) {
          final settings = settingsState.settings;
          return MaterialApp(
            title: AppConstants.appName,
            // Dark is the default product theme; light is optional.
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: AppTheme.themeModeOf(settings),
            home: BlocBuilder<AppStartupCubit, AppStartupState>(
              bloc: _locator.appStartupCubit,
              builder: (context, startup) {
                if (startup.phase == AppStartupPhase.setupRequired) {
                  return SetupScreen(
                    error: _bootstrapError ?? _locator.grokCliCubit.state.error,
                    onRetry: () async {
                      final s = _locator.settingsCubit.state.settings;
                      _bootstrapError = null;
                      await _locator.grokCliCubit.detect(
                        customCommandPath: s.grokCommandPath,
                        useNpx: s.useNpxGrok,
                      );
                      if (_locator.grokCliCubit.state.found) {
                        _locator.appStartupCubit.setPhase(
                          AppStartupPhase.ready,
                        );
                        if (mounted) setState(() {});
                        if (s.autoStartGrokProcess) {
                          final cli = _locator.grokCliCubit.state;
                          unawaited(
                            _startGrokInBackground(cli.command!, cli.args),
                          );
                        }
                      } else if (mounted) {
                        setState(() {});
                      }
                    },
                  );
                }
                return const MainShell();
              },
            ),
          );
        },
      ),
    );
  }
}
