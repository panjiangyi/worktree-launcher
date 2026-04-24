#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
CORE_SCRIPT="$REPO_DIR/ccl-core.sh"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    die "$message
expected: $expected
actual:   $actual"
  fi
}

run_case() {
  local cwd="$1"
  local expected_root="$2"
  local expected_name="$3"
  local output

  output="$(
    cd "$cwd"
    source "$CORE_SCRIPT"
    repo_root=""
    current_worktree_root=""
    repo_name=""
    username=""
    worktree_repo_dir=""
    config_path=""
    main_branch=""
    repo_context_loaded=0
    ensure_repo_context
    printf '%s\n%s\n%s\n%s\n' "$repo_root" "$current_worktree_root" "$repo_name" "$worktree_repo_dir"
  )"

  local actual_root actual_current actual_name actual_worktree_dir
  mapfile -t lines <<< "$output"
  actual_root="${lines[0]:-}"
  actual_current="${lines[1]:-}"
  actual_name="${lines[2]:-}"
  actual_worktree_dir="${lines[3]:-}"

  assert_eq "$actual_root" "$expected_root" "ensure_repo_context should resolve the main worktree root"
  assert_eq "$actual_name" "$expected_name" "ensure_repo_context should derive the repository name from the main worktree root"
  assert_eq "$actual_worktree_dir" "$HOME/.worktrees/$expected_name" "worktree_repo_dir should be stable across worktrees"

  if [[ "$cwd" == "$expected_root" ]]; then
    assert_eq "$actual_current" "$expected_root" "current_worktree_root should match the main worktree when run there"
  else
    assert_eq "$actual_current" "$cwd" "current_worktree_root should preserve the current linked worktree path"
  fi
}

tmpdir="$(mktemp -d /tmp/ccl-test-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

main_repo="$tmpdir/project-main"
linked_worktree="$tmpdir/project-feature"

mkdir -p "$main_repo"
cd "$main_repo"
git init -q -b main
git config user.name 'Test User'
git config user.email 'test@example.com'
printf 'hello\n' > README.md
git add README.md
git commit -q -m 'init'
git branch dev
git worktree add -q "$linked_worktree" -b test/feature dev

run_case "$main_repo" "$main_repo" "project-main"
run_case "$linked_worktree" "$main_repo" "project-main"

printf 'ok - worktree root detection\n'
