import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/attachment_item.dart';

class AttachmentService {
  AttachmentService({
    Uuid? uuid,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _uuid = uuid ?? const Uuid(),
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Uuid _uuid;
  final Future<Directory> Function() _supportDirectoryProvider;

  static const imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.heic',
    '.heif',
    '.tiff',
    '.tif',
    '.bmp',
    '.ico',
  };
  static const textExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.json',
    '.yaml',
    '.yml',
    '.toml',
    '.dart',
    '.ts',
    '.tsx',
    '.js',
    '.jsx',
    '.py',
    '.rs',
    '.go',
    '.java',
    '.kt',
    '.swift',
    '.c',
    '.cpp',
    '.h',
    '.cs',
    '.rb',
    '.php',
    '.sql',
    '.sh',
    '.zsh',
    '.xml',
    '.html',
    '.css',
    '.scss',
  };

  Future<Directory> _stagingDir() async {
    final support = await _supportDirectoryProvider();
    final dir = Directory(p.join(support.path, 'grokker', 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<AttachmentItem?> createFromBytes({
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    int warningThreshold = AppConstants.attachmentWarningBytesDefault,
  }) async {
    final dir = await _stagingDir();
    final fileName = 'paste_${_uuid.v4()}.$extension';
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return validateAndCreate(filePath, warningThreshold: warningThreshold);
  }

  Future<AttachmentItem?> validateAndCreate(
    String filePath, {
    int warningThreshold = AppConstants.attachmentWarningBytesDefault,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final ext = p.extension(filePath).toLowerCase();
    final stat = await file.stat();
    final type = _detectType(ext);
    if (type == AttachmentType.unknown) return null;

    String? warning;
    if (stat.size > warningThreshold) {
      warning = 'Large file (${_formatBytes(stat.size)}). Sending may be slow.';
    }

    return AttachmentItem(
      id: _uuid.v4(),
      path: p.absolute(filePath),
      type: type,
      fileName: p.basename(filePath),
      sizeBytes: stat.size,
      mimeType: _mimeForExtension(ext, type),
      warning: warning,
    );
  }

  Future<String> buildAttachmentReferenceSection(
    List<AttachmentItem> attachments, {
    bool inlineSmallText = true,
    int inlineMaxBytes = AppConstants.inlineTextMaxBytes,
  }) async {
    final buffer = StringBuffer();
    for (final a in attachments) {
      switch (a.type) {
        case AttachmentType.image:
          buffer.writeln(
            '* [image] ${a.fileName} (${a.mimeType}, ${_formatBytes(a.sizeBytes)}) — attached inline in this prompt.',
          );
        case AttachmentType.pdf:
          buffer.writeln(
            '* [pdf] ${a.path} (${_formatBytes(a.sizeBytes)}${a.pageCount != null ? ', ${a.pageCount} pages' : ''})',
          );
          buffer.writeln('  Attached PDF passed as local file reference.');
        default:
          buffer.writeln(
            '* [${a.type.name}] ${a.path} (${_formatBytes(a.sizeBytes)})',
          );
          if (inlineSmallText &&
              a.sizeBytes <= inlineMaxBytes &&
              a.type != AttachmentType.image &&
              a.type != AttachmentType.pdf) {
            try {
              final content = await File(a.path).readAsString();
              buffer.writeln('  Inline content:\n```\n$content\n```');
            } catch (_) {
              buffer.writeln('  (Could not read file for inline content)');
            }
          }
      }
    }
    return buffer.toString();
  }

  AttachmentType _detectType(String ext) {
    if (imageExtensions.contains(ext)) return AttachmentType.image;
    if (ext == '.pdf') return AttachmentType.pdf;
    if (ext == '.md' || ext == '.markdown') return AttachmentType.markdown;
    if ({'.json', '.yaml', '.yml', '.toml'}.contains(ext)) {
      return AttachmentType.config;
    }
    if (textExtensions.contains(ext)) return AttachmentType.code;
    if (ext == '.txt') return AttachmentType.text;
    return AttachmentType.unknown;
  }

  String _mimeForExtension(String ext, AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        if (ext == '.png') return 'image/png';
        if (ext == '.webp') return 'image/webp';
        if (ext == '.gif') return 'image/gif';
        if (ext == '.heic') return 'image/heic';
        if (ext == '.heif') return 'image/heif';
        return 'image/jpeg';
      case AttachmentType.pdf:
        return 'application/pdf';
      case AttachmentType.markdown:
        return 'text/markdown';
      case AttachmentType.config:
        if (ext == '.json') return 'application/json';
        if (ext == '.toml') return 'application/toml';
        return 'application/yaml';
      default:
        return 'text/plain';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
