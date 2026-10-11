#!/usr/bin/env bash
# Tag and publish a release.
#   usage: release.sh X.Y.Z
# Writes the version to both plugin manifests, commits, tags vX.Y.Z, pushes main and
# the tag, and creates the GitHub release. Refuses unless on a clean, up-to-date main.
set -euo pipefail
version="${1:?usage: release.sh X.Y.Z}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $version" >&2; exit 2; }
tag="v$version"
cd "$(git rev-parse --show-toplevel)"

[ "$(git branch --show-current)" = main ] || { echo "releases are cut from main" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean" >&2; exit 1; }
git fetch -q --tags origin main
[ -z "$(git rev-list HEAD..origin/main)" ] || { echo "main is behind origin/main" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then echo "$tag already exists" >&2; exit 1; fi

last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
if [ -n "$last" ]; then notes=$(git log --format='- %s' "$last..HEAD"); else notes="Initial release."; fi

# sed, not jq: keeps the manifests' formatting, and the two files identical.
for f in plugin.json .claude-plugin/plugin.json; do
  sed -E 's/("version": *")[^"]*/\1'"$version"'/' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
if ! out=$(claude plugin validate . 2>&1); then
  git checkout -q -- plugin.json .claude-plugin/plugin.json   # tree was clean, so this only undoes the bump
  echo "$out" >&2; echo "plugin validation failed; nothing was committed" >&2; exit 1
fi
git diff --quiet || git commit -qam "chore(release): $tag"
git tag -a "$tag" -m "$tag"
git push -q --atomic origin main "$tag"
gh release create "$tag" --title "$tag" --notes "$notes"
