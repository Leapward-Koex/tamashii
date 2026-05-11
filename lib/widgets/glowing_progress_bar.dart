import 'package:flutter/material.dart';

class GlowingProgressBar extends StatefulWidget {
  const GlowingProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color = const Color(0xFF68F0FF),
    this.backgroundColor = const Color(0x1FFFFFFF),
    this.fillKey,
  });

  final double progress;
  final double height;
  final Color color;
  final Color backgroundColor;
  final Key? fillKey;

  @override
  State<GlowingProgressBar> createState() => _GlowingProgressBarState();
}

class _GlowingProgressBarState extends State<GlowingProgressBar> {
  static const _animationDuration = Duration(milliseconds: 260);

  double _normalizedProgress(double progress) {
    if (!progress.isFinite) return 0;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = _normalizedProgress(widget.progress);
    final borderRadius = BorderRadius.circular(widget.height * 2);

    return Semantics(
      value: '${(targetProgress * 100).round()}%',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: widget.height,
          color: widget.backgroundColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * targetProgress;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: AnimatedContainer(
                        key: widget.fillKey,
                        duration: _animationDuration,
                        curve: Curves.easeOutCubic,
                        width: fillWidth,
                        height: widget.height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withValues(alpha: 0.78),
                              Colors.white.withValues(alpha: 0.9),
                              widget.color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.36),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
