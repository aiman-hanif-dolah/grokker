import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/models/attachment_item.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_typography.dart';
import '../cubit/attachment_cubit.dart';

class AttachmentChips extends StatelessWidget {
  const AttachmentChips({
    super.key,
    required this.attachments,
    required this.onRemove,
    required this.onTogglePin,
  });

  final List<AttachmentItem> attachments;
  final void Function(String id) onRemove;
  final void Function(String id) onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: GrokkerSpacing.s8,
      runSpacing: GrokkerSpacing.s8,
      children: attachments
          .take(AttachmentCubit.maxImageAttachments + 10)
          .map(
            (a) => _Chip(
              attachment: a,
              onRemove: () => onRemove(a.id),
              onTogglePin: () => onTogglePin(a.id),
            ),
          )
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.attachment,
    required this.onRemove,
    required this.onTogglePin,
  });

  final AttachmentItem attachment;
  final VoidCallback onRemove;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GrokkerSpacing.s8,
        vertical: GrokkerSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: GrokkerSurfaces.raised,
        border: Border.all(
          color: attachment.isPinned
              ? GrokkerColors.signalBlue.withValues(alpha: 0.4)
              : GrokkerColors.pewter.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        boxShadow: attachment.isPinned
            ? GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 6)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment.type == AttachmentType.image)
            ClipRRect(
              borderRadius: BorderRadius.circular(GrokkerRadius.badge),
              child: Image.file(
                File(attachment.path),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image,
                  size: 20,
                  color: GrokkerColors.slate,
                ),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: GrokkerColors.signalBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GrokkerRadius.badge),
              ),
              child: Icon(
                _iconFor(attachment.type),
                size: 14,
                color: GrokkerColors.signalBlueBright,
              ),
            ),
          const SizedBox(width: GrokkerSpacing.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: GrokkerTypography.bodySm(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachment.warning != null)
                  Text(
                    attachment.warning!,
                    style: GrokkerTypography.caption(
                      color: GrokkerColors.warningAmber,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              attachment.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 14,
              color: attachment.isPinned
                  ? GrokkerColors.signalBlueBright
                  : GrokkerColors.fog,
            ),
            onPressed: onTogglePin,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 14,
              color: GrokkerColors.fog,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.markdown:
        return Icons.description;
      case AttachmentType.code:
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }
}
