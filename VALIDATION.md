# Validation record — 2026-11-05

This record distinguishes checks run in the current environment from untested compiler ports.

## Generator and core engine

- `python3 -m unittest discover -s tests -v`: 7 tests passed (including all eight TIFF orientation transforms).
- Generator accepts all three optimizer parameter families: `gamma`, `local_dark`, and `clahe`.
- GCC generated sources compile with strict C89 flags and `-Werror`.
- Clang strict-C89 build is also checked separately when available.
- The core can be built without optional codec libraries; `fax_image.c` then provides built-in PGM/BMP input only.

## In-process image decoder

The `fax_image_load_file()` API returns one owned, contiguous 8-bit grayscale raster plus width, height, stride, DPI and selected TIFF directory. The CLI passes that memory directly to the optimizer. There is no converter subprocess or intermediate PGM file.

Verified fixtures:

- PGM P5.
- BMP BI_RGB: 1-bit, paletted 4-bit, RGB 24-bit; top-down/bottom-up parser and DPI metadata path.
- PNG: RGB, palette, alpha/tRNS compositing onto white, pHYs DPI.
- JPEG: grayscale output and JFIF DPI metadata.
- TIFF: Group 3 and Group 4 bilevel input, LZW, Deflate and PackBits compression, tiled TIFF, multi-directory selection, and all eight orientation values.
- TIFF orientation 1–8 output pixels were compared against the expected flips/transposes/rotations using raw un-oriented test pixels; all eight matched.
- PNG half-transparent black over white decoded to gray 127; fully transparent pixels decoded to white 255.
- Truncated PNG, JPEG, TIFF and BMP inputs fail cleanly; ASan/UBSan with leak detection reported no decoder-owned leaks on these failure paths after the cleanup fix.

The test harness compiles `fax_image.c` and calls the API directly. The production CLI detects the format from a short signature probe, then writes decoded pixels into the one final grayscale raster allocation. PNG/JPEG decode scanlines directly into it; BMP uses a row buffer; TIFF uses scanline/tile conversion plus libtiff's own current strip/tile cache. This is not a second converted full-raster file, though TIFF peak memory depends on strip/tile layout. It does not invoke ImageMagick, ffmpeg, Python Pillow, or another converter at runtime, nor does it create/reload an intermediate raster file. Pillow is used only to create fixture files and inspect results during testing.

## End-to-end optimizer and G3 output

- Adaptive, full and apply modes run through the C engine.
- Full mode evaluates the 410-candidate grid.
- TIFF output was opened with Pillow and checked for 1-bit mode, Group 3 compression, `T4Options=0`, and pixel equality with the input binary raster.

## Known boundaries

- PNG/JPEG/TIFF adapters call libpng, libjpeg-turbo and libtiff in-process. The default GCC build uses shared libraries; these are runtime dependencies, but not converter processes or intermediate-image handoffs. A fully static link was attempted against the installed distro archives and failed because static libtiff pulled in the C++ LERC dependency. Static linking requires a codec build/configuration with compatible static transitive dependencies.
- JPEG CMYK/YCCK and JPEG EXIF orientation are not supported by this adapter yet.
- TIFF planar-separate and CMYK-separated images are not supported. TIFF contiguous grayscale, palette and RGB strip/tile layouts are supported for the documented sample depths.
- BMP RLE and bitfield-compressed variants are not supported; Windows BI_RGB is supported.
- GIF, WebP, HEIF and RAW are not supported.
- Turbo C and Microsoft Visual C/C++ have not been run in this environment. Their profiles are generation/build targets only, not verified ports.
- Full pixel equivalence with OpenCV preprocessing is not claimed; Gaussian and CLAHE implementation details and rounding may differ.
