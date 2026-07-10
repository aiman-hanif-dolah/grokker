import 'package:flutter/material.dart';

import '../../styles/design_tokens.dart';
import '../../styles/grokker_typography.dart';

class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.label,
    this.pulse = false,
  });

  final Color color;
  final String? label;
  final bool pulse;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.pulse) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final scale = 1.0 + (_controller.value * 1.2);
                    final opacity = 1.0 - _controller.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: opacity * 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: GrokkerShadows.glow(widget.color, blur: 6),
                ),
              ),
            ],
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(width: GrokkerSpacing.s8),
          Text(
            widget.label!,
            style: GrokkerTypography.caption(color: GrokkerColors.fog),
          ),
        ],
      ],
    );
  }
}
