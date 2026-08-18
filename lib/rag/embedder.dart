import 'dart:math' as math;

/// Turns text into a fixed-length vector for retrieval.
///
/// Two implementations: [LexicalEmbedder] (shipped — pure Dart, no model,
/// keyword/feature-hashing retrieval) and a documented MiniLM TFLite embedder
/// for real *semantic* retrieval (see docs/RAG.md). Both produce [dim]-length
/// L2-normalised vectors, so cosine similarity is just a dot product and the
/// same ObjectBox HNSW index works for either.
abstract class Embedder {
  int get dim;
  List<double> embed(String text);
}

/// A model-free embedder: signed feature-hashing of word tokens into a fixed
/// vector. It captures lexical overlap (shared words → closer vectors), which
/// is enough to retrieve the right passage from a small curated FAQ. Swap in
/// the MiniLM embedder for true semantic matching.
class LexicalEmbedder implements Embedder {
  const LexicalEmbedder([this._dim = 256]);

  final int _dim;

  @override
  int get dim => _dim;

  @override
  List<double> embed(String text) {
    final vec = List<double>.filled(_dim, 0);
    for (final token in _tokenize(text)) {
      final h = token.hashCode;
      final idx = h.abs() % _dim;
      // Signed hashing reduces collisions cancelling systematically.
      vec[idx] += (h & 1) == 0 ? 1.0 : -1.0;
    }
    return _l2normalize(vec);
  }

  /// Split on non-word characters, keeping Latin, Devanagari (Hindi) and Tamil
  /// letters so hi/ta content tokenises too. Drops 1-char tokens.
  static Iterable<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9ऀ-ॿ஀-௿]+'))
      .where((w) => w.length > 1);

  static List<double> _l2normalize(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    return [for (final x in v) x / norm];
  }
}

/// Cosine similarity of two equal-length vectors (a dot product when both are
/// L2-normalised). Exposed for tests and non-ObjectBox fallbacks.
double cosineSimilarity(List<double> a, List<double> b) {
  final n = a.length < b.length ? a.length : b.length;
  var dot = 0.0;
  for (var i = 0; i < n; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}
