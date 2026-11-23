# GLSL Source-Version Policy

## Current decision

The line program is intentionally authored as GLSL 1.30:

- `gbuffers_line.vsh`
- `gbuffers_line.fsh`

This is a targeted Iris compatibility measure, not a blanket conversion of the shaderpack. Other stages retain their current declarations until they have been individually audited and migrated safely.

## Why GLSL 1.30 for lines

Iris 26.1's `TransformPatcher` has a dedicated path for vanilla line programs. When `VanillaParameters.isLines()` is true, Iris routes the program through `VanillaCoreTransformer`, raises the parsed version to at least GLSL 3.30, and applies fragment-output location attachment through `CompatibilityTransformer.transformFragmentCore`.

That path is materially different from explicitly declaring `#version 330 compatibility`, which leaves the shader on the compatibility-profile path. The latter produced this reported driver error during line-program compilation:

```text
the compatibility profile is not supported
```

Iris implementation references (26.1):

- `common/src/main/java/net/irisshaders/iris/pipeline/transform/TransformPatcher.java`
- `common/src/main/java/net/irisshaders/iris/pipeline/transform/transformer/VanillaCoreTransformer.java`
- `common/src/main/java/net/irisshaders/iris/pipeline/transform/transformer/CompatibilityTransformer.java`

## Line-stage source requirements

- Keep the source declaration at `#version 130`; do not add an explicit compatibility profile.
- Use `outColor0` and `outColor1` for fragment outputs so Iris can attach locations 0 and 1.
- Keep `/* RENDERTARGETS: 0,2 */`; output location 0 writes colortex0 and output location 1 writes colortex2.
- Avoid `layout(location = ...)` in these GLSL 1.30 source files.
- Avoid `ftransform()` in the line vertex shader. Use the explicit projection/model-view/vertex expression so Iris's core transformer can rewrite each legacy built-in.

## Why not GLSL 1.20

The current line stages use GLSL 1.30-era `in`/`out` interface qualifiers. GLSL 1.20 would require a separate `attribute`/`varying` conversion and offers no compatibility benefit worth that extra migration for this program.

## Why not change every stage at once

A shaderpack's source version is not the same as the final version sent to the driver. Iris parses and transforms shader stages according to the program type and declared profile. Fragment output declarations, render-target mapping, legacy built-ins, and composite-stage behavior must all be migrated consistently.

The working Complementary and MakeUp references demonstrate that GLSL 1.30 and 1.20 source declarations are viable in established packs, but they do not prove that every Serene Ultra stage can be changed mechanically. Each program family must be checked against Iris's actual transformation path and then validated.

## Validation status

GitHub Actions validates GLSL syntax, program linking, shaderpack structure, and project-specific invariants. These checks do not replace a real Iris runtime test on the user's Windows/Linux graphics drivers. A successful CI run must not be described as proof that the in-game shader load is fixed.
