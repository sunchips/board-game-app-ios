#!/bin/bash
# Generate 1x/2x/3x image assets from raw source images.
# Usage: ./generate-assets.sh
#
# The game picker grid cards are ~170pt wide (square), so:
#   1x = 170px, 2x = 340px, 3x = 510px
#
# Each raw image is center-cropped to a square, then resized to all three scales.

set -euo pipefail
cd "$(dirname "$0")"

ASSETS_DIR="../BoardGameApp/Assets.xcassets/Games"
SIZE_1X=170
SIZE_2X=340
SIZE_3X=510

for raw in *.jpg *.png; do
    [ -f "$raw" ] || continue
    slug="${raw%.*}"
    imageset="$ASSETS_DIR/$slug.imageset"

    if [ ! -d "$imageset" ]; then
        echo "⚠ No imageset for $slug, skipping"
        continue
    fi

    echo "Processing $slug..."

    # Get dimensions
    w=$(sips -g pixelWidth "$raw" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$raw" | awk '/pixelHeight/{print $2}')

    # Center-crop to square (use the smaller dimension)
    if [ "$w" -gt "$h" ]; then
        crop_size=$h
        offset_x=$(( (w - h) / 2 ))
        offset_y=0
    else
        crop_size=$w
        offset_x=0
        offset_y=$(( (h - w) / 2 ))
    fi

    # Create temp square crop
    tmp="/tmp/${slug}_square.png"
    sips -c "$crop_size" "$crop_size" --cropOffset "$offset_y" "$offset_x" "$raw" --out "$tmp" > /dev/null 2>&1

    # Generate each scale
    for scale in 1 2 3; do
        case $scale in
            1) size=$SIZE_1X; suffix="" ;;
            2) size=$SIZE_2X; suffix="@2x" ;;
            3) size=$SIZE_3X; suffix="@3x" ;;
        esac
        out="$imageset/${slug}${suffix}.png"
        sips -z "$size" "$size" "$tmp" --out "$out" > /dev/null 2>&1
        echo "  ${scale}x: ${size}px → $(basename "$out")"
    done

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

    # Remove the old single image.png if it exists and isn't one of our generated files
    old="$imageset/image.png"
    if [ -f "$old" ] && [ "$(basename "$old")" = "image.png" ]; then
        rm "$old"
    fi

    rm "$tmp"
done

echo "Done! All assets generated."
