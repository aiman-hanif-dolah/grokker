import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/platform/platform_info.dart';
import '../../../acp/data/services/acp_client.dart';
import '../../../acp/data/services/grok_process_service.dart';
import '../../../acp/domain/models/acp_models.dart';

class DiagnosticsState extends Equatable {
  const DiagnosticsState({
    this.visible = false,
    this.stderrLines = const [],
    this.acpEvents = const [],
    this.lastError,
    this.grokCommand,
    this.grokResolvedPath,
    this.grokVersion,
    this.workspacePath,
    this.acpSessionId,
    this.modelRequested,
    this.modelConfirmed,
    this.effortRequested,
    this.effortConfirmed,
    this.initialized = false,
    this.protocolVersion,
    this.processStatus = 'stopped',
  });

  final bool visible;
  final List<String> stderrLines;
  final List<Map<String, dynamic>> acpEvents;
  final String? lastError;
  final String? grokCommand;
  final String? grokResolvedPath;
  final String? grokVersion;
  final String? workspacePath;
  final String? acpSessionId;
  final String? modelRequested;
  final String? modelConfirmed;
  final String? effortRequested;
  final String? effortConfirmed;
  final bool initialized;
  final int? protocolVersion;
  final String processStatus;

  DiagnosticsState copyWith({
    bool? visible,
    List<String>? stderrLines,
    List<Map<String, dynamic>>? acpEvents,
    String? lastError,
    String? grokCommand,
    String? grokResolvedPath,
    String? grokVersion,
    String? workspacePath,
    String? acpSessionId,
    String? modelRequested,
    String? modelConfirmed,
    String? effortRequested,
    String? effortConfirmed,
    bool? initialized,
    int? protocolVersion,
    String? processStatus,
  }) {
    return DiagnosticsState(
      visible: visible ?? this.visible,
      stderrLines: stderrLines ?? this.stderrLines,
      acpEvents: acpEvents ?? this.acpEvents,
      lastError: lastError ?? this.lastError,
      grokCommand: grokCommand ?? this.grokCommand,
      grokResolvedPath: grokResolvedPath ?? this.grokResolvedPath,
      grokVersion: grokVersion ?? this.grokVersion,
      workspacePath: workspacePath ?? this.workspacePath,
      acpSessionId: acpSessionId ?? this.acpSessionId,
      modelRequested: modelRequested ?? this.modelRequested,
      modelConfirmed: modelConfirmed ?? this.modelConfirmed,
      effortRequested: effortRequested ?? this.effortRequested,
      effortConfirmed: effortConfirmed ?? this.effortConfirmed,
      initialized: initialized ?? this.initialized,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      processStatus: processStatus ?? this.processStatus,
    );
  }

  String toClipboardText() {
    final buffer = StringBuffer();
    buffer.writeln('Grokker Diagnostics');
    buffer.writeln('OS: ${PlatformInfo.osName}');
    buffer.writeln('App: ${AppConstants.appName} ${AppConstants.appVersion}');
    buffer.writeln('Grok command: $grokCommand');
    buffer.writeln('Grok path: $grokResolvedPath');
    buffer.writeln('Grok version: $grokVersion');
    buffer.writeln('Process: $processStatus');
    buffer.writeln('ACP initialized: $initialized');
    buffer.writeln('Protocol version: $protocolVersion');
    buffer.writeln('ACP session: $acpSessionId');
    buffer.writeln('Workspace: $workspacePath');
    buffer.writeln('Model requested: $modelRequested');
    buffer.writeln('Model confirmed: $modelConfirmed');
    buffer.writeln('Effort requested: $effortRequested');
    buffer.writeln('Effort confirmed: $effortConfirmed');
    buffer.writeln('Last error: $lastError');
    buffer.writeln('--- stderr ---');
    for (final line in stderrLines) {
      buffer.writeln(line);
    }
    buffer.writeln('--- ACP events ---');
    for (final event in acpEvents) {
      buffer.writeln(event);
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    visible,
    stderrLines,
    acpEvents,
    lastError,
    grokCommand,
    grokResolvedPath,
    grokVersion,
    workspacePath,
    acpSessionId,
    modelRequested,
    modelConfirmed,
    effortRequested,
    effortConfirmed,
    initialized,
    protocolVersion,
    processStatus,
  ];
}

class DiagnosticsCubit extends Cubit<DiagnosticsState> {
  DiagnosticsCubit({
    required GrokProcessService processService,
    required AcpClient acpClient,
  }) : _processService = processService,
       _acpClient = acpClient,
       super(const DiagnosticsState()) {
    _stderrSub = _processService.stderrLines.listen(_onStderr);
    _eventSub = _acpClient.events.listen(_onAcpEvent);
    _statusSub = _processService.statusStream.listen((status) {
      emit(state.copyWith(processStatus: status.state.name));
    });
  }

  final GrokProcessService _processService;
  final AcpClient _acpClient;
  StreamSubscription<String>? _stderrSub;
  StreamSubscription<AcpEvent>? _eventSub;
  StreamSubscription? _statusSub;

  void toggle() => emit(state.copyWith(visible: !state.visible));

  void setVisible(bool visible) => emit(state.copyWith(visible: visible));

  void updateContext({
    String? grokCommand,
    String? grokResolvedPath,
    String? grokVersion,
    String? workspacePath,
    String? acpSessionId,
    String? modelRequested,
    String? modelConfirmed,
    String? effortRequested,
    String? effortConfirmed,
    bool? initialized,
    int? protocolVersion,
    String? lastError,
  }) {
    emit(
      state.copyWith(
        grokCommand: grokCommand,
        grokResolvedPath: grokResolvedPath,
        grokVersion: grokVersion,
        workspacePath: workspacePath,
        acpSessionId: acpSessionId,
        modelRequested: modelRequested,
        modelConfirmed: modelConfirmed,
        effortRequested: effortRequested,
        effortConfirmed: effortConfirmed,
        initialized: initialized,
        protocolVersion: protocolVersion,
        lastError: lastError,
      ),
    );
  }

  void _onStderr(String line) {
    final lines = [...state.stderrLines, line];
    while (lines.length > AppConstants.maxStderrLines) {
      lines.removeAt(0);
    }
    emit(state.copyWith(stderrLines: lines));
  }

  void _onAcpEvent(AcpEvent event) {
    final events = [
      ...state.acpEvents,
      {
        'type': event.type.name,
        'time': event.timestamp.toIso8601String(),
        if (event.text != null) 'text': event.text,
        if (event.rawPayload != null) 'raw': event.rawPayload,
      },
    ];
    while (events.length > AppConstants.maxRawEvents) {
      events.removeAt(0);
    }
    emit(state.copyWith(acpEvents: events));
  }

  @override
  Future<void> close() async {
    await _stderrSub?.cancel();
    await _eventSub?.cancel();
    await _statusSub?.cancel();
    return super.close();
  }
}
