#!/usr/bin/env python3
"""Structural checks for Serene Ultra. This is not a GLSL compiler."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
REQUIRED = (
    "shaders.properties",
    "gbuffers_terrain.vsh", "gbuffers_terrain.fsh",
    "gbuffers_entities.vsh", "gbuffers_entities.fsh",
    "gbuffers_hand.vsh", "gbuffers_hand.fsh",
    "shadow.vsh", "shadow.fsh",
    "composite.vsh", "composite.fsh",
    "final.vsh", "final.fsh",
    "lang/en_us.lang",
)
errors = []

for rel in REQUIRED:
    path = SHADERS / rel
    if not path.is_file():
        errors.append(f"Missing required shaderpack file: shaders/{rel}")

for path in SHADERS.rglob("*"):
    if path.suffix not in {".vsh", ".fsh", ".csh", ".glsl"}:
        continue
    source = path.read_text(encoding="utf-8")
    if not re.search(r"^\s*#version\s+330\b", source, re.MULTILINE):
        errors.append(f"{path.relative_to(ROOT)}: expected an explicit GLSL 330 version")
    if source.count("{") != source.count("}"):
        errors.append(f"{path.relative_to(ROOT)}: unbalanced brace count")

audit = ROOT / "docs" / "REFERENCE_ULTRA_AUDIT.md"
if not audit.is_file():
    errors.append("Missing source-derived Ultra reference audit")
else:
    audit_text = audit.read_text(encoding="utf-8")
    for token in ("SHADOW_QUALITY", "COLORED_LIGHTING", "WORLD_SPACE_REFLECTIONS",
                  "WATER_REFLECT_QUALITY", "CLOUD_QUALITY", "RAIN_PUDDLES"):
        if token not in audit_text:
            errors.append(f"Reference audit is missing required setting: {token}")

props_path = SHADERS / "shaders.properties"
if props_path.is_file():
    props = props_path.read_text(encoding="utf-8")
    for profile in ("Ultra-Light", "Smooth", "Ultra", "HDR", "Ultra-HDR"):
        if f"profile.{profile} =" not in props:
            errors.append(f"Missing shader profile: {profile}")
    for screen in ("screen = <profile>", "screen.QUALITY =", "screen.COLOR ="):
        if screen not in props:
            errors.append(f"Missing menu configuration: {screen}")
    if "SHADOW_ALPHA_CUTOFF" not in props:
        errors.append("Shadow alpha cutoff is not exposed in the Quality menu")

final_path = SHADERS / "final.fsh"
if final_path.is_file():
    final = final_path.read_text(encoding="utf-8")
    for option in ("RED_GAIN", "GREEN_GAIN", "BLUE_GAIN", "GAMMA", "EXPOSURE",
                   "CONTRAST", "SATURATION", "HDR_LOOK"):
        if f"#define {option} " not in final:
            errors.append(f"Missing active color control: {option}")

shadow_vertex = SHADERS / "shadow.vsh"
shadow_fragment = SHADERS / "shadow.fsh"
if shadow_vertex.is_file() and shadow_fragment.is_file():
    vertex = shadow_vertex.read_text(encoding="utf-8")
    fragment = shadow_fragment.read_text(encoding="utf-8")
    for varying in ("vShadowTexCoord", "vShadowVertexColor"):
        if varying not in vertex or varying not in fragment:
            errors.append(f"Shadow alpha-test varying is missing or mismatched: {varying}")
    if "uniform sampler2D texture" not in fragment or "discard" not in fragment:
        errors.append("Shadow pass must sample the material texture and discard transparent texels")
    if "#define SHADOW_ALPHA_CUTOFF " not in fragment:
        errors.append("Shadow alpha cutoff must be an active shader option")

brief = ROOT / "PROJECT_BRIEF.md"
if not brief.is_file():
    errors.append("Missing cumulative PROJECT_BRIEF.md")

if errors:
    print("Serene Ultra structural validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("Serene Ultra structural validation passed.")
print("Note: GLSL compilation and in-game Iris compatibility require runtime testing.")
