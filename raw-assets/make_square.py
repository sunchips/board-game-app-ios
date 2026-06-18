"""Generate square game-cover assets with a blurred background.

Every raw image is composited onto a square canvas:
  1. A background is created (blurred copy of the source, or a solid color).
  2. The original image is scaled to fit and centered on top.

Per-game overrides live in GAME_CONFIG below.
"""

import sys
from PIL import Image, ImageFilter, ImageEnhance

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
BLUR_RADIUS = 40
BG_BRIGHTNESS = 0.6      # darken blurred bg to 60%
FOREGROUND_SCALE = 0.88   # foreground occupies 88% of the canvas

# ---------------------------------------------------------------------------
# Per-game overrides
#
# Keys are the slug (filename without extension).  Supported fields:
#   bg_color:      hex color string — use a solid color instead of blur
#   fg_scale:      override FOREGROUND_SCALE for this game
#   bg_brightness: override BG_BRIGHTNESS
#   blur_radius:   override BLUR_RADIUS
# ---------------------------------------------------------------------------
GAME_CONFIG = {
    "petiquette": {
        "fg_scale": 1.40,
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _dominant_color(img: Image.Image) -> tuple:
    """Average color of opaque pixels in an RGBA image."""
    pixels = list(img.get_flattened_data())
    opaque = [(r, g, b) for r, g, b, a in pixels if a > 128]
    if not opaque:
        return (255, 255, 255)
    n = len(opaque)
    return (sum(r for r, _, _ in opaque) // n,
            sum(g for _, g, _ in opaque) // n,
            sum(b for _, _, b in opaque) // n)


# ---------------------------------------------------------------------------
# Compositing
# ---------------------------------------------------------------------------

def make_blur_background(img: Image.Image, size: int, cfg: dict) -> Image.Image:
    """Scale source to fill square, crop, blur, darken."""
    w, h = img.size
    scale = size / min(w, h)
    bg_w, bg_h = int(w * scale), int(h * scale)
    bg = img.resize((bg_w, bg_h), Image.LANCZOS)

    left = (bg_w - size) // 2
    top = (bg_h - size) // 2
    bg = bg.crop((left, top, left + size, top + size))

    radius = cfg.get("blur_radius", BLUR_RADIUS)
    bg = bg.filter(ImageFilter.GaussianBlur(radius=radius))

    brightness = cfg.get("bg_brightness", BG_BRIGHTNESS)
    bg = ImageEnhance.Brightness(bg).enhance(brightness)

    return bg


def make_solid_background(size: int, color: str) -> Image.Image:
    """Create a solid-color square canvas."""
    return Image.new("RGB", (size, size), color)


def make_square(img: Image.Image, size: int, cfg: dict) -> Image.Image:
    w, h = img.size

    # --- Background / border layer ---
    bg_color = cfg.get("bg_color")
    if bg_color:
        border_layer = make_solid_background(size, bg_color)
    else:
        border_layer = make_blur_background(img, size, cfg)

    canvas = border_layer.copy()

    # --- Foreground ---
    fg_scale = cfg.get("fg_scale", FOREGROUND_SCALE)
    fg_max = int(size * fg_scale)
    scale = fg_max / max(w, h)
    fg_w, fg_h = int(w * scale), int(h * scale)
    fg = img.resize((fg_w, fg_h), Image.LANCZOS)

    x = (size - fg_w) // 2
    y = (size - fg_h) // 2
    canvas.paste(fg, (x, y))

    # --- Ensure border is always on top ---
    if fg_scale > FOREGROUND_SCALE:
        border_px = int(size * (1 - FOREGROUND_SCALE) / 2)
        mask = Image.new("L", (size, size), 255)
        inner = Image.new("L", (size - 2 * border_px, size - 2 * border_px), 0)
        mask.paste(inner, (border_px, border_px))
        canvas.paste(border_layer, mask=mask)

    return canvas


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <input> <output> <size>")
        sys.exit(1)

    input_path, output_path, size = sys.argv[1], sys.argv[2], int(sys.argv[3])

    import os
    slug = os.path.splitext(os.path.basename(input_path))[0]
    cfg = GAME_CONFIG.get(slug, {})

    img = Image.open(input_path)
    if img.mode == "RGBA":
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        bg_fill = _dominant_color(img)
        flat = Image.new("RGB", img.size, bg_fill)
        flat.paste(img, mask=img.split()[3])
        img = flat
    else:
        img = img.convert("RGB")
    result = make_square(img, size, cfg)
    result.save(output_path, "PNG")


if __name__ == "__main__":
    main()
