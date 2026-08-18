import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:retinascreen/services/fundus_ai.dart';

void main() {
  img.Image checkerboard(int seed) {
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final on = (((x + seed) ~/ 8) + (y ~/ 8)).isEven;
        final v = on ? 230 : 15;
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    return image;
  }

  test('perceptual hash is 64 bits and identical images match', () {
    final a = checkerboard(0);
    final h1 = FundusAi.perceptualHash(a);
    final h2 = FundusAi.perceptualHash(a);
    expect(h1, hasLength(64));
    expect(FundusAi.hamming(h1, h2), 0);
    expect(FundusAi.looksDuplicate(h1, h2), isTrue);
  });

  img.Image verticalSplit() {
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final v = x < 32 ? 230 : 15;
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    return image;
  }

  test('a clearly different image has a different hash', () {
    final h1 = FundusAi.perceptualHash(checkerboard(0));
    final h2 = FundusAi.perceptualHash(verticalSplit());
    expect(FundusAi.hamming(h1, h2), greaterThan(FundusAi.duplicateThreshold));
    expect(FundusAi.looksDuplicate(h1, h2), isFalse);
  });

  test('enhance returns an image of the requested size', () {
    final out = FundusAi.enhance(checkerboard(0), size: 64);
    expect(out.width, 64);
    expect(out.height, 64);
  });

  test('bytes helpers return null on undecodable input', () {
    final junk = img.encodePng(img.Image(width: 1, height: 1));
    // A valid tiny PNG decodes; garbage does not.
    expect(FundusAi.perceptualHashBytes(junk), isNotNull);
    expect(FundusAi.enhanceBytes(junk), isNotNull);
  });
}
