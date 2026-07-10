import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/models/chat_image_attachment.dart';

class GeneratedImageService {
  GeneratedImageService({
    Uuid? uuid,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _uuid = uuid ?? const Uuid(),
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Uuid _uuid;
  final Future<Directory> Function() _supportDirectoryProvider;

  Future<Directory> _sessionImageDir(String sessionId) async {
    final support = await _supportDirectoryProvider();
    final dir = Directory(p.join(support.path, 'grokker', 'images', sessionId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<ChatImageAttachment> saveBase64Image({
    required String sessionId,
    required String base64Data,
    String? mimeType,
    String? suggestedName,
  }) async {
    final bytes = _decodeBase64(base64Data);
    final resolvedMime = mimeType ?? _mimeFromBytes(bytes) ?? 'image/png';
    final ext = _extensionForMime(resolvedMime);
    final dir = await _sessionImageDir(sessionId);
    final fileName = suggestedName ?? '${_uuid.v4()}.$ext';
    final dest = File(p.join(dir.path, fileName));
    await dest.writeAsBytes(bytes, flush: true);
    return ChatImageAttachment(
      id: _uuid.v4(),
      path: dest.path,
      mimeType: resolvedMime,
    );
  }

  Future<ChatImageAttachment> importImageFile({
    required String sessionId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Generated image not found', sourcePath);
    }
    final dir = await _sessionImageDir(sessionId);
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath).replaceFirst('.', '')
        : 'jpg';
    final dest = File(p.join(dir.path, '${_uuid.v4()}.$ext'));
    await source.copy(dest.path);
    return ChatImageAttachment(
      id: _uuid.v4(),
      path: dest.path,
      mimeType: _mimeFromPath(sourcePath) ?? 'image/jpeg',
    );
  }

  Uint8List _decodeBase64(String data) {
    var normalized = data.trim();
    final comma = normalized.indexOf(',');
    if (normalized.startsWith('data:') && comma != -1) {
      normalized = normalized.substring(comma + 1);
    }
    return base64Decode(normalized);
  }

  String? _mimeFromBytes(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  String? _mimeFromPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  String _extensionForMime(String mime) {
    switch (mime) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }
}
