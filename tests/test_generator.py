import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


class GeneratorTests(unittest.TestCase):
    def run_generator(self, out, *extra):
        return subprocess.run([
            sys.executable, str(ROOT / "generator.py"),
            "--profile", str(ROOT / "profiles" / "gcc_c89.json"),
            "--outdir", str(out), *extra,
        ], check=True, capture_output=True, text=True)

    def test_generates_full_engine_and_gamma_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "generated"
            self.run_generator(out, "--gamma", "1.0")
            expected = {
                "fax_port.h", "fax_core.h", "fax_core.c", "fax_tables.c",
                "test_fax.c", "fax_engine.h", "fax_engine.c", "fax_g3.c",
                "fax_engine_test.c", "fax_image.c", "fax_image.h",
                "default_params.json", "build_info.json",
            }
            self.assertTrue(expected.issubset({p.name for p in out.iterdir()}))
            table = (out / "fax_tables.c").read_text(encoding="ascii")
            for value in range(0, 256, 17):
                self.assertRegex(table, r"(?<!\d){}(?!\d)".format(value))
            info = json.loads((out / "build_info.json").read_text(encoding="utf-8"))
            self.assertEqual(info["parameters"]["gamma"], 1.0)
            self.assertIn("CLAHE", " ".join(info["implementation"]["implemented"]))
            self.assertIn("in-process libpng", " ".join(info["implementation"]["implemented"]))
            self.assertIn("GIF/WebP/HEIF/RAW input", info["implementation"]["not_implemented"])

    def test_thread_backends_are_generated_per_profile_and_arch(self):
        with tempfile.TemporaryDirectory() as tmp:
            for threads, arch, token in (("win32", "x64", "CreateThread"),
                                         ("pthread", "x86", "pthread_create"),
                                         ("none", "generic", "return 1;")):
                out = Path(tmp) / threads
                self.run_generator(out, "--threads", threads, "--arch", arch)
                header = (out / "fax_thread.h").read_text(encoding="ascii")
                source = (out / "fax_thread.c").read_text(encoding="ascii")
                self.assertIn("backend={} arch={}".format(threads, arch), header)
                self.assertIn(token, source)
            self.assertIn("FAX_MAX_THREADS 1", (Path(tmp) / "none" / "fax_thread.h").read_text())
            self.assertIn("FAX_MAX_THREADS 8", (Path(tmp) / "pthread" / "fax_thread.h").read_text())

    def test_all_optimizer_parameter_families_are_accepted(self):
        candidates = [
            {"family": "gamma", "gamma": 1.2, "serpentine": False},
            {"family": "local_dark", "gamma": 1.05, "serpentine": True,
             "sigma_px": 7.0, "strength": 0.425, "floor": 0.0},
            {"family": "clahe", "gamma": 1.1, "serpentine": False, "clip": 0.75},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            for index, candidate in enumerate(candidates):
                params = Path(tmp) / "params_{}.json".format(index)
                params.write_text(json.dumps({"best_candidate": candidate}), encoding="utf-8")
                out = Path(tmp) / "out_{}".format(index)
                self.run_generator(out, "--params", str(params))
                saved = json.loads((out / "default_params.json").read_text(encoding="utf-8"))
                self.assertEqual(saved["family"], candidate["family"])
                self.assertEqual(saved["serpentine"], candidate["serpentine"])

    def test_generated_gamma_reference_lut_matches_numpy(self):
        with tempfile.TemporaryDirectory() as tmp:
            params = Path(tmp) / "best_params.json"
            params.write_text(json.dumps({
                "best_candidate": {"family": "gamma", "gamma": 1.2, "serpentine": False}
            }), encoding="utf-8")
            out = Path(tmp) / "generated"
            self.run_generator(out, "--params", str(params))
            source = (out / "fax_tables.c").read_text(encoding="ascii")
            body = source.split("{", 1)[1].split("}", 1)[0]
            actual = np.array([int(x) for x in re.findall(r"\d+", body)], dtype=np.uint8)
            values = np.arange(256, dtype=np.float32)
            expected = np.clip(np.rint((values / 255.0) ** 1.2 * 255), 0, 255).astype(np.uint8)
            self.assertTrue(np.array_equal(actual, expected))

    def test_rejects_invalid_parameter_family(self):
        with tempfile.TemporaryDirectory() as tmp:
            params = Path(tmp) / "bad.json"
            params.write_text(json.dumps({"family": "adaptive_noise", "gamma": 1.0,
                                          "serpentine": True}), encoding="utf-8")
            result = subprocess.run([
                sys.executable, str(ROOT / "generator.py"),
                "--profile", str(ROOT / "profiles" / "gcc_c89.json"),
                "--outdir", str(Path(tmp) / "out"), "--params", str(params),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("params family must be", result.stderr)


if __name__ == "__main__":
    unittest.main()
