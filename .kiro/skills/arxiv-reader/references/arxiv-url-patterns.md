# arXiv URL Patterns & API Reference

Load when: constructing arXiv URLs, using arXiv API, or handling edge cases with paper IDs.

## Paper ID Formats

| Format | Example | Era |
|--------|---------|-----|
| New format (2007+) | `2301.07041` | YYMM.NNNNN |
| New with version | `2301.07041v2` | YYMM.NNNNNvN |
| Old format (pre-2007) | `hep-th/9901001` | category/YYMMNNN |

To extract ID from URL:
- `https://arxiv.org/abs/2301.07041` → `2301.07041`
- `https://arxiv.org/abs/2301.07041v2` → `2301.07041v2` (or `2301.07041` without version)
- `https://ar5iv.labs.arxiv.org/html/2301.07041` → `2301.07041`

## URL Endpoints

### Abstract Page (quick metadata)
```
https://arxiv.org/abs/{id}
```
Returns: HTML page with title, authors, abstract, categories, submission dates.
Best for: Quick overview, deciding if paper is relevant.

### ar5iv HTML (full paper reading)
```
https://ar5iv.labs.arxiv.org/html/{id}
```
Returns: Full paper rendered as HTML from LaTeX source.
Best for: Reading full paper content, specific sections.
Caveat: Some papers with complex LaTeX may not render. ~97% coverage.

### arxiv Native HTML (newer papers)
```
https://arxiv.org/html/{id}
```
Returns: arxiv's own HTML rendering (available for papers submitted with HTML support).
Best for: Fallback when ar5iv fails, newer papers.

### arXiv API (structured metadata)
```
https://export.arxiv.org/api/query?id_list={id1},{id2}
https://export.arxiv.org/api/query?search_query=all:{keyword}&max_results=10
```
Returns: Atom XML with structured metadata (title, authors, abstract, categories, dates).
Best for: Batch metadata retrieval, programmatic search.

## webFetch Strategy by Use Case

| Use Case | URL | mode | searchPhrase |
|----------|-----|------|-------------|
| Get abstract | arxiv.org/abs/{id} | truncated | — |
| Read specific section | ar5iv.labs.arxiv.org/html/{id} | selective | section name or key term |
| Read full paper | ar5iv.labs.arxiv.org/html/{id} | full | — |
| Search by keyword | Use remote_web_search instead | — | — |
| Batch metadata | export.arxiv.org/api/query?... | truncated | — |

## arXiv Categories (common)

| Category | Field |
|----------|-------|
| cs.AI | Artificial Intelligence |
| cs.CL | Computation and Language (NLP) |
| cs.CV | Computer Vision |
| cs.LG | Machine Learning |
| cs.SE | Software Engineering |
| stat.ML | Machine Learning (Statistics) |
| math.OC | Optimization and Control |

## Rate Limiting

arXiv API: be respectful, no more than 1 request per 3 seconds for API endpoint.
ar5iv: no documented rate limit, but avoid rapid sequential fetches.
webFetch/remote_web_search: governed by Kiro's built-in rate limiting.
