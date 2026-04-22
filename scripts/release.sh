#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [patch|minor|major|<semver>|none]

Defaults to:
  patch

Examples:
  scripts/release.sh
  scripts/release.sh patch
  scripts/release.sh minor
  scripts/release.sh 1.2.0
  scripts/release.sh none

Behavior:
  1. Verifies the git worktree is clean
  2. Verifies you are on the main branch
  3. Runs npm pack --dry-run
  4. Optionally bumps package.json version with npm version
  5. Pushes the branch and tags to GitHub
  6. Publishes the package to npm
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

info() {
  printf '[release] %s\n' "$*" >&2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION_BUMP="${1:-patch}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "Current directory is not inside a Git repository"
cd "$REPO_ROOT"

CURRENT_BRANCH="$(git branch --show-current)"
[[ "$CURRENT_BRANCH" == "main" ]] || die "Release script must be run from the main branch"

[[ -z "$(git status --porcelain)" ]] || die "Git worktree is not clean"

command -v npm >/dev/null 2>&1 || die "npm is not installed"

PACKAGE_NAME="$(node -p "require('./package.json').name")"
CURRENT_VERSION="$(node -p "require('./package.json').version")"

info "Package: $PACKAGE_NAME"
info "Current version: $CURRENT_VERSION"
info "Running npm pack --dry-run"
npm pack --dry-run

if [[ "$VERSION_BUMP" != "none" ]]; then
  info "Bumping version with npm version $VERSION_BUMP"
  npm version "$VERSION_BUMP" -m "Release %s"
else
  info "Skipping version bump"
fi

NEW_VERSION="$(node -p "require('./package.json').version")"
info "New version: $NEW_VERSION"

info "Pushing branch and tags to GitHub"
git push origin main --follow-tags

info "Publishing $PACKAGE_NAME@$NEW_VERSION to npm"
npm publish

info "Release complete"
