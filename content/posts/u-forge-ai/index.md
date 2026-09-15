---
title: "u-forge.ai: Reliability Engineering for Local-First AI Worldbuilding"
date: 2026-09-14T12:00:00-07:00
description: "How I am building a Rust desktop TTRPG workspace with a knowledge graph, hybrid GraphRAG retrieval, and resource-aware local inference."
menu:
  sidebar:
    name: u-forge.ai
    identifier: u-forge-ai
    weight: 5
tags: ["u-forge.ai", "Rust", "AI", "GraphRAG", "local-first", "reliability"]
categories: ["Projects", "AI"]
---

**u-forge.ai (Universe Forge)** is my local-first desktop application for tabletop RPG worldbuilding. I have been developing it since 2024, bringing together object-based notes, a knowledge graph, and optional AI assistance to help game masters build and explore their settings.

The application is functional and demoable, and I am actively refining search relevance and retrieval precision. The current project documentation identifies it as a **v0.1.1 alpha targeting Linux x86_64**. Its public home is [the GitHub repository](https://github.com/th3raid0r/u-forge.ai)—there is no live standalone product website at the u-forge.ai domain yet. For current setup and availability, start with the repository's README and [release listings](https://github.com/th3raid0r/u-forge.ai/releases).

![Universe Forge showing keyword and hybrid search, a connected world graph, object properties, and an AI assistant](u-forge-ai.png)

*The native workspace brings search, relationships, editable world objects, and optional AI assistance together. Screenshot from the project repository.*

## From campaign notes to a connected world

A campaign setting is more than a collection of documents. Characters belong to factions, locations have histories, and events connect people and places. Those relationships deserve to be part of the data rather than something the author must reconstruct from scattered notes.

Universe Forge models world content as schema-defined objects and relationships. A native workspace provides editing, search, a details view, an assistant, and a World Canvas for exploring the relationship graph. SQLite stores the world data, text chunks, schemas, and saved canvas positions locally.

The important architectural boundary is between **durable world data and optional inference**. Core editing, graph navigation, import/export, and full-text search remain usable without an AI backend. AI is an additional way to work with a setting, not a prerequisite for opening it.

## Hybrid retrieval and GraphRAG

I designed and implemented GraphRAG retrieval over structured objects and unstructured note content. The search layer combines:

- **Keyword retrieval** through SQLite FTS5 for names, phrases, and explicit terms.
- **Semantic retrieval** using embeddings and sqlite-vec for conceptually related material.
- **Hybrid search** using reciprocal rank fusion to combine result rankings, with optional reranking.

The knowledge graph preserves the relationships surrounding the notes. Retrieval gives the assistant relevant world content to work with instead of relying only on a model's general knowledge.

Search also has to degrade usefully. If an optional retrieval capability is unavailable or fails, successful search paths should still produce results. Improving the quality and precision of those results is an ongoing focus, not a solved problem or a benchmark claim.

## AI assistance with validated writes

The optional assistant uses Rig and exposes tools for keyword, semantic, and hybrid search, plus node and relationship updates. Tool arguments are validated against JSON Schema. Schema-aware JSONL imports resolve nodes and relationships in separate phases, reporting invalid records and unresolved or ambiguous relationships rather than silently extending the world's schema.

These boundaries bring operational discipline to a creative tool: generated suggestions still have to fit the application's data model. Validation does not guarantee that AI-generated lore is correct, but it helps keep malformed operations from becoming persistent world data.

## Resource-aware inference on consumer hardware

Local inference means working within real memory, compute, and model-loading constraints. I built a multi-device inference queuing system to schedule workloads across NPU, CPU, and GPU resources, with the aim of balancing throughput and latency. Actual device availability depends on the configured backend, models, drivers, and hardware; this is not a promise that every device works on every machine.

The implementation includes cancellable jobs, typed failure and timeout outcomes, queue telemetry, adaptive embedding dispatch, model-context budgeting, and repeated-tool-call circuit breaking. Those are practical reliability concerns: cancelled work should stop, failures should be actionable, and an agent should not repeat the same tool call indefinitely.

[Lemonade](https://github.com/lemonade-sdk/lemonade) provides local inference integration, including discovery, model selection, and management of a private runtime on Linux. Separately managed endpoints are also supported. **Local-first does not mean every possible configuration is local-only:** explicitly configuring a non-local endpoint can send inference requests outside the machine.

My earlier [CachyOS and Strix Halo inference guide](/posts/strixhalo-cachyos/) explores the hardware and Linux ecosystem behind this work. It is a dated setup guide, not a current compatibility matrix or a u-forge.ai performance benchmark. The project does not require Strix Halo hardware.

## Architecture and delivery

| Concern | Implementation |
| --- | --- |
| Desktop application | Rust 2024 multi-crate workspace; native GPUI interface through gpui-ce |
| World data | SQLite, schema-driven objects and relationships, validated JSONL ingestion |
| Retrieval | FTS5, sqlite-vec, keyword/semantic/hybrid search, optional reranking |
| Assistant | Rig, schema-validated tools, optional Lemonade inference |
| Runtime reliability | Tokio, cancellation, bounded model context, typed outcomes and telemetry |
| Distribution | Linux x86_64 AppImage packaging and GitHub Actions release workflow |

The packaging workflow includes application defaults and a private Lemonade runtime, with SHA-256 verification for runtime provisioning. The documented packaged target is Linux x86_64; I am not presenting unverified Windows or macOS builds as supported releases.

## Applying SRE experience beyond the cloud

At Aerospike, my work centers on reliable platforms: SLO-based alerting, incident response, automated operational guardrails, and reducing manual toil. Universe Forge applies that same thinking to a desktop AI product:

- Keep useful functionality available when a dependency is missing.
- Make resource ownership, cancellation, and failure states explicit.
- Validate inputs at import and agent-write boundaries.
- Make packaging and runtime setup repeatable.
- Treat retrieval quality as something to inspect and improve, not assume.

It also complements my work on [Tucson.social](/#projects). One project is a local creative workspace; the other is a suite of federated community services. Both involve end-to-end ownership and a deliberate choice about where data, infrastructure, and control should live.

## What is next—and what is not shipped

My immediate focus is improving search relevance and retrieval precision. The documented longer-term roadmap includes richer schema icons, improved chunking and embeddings, a dedicated timeline, geographic maps, session transcription, and rules ingestion. These are **roadmap items**, not a list of current capabilities. The existing World Canvas is a relationship graph, not a geographic map, and a proposed embedded TypeScript agent runtime remains a placeholder rather than a shipped feature.

For the current state, see the [README](https://github.com/th3raid0r/u-forge.ai#readme), [architecture documentation](https://github.com/th3raid0r/u-forge.ai/blob/main/ARCHITECTURE.md), and [compatibility notes](https://github.com/th3raid0r/u-forge.ai/blob/main/COMPAT.md). This write-up describes the project as reviewed in September 2026; the repository remains the source for subsequent changes.
