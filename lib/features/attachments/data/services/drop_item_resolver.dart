import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/models/attachment_item.dart';
import 'attachment_service.dart';

class DropItemResolver {
  DropItemResolver(this._service);

  final AttachmentService _service;

  Future<List<AttachmentItem>> resolve(
    List<DropItem> items, {
    int warningThreshold = 5242880,
  }) async {
    final resolved = <AttachmentItem>[];
    for (final item in items) {
      final attachments = await _resolveItem(
        item,
        warningThreshold: warningThreshold,
      );
      resolved.addAll(attachments);
    }
    return resolved;
  }

  Future<List<AttachmentItem>> _resolveItem(
    DropItem item, {
    required int warningThreshold,
  }) async {
    if (item is DropItemDirectory) {
      return _resolveDirectory(item, warningThreshold: warningThreshold);
    }

    final bookmark = item.extraAppleBookmark;
    var accessed = false;
    if (bookmark != null && bookmark.isNotEmpty) {
      accessed = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
    }

    try {
      final path = item.path;
      if (path.isNotEmpty) {
        final attachment = await _service.validateAndCreate(
          p.absolute(path),
          warningThreshold: warningThreshold,
        );
        if (attachment != null) {
          return [attachment];
        }
      }

      final bytes = await _readBytes(item);
      if (bytes == null || bytes.isEmpty) return const [];

      final extension = _extensionFor(item, bytes);
      final mimeType = item.mimeType ?? _mimeForExtension(extension);
      final attachment = await _service.createFromBytes(
        bytes: bytes,
        mimeType: mimeType,
        extension: extension,
        warningThreshold: warningThreshold,
      );
      return attachment == null ? const [] : [attachment];
    } finally {
      if (accessed && bookmark != null && bookmark.isNotEmpty) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }

  Future<List<AttachmentItem>> _resolveDirectory(
    DropItemDirectory directory, {
    required int warningThreshold,
  }) async {
    final dir = Directory(directory.path);
    if (!await dir.exists()) return const [];

    final resolved = <AttachmentItem>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final attachment = await _service.validateAndCreate(
        entity.path,
        warningThreshold: warningThreshold,
      );
      if (attachment != null) {
        resolved.add(attachment);
      }
    }
    return resolved;
  }

  Future<Uint8List?> _readBytes(DropItem item) async {
    try {
      return await item.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String _extensionFor(DropItem item, Uint8List bytes) {
    final fromPath = p.extension(item.path);
    if (fromPath.isNotEmpty) {
      return fromPath.substring(1).toLowerCase();
    }

    final fromName = item.name;
    if (fromName.contains('.')) {
      return p.extension(fromName).substring(1).toLowerCase();
    }

    final mime = item.mimeType;
    if (mime != null) {
      final fromMime = _extensionFromMime(mime);
      if (fromMime != null) return fromMime;
    }

    if (bytes.length >= 8) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
      if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
      if (bytes[0] == 0x25 && bytes[1] == 0x50) return 'pdf';
    }

    return 'bin';
  }

  String? _extensionFromMime(String mime) {
    return switch (mime) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'application/pdf' => 'pdf',
      'text/plain' => 'txt',
      'text/markdown' => 'md',
      _ => null,
    };
  }

  String _mimeForExtension(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'pdf' => 'application/pdf',
      'md' => 'text/markdown',
      _ => 'application/octet-stream',
    };
  }
}
