import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/models/acp_models.dart';
import 'acp_event_normalizer.dart';
import 'grok_cli_locator_service.dart';
import 'grok_process_service.dart';

typedef ClientRequestHandler =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );

class AcpClient {
  AcpClient({
    required GrokProcessService processService,
    AcpEventNormalizer? eventNormalizer,
  }) : _processService = processService,
       _normalizer = eventNormalizer ?? AcpEventNormalizer();

  final GrokProcessService _processService;
  final AcpEventNormalizer _normalizer;
  final _eventController = StreamController<AcpEvent>.broadcast();
  final _rawEventLog = <Map<String, dynamic>>[];
  final _pendingRequests = <dynamic, Completer<AcpJsonRpcResponse>>{};
  final _pendingRequestMethods = <dynamic, String>{};

  int _nextId = 1;
  bool _initialized = false;
  int? _protocolVersion;
  Map<String, dynamic>? _agentCapabilities;
  StreamSubscription<String>? _stdoutSub;
  ClientRequestHandler? _clientRequestHandler;

  Stream<AcpEvent> get events => _eventController.stream;
  bool get isInitialized => _initialized;
  int? get protocolVersion => _protocolVersion;
  Map<String, dynamic>? get agentCapabilities => _agentCapabilities;
  List<Map<String, dynamic>> get rawEventLog => List.unmodifiable(_rawEventLog);

  void setClientRequestHandler(ClientRequestHandler handler) {
    _clientRequestHandler = handler;
  }

  Future<void> connect() async {
    await _stdoutSub?.cancel();
    _stdoutSub = _processService.stdoutLines.listen(_handleStdoutLine);
  }

  Future<void> initialize() async {
    final response = await _sendRequest('initialize', {
      'protocolVersion': AppConstants.acpProtocolVersion,
      'clientCapabilities': {
        'fs': {'readTextFile': true, 'writeTextFile': true},
        'terminal': false,
      },
      'clientInfo': {
        'name': 'grokker',
        'title': 'Grokker',
        'version': AppConstants.appVersion,
      },
    });

    if (response.isError) {
      throw AcpInitializeFailedError(technicalDetails: response.error?.message);
    }

    final result = response.result as Map<String, dynamic>? ?? {};
    _protocolVersion = result['protocolVersion'] as int?;
    _agentCapabilities = result['agentCapabilities'] as Map<String, dynamic>?;
    _initialized = true;

    _emitEvent(
      AcpEvent(
        type: AcpEventType.raw,
        timestamp: DateTime.now(),
        text: 'ACP initialized (protocol v$_protocolVersion)',
        rawPayload: result,
      ),
    );
  }

  Future<AcpSession> createSession({String? cwd}) async {
    if (!_initialized) {
      throw const AcpInitializeFailedError(
        technicalDetails: 'Call initialize() before session/new',
      );
    }

    final workingDir = _resolveSessionCwd(cwd);
    final response = await _sendRequest(
      'session/new',
      {
        'cwd': workingDir,
        'mcpServers': <Map<String, dynamic>>[],
      },
      timeout: const Duration(seconds: 60),
    );
    if (response.isError) {
      final details = response.error?.data ?? response.error?.message;
      throw AcpSessionCreationFailedError(technicalDetails: '$details');
    }

    final result = response.result as Map<String, dynamic>? ?? {};
    final session = AcpSession.fromJson(result);
    if (session.id.isEmpty) {
      throw AcpSessionCreationFailedError(
        technicalDetails: 'Grok returned empty sessionId: $result',
      );
    }
    return session;
  }

