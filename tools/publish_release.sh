#!/usr/bin/env bash
set -euo pipefail

# Only create releases. A retry must never replace an existing tag or download.
cd "$(dirname "$0")/.."
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY}"
: "${GITHUB_SHA:?Set GITHUB_SHA to the tested commit}"
[[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]]
[[ "$(git rev-parse HEAD)" == "$GITHUB_SHA" ]]
version=$(python - <<'PY'
import pathlib, re, xml.etree.ElementTree as ET
root = pathlib.Path('.')
version = re.search(r'version\s*=\s*"(\d+\.\d+\.\d+)"', (root/'pokepal.koplugin/_meta.lua').read_text()).group(1)
assert ET.parse(root/'native/kual/config.xml').findtext('information/version') == version, 'KUAL version differs'
assert (root/'pokepal.koplugin/INSTALL.txt').read_text().splitlines()[0] == f'POKEPAL {version}', 'Install version differs'
assert (root/f'docs/release-v{version}.md').is_file(), 'Missing release notes'
print(version)
PY
)
tag="v$version"
notes="docs/release-$tag.md"

# Successful reads are required: network/authentication failures are not 404s.
releases=$(gh api "repos/$GITHUB_REPOSITORY/releases?per_page=100" --paginate --jq '.[].tag_name')
tags=$(gh api "repos/$GITHUB_REPOSITORY/git/matching-refs/tags/$tag" --jq '.[].ref')
if grep -Fxq "$tag" <<< "$releases" || grep -Fxq "refs/tags/$tag" <<< "$tags"; then
    echo "Refusing to change existing release or tag $tag. Bump the version for a new release." >&2
    exit 1
fi
if [[ "${1:-}" == --check ]]; then
    echo "Ready to build $tag from $GITHUB_SHA"
    exit 0
fi
[[ $# == 0 ]]

assets=("dist/PokePal-$tag-koreader.zip" "dist/PokePal-$tag-kual.zip"
        "dist/PokePal-$tag-corresponding-source.zip" "dist/PokePal-$tag-SHA256.txt")
for asset in "${assets[@]}"; do test -s "$asset"; done
(cd dist && sha256sum --check "PokePal-$tag-SHA256.txt")

# Creation must succeed before any upload or edit. No --clobber and no reuse of drafts.
gh release create "$tag" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" \
    --title "$version" --draft --notes-file "$notes"
gh release upload "$tag" "${assets[@]}" --repo "$GITHUB_REPOSITORY"

# Check the bytes GitHub serves before making this new draft public.
download=$(mktemp -d)
trap 'rm -rf "$download"' EXIT
gh release download "$tag" --repo "$GITHUB_REPOSITORY" --dir "$download"
for asset in "${assets[@]}"; do cmp "$asset" "$download/$(basename "$asset")"; done
(cd "$download" && sha256sum --check "PokePal-$tag-SHA256.txt")
gh release edit "$tag" --repo "$GITHUB_REPOSITORY" --draft=false --prerelease=false --latest
