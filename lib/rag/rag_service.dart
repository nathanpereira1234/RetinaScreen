import 'embedder.dart';
import 'knowledge_base.dart';

/// Retrieval-augmented grounding for the assistant.
///
/// The knowledge base is a small, fixed, curated list, so the "vector store" is
/// simply the embeddings held in memory: [init] embeds every passage once, and
/// [retrieve] does a brute-force cosine top-k. At a few-hundred-passage corpus
/// this is sub-millisecond and needs no database, no native plugin, and no
/// codegen — deliberately chosen after ObjectBox's generator pulled in an
/// analyzer incompatible with Drift's. A real vector DB (ObjectBox HNSW) is the
/// documented upgrade for a large corpus — see docs/RAG.md.
///
/// Non-negotiable: the corpus is curated non-diagnostic content, so grounding
/// keeps the assistant's answers inside vetted material.
class RagService {
  RagService([this.embedder = const LexicalEmbedder()]);

  final Embedder embedder;
  final List<_Indexed> _index = [];
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    for (final e in knowledgeBase) {
      // Embed topic + text so a topical query still matches.
      _index.add(_Indexed(e, embedder.embed('${e.topic} ${e.text}')));
    }
    _ready = true;
  }

  /// Up to [k] relevant passages for [text], preferring [lang] when enough
  /// in-language passages match. Empty when not initialised or nothing matches.
  List<KbEntry> retrieve(String text, {String? lang, int k = 3}) {
    if (!_ready) return const [];
    final queryVec = embedder.embed(text);
    var scored = [
      for (final item in _index)
        (entry: item.entry, score: cosineSimilarity(queryVec, item.vector)),
    ];
    if (lang != null) {
      final inLang = scored.where((s) => s.entry.lang == lang).toList();
      if (inLang.isNotEmpty) scored = inLang;
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [
      for (final s in scored.take(k))
        if (s.score > 0) s.entry,
    ];
  }

  void dispose() {}
}

class _Indexed {
  _Indexed(this.entry, this.vector);
  final KbEntry entry;
  final List<double> vector;
}
