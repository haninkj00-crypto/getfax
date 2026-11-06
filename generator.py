#!/usr/bin/env python3
"""Generate the portable C89 fax enhancement, optimizer and G3 TIFF sources."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, Dict, Tuple

import numpy as np

import thread_backends

ROOT = Path(__file__).resolve().parent
TEMPLATE_DIR = ROOT / "templates"
PROFILE_DIR = ROOT / "profiles"
VERSION = "0.2.0"

REQUIRED_PROFILE_KEYS = (
    "name", "compiler_id", "memory_model", "image_qualifier",
    "work_qualifier", "table_qualifier", "inline_keyword",
    "calling_convention", "restrict_keyword", "compile_command",
    "version_command", "notes",
)
PARAM_KEYS = {
    "gamma": (),
    "local_dark": ("sigma_px", "strength", "floor"),
    "clahe": ("clip",),
}


def read_json(path: Path) -> Dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ValueError("cannot read {}: {}".format(path, exc)) from exc
    except json.JSONDecodeError as exc:
        raise ValueError("invalid JSON in {}: {}".format(path, exc)) from exc
    if not isinstance(value, dict):
        raise ValueError("{} must contain a JSON object".format(path))
    return value


def validate_profile(profile: Dict[str, Any], path: Path) -> None:
    missing = [key for key in REQUIRED_PROFILE_KEYS if key not in profile]
    if missing:
        raise ValueError("profile {} is missing: {}".format(path, ", ".join(missing)))
    for key in (
        "image_qualifier", "work_qualifier", "table_qualifier",
        "inline_keyword", "calling_convention", "restrict_keyword",
    ):
        value = profile[key]
        if not isinstance(value, str):
            raise ValueError("profile key {} must be a string".format(key))
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*|", value):
            raise ValueError("profile key {} contains unsafe C tokens: {!r}".format(key, value))
    if not isinstance(profile["notes"], list) or not all(
        isinstance(item, str) for item in profile["notes"]
    ):
        raise ValueError("profile notes must be a list of strings")


def normalize_params(args: argparse.Namespace) -> Tuple[float, int, Dict[str, Any]]:
    candidate: Dict[str, Any]
    gamma = float(args.gamma)
    serpentine = int(args.serpentine)
    if args.params:
        raw = read_json(Path(args.params))
        if "best_candidate" in raw:
            raw = raw["best_candidate"]
        family = raw.get("family")
        if family not in PARAM_KEYS:
            raise ValueError("params family must be gamma, local_dark, or clahe")
        missing = [key for key in ("gamma", "serpentine") + PARAM_KEYS[family] if key not in raw]
        if missing:
            raise ValueError("params file is missing: {}".format(", ".join(missing)))
        candidate = {"family": family, "gamma": float(raw["gamma"]),
                     "serpentine": bool(raw["serpentine"])}
        for key in PARAM_KEYS[family]:
            candidate[key] = float(raw[key])
        gamma = candidate["gamma"]
        serpentine = int(candidate["serpentine"])
    else:
        candidate = {"family": "gamma", "gamma": gamma,
                     "serpentine": bool(serpentine)}
    if not math.isfinite(gamma) or not (0.05 <= gamma <= 8.0):
        raise ValueError("gamma must be finite and between 0.05 and 8.0")
    for key, value in candidate.items():
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("parameter {} must be finite".format(key))
    if candidate["family"] == "local_dark":
        if candidate["sigma_px"] <= 0 or candidate["strength"] < 0 or candidate["floor"] < 0:
            raise ValueError("local_dark sigma must be positive; strength/floor must be non-negative")
    if candidate["family"] == "clahe" and candidate["clip"] <= 0:
        raise ValueError("CLAHE clip must be positive")
    return gamma, serpentine, candidate


def make_gamma_table(gamma: float) -> str:
    source = np.arange(256, dtype=np.float32)
    values = np.clip(
        np.rint((source / 255.0) ** gamma * 255), 0, 255
    ).astype(np.uint8)
    lines = []
    for offset in range(0, 256, 8):
        lines.append("    " + ", ".join(str(int(v)) for v in values[offset:offset + 8]) + ",")
    return "\n".join(lines)


def replace_tokens(template: str, mapping: Dict[str, str], name: str) -> str:
    result = template
    for key, value in mapping.items():
        result = result.replace("@{}@".format(key), value)
    unresolved = re.findall(r"@[A-Z0-9_]+@", result)
    if unresolved:
        raise ValueError("unresolved template tokens in {}: {}".format(
            name, ", ".join(sorted(set(unresolved)))))
    return result


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def generate(profile_path: Path, outdir: Path, gamma: float,
             serpentine: int, candidate: Dict[str, Any],
             threads: str = "auto", arch: str = "generic") -> Dict[str, Any]:
    profile = read_json(profile_path)
    validate_profile(profile, profile_path)
    if threads == "auto":
        threads = profile.get("threads", "none")
    outdir.mkdir(parents=True, exist_ok=True)
    mapping = {
        "IMAGE_QUAL": profile["image_qualifier"],
        "WORK_QUAL": profile["work_qualifier"],
        "TABLE_QUAL": profile["table_qualifier"],
        "INLINE_KEYWORD": profile["inline_keyword"],
        "CALLING_CONVENTION": profile["calling_convention"],
        "RESTRICT_KEYWORD": profile["restrict_keyword"],
        "GAMMA_TABLE": make_gamma_table(gamma),
        "SERPENTINE_DEFAULT": str(serpentine),
        "FAMILY_ENUM": {"gamma": "FAX_FAMILY_GAMMA", "local_dark": "FAX_FAMILY_LOCAL_DARK", "clahe": "FAX_FAMILY_CLAHE"}[candidate["family"]],
        "PARAM_GAMMA": "{:.12g}".format(candidate["gamma"]),
        "PARAM_SERPENTINE": "{}".format(1 if candidate["serpentine"] else 0),
        "PARAM_SIGMA": "{:.12g}".format(candidate.get("sigma_px", 0.0)),
        "PARAM_STRENGTH": "{:.12g}".format(candidate.get("strength", 0.0)),
        "PARAM_FLOOR": "{:.12g}".format(candidate.get("floor", 0.0)),
        "PARAM_CLIP": "{:.12g}".format(candidate.get("clip", 0.0)),
    }
    template_map = {
        "fax_port.h": "fax_port.h.in",
        "fax_core.h": "fax_core.h.in",
        "fax_core.c": "fax_core.c.in",
        "fax_tables.c": "fax_tables.c.in",
        "test_fax.c": "test_fax.c.in",
        "fax_engine.h": "fax_engine.h.in",
        "fax_engine.c": "fax_engine.c.in",
        "fax_g3.c": "fax_g3.c.in",
        "fax_image.h": "fax_image.h.in",
        "fax_image.c": "fax_image.c.in",
        "fax_engine_test.c": "fax_engine_test.c.in",
        "fax_default_params.h": "fax_default_params.h.in",
        "fax_default_params.c": "fax_default_params.c.in",
    }
    generated: Dict[str, Any] = {}
    for output_name, template_name in template_map.items():
        source = (TEMPLATE_DIR / template_name).read_text(encoding="utf-8")
        content = replace_tokens(source, mapping, template_name)
        if output_name == "test_fax.c":
            content = content.replace(
                "fax_gamma_lut, 1, row_a, row_b",
                "fax_gamma_lut, {}, row_a, row_b".format(serpentine))
            content = content.replace("@SERPENTINE_DEFAULT@", str(serpentine))
        target = outdir / output_name
        target.write_text(content, encoding="ascii", newline="\n")
        generated[output_name] = {"bytes": target.stat().st_size, "sha256": sha256(target)}

    thread_header, thread_source = thread_backends.render(threads, arch)
    for output_name, content in (("fax_thread.h", thread_header), ("fax_thread.c", thread_source)):
        target = outdir / output_name
        target.write_text(content, encoding="ascii", newline="\n")
        generated[output_name] = {"bytes": target.stat().st_size, "sha256": sha256(target)}

    defaults = outdir / "default_params.json"
    defaults.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    generated[defaults.name] = {"bytes": defaults.stat().st_size, "sha256": sha256(defaults)}

    info = {
        "generator_version": VERSION,
        "profile_file": str(profile_path.resolve()),
        "profile": profile,
        "parameters": {"gamma": gamma, "serpentine": bool(serpentine), "candidate": candidate},
        "threading": {"backend": threads, "arch": arch},
        "implementation": {
            "implemented": [
                "8-bit grayscale raster API", "Gaussian blur with replicate and reflect-101 borders",
                "local-dark enhancement", "CLAHE with 12x8 tile grid and clipping/redistribution",
                "gamma mapping", "Floyd-Steinberg and serpentine dithering",
                "adaptive coarse/refinement candidate search", "full 410-candidate grid",
                "MAE/NCC/dark-detail/coverage scoring", "CCITT Group 3 MH 1D encoder",
                "1-bit little-endian TIFF writer, one row per strip", "caller-owned work buffers", "multi-threaded candidate evaluation (generated per-OS thread backend)",
                "in-process grayscale decoder API returning one owned raster allocation",
                "built-in PGM P2/P5 and Windows BMP BI_RGB 1/4/8/24/32-bpp decoders",
                "optional in-process libpng, libjpeg and libtiff adapters (no converter subprocess or intermediate file)",
                "TIFF multi-directory page selection, strips/tiles, DPI and all eight orientation values",
                "PNG alpha/tRNS compositing onto white and RGB-to-gray conversion",
                "BMP top-down/bottom-up rows and pixels-per-meter DPI metadata",
            ],
            "not_implemented": [
                "GIF/WebP/HEIF/RAW input", "CMYK/YCCK JPEG input", "JPEG EXIF orientation",
                "TIFF planar-separate and CMYK-separated photometric input",
                "BMP RLE/bitfield compression and ICC color management",
                "G3 2D coding option", "C-side source-DPI resampling",
            ],
            "compatibility_note": "CLAHE/Gaussian are algorithmically equivalent in intent but are not claimed bit-identical to OpenCV internals.",
        },
        "build_command": profile["compile_command"],
        "generated_files": generated,
    }
    (outdir / "build_info.json").write_text(
        json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return info


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", help="path to a compiler profile JSON")
    parser.add_argument("--outdir", default="build/generated", help="generated source directory")
    parser.add_argument("--gamma", type=float, default=1.0,
                        help="default gamma used for the generated 256-byte reference LUT")
    parser.add_argument("--serpentine", type=int, choices=(0, 1), default=1)
    parser.add_argument("--params", help="optimizer best_params.json; gamma/local_dark/CLAHE accepted")
    parser.add_argument("--threads", choices=("auto",) + thread_backends.BACKENDS, default="auto",
                        help="thread backend; auto = the profile's 'threads' key (none if absent)")
    parser.add_argument("--arch", choices=sorted(thread_backends.ARCHES), default="generic",
                        help="target architecture; sets the thread cap and workspace memory budget")
    parser.add_argument("--list-profiles", action="store_true")
    args = parser.parse_args(argv)
    if args.list_profiles:
        for path in sorted(PROFILE_DIR.glob("*.json")):
            print("{}\t{}".format(path.name, path.stem))
        return 0
    if not args.profile:
        parser.error("--profile is required unless --list-profiles is used")
    try:
        gamma, serpentine, candidate = normalize_params(args)
        info = generate(Path(args.profile), Path(args.outdir), gamma, serpentine, candidate,
                        args.threads, args.arch)
    except (OSError, ValueError, TypeError) as exc:
        print("error: {}".format(exc), file=sys.stderr)
        return 2
    print("Generated {} C/source artifacts for '{}' in {}".format(
        len(info["generated_files"]), info["profile"]["name"], Path(args.outdir).resolve()))
    print("default candidate={} gamma={} serpentine={}".format(
        candidate["family"], gamma, bool(serpentine)))
    print("Build: {}".format(info["build_command"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
