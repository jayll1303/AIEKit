# Mutation Testing with mutmut

Advanced guide for mutation testing setup, configuration, result interpretation, CI integration, and strategies for prioritizing surviving mutants.

> **Quick start**: See the [main SKILL.md](../SKILL.md#mutation-testing-quick-start) for basic install and run commands.

## Configuration

### Full `pyproject.toml` Reference

```toml
[tool.mutmut]
# Source code to mutate (required)
paths_to_mutate = "src/"

# Test directory
tests_dir = "tests/"

# Test runner command — use -x to stop on first failure (faster)
runner = "python -m pytest -x --tb=short -q"

# Glob patterns for files to mutate (optional, narrows scope)
# paths_to_mutate takes directories; use dict_synonyms or regex for finer control
dict_synonyms = ["Struct", "NamedStruct"]

# Backup original files (default: true)
backup = false
```

### Scoping Mutations

Limit mutation runs to specific modules for faster feedback:

```bash
# Mutate only a single file
uv run mutmut run --paths-to-mutate src/pipeline/transform.py

# Mutate only specific tests (useful for focused iteration)
uv run mutmut run --tests-dir tests/unit/

# Run a single mutant by ID (for debugging)
uv run mutmut run --mutation <mutant-id>
```

### Parallelization

mutmut runs mutants sequentially by default. For large codebases, use `--parallel`:

```bash
# Use all available cores
uv run mutmut run --parallel

# Or combine with a fast test runner
# In pyproject.toml:
# runner = "python -m pytest -x --tb=line -q --timeout=10"
```

> **Tip**: Add `--timeout=10` to your pytest runner to kill mutants that cause infinite loops quickly.

## Interpreting Results

### Result Categories

After a run, `mutmut results` shows a summary:

```
Survived 🙁:  12
Killed ✓:     87
Timeout ⏰:    3
Suspicious 🤔: 1
```

| Status | What It Means | Action |
|---|---|---|
| Killed | Your tests detected the mutation — test is effective | None needed |
| Survived | Tests passed despite the mutation — gap in coverage | Write a test targeting this code path |
| Timeout | Mutation caused an infinite loop or extreme slowdown | Usually safe to ignore; may indicate missing loop bounds |
| Suspicious | Unexpected exit code or crash | Investigate — may be a flaky test or environment issue |

### Inspecting Surviving Mutants

```bash
# List all surviving mutant IDs
uv run mutmut results

# Show the diff for a specific mutant
uv run mutmut show <mutant-id>

# Example output:
# --- src/pipeline/transform.py
# +++ src/pipeline/transform.py (mutant)
# @@ -42,7 +42,7 @@
#  def normalize(values: list[float]) -> list[float]:
#      total = sum(values)
# -    return [v / total for v in values]
# +    return [v * total for v in values]
```

### Common Mutation Operators

mutmut applies these transformations to your source code:

| Operator | Example Original | Example Mutant |
|---|---|---|
| Arithmetic | `a + b` | `a - b` |
| Comparison | `x > 0` | `x >= 0`, `x < 0` |
| Boolean | `True` | `False` |
| Return value | `return x` | `return None` |
| Keyword | `break` | `continue` |
| Number literal | `0` | `1` |
| String literal | `"hello"` | `"XXhelloXX"` |
| Negate condition | `if x:` | `if not x:` |

Understanding which operator produced a survivor helps you write the right test.

## Killing Surviving Mutants

### Workflow

1. Run `uv run mutmut show <id>` to see the mutation diff
2. Identify what behavior changed (e.g., `+` became `-`)
3. Write a test that asserts the correct behavior for that code path
4. Re-run mutmut to confirm the mutant is now killed

### Example: Killing an Arithmetic Mutant

Surviving mutant diff:

```python
# Original
def discount_price(price: float, rate: float) -> float:
    return price * (1 - rate)

# Mutant: changed - to +
def discount_price(price: float, rate: float) -> float:
    return price * (1 + rate)
```

Test that kills it:

```python
def test_discount_reduces_price():
    """A 20% discount on $100 should yield $80, not $120."""
    result = discount_price(100.0, 0.2)
    assert result == pytest.approx(80.0)
```

## CI Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/mutation-testing.yml
name: Mutation Testing

on:
  pull_request:
    paths:
      - "src/**/*.py"
      - "tests/**/*.py"

jobs:
  mutmut:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v4

      - name: Install dependencies
        run: uv sync --dev

      - name: Run mutation testing
        run: |
          uv run mutmut run --no-progress 2>&1 | tee mutmut-output.txt
          uv run mutmut results | tee -a mutmut-output.txt

      - name: Check mutation score
        run: |
          # Extract killed and total counts
          KILLED=$(grep -oP 'Killed.*?(\d+)' mutmut-output.txt | grep -oP '\d+')
          SURVIVED=$(grep -oP 'Survived.*?(\d+)' mutmut-output.txt | grep -oP '\d+')
          TOTAL=$((KILLED + SURVIVED))

          if [ "$TOTAL" -eq 0 ]; then
            echo "No mutants generated"
            exit 0
          fi

          SCORE=$((KILLED * 100 / TOTAL))
          echo "Mutation score: ${SCORE}% (${KILLED}/${TOTAL})"

          # Fail if score drops below threshold
          if [ "$SCORE" -lt 80 ]; then
            echo "::error::Mutation score ${SCORE}% is below 80% threshold"
            exit 1
          fi

      - name: Generate HTML report
        if: always()
        run: uv run mutmut html

      - name: Upload mutation report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: html/
```

### Key CI Considerations

- **Run on PR only for changed files**: Mutation testing is slow. Scope it to changed source paths.
- **Set a score threshold**: Start with 70-80% and raise it as your suite matures.
- **Cache dependencies**: Add `uv cache` step to speed up installs.
- **Timeout protection**: Set `runner = "python -m pytest -x --timeout=30"` to prevent hanging mutants.
- **Incremental runs**: On large codebases, mutate only files changed in the PR:

```bash
# Get changed Python files from the PR
CHANGED=$(git diff --name-only origin/main -- 'src/**/*.py' | tr '\n' ',')
uv run mutmut run --paths-to-mutate "$CHANGED"
```

## Prioritizing Surviving Mutants

Not all surviving mutants are equally important. Use this priority framework:

### Priority 1: Business Logic Mutations

Mutants in code that implements core business rules or domain logic. These are the most dangerous gaps.

**Signals**: mutations in functions that calculate prices, validate inputs, transform data, or make decisions.

### Priority 2: Boundary and Comparison Mutations

Mutants that change comparison operators (`>` to `>=`, `==` to `!=`). Off-by-one and boundary errors are a common source of production bugs.

**Signals**: mutations in loop bounds, range checks, threshold comparisons.

### Priority 3: Error Handling Mutations

Mutants in exception handling, validation, or guard clauses. If a mutant removes a `raise` or changes an error condition and tests still pass, your error paths are untested.

**Signals**: mutations in `if ... raise`, `try/except`, validation functions.

### Priority 4: Return Value Mutations

Mutants that change return values (e.g., `return x` → `return None`). These indicate your tests don't assert on the actual output.

**Signals**: mutations in `return` statements, especially in utility functions.

### Lower Priority: Cosmetic and Logging Mutations

Mutants in logging statements, string formatting, or debug output. These rarely indicate real test gaps.

**When to ignore**: mutations in `logger.info(...)`, `print(...)`, or `__repr__` methods.

### Triage Checklist

For each surviving mutant, ask:

1. **Is this code path reachable in production?** If not, consider marking it as acceptable.
2. **Would this mutation cause a user-visible bug?** If yes, write a test immediately.
3. **Is the mutation in a hot path or critical calculation?** Prioritize accordingly.
4. **Is the surviving mutant equivalent?** Some mutations produce logically identical code (e.g., `x * 1` → `x * 1`). These are false positives — no test can kill them.

### Equivalent Mutants

An equivalent mutant produces the same behavior as the original code (e.g., mutating `sorted(xs)` to `sorted(xs, reverse=False)`). These inflate your "survived" count. When you identify one, document it and move on.

## Integration with Hypothesis

Combine property-based tests with mutation testing for maximum coverage:

```python
from hypothesis import given, settings
import hypothesis.strategies as st

@given(values=st.lists(st.floats(allow_nan=False, allow_infinity=False, min_value=0.01), min_size=1))
@settings(max_examples=50)
def test_normalize_sums_to_one(values: list[float]) -> None:
    """Property: normalized values always sum to ~1.0.

    This test kills arithmetic mutants in normalize() because
    any change to the division logic breaks the sum-to-one invariant.
    """
    result = normalize(values)
    assert abs(sum(result) - 1.0) < 1e-6
```

Property-based tests are effective mutant killers because they test invariants across many inputs, making it hard for mutations to slip through.

> **See also**: [Hypothesis Strategies](hypothesis-strategies.md) for strategy recipes, [Property Patterns](property-patterns.md) for more property types