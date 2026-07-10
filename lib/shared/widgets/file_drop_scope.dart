import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_drop/src/events.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

/// Reliable file-drop handling for macOS/desktop.
///
/// The stock [DropTarget] widget can miss drops on macOS when file promises
/// resolve asynchronously (status is already idle when [DropDoneEvent] fires).
/// This scope listens to raw drop events and accepts completed drops while a
/// drag session was active in this widget's bounds.
class FileDropScope extends StatefulWidget {
  const FileDropScope({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.onDraggingChanged,
    this.enabled = true,
  });

  final Widget child;
  final void Function(List<DropItem> files) onFilesDropped;
  final ValueChanged<bool>? onDraggingChanged;
  final bool enabled;

  @override
  State<FileDropScope> createState() => _FileDropScopeState();
}

class _FileDropScopeState extends State<FileDropScope> {
  bool _dragInBounds = false;
  bool _pendingDrop = false;

  @override
  void initState() {
    super.initState();
    DesktopDrop.instance.init();
    if (widget.enabled) {
      DesktopDrop.instance.addRawDropEventListener(_onDropEvent);
    }
  }

  @override
  void didUpdateWidget(FileDropScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      DesktopDrop.instance.addRawDropEventListener(_onDropEvent);
    } else if (!widget.enabled && oldWidget.enabled) {
      DesktopDrop.instance.removeRawDropEventListener(_onDropEvent);
      _setDragging(false);
      _dragInBounds = false;
      _pendingDrop = false;
    }
  }

  void _onDropEvent(DropEvent event) {
    if (!widget.enabled) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final globalPosition = _scaleHoverPoint(context, event.location);
    final localPosition = renderBox.globalToLocal(globalPosition);
    final inBounds = renderBox.paintBounds.contains(localPosition);

    if (event is DropEnterEvent) {
      if (inBounds) {
        _dragInBounds = true;
        _setDragging(true);
      }
    } else if (event is DropUpdateEvent) {
      if (inBounds) {
        if (!_dragInBounds) {
          _dragInBounds = true;
          _setDragging(true);
        }
      } else if (_dragInBounds) {
        _dragInBounds = false;
        _setDragging(false);
      }
    } else if (event is DropExitEvent) {
      // macOS may emit exit before async file promises finish; keep session
      // alive until we see DropDoneEvent or a new drag enters.
      _pendingDrop = _dragInBounds;
      _setDragging(false);
    } else if (event is DropDoneEvent) {
      final shouldAccept =
          event.files.isNotEmpty &&
          (inBounds ||
              _dragInBounds ||
              _pendingDrop ||
              _isUnknownDropPoint(event.location));
      _dragInBounds = false;
      _pendingDrop = false;
      _setDragging(false);
      if (shouldAccept) {
        widget.onFilesDropped(event.files);
      }
    }
  }

  bool _isUnknownDropPoint(Offset location) {
    // Async macOS promise drops sometimes arrive with a cleared hover point.
    return UniversalPlatform.isMacOS && location == Offset.zero;
  }

  void _setDragging(bool dragging) {
    widget.onDraggingChanged?.call(dragging);
  }

  @override
  void dispose() {
    if (widget.enabled) {
      DesktopDrop.instance.removeRawDropEventListener(_onDropEvent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Offset _scaleHoverPoint(BuildContext context, Offset point) {
  if (UniversalPlatform.isWindows || UniversalPlatform.isAndroid) {
    final ratio = MediaQuery.of(context).devicePixelRatio;
    return point.scale(1 / ratio, 1 / ratio);
  }
  return point;
}
