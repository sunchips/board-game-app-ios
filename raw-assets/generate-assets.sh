#!/bin/bash
# Generate 1x/2x/3x image assets from raw source images.
# Usage: ./generate-assets.sh
#
# The game picker grid cards are ~170pt wide (square), so:
#   1x = 170px, 2x = 340px, 3x = 510px
#
# Square images are resized directly.
# Non-square images get a blurred version of themselves as background,
# with the original image centered on the square canvas.

set -euo pipefail
cd "$(dirname "$0")"

ASSETS_DIR="../BoardGameApp/Assets.xcassets/Games"
SIZE_3X=510

SCRIPT_DIR="$(pwd)"

for raw in *.jpg *.png; do
    [ -f "$raw" ] || continue
    slug="${raw%.*}"
    imageset="$ASSETS_DIR/$slug.imageset"

    if [ ! -d "$imageset" ]; then
        echo "⚠ No imageset for $slug, skipping"
        continue
    fi

    echo "Processing $slug..."

    # Generate the 3x square image (510x510) using Python
    # Python handles both square (center-crop) and non-square (blur background)
    tmp="/tmp/${slug}_square_3x.png"
    python3 "$SCRIPT_DIR/make_square.py" "$raw" "$tmp" "$SIZE_3X"

    # Generate 2x and 1x by downscaling from 3x
    out_3x="$imageset/${slug}@3x.png"
    out_2x="$imageset/${slug}@2x.png"
    out_1x="$imageset/${slug}.png"

    cp "$tmp" "$out_3x"
    sips -z 340 340 "$tmp" --out "$out_2x" > /dev/null 2>&1
    sips -z 170 170 "$tmp" --out "$out_1x" > /dev/null 2>&1

    echo "  1x: 170px, 2x: 340px, 3x: 510px"

    # Update Contents.json
    cat > "$imageset/Contents.json" << EOJSON
{
  "images" : [
    {
      "filename" : "${slug}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "${slug}@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "${slug}@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOJSON

    # Remove the old single image.png if it exists
    old="$imageset/image.png"
    if [ -f "$old" ] && [ "$(basename "$old")" = "image.png" ]; then
        rm "$old"
    fi

    rm "$tmp"
done

echo "Done! All assets generated."
