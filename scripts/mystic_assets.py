#!/usr/bin/env python3
"""
Generate simple Mystic Recovery raster branding for the PBRP theme.

This avoids shipping opaque binary art in the repository while replacing the
PBRP splash/logo/button images that would otherwise remain visible.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    Image = None  # type: ignore[assignment]

BG = (20, 20, 20, 255)
CARD = (30, 30, 34, 255)
ACCENT = (124, 77, 255, 255)
ACCENT_DIM = (90, 55, 190, 255)
WHITE = (245, 245, 245, 255)
MUTED = (180, 180, 190, 255)

FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
)


def font(size: int):
    for path in FONT_CANDIDATES:
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def centered(draw, box, text, size, fill=WHITE):
    x0, y0, x1, y1 = box
    draw.text(
        ((x0 + x1) // 2, (y0 + y1) // 2),
        text,
        font=font(size),
        fill=fill,
        anchor="mm",
    )


def make_mark(size: int):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    inset = max(2, size // 32)
    d.rounded_rectangle(
        (inset, inset, size - inset - 1, size - inset - 1),
        radius=size // 4,
        fill=BG,
        outline=ACCENT,
        width=max(2, size // 24),
    )
    centered(d, (0, 0, size, size - size // 14), "M", int(size * 0.58), ACCENT)
    d.ellipse(
        (size // 2 - size // 24, size - size // 5,
         size // 2 + size // 24, size - size // 5 + size // 12),
        fill=WHITE,
    )
    return im


def make_splash(size: int = 719):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pad = 24
    d.ellipse((pad, pad, size - pad, size - pad), fill=BG, outline=ACCENT, width=10)
    d.ellipse(
        (pad + 34, pad + 34, size - pad - 34, size - pad - 34),
        outline=ACCENT_DIM,
        width=3,
    )
    centered(d, (0, size * 0.25, size, size * 0.60), "MysticRecovery", 90, WHITE)
    d.line(
        (size * 0.28, size * 0.71, size * 0.72, size * 0.71),
        fill=ACCENT_DIM,
        width=4,
    )
    centered(d, (0, size * 0.68, size, size * 0.93), "SM-T510", 34, MUTED)
    return im


def make_power_logo(w: int = 940, h: int = 377):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line((30, h - 42, w - 30, h - 42), fill=ACCENT_DIM, width=5)
    centered(d, (0, 30, w, h * 0.75), "MysticRecovery", 110, WHITE)
    return im


def make_card(w: int = 1080, h: int = 458, label: str = "MYSTIC"):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 12, w - 5, h - 13), radius=36, fill=CARD, outline=ACCENT_DIM, width=4)
    d.rounded_rectangle((4, 12, 22, h - 13), radius=9, fill=ACCENT)
    centered(d, (60, 0, w - 40, h), label, 96, WHITE)
    return im


def write_if_changed(path: Path, im, dry_run: bool) -> bool:
    if dry_run:
        print(f"[dry-run] would generate asset {path}")
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"[asset] {path}")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate Mystic theme images")
    ap.add_argument("--root", required=True)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if Image is None:
        print("error: Pillow is required (install python3-pil)", file=sys.stderr)
        return 2

    root = Path(args.root)
    theme = root / "bootable" / "recovery" / "gui" / "theme" / "portrait_hdpi" / "images"
    if not theme.is_dir():
        print(f"asset skip: {theme} not found")
        return 0

    write_if_changed(theme / "logo.png", make_mark(128), args.dry_run)
    write_if_changed(theme / "pb.png", make_mark(128), args.dry_run)
    write_if_changed(theme / "about.png", make_mark(119), args.dry_run)
    write_if_changed(theme / "splashlogo.png", make_splash(719), args.dry_run)
    write_if_changed(theme / "power_logo.png", make_power_logo(940, 377), args.dry_run)

    cards = {
        "main_button_pbrp_about.png": "ABOUT MYSTICRECOVERY",
        "main_button_pbrp_custom.png": "CUSTOMIZE",
        "main_button_pbrp_tools.png": "MYSTICRECOVERY TOOLS",
        "main_button_pbrp_special_settings.png": "SPECIAL SETTINGS",
    }
    for name, label in cards.items():
        if (theme / name).is_file():
            write_if_changed(theme / name, make_card(1080, 458, label), args.dry_run)

    return 0


if __name__ == "__main__":
    sys.exit(main())
