import 'package:material_ui/material_ui.dart';

class GlowingProgressBar extends StatelessWidget {
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

  static const _animationDuration = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetProgress = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final progressColor = color ?? colorScheme.primary;
    final trackColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fill = ColoredBox(key: fillKey, color: progressColor);

    Widget alignFill(double fraction, Widget? child) {
      return FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fraction,
        heightFactor: 1,
        child: child,
      );
    }

    return Semantics(
      label: 'Download progress',
      value: '${(targetProgress * 100).round()}%',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ColoredBox(
          color: trackColor,
          child: MediaQuery.disableAnimationsOf(context)
              ? alignFill(targetProgress, fill)
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: targetProgress),
                  duration: _animationDuration,
                  curve: Curves.easeOut,
                  builder: (_, fraction, child) => alignFill(fraction, child),
                  child: fill,
                ),
        ),
      ),
    );
  }
}
