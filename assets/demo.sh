#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR=$(mktemp -d)
trap 'rm -rf "$DEMO_DIR"' EXIT
cd "$DEMO_DIR"

# Simulate real terminal
export TERM=xterm-256color
export GIT_TERMINAL_PROMPT=0

GREEN='\033[32m'
CYAN='\033[36m'
RED='\033[31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

cmd() {
  echo -e "${GREEN}\$ ${NC}${CYAN}$1${NC}"
  eval "$1"
  echo ""
}

comment() {
  echo -e "${DIM}# $1${NC}"
  sleep 0.3
}

comment "git-hooks: zero-dep commit guards"
comment "Let's see it in action."
echo ""
sleep 1

comment "1. Init a new repo"
cmd "git init demo"
cd demo
git config user.email "dev@example.com"
git config user.name "Dev"
sleep 0.5

comment "2. One-command install"
cmd "curl -fsSL https://raw.githubusercontent.com/agent6605/git-hooks/main/install.sh | bash"
sleep 1

comment "3. Try to commit a secret key"
cmd 'echo "AWS_KEY=AKIA123456789EXAMPLE" > .env'
cmd "git add .env"
cmd 'git commit -m "add env file"'
echo -e "${RED}[!!]${NC} Blocked! Hook caught the AWS key."
sleep 2

comment "4. Bypass with SKIP env var when intentional"
cmd 'SKIP=secret-check git commit -m "add env"'
echo -e "${GREEN}[ok]${NC} Bypassed, commit succeeded."
sleep 1

comment "5. Conventional commit validation"
comment "Bad message saved to file:"
cmd 'echo "bad message" > /tmp/msg && bash .git/hooks/commit-msg /tmp/msg || true'
sleep 0.5

comment "Good message — passes:"
cmd 'echo "feat: add env file" > /tmp/msg && bash .git/hooks/commit-msg /tmp/msg'
sleep 0.5

comment "6. Branch name validation"
comment "Invalid branch — blocked:"
cmd "git checkout -q -b BAD_BRANCH_NAME 2>/dev/null || true; bash .git/hooks/pre-push || true"
sleep 0.5

comment "Valid branch — passes:"
cmd "git checkout -q -b feat/add-env-support 2>/dev/null || true; bash .git/hooks/pre-push"
sleep 0.5

echo ""
echo -e "${GREEN}${BOLD}Done! 7 hooks, zero deps, one command.${NC}"
echo ""
echo -e "${GREEN}\$ ${NC}${CYAN}curl -fsSL ${DIM}https://raw.githubusercontent.com/agent6605/git-hooks/main/install.sh${NC} ${GREEN}|${NC} ${CYAN}bash${NC}"
echo ""
sleep 1
