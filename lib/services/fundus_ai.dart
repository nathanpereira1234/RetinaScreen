import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// On-device image AI for the fundus flow — all pure `image`-package maths, no
/// model and no network:
/// - [perceptualHash] / [hamming]: catch a photo reused across patients.
/// - [enhance]: Ben-Graham retinal preprocessing (crop-to-fundus + local
///   contrast) that makes any downstream grader more accurate and gives the
///   worker a clearer "enhanced view".
///
/// None of this is a clinical judgement. Unit-tested in
/// `test/fundus_ai_test.dart`.
class FundusAi {
  const FundusAi();

  // --- Perceptual hash (aHash, 64-bit as 64 bools) ---

  static List<bool> perceptualHash(img.Image image) {
    final small = img.copyResize(image, width: 8, height: 8);
    final lum = <double>[];
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final p = small.getPixel(x, y);
        lum.add(0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
      }
    }
    final mean = lum.reduce((a, b) => a + b) / lum.length;
    return [for (final v in lum) v >= mean];
  }

  static List<bool>? perceptualHashBytes(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    return decoded == null ? null : perceptualHash(decoded);
  }

  /// Number of differing bits between two hashes (0 = identical). Hashes must be
  /// the same length.
  static int hamming(List<bool> a, List<bool> b) {
    final n = a.length < b.length ? a.length : b.length;
    var d = 0;
    for (var i = 0; i < n; i++) {
      if (a[i] != b[i]) d++;
    }
    return d;
  }

  /// Two 64-bit hashes within this distance are "the same image".
  static const int duplicateThreshold = 6;

  static bool looksDuplicate(List<bool> a, List<bool> b) =>
      hamming(a, b) <= duplicateThreshold;

  // --- Ben-Graham retinal preprocessing ---

  /// Crop to the fundus disc, resize, and apply local-average contrast:
  /// `out = clip(4*(pixel - blur) + 128)`, then a circular mask. Returns a new
  /// image of [size] x [size].
  static img.Image enhance(img.Image src, {int size = 512}) {
    final cropped = _cropToFundus(src);
    final resized = img.copyResize(cropped, width: size, height: size);
    final blurred = img.gaussianBlur(
      img.Image.from(resized),
      radius: (size * 0.05).round().clamp(1, 40),
    );
    final out = img.Image(width: size, height: size);
    final cx = size / 2, cy = size / 2, r = size / 2 * 0.95;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > r * r) {
          out.setPixelRgb(x, y, 0, 0, 0); // mask outside the disc
          continue;
        }
        final p = resized.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          _clip(4 * (p.r - b.r) + 128),
          _clip(4 * (p.g - b.g) + 128),
          _clip(4 * (p.b - b.b) + 128),
        );
      }
    }
    return out;
  }

  /// Decode, enhance, and re-encode as PNG. Null on undecodable input.
  static Uint8List? enhanceBytes(Uint8List bytes, {int size = 512}) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) return null;
    return img.encodePng(enhance(decoded, size: size));
  }

  static int _clip(num v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

  /// Bounding box of the non-black region (the illuminated fundus). Falls back
  /// to the whole frame when the image is essentially uniform.
  static img.Image _cropToFundus(img.Image src) {
    var minX = src.width, minY = src.height, maxX = 0, maxY = 0;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (l > 24) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX <= minX || maxY <= minY) return src;
    return img.copyCrop(
      src,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }
}
