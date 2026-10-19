#!/bin/sh
set -eu

#SRC=/app/src/pricep
SRC=/app/src
OUT=/app/site/pricep

rm -rf "$OUT"
mkdir -p "$OUT"

npx lightningcss --minify "$SRC/style.css" -o "$OUT/style.css"
npx terser "$SRC/script.js" -c -m -o "$OUT/script.js"

npx html-minifier-terser \
  --collapse-whitespace \
  --remove-comments \
  --minify-css true \
  --minify-js true \
  "$SRC/index.html" -o "$OUT/index.html"

[ -d "$SRC/assets" ] && cp -r "$SRC/assets" "$OUT/assets"

echo "Build done: $OUT"