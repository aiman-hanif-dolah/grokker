import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../shared/models/grok_process_status.dart';
import '../../data/services/acp_client.dart';
import '../../data/services/acp_client_request_handler.dart';
import '../../data/services/grok_process_service.dart';
import '../../domain/models/acp_models.dart';

class AcpConnectionState extends Equatable {
  const AcpConnectionState({
    this.processStatus = const GrokProcessStatus(
      state: GrokProcessState.stopped,
    ),
    this.initialized = false,
    this.protocolVersion,
    this.lastError,
    this.isConnecting = false,
    this.quotaStatus,
    this.usageUsed,
    this.usageSize,
  });

  final GrokProcessStatus processStatus;
  final bool initialized;
  final int? protocolVersion;
  final String? lastError;
  final bool isConnecting;
  final String? quotaStatus;
  final int? usageUsed;
  final int? usageSize;

  AcpConnectionState copyWith({
    GrokProcessStatus? processStatus,
    bool? initialized,
    int? protocolVersion,
    String? lastError,
    bool? isConnecting,
    String? quotaStatus,
    int? usageUsed,
    int? usageSize,
  }) {
    return AcpConnectionState(
      processStatus: processStatus ?? this.processStatus,
      initialized: initialized ?? this.initialized,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      lastError: lastError,
      isConnecting: isConnecting ?? this.isConnecting,
      quotaStatus: quotaStatus ?? this.quotaStatus,
      usageUsed: usageUsed ?? this.usageUsed,
      usageSize: usageSize ?? this.usageSize,
    );
  }

  @override
  List<Object?> get props => [
    processStatus,
    initialized,
    protocolVersion,
    lastError,
    isConnecting,
    quotaStatus,
    usageUsed,
    usageSize,
  ];
}

class AcpConnectionCubit extends Cubit<AcpConnectionState> {
  AcpConnectionCubit({
    required GrokProcessService processService,
    required AcpClient acpClient,
    required AcpClientRequestHandler clientRequestHandler,
  }) : _processService = processService,
       _acpClient = acpClient,
       _clientRequestHandler = clientRequestHandler,
       super(const AcpConnectionState()) {
    _statusSub = _processService.statusStream.listen((status) {
      emit(state.copyWith(processStatus: status));
      if (status.state == GrokProcessState.failed) {
        emit(
          state.copyWith(
            initialized: false,
            lastError: status.lastError ?? 'Process failed',
          ),
        );
      }
    });
    _eventSub = _acpClient.events.listen(_onAcpEvent);
    _acpClient.setClientRequestHandler(_clientRequestHandler.handle);
  }

  final GrokProcessService _processService;
  final AcpClient _acpClient;
  final AcpClientRequestHandler _clientRequestHandler;
  StreamSubscription<GrokProcessStatus>? _statusSub;
  StreamSubscription<AcpEvent>? _eventSub;

  AcpClient get acpClient => _acpClient;
  GrokProcessService get processService => _processService;

  Future<void> start({
    String command = AppConstants.defaultGrokCommand,
    List<String> args = AppConstants.defaultGrokArgs,
  }) async {
    emit(state.copyWith(isConnecting: true, lastError: null));
    try {
      await _processService.start(command: command, args: args);
      await _acpClient.connect();
      await _acpClient.initialize();
      emit(
        state.copyWith(
          isConnecting: false,
          initialized: true,
          protocolVersion: _acpClient.protocolVersion,
        ),
      );
    } on AppError catch (e) {
      emit(
        state.copyWith(
          isConnecting: false,
          initialized: false,
          lastError: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isConnecting: false,
          initialized: false,
          lastError: e.toString(),
        ),
      );
    }
  }

  Future<void> restart({String? command, List<String>? args}) async {
    emit(state.copyWith(initialized: false));
    await _acpClient.shutdown();
    await _processService.restart(command: command, args: args);
    await _acpClient.connect();
    await _acpClient.initialize();
    emit(
      state.copyWith(
        initialized: true,
        protocolVersion: _acpClient.protocolVersion,
        lastError: null,
      ),
    );
  }

  Future<void> stop() async {
    await _acpClient.shutdown();
    await _processService.stop();
    emit(state.copyWith(initialized: false));
  }

  void updateWorkspace(String path) {
    _clientRequestHandler.workspacePath = path;
  }

  void _onAcpEvent(AcpEvent event) {
    if (event.type == AcpEventType.usageUpdate &&
        event.usageUsed != null &&
        event.usageSize != null) {
      emit(
        state.copyWith(
          usageUsed: event.usageUsed,
          usageSize: event.usageSize,
          quotaStatus: '${event.usageUsed} / ${event.usageSize} tokens',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _statusSub?.cancel();
    await _eventSub?.cancel();
    await stop();
    return super.close();
  }
}
