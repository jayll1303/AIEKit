#!/usr/bin/env python3
"""
Skill Staleness Detection Script

Scans all SKILL.md files for version references and "Tested with" markers,
then flags skills that may be outdated based on:
1. Missing version pins (no "Tested with" line)
2. Version references older than a configurable threshold
3. References to tools/libraries with known recent major releases

Usage:
    python check-skill-staleness.py [--skills-dir PATH] [--max-age-days N] [--json]

Output:
    Report of potentially stale skills with actionable recommendations.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional


# Known tools and their latest major versions (update periodically)
# Format: tool_name -> (latest_version_prefix, release_date_approx)
KNOWN_VERSIONS = {
    "vllm": ("0.8", "2026-05"),
    "vLLM": ("0.8", "2026-05"),
    "tgi": ("3.0", "2026-04"),
    "TGI": ("3.0", "2026-04"),
    "torch": ("2.6", "2026-04"),
    "PyTorch": ("2.6", "2026-04"),
    "transformers": ("4.50", "2026-05"),
    "CUDA": ("12.6", "2026-03"),
    "sglang": ("0.5", "2026-05"),
    "SGLang": ("0.5", "2026-05"),
    "triton": ("2.54", "2026-04"),
    "ollama": ("0.6", "2026-05"),
    "Ollama": ("0.6", "2026-05"),
    "unsloth": ("2025.5", "2026-05"),
    "Unsloth": ("2025.5", "2026-05"),
    "ultralytics": ("8.4", "2026-05"),
    "modal": ("1.4", "2026-05"),
    "Modal": ("1.4", "2026-05"),
    "trl": ("0.16", "2026-05"),
    "TRL": ("0.16", "2026-05"),
    "peft": ("0.15", "2026-05"),
    "PEFT": ("0.15", "2026-05"),
    "llama.cpp": ("b5000", "2026-05"),
    "llama-cpp-python": ("0.3", "2026-05"),
    "faiss": ("1.9", "2026-03"),
    "chromadb": ("0.6", "2026-04"),
    "sentence-transformers": ("4.0", "2026-04"),
    "ruff": ("0.9", "2026-05"),
    "uv": ("0.7", "2026-05"),
}


@dataclass
class VersionRef:
    """A version reference found in a skill file."""
    tool: str
    version_found: str
    latest_known: str
    line_number: int
    line_content: str
    potentially_stale: bool = False


@dataclass
class SkillReport:
    """Staleness report for a single skill."""
    name: str
    path: str
    has_tested_with: bool = False
    tested_with_line: str = ""
    tested_with_date: Optional[str] = None
    version_refs: list = field(default_factory=list)
    issues: list = field(default_factory=list)
    severity: str = "ok"  # ok, warning, stale


def find_skills_dir(start_path: str) -> Path:
    """Find the .kiro/skills directory."""
    path = Path(start_path)
    skills_dir = path / ".kiro" / "skills"
    if skills_dir.exists():
        return skills_dir
    # Try parent directories
    for parent in path.parents:
        skills_dir = parent / ".kiro" / "skills"
        if skills_dir.exists():
            return skills_dir
    return Path(start_path) / ".kiro" / "skills"


def parse_tested_with(content: str) -> tuple[Optional[str], Optional[str]]:
    """Extract 'Tested with' line and date if present."""
    # Match patterns like: > Tested with: vLLM 0.8.x, PyTorch 2.5, CUDA 12.4 (June 2026)
    pattern = r"[>*_]*\s*Tested with:?\s*(.+?)(?:\(([A-Za-z]+ \d{4})\))?"
    match = re.search(pattern, content, re.IGNORECASE)
    if match:
        line = match.group(0).strip()
        date = match.group(2) if match.group(2) else None
        return line, date
    return None, None


def extract_version_refs(content: str, filepath: str) -> list[VersionRef]:
    """Find version references in skill content."""
    refs = []
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        for tool, (latest, _) in KNOWN_VERSIONS.items():
            # Match patterns like: vllm 0.6.x, torch>=2.0, vLLM 0.5.4
            patterns = [
                rf"\b{re.escape(tool)}[>=<~\s]+(\d+\.\d+(?:\.\d+)?(?:\.x)?)",
                rf"\b{re.escape(tool)}:(\d+\.\d+(?:\.\d+)?)",
            ]
            for pattern in patterns:
                matches = re.finditer(pattern, line, re.IGNORECASE)
                for match in matches:
                    version_found = match.group(1).rstrip(".x")
                    # Compare major.minor
                    try:
                        found_parts = [int(x) for x in version_found.split(".")[:2]]
                        latest_parts = [int(x) for x in latest.split(".")[:2]]
                        potentially_stale = found_parts < latest_parts
                    except (ValueError, IndexError):
                        potentially_stale = False

                    refs.append(VersionRef(
                        tool=tool,
                        version_found=version_found,
                        latest_known=latest,
                        line_number=i,
                        line_content=line.strip()[:120],
                        potentially_stale=potentially_stale,
                    ))
    return refs


def analyze_skill(skill_dir: Path, max_age_days: int) -> SkillReport:
    """Analyze a single skill for staleness."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return SkillReport(
            name=skill_dir.name,
            path=str(skill_md),
            issues=["Missing SKILL.md"],
            severity="warning",
        )

    content = skill_md.read_text(encoding="utf-8")
    report = SkillReport(name=skill_dir.name, path=str(skill_md))

    # Check for "Tested with" line
    tested_line, tested_date = parse_tested_with(content)
    if tested_line:
        report.has_tested_with = True
        report.tested_with_line = tested_line
        report.tested_with_date = tested_date
    else:
        report.issues.append("No 'Tested with' version pin found")

    # Check date staleness
    if tested_date:
        try:
            date_obj = datetime.strptime(tested_date, "%B %Y")
            age = datetime.now() - date_obj
            if age > timedelta(days=max_age_days):
                report.issues.append(
                    f"Tested-with date '{tested_date}' is {age.days} days old (threshold: {max_age_days})"
                )
        except ValueError:
            pass

    # Check version references
    report.version_refs = extract_version_refs(content, str(skill_md))
    stale_refs = [r for r in report.version_refs if r.potentially_stale]
    if stale_refs:
        for ref in stale_refs:
            report.issues.append(
                f"Line {ref.line_number}: {ref.tool} {ref.version_found} "
                f"(latest known: {ref.latest_known})"
            )

    # Also scan references/ directory
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in refs_dir.glob("*.md"):
            ref_content = ref_file.read_text(encoding="utf-8")
            ref_versions = extract_version_refs(ref_content, str(ref_file))
            stale_ref_versions = [r for r in ref_versions if r.potentially_stale]
            for ref in stale_ref_versions:
                report.issues.append(
                    f"[{ref_file.name}] Line {ref.line_number}: {ref.tool} {ref.version_found} "
                    f"(latest known: {ref.latest_known})"
                )
            report.version_refs.extend(ref_versions)

    # Determine severity
    if not report.issues:
        report.severity = "ok"
    elif any("stale" in i.lower() or "latest known" in i.lower() for i in report.issues):
        report.severity = "stale"
    else:
        report.severity = "warning"

    return report


