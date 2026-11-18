#!/bin/bash
#
# Builds "Wolfenstein The New Order.app" from YOUR copy of Wolfenstein: The New Order (Windows version, Steam).
# Nothing from the game is stored in this repository; everything is generated locally from your install.
#
# Usage: scripts/build.sh [path/to/Wolfenstein.The.New.Order]   (the folder with WolfNewOrder_x64.exe)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "error: $*" >&2; exit 1; }
step() { echo "==> [$1/6] $2"; }

find_game() {
    local c
    for c in \
        "$HOME/Library/Application Support/Steam/steamapps/common/Wolfenstein.The.New.Order" \
        "$HOME/Library/Application Support/CrossOver/Bottles/"*"/drive_c/Program Files (x86)/Steam/steamapps/common/Wolfenstein.The.New.Order"; do
        [[ -f "$c/WolfNewOrder_x64.exe" ]] && { echo "$c"; return; }
    done
}
GAME="${1:-$(find_game)}"
[[ -n "$GAME" ]] || die "the game was not found. Pass the folder that contains WolfNewOrder_x64.exe"

# The Steam release this project is written against (see docs/NOTES.md)
SHA_EXE="9e413197e097ba41e85f0de47ddd3918f7656c432f8431f5f15e4b7eeb7c371c"          # as shipped (SteamStub)
SHA_UNWRAPPED="bd70efffbd47ebbf93232838af0d89d63ff8432c13757516701556edeaca3f2b"    # after tools/unwrap_steamstub.py
SHA_SUPERSCRIPT="e8d1b5f6cb6dffeb992e146d1bd5d953bf07812bbad7644468a61240f895cf70"
SHA_BINK="07915cf09c53bdec299854d05dba1435e15a5640c71f1ac48b0cd5512046e8f1"

step 1 "Checking requirements"
for t in clang make python3 codesign ar openssl; do
    command -v "$t" >/dev/null 2>&1 || die "'$t' was not found. Install Apple's Command Line Tools: xcode-select --install"
done
[[ "$(uname -m)" == "arm64" ]] || die "this build targets Apple Silicon Macs"

step 2 "Verifying your copy of the game"
check() {
    [[ -f "$1" ]] || die "$1 was not found"
    local sha; sha="$(shasum -a 256 "$1" | awk '{print $1}')"
    [[ "$sha" == "$2" ]] || die "$1 is not from the supported Steam release (SHA-256 $sha)"
}
check "$GAME/WolfNewOrder_x64.exe" "$SHA_EXE"
check "$GAME/superscriptx64.dll" "$SHA_SUPERSCRIPT"
check "$GAME/bink2w64.dll" "$SHA_BINK"

step 3 "Preparing the translator"
[[ -x "$ROOT/.venv/bin/python" ]] || python3 -m venv "$ROOT/.venv"
"$ROOT/.venv/bin/python" -m pip install --quiet --disable-pip-version-check "capstone==5.0.6" "lief==0.16.6"

cd "$ROOT"
mkdir -p build
python3 -I tools/unwrap_steamstub.py "$GAME/WolfNewOrder_x64.exe" build/WolfNewOrder_x64.unwrapped.exe
check build/WolfNewOrder_x64.unwrapped.exe "$SHA_UNWRAPPED"
ln -sf build/WolfNewOrder_x64.unwrapped.exe orig.exe
ln -sf "$GAME/superscriptx64.dll" orig_superscript.dll
ln -sf "$GAME/bink2w64.dll" orig_bink.dll

step 4 "Translating the game's code to C"
make -s gen
make -s gen-dll
make -s gen-bink

step 5 "Compiling"
make -s -j"$(sysctl -n hw.ncpu)" boot

step 6 "Packaging the app"
make -s app
echo "Done: build/Wolfenstein The New Order.app"
