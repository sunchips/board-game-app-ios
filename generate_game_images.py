#!/usr/bin/env python3
"""Generate placeholder game icons for the board game app asset catalog."""

import json
import os
from PIL import Image, ImageDraw, ImageFont

ASSETS_DIR = "BoardGameApp/Assets.xcassets/Games"

GAMES = [
    ("bunny-kingdom", "Bunny Kingdom", (139, 195, 74)),      # green
    ("calico", "Calico", (255, 167, 38)),                     # orange
    ("catan", "Catan", (198, 40, 40)),                        # red
    ("codenames", "Codenames", (30, 30, 30)),                  # dark
    ("coup", "Coup", (156, 39, 176)),                         # purple
    ("everdell", "Everdell", (76, 175, 80)),                  # forest green
    ("hanabi", "Hanabi", (244, 67, 54)),                      # firework red
    ("hues-and-cues", "Hues & Cues", (0, 188, 212)),          # cyan
    ("jaipur", "Jaipur", (255, 193, 7)),                      # amber
    ("king-of-new-york", "King of NY", (33, 150, 243)),       # blue
    ("parks", "Parks", (46, 125, 50)),                        # park green
    ("petiquette", "Petiquette", (255, 112, 67)),             # deep orange
    ("scythe", "Scythe", (69, 90, 100)),                     # blue-grey
    ("secret-hitler", "Secret Hitler", (183, 28, 28)),        # dark red
    ("the-king-is-dead", "King Is Dead", (121, 85, 72)),      # brown
    ("viticulture", "Viticulture", (106, 27, 154)),           # deep purple
    ("wavelength", "Wavelength", (233, 30, 99)),              # pink
]

CONTENTS_JSON = {
    "images": [{"filename": "image.png", "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1},
}

FOLDER_CONTENTS = {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": True}}

SIZE = 512


def create_game_image(name: str, color: tuple[int, int, int], path: str):
    img = Image.new("RGB", (SIZE, SIZE), color)
    draw = ImageDraw.Draw(img)

    # Draw a subtle darker border/vignette effect
    border_color = tuple(max(0, c - 40) for c in color)
    for i in range(8):
        draw.rectangle([i, i, SIZE - 1 - i, SIZE - 1 - i], outline=border_color)

    # Draw the game initial large and centered
    initials = "".join(w[0] for w in name.split() if w[0].isalpha())[:2]

    # Try to use a system font
    font_size = 180
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFCompact-Bold.otf", font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except (OSError, IOError):
            font = ImageFont.load_default()

    # Center the text
    bbox = draw.textbbox((0, 0), initials, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (SIZE - tw) / 2 - bbox[0]
    y = (SIZE - th) / 2 - bbox[1] - 10

    # Text shadow
    draw.text((x + 2, y + 2), initials, fill=(0, 0, 0, 128), font=font)
    # White text
    draw.text((x, y), initials, fill=(255, 255, 255), font=font)

    # Game name at bottom
    small_size = 32
    try:
        small_font = ImageFont.truetype("/System/Library/Fonts/SFCompact-Medium.otf", small_size)
    except (OSError, IOError):
        try:
            small_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", small_size)
        except (OSError, IOError):
            small_font = ImageFont.load_default()

    bbox2 = draw.textbbox((0, 0), name, font=small_font)
    tw2 = bbox2[2] - bbox2[0]
    x2 = (SIZE - tw2) / 2 - bbox2[0]
    draw.text((x2 + 1, SIZE - 60 + 1), name, fill=(0, 0, 0, 128), font=small_font)
    draw.text((x2, SIZE - 60), name, fill=(255, 255, 255, 230), font=small_font)

    img.save(path, "PNG")


def main():
    # Create the Games folder Contents.json
    games_dir = ASSETS_DIR
    with open(os.path.join(games_dir, "Contents.json"), "w") as f:
        json.dump(FOLDER_CONTENTS, f, indent=2)

    for slug, name, color in GAMES:
        imageset_dir = os.path.join(games_dir, f"{slug}.imageset")
        os.makedirs(imageset_dir, exist_ok=True)

        # Write Contents.json
        with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
            json.dump(CONTENTS_JSON, f, indent=2)

        # Generate the image
        img_path = os.path.join(imageset_dir, "image.png")
        create_game_image(name, color, img_path)
        print(f"  Created {slug}")

    print(f"\nDone! {len(GAMES)} game images created.")


if __name__ == "__main__":
    main()
