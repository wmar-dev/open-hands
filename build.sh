#!/usr/bin/env bash
# Regenerate all STLs and preview images from robotic_hands.scad.
set -euo pipefail
cd "$(dirname "$0")"

SCAD=robotic_hands.scad
OPENSCAD=${OPENSCAD:-openscad}
BACKEND=(--backend=manifold)
IMG=(--backend=manifold --render --colorscheme=Tomorrow)

mkdir -p stl images

echo "Exporting STLs..."
"$OPENSCAD" "${BACKEND[@]}" -D 'part="palm"'  -D 'hand="right"' -o stl/palm_right.stl  "$SCAD"
"$OPENSCAD" "${BACKEND[@]}" -D 'part="palm"'  -D 'hand="left"'  -o stl/palm_left.stl   "$SCAD"
"$OPENSCAD" "${BACKEND[@]}" -D 'part="links"'                   -o stl/links.stl       "$SCAD"
"$OPENSCAD" "${BACKEND[@]}" -D 'part="wrist"'                   -o stl/wrist.stl       "$SCAD"
"$OPENSCAD" "${BACKEND[@]}" -D 'part="plate"' -D 'hand="right"' -o stl/plate_right.stl "$SCAD"
"$OPENSCAD" "${BACKEND[@]}" -D 'part="plate"' -D 'hand="left"'  -o stl/plate_left.stl  "$SCAD"

echo "Rendering images..."
"$OPENSCAD" "${IMG[@]}" -o images/front.png --imgsize=1400,900 --camera=0,0,80,75,0,15,640  "$SCAD"
"$OPENSCAD" "${IMG[@]}" -o images/back.png  --imgsize=1400,900 --camera=0,0,80,60,0,200,640 "$SCAD"
"$OPENSCAD" "${IMG[@]}" -o images/side.png  --imgsize=1200,900 --camera=85,0,70,85,0,90,520 "$SCAD"
"$OPENSCAD" "${IMG[@]}" -D 'part="plate"' -o images/print_plate.png --imgsize=1400,850 --camera=72,68,0,30,0,0,560 "$SCAD"
"$OPENSCAD" "${IMG[@]}" -D 'part="wrist"' -o images/wrist.png       --imgsize=800,700  --camera=0,0,20,55,0,25,200  "$SCAD"

echo "Done."
