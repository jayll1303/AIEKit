# arXiv Reader Skill — Implementation Plan

## Goal
Tạo Kiro Skill giúp agent đọc và phân tích paper từ arXiv.

## Approach
- Tạo Skill (không phải Steering) vì: portable, on-demand, chứa workflow chi tiết
- Dùng tools có sẵn của Kiro: `webFetch`, `remote_web_search` — KHÔNG cần MCP server
- Ưu tiên HTML version (ar5iv.labs.arxiv.org) thay vì PDF — dễ parse, ít token hơn

## Key Decisions
- ar5iv.org render LaTeX → HTML, agent đọc được trực tiếp qua webFetch
- Abstract page (arxiv.org/abs/) cho quick overview
- Full HTML (ar5iv.labs.arxiv.org) cho deep reading
- arXiv API (export.arxiv.org/api/) cho search/metadata

## Files to Create
1. `.kiro/skills/arxiv-reader/SKILL.md` — Main skill file
2. `.kiro/skills/arxiv-reader/references/arxiv-url-patterns.md` — URL patterns & API reference

## Tasks
- [x] Research arXiv URL patterns and ar5iv availability
- [x] Create SKILL.md with workflows
- [x] Create reference file for URL patterns
- [x] Verify skill structure
