import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../objectbox.g.dart';
import 'embedder.dart';
import 'kb_chunk.dart';
import 'knowledge_base.dart';

/// Retrieval-augmented grounding for the assistant.
///
/// Opens a small ObjectBox vector store (separate from the Drift patient DB),
/// seeds it from the curated [knowledgeBase] on first run, and answers
/// [retrieve] with the nearest passages via ObjectBox's on-device HNSW index.
///
/// Everything degrades gracefully: if the store can't open (unsupported device,
/// tests), [isReady] is false and [retrieve] returns nothing — the assistant
/// then answers without grounding rather than crashing.
class RagService {
  RagService([this.embedder = const LexicalEmbedder()]);

  final Embedder embedder;

  Store? _store;
  Box<KbChunk>? _box;
  bool _tried = false;

  bool get isReady => _box != null;

  Future<void> init() async {
    if (_tried) return;
    _tried = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _store = await openStore(directory: p.join(dir.path, 'kb-vectors'));
      final box = _store!.box<KbChunk>();
      _box = box;
      if (box.isEmpty()) _seed(box);
    } catch (_) {
      _store = null;
      _box = null;
    }
  }

  void _seed(Box<KbChunk> box) {
    box.putMany([
      for (final e in knowledgeBase)
        KbChunk(
          lang: e.lang,
          topic: e.topic,
          text: e.text,
          // Embed topic + text so a topical query still matches.
          embedding: embedder.embed('${e.topic} ${e.text}'),
        ),
    ]);
  }

  /// Up to [k] relevant passages for [text], preferring [lang] when enough
  /// in-language passages are found. Empty when the store isn't ready.
  List<KbChunk> retrieve(String text, {String? lang, int k = 3}) {
    final box = _box;
    if (box == null) return const [];
    final queryVec = embedder.embed(text);
    final query =
        box.query(KbChunk_.embedding.nearestNeighborsF32(queryVec, k * 4)).build();
    try {
      var chunks = query.findWithScores().map((s) => s.object).toList();
      if (lang != null) {
        final inLang = chunks.where((c) => c.lang == lang).toList();
        if (inLang.isNotEmpty) chunks = inLang;
      }
      return chunks.take(k).toList();
    } finally {
      query.close();
    }
  }

  void dispose() {
    _store?.close();
    _store = null;
    _box = null;
  }
}
