#!/usr/bin/env bash
set -euo pipefail
mkdir -p Mawaru/Fonts
base="https://raw.githubusercontent.com/google/fonts/main/ofl"

fetch_font() {
  local family="$1"
  local file="$2"
  curl --retry 3 --retry-delay 2 --fail --location --silent --show-error \
    "$base/$family/$file" -o "Mawaru/Fonts/$file"
  curl --retry 3 --retry-delay 2 --fail --location --silent --show-error \
    "$base/$family/OFL.txt" -o "Mawaru/Fonts/$file.license.txt"
}

fetch_font yomogi Yomogi-Regular.ttf
fetch_font kleeone KleeOne-Regular.ttf
fetch_font zenkurenaido ZenKurenaido-Regular.ttf

python3 - <<'PY'
from pathlib import Path
fonts = list(Path("Mawaru/Fonts").glob("*.ttf"))
if len(fonts) != 3:
    raise SystemExit("Expected three font resources")
for font in fonts:
    magic = font.read_bytes()[:4]
    if magic not in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
        raise SystemExit(f"Invalid font data: {font}")
    if font.stat().st_size < 100000:
        raise SystemExit(f"Font unexpectedly tiny: {font}")
    print("Verified font resource:", font.name, font.stat().st_size, "bytes")
PY
