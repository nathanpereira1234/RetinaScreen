import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:retinascreen/services/fundus_quality.dart';

void main() {
  img.Image solid(int v) {
    final image = img.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    return image;
  }

  img.Image checkerboard() {
    final image = img.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final on = ((x ~/ 8) + (y ~/ 8)).isEven;
        final v = on ? 220 : 20;
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    return image;
  }

  test('a black frame is poor: too dark + low field', () {
    final q = FundusQuality.assess(solid(0));
    expect(q.verdict, FundusVerdict.poor);
    expect(q.issues, contains(FundusIssue.tooDark));
    expect(q.issues, contains(FundusIssue.lowField));
    expect(q.isGradable, isFalse);
  });

  test('a flat mid-grey frame is poor: blurry (no detail)', () {
    final q = FundusQuality.assess(solid(127));
    expect(q.issues, contains(FundusIssue.blurry));
    expect(q.verdict, FundusVerdict.poor);
  });

  test('a fully bright frame is poor: too bright', () {
    final q = FundusQuality.assess(solid(240));
    expect(q.issues, contains(FundusIssue.tooBright));
    expect(q.verdict, FundusVerdict.poor);
  });

  test('a sharp, well-exposed, full-field frame is good', () {
    final q = FundusQuality.assess(checkerboard());
    expect(q.issues, isEmpty);
    expect(q.verdict, FundusVerdict.good);
    expect(q.isGradable, isTrue);
    expect(q.score, greaterThan(0.6));
  });

  test('assessBytes returns null on undecodable bytes', () {
    expect(FundusQuality.assessBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