def main():
    parser = argparse.ArgumentParser(description="Check AIE-Skills for staleness")
    parser.add_argument(
        "--skills-dir",
        default=".",
        help="Path to project root or .kiro/skills directory",
    )
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=90,
        help="Maximum age in days before a 'Tested with' date is flagged (default: 90)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON for programmatic consumption",
    )
    args = parser.parse_args()

    skills_dir = find_skills_dir(args.skills_dir)
    if not skills_dir.exists():
        print(f"Error: Skills directory not found at {skills_dir}", file=sys.stderr)
        sys.exit(1)

    reports = []
    for skill_dir in sorted(skills_dir.iterdir()):
        if skill_dir.is_dir() and not skill_dir.name.startswith("."):
            report = analyze_skill(skill_dir, args.max_age_days)
            reports.append(report)

    # Output
    if args.json:
        output = {
            "scan_date": datetime.now().isoformat(),
            "skills_dir": str(skills_dir),
            "max_age_days": args.max_age_days,
            "summary": {
                "total": len(reports),
                "ok": sum(1 for r in reports if r.severity == "ok"),
                "warning": sum(1 for r in reports if r.severity == "warning"),
                "stale": sum(1 for r in reports if r.severity == "stale"),
            },
            "skills": [
                {
                    "name": r.name,
                    "severity": r.severity,
                    "has_tested_with": r.has_tested_with,
                    "tested_with_date": r.tested_with_date,
                    "issues": r.issues,
                }
                for r in reports
            ],
        }
        print(json.dumps(output, indent=2))
    else:
        # Human-readable output
        stale = [r for r in reports if r.severity == "stale"]
        warnings = [r for r in reports if r.severity == "warning"]
        ok = [r for r in reports if r.severity == "ok"]

        print(f"\n{'='*60}")
        print(f"  AIE-Skills Staleness Report")
        print(f"  Scanned: {len(reports)} skills | Date: {datetime.now().strftime('%Y-%m-%d')}")
        print(f"  Threshold: {args.max_age_days} days")
        print(f"{'='*60}\n")

        if stale:
            print(f"🔴 STALE ({len(stale)} skills) — version references outdated:\n")
            for r in stale:
                print(f"  {r.name}")
                for issue in r.issues:
                    print(f"    └─ {issue}")
                print()

        if warnings:
            print(f"🟡 WARNING ({len(warnings)} skills) — missing version pin:\n")
            for r in warnings:
                print(f"  {r.name}")
                for issue in r.issues:
                    print(f"    └─ {issue}")
                print()

        if ok:
            print(f"🟢 OK ({len(ok)} skills) — up to date\n")
            for r in ok:
                pin = f" [{r.tested_with_date}]" if r.tested_with_date else ""
                print(f"  ✓ {r.name}{pin}")

        print(f"\n{'─'*60}")
        print(f"  Summary: {len(ok)} ok | {len(warnings)} warnings | {len(stale)} stale")
        print(f"{'─'*60}\n")

        if stale or warnings:
            print("  Recommended actions:")
            if stale:
                print("  1. Update stale skills with current tool versions")
                print("     Add/update: > Tested with: <tool> <version> (<Month Year>)")
            if warnings:
                print("  2. Add 'Tested with' version pin to flagged skills")
            print()

    sys.exit(1 if stale else 0)


if __name__ == "__main__":
    main()
