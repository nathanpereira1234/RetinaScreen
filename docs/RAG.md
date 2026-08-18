# On-device RAG (grounded assistant)

The assistant is grounded with **retrieval-augmented generation**, fully
on-device. Instead of the 1B model answering from its own memory, it answers
from a **curated, non-diagnostic knowledge base** — which makes it both more
accurate and safer (answers come from vetted patient-education content, never an
open-ended model opinion, never a diagnosis).

## Pipeline

```
question ─▶ Embedder ─▶ ObjectBox HNSW (vector search) ─▶ top-k passages
                                                              │
                          ┌───────────────────────────────────┘
                          ▼
        grounded prompt ("use ONLY this approved info") ─▶ Gemma ─▶ answer
```

- **Knowledge base** — `lib/rag/knowledge_base.dart`. Curated passages (en/hi/ta)
  on what results mean, preparing for the eye visit, why attending matters,
  diabetic eye care. **This file is the safety boundary — edit it to curate what
  the assistant can say.**
- **Embedder** — `lib/rag/embedder.dart`. Ships `LexicalEmbedder` (pure Dart,
  feature-hashing, no model). Real *semantic* retrieval is a drop-in — see below.
- **Vector store** — `lib/rag/kb_chunk.dart` (`@Entity` with an
  `@HnswIndex(dimensions: 256)` float-vector) + `rag_service.dart` (ObjectBox).
  Seeded from the KB on first run; separate from the Drift patient DB; degrades
  gracefully (`isReady == false`) if it can't open.
- **Grounding** — `GemmaAssistant.ask` prepends retrieved passages with a
  "use ONLY this approved information" instruction. The `TemplateAssistant`
  returns the retrieved passage directly, so retrieval helps even without the
  LLM.

## Build / run

`objectbox` + `objectbox_flutter_libs` are dependencies; `objectbox_generator`
generates `lib/objectbox.g.dart` (+ `objectbox-model.json`) during
`dart run build_runner build`. It's a native plugin — validate the Gradle build
on a device. No extra Android setup beyond the defaults.

## Upgrade to semantic embeddings (MiniLM)

`LexicalEmbedder` matches on shared words — good for a small FAQ, but it doesn't
understand paraphrase. For true semantic retrieval, drop in a sentence embedder
(e.g. **all-MiniLM-L6-v2**, 384-dim):

1. Convert MiniLM to TFLite and bundle it (like the DR model) — include the
   WordPiece vocab.
2. Implement `TfliteEmbedder implements Embedder` (`dim => 384`): WordPiece-
   tokenize → run the model via `tflite_flutter` → mean-pool the token
   embeddings → L2-normalise.
3. Set the entity's `@HnswIndex(dimensions: 384)` to match and bump the KB store
   name (so it re-seeds with the new vectors).
4. Pass your embedder to `RagService(TfliteEmbedder())` in `ragServiceProvider`.

Everything else — the ObjectBox index, retrieval, grounding — is unchanged;
only the `Embedder` implementation swaps.

> On-device text embedding is the genuinely fiddly part (tokenizer + TF ops).
> The lexical embedder ships working retrieval today; MiniLM upgrades quality
> when you're ready.
