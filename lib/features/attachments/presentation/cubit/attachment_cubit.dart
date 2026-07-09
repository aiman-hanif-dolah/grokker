import 'package:desktop_drop/desktop_drop.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/attachment_item.dart';
import '../../data/services/attachment_service.dart';
import '../../data/services/clipboard_attachment_reader.dart';
import '../../data/services/drop_item_resolver.dart';

class AttachmentState extends Equatable {
  const AttachmentState({
    this.attachments = const [],
    this.isLoading = false,
    this.statusMessage,
  });

  final List<AttachmentItem> attachments;
  final bool isLoading;
  final String? statusMessage;

  AttachmentState copyWith({
    List<AttachmentItem>? attachments,
    bool? isLoading,
    String? statusMessage,
    bool clearStatus = false,
  }) {
    return AttachmentState(
      attachments: attachments ?? this.attachments,
      isLoading: isLoading ?? this.isLoading,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }

  @override
  List<Object?> get props => [attachments, isLoading, statusMessage];
}

class AttachmentPasteResult {
  const AttachmentPasteResult({
    this.attached = false,
    this.insertedText,
  });

  final bool attached;
  final String? insertedText;
}

class AttachmentCubit extends Cubit<AttachmentState> {
  AttachmentCubit(
    this._service, {
    ClipboardAttachmentReader? clipboardReader,
    DropItemResolver? dropItemResolver,
  }) : _clipboardReader = clipboardReader ?? ClipboardAttachmentReader(),
       _dropItemResolver = dropItemResolver ?? DropItemResolver(_service),
       super(const AttachmentState());

  final AttachmentService _service;
  final ClipboardAttachmentReader _clipboardReader;
  final DropItemResolver _dropItemResolver;

  static const _pickerExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'heic',
    'heif',
    'tiff',
    'tif',
    'bmp',
    'ico',
    'pdf',
    'txt',
    'md',
    'json',
    'yaml',
    'yml',
    'toml',
    'dart',
    'ts',
    'tsx',
    'js',
    'py',
    'rs',
    'go',
  ];

  Future<void> pickFiles({int warningThreshold = 5242880}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _pickerExtensions,
    );
    if (result == null) return;
    await addPaths(
      result.paths.whereType<String>().toList(),
      warningThreshold: warningThreshold,
    );
  }

  Future<void> pickImages({int warningThreshold = 5242880}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;
    await addPaths(
      result.paths.whereType<String>().toList(),
      warningThreshold: warningThreshold,
    );
  }

  Future<AttachmentPasteResult> pasteFromClipboard({
    int warningThreshold = 5242880,
  }) async {
    final payload = await _clipboardReader.read();
    if (payload == null) {
      return const AttachmentPasteResult();
    }

    if (payload.hasAttachments) {
      emit(state.copyWith(isLoading: true, clearStatus: true));
      final updated = [...state.attachments];
      final currentImages = state.attachments.where((a) => a.type == AttachmentType.image).length;
      var addedImages = 0;

      if (payload.image != null && currentImages + addedImages < maxImageAttachments) {
        final image = payload.image!;
        final item = await _service.createFromBytes(
          bytes: image.bytes,
          mimeType: image.mimeType,
          extension: image.extension,
          warningThreshold: warningThreshold,
        );
        if (item != null) {
          updated.add(item);
          addedImages++;
        }
      }

      if (payload.filePaths.isNotEmpty) {
        for (final path in payload.filePaths) {
          final item = await _service.validateAndCreate(
            path,
            warningThreshold: warningThreshold,
          );
          if (item != null) {
            if (item.type == AttachmentType.image && currentImages + addedImages >= maxImageAttachments) {
              continue;
            }
            updated.add(item);
            if (item.type == AttachmentType.image) addedImages++;
          }
        }
      }

      emit(
        AttachmentState(
          attachments: updated,
          statusMessage: _statusFor(updated),
        ),
      );
      return const AttachmentPasteResult(attached: true);
    }

    if (payload.text != null) {
      return AttachmentPasteResult(insertedText: payload.text);
    }

    return const AttachmentPasteResult();
  }

  static const int maxImageAttachments = 3;

  Future<void> addDropItems(
    List<DropItem> items, {
    int warningThreshold = 5242880,
  }) async {
    if (items.isEmpty) return;
    emit(state.copyWith(isLoading: true, clearStatus: true));

    final resolved = await _dropItemResolver.resolve(
      items,
      warningThreshold: warningThreshold,
    );

    if (resolved.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          statusMessage: 'No supported files in drop.',
        ),
      );
      return;
    }

    final currentImages = state.attachments.where((a) => a.type == AttachmentType.image).length;
    final newImages = resolved.where((a) => a.type == AttachmentType.image).length;
    if (currentImages + newImages > maxImageAttachments) {
      emit(
        state.copyWith(
          isLoading: false,
          statusMessage: 'Max $maxImageAttachments images allowed.',
        ),
      );
      return;
    }

    final updated = [...state.attachments, ...resolved];
    emit(
      AttachmentState(
        attachments: updated,
        statusMessage: _statusFor(updated),
      ),
    );
  }

  Future<void> addPaths(
    List<String> paths, {
    int warningThreshold = 5242880,
  }) async {
    if (paths.isEmpty) return;
    emit(state.copyWith(isLoading: true, clearStatus: true));
    final updated = [...state.attachments];
    var added = 0;
    final currentImages = state.attachments.where((a) => a.type == AttachmentType.image).length;
    for (final path in paths) {
      final item = await _service.validateAndCreate(
        path,
        warningThreshold: warningThreshold,
      );
      if (item != null) {
        if (item.type == AttachmentType.image && currentImages + added >= maxImageAttachments) {
          continue;
        }
        updated.add(item);
        added++;
      }
    }
    emit(
      AttachmentState(
        attachments: updated,
        statusMessage: added == 0
            ? 'No supported files in selection.'
            : _statusFor(updated),
      ),
    );
  }

  String? _statusFor(List<AttachmentItem> attachments) {
    if (attachments.any((a) => a.type == AttachmentType.pdf)) {
      return 'Attached PDF passed as local file reference.';
    }
    if (attachments.any((a) => a.type == AttachmentType.image)) {
      return 'Image attached — Grok can inspect it with your prompt.';
    }
    return null;
  }

  void remove(String id) {
    emit(
      state.copyWith(
        attachments: state.attachments.where((a) => a.id != id).toList(),
        clearStatus: true,
      ),
    );
  }

  void togglePin(String id) {
    emit(
      state.copyWith(
        attachments: state.attachments.map((a) {
          if (a.id == id) return a.copyWith(isPinned: !a.isPinned);
          return a;
        }).toList(),
      ),
    );
  }

  List<AttachmentItem> clearUnpinned() {
    final pinned = state.attachments.where((a) => a.isPinned).toList();
    emit(state.copyWith(attachments: pinned, clearStatus: true));
    return pinned;
  }

  void clear() => emit(const AttachmentState());

  Future<String> buildReferenceSection({bool inlineSmallText = true}) {
    return buildReferenceSectionFor(
      state.attachments,
      inlineSmallText: inlineSmallText,
    );
  }

  Future<String> buildReferenceSectionFor(
    List<AttachmentItem> attachments, {
    bool inlineSmallText = true,
  }) {
    return _service.buildAttachmentReferenceSection(
      attachments,
      inlineSmallText: inlineSmallText,
    );
  }
}