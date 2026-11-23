# Collecting Serene Ultra / Iris diagnostics

The shader pack itself cannot write files: GLSL has no filesystem access. Iris and OpenGL write diagnostics to Minecraft's `logs/latest.log`. These helpers collect the matching error context and preserve the complete log in a report placed in the Minecraft `shaderpacks` directory.

## Before collecting

1. Start Minecraft with Iris and select Serene Ultra.
2. Reproduce the error popup / vanilla fallback.
3. Close Minecraft so `latest.log` is flushed.
4. Run the helper below.

## Windows

From the repository/tools folder, double-click `Collect-Iris-Diagnostics.bat`. Alternatively, copy the `tools` folder somewhere and run the BAT file there. Python 3 must be installed and available as `py -3`.

If Minecraft uses a custom game directory, pass it as an argument:
```bat
py -3 collect_iris_diagnostics.py --game-dir "D:\Games\Minecraft"
```

## Linux

Run:
```sh
chmod +x tools/collect-iris-diagnostics.sh
tools/collect-iris-diagnostics.sh
```

For a custom game directory:
```sh
python3 tools/collect_iris_diagnostics.py --game-dir "$HOME/Games/Minecraft"
```

The script detects the standard Minecraft directory by default. It creates `Serene-Ultra-Iris-Diagnostics-YYYYMMDD-HHMMSS.txt` inside that game's `shaderpacks` folder. The report contains filtered Iris/GLSL/OpenGL context and the complete original `latest.log`.

Review the report before sharing: Minecraft logs can contain usernames, local paths, server addresses, and chat messages. The script does not upload or transmit anything.

## Blend-directive audit

The current `main` configuration was checked against Iris 26.1's `ShaderProperties` parser and the current Iris rendering-properties reference.

- Program-wide directives such as `blend.gbuffers_textured_lit=off` are valid.
- Per-buffer directives must use a recognized attachment name after the program, for example `.colortex2=off`.
- The current per-buffer directives use `colortexN` names; no unknown buffer suffix was found in the current `shaders.properties`.
- Iris throws `Failed to parse buffer blend! index = -1` when a dotted blend directive contains an unrecognized buffer suffix. The current source configuration therefore does not reproduce that parser failure by inspection.

This does not prove that an older ZIP, a stale shaderpack copy, or a different Iris build cannot produce the popup. Confirm the exact ZIP selected in-game and capture `latest.log` after reproducing it. Do not infer that a successful static check proves runtime compatibility.

References:
- Iris 26.1 `ShaderProperties.java`: https://github.com/IrisShaders/Iris/blob/26.1/common/src/main/java/net/irisshaders/iris/shaderpack/properties/ShaderProperties.java
- Iris rendering properties: https://shaders.properties/current/reference/shadersproperties/rendering/
