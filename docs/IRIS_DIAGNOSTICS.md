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
