"""Make a square image from any aspect ratio.

Square inputs:  center-crop to the target size.
Non-square:     fill a square canvas with a heavily blurred, scaled-up
                copy of the source, then overlay the original centered
                and scaled to fit (with a small margin).

The blur-background technique matches what Instagram / Spotify use for
non-square cover art.
"""

import sys
from PIL import Image, ImageFilter

ASPECT_TOLERANCE = 0.03  # treat within 3% of square as square
BLUR_RADIUS = 40         # gaussian blur radius for the background
BG_SATURATION = 1.1      # slightly boost saturation on the blurred bg
FOREGROUND_SCALE = 0.88  # foreground takes up 88% of the canvas


def center_crop_square(img: Image.Image, size: int) -> Image.Image:
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = img.crop((left, top, left + side, top + side))
    return cropped.resize((size, size), Image.LANCZOS)


def blur_background_square(img: Image.Image, size: int) -> Image.Image:
    w, h = img.size

    # --- Background: scale source to fill the square, then blur ---
    scale = size / min(w, h)
    bg_w, bg_h = int(w * scale), int(h * scale)
    bg = img.resize((bg_w, bg_h), Image.LANCZOS)

    # Center-crop the scaled bg to exact square
    left = (bg_w - size) // 2
    top = (bg_h - size) // 2
    bg = bg.crop((left, top, left + size, top + size))

    # Heavy gaussian blur
    bg = bg.filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS))

    # Darken slightly so the foreground pops
    from PIL import ImageEnhance
    bg = ImageEnhance.Brightness(bg).enhance(0.6)

    # --- Foreground: scale to fit within the canvas with margin ---
    fg_max = int(size * FOREGROUND_SCALE)
    fg_scale = fg_max / max(w, h)
    fg_w, fg_h = int(w * fg_scale), int(h * fg_scale)
    fg = img.resize((fg_w, fg_h), Image.LANCZOS)

    # Paste centered
    x = (size - fg_w) // 2
    y = (size - fg_h) // 2
    bg.paste(fg, (x, y))

    return bg


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <input> <output> <size>")
        sys.exit(1)

    input_path, output_path, size = sys.argv[1], sys.argv[2], int(sys.argv[3])

    img = Image.open(input_path).convert("RGB")
    w, h = img.size
    aspect = w / h

    result = blur_background_square(img, size)

    result.save(output_path, "PNG")


if __name__ == "__main__":
    main()
