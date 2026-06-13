#!/usr/bin/env python3
"""Download board game images from Wikipedia for the asset catalog."""

import json
import os
import time
import urllib.request
from PIL import Image
from io import BytesIO

ASSETS_DIR = "BoardGameApp/Assets.xcassets/Games"

# (slug, Wikipedia article title)
GAMES = [
    ("bunny-kingdom", "Bunny_Kingdom"),
    ("calico", "Calico_(board_game)"),
    ("catan", "Catan"),
    ("codenames", "Codenames_(board_game)"),
    ("coup", "Coup_(card_game)"),
    ("everdell", "Everdell"),
    ("hanabi", "Hanabi_(card_game)"),
    ("hues-and-cues", "Hues_and_Cues"),
    ("jaipur", "Jaipur_(card_game)"),
    ("king-of-new-york", "King_of_New_York_(board_game)"),
    ("parks", "Parks_(board_game)"),
    ("petiquette", None),
    ("scythe", "Scythe_(board_game)"),
    ("secret-hitler", "Secret_Hitler"),
    ("the-king-is-dead", "The_King_Is_Dead_(board_game)"),
    ("viticulture", "Viticulture_(board_game)"),
    ("wavelength", "Wavelength_(board_game)"),
]

WIKI_REST = "https://en.wikipedia.org/api/rest_v1/page/summary/{}"
UA = "BoardGameApp/1.0 (personal hobby project; sanchitbhatnagar@gmail.com)"


def fetch_image_url(title: str) -> str | None:
    url = WIKI_REST.format(urllib.request.quote(title))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    # Prefer original over thumbnail for better quality
    orig = data.get("originalimage", {}).get("source")
    if orig:
        return orig
    return data.get("thumbnail", {}).get("source")


def download_and_save(url: str, path: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req) as resp:
        data = resp.read()

    img = Image.open(BytesIO(data))
    img = img.convert("RGB")
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(path, "PNG")


def main():
    for slug, wiki_title in GAMES:
        print(f"  {slug}...", end=" ", flush=True)

        if wiki_title is None:
            print("SKIPPED (no Wikipedia article)")
            continue

        try:
            image_url = fetch_image_url(wiki_title)
            if not image_url:
                print("NO IMAGE")
                continue

            img_path = os.path.join(ASSETS_DIR, f"{slug}.imageset", "image.png")
            download_and_save(image_url, img_path)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")

        time.sleep(2)

    print("\nDone!")


if __name__ == "__main__":
    main()
