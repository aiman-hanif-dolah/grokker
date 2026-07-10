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
    '.log',
    '.csv',
    '.tsv',
    '.md',
    '.markdown',
    '.rst',
    '.json',
    '.jsonc',
    '.json5',
    '.yaml',
    '.yml',
    '.toml',
    '.ini',
    '.cfg',
    '.conf',
    '.env',
    '.properties',
    '.xml',
    '.html',
    '.htm',
    '.css',
    '.scss',
    '.less',
    '.svg',
    '.dart',
    '.ts',
    '.tsx',
    '.js',
    '.jsx',
    '.mjs',
    '.cjs',
    '.py',
    '.rb',
    '.php',
    '.rs',
    '.go',
    '.java',
    '.kt',
    '.kts',
    '.swift',
    '.c',
    '.cc',
    '.cpp',
    '.cxx',
    '.h',
    '.hpp',
    '.cs',
    '.fs',
    '.sql',
    '.sh',
    '.bash',
    '.zsh',
    '.ps1',
    '.bat',
    '.cmd',
    '.r',
    '.lua',
    '.pl',
    '.pm',
    '.scala',
    '.groovy',
    '.gradle',
    '.cmake',
    '.make',
    '.mk',
    '.dockerfile',
    '.gitignore',
    '.gitattributes',
    '.editorconfig',
    '.lock',
  };

  static const documentExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.odt',
    '.ods',
    '.odp',
    '.rtf',
    '.epub',
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
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final fileName = 'paste_${_uuid.v4()}.$ext';
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return validateAndCreate(filePath, warningThreshold: warningThreshold);
  }

  /// Accepts any existing file. Unknown types become [AttachmentType.binary]
  /// so PDFs and other documents are never silently dropped.
  Future<AttachmentItem?> validateAndCreate(
    String filePath, {
    int warningThreshold = AppConstants.attachmentWarningBytesDefault,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final ext = p.extension(filePath).toLowerCase();
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    final type = _detectType(ext);
    String? warning;
    if (stat.size > warningThreshold) {
      warning = 'Large file (${_formatBytes(stat.size)}). Sending may be slow.';
    }
    if (type == AttachmentType.pdf &&
        stat.size > AppConstants.inlineTextMaxBytes) {
      warning = warning == null
          ? 'PDF will be embedded as binary for Grok to read.'
          : '$warning PDF embedded as binary.';
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
            '* [pdf] ${a.fileName} (${_formatBytes(a.sizeBytes)}) at ${a.path}',
          );
          buffer.writeln(
            '  PDF binary content is embedded in the prompt for Grok to read.',
          );
        case AttachmentType.binary:
          buffer.writeln(
            '* [binary] ${a.fileName} (${a.mimeType}, ${_formatBytes(a.sizeBytes)}) at ${a.path}',
          );
          buffer.writeln('  Binary content is embedded when size permits.');
        default:
          buffer.writeln(
            '* [${a.type.name}] ${a.path} (${_formatBytes(a.sizeBytes)})',
          );
          if (inlineSmallText &&
              a.sizeBytes <= inlineMaxBytes &&
              a.type != AttachmentType.image) {
            try {
              final content = await File(a.path).readAsString();
              buffer.writeln('  Inline content:\n```\n$content\n```');
            } catch (_) {
              // Try as binary note
              buffer.writeln(
                '  (Text decode failed — binary will be embedded if possible)',
              );
            }
          }
      }
    }
    return buffer.toString();
  }

  AttachmentType _detectType(String ext) {
    if (imageExtensions.contains(ext)) return AttachmentType.image;
    if (ext == '.pdf') return AttachmentType.pdf;
    if (ext == '.md' || ext == '.markdown' || ext == '.rst') {
      return AttachmentType.markdown;
    }
    if ({
      '.json',
      '.jsonc',
      '.json5',
      '.yaml',
      '.yml',
      '.toml',
      '.ini',
      '.cfg',
      '.conf',
      '.env',
      '.properties',
    }.contains(ext)) {
      return AttachmentType.config;
    }
    if (ext == '.txt' || ext == '.log' || ext == '.csv' || ext == '.tsv') {
      return AttachmentType.text;
    }
    if (textExtensions.contains(ext)) return AttachmentType.code;
    if (documentExtensions.contains(ext)) return AttachmentType.binary;
    // Accept unknown files as binary rather than rejecting them.
    return AttachmentType.binary;
  }

  String _mimeForExtension(String ext, AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        if (ext == '.png') return 'image/png';
        if (ext == '.webp') return 'image/webp';
        if (ext == '.gif') return 'image/gif';
        if (ext == '.heic') return 'image/heic';
        if (ext == '.heif') return 'image/heif';
        if (ext == '.bmp') return 'image/bmp';
        if (ext == '.svg') return 'image/svg+xml';
        return 'image/jpeg';
      case AttachmentType.pdf:
        return 'application/pdf';
      case AttachmentType.markdown:
        return 'text/markdown';
      case AttachmentType.config:
        if (ext == '.json' || ext == '.jsonc' || ext == '.json5') {
          return 'application/json';
        }
        if (ext == '.toml') return 'application/toml';
        if (ext == '.xml') return 'application/xml';
        return 'application/yaml';
      case AttachmentType.binary:
        return _binaryMime(ext);
      case AttachmentType.code:
      case AttachmentType.text:
      case AttachmentType.unknown:
        return 'text/plain';
    }
  }

  String _binaryMime(String ext) {
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.zip' => 'application/zip',
      '.gz' => 'application/gzip',
      '.7z' => 'application/x-7z-compressed',
      '.rtf' => 'application/rtf',
      '.epub' => 'application/epub+zip',
      _ => 'application/octet-stream',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
