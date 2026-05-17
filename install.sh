#!/usr/bin/env bash
set -euo pipefail

readonly REPO="agent6605/git-hooks"
# shellcheck disable=SC2034
readonly VERSION="v1.0.0"

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

install_hooks_type() {
  local hook_type="$1" hook_dir="$2"
  local runner="$hook_dir/$hook_type"
  local hooks_d="$hook_dir/hooks.d/$hook_type"
  local hook_files=("$REPO_DIR/hooks/$hook_type"/*)

  local found=0
  for f in "${hook_files[@]}"; do [[ -f "$f" ]] && { found=1; break; }; done
  [[ $found -eq 0 ]] && return

  if [[ -f "$runner" ]]; then
    if [[ -t 0 ]]; then
      echo -n "  overwrite $hook_type? [y/N] "
      read -r resp
      [[ "$resp" != "y" ]] && { ok "skip $hook_type"; return; }
    fi
  fi

  mkdir -p "$hooks_d"

  if $USE_LINK; then
    for f in "${hook_files[@]}"; do
      [[ ! -f "$f" ]] && continue
      local name
      name=$(basename "$f")
      ln -sf "$f" "$hooks_d/$name"
    done
  else
    for f in "${hook_files[@]}"; do
      [[ ! -f "$f" ]] && continue
      local name
      name=$(basename "$f")
      cp "$f" "$hooks_d/$name"
      chmod +x "$hooks_d/$name"
    done
  fi

  cat > "$runner" << 'RUNNER'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks.d/__TYPE__"

for hook in "$HOOKS_DIR"/*; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  if [[ -z "${SKIP:-}" ]] || ! echo "$SKIP" | grep -qw "$name"; then
    bash "$hook" "$@"
  fi
done
RUNNER
  sed -i "s/__TYPE__/$hook_type/g" "$runner"
  chmod +x "$runner"

  local count
  count=$(find "$REPO_DIR/hooks/$hook_type" -type f | wc -l)
  ok "$hook_type ($count hooks)"
}

selective_hooks() {
  local hook_dir="$1"
  if [[ -n "$HOOK_LIST" ]]; then
    IFS=',' read -ra selected <<< "$HOOK_LIST"
    for name in "${selected[@]}"; do
      for dir in pre-commit commit-msg pre-push post-checkout post-merge; do
        if [[ -f "$REPO_DIR/hooks/$dir/$name" ]]; then
          install_hooks_type "$dir" "$hook_dir"
          break
        fi
      done
    done
  fi
}

# shellcheck disable=SC2120
main() {
  # shellcheck disable=SC2119
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
      install_hooks_type "$dir" "$hook_dir"
    done
  fi

  echo ""
  ok "hooks installed in $hook_dir"
}

main "$@"
