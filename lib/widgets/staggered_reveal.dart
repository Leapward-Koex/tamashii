import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 0.08),
  });

  final int index;
  final Duration duration;
  final Offset offset;
  final Widget child;

  static Key fadeKeyForIndex(int index) =>
      ValueKey<String>('staggered-reveal-fade-$index');
  static Key slideKeyForIndex(int index) =>
      ValueKey<String>('staggered-reveal-slide-$index');

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _opacity;
  late final Animation<Offset> _slide;
  Timer? _startTimer;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_initialized) {
      if (reduceMotion) {
        _startTimer?.cancel();
        _controller?.value = 1;
      }
      return;
    }
    _initialized = true;

    final scrollPosition = Scrollable.maybeOf(context)?.position;
    if (reduceMotion || (scrollPosition?.isScrollingNotifier.value ?? false)) {
      return;
    }

    final controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final opacity = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    _controller = controller;
    _opacity = opacity;
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(opacity);
    final delayMilliseconds = math.min(widget.index * 55, 230);
    if (delayMilliseconds <= 0) {
      controller.forward();
    } else {
      _startTimer = Timer(
        Duration(milliseconds: delayMilliseconds),
        controller.forward,
      );
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _opacity?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity;
    if (opacity == null) {
      return widget.child;
    }
    return FadeTransition(
      key: StaggeredReveal.fadeKeyForIndex(widget.index),
      opacity: opacity,
      child: SlideTransition(
        key: StaggeredReveal.slideKeyForIndex(widget.index),
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
