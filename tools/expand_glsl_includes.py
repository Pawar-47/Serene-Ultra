#!/usr/bin/env python3
"""Expand Iris shaderpack #include directives for standalone GLSL validation."""
from __future__ import annotations
import re
import sys
from pathlib import Path

SHADER_ROOT = (Path(__file__).resolve().parents[1] / "shaders").resolve()
INCLUDE_PATTERN = re.compile(r'^\s*#include\s*["<]([^">]+)[">]\s*(?://.*)?$')

def resolve_include(include_name: str, including_file: Path) -> Path:
    if include_name.startswith("/"):
        target = (SHADER_ROOT / include_name.lstrip("/")).resolve()
    else:
        target = (including_file.parent / include_name).resolve()
    try:
        target.relative_to(SHADER_ROOT)
    except ValueError as exc:
        raise ValueError(f"Include escapes shader root: {include_name}") from exc
    if not target.is_file():
        raise FileNotFoundError(f"Missing shader include {include_name} from {including_file}")
    return target

def expand_file(source: Path, stack: tuple[Path, ...] = ()) -> str:
    source = source.resolve()
    if source in stack:
        cycle = " -> ".join(str(path) for path in (*stack, source))
        raise ValueError(f"Cyclic shader include: {cycle}")
    text = source.read_text(encoding="utf-8")
    output: list[str] = []
    for line in text.splitlines():
        match = INCLUDE_PATTERN.match(line)
        if not match:
            output.append(line)
            continue
        included = resolve_include(match.group(1), source)
        output.append(f"// BEGIN INCLUDE {included.relative_to(SHADER_ROOT).as_posix()}")
        output.append(expand_file(included, (*stack, source)))
        output.append(f"// END INCLUDE {included.relative_to(SHADER_ROOT).as_posix()}")
    return "\n".join(output)

def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: expand_glsl_includes.py INPUT OUTPUT", file=sys.stderr)
        return 2
    source, output = Path(sys.argv[1]), Path(sys.argv[2])
    expanded = expand_file(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(expanded + "\n", encoding="utf-8")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
