# Fax C Portable Engine

A portable C89 fax image processing and CCITT Group 3 TIFF encoding engine, with a Windows GUI application.

## Overview

This project provides a portable C image processing engine designed to convert grayscale images into 1-bit fax-compatible images.

The engine includes:

- Gaussian blur and local-dark enhancement
- CLAHE (Contrast Limited Adaptive Histogram Equalization)
- Gamma correction
- Floyd–Steinberg dithering with serpentine scanning
- Adaptive parameter optimization and candidate evaluation
- CCITT Group 3 Modified Huffman (MH/1D) encoding
- 1-bit TIFF output
- In-process image decoding through optional PNG, JPEG and TIFF libraries

The core engine is written in C89-compatible C and is designed to be embedded into other applications.

## Current Release

**Available binaries: Windows 32-bit (x86) and 64-bit (x64).**

The current release includes:

- Windows x86 and x64 engine executables
- Windows GUI application
- Windows installer
- C89 engine source code
- Python-based source generator and compiler profiles

The GUI application is currently Windows-only.

## Portability

The C engine is designed to be portable across different operating systems and compiler environments.

The source generator includes compiler profiles and platform-specific threading backends for:

- Windows (Win32 threads)
- POSIX systems (pthreads)
- Single-threaded environments

Additional target profiles include GCC, MSVC and Turbo C memory models.

However, these targets are not all equally validated or released.

**Currently, only Windows x86 and x64 binaries are provided as release builds.**

16-bit DOS/Windows targets and Linux/Unix builds have not yet been published as supported releases. They can be generated and built using the provided scripts and compiler profiles, but additional compilation and runtime testing are required.

A GUI implementation for non-Windows platforms is also not currently available.

## Requirements

### Windows GUI

- Windows x86 or x64
- Visual Basic 5 runtime
- Common Controls OCX

### Source generation

- Python 3
- NumPy

### C engine

- A C89-compatible compiler
- Optional: libpng, libjpeg-turbo and libtiff for PNG, JPEG and TIFF input

## Building

Install the Python dependency:

```sh
python -m pip install -r requirements.txt
```

Generate C sources using a compiler profile:

```sh
python generator.py --profile profiles/gcc_c89.json --outdir build/gcc_c89
```

Other profiles are available in the `profiles/` directory.

See [DEVELOPMENT.md](DEVELOPMENT.md) for compiler-specific build instructions, API documentation and implementation details.

## Project Structure

| Directory | Description |
|---|---|
| `templates/` | C source templates |
| `profiles/` | Compiler and target profiles |
| `vb/` | Visual Basic GUI source |
| `installer/` | Windows installer configuration and runtime files |
| `tests/` | Generator and image decoder tests |
| `tools/` | Development utilities |
| `build/` | Generated sources and build outputs |

## Limitations

- Only CCITT Group 3 MH (1D) encoding is implemented.
- GIF, WebP, HEIF and RAW decoding are not implemented.
- CMYK/YCCK JPEG input is not supported.
- The engine requires caller-provided workspaces; the convenience CLI handles its own allocations.
- Image processing results are not guaranteed to be bit-identical to OpenCV implementations.

See [VALIDATION.md](VALIDATION.md) for current validation results and known limitations.

## License

See [LICENSE](LICENSE).
