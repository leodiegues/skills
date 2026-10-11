#!/usr/bin/env bash
# Print the next release version (no leading "v").
#   usage: next-version.sh [major|minor|patch|X.Y.Z]
# No v* tag yet → 0.1.0. Otherwise bump the latest v* tag: by the argument if given,
# else inferred from the conventional commits since that tag
# (breaking → major, or minor while still 0.x; feat → minor; anything else → patch).
set -euo pipefail
arg="${1:-}"
if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "$arg"; exit; fi

last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
if [ -z "$last" ]; then echo "0.1.0"; exit; fi
[ -n "$(git rev-list "$last..HEAD")" ] || { echo "nothing to release: no commits since $last" >&2; exit 1; }

IFS=. read -r major minor patch <<<"${last#v}"
if [ -z "$arg" ]; then
  log=$(git log --format='%s%n%b' "$last..HEAD")
  if grep -qE '^[a-z]+(\([^)]*\))?!:|^BREAKING CHANGE' <<<"$log"; then
    [ "$major" = 0 ] && arg=minor || arg=major
  elif grep -qE '^feat(\([^)]*\))?:' <<<"$log"; then arg=minor
  else arg=patch; fi
fi
case "$arg" in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
  *) echo "usage: next-version.sh [major|minor|patch|X.Y.Z]" >&2; exit 2 ;;
esac
