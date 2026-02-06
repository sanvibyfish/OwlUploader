#!/usr/bin/env python3
"""Generate DEV-badged app icons for Debug builds.

Reads each PNG from AppIcon.appiconset, overlays a red "DEV" badge
in the bottom-right corner, and writes the results to AppIcon-Dev.appiconset.

Usage:
    pip install Pillow
    python scripts/generate_dev_icon.py
"""

import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "OwlUploader" / "Assets.xcassets" / "AppIcon.appiconset"
DST_DIR = REPO_ROOT / "OwlUploader" / "Assets.xcassets" / "AppIcon-Dev.appiconset"

ICON_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def add_dev_badge(img: Image.Image) -> Image.Image:
    """Overlay a red rounded-rect 'DEV' badge on the bottom-right corner."""
    img = img.copy().convert("RGBA")
    size = img.width  # icons are square

    # Badge dimensions relative to icon size
    badge_h = max(int(size * 0.22), 6)
    badge_w = max(int(size * 0.42), 12)
    radius = max(int(badge_h * 0.28), 2)
    margin = max(int(size * 0.04), 1)

    # Position: bottom-right
    x1 = size - margin - badge_w
    y1 = size - margin - badge_h
    x2 = size - margin
    y2 = size - margin

    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Draw red rounded rectangle
    draw.rounded_rectangle(
        [(x1, y1), (x2, y2)],
        radius=radius,
        fill=(220, 38, 38, 230),  # red with slight transparency
    )

    # Pick font size to fit inside the badge (minimum 8 to avoid rendering issues)
    font_size = max(int(badge_h * 0.65), 8)
    try:
        # macOS system font
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype(
                "/System/Library/Fonts/SFCompact.ttf", font_size
            )
        except (OSError, IOError):
            font = ImageFont.load_default()

    # Center text in badge
    text = "DEV"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = x1 + (badge_w - tw) / 2
    ty = y1 + (badge_h - th) / 2 - bbox[1]  # adjust for font ascent

    draw.text((tx, ty), text, fill=(255, 255, 255, 255), font=font)

    return Image.alpha_composite(img, overlay)


def generate_contents_json() -> dict:
    """Build Contents.json for the Dev icon set, mirroring the original."""
    src_contents = json.loads((SRC_DIR / "Contents.json").read_text())
    dst_images = []
    for entry in src_contents["images"]:
        dst_entry = dict(entry)
        dst_entry["folder"] = "Assets.xcassets/AppIcon-Dev.appiconset/"
        dst_images.append(dst_entry)
    return {"images": dst_images}


def main():
    DST_DIR.mkdir(parents=True, exist_ok=True)

    for sz in ICON_SIZES:
        src_path = SRC_DIR / f"{sz}.png"
        if not src_path.exists():
            print(f"  [skip] {src_path.name} not found")
            continue

        img = Image.open(src_path)
        result = add_dev_badge(img)
        dst_path = DST_DIR / f"{sz}.png"
        result.save(dst_path, "PNG")
        print(f"  [ok]   {sz}x{sz} -> {dst_path}")

    contents = generate_contents_json()
    contents_path = DST_DIR / "Contents.json"
    contents_path.write_text(json.dumps(contents, indent=2) + "\n")
    print(f"  [ok]   Contents.json -> {contents_path}")
    print("\nDone! DEV icons generated in AppIcon-Dev.appiconset/")


if __name__ == "__main__":
    main()
