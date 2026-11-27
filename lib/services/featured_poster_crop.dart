import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A detection in normalized, top-left-origin coordinates of the poster.
typedef PosterFace = ({
  double left,
  double top,
  double right,
  double bottom,
  double confidence,
});

const _minimumConfidence = 0.45;
const _minimumFaceArea = 0.002;
const _minimumRelativeArea = 0.14;

/// Selects an alignment for [BoxFit.cover] that keeps prominent faces visible.
///
/// Favors the upper area to leave room for the featured card's title and actions.
Alignment featuredPosterAlignment({
  required Size source,
  required Size target,
  required List<PosterFace> faces,
}) {
  if (source.isEmpty ||
      target.isEmpty ||
      !source.isFinite ||
      !target.isFinite) {
    return Alignment.center;
  }
  final prominent = _prominentFaces(faces);
  if (prominent.isEmpty) return Alignment.center;

  final heightAtCardWidth = target.width * source.height / source.width;
  if (heightAtCardWidth > target.height) {
    final extraHeight = heightAtCardWidth - target.height;
    if (extraHeight <= 0.001 || !extraHeight.isFinite) return Alignment.center;

    final start = _bestStart(
      spans: [
        for (final face in prominent)
          (
            start: face.bounds.top * heightAtCardWidth,
            end: face.bounds.bottom * heightAtCardWidth,
            weight: face.weight,
          ),
      ],
      length: target.height,
      extra: extraHeight,
      safeStart: target.height * 0.06,
      safeEnd: target.height * 0.56,
      targetCenter: target.height * 0.36,
    );
    return Alignment(0, 2 * start / extraHeight - 1);
  }

  final widthAtCardHeight = target.height * source.width / source.height;
  final extraWidth = widthAtCardHeight - target.width;
  if (extraWidth <= 0.001 || !extraWidth.isFinite) return Alignment.center;

  final start = _bestStart(
    spans: [
      for (final face in prominent)
        (
          start: face.bounds.left * widthAtCardHeight,
          end: face.bounds.right * widthAtCardHeight,
          weight: face.weight,
        ),
    ],
    length: target.width,
    extra: extraWidth,
    safeStart: target.width * 0.05,
    safeEnd: target.width * 0.95,
    targetCenter: target.width * 0.50,
  );
  return Alignment(2 * start / extraWidth - 1, 0);
}

typedef _WeightedFace = ({Rect bounds, double area, double weight});
typedef _Span = ({double start, double end, double weight});

List<_WeightedFace> _prominentFaces(List<PosterFace> detections) {
  final faces = <_WeightedFace>[];
  var largestArea = 0.0;
  for (final face in detections) {
    if (!face.confidence.isFinite ||
        face.confidence < _minimumConfidence ||
        !face.left.isFinite ||
        !face.top.isFinite ||
        !face.right.isFinite ||
        !face.bottom.isFinite) {
      continue;
    }
    final bounds = Rect.fromLTRB(
      _bounded(face.left, 1),
      _bounded(face.top, 1),
      _bounded(face.right, 1),
      _bounded(face.bottom, 1),
    );
    final area = bounds.width * bounds.height;
    if (bounds.isEmpty || area < _minimumFaceArea) continue;

    final confidence = math.min(face.confidence, 1.0);
    final weight = math.sqrt(area) * confidence * confidence;
    faces.add((bounds: bounds, area: area, weight: weight));
    largestArea = math.max(largestArea, area);
  }
  final minimumArea = largestArea * _minimumRelativeArea;
  return faces.where((face) => face.area >= minimumArea).toList();
}

double _bestStart({
  required List<_Span> spans,
  required double length,
  required double extra,
  required double safeStart,
  required double safeEnd,
  required double targetCenter,
}) {
  final centered = extra / 2;
  final candidates = <double>{0, centered, extra};
  final edges = [0.0, safeStart, safeEnd, length];
  for (final span in spans) {
    // The scores are linear between the offsets that align these edges.
    for (final edge in edges) {
      candidates.add(_bounded(span.start - edge, extra));
      candidates.add(_bounded(span.end - edge, extra));
    }
    candidates.add(_bounded((span.start + span.end) / 2 - targetCenter, extra));
  }

  final totalWeight = spans.fold<double>(0, (sum, span) => sum + span.weight);
  var bestStart = centered;
  var bestScore = double.negativeInfinity;
  for (final start in candidates) {
    var tally = 0.0;
    for (final span in spans) {
      final visible = _overlap(span, start, start + length);
      final clear = _overlap(span, start + safeStart, start + safeEnd);
      final center = (span.start + span.end) / 2;
      final placement = (center - start - targetCenter).abs() / length;
      tally += span.weight * (3 * visible + 1.25 * clear - 0.45 * placement);
    }
    final distance = (start - centered).abs();
    final score = tally / totalWeight - 0.12 * distance / length;
    final tied = (score - bestScore).abs() <= 1e-9;
    final bestDistance = (bestStart - centered).abs();
    if (score > bestScore + 1e-9 ||
        tied &&
            (distance < bestDistance ||
                distance == bestDistance && start < bestStart)) {
      bestScore = score;
      bestStart = start;
    }
  }
  return bestStart;
}

double _overlap(_Span span, double start, double end) {
  final overlap = math.max(
    0.0,
    math.min(end, span.end) - math.max(start, span.start),
  );
  return overlap / (span.end - span.start);
}

double _bounded(double value, double max) =>
    math.max(0.0, math.min(value, max));
