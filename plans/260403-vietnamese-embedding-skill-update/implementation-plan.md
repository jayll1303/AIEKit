# Vietnamese Embedding Exception - Skill Update Plan

## Goal
Add Vietnamese-specific embedding guidance to `text-embeddings-rag` skill based on VN-MTEB benchmark research.

## Research Summary (VN-MTEB)
- Paper: "VN-MTEB: Vietnamese Massive Text Embedding Benchmark" (EACL 2026 Findings)
- 41 datasets, 6 tasks: retrieval, reranking, classification, clustering, pair classification, STS
- Key finding: RoPE-based models >> APE-based models for Vietnamese
- Top models: gte-Qwen2-7B-instruct (Avg ~57.5), e5-Mistral-7B-instruct (Avg ~56.5)
- Vietnamese monolingual models exist but limited scope

## Changes

### 1. SKILL.md
- [x] Add Vietnamese exception note in "When to Use" or new section
- [x] Add Vietnamese-specific anti-pattern

### 2. references/embedding-model-guide.md
- [x] Add "Vietnamese Embedding Models (VN-MTEB)" section with:
  - VN-MTEB benchmark overview
  - Model ranking table from paper
  - Vietnamese monolingual models
  - Vietnamese-specific recommendations
  - Word segmentation note for BM25 hybrid search
  - Code example with Vietnamese text

## Status: DONE
