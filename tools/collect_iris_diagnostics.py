#!/usr/bin/env python3
"""Collect Iris/GLSL/OpenGL errors from Minecraft latest.log into shaderpacks/."""
from __future__ import annotations
import argparse
import datetime as dt
import os
import platform
import re
import sys
from pathlib import Path

PATTERN = re.compile(
    r"iris|glsl|shader.?pack|shader.?program|compile|compiler|opengl|"
    r"failed|fatal|exception|\berror\b|\bwarn(?:ing)?\b|"
    r"unsupported|compatibility profile|linker|uniform|rendertarget",
    re.IGNORECASE,
)
CONTEXT = 8

def default_game_dir() -> Path:
    home = Path.home()
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        return Path(appdata) / ".minecraft" if appdata else home / "AppData/Roaming/.minecraft"
    if sys.platform == "darwin":
        return home / "Library/Application Support/minecraft"
    return Path(os.environ.get("MINECRAFT_DIR", home / ".minecraft")).expanduser()

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-dir", type=Path, default=default_game_dir(),
                        help="Minecraft game directory (default: detected standard location)")
    parser.add_argument("--log", type=Path, help="Explicit latest.log path")
    parser.add_argument("--shaderpacks-dir", type=Path,
                        help="Output directory (default: <game-dir>/shaderpacks)")
    args = parser.parse_args()
    game_dir = args.game_dir.expanduser()
    log_path = args.log.expanduser() if args.log else game_dir / "logs" / "latest.log"
    output_dir = args.shaderpacks_dir.expanduser() if args.shaderpacks_dir else game_dir / "shaderpacks"

    if not log_path.is_file():
        print(f"ERROR: Minecraft log not found: {log_path}", file=sys.stderr)
        print("Launch Minecraft, reproduce the Iris error, close the game, then run this tool again.", file=sys.stderr)
        return 2
    try:
        raw = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"ERROR: Cannot read {log_path}: {exc}", file=sys.stderr)
        return 2

    lines = raw.splitlines()
    selected: set[int] = set()
    hits = [i for i, line in enumerate(lines) if PATTERN.search(line)]
    for i in hits:
        selected.update(range(max(0, i - CONTEXT), min(len(lines), i + CONTEXT + 1)))

    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    report = output_dir / f"Serene-Ultra-Iris-Diagnostics-{stamp}.txt"
    with report.open("w", encoding="utf-8", newline="\n") as out:
        out.write("SERENE ULTRA — IRIS DIAGNOSTIC REPORT\n")
        out.write(f"Generated: {dt.datetime.now().astimezone().isoformat()}\n")
        out.write(f"Platform: {platform.platform()}\n")
        out.write(f"Python: {platform.python_version()}\n")
        out.write(f"Game directory: {game_dir.resolve()}\n")
        out.write(f"Log source: {log_path.resolve()}\n")
        out.write(f"Total log lines: {len(lines)}\n")
        out.write(f"Matched lines: {len(hits)} (with {CONTEXT}-line context)\n")
        out.write("\n=== IRIS / SHADER / GLSL / OPENGL ERROR CONTEXT ===\n")
        if selected:
            previous = -2
            for i in sorted(selected):
                if i > previous + 1:
                    out.write("\n--- omitted unrelated log lines ---\n")
                out.write(f"{i + 1:06d}: {lines[i]}\n")
                previous = i
        else:
            out.write("No matching diagnostic lines found. Full log is included below.\n")
        out.write("\n=== COMPLETE MINECRAFT latest.log (unaltered) ===\n")
        out.write(raw)
        if raw and not raw.endswith("\n"):
            out.write("\n")
    print(f"Diagnostic report saved: {report}")
    print("Attach this TXT report to your Serene Ultra issue/chat. Review it first for private server/chat details.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
