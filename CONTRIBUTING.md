# Contributing to AIE-Skills

## Adding a New Skill

1. Read [Skill Creation Best Practices](docs/skill-creation-best-practices.md)
2. Create skill directory: `.kiro/skills/<skill-name>/SKILL.md`
3. Add `references/` directory if SKILL.md exceeds ~200 lines
4. Update [Skill Interconnection Map](docs/skill-interconnection-map.md)
5. Add to appropriate profile in `lib/profiles.sh` AND `install.sh`
6. Update README.md skills table
7. Run tests: `bats tests/`

### Skill Checklist
- [ ] SKILL.md has valid frontmatter (name, description with "Use when...")
- [ ] Description contains specific keywords for activation
- [ ] Scope boundary defined ("Does NOT handle: → other-skill")
- [ ] Added to profile function or standalone list in `all_skills()`
- [ ] Interconnection map updated

## Adding a New Profile

1. Create `profile_<name>()` function in `lib/profiles.sh` AND `install.sh`
2. Add steering mapping in `resolve_steering()` if needed
3. Add to `--list` output and `--help` text in `install.sh`
4. Add tests in `tests/test_profile_functions.bats`
5. Update README.md profiles table

## Modifying Steering

1. Follow [Kiro Compatible Guide](docs/kiro-compatible.md) for frontmatter
2. Check domain overlap with existing steering (one file = one domain)
3. Update `resolve_steering()` if profile-mapped
4. Run tests: `bats tests/test_resolve_steering.bats`

## Running Tests

```bash
# Install bats-core (if not installed)
# macOS: brew install bats-core
# Ubuntu: apt install bats

# Run all tests
bats tests/

# Run specific test file
bats tests/test_profile_functions.bats

# Run with verbose output
bats --verbose-run tests/
```

## Keeping lib/ and install.sh in Sync

Profile functions exist in both `lib/profiles.sh` (for tests) and `install.sh` (for curl | bash). When modifying profiles:

1. Edit `lib/profiles.sh` first
2. Copy changes to `install.sh`
3. Run `bats tests/` to verify

## Commit Convention

```
feat(skill): add <skill-name>
feat(profile): add <profile-name> profile
feat(installer): add --flag-name flag
fix(installer): <description>
docs: update <what>
test: add tests for <what>
```
