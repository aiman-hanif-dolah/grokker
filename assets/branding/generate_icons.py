#!/usr/bin/env python3
"""Generate Grokker logo SVG and raster icon assets from geometric specs."""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent.parent

CX = CY = 512.0
BACKGROUND = "#000000"
STRUCTURE = "#FFFFFF"
GREEN = "#71CA0A"
TEAL = "#03B7A6"
BLUE = "#0162E3"
PURPLE = "#7739F1"

RING_OUTER_R = 132
RING_INNER_R = 62
ARC_OUTER_R = 200
ARC_INNER_R = 158
ARC_SPAN = 52

BLADES = [
    (135, GREEN, 468, 32, 115, 38, 12),
    (45, TEAL, 538, 32, 115, 38, 12),
    (-45, BLUE, 450, 32, 115, 38, 12),
    (-135, PURPLE, 512, 32, 115, 38, 12),
]


def pol(r: float, angle_deg: float) -> tuple[float, float]:
    a = math.radians(angle_deg)
    return (CX + r * math.cos(a), CY - r * math.sin(a))


def fmt(point: tuple[float, float]) -> str:
    return f"{point[0]:.2f},{point[1]:.2f}"


def annular_sector(r_inner: float, r_outer: float, a1: float, a2: float) -> str:
    p1 = pol(r_outer, a1)
    p2 = pol(r_outer, a2)
    p3 = pol(r_inner, a2)
    p4 = pol(r_inner, a1)
    large = 1 if abs(a2 - a1) > 180 else 0
    return (
        f"M {fmt(p1)} "
        f"A {r_outer},{r_outer} 0 {large} 0 {fmt(p2)} "
        f"L {fmt(p3)} "
        f"A {r_inner},{r_inner} 0 {large} 1 {fmt(p4)} Z"
    )


def blade_path(
    tip_angle: float,
    tip_r: float,
    spread_deg: float,
    inner_r: float,
    notch_depth: float,
    notch_half_width: float,
) -> str:
    tip = pol(tip_r, tip_angle)
    left = pol(inner_r, tip_angle + spread_deg / 2)
    right = pol(inner_r, tip_angle - spread_deg / 2)
    notch_outer = inner_r + notch_depth
    notch_left = pol(notch_outer, tip_angle + notch_half_width)
    notch_right = pol(notch_outer, tip_angle - notch_half_width)
    notch_tip = pol(notch_outer + notch_depth * 0.75, tip_angle)
    return (
        f"M {fmt(tip)} L {fmt(left)} L {fmt(notch_left)} "
        f"L {fmt(notch_tip)} L {fmt(notch_right)} L {fmt(right)} Z"
    )


def build_svg() -> str:
    arcs = [
        annular_sector(ARC_INNER_R, ARC_OUTER_R, 90 - ARC_SPAN / 2, 90 + ARC_SPAN / 2),
        annular_sector(ARC_INNER_R, ARC_OUTER_R, -ARC_SPAN / 2, ARC_SPAN / 2),
        annular_sector(ARC_INNER_R, ARC_OUTER_R, -90 - ARC_SPAN / 2, -90 + ARC_SPAN / 2),
        annular_sector(ARC_INNER_R, ARC_OUTER_R, 180 - ARC_SPAN / 2, 180 + ARC_SPAN / 2),
    ]
    blades = [
        blade_path(angle, tip_r, spread, inner_r, notch_depth, notch_half)
        for angle, _, tip_r, spread, inner_r, notch_depth, notch_half in BLADES
    ]
    colors = [color for _, color, *_ in BLADES]

    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Grokker">',
        f'<rect width="1024" height="1024" fill="{BACKGROUND}"/>',
        f'<circle cx="{CX}" cy="{CY}" r="{RING_OUTER_R}" fill="{STRUCTURE}"/>',
        f'<circle cx="{CX}" cy="{CY}" r="{RING_INNER_R}" fill="{BACKGROUND}"/>',
    ]
    for arc in arcs:
        parts.append(f'<path d="{arc}" fill="{STRUCTURE}"/>')
    for color, blade in zip(colors, blades):
        parts.append(f'<path d="{blade}" fill="{color}"/>')
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def render_png(svg_path: Path, png_path: Path, size: int) -> None:
    subprocess.run(
        [
            "rsvg-convert",
            "-w",
            str(size),
            "-h",
            str(size),
            "-o",
            str(png_path),
            str(svg_path),
        ],
        check=True,
    )


def write_ico(png_paths: list[tuple[int, Path]], ico_path: Path) -> None:
    images = [Image.open(path).convert("RGBA") for _, path in png_paths]
    images[0].save(
        ico_path,
        format="ICO",
        sizes=[(img.width, img.height) for img in images],
        append_images=images[1:],
    )


def main() -> None:
    svg_path = ROOT / "grokker_logo.svg"
    svg_path.write_text(build_svg(), encoding="utf-8")

    sizes = {
        "grokker_logo.png": 1024,
        "grokker_logo_48.png": 48,
        "favicon.png": 32,
        "favicon_16.png": 16,
        "favicon_32.png": 32,
        "favicon_48.png": 48,
        "favicon_64.png": 64,
        "favicon_128.png": 128,
        "favicon_256.png": 256,
    }
    for name, size in sizes.items():
        render_png(svg_path, ROOT / name, size)

    write_ico(
        [
            (16, ROOT / "favicon_16.png"),
            (32, ROOT / "favicon_32.png"),
            (48, ROOT / "favicon_48.png"),
            (64, ROOT / "favicon_64.png"),
            (128, ROOT / "favicon_128.png"),
            (256, ROOT / "favicon_256.png"),
        ],
        ROOT / "favicon.ico",
    )

    mac_icon_dir = PROJECT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    mac_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for name, size in mac_sizes.items():
        render_png(svg_path, mac_icon_dir / name, size)

    win_png = PROJECT / "windows/runner/resources/app_icon.png"
    win_ico = PROJECT / "windows/runner/resources/app_icon.ico"
    render_png(svg_path, win_png, 256)
    write_ico(
        [
            (16, ROOT / "favicon_16.png"),
            (32, ROOT / "favicon_32.png"),
            (48, ROOT / "favicon_48.png"),
            (64, ROOT / "favicon_64.png"),
            (128, ROOT / "favicon_128.png"),
            (256, ROOT / "favicon_256.png"),
        ],
        win_ico,
    )

    print(f"Wrote {svg_path}")
    print("Generated PNG/ICO assets and macOS app icons.")


if __name__ == "__main__":
    main()