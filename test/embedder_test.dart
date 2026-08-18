import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/rag/embedder.dart';

void main() {
  const embedder = LexicalEmbedder(256);

  double norm(List<double> v) {
    var s = 0.0;
    for (final x in v) {
      s += x * x;
    }
    return math.sqrt(s);
  }

  test('embeddings are the right length and L2-normalised', () {
    final v = embedder.embed('prepare for the eye appointment');
    expect(v, hasLength(256));
    expect(norm(v), closeTo(1.0, 1e-6));
  });

  test('empty / token-less text yields a zero vector safely', () {
    final v = embedder.embed('   ');
    expect(v, hasLength(256));
    expect(norm(v), 0.0);
  });

  test('overlapping text is more similar than unrelated text', () {
    final a = embedder.embed('how do I prepare for my eye appointment');
    final b = embedder.embed('what should I bring to the eye appointment');
    final c = embedder.embed('blood sugar and cholesterol control diabetes');
    expect(
      cosineSimilarity(a, b),
      greaterThan(cosineSimilarity(a, c)),
    );
  });

  test('identical text is maximally similar (cosine ~1)', () {
    final a = embedder.embed('attend the referral clinic');
    final b = embedder.embed('attend the referral clinic');
    expect(cosineSimilarity(a, b), closeTo(1.0, 1e-6));
  });
}
