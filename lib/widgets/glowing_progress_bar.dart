import 'package:flutter/material.dart';

class GlowingProgressBar extends StatefulWidget {
  const GlowingProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color,
    this.backgroundColor,
    this.fillKey,
  });

  final double progress;
  final double height;
  final Color? color;
  final Color? backgroundColor;
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
    final colorScheme = Theme.of(context).colorScheme;
    final targetProgress = _normalizedProgress(widget.progress);
    final borderRadius = BorderRadius.circular(widget.height * 2);
    final progressColor = widget.color ?? colorScheme.primary;
    final accentColor = Color.lerp(progressColor, colorScheme.tertiary, 0.34)!;
    final trackColor =
        widget.backgroundColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);

    return Semantics(
      value: '${(targetProgress * 100).round()}%',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          height: widget.height,
          color: trackColor,
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
                              Color.lerp(progressColor, Colors.black, 0.08)!,
                              progressColor,
                              accentColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: progressColor.withValues(alpha: 0.22),
                              blurRadius: 8,
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
