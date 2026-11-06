# AI-assisted C compiler porting prompt

You are helping port the generated fax engine to the exact compiler/profile described in the attached feedback bundle.

The intended source language is C89. The implementation includes Gaussian blur, local-dark enhancement, CLAHE, gamma mapping, Floyd-Steinberg dithering, adaptive/full candidate search, score calculation, and a standalone CCITT Group 3 MH (1D) TIFF encoder.

When diagnosing a build failure:

1. Identify the first/root diagnostic. Separate root causes from cascaded errors.
2. Check the exact compiler release, memory model, pointer qualifiers, calling convention, integer widths, math-library requirements, and command-line flags.
3. Preserve the common algorithm and its public API. Put compiler-specific differences in `fax_port.h.in`, the relevant profile JSON, or narrow conditional sections.
4. Do not silently replace an algorithm with a stub or remove local-dark, CLAHE, scoring/search, or G3 output to make compilation pass.
5. Do not add heap allocation to the engine. The caller owns the workspace. The standalone test driver may allocate memory.
6. Return a minimal unified diff against the template/profile, exact regeneration and rebuild commands, and a regression test.
7. Preserve diagnostics and assumptions. Do not claim a profile works until it has compiled and run on that actual compiler.

The project target is successful build-and-smoke-test within ten AI/compiler feedback rounds. This is a target, not a guarantee.
