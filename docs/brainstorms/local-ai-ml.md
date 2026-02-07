# Local AI/ML Approaches for Email Client on Mac Mini Hub

## Brainstorm Document

**Date:** 2026-02-06
**Context:** Research into local, privacy-preserving AI/ML approaches for an email client where a Mac Mini (Apple Silicon) runs 24/7 as the AI processing hub. The system must classify emails, extract recommendations from newsletters, and generate daily digests -- all without cloud AI APIs.

---

> **⚠️ Architecture Update**: This document was written before the final architecture was decided. The server is now **Go** (not Swift), and LLM inference uses **Ollama** (not MLX). The classification cascade concepts, prompt design, recommendation extraction approaches, and performance analysis in this document remain valid — but references to MLX, Core ML, Swift-native inference, and Apple's NaturalLanguage framework should be read as historical research. The Go server calls Ollama via HTTP API, with a swappable interface to support Anthropic/OpenAI for hosted deployments. See `go-server-architecture.md` for the current design.

---

## Table of Contents

1. [Local LLM Options for Mac](#1-local-llm-options-for-mac)
2. [Core ML for Classification](#2-core-ml-for-classification)
3. [Email Classification Approaches](#3-email-classification-approaches)
4. [Recommendation Extraction](#4-recommendation-extraction)
5. [Digest Generation](#5-digest-generation)
6. [Performance and Resource Considerations](#6-performance-and-resource-considerations)
7. [MLX Framework Deep Dive](#7-mlx-framework-deep-dive)
8. [Hybrid Approaches](#8-hybrid-approaches)
9. [Recommended Architecture](#9-recommended-architecture)
10. [Open Questions and Next Steps](#10-open-questions-and-next-steps)

---

## 1. Local LLM Options for Mac

### Inference Frameworks

There are five primary frameworks for running local LLMs on Apple Silicon, each with distinct trade-offs.

#### MLX (Apple's Framework)

- **What it is:** Apple's open-source array framework purpose-built for Apple Silicon ML workloads. Uses Metal for GPU acceleration and leverages unified memory for zero-copy tensor operations between CPU and GPU.
- **Language support:** C, C++, Python, and Swift APIs. First-class Swift support is critical for our native macOS app.
- **Performance:** Highest sustained generation throughput on Apple Silicon. Benchmarks show approximately 230 tokens/sec with 5-7ms per-token latency and approximately 12ms P99 latency. This is roughly 50% faster than llama.cpp on the same hardware.
- **Why it wins for us:** Native Swift API, best Apple Silicon optimization, zero-copy unified memory, built-in quantization, and LoRA fine-tuning support. Apple signaled at WWDC 2025 that MLX is a strategic component of the ecosystem.
- **Quantization:** Built-in 4-bit quantization with minimal accuracy loss and up to 3.5x reduction in memory usage. Supports mixed-precision strategies (different precision per layer).
- **Model ecosystem:** Thousands of models on Hugging Face in MLX format, including Llama, Qwen, Mistral, Phi, and others.

#### llama.cpp

- **What it is:** C/C++ inference engine with Metal backend for Apple Silicon. Very mature, huge community.
- **Performance:** Approximately 150 tokens/sec on Apple Silicon (short context). Roughly 60-120 tokens/sec for 7-8B models on M3/M4 Macs.
- **Strengths:** GGUF model format is the most widely supported quantization format. Excellent grammar-based constrained output (GBNF) for structured JSON generation. Huge model ecosystem.
- **Weaknesses vs MLX:** 20-50% lower throughput on Apple Silicon due to memory transfer overhead in the Metal backend. MLX's lazy evaluation and operation fusion give it an edge.
- **Still relevant because:** Grammar-constrained output (GBNF) for guaranteed JSON is extremely mature and battle-tested. If MLX's structured output story is weaker, llama.cpp may be needed for extraction tasks.

#### Ollama

- **What it is:** Developer-friendly wrapper around llama.cpp with a REST API. Easy model management and downloading.
- **Performance:** 20-40 tokens/sec (significantly slower than raw llama.cpp or MLX due to overhead).
- **Strengths:** Dead simple to get running, great for prototyping. REST API makes it easy to integrate from any language.
- **Weaknesses:** Lags in throughput and TTFT. Running natively on Mac is 5-6x faster than running through Docker. Not ideal for production continuous processing.
- **Role for us:** Excellent for initial prototyping and model evaluation. Could serve as a fallback REST API if we want to decouple the LLM from the Swift app process.

#### LM Studio

- **What it is:** Desktop app with a GUI for running local models. Also provides a local API server.
- **Strengths:** Easy model discovery and downloading. Good for non-technical evaluation of models.
- **Weaknesses:** GUI app is overhead for a headless server use case. Not ideal for programmatic integration.
- **Role for us:** Useful during model evaluation phase only. Not a production component.

#### MLC-LLM

- **What it is:** Machine Learning Compilation framework. Compiles models for efficient deployment.
- **Performance:** Approximately 190 tokens/sec with approximately 13ms P99 latency. Delivers the best time-to-first-token (TTFT) for moderate prompt sizes.
- **Strengths:** Paged KV cache provides robust scaling for extended contexts (32k-128k tokens). Strong out-of-the-box inference features.
- **Weaknesses:** Smaller community than MLX or llama.cpp. Less Swift integration.

### Model Families for Our Tasks

#### For Classification (Small, Fast Models)

| Model | Parameters | Quantized Size | Speed (M4) | Notes |
|-------|-----------|---------------|-------------|-------|
| Qwen2.5-0.5B | 0.5B | ~350MB | Very fast | Smallest viable option, good for simple classification |
| Qwen2.5-1.5B | 1.5B | ~1GB | Very fast | Sweet spot for classification tasks |
| Phi-4-mini | 3.8B | ~2.5GB | Fast | Strong accuracy for size, good reasoning |
| Llama 3.2-1B | 1B | ~700MB | Very fast | Optimized for edge deployment |
| Llama 3.2-3B | 3B | ~2GB | Fast | Good balance of speed and capability |

**Recommendation:** Qwen2.5-1.5B or Llama 3.2-3B for the primary classifier. Both are fast enough for real-time email processing and small enough to leave headroom for other tasks.

#### For Extraction and Summarization (Larger, More Capable Models)

| Model | Parameters | Quantized Size | Speed (M4 Pro, 24GB) | Notes |
|-------|-----------|---------------|----------------------|-------|
| Qwen2.5-7B | 7B | ~4.5GB | 18-22 tok/s | Strong general capability |
| Llama 3.1-8B | 8B | ~5GB | 18-22 tok/s | Good instruction following |
| Mistral-7B | 7B | ~4.5GB | 18-22 tok/s | Strong structured output |
| Qwen2.5-14B | 14B | ~9GB | 20-24 tok/s (24GB) | Best quality, needs 24GB+ |

**Recommendation:** Qwen2.5-7B (4-bit) as the primary extraction/summarization model. It fits comfortably in memory alongside the classifier and leaves room for the OS and app.

#### Fine-tuned vs General Models

**For classification:** A fine-tuned small model (1.5-3B) will dramatically outperform a prompted general model. Research consistently shows that fine-tuned small LLMs significantly outperform zero-shot generative AI models for text classification tasks. A fine-tuned Qwen2.5-1.5B could match or beat a prompted 7B model on our specific classification task while running 5-10x faster.

**For extraction:** General models with good prompting are likely sufficient. The extraction task is varied enough (books, movies, articles, podcasts) that fine-tuning would need a large diverse dataset. Better to use a capable 7B model with structured output constraints.

**For summarization:** General models with templates. Summarization is a core capability of any instruction-tuned model. A 7B model with a good prompt template will handle this well.

---

## 2. Core ML for Classification

### Overview

Core ML is Apple's framework for deploying ML models on Apple devices. For our email classifier, there are two distinct approaches: using Create ML to train a traditional text classifier, or converting a transformer model to Core ML format.

### Approach A: Create ML Text Classifier (MLTextClassifier)

**What it is:** Apple's built-in tool for training text classification models. Available as a framework (trainable in Swift code) and as a macOS app (Create ML GUI).

**How it works:**
1. Prepare labeled data as CSV or JSON: `{"text": "Can you review this by Friday?", "label": "action"}`
2. Train using `MLTextClassifier` with specified text and label columns
3. Export as `.mlmodel` file
4. Import into Xcode project
5. Run inference with a few lines of Swift code

**Algorithms supported:**
- Transfer Learning (default, recommended): Leverages pre-built text embeddings trained on large datasets. Only needs a small labeled dataset (hundreds to low thousands of examples).
- Maximum Entropy
- Conditional Random Field
- Support Vector Machine

**Strengths:**
- Extremely fast inference (microseconds to low milliseconds per classification)
- Tiny model size (a few MB)
- Native Swift integration, no external dependencies
- Runs on Neural Engine for efficiency
- Transfer learning means we need relatively little training data

**Weaknesses:**
- Bag-of-words representation loses word order and context
- Limited understanding of nuanced email content
- No access to email metadata (headers, sender patterns) unless engineered as text features
- Binary or multi-class only -- not great for nuanced confidence scoring

**Training data requirements:**
- Minimum: ~100 examples per category (4 categories = ~400 total)
- Recommended: 500-1000+ examples per category for good accuracy
- Format: 80/20 train/test split
- Data can come from manually labeled emails during the training period

### Approach B: Convert Transformer to Core ML (DistilBERT/BERT)

**What it is:** Train or fine-tune a transformer-based classifier in Python, then convert to Core ML format using `coremltools` for deployment in the Swift app.

**Process:**
1. Fine-tune DistilBERT on labeled email data using Hugging Face Transformers (Python)
2. Convert to Core ML using `coremltools` or the Hugging Face `exporters` package
3. Deploy the `.mlmodel` in the Swift app
4. Run inference using Core ML runtime

**Why DistilBERT:**
- 40% smaller and 45% faster than BERT while retaining 96-97% of language understanding
- Ideal for on-device deployment with constrained resources
- Proven to significantly outperform zero-shot generative models on classification tasks
- Can handle nuanced text understanding (word order, context, negation)

**Model characteristics:**
- DistilBERT: 66M parameters, ~250MB in float16, ~130MB quantized
- Inference: Low single-digit milliseconds on Neural Engine
- Much richer text understanding than bag-of-words approaches

**Conversion pipeline:**
```
Python: Fine-tune DistilBERT (Hugging Face)
   -> Export with coremltools / exporters
   -> .mlmodel file
   -> Integrate in Xcode / Swift app
   -> Core ML runtime (Neural Engine)
```

### Approach C: Apple NaturalLanguage Framework

**What it is:** Apple's built-in NLP framework providing tokenization, part-of-speech tagging, named entity recognition, and custom text classification via `NLTagger` and `NLModel`.

**Capabilities:**
- `NLTagger`: Built-in NER for persons, places, organizations (but not custom entity types like books, movies)
- `NLModel`: Custom text classifiers trained via Create ML, deployable through the NaturalLanguage framework
- Language identification, tokenization, lemmatization
- Sentiment analysis

**Role for us:**
- Use `NLTagger` for basic NER as a preprocessing step (identify person names in emails)
- Use `NLModel` for the lightweight text classifier (same model from Create ML, just accessed through NaturalLanguage API)
- Not sufficient on its own for recommendation extraction (no custom entity types without training)

### Recommendation for Classification

**Primary approach: Approach B (DistilBERT converted to Core ML)**
- Best accuracy for nuanced email classification
- Still extremely fast (low ms inference)
- Can be retrained as we collect more labeled data
- Handles the "aggressive, false positives OK" requirement well by tuning the confidence threshold

**Fallback/complement: Approach A (Create ML) or Approach C (NaturalLanguage)**
- Use as a fast first-pass filter before the DistilBERT model
- Extremely fast, no overhead
- Good for obvious cases (clear spam, clear transactional)

---

## 3. Email Classification Approaches

### The Four Categories

1. **Action** -- Needs a response from the user
2. **Newsletter** -- Reading material, routed to Reading Queue
3. **Spam/Marketing** -- Filtered out, reviewable
4. **Transactional** -- Auto-archived (receipts, shipping, 2FA, etc.)

### Multi-Layer Classification Architecture

The classification system should operate as a pipeline with multiple layers, from cheapest/fastest to most expensive/capable.

#### Layer 0: Deterministic Rules (Zero Cost)

These are hard rules that never need ML:

```
IF sender IN vip_list -> Action (always)
IF header "List-Unsubscribe" present AND sender IN known_newsletter_domains -> Newsletter
IF header "X-Mailer" matches known_transactional_senders -> Transactional
IF sender matches "noreply@", "no-reply@" patterns -> NOT Action
IF subject matches "Your order", "Shipping confirmation", "Password reset" -> Transactional
IF subject matches "Your receipt from", "Payment received" -> Transactional
IF email has "Precedence: bulk" header -> Newsletter or Spam (not Action)
```

**Coverage estimate:** 30-50% of all emails can be classified with rules alone with very high confidence.

#### Layer 1: Feature-Based ML Classifier (Very Fast)

A lightweight classifier using engineered features. This runs on every email not caught by Layer 0.

**Feature categories:**

**Header features:**
- Sender domain reputation (known newsletter, known transactional, unknown)
- Presence of List-Unsubscribe header
- To vs CC vs BCC recipient position
- Number of recipients
- Bulk sending headers (X-Mailer, Precedence, etc.)
- Reply-To differs from From
- SPF/DKIM/DMARC alignment

**Sender behavior features (built over time):**
- Historical reply frequency: How often the user replies to this sender
- Historical reply latency: How quickly the user typically responds
- Sender frequency: How often this sender emails
- Last interaction recency: Days since last reply to this sender
- Sender in contacts: Boolean
- Prior classification distribution: What this sender's emails were previously classified as

**Content features:**
- Presence of question marks directed at recipient
- Action phrases: "can you", "could you", "let me know", "what do you think", "are you available", "please review", "by [date]"
- Deadline mentions (dates within 7 days)
- Email length (very short personal vs long newsletter)
- HTML complexity (simple text vs rich newsletter layout)
- Number of links (newsletters have many, personal emails have few)
- Image count (newsletters are image-heavy)
- Unsubscribe link text present in body
- Promotional language density ("sale", "offer", "limited time", "click here")

**Model options for Layer 1:**
- Gradient Boosted Trees (XGBoost/LightGBM): Fast, interpretable, handles mixed feature types well
- Core ML MLTextClassifier with feature engineering
- Random Forest: Simple, robust baseline
- All of these run in microseconds

#### Layer 2: Transformer Classifier (Fast, High Accuracy)

The fine-tuned DistilBERT (or similar) from Section 2. Runs on emails where Layer 1 has moderate confidence (not obviously one category).

**Input:** Email subject + first 512 tokens of body
**Output:** Probability distribution over 4 classes
**Inference time:** 1-5ms on Neural Engine

#### Layer 3: LLM Analysis (Slower, Highest Capability)

For the small percentage of emails where Layers 1-2 are uncertain. Uses the 7B model with a classification prompt.

**When invoked:**
- Layer 2 confidence below threshold (e.g., max class probability < 0.7)
- Email from a new/unknown sender with ambiguous content
- Emails that look like newsletters but might contain action items directed at the user

**Prompt structure:**
```
Classify this email into exactly one category: ACTION, NEWSLETTER, SPAM, TRANSACTIONAL.

ACTION: The sender expects a response from the recipient. Contains questions, requests, deadlines, or calls to action directed at the reader.
NEWSLETTER: Informational content sent to a list. May contain recommendations, news, or analysis. Not expecting a reply.
SPAM: Unsolicited marketing, promotions, or junk.
TRANSACTIONAL: Automated messages like receipts, shipping notifications, password resets, calendar invites.

When in doubt between ACTION and another category, choose ACTION.

Subject: {subject}
From: {sender}
Body:
{truncated_body}

Classification:
```

### Handling the "Aggressive -- False Positives OK, False Negatives NOT OK" Requirement

This is the most critical design requirement for the Action Queue. The system must catch everything that needs a response, even if it means some newsletters or transactional emails incorrectly appear in the Action Queue.

**Strategies:**

1. **Asymmetric loss function during training:** Weight false negatives (missing an Action email) 5-10x more heavily than false positives in the loss function. This pushes the model toward over-classifying as Action.

2. **Low confidence threshold for Action:** If the Action probability exceeds even a modest threshold (e.g., 0.25 instead of the typical 0.5), classify as Action. Only classify as non-Action when the model is very confident it is not.

3. **Union of signals:** If ANY layer suggests Action, classify as Action. The email only goes to a non-Action queue if ALL layers agree it does not need a response.

4. **VIP override:** Emails from VIP senders always go to Action regardless of content analysis.

5. **New sender bias:** Emails from previously unseen senders with any ambiguity default to Action. The cost of missing a new important contact is high.

6. **Doubt-defaults-to-Action in LLM prompt:** Explicitly instruct the Layer 3 LLM to choose Action when uncertain (as shown in the prompt above).

7. **Daily digest review:** The 3 most uncertain filtered items are surfaced in the daily digest, giving the user a safety net to catch any false negatives that slipped through.

### Training with User Feedback Signals

**Explicit signals:**
- User moves email from Filtered to Action (strong signal: false negative)
- User moves email from Action to Newsletter/Filtered (signal: false positive, but acceptable)
- User replies to an email (confirms it was correctly classified as Action)
- User archives without replying from Action Queue (possible false positive)

**Implicit signals:**
- Time spent reading in Action Queue vs quickly archiving
- Snooze behavior (snoozed items are confirmed Action items)
- Multi-snooze (very important Action item the user is procrastinating on)

**Training loop:**
1. First 2 weeks: Aggressive surfacing of borderline cases. High false positive rate accepted.
2. Collect user corrections and implicit signals.
3. Retrain Layer 1 and Layer 2 models weekly during the training period.
4. After convergence: Retrain monthly or when user correction rate exceeds a threshold.

**Cold start strategy:**
- Week 1: Rules (Layer 0) handle obvious cases. Everything ambiguous goes to Action.
- Week 2: Enough labeled data to train Layer 1 features (sender behavior).
- Week 3-4: Enough data to fine-tune Layer 2 classifier.
- Month 2+: System reaches steady state. Layer 3 LLM invoked rarely.

---

## 4. Recommendation Extraction

### The Challenge

Extracting structured recommendations (books, movies, music, articles, podcasts, products) from unstructured newsletter text. This is harder than classification because:
- Entity types are non-standard (not typical NER categories like PERSON, ORG, LOCATION)
- Context matters: "I read Dune" is not a recommendation, but "Dune is the best sci-fi novel I've read this year" is
- Titles can be ambiguous: "The Bear" could be a TV show or a restaurant
- Format varies wildly across newsletters

### Approach: LLM with Structured Output

This is the task where a capable local LLM (7B) earns its keep. Traditional NER is insufficient because we need to understand recommendation context, not just identify entities.

#### Prompt Design

```
Extract all recommendations from this newsletter. A recommendation is when the author
suggests, endorses, praises, or highlights a specific book, movie, TV show, music
(album/song/artist), article, podcast, or product.

For each recommendation, extract:
- type: one of [book, movie_tv, music, article, podcast, product, other]
- title: the name of the recommended item
- creator: author, director, artist, etc. (if mentioned)
- context: the sentence or phrase where the recommendation appears (quote directly)
- confidence: high, medium, or low

Only include items the author is clearly recommending or endorsing. Do not include
items merely mentioned in passing without positive sentiment.

Newsletter text:
{newsletter_body}

Respond in JSON format:
{
  "recommendations": [
    {
      "type": "book",
      "title": "...",
      "creator": "...",
      "context": "...",
      "confidence": "high"
    }
  ]
}
```

#### Structured Output Enforcement

**llama.cpp GBNF grammars:** The most mature approach for guaranteeing valid JSON output. Define a GBNF grammar that matches the exact JSON schema, and the model is constrained to only produce tokens that form valid output. This eliminates JSON parsing errors entirely and reportedly improves extraction accuracy by approximately 25% because the model is forced to think in structured terms.

**MLX structured output:** MLX supports constrained decoding but the tooling is less mature than llama.cpp's GBNF. As of early 2026, this is an area of active development.

**Practical approach:** Use llama.cpp (via llama-cpp-python or a subprocess) specifically for recommendation extraction if MLX's structured output is insufficient. The two frameworks can coexist.

**JSON schema to grammar conversion:** llama.cpp includes `json-schema-to-grammar.py` which automatically converts a JSON schema to a GBNF grammar. Define our recommendation schema once and generate the grammar automatically.

### NER as a Pre-processing Step

While full recommendation extraction requires LLM reasoning, NER can serve as a useful preprocessing step:

**Apple NaturalLanguage (NLTagger):**
- Identify person names (potential authors, directors, artists)
- Identify organizations (publishers, studios, labels)
- Free, built-in, runs in microseconds

**spaCy (Python, if using a Python sidecar):**
- More capable NER: persons, organizations, works of art, products, events
- Can be trained on custom entity types
- The `en_core_web_trf` transformer-based pipeline offers highest accuracy
- Could pre-annotate text before sending to LLM, improving extraction accuracy

**Hybrid NER + LLM approach:**
1. Run NER to identify candidate entities and their types
2. Pass annotated text to LLM: "The following entities were detected: [Dune (WORK_OF_ART), Frank Herbert (PERSON)]. Extract any recommendations..."
3. LLM uses NER annotations as hints but makes final recommendation decisions based on context

### Identifying Recommendation Context

The LLM handles this naturally through prompt engineering, but key patterns to recognize:

**Strong recommendation signals:**
- Superlatives: "the best", "my favorite", "must-read", "must-watch"
- Explicit endorsement: "I highly recommend", "you should read/watch/listen to"
- Gift language: "perfect gift", "I bought this for everyone"
- Repeated mention with praise across multiple paragraphs
- Rating or scoring: "10/10", "five stars", "A+"

**Moderate signals:**
- Positive sentiment near a title: "loved", "enjoyed", "fascinating", "brilliant"
- Comparison praise: "better than", "the best since"
- Currently consuming: "I'm reading", "just finished", "been listening to"

**Weak/negative signals (not recommendations):**
- Negative reviews: "disappointed by", "waste of time"
- Mere mentions: "speaking of Dune" (no endorsement)
- Self-promotion: Author promoting their own work
- Ads within newsletters

### Duplicate Detection Across Newsletters

When multiple newsletters recommend the same item, we want to consolidate into a single entry showing all sources.

**Approach: Embedding-based similarity**

1. **Generate embeddings** for each extracted recommendation title + creator using a local embedding model
2. **Compare against existing recommendations** using cosine similarity
3. **Threshold:** If similarity > 0.85, consider it a duplicate and merge

**Embedding model options (all run locally):**
- `nomic-embed-text` via Ollama: Good quality, runs locally
- `all-MiniLM-L6-v2`: Small (80MB), fast, good for semantic similarity
- MLX-compatible embedding models from Hugging Face

**Storage:** Use a simple SQLite database with a vector similarity extension (sqlite-vss) or just brute-force cosine similarity for the small number of recommendations we will have (likely < 1000 total).

**Merge strategy:**
- Keep the first-seen entry as primary
- Add additional sources: "Recommended by Stratechery (Jan 15), The Browser (Jan 18), Austin Kleon (Jan 20)"
- Keep all context snippets, accessible on tap-to-expand

**Edge cases:**
- Same title, different editions (e.g., book vs audiobook): Merge
- Same title, different works (e.g., "The Bear" TV show vs restaurant): Use type and creator to disambiguate
- Fuzzy title matching: "Lord of the Rings" vs "LOTR" vs "The Lord of the Rings": Embeddings handle this naturally

---

## 5. Digest Generation

### Requirements

Two daily digests (6 AM and 7 PM) that summarize email activity and surface important items. These are generated views in the app, not notification emails.

### Approach: Template-Based with LLM Summarization

Pure template-based digests handle the structural elements (counts, lists, snooze returns), while LLM summarization adds intelligence for borderline items and notable transactional emails.

#### Template Components (No LLM Needed)

These are simple database queries rendered into templates:

**Morning (6 AM):**
```
- Action Queue: {count} items across {account_breakdown}
- Snoozed returning today: {list with times}
- Reading Queue: {count} new newsletters since yesterday
- Borderline items: {top 3 lowest-confidence filtered items}
- Notable transactional: {packages arriving, large charges}
```

**Evening (7 PM):**
```
- Still in Action Queue: {count} items
- Handled today: sent {sent_count}, archived {archive_count}
- Newsletters arrived today: {list with titles}
- Multi-snoozed items: {items snoozed 3+ times with gentle nudge}
```

#### LLM-Enhanced Components

**Borderline item descriptions:** For the 3 most uncertain filtered items, generate a one-sentence explanation of why they might be important:
```
"Email from shipping@amazon.com about 'Your order has been updated' --
this could be a delivery change requiring action rather than a routine tracking update."
```

**Notable transactional summaries:** For large charges or unusual transactional emails:
```
"United Airlines charged $847 yesterday. Two packages arriving today
(Amazon, USPS)."
```

**Smart nudges for multi-snoozed items:**
```
"You've snoozed the email from Sarah Chen about the Q1 review 3 times
over 5 days. It might be worth a quick reply today."
```

### Template vs Generative

**Use templates for:** Structure, counts, lists, timestamps. These are deterministic and should never hallucinate.

**Use LLM for:** One-sentence summaries, context explanations, smart nudges. These benefit from natural language generation but should be grounded in specific data.

**Guard rail:** Every LLM-generated summary references a specific email. The user can tap to see the original. Never generate claims not grounded in actual email data.

### Performance

Digest generation is a batch job that runs at scheduled times. It is not latency-sensitive.

- Template components: < 100ms (database queries)
- LLM summaries: 3-5 items x approximately 2 seconds each = approximately 10-15 seconds total
- Total digest generation time: Under 30 seconds

This is well within acceptable limits for a 6 AM and 7 PM scheduled job.

---

## 6. Performance and Resource Considerations

### Hardware Configurations

#### Mac Mini M4 (Base)
- **CPU:** 10-core (4P + 6E)
- **GPU:** 10-core
- **RAM:** 16GB or 24GB unified memory
- **Memory bandwidth:** 120 GB/s
- **Power:** 3-4W idle, 40-45W max load
- **Price:** $599 (16GB), $799 (24GB)

#### Mac Mini M4 Pro
- **CPU:** 12-core (8P + 4E) or 14-core (10P + 4E)
- **GPU:** 16-core or 20-core
- **RAM:** 24GB, 48GB, or 64GB unified memory
- **Memory bandwidth:** 273 GB/s
- **Power:** Similar efficiency profile
- **Price:** Starting at $1,399

### Memory Budget Analysis

For our workload (classify + extract + summarize), here is a memory budget estimate:

| Component | Memory Usage |
|-----------|-------------|
| macOS + system services | ~4-5GB |
| Email client app (Swift) | ~200-500MB |
| Classification model (DistilBERT, Core ML) | ~130-250MB |
| Feature-based classifier (XGBoost/similar) | ~10-50MB |
| Extraction/Summarization model (7B, 4-bit) | ~4-5GB |
| Embedding model for dedup | ~100-300MB |
| SQLite + data | ~100-500MB |
| **Total** | **~9-12GB** |

**Conclusion:** A Mac Mini M4 with 24GB unified memory is the minimum recommended configuration. It provides comfortable headroom for the 7B model plus all other components. The 16GB configuration would work if we use only a 3B model for extraction, but this may sacrifice quality.

The M4 Pro with 24GB would provide approximately 2x the memory bandwidth (273 vs 120 GB/s), which directly translates to faster token generation (35-45 tok/s vs 18-22 tok/s for the 7B model). For a 24/7 processing hub, this extra performance is worth the investment.

### Processing Volume Estimate

**Assumptions:**
- 3 email accounts
- Average 50-150 emails/day total across all accounts
- Peak: 200 emails/day during busy periods

**Processing time per email:**

| Task | Time | When |
|------|------|------|
| Rule-based check (Layer 0) | < 1ms | Every email |
| Feature extraction + Layer 1 classifier | ~5-10ms | ~50-70% of emails |
| Layer 2 transformer classifier | ~5-15ms | ~20-30% of emails |
| Layer 3 LLM classification | ~2-5s | ~5-10% of emails |
| Recommendation extraction (newsletters only) | ~5-15s | ~10-20% of emails |

**Daily processing time:**
- 150 emails/day, average ~100ms per email (most are fast): ~15 seconds total for classification
- 20 newsletters with recommendation extraction at approximately 10s each: ~200 seconds total
- 2 digest generations at approximately 30s each: ~60 seconds total
- **Total daily compute: Under 5 minutes of actual processing**

The Mac Mini will be idle >99% of the time. This workload is trivially light for Apple Silicon running 24/7.

### Batching Strategies

Even though the workload is light, smart batching improves efficiency:

1. **IMAP polling interval:** Check for new emails every 1-5 minutes (configurable). Process all new emails in a batch.
2. **Classification pipeline:** Run all new emails through Layer 0 and Layer 1 together. Only invoke Layer 2/3 for uncertain cases.
3. **Newsletter extraction:** Queue newsletters and process extraction in a batch after classification. No urgency since these go to the Reading Queue.
4. **Model loading:** Keep the classification model (small) loaded at all times. Load the 7B extraction model on-demand when there are newsletters to process, then unload after processing to free memory. On M4 Pro with 24GB+, keeping both loaded is feasible.
5. **Digest generation:** Single batch job at scheduled times. Pre-compute all needed data.

### Thermal and Longevity Considerations

- Mac Mini M4 is designed for always-on operation
- Our workload produces minimal thermal load (< 5 minutes of compute per day)
- Idle power consumption of 3-4W means negligible electricity cost (roughly $3-5/year)
- No fans needed for our workload intensity
- SSD writes are minimal (email metadata and classification decisions)

---

## 7. MLX Framework Deep Dive

### Architecture

MLX is built around several core principles that make it ideal for our use case:

**Unified memory:** Arrays live in shared memory. Operations on MLX arrays can be performed on any supported device type (CPU or GPU) without transferring data. This is a fundamental advantage on Apple Silicon where CPU and GPU share the same memory pool.

**Lazy evaluation:** Computations are only materialized when needed. This enables operation fusion (combining multiple operations into a single GPU kernel) and reduces memory allocation overhead.

**Metal GPU backend:** MLX uses Metal Performance Shaders and custom Metal kernels for GPU-accelerated computation. The Neural Engine integration (especially on M4/M5) adds dedicated ML acceleration hardware.

### Swift API

MLX provides first-class Swift support through several packages:

```swift
// Core packages
import MLX          // Core array operations
import MLXLMCommon  // Common LLM infrastructure
import MLXLLM       // LLM-specific functionality
```

**Model loading from Hugging Face:**
```swift
// Single-line model loading with automatic downloading and caching
let model = try await LLMModelFactory.shared.load(
    configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
)
```

**Streaming inference:**
```swift
// Async/await streaming for UI responsiveness
for try await token in model.generate(prompt: classificationPrompt) {
    // Process each token as it arrives
}
```

**Key integration patterns:**
- Async/await for non-blocking inference
- Model caching (download once, load from disk subsequently)
- Memory management (explicit model unloading when done)
- Offline capability via bundled models (no network needed after first download)

### MLX vs llama.cpp for Our Use Case

| Aspect | MLX | llama.cpp |
|--------|-----|-----------|
| **Swift integration** | Native, first-class | C API, requires bridging |
| **Throughput** | ~230 tok/s | ~150 tok/s |
| **Latency** | 5-7ms per token | Higher |
| **Structured output** | Developing | Mature (GBNF grammars) |
| **Model ecosystem** | Growing (HF mlx-community) | Largest (GGUF) |
| **Fine-tuning** | Built-in LoRA support | Separate tooling |
| **Quantization** | Built-in, mixed precision | GGUF quantization, many options |
| **Memory efficiency** | Zero-copy unified memory | Metal backend, some overhead |
| **Long context** | Rotating KV cache (good to 32k) | Standard KV cache |
| **Community** | Apple-backed, growing | Massive, very mature |

**Verdict:** Use MLX as the primary framework for classification and summarization (where Swift integration and speed matter). Use llama.cpp (via subprocess or Python bridge) for recommendation extraction when we need guaranteed structured JSON output via GBNF grammars. Revisit this split as MLX's structured output matures.

### Fine-Tuning with MLX

MLX supports LoRA and QLoRA fine-tuning directly on Apple Silicon:

**Process:**
1. Prepare training data as JSONL (train.jsonl, test.jsonl, valid.jsonl)
2. Choose a base model (e.g., Qwen2.5-1.5B-Instruct)
3. Run LoRA fine-tuning: creates a small adapter file (few MB)
4. Fuse the adapter with the base model or load adapter at inference time
5. Deploy the fine-tuned model

**Training time on Apple Silicon:** Approximately 7-10 seconds per training step. A full fine-tuning run on a few thousand examples takes minutes, not hours.

**For email classification:**
- Fine-tune Qwen2.5-1.5B on labeled email data
- Use the chat/instruction format to frame classification as a prompt-response task
- The resulting model will be a classification specialist while retaining general language understanding
- Adapter size: a few MB on top of the base model

**Retraining cadence:**
- Initial training: During 2-week onboarding period
- Weekly retraining during first month as user corrections accumulate
- Monthly retraining after convergence
- On-demand retraining if user correction rate spikes

### MLX Quantization Details

MLX supports several quantization strategies:

- **4-bit quantization:** Up to 3.5x memory reduction with minimal accuracy loss. Recommended for 7B+ models.
- **8-bit quantization:** 2x memory reduction, nearly lossless. Good for smaller models where we can afford the memory.
- **Mixed precision:** Different layers quantized at different bit widths. Attention layers kept at higher precision, feedforward layers at 4-bit. Best accuracy/memory trade-off.
- **Group-size configuration:** Smaller groups = better quality, larger groups = more compression.

---

## 8. Hybrid Approaches

### The Case for a Cascade Architecture

The central insight is that most emails are easy to classify. A simple rule or small model handles 80-90% of volume. Only ambiguous emails need a larger, slower model. This cascade approach minimizes latency, compute, and memory usage while maintaining high accuracy.

### Proposed Cascade Design

```
Email arrives
    |
    v
[Layer 0: Rules] -----> Classified with high confidence (30-50%)
    |
    | (uncertain)
    v
[Layer 1: Feature ML] -----> Classified with high confidence (30-40%)
    |
    | (uncertain)
    v
[Layer 2: DistilBERT] -----> Classified with high confidence (15-25%)
    |
    | (uncertain)
    v
[Layer 3: 7B LLM] -----> Final classification (5-10%)
    |
    v
[Confidence check] -----> If still uncertain, default to Action
```

### Confidence Calibration

Each layer outputs a confidence score. The cascade uses these to decide whether to defer to the next layer:

**Layer 0 (Rules):** Binary -- either the rule matches or it does not. Matches are 100% confident.

**Layer 1 (Feature ML):** Calibrated probability. Defer if max class probability < 0.85.

**Layer 2 (DistilBERT):** Calibrated probability. Defer if max class probability < 0.75. Temperature scaling can improve calibration.

**Layer 3 (7B LLM):** Extract confidence from token probabilities or explicit confidence in the prompt response. If still uncertain, apply the Action bias.

### Resource Usage in Cascade Mode

| Layer | Model Size in Memory | Inference Time | Invocation Rate |
|-------|---------------------|----------------|-----------------|
| Layer 0 | ~0 (code logic) | < 1ms | 100% |
| Layer 1 | ~10-50MB | ~5-10ms | ~50-70% |
| Layer 2 | ~130-250MB | ~5-15ms | ~20-30% |
| Layer 3 | ~4-5GB (loaded on demand) | ~2-5s | ~5-10% |

**Always loaded:** Layers 0, 1, 2 (total: ~200-300MB)
**Loaded on demand:** Layer 3 (4-5GB, loaded when needed, unloaded after batch)

This means the system uses under 1GB for classification most of the time, with the heavy model only loaded briefly when needed.

### Separate Models for Separate Tasks

Beyond the classification cascade, different tasks warrant different models:

| Task | Model | Size | Loaded |
|------|-------|------|--------|
| Email classification | Fine-tuned Qwen2.5-1.5B or DistilBERT | 1-1.5GB or 250MB | Always |
| Recommendation extraction | Qwen2.5-7B (4-bit) | ~4.5GB | On demand (newsletters) |
| Digest summarization | Same Qwen2.5-7B | Shared | On demand (2x daily) |
| Embedding/dedup | nomic-embed-text or MiniLM | ~100-300MB | On demand |

**Key insight:** The extraction and summarization models can be the same 7B model with different prompts. Load it once, process all newsletters, generate both digests, then unload. This keeps memory usage efficient.

### Adaptive Complexity

Over time, the system learns which senders and patterns can be handled by simpler layers:

- After 100 emails from a sender, the system knows their pattern. Most future emails from that sender can be classified by Layer 0 or 1.
- Newsletter senders are learned after 2-3 emails. All future emails from that sender go straight to Newsletter.
- Transactional senders (Amazon, banks, airlines) are learned almost immediately.

The result: The system gets faster and cheaper over time as more emails are handled by cheaper layers.

---

## 9. Recommended Architecture

### Summary of Recommendations

Based on all research above, here is the recommended architecture:

#### Hardware
- **Mac Mini M4 Pro with 24GB unified memory** (minimum). 48GB preferred if budget allows.
- Runs 24/7 with negligible power consumption for our workload.

#### Frameworks
- **MLX (Swift):** Primary framework for classification inference, summarization, and fine-tuning.
- **llama.cpp:** Secondary framework for recommendation extraction (structured JSON output via GBNF grammars). Invoked as a subprocess or via Python bridge.
- **Core ML:** For the DistilBERT classifier in the cascade. Runs on Neural Engine for maximum efficiency.
- **Apple NaturalLanguage:** For basic NER preprocessing and tokenization.

#### Models
- **Classification (always loaded):** Fine-tuned DistilBERT via Core ML (~250MB) OR fine-tuned Qwen2.5-1.5B via MLX (~1GB)
- **Feature classifier (always loaded):** XGBoost/LightGBM trained on email features (~50MB)
- **Extraction + Summarization (on demand):** Qwen2.5-7B 4-bit via MLX or llama.cpp (~4.5GB)
- **Embeddings (on demand):** nomic-embed-text or all-MiniLM-L6-v2 (~100-300MB)

#### Classification Pipeline
1. Layer 0: Deterministic rules (VIP, known senders, headers)
2. Layer 1: Feature-based classifier (sender behavior, header features, content features)
3. Layer 2: Fine-tuned transformer classifier (DistilBERT or small LLM)
4. Layer 3: 7B LLM for ambiguous cases
5. Default to Action when uncertain

#### Processing Flow
1. IMAP poll every 1-5 minutes
2. Batch classify all new emails through the cascade
3. Queue newsletters for recommendation extraction
4. Load 7B model, process all queued newsletters, extract recommendations, unload
5. At 6 AM and 7 PM, load 7B model, generate digests, unload
6. Sync all decisions and extractions to other devices

---

## 10. Open Questions and Next Steps

### Questions to Resolve

1. **MLX structured output maturity:** Test MLX's constrained decoding for JSON output. If it is reliable enough, we can use MLX for everything and drop the llama.cpp dependency.

2. **DistilBERT vs fine-tuned small LLM for classification:** Both are viable. DistilBERT via Core ML is faster and lighter. A fine-tuned 1.5B LLM via MLX is more capable. Need to test both with real email data to see if the accuracy difference justifies the resource difference.

3. **Training data collection:** How do we bootstrap the labeled dataset? Options:
   - Manual labeling of the first 2 weeks of email
   - Semi-supervised: Use rules to label obvious cases, only manually label ambiguous ones
   - Active learning: System asks user to classify the most uncertain emails

4. **Python sidecar vs pure Swift:** Some ML tooling (spaCy, scikit-learn for XGBoost, Hugging Face for fine-tuning) is Python-only. Options:
   - Pure Swift: Use MLX Swift for everything. Limits tooling options.
   - Python sidecar: Swift app calls a Python process for training and some inference. More flexible but adds complexity.
   - Hybrid: Swift for runtime inference, Python scripts for periodic retraining.

5. **Model update distribution:** When we retrain models on the Mac Mini, how do we version and manage model files? Need a model registry/versioning scheme.

6. **Recommendation entity resolution:** How do we link extracted titles to real-world entities? Options:
   - Just store as text (simplest)
   - Use a local database of known books/movies (e.g., Open Library data)
   - On-demand lookup when user interacts (requires network, breaks local-only)

7. **Testing and evaluation:** Need to define metrics:
   - Action recall > 99% (false negative rate < 1%)
   - Action precision > 70% (some false positives OK)
   - Newsletter/Spam/Transactional: Standard F1 > 90%
   - Recommendation extraction: Precision > 80%, Recall > 70%

### Immediate Next Steps

1. **Prototype the classification cascade** with Ollama (easy setup) to validate the approach with real email data.
2. **Collect and label 500-1000 emails** across the 4 categories to create a training dataset.
3. **Benchmark MLX vs llama.cpp** on the target Mac Mini hardware for our specific model choices.
4. **Test structured JSON output** with both MLX and llama.cpp GBNF on sample newsletters.
5. **Build the rule engine (Layer 0)** -- this requires no ML and provides immediate value.
6. **Evaluate Create ML text classifier** as a fast baseline to understand the accuracy floor.

---

## Appendix: Key Resources

### Frameworks and Tools
- MLX: https://github.com/ml-explore/mlx
- MLX Swift: https://github.com/ml-explore/mlx-swift
- MLX LM (Python): https://github.com/ml-explore/mlx-lm
- llama.cpp: https://github.com/ggml-org/llama.cpp
- Ollama: https://ollama.com
- Core ML Tools: https://github.com/apple/coremltools
- Hugging Face Exporters (for Core ML): https://github.com/huggingface/exporters
- Apple NaturalLanguage Framework: https://developer.apple.com/documentation/NaturalLanguage

### Models (Hugging Face)
- MLX Community Models: https://huggingface.co/mlx-community
- Qwen2.5 Series: https://huggingface.co/Qwen
- Llama 3.2: https://huggingface.co/meta-llama
- DistilBERT: https://huggingface.co/distilbert-base-uncased
- nomic-embed-text: https://huggingface.co/nomic-ai/nomic-embed-text-v1.5

### Research
- Production-Grade Local LLM Inference on Apple Silicon (comparative study): https://arxiv.org/abs/2511.05502
- Apple MLX Research: https://machinelearning.apple.com/research
- Fine-Tuned Small LLMs Outperform Zero-Shot Models: https://www.aimodels.fyi/papers/arxiv/fine-tuned-small-llms-still-significantly-outperform
- WWDC 2025 MLX Session: https://developer.apple.com/videos/play/wwdc2025/298/
