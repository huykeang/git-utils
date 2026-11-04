#!/bin/bash
# install.sh should update the existing ~/.git-utils install from the
# directory it is run from, and should not append a second PATH line.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# Fake git so a re-run cannot reach GitHub. Records every invocation.
install_git_stub() {
  local home="$1"
  mkdir -p "$home/bin"
  cat >"$home/bin/git" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$GIT_LOG"
exit 0
EOF
  chmod +x "$home/bin/git"
}

# A local re-run must replace scripts in an existing install and must not pull.
test_local_rerun_updates_installed_scripts() {
  local name="local re-run copies scripts into the existing install"
  local home git_log installed
  home="$(mktemp -d)"
  git_log="$home/git.log"
  installed="$home/.git-utils/git-clone-gitlab-group-repos"
  mkdir -p "$home/.git-utils/.git"
  printf 'old script without confirm\n' >"$installed"
  install_git_stub "$home"

  HOME="$home" GIT_LOG="$git_log" PATH="$home/bin:$PATH" bash "$INSTALL"

  if ! cmp -s "$ROOT/git-clone-gitlab-group-repos" "$installed"; then
    fail "$name (installed script was not replaced)"
    echo "installed contents:"
    cat "$installed"
    return
  fi
  if [ -s "$git_log" ]; then
    fail "$name (invoked git)"
    cat "$git_log"
    return
  fi
  pass "$name"
}

# The saved PATH line uses a literal $HOME, so a second run must see it.
test_rerun_does_not_duplicate_path_line() {
  local name="re-run does not append a duplicate PATH line"
  local home count
  home="$(mktemp -d)"
  mkdir -p "$home/.git-utils/.git"
  printf 'export PATH="$HOME/.git-utils:$PATH"\n' >"$home/.bashrc"
  install_git_stub "$home"

  HOME="$home" GIT_LOG="$home/git.log" PATH="$home/bin:$PATH" bash "$INSTALL"

  count="$(grep -c 'git-utils' "$home/.bashrc")"
  if [ "$count" -ne 1 ]; then
    fail "$name (found $count PATH lines)"
    cat "$home/.bashrc"
    return
  fi
  pass "$name"
}

test_local_rerun_updates_installed_scripts
test_rerun_does_not_duplicate_path_line

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "all tests passed"
