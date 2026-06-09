#!/usr/bin/env python3
"""
Skill Effectiveness Analyzer

Reads .kiro/metrics/skill-usage.jsonl and produces a summary report showing:
- Which skills are activated most frequently
- Success rate per skill
- Average retry count per skill
- Skills that are never activated (potential candidates for removal)

Usage:
    python analyze-skill-effectiveness.py [--metrics-file PATH] [--json]
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def load_metrics(metrics_file: Path) -> list[dict]:
    """Load JSONL metrics file."""
    entries = []
    if not metrics_file.exists():
        return entries
    with open(metrics_file, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"Warning: Invalid JSON at line {line_num}, skipping", file=sys.stderr)
    return entries


def get_all_skills(project_root: Path) -> set[str]:
    """Get all installed skill names."""
    skills_dir = project_root / ".kiro" / "skills"
    if not skills_dir.exists():
        return set()
    return {
        d.name for d in skills_dir.iterdir()
        if d.is_dir() and not d.name.startswith(".")
    }


def analyze(entries: list[dict], all_skills: set[str]) -> dict:
    """Analyze metrics entries."""
    skill_stats = defaultdict(lambda: {
        "activations": 0,
        "successes": 0,
        "failures": 0,
        "partial": 0,
        "total_retries": 0,
    })

    total_sessions = len(entries)
    total_successful = 0

    for entry in entries:
        skills = entry.get("skills_activated", [])
        success = entry.get("task_success")
        retries = entry.get("retry_count", 0)

        if success is True:
            total_successful += 1

        for skill in skills:
            stats = skill_stats[skill]
            stats["activations"] += 1
            stats["total_retries"] += retries
            if success is True:
                stats["successes"] += 1
            elif success is False:
                stats["failures"] += 1
            else:
                stats["partial"] += 1

    # Calculate derived metrics
    skill_reports = []
    for skill, stats in sorted(skill_stats.items(), key=lambda x: x[1]["activations"], reverse=True):
        total = stats["activations"]
        success_rate = stats["successes"] / total if total > 0 else 0
        avg_retries = stats["total_retries"] / total if total > 0 else 0
        skill_reports.append({
            "name": skill,
            "activations": total,
            "success_rate": round(success_rate, 2),
            "avg_retries": round(avg_retries, 1),
            "failures": stats["failures"],
        })

    # Find never-activated skills
    activated_skills = set(skill_stats.keys())
    never_activated = sorted(all_skills - activated_skills)

    return {
        "period": {
            "total_sessions": total_sessions,
            "first_entry": entries[0].get("timestamp", "unknown") if entries else None,
            "last_entry": entries[-1].get("timestamp", "unknown") if entries else None,
        },
        "overall": {
            "total_sessions": total_sessions,
            "success_rate": round(total_successful / total_sessions, 2) if total_sessions > 0 else 0,
            "unique_skills_used": len(activated_skills),
            "total_skills_installed": len(all_skills),
        },
        "per_skill": skill_reports,
        "never_activated": never_activated,
    }


def main():
    parser = argparse.ArgumentParser(description="Analyze skill effectiveness metrics")
    parser.add_argument(
        "--metrics-file",
        default=".kiro/metrics/skill-usage.jsonl",
        help="Path to metrics JSONL file",
    )
    parser.add_argument(
        "--project-root",
        default=".",
        help="Path to project root (for finding installed skills)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON",
    )
    args = parser.parse_args()

    metrics_file = Path(args.metrics_file)
    project_root = Path(args.project_root)

    entries = load_metrics(metrics_file)
    if not entries:
        if args.json:
            print(json.dumps({"error": "No metrics data found", "file": str(metrics_file)}))
        else:
            print(f"No metrics data found at {metrics_file}")
            print("The skill-effectiveness-tracking hook generates this data automatically.")
            print("Use the project for a while and re-run this script.")
        sys.exit(0)

    all_skills = get_all_skills(project_root)
    report = analyze(entries, all_skills)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"\n{'='*60}")
        print(f"  Skill Effectiveness Report")
        print(f"  Sessions: {report['overall']['total_sessions']} | "
              f"Overall success rate: {report['overall']['success_rate']*100:.0f}%")
        print(f"  Skills used: {report['overall']['unique_skills_used']}/{report['overall']['total_skills_installed']}")
        print(f"{'='*60}\n")

        if report["per_skill"]:
            print("  Top skills by activation:\n")
            print(f"  {'Skill':<30} {'Used':>5} {'Success':>8} {'Avg Retries':>12}")
            print(f"  {'─'*30} {'─'*5} {'─'*8} {'─'*12}")
            for s in report["per_skill"][:20]:
                success_pct = f"{s['success_rate']*100:.0f}%"
                print(f"  {s['name']:<30} {s['activations']:>5} {success_pct:>8} {s['avg_retries']:>12}")
            print()

        if report["never_activated"]:
            print(f"  ⚠ Never activated ({len(report['never_activated'])} skills):")
            print(f"  Consider reviewing whether these skills are needed:\n")
            for skill in report["never_activated"]:
                print(f"    • {skill}")
            print()

        # Flag problematic skills
        problematic = [s for s in report["per_skill"] if s["success_rate"] < 0.5 and s["activations"] >= 3]
        if problematic:
            print(f"  🔴 Low success rate (< 50%, ≥ 3 activations):\n")
            for s in problematic:
                print(f"    • {s['name']}: {s['success_rate']*100:.0f}% success, "
                      f"{s['avg_retries']} avg retries")
            print()

    sys.exit(0)


if __name__ == "__main__":
    main()
