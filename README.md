[**Windows용 설치/Install for Windows:**](https://github.com/haninkj00-crypto/getfax/releases)

# Fax C Portable Engine — complete first implementation

This project is a **development-time Python source generator** for a callable, embeddable C89 grayscale-to-1-bit fax engine. Python and NumPy are required only to generate the target C sources. The core engine does not start Python or require OpenCV/libtiff. The optional modern CLI image adapter uses codec APIs directly inside the same process.

The implementation now contains the processing functions that were missing from the earlier baseline:

- Gaussian blur (reflect-101 border for local enhancement; replicate border for reconstruction scoring);
- local-dark enhancement (`max(blur(gray) - gray - floor, 0)` followed by strength subtraction);
- CLAHE with a 12x8 tile grid, histogram clipping, redistribution and bilinear LUT interpolation;
- gamma mapping and Floyd–Steinberg dithering, including serpentine scan;
- the adaptive coarse/refinement search and the original 410-candidate full grid;
- the optimizer's score components: MAE, NCC, dark-detail correlation, high/low detail darkness ratio, black coverage and transition count;
- a self-contained CCITT Group 3 MH (1D) encoder and little-endian, 1-bit TIFF writer, without libtiff.

The processing API consumes an **8-bit grayscale raster in memory**. The CLI's `fax_image_load_file()` layer detects the format from a short file signature and decodes directly into the one final grayscale allocation consumed by the engine. It does not launch a converter process, create a PGM, or reload a converted image. PGM and Windows BMP decoding are built in. PNG, JPEG and TIFF use libpng, libjpeg-turbo and libtiff APIs called inside the same process. PNG/JPEG scanlines write directly into the final raster; TIFF uses one scanline or tile scratch buffer and writes into that raster. The libraries are link-time/runtime dependencies unless static archives are selected, but they are decoders, not converter subprocesses.

## 1. Generate target sources

From this directory:

```sh
python3 -m pip install -r requirements.txt
python3 generator.py --profile profiles/gcc_c89.json --outdir build/gcc_c89
```

Other target profiles:

```sh
python3 generator.py --profile profiles/msvc_c89.json --outdir build/msvc_c89
python3 generator.py --profile profiles/turbo_c_small.json --outdir build/turbo_c_small
python3 generator.py --profile profiles/turbo_c_large_huge.json --outdir build/turbo_c_large_huge
```

A `best_params.json` from `fax_g3_optimizer.py` can be embedded as the generated default candidate. All three families are accepted:

```sh
python3 generator.py \
  --profile profiles/gcc_c89.json \
  --outdir build/from_optimizer \
  --params /path/to/best_params.json
```

The generated `fax_default_params.c/.h` expose `fax_default_candidate`. The generated program's `apply` mode uses this parameter set without searching.

## 2. Build and run

### Pre-built Windows Release

The current pre-release provides a Windows installer supporting both x86 (32-bit) and x64 (64-bit) systems.

The installer automatically detects the operating system architecture and installs the corresponding application binaries.

- Windows x86 (32-bit)
- Windows x64 (64-bit)

**Pre-built binaries are currently available for Windows only.**

The GUI application is currently Windows-specific.

Linux and 16-bit DOS/Windows targets are not included in the current release. Source generation profiles are provided for these environments, but additional target-specific build and runtime validation is required.

See [GitHub Releases](https://github.com/haninkj00-crypto/getfax/releases) for available downloads.

### GCC / Clang

```sh
cd build/gcc_c89
gcc -std=c89 -pedantic -Wall -Wextra -Werror -O2 \
  -DFAX_WITH_PNG -DFAX_WITH_JPEG -DFAX_WITH_TIFF \
  $(pkg-config --cflags libpng libjpeg libtiff-4) \
  fax_core.c fax_engine.c fax_g3.c fax_image.c fax_tables.c \
  fax_default_params.c fax_engine_test.c -lm \
  $(pkg-config --libs libpng libjpeg libtiff-4) -o fax_engine_test
```

The test driver detects image format from the file signature. Built-in formats are PGM P2/P5 and Windows BMP BI_RGB 1/4/8/24/32-bpp. When the codec defines above are enabled, PNG, JPEG and TIFF are decoded in-process. The signature probe reads only the first eight bytes; the actual decoder then reads the source once into the destination raster. TIFF page selection is zero-based:

```sh
./fax_engine_test input.png result adaptive
./fax_engine_test input.jpg result full
./fax_engine_test input.tif result adaptive 0
./fax_engine_test multipage.tif page2 apply 1
./fax_engine_test input.pgm result apply
```

- `adaptive`: sparse first pass followed by up to three refinement rounds;
- `full`: the complete 410-candidate grid;
- `apply`: render only the `fax_default_candidate` generated from the parameter JSON.

Outputs include `*_best.pgm`, `*_best_g3.tif`, and `*_metrics.csv`. The TIFF is one-page, 1-bit, Group 3 MH/1D, little-endian, one scanline per strip, with `T4Options=0`.

### Visual Studio C compiler

Use a Developer Command Prompt with libpng, libjpeg-turbo and libtiff headers and libraries available (for example, through a static vcpkg triplet). Define `FAX_WITH_PNG`, `FAX_WITH_JPEG`, `FAX_WITH_TIFF`, add the codec include directory, and link their static libraries. The decoder calls these libraries in-process; it does not spawn converter programs. The generated `msvc_c89.json` contains the command shape.

### Turbo C

The generated profile records the intended memory model and image-pointer qualifier. A typical build command is:

```bat
tcc -ml -O -c fax_core.c fax_engine.c fax_g3.c fax_tables.c fax_default_params.c
```

Use `-ms` for the small-model profile. This is a core-object build only: the convenience CLI and modern PNG/JPEG/TIFF codec dependencies are deliberately excluded. The application supplies a decoded grayscale raster directly through the C API. The small model is not suitable for image buffers crossing its near-data segment. The large/huge profile is a starting point for compiler-specific validation, not a claim that the full-page optimizer fits conventional DOS memory. For real DOS use, the host program must supply compatible far/huge buffers and an allocator (for example XMS/EMS-backed storage); the current optimizer workspace is still image-sized.

## 2b. Multi-core search and per-OS/architecture generation

Candidate evaluation in `adaptive` and `full` modes runs on several threads. Everything that depends on the OS or CPU architecture is generated by `thread_backends.py` into `fax_thread.h/.c`; the C templates only use that small API.

```sh
python3 generator.py --profile profiles/msvc_c89.json --outdir build/msvc_c89 --arch x64            # win32 threads
python3 generator.py --profile profiles/gcc_c89.json  --outdir build/gcc_c89  --arch x64            # pthread (add -pthread)
python3 generator.py --profile profiles/gcc_c89.json  --outdir build/mingw    --threads win32      # MinGW
python3 generator.py --profile profiles/turbo_c_small.json --outdir build/tc                          # no threads (16-bit)
```

- `--threads win32|pthread|none` overrides the profile's `threads` key; `--arch x86|x64|arm64|generic` sets the thread cap and the workspace memory budget (x86: 8 threads / 1000 MB).
- Run-time: `fax_engine_test ... --threads N` (0 or omitted = CPU count, at most 8, limited by the memory budget). Each extra thread needs about 10 bytes per pixel of workspace (a 1728x2292 page: roughly 40 MB per thread).
- The result is identical for any thread count (best candidate ties are broken by candidate id). The CSV row order may differ. Callbacks run under a lock and may be called from worker threads.
- The engine API: `fax_optimizer_options.extra_workspaces` / `extra_count` supply the extra workspaces; the engine still never allocates.

## 3. C API

The primary interface is in `fax_engine.h`.

- `fax_optimize(...)`: run adaptive or full search; returns the best candidate and best binary raster. An optional callback receives every candidate's complete metrics so the host can write CSV or show progress.
- `fax_apply_candidate(...)`: render one fixed candidate without searching.
- `fax_local_dark_enhance(...)`: expose local-dark preprocessing directly.
- `fax_clahe_enhance(...)`: expose CLAHE preprocessing directly.
- `fax_score_binary(...)`: score a supplied binary raster.
- `fax_write_g3_tiff(...)`: stream a TIFF to a caller-provided write callback.
- `fax_image_load_file(...)`: decode PGM/BMP internally and optional PNG/JPEG/TIFF through in-process codec libraries into a contiguous 8-bit grayscale buffer, with dimensions and DPI metadata.
- `fax_image_release(...)`: release the decoded image buffer.

The engine does **not allocate memory**. The caller fills `fax_engine_workspace` with writable buffers:

| Workspace field | Required capacity |
|---|---:|
| `detail_ref` | `width * height` bytes |
| `work_tmp` | `width * height` floats |
| `reconstruction` | `width * height` floats |
| `base_image` | `width * height` bytes |
| `binary_image` | `width * height` bytes |
| `dither_row_a`, `dither_row_b` | `width` floats each |
| `clahe_maps` | `12 * 8 * 256` bytes |
| `gaussian_kernel` | `257` floats |
| `candidate_entries` | 512 `fax_search_entry` records (optimizer only) |
| `strip_offsets`, `strip_byte_counts` | `height` `fax_u32` values each (TIFF only) |

Image-sized workspace use is approximately **11 bytes per pixel** (1 + 4 + 4 + 1 + 1), excluding row buffers, CLAHE maps, candidate records and TIFF strip tables. A 1728x2292 raster therefore needs about 43.6 MB of image-sized work memory. `fax_engine_test.c` uses `malloc` for convenience; the engine itself does not allocate.

The two-row Floyd–Steinberg streaming interface in `fax_core.h` remains available separately. It is useful when the input is already enhanced and only dithering is required. The current complete local-dark/CLAHE search still uses image-sized buffers; a fully row-streaming version of those operations is not claimed.

## 4. Numerical equivalence and boundaries

The image adapter returns a single contiguous grayscale raster allocation. PNG and JPEG scanline decoding write into that final allocation; TIFF strip/tile decoding uses one scanline or tile scratch buffer and writes into the final allocation. BMP uses one temporary source row. PGM P2/P5 data are read directly into the final allocation. The adapter does not materialize a second full-size *converted output raster* or pass through an intermediate file. libtiff may internally cache the current decoded strip/tile; TIFF peak memory therefore also depends on the source file's strip/tile organization. The TIFF path supports contiguous unsigned grayscale, palette and RGB strips/tiles, 1/2/4/8/16-bit samples where applicable, multi-directory page selection, DPI, and all eight TIFF orientation values. TIFF planar-separate and CMYK-separated photometric input are rejected. CMYK/YCCK JPEG is rejected, and JPEG EXIF orientation is not yet applied.

The C implementation follows the Python optimizer's mathematical definitions, candidate grids and score weights. It is **not claimed to be bit-identical to OpenCV**. OpenCV's internal Gaussian fixed-point paths, CLAHE padding/tile details and rounding can differ by a small amount. Because error diffusion can amplify a one-level grayscale difference, candidate rankings and binary pixels may differ from Python. The score remains a heuristic proxy, not OCR accuracy.

The C Group 3 encoder is independent of libtiff. Its TIFF output was checked with Pillow: `BitsPerSample=1`, `Compression=3`, `PhotometricInterpretation=0`, `RowsPerStrip=1`, `T4Options=0`, and decoded pixels identical to the input binary raster in the included smoke test. The encoder only implements 1D Modified Huffman coding; 2D Group 3 options are not implemented.

The PNG/JPEG/TIFF adapters are optional build components. GCC's default profile links libpng, libjpeg-turbo and libtiff into the same CLI process. Omitting the codec defines and libraries leaves the built-in PGM/BMP decoder and the independent in-memory engine API. To remove shared-library runtime dependencies, use static codec archives; this depends on the exact codec build and all of its transitive dependencies. In the current Linux environment, a fully static link against the distro libtiff archive was not successful because that archive pulls in the C++ LERC library. This does not affect the normal in-process shared-library build. The Turbo C profiles intentionally exclude the modern codec dependencies.

The engine uses the C math library (`pow`, `exp`, `sqrt`, `floor`, `fmod`). This is a standard compiler/runtime library dependency, not a Python or OpenCV runtime. GCC links it with `-lm`; other toolchains may link it automatically or require their math library option.

## 5. AI-assisted compiler feedback (target: <= 10 rounds)

Do not patch the generated `.c` file as the only fix. Preserve the generated directory and complete compiler log, then create a bundle:

```sh
python3 tools/make_feedback_bundle.py \
  --generated build/turbo_c_large_huge \
  --profile profiles/turbo_c_large_huge.json \
  --compiler-version "Turbo C 3.0" \
  --command "tcc -ml -O -c fax_core.c fax_engine.c fax_g3.c fax_tables.c fax_default_params.c" \
  --log build/turbo_c_large_huge/build.log \
  --log-encoding cp949 \
  --round 1 \
  --out build/turbo_c_large_huge/AI_FEEDBACK.md
```

Give the bundle to the AI. It must identify the root diagnostic, return a minimal diff against a generator template/profile, and add a regression test. Regenerate after the change and increment `--round`. Ten rounds is a target, not a guarantee. Do not label a compiler profile verified until the generated code compiles and its test executable runs on that compiler.

## 6. Test suite

```sh
python3 -m unittest discover -s tests -v
```

The tests cover source generation, all parameter families, strict-C89 compilation and in-process PNG/JPEG/BMP/TIFF decoding, including alpha, multipage TIFF and orientation metadata. Pillow is used to generate and inspect test fixtures.
