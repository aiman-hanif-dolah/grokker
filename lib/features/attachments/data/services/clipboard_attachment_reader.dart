import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImageData {
  const ClipboardImageData({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
}

class ClipboardPastePayload {
  const ClipboardPastePayload({
    this.filePaths = const [],
    this.image,
    this.text,
  });

  final List<String> filePaths;
  final ClipboardImageData? image;
  final String? text;

  bool get hasAttachments => filePaths.isNotEmpty || image != null;
}

class ClipboardAttachmentReader {
  Future<ClipboardPastePayload?> read() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;

    final reader = await clipboard.read();

    final filePaths = await _readFilePaths(reader);
    if (filePaths.isNotEmpty) {
      return ClipboardPastePayload(filePaths: filePaths);
    }

    final image = await _readImage(reader);
    if (image != null) {
      return ClipboardPastePayload(image: image);
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        return ClipboardPastePayload(text: text);
      }
    }

    return null;
  }

  Future<List<String>> _readFilePaths(ClipboardReader reader) async {
    final paths = <String>{};

    for (final item in reader.items) {
      if (item.canProvide(Formats.fileUri)) {
        final uri = await item.readValue(Formats.fileUri);
        final path = _pathFromUri(uri?.toString());
        if (path != null && File(path).existsSync()) {
          paths.add(path);
        }
      }
    }

    if (paths.isEmpty && reader.canProvide(Formats.fileUri)) {
      final uri = await reader.readValue(Formats.fileUri);
      final path = _pathFromUri(uri?.toString());
      if (path != null && File(path).existsSync()) {
        paths.add(path);
      }
    }

    return paths.toList();
  }

  String? _pathFromUri(String? uri) {
    if (uri == null || uri.isEmpty) return null;
    if (uri.startsWith('file://')) {
      try {
        return Uri.parse(uri).toFilePath();
      } catch (_) {
        return null;
      }
    }
    if (uri.startsWith('/')) return uri;
    return null;
  }

  Future<ClipboardImageData?> _readImage(ClipboardReader reader) async {
    const formats = <(FileFormat, String, String)>[
      (Formats.png, 'image/png', 'png'),
      (Formats.jpeg, 'image/jpeg', 'jpg'),
      (Formats.webp, 'image/webp', 'webp'),
    ];

    for (final (format, mime, ext) in formats) {
      if (!reader.canProvide(format)) continue;
      final bytes = await _readFileBytes(reader, format);
      if (bytes != null && bytes.isNotEmpty) {
        return ClipboardImageData(bytes: bytes, mimeType: mime, extension: ext);
      }
    }

    return null;
  }

  Future<Uint8List?> _readFileBytes(
    ClipboardReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();

    reader.getFile(format, (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }
}