  Future<Map<String, dynamic>> sendPrompt({
    required String sessionId,
    required List<Map<String, dynamic>> prompt,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final response = await _sendRequest('session/prompt', {
      'sessionId': sessionId,
      'prompt': prompt,
    }, timeout: timeout);

    if (response.isError) {
      final details = response.error?.data ?? response.error?.message;
      throw PromptSendFailedError(technicalDetails: '$details');
    }

    return response.result as Map<String, dynamic>? ?? {};
  }

  void cancelSession(String sessionId) {
    _sendNotification('session/cancel', {'sessionId': sessionId});
  }

  Future<void> shutdown() async {
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _initialized = false;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('ACP client shutting down'));
      }
    }
    _pendingRequests.clear();
    _pendingRequestMethods.clear();
  }

  Future<AcpJsonRpcResponse> _sendRequest(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = AppConstants.acpRequestTimeout,
  }) async {
    final id = _nextId++;
    final request = AcpJsonRpcRequest(id: id, method: method, params: params);
    final completer = Completer<AcpJsonRpcResponse>();
    _pendingRequests[id] = completer;
    _pendingRequestMethods[id] = method;

    _logRaw({'direction': 'out', 'request': request.toJson()});
    _processService.writeLine(jsonEncode(request.toJson()));

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(id);
          _pendingRequestMethods.remove(id);
          throw ResponseTimeoutError(
            technicalDetails: 'Timeout on $method (id=$id)',
          );
        },
      );
    } catch (e) {
      _pendingRequests.remove(id);
      _pendingRequestMethods.remove(id);
      rethrow;
    }
  }

  void _sendNotification(String method, Map<String, dynamic> params) {
    final notification = {'jsonrpc': '2.0', 'method': method, 'params': params};
    _logRaw({'direction': 'out', 'notification': notification});
    _processService.writeLine(jsonEncode(notification));
  }

  void _handleStdoutLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      _logRaw({'direction': 'in', 'payload': json});

      if (json.containsKey('id') && json.containsKey('method')) {
        _handleClientRequest(json);
        return;
      }

      if (json.containsKey('id')) {
        _handleResponse(json);
        return;
      }

      if (json.containsKey('method')) {
        _handleNotification(json);
        return;
      }

      _emitEvent(
        AcpEvent(
          type: AcpEventType.unknown,
          timestamp: DateTime.now(),
          rawPayload: json,
        ),
      );
    } catch (e) {
      AppLogger.warn('Failed to parse ACP line: $trimmed');
      _emitEvent(
        AcpEvent(
          type: AcpEventType.unknown,
          timestamp: DateTime.now(),
          text: trimmed,
          rawPayload: {'parseError': e.toString(), 'line': trimmed},
        ),
      );
    }
  }

  void _handleResponse(Map<String, dynamic> json) {
    final response = AcpJsonRpcResponse.fromJson(json);
    final method = _pendingRequestMethods.remove(response.id);
    final completer = _pendingRequests.remove(response.id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
    if (method == 'session/prompt' && !response.isError) {
      final result = response.result as Map<String, dynamic>? ?? {};
      _emitEvent(
        AcpEvent(
          type: AcpEventType.promptTurnCompleted,
          timestamp: DateTime.now(),
          status: result['stopReason'] as String?,
          rawPayload: result,
        ),
      );
    }
  }

  void _handleNotification(Map<String, dynamic> json) {
    final notification = AcpJsonRpcNotification.fromJson(json);
    final event = _normalizer.normalizeNotification(notification);
    _emitEvent(event);
  }

  Future<void> _handleClientRequest(Map<String, dynamic> json) async {
    final id = json['id'];
    final method = json['method'] as String;
    final params = json['params'] as Map<String, dynamic>? ?? {};

    final event = _normalizer.normalizeClientRequest(method, params);
    _emitEvent(event);

    try {
      final handler = _clientRequestHandler;
      final result = handler != null
          ? await handler(method, params)
          : <String, dynamic>{'approved': false, 'reason': 'No handler'};

      final response = {'jsonrpc': '2.0', 'id': id, 'result': result};
      _logRaw({'direction': 'out', 'response': response});
      _processService.writeLine(jsonEncode(response));
    } catch (e) {
      final response = {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': e.toString()},
      };
      _processService.writeLine(jsonEncode(response));
    }
  }

  void _emitEvent(AcpEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _logRaw(Map<String, dynamic> entry) {
    _rawEventLog.add({...entry, 'timestamp': DateTime.now().toIso8601String()});
    while (_rawEventLog.length > AppConstants.maxRawEvents) {
      _rawEventLog.removeAt(0);
    }
  }

  String _resolveSessionCwd(String? cwd) {
    if (cwd != null && cwd.isNotEmpty) return p.absolute(cwd);
    final home = GrokCliLocatorService.resolveHomeDirectory();
    if (home != null && home.isNotEmpty) return home;
    return p.absolute(Directory.current.path);
  }

  Future<void> dispose() async {
    await shutdown();
    await _eventController.close();
  }
}
