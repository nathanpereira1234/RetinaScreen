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
- **Vector store** — `lib/rag/rag_service.dart`. The KB is a small fixed list,
  so the store is just the embeddings held in memory: embed every passage once
  at `init()`, then brute-force cosine top-k per query (sub-millisecond at this
  scale). No database, no native plugin, no codegen.
  > Originally built on ObjectBox HNSW, but its code generator pulled in an
  > `analyzer` version incompatible with Drift's `source_gen`, breaking
  > `build_runner`. The in-memory index is equivalent at a few-hundred-passage
  > corpus; a real vector DB (ObjectBox HNSW / `sqlite-vec`) is the upgrade for a
  > large corpus — swap only `RagService`'s storage, the rest is unchanged.
- **Grounding** — `GemmaAssistant.ask` prepends retrieved passages with a
  "use ONLY this approved information" instruction. The `TemplateAssistant`
  returns the retrieved passage directly, so retrieval helps even without the
  LLM.

## Build / run

Nothing extra — the in-memory store adds no dependency, no native plugin, and no
codegen. RAG works as soon as the app runs (with the lexical embedder); the
answer quality upgrades when you drop in the Gemma model and/or the MiniLM
embedder.

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
