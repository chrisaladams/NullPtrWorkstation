#!/usr/bin/env bash
# publish-results.sh DIR BRANCH MESSAGE — push the contents of DIR (logs, screenshots) as a
# single commit to BRANCH. Commits from a fresh repository in a temporary directory, so
# nothing else from the workspace (e.g. the downloaded ISO) can ever be included; files over
# 20 MB are dropped as a second guard. Needs GH_TOKEN and GITHUB_REPOSITORY.
set -euo pipefail
src="$1"; branch="$2"; msg="$3"
d="$(mktemp -d)"
cp -r "$src"/. "$d"/
find "$d" -type f -size +20M -print -delete
cd "$d"
git init -q -b "$branch"
git config user.name "Chris Adams"
git config user.email "chrisaladams@gmail.com"
git add -A
git commit -qm "$msg"
git push -qf "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$branch"
echo "published $(git ls-files | wc -l) files to $branch"
