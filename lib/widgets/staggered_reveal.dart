import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  static Key fadeKeyForIndex(int index) => ValueKey<String>('staggered-reveal-fade-$index');
  static Key slideKeyForIndex(int index) => ValueKey<String>('staggered-reveal-slide-$index');

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delayMilliseconds = math.min(widget.index * 55, 230);
    _startTimer = Timer(Duration(milliseconds: delayMilliseconds), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: StaggeredReveal.fadeKeyForIndex(widget.index),
      opacity: _opacity,
      child: SlideTransition(key: StaggeredReveal.slideKeyForIndex(widget.index), position: _slide, child: widget.child),
    );
  }
}
