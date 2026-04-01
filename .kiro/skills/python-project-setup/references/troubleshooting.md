# Troubleshooting: Python Project Setup with uv

Common issues and fixes for dependency resolution failures, lock file conflicts, virtual environment problems, and Python version mismatches when using uv.

## Dependency Resolution Failures

### `error: No solution found when resolving dependencies`

The resolver cannot find a set of package versions that satisfies all constraints.

**Common causes and fixes:**

1. **Conflicting version constraints** — two packages require incompatible versions of a shared dependency.

```
error: No solution found when resolving dependencies:
  ╰─▶ Because package-a>=2.0 depends on numpy>=2.0 and package-b>=1.0 depends on numpy<2.0,
      we can conclude that package-a>=2.0 and package-b>=1.0 are incompatible.
```

Fix: relax one constraint or pin to a compatible range.

```bash
# Check what each package needs
uv pip compile --no-emit-package numpy pyproject.toml

# Pin to a version both can accept
uv add "numpy>=1.26,<2"
```

2. **No wheels for your platform** — the package doesn't publish wheels for your OS/arch/Python version. Fix: `uv add my-package --no-binary my-package` to allow source builds.

3. **Yanked or missing version** — check available versions with `uv pip index versions my-package` and pin to an available one.

### `error: Failed to download and build`

```
error: Failed to download and build `my-package==1.2.3`
  Caused by: Build backend failed
```

Fix: install system build deps (`sudo apt install build-essential python3-dev`), try `uv add my-package --only-binary my-package` for a pre-built wheel, or check if a newer version ships wheels.


### `error: Resolver requires Python X.Y but found X.Z`

The `requires-python` in `pyproject.toml` doesn't match the active Python version.

```
error: The requested Python version >=3.12 is not compatible with Python 3.11.9
```

Fix:

```bash
# Check current Python version
uv python list

# Install the required version
uv python install 3.12

# Re-create venv with the correct version
uv venv --python 3.12
uv sync
```

Or relax the constraint in `pyproject.toml`:

```toml
[project]
requires-python = ">=3.11"
```

---

## Lock File Conflicts

### `error: The lockfile is outdated`

The `uv.lock` file is stale — `pyproject.toml` was modified without re-locking.

```
error: The lockfile at `uv.lock` needs to be updated, but `--locked` was provided.
```

Fix:

```bash
# Regenerate the lock file
uv lock

# Then sync the environment
uv sync
```

### Git merge conflicts in `uv.lock`

After a merge, `uv.lock` has conflict markers.

Fix: do not manually resolve lock file conflicts. Regenerate it:

```bash
# Accept either side (content doesn't matter, we'll regenerate)
git checkout --theirs uv.lock

# Regenerate from the merged pyproject.toml
uv lock

# Stage the clean lock file
git add uv.lock
git commit --no-edit
```

### `uv.lock` keeps changing between machines

Different platforms resolve to different wheels, causing lock file churn.

Fix: ensure all contributors use the same resolution strategy:

```toml
# pyproject.toml — pin resolution environment if needed
[tool.uv]
# Force resolution for a specific platform (useful for CI)
python-platform = "linux"
python-version = "3.12"
```

Or add `uv.lock` to `.gitattributes` for cleaner diffs:

```
# .gitattributes
uv.lock linguist-generated=true merge=binary
```

### Lock file version mismatch

Different uv versions produce incompatible lock files.

```
error: The lockfile was created by a newer version of uv
```

Fix:

```bash
# Update uv to the latest version
uv self update

# Or pin uv version in CI
# GitHub Actions
- uses: astral-sh/setup-uv@v4
  with:
    version: "0.5.x"
```

---

## Virtual Environment Issues

### `error: No virtual environment found`

uv cannot find a `.venv` directory.

```
error: Failed to find the project environment. Use `uv sync` to create it.
```

Fix:

```bash
# Create and sync the virtual environment
uv sync

# Or create the venv explicitly
uv venv
uv sync
```

### Wrong Python in `.venv`

The virtual environment was created with a different Python version than expected.

```bash
# Check what's in the current venv
uv run python --version

# Recreate with the correct version
rm -rf .venv
uv venv --python 3.12
uv sync
```

### `.venv` corrupted or broken

Symptoms: import errors for installed packages, `uv run` fails with module not found.

```bash
# Nuclear option: recreate from scratch
rm -rf .venv
uv sync
```

### Activated venv doesn't match uv's venv

You activated a venv manually but uv uses a different one.

```bash
# Deactivate any manually activated venv
deactivate

# Let uv manage the venv — use uv run instead of activating
uv run python my_script.py
uv run pytest
```

Best practice: prefer `uv run <cmd>` over manually activating `.venv`. This ensures uv always uses the correct environment.

### Permission errors on `.venv`

`Permission denied` when creating venv — fix ownership (`sudo chown -R $(whoami) .venv/`) or delete and recreate with `rm -rf .venv && uv sync`.

---

## Python Version Mismatches

### Installed Python not detected by uv

```bash
# List Python versions uv can find
uv python list

# Install a managed Python version
uv python install 3.12

# Pin the project to a specific version
uv python pin 3.12
```

This creates a `.python-version` file that uv (and other tools like pyenv) respect.

### `requires-python` too restrictive

`No interpreter found for Python >=3.13` — either install it (`uv python install 3.13`) or relax the constraint in `pyproject.toml`.

### Different Python versions across team

Pin the version so everyone uses the same:

```bash
uv python pin 3.12
```

```toml
[project]
requires-python = ">=3.11,<3.14"
```

Commit `.python-version` to version control.

### System Python vs uv-managed Python

uv manages its own Python installations separate from system Python:

```bash
uv python find 3.12          # see where Python comes from
uv python install 3.12       # install uv-managed (doesn't affect system)
uv venv --python 3.12        # use it
```

---

## Quick Diagnostic Commands

When something goes wrong, run these to gather context:

```bash
# Environment info
uv version                    # uv version
uv python list                # available Python versions
uv run python --version       # Python in current venv

# Dependency info
uv pip list                   # installed packages
uv pip show <package>         # package details and location
uv tree                       # dependency tree

# Reset everything
rm -rf .venv uv.lock
uv lock
uv sync
```

> **See also**: [pyproject-recipes](pyproject-recipes.md) for advanced configuration patterns that can prevent many of these issues
