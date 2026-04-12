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

class _GlowingProgressBarState extends State<GlowingProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _previousProgress = widget.progress.clamp(0.0, 1.0);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant GlowingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousProgress = oldWidget.progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = widget.progress.clamp(0.0, 1.0);
    final borderRadius = BorderRadius.circular(widget.height * 2);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        height: widget.height,
        color: widget.backgroundColor,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 320),
          tween: Tween<double>(begin: _previousProgress, end: targetProgress),
          builder: (context, animatedProgress, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final fillWidth = constraints.maxWidth * animatedProgress;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        final shimmer = _glowController.value;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: borderRadius,
                            child: SizedBox(
                              key: widget.fillKey,
                              width: fillWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(-1.4 + (shimmer * 1.8), 0),
                                    end: Alignment(0.8 + (shimmer * 1.8), 0),
                                    colors: [
                                      widget.color.withValues(alpha: 0.86),
                                      Colors.white.withValues(alpha: 0.92),
                                      widget.color,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.color.withValues(
                                        alpha: 0.42,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: SizedBox(height: widget.height),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
