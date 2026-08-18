import 'package:objectbox/objectbox.dart';

/// A chunk of the curated, non-diagnostic knowledge base, with its embedding
/// indexed for on-device HNSW nearest-neighbour search (ObjectBox vector DB).
///
/// This store holds ONLY approved educational content — never patient data
/// (that stays in the Drift database). Grounding the assistant on this KB is
/// what keeps its answers inside vetted, non-diagnostic material.
@Entity()
class KbChunk {
  KbChunk({
    this.id = 0,
    required this.lang,
    required this.topic,
    required this.text,
    this.embedding,
  });

  @Id()
  int id;

  /// Language code ('en' / 'hi' / 'ta').
  String lang;

  /// A short topic tag (for display / filtering).
  String topic;

  /// The passage text shown to the model as grounding.
  String text;

  /// The passage embedding. Dimensions must match [Embedder.dim] (256).
  @HnswIndex(dimensions: 256)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;
}
