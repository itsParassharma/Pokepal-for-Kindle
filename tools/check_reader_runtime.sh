#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software
curl --fail --location --retry 3 --output "$work/koreader.tar.xz" \
    https://github.com/koreader/koreader/releases/download/v2026.07.1/koreader-linux-x86_64-v2026.07.1.tar.xz
echo "299aadb28147a25e9432ced1214ea444a4184393b5ae97cf42402c8a61b1a1b0  $work/koreader.tar.xz" | sha256sum --check
mkdir "$work/koreader"
tar -xJf "$work/koreader.tar.xz" -C "$work/koreader"
cd "$work/koreader/lib/koreader"
KO_HOME="$(mktemp -d "$work/home.XXXXXX")" ./luajit "$root/tests/test_koreader_runtime.lua" "$root/pokepal.koplugin" | tee "$work/koreader.log"
grep -q 'KOREADER RUNTIME: .* checks passed' "$work/koreader.log"
git init "$work/simpleui-source"
git -C "$work/simpleui-source" fetch --depth=1 https://github.com/doctorhetfield-cmd/simpleui.koplugin.git \
    e5cd6dcb31fa759b9831223d4719f61126367cff 257c26d6685ced4fc2e895f98287b5f16f1d4f5e
mkdir -p "$root/tests/rendered"
for revision in e5cd6dcb31fa759b9831223d4719f61126367cff 257c26d6685ced4fc2e895f98287b5f16f1d4f5e; do
    target="$work/$revision.koplugin"
    mkdir "$target"
    git -C "$work/simpleui-source" archive "$revision" | tar -x -C "$target"
    KO_HOME="$(mktemp -d "$work/home.XXXXXX")" ./luajit "$root/tests/test_simpleui_runtime.lua" "$root/pokepal.koplugin" "$target" "$root/tests/rendered/simpleui-$revision.png" | tee "$work/critter.log"
    grep -q 'SIMPLEUI UPSTREAM RUNTIME: .* passed' "$work/critter.log"
    KO_HOME="$(mktemp -d "$work/home.XXXXXX")" ./luajit "$root/tests/test_simpleui_module_runtime.lua" "$root/pokepal.koplugin" "$target" "$root/tests/rendered/simpleui-card-$revision" | tee "$work/card.log"
    grep -q 'SIMPLEUI MODULE RUNTIME: all checks passed' "$work/card.log"
done
