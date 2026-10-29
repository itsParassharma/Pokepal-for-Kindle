#!/usr/bin/env bash
set -euo pipefail

archive=$(realpath "${1:?Pass the corresponding-source ZIP}")
version=${2:?Pass the release tag}
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
filename="PokePal-${version}-corresponding-source.zip"
[[ "$(basename "$archive")" == "$filename" ]]
expected=$(sha256sum "$archive" | cut -d ' ' -f 1)
checkout=$(mktemp -d)
trap 'git worktree remove --force "$checkout"' EXIT

if git ls-remote --exit-code --heads origin release-sources >/dev/null; then
    git fetch --no-tags origin release-sources
    git worktree add --detach "$checkout" FETCH_HEAD
else
    git worktree add --detach "$checkout" HEAD
    git -C "$checkout" switch --orphan release-sources
fi
mkdir -p "$checkout/$version"
cp "$archive" "$checkout/$version/$filename"
git -C "$checkout" add "$version/$filename"
if ! git -C "$checkout" diff --cached --quiet; then
    git -C "$checkout" -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' commit -m "Source download for $version"
    git -C "$checkout" push origin HEAD:refs/heads/release-sources
fi

# Verify the public download before removing the copy from release assets.
download="$checkout/download.zip"
curl --fail --location --retry 5 --retry-all-errors --max-time 60 \
    "https://github.com/${GITHUB_REPOSITORY}/raw/refs/heads/release-sources/$version/$filename" -o "$download"
printf '%s  %s\n' "$expected" "$download" | sha256sum --check
