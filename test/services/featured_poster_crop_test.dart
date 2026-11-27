import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/featured_poster_crop.dart';

const _portrait = Size(400, 600);
const _card = Size(996, 851);

void main() {
  test('centers when there are no usable face detections', () {
    expect(_alignment([]), Alignment.center);
    expect(
      _alignment([
        _face(.10, .10, .30, .30, .20),
        _face(.10, .10, .12, .12),
        _face(.15, double.negativeInfinity, .40, .90),
      ]),
      Alignment.center,
    );
  });

  test('centers when dimensions are unavailable or no cropping is needed', () {
    final faces = [_face(.30, .10, .56, .24)];
    expect(
      featuredPosterAlignment(source: Size.zero, target: _card, faces: faces),
      Alignment.center,
    );
    expect(
      featuredPosterAlignment(
        source: _portrait,
        target: const Size(double.infinity, 300),
        faces: faces,
      ),
      Alignment.center,
    );
    expect(
      featuredPosterAlignment(
        source: _portrait,
        target: const Size(200, 300),
        faces: faces,
      ),
      Alignment.center,
    );
  });

  test('a face clipped by the centered crop becomes fully visible', () {
    final face = _face(.30, .10, .56, .24);
    final alignment = _alignment([face]);
    final centered = _renderedFace(face, Alignment.center);
    final adjusted = _renderedFace(face, alignment);

    expect(centered.top, lessThan(0));
    expect(adjusted.top, greaterThan(_card.height * .06));
    expect(adjusted.bottom, lessThanOrEqualTo(_card.height * .56));
    expect(adjusted.height, closeTo(centered.height, .001));
  });

  test('keeps both prominent faces above the content when they fit', () {
    final first = _face(.16, .34, .36, .48, .90);
    final second = _face(.54, .44, .74, .59, .92);
    final alignment = _alignment([first, second]);

    expect(
      _renderedFace(first, alignment).top,
      greaterThanOrEqualTo(_card.height * .06 - .01),
    );
    expect(
      _renderedFace(second, alignment).bottom,
      lessThanOrEqualTo(_card.height * .56 + .01),
    );
    expect(alignment, _alignment([second, first]));
  });

  test('ignores a tiny detection far from the main face', () {
    final main = _face(.35, .35, .65, .58, .83);
    final tiny = _face(.08, .88, .13, .94, .99);
    expect(_alignment([main, tiny]), _alignment([main]));
  });

  test('keeps a low face in frame when it cannot clear the overlay', () {
    final face = _face(.30, .74, .60, .98);
    final adjusted = _renderedFace(face, _alignment([face]));

    expect(adjusted.top, greaterThanOrEqualTo(0));
    expect(adjusted.bottom, lessThanOrEqualTo(_card.height));
  });

  test('a landscape source can preserve a face near the left edge', () {
    const landscape = Size(1200, 400);
    final face = _face(.07, .34, .18, .62);
    final alignment = featuredPosterAlignment(
      source: landscape,
      target: _card,
      faces: [face],
    );
    final adjusted = _renderedFace(face, alignment, source: landscape);

    expect(alignment.y, 0);
    expect(adjusted.left, greaterThan(0));
    expect(adjusted.right, lessThan(_card.width));
  });
}

Alignment _alignment(List<PosterFace> faces) =>
    featuredPosterAlignment(source: _portrait, target: _card, faces: faces);

Rect _renderedFace(
  PosterFace face,
  Alignment alignment, {
  Size source = _portrait,
}) {
  final fit = applyBoxFit(BoxFit.cover, source, _card);
  final crop = alignment.inscribe(fit.source, Offset.zero & source);
  final scale = fit.destination.width / crop.width;
  return Rect.fromLTRB(
    (face.left * source.width - crop.left) * scale,
    (face.top * source.height - crop.top) * scale,
    (face.right * source.width - crop.left) * scale,
    (face.bottom * source.height - crop.top) * scale,
  );
}

PosterFace _face(
  double left,
  double top,
  double right,
  double bottom, [
  double confidence = .95,
]) => (
  left: left,
  top: top,
  right: right,
  bottom: bottom,
  confidence: confidence,
);
