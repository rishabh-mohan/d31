"""Draws the launcher icon.

The icon has to be the project's own work: `assets/images/` is placeholder art
copied from KSS and is never published, so nothing in `android/app/src/main/res`
may be derived from it. This draws a plain mark from the D30 palette instead --
a cream "30" on the accent orange -- at every density Android asks for.

Outputs, all under android/app/src/main/res:

  mipmap-<density>/ic_launcher.png            legacy icon, full bleed
  mipmap-<density>/ic_launcher_foreground.png adaptive foreground, transparent
  mipmap-anydpi-v26/ic_launcher.xml           adaptive icon, written by hand
  values/ic_launcher_background.xml           the adaptive background colour

Run with the interpreter CLAUDE.md names:

  python -I tools/make_app_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"

ACCENT = (255, 139, 85, 255)  # D30Colors.accent
CREAM = (255, 248, 236, 255)  # D30Colors.panel

# Legacy launcher sizes, and the 108dp adaptive canvas at the same densities.
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# Any heavy sans will do; the glyphs are rasterised into the PNG, so this is a
# build-time dependency only. Falls back to PIL's bitmap font.
FONT_CANDIDATES = [
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def load_font(px: int) -> ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, px)
    print("warning: no TrueType font found, falling back to the bitmap font")
    return ImageFont.load_default(px)


def draw_label(image: Image.Image, box: int, height_fraction: float) -> None:
    """Centres "30" in the image, sized so its ink is `height_fraction` tall."""
    draw = ImageDraw.Draw(image)
    # Binary-search a point size: metrics differ per font, so measure the ink.
    target = box * height_fraction
    lo, hi = 1, box * 2
    best = 1
    while lo <= hi:
        mid = (lo + hi) // 2
        bbox = draw.textbbox((0, 0), "30", font=load_font(mid))
        if bbox[3] - bbox[1] <= target:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    font = load_font(best)
    bbox = draw.textbbox((0, 0), "30", font=font)
    draw.text(
        (
            (box - (bbox[2] - bbox[0])) / 2 - bbox[0],
            (box - (bbox[3] - bbox[1])) / 2 - bbox[1],
        ),
        "30",
        font=font,
        fill=CREAM,
    )


def legacy(box: int) -> Image.Image:
    """Full-bleed icon with rounded corners, for pre-adaptive launchers."""
    # Drawn at 4x and downsampled: the rounded corners alias badly at 48px.
    scale = 4
    big = Image.new("RGBA", (box * scale, box * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    draw.rounded_rectangle(
        (0, 0, box * scale - 1, box * scale - 1),
        radius=int(box * scale * 0.22),
        fill=ACCENT,
    )
    label = Image.new("RGBA", (box * scale, box * scale), (0, 0, 0, 0))
    draw_label(label, box * scale, 0.42)
    big.alpha_composite(label)
    return big.resize((box, box), Image.LANCZOS)


def adaptive_foreground(box: int) -> Image.Image:
    """Transparent 108dp layer. The launcher masks and may scale it, so the
    mark stays inside the inner 66dp safe zone."""
    scale = 4
    big = Image.new("RGBA", (box * scale, box * scale), (0, 0, 0, 0))
    # 66/108 of the canvas is guaranteed visible; keep the ink well inside it.
    draw_label(big, box * scale, 0.30)
    return big.resize((box, box), Image.LANCZOS)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"wrote {path.relative_to(RES.parent.parent.parent.parent)}")


def main() -> int:
    if not RES.exists():
        print(f"no res directory at {RES}", file=sys.stderr)
        return 1

    for density, (legacy_px, adaptive_px) in DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        legacy(legacy_px).save(folder / "ic_launcher.png")
        adaptive_foreground(adaptive_px).save(folder / "ic_launcher_foreground.png")
        print(f"wrote mipmap-{density}: {legacy_px}px legacy, {adaptive_px}px adaptive")

    write(
        RES / "mipmap-anydpi-v26/ic_launcher.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
    )
    write(
        RES / "values/ic_launcher_background.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#FF8B55</color>\n'
        "</resources>\n",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
