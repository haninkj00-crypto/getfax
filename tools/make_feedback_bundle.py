#!/usr/bin/env python3
"""Assemble compiler/profile/log/source context for an AI-assisted porting round."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GENERATED_FILES = (
    "fax_port.h", "fax_core.h", "fax_core.c", "fax_tables.c", "fax_thread.h", "fax_thread.c", "test_fax.c",
    "fax_engine.h", "fax_engine.c", "fax_g3.c", "fax_engine_test.c",
    "fax_default_params.h", "fax_default_params.c", "default_params.json",
)
TEMPLATE_FILES = (
    "fax_port.h.in", "fax_core.h.in", "fax_core.c.in", "fax_tables.c.in", "test_fax.c.in",
    "fax_engine.h.in", "fax_engine.c.in", "fax_g3.c.in", "fax_engine_test.c.in",
    "fax_default_params.h.in", "fax_default_params.c.in",
)


def read_text(path: Path, encoding: str = "utf-8") -> str:
    try:
        return path.read_text(encoding=encoding, errors="replace")
    except (OSError, LookupError) as exc:
        raise ValueError("cannot read {} with encoding {}: {}".format(path, encoding, exc)) from exc


def fenced(text: str, language: str = "text") -> str:
    marker = "```" if "```" not in text else "````"
    return "{0}{1}\n{2}\n{0}".format(marker, language, text.rstrip())


def append_file(parts, heading: str, path: Path, language: str) -> None:
    if path.is_file():
        parts.extend(["", "### {}".format(heading), fenced(read_text(path), language)])
    else:
        parts.extend(["", "### {} (MISSING)".format(heading)])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--generated", required=True, help="directory produced by generator.py")
    ap.add_argument("--profile", required=True, help="profile JSON used for generation")
    ap.add_argument("--project-root", help="project root; defaults to generated/../..")
    ap.add_argument("--compiler-version", default="not supplied")
    ap.add_argument("--command", default="not supplied")
    ap.add_argument("--log", required=True, help="compiler output log")
    ap.add_argument("--log-encoding", default="utf-8", help="compiler log encoding (e.g. utf-8, cp949, cp437)")
    ap.add_argument("--round", type=int, required=True)
    ap.add_argument("--out", required=True, help="output Markdown file")
    args = ap.parse_args(argv)

    generated = Path(args.generated).resolve()
    profile_path = Path(args.profile).resolve()
    log_path = Path(args.log).resolve()
    project_root = Path(args.project_root).resolve() if args.project_root else generated.parent.parent
    if args.round < 1 or args.round > 10:
        ap.error("--round must be between 1 and 10")

    try:
        build_info = json.loads(read_text(generated / "build_info.json"))
        profile_text = read_text(profile_path)
        log_text = read_text(log_path, args.log_encoding)
    except (ValueError, json.JSONDecodeError) as exc:
        print("error: {}".format(exc), file=sys.stderr)
        return 2

    parts = [
        "# AI compiler feedback bundle",
        "",
        "## Round and environment",
        "- Round: {} / target maximum: 10".format(args.round),
        "- Profile: {}".format(profile_path),
        "- Project root: {}".format(project_root),
        "- Compiler version: {}".format(args.compiler_version),
        "- Build command: {}".format(args.command),
        "- Log encoding: {}".format(args.log_encoding),
        "- Generator build command: {}".format(build_info.get("build_command", "unknown")),
        "- Generator version: {}".format(build_info.get("generator_version", "unknown")),
        "- Parameters: {}".format(json.dumps(build_info.get("parameters", {}), ensure_ascii=False)),
        "",
        "## Compiler output (complete log)",
        fenced(log_text),
        "",
        "## Profile JSON",
        fenced(profile_text, "json"),
        "",
        "## Build manifest",
        fenced(json.dumps(build_info, ensure_ascii=False, indent=2), "json"),
        "",
        "## Generated sources",
    ]

    for filename in GENERATED_FILES:
        append_file(parts, filename, generated / filename, "c")

    parts.extend(["", "## Generator templates (edit these, not only generated output)"])
    for filename in TEMPLATE_FILES:
        append_file(parts, filename, project_root / "templates" / filename, "c")
    append_file(parts, "generator.py", project_root / "generator.py", "python")

    parts.extend([
        "",
        "## Required response format",
        "1. Identify the first/root error and distinguish it from cascaded diagnostics.",
        "2. Explain the compiler-specific cause.",
        "3. Return a minimal unified diff against the generator template or profile.",
        "4. Give the exact regeneration and rebuild commands.",
        "5. Add or update a regression test; do not merely silence diagnostics.",
        "6. State any assumptions that remain unverified.",
        "",
        "Do not claim the target compiler is supported until the generated sources compile and the smoke test runs on that compiler.",
    ])

    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print("Wrote {} ({} bytes)".format(output.resolve(), output.stat().st_size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
