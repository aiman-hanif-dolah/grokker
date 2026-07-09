import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/acp/data/services/acp_event_normalizer.dart';
import 'package:grokker/features/acp/domain/models/acp_models.dart';

void main() {
  group('JSON-RPC encoding', () {
    test('request encodes correctly', () {
      final request = AcpJsonRpcRequest(
        id: 1,
        method: 'initialize',
        params: {'protocolVersion': 1},
      );
      final json = request.toJson();
      expect(json['jsonrpc'], '2.0');
      expect(json['id'], 1);
      expect(json['method'], 'initialize');
    });

    test('response parses correctly', () {
      final raw = {
        'jsonrpc': '2.0',
        'id': 2,
        'result': {'stopReason': 'end_turn'},
      };
      final response = AcpJsonRpcResponse.fromJson(raw);
      expect(response.id, 2);
      expect(response.isError, false);
      expect((response.result as Map)['stopReason'], 'end_turn');
    });

    test('error response parses correctly', () {
      final raw = {
        'jsonrpc': '2.0',
        'id': 3,
        'error': {'code': -32600, 'message': 'Invalid Request'},
      };
      final response = AcpJsonRpcResponse.fromJson(raw);
      expect(response.isError, true);
      expect(response.error?.code, -32600);
    });
  });

  group('ACP notification parsing', () {
    final normalizer = AcpEventNormalizer();

    test('agent_message_chunk normalized', () {
      final notification = AcpJsonRpcNotification.fromJson({
        'jsonrpc': '2.0',
        'method': 'session/update',
        'params': {
          'sessionId': 'sess_1',
          'update': {
            'sessionUpdate': 'agent_message_chunk',
            'messageId': 'msg_1',
            'content': {'type': 'text', 'text': 'Hello'},
          },
        },
      });
      final event = normalizer.normalizeNotification(notification);
      expect(event.type, AcpEventType.assistantTextChunk);
      expect(event.text, 'Hello');
      expect(event.sessionId, 'sess_1');
    });

    test('agent_message_chunk image normalized', () {
      final notification = AcpJsonRpcNotification.fromJson({
        'jsonrpc': '2.0',
        'method': 'session/update',
        'params': {
          'sessionId': 'sess_1',
          'update': {
            'sessionUpdate': 'agent_message_chunk',
            'messageId': 'msg_2',
            'content': {
              'type': 'image',
              'mimeType': 'image/png',
              'data': 'aGVsbG8=',
            },
          },
        },
      });
      final event = normalizer.normalizeNotification(notification);
      expect(event.type, AcpEventType.assistantImageChunk);
      expect(event.imageData, 'aGVsbG8=');
      expect(event.imageMimeType, 'image/png');
    });

    test('tool_call_update image normalized', () {
      final notification = AcpJsonRpcNotification.fromJson({
        'jsonrpc': '2.0',
        'method': 'session/update',
        'params': {
          'sessionId': 'sess_1',
          'update': {
            'sessionUpdate': 'tool_call_update',
            'toolCallId': 'tool_1',
            'status': 'completed',
            'rawOutput': {
              'type': 'ImageGen',
              'path': '/tmp/generated.jpg',
              'filename': 'generated.jpg',
            },
          },
        },
      });
      final event = normalizer.normalizeNotification(notification);
      expect(event.type, AcpEventType.toolImageCompleted);
      expect(event.imagePath, '/tmp/generated.jpg');
    });

    test('unknown update preserved', () {
      final notification = AcpJsonRpcNotification.fromJson({
        'jsonrpc': '2.0',
        'method': 'session/update',
        'params': {
          'sessionId': 'sess_1',
          'update': {'sessionUpdate': 'future_thing', 'data': 42},
        },
      });
      final event = normalizer.normalizeNotification(notification);
      expect(event.type, AcpEventType.unknown);
      expect(event.rawPayload?['sessionUpdate'], 'future_thing');
    });
  });
}
