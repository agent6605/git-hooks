#!/usr/bin/env bash
set -euo pipefail

readonly REPO="agent6605/git-hooks"
readonly VERSION="v1.0.0"
readonly HOOK_URL="https://raw.githubusercontent.com/$REPO/$VERSION/hooks"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}->${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
err()   { echo -e "${RED}[!!]${NC} $1"; }

usage() {
  cat <<EOF
Usage: install.sh [options]

Install git hooks into current repository.

Options:
  --dir DIR       Install to specific repo (default: current dir)
  --hooks LIST    Comma-separated hooks to install (default: all)
  --link          Symlink instead of copy (auto-update on fetch)
  --help          Show this message

Examples:
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash
  bash install.sh --hooks secret-check,conventional
  bash install.sh --dir ~/my-project --link
EOF
  exit 0
}

parse_args() {
  TARGET_DIR=""
  HOOK_LIST=""
  USE_LINK=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)    TARGET_DIR="$2"; shift 2 ;;
      --hooks)  HOOK_LIST="$2"; shift 2 ;;
      --link)   USE_LINK=true; shift ;;
      --help)   usage ;;
      *)        err "Unknown: $1"; usage ;;
    esac
  done

  if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
  fi
  TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
}

install_mode() {
  local src="$1" dst="$2"
  if $USE_LINK; then
    ln -sf "$src" "$dst"
  else
    cp "$src" "$dst"
    chmod +x "$dst"
  fi
}

install_hook() {
  local name="$1" hook_dir="$2"
  local src_file="$REPO_DIR/hooks/$name"
  local hook_dst="$hook_dir/$name"

  if [[ -f "$hook_dst" ]]; then
    echo -n "  overwrite? [y/N] "
    read -r resp
    [[ "$resp" != "y" ]] && { ok "skip $name"; return; }
  fi

  mkdir -p "$(dirname "$hook_dst")"
  install_mode "$src_file" "$hook_dst"
  ok "$name"
}

selective_hooks() {
  local hook_dir="$1"
  local selected=()

  if [[ -n "$HOOK_LIST" ]]; then
    IFS=',' read -ra selected <<< "$HOOK_LIST"
  else
    for f in "$REPO_DIR"/hooks/*/*; do
      [[ -f "$f" ]] && selected+=("$f")
    done
  fi

  for hook in "${selected[@]}"; do
    local rel="${hook#$REPO_DIR/hooks/}"
    local hook_type="${rel%%/*}"
    local hook_name="${rel#*/}"

    case "$hook_type" in
      pre-commit|commit-msg|pre-push|post-checkout|post-merge)
        install_hook "$rel" "$hook_dir"
        ;;
      *)
        err "unknown hook type: $hook_type"
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  info "target: $TARGET_DIR"
  info "hooks:  ${HOOK_LIST:-all}"
  info "mode:   $($USE_LINK && echo symlink || echo copy)"

  local git_dir="$TARGET_DIR/.git"
  if [[ ! -d "$git_dir" ]]; then
    err "$TARGET_DIR is not a git repo"
    exit 1
  fi

  local hook_dir="$git_dir/hooks"
  mkdir -p "$hook_dir"

  echo ""
  if [[ -n "$HOOK_LIST" ]]; then
    selective_hooks "$hook_dir"
  else
    for dir in pre-commit commit-msg pre-push post-checkout post-merge; do
      for f in "$REPO_DIR/hooks/$dir"/*; do
        [[ -f "$f" ]] && install_hook "$dir/$(basename "$f")" "$hook_dir"
      done
    done
  fi

  echo ""
  ok "hooks installed in $hook_dir"

  if $USE_LINK; then
    echo ""
    info "symlink mode: hooks auto-update when you \`git pull\` the hooks repo."
  fi
}

main "$@"
