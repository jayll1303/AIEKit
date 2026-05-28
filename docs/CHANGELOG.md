# Changelog

All notable changes to AIE-Skills.

## [2.3.0] — 2026-05-28

### Added
- `modal-batch-processing` skill — Modal job orchestration with `.map`, `.starmap`, `.spawn`, `.spawn_map`, `@modal.batched`
- `modal-sandbox` skill — Modal Sandbox lifecycle: isolated execution, tunnels, snapshots, filesystem API
- **Modal** profile (2 skills) added to profiles list

### Notes
- Skills updated to Modal SDK 1.4.3 (2026-05-18):
  - `modal-sandbox`: uses new `sb.filesystem.*` API (replaces deprecated `sandbox.open/ls/mkdir/rm`), readiness probes, `inbound/outbound_cidr_allowlist`, `snapshot_directory()` as root filesystem
  - `modal-batch-processing`: documents `Function.with_options()`, `Function.with_batching()`, `routing_region`, deployment strategies

## [2.2.0] — 2026-04-10

### Added
- `--skill` now supports comma-separated skill names: `--skill yolo,paddleocr`
- `--json` / `-j` flag — machine-readable JSON output for agent/programmatic use
- `resolve_skill_steering()` — skill-level steering mapping (individual skill → steering files)
- `resolve_skills_steering()` — collect and deduplicate steering for multiple skills
- Steering auto-install for `--skill` mode (previously skipped)
- `--list` now shows all available skills in addition to profiles
- JSON output tests (`tests/test_json_output.bats`)
- Skill-level steering mapping tests (`tests/test_skill_steering.bats`)
- Comma-separated skill + steering integration tests

### Changed
- `aie-skills-installer` SKILL.md: agent now calls `install.sh --skill --json` instead of copying files directly
- `--skill` mode no longer skips steering — uses skill-level mapping
- README updated with `--skill` comma-separated and `--json` examples

## [2.1.0] — 2026-04-09

### Added
- `--dry-run` / `-n` flag — preview installation without making changes
- `--list` / `-l` flag — show available profiles and skill counts
- `--update` / `--force` / `-f` flag — overwrite existing components
- `--skill` / `-s` flag — install a single skill by name
- `lib/profiles.sh` — extracted profile functions for testability
- Copy failure warnings (previously silent `|| true`)
- Source structure validation (checks skills/ and steering/ after clone)
- Idempotency tests, powers install tests, steering conversion tests
- Steering skip-if-exists tests
- Troubleshooting guide (`docs/troubleshooting.md`)
- This changelog

### Changed
- Steering frontmatter conversion now uses portable pure-bash approach (no `sed -i`)
- `test_helper.bash` sources `lib/profiles.sh` directly (no fragile sed extraction)
- `create_mock_source()` now includes mock powers
- Summary output shows failed/updated counts

### Fixed
- `sed -i` steering conversion was not portable across GNU/BSD
- `sed -i` multiline replacement could corrupt frontmatter
- CRLF line endings could break steering conversion

## [2.0.0] — 2026-04-09

### Breaking Changes
- Default install now installs 6 core skills only (was 29)
- Hooks no longer installed to target projects

### Added
- Profile-based installation (`--profile llm`, `--profile inference`, etc.)
- Combine profiles: `--profile llm,inference`
- `--powers` / `-p` flag for optional MCP power installation
- `ml-brainstorm` skill (standalone, Meta Layer)
- Steering auto-mapping per profile
- Idempotent installation (skip existing, no overwrite)

### Changed
- `kiro-component-creation.md` steering converted from `always` to `auto` on install
- Installer output shows profile-aware next steps
- `--all` flag preserved for backward compatibility (installs all 30 skills)

## [1.0.0] — 2026-04-03

### Added
- Initial release with 29 skills, 6 steering, 6 hooks
- One-liner remote installer
- Smart installer skill (`aie-skills-installer`)
- 3 MCP Powers (HuggingFace, GPU Monitor, Sentry)
- 6 development-only hooks
- 6 steering files
- BATS test suite
