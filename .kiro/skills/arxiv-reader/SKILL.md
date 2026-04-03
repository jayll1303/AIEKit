---
name: arxiv-reader
description: "Read and analyze arXiv papers via HTML. Use when user mentions arxiv, paper, research paper, academic paper, arxiv ID, or asks to read/summarize/analyze a scientific paper."
---

# arXiv Paper Reader

Read, summarize, and analyze academic papers from arXiv using Kiro's built-in web tools.

## Scope

This skill handles: reading arXiv papers, extracting abstracts, summarizing sections, analyzing methodology, searching arXiv.
Does NOT handle: PDF-only papers outside arXiv, citation graph analysis, bulk paper downloads.

## When to Use

- User shares an arXiv URL or paper ID (e.g., `2301.07041`)
- User asks to read, summarize, or analyze a research paper
- User wants to search arXiv for papers on a topic
- User asks about a specific paper's methodology, results, or contributions

## Key Insight: ar5iv for Full Paper Reading

arXiv papers are LaTeX → PDF. Agent cannot read PDF directly via webFetch.
**Solution:** Use `ar5iv.labs.arxiv.org` which renders LaTeX → HTML. Agent reads HTML perfectly.

## URL Pattern Quick Reference

| Need | URL Pattern | Tool |
|------|-------------|------|
| Abstract + metadata | `https://arxiv.org/abs/{id}` | webFetch (truncated) |
| Full paper as HTML | `https://ar5iv.labs.arxiv.org/html/{id}` | webFetch (selective/full) |
| Search papers | `https://arxiv.org/search/?query={q}` | remote_web_search preferred |
| API metadata (XML) | `https://export.arxiv.org/api/query?id_list={id}` | webFetch |

See [references/arxiv-url-patterns.md](references/arxiv-url-patterns.md) for full details.

## Core Workflows

### Workflow 1: Read a Specific Paper

Given an arXiv ID or URL:

1. Extract the paper ID from input (e.g., `2301.07041` from `https://arxiv.org/abs/2301.07041` or `2301.07041v2`)
2. Fetch abstract page: `webFetch` url=`https://arxiv.org/abs/{id}` mode=truncated
   **Validate:** Response contains title, authors, abstract text.
3. If user needs full paper content, fetch HTML version:
   `webFetch` url=`https://ar5iv.labs.arxiv.org/html/{id}` mode=selective, searchPhrase="{section keyword}"
   **Validate:** Response contains readable paper sections (not just navigation).
4. If selective mode returns insufficient content, retry with mode=full for complete paper.
5. Summarize findings based on user's request (overview, methodology, results, etc.)

**Validate:** Summary references specific sections, figures, or equations from the paper.

### Workflow 2: Search for Papers on a Topic

1. Use `remote_web_search` with query: `arxiv {topic} site:arxiv.org`
2. Extract paper IDs from search results
3. For each relevant result, fetch abstract via `webFetch` url=`https://arxiv.org/abs/{id}` mode=truncated
4. Present papers with: title, authors, date, abstract summary, relevance note

**Validate:** Each paper listed has concrete metadata, not just URL.

### Workflow 3: Deep Analysis of a Paper Section

1. Complete Workflow 1 steps 1-2 first (get overview)
2. Identify target section from user request (e.g., "methodology", "experiments", "related work")
3. Fetch with selective mode: `webFetch` url=`https://ar5iv.labs.arxiv.org/html/{id}` mode=selective searchPhrase="{section name or key term}"
4. If ar5iv returns empty/minimal content (some papers not yet converted), fallback:
   - Try `webFetch` url=`https://arxiv.org/html/{id}` mode=selective (arxiv's own HTML, newer papers)
   - Last resort: inform user that paper is PDF-only, suggest they attach the PDF directly

**Validate:** Extracted section contains substantive content, not just headers.

## ar5iv Fallback Strategy

```
ar5iv returns empty/error?
├─ Paper too new (< few days old)?
│   └─ Try arxiv.org/html/{id} (native HTML, available for newer papers)
├─ Paper has complex LaTeX?
│   └─ ar5iv may fail on some papers. Try arxiv.org/html/{id}
└─ Neither works?
    └─ Inform user: "This paper is only available as PDF. 
       You can attach the PDF file directly in chat for me to analyze."
```

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "I'll fetch the PDF URL" | webFetch cannot parse PDF binary. Always use HTML versions. |
| "I'll read the entire paper at once" | Full papers are huge. Use selective mode with searchPhrase first. |
| "ar5iv doesn't work, give up" | Try arxiv.org/html/ as fallback. Only then suggest PDF attachment. |
| "I'll summarize without reading" | NEVER summarize from title/abstract alone when user asks for deep analysis. |

## Output Format

When presenting paper analysis:

```
📄 **{Title}**
Authors: {authors} | Published: {date} | arXiv: {id}

**Abstract:** {1-2 sentence summary}

**Key Contributions:**
1. {contribution 1}
2. {contribution 2}

**Methodology:** {brief description}

**Results:** {key findings}

**Relevance:** {why this matters for user's context}
```

## References

- [arXiv URL Patterns](references/arxiv-url-patterns.md) — Load when: need to construct URLs or use arXiv API
