# Notebook Best Practices Reference

**Load when:** setup notebook workflow chuyên nghiệp với linting, testing, conversion, CI/CD.

## nbconvert — Format Conversion

```bash
# Notebook → Python script
jupyter nbconvert --to script notebook.ipynb

# Notebook → HTML (with outputs)
jupyter nbconvert --to html notebook.ipynb

# Notebook → PDF (requires LaTeX)
jupyter nbconvert --to pdf notebook.ipynb

# Notebook → Markdown
jupyter nbconvert --to markdown notebook.ipynb

# Execute notebook and save with outputs
jupyter nbconvert --to notebook --execute notebook.ipynb --output executed.ipynb
```

### Programmatic conversion

```python
import subprocess
subprocess.run([
    "jupyter", "nbconvert",
    "--to", "script",
    "--no-prompt",           # Remove cell prompts (In[1]:)
    "notebook.ipynb"
], check=True)
```

## nbstripout — Auto-clean Outputs on Commit

```bash
# Install
pip install nbstripout

# Setup git filter (per-repo)
nbstripout --install

# Manual strip
nbstripout notebook.ipynb

# Check if notebook has outputs
nbstripout --is-stripped notebook.ipynb
```

`.gitattributes` (auto-created by `--install`):

```
*.ipynb filter=nbstripout
*.zpln filter=nbstripout
*.ipynb diff=ipynb
```

## Notebook Linting — nbqa

Run standard Python linters on notebook code cells:

```bash
# Install
pip install nbqa ruff

# Lint with ruff
nbqa ruff notebook.ipynb

# Format with ruff
nbqa ruff notebook.ipynb --fix

# Type check with mypy
nbqa mypy notebook.ipynb
```

## Notebook Testing

### pytest + nbmake

```bash
pip install pytest nbmake

# Run all notebooks as tests
pytest --nbmake notebooks/

# With timeout per cell (seconds)
pytest --nbmake --nbmake-timeout=300 notebooks/

# Specific notebook
pytest --nbmake notebooks/train.ipynb
```

### testbook — Unit test notebook functions

```python
# test_notebook.py
from testbook import testbook

@testbook("notebooks/utils.ipynb", execute=True)
def test_helper_function(tb):
    func = tb.ref("my_function")
    result = func(42)
    assert result == 84
```

## Papermill — Parameterized Execution

```bash
pip install papermill

# Execute with parameters
papermill input.ipynb output.ipynb -p learning_rate 0.01 -p epochs 10
```

Notebook cần có cell tagged `parameters`:

```json
{
  "cell_type": "code",
  "metadata": {
    "tags": ["parameters"]
  },
  "source": ["learning_rate = 0.001\n", "epochs = 5"]
}
```

Papermill injects a new cell after `parameters` cell with overridden values.

## CI/CD Patterns

### GitHub Actions — Validate notebooks

```yaml
name: Notebook CI
on: [push, pull_request]
jobs:
  test-notebooks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install pytest nbmake
      - run: pytest --nbmake notebooks/ --nbmake-timeout=600
```

### Pre-commit hook — Strip outputs

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/kynan/nbstripout
    rev: 0.7.1
    hooks:
      - id: nbstripout
```

## Notebook Organization Patterns

### Naming convention

```
notebooks/
├── 01-data-exploration.ipynb
├── 02-preprocessing.ipynb
├── 03-model-training.ipynb
├── 04-evaluation.ipynb
└── utils/
    └── helpers.ipynb
```

- Prefix với số thứ tự cho workflow order
- Tên kebab-case, mô tả rõ purpose
- Tách utility code ra module Python riêng khi có thể

### Cell organization trong notebook

1. Title + description (markdown)
2. Imports + config (code)
3. Data loading (code + markdown headers)
4. Processing sections (markdown header → code cells)
5. Results/visualization (code)
6. Summary/conclusions (markdown)

## Reproducibility Checklist

- [ ] Pin package versions: `!pip install torch==2.1.0`
- [ ] Set random seeds: `torch.manual_seed(42); np.random.seed(42)`
- [ ] Document runtime environment: Python version, GPU type
- [ ] Use relative paths or configurable base paths
- [ ] Include data download/generation steps
- [ ] Clear and re-run all cells top-to-bottom before sharing
