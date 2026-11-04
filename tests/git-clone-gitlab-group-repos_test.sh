#!/bin/bash
# Behavior tests for git-clone-gitlab-group-repos.
# curl and git are stand-ins so the test never talks to GitLab or clones repos.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/git-clone-gitlab-group-repos"
GROUP_URL="https://gitlab.example.com/eco/unified"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# Run the script against fixture pages. Prints "status<newline>output".
run_script() {
  local fixture_dir="$1"
  local answer="$2"
  local work bin

  work="$(mktemp -d)"
  bin="$work/bin"
  mkdir -p "$bin"

  cat >"$bin/curl" <<'EOF'
#!/bin/bash
outfile=""
url=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    outfile="$arg"
  fi
  case "$arg" in
    http://*|https://*) url="$arg" ;;
  esac
  prev="$arg"
done

case "$url" in
  *"/api/v4/groups/eco%2Funified/projects?"*) ;;
  *)
    echo "unexpected url: $url" >&2
    exit 1
    ;;
esac

page="$(printf '%s\n' "$url" | sed -n 's/.*[&?]page=\([0-9][0-9]*\).*/\1/p')"
src="$FIXTURE_DIR/page-${page}.json"
if [ -f "$src" ]; then
  cp "$src" "$outfile"
else
  printf '[]\n' >"$outfile"
fi
printf '200'
EOF

  cat >"$bin/git" <<'EOF'
#!/bin/bash
if [ "$1" = "clone" ]; then
  dest="${3:-}"
  if [ -n "$dest" ]; then
    parent="$(dirname "$dest")"
    if [ "$parent" != "." ] && [ ! -d "$parent" ]; then
      echo "missing parent directory: $parent" >&2
      exit 1
    fi
    printf '%s %s\n' "$2" "$dest" >>"$CLONE_LOG"
  else
    printf '%s\n' "$2" >>"$CLONE_LOG"
  fi
  exit 0
fi
echo "unexpected git args: $*" >&2
exit 1
EOF

  chmod +x "$bin/curl" "$bin/git"
  export FIXTURE_DIR="$fixture_dir"
  export CLONE_LOG="$work/clones.log"
  export GITLAB_PRIVATE_TOKEN="test-token"
  export PATH="$bin:$PATH"
  : >"$CLONE_LOG"

  local output status
  cd "$work"
  set +e
  output="$(printf '%s\n' "$answer" | "$SCRIPT" "$GROUP_URL" 2>&1)"
  status=$?
  set -e
  printf '%s\n%s\n' "$status" "$output"
  printf '%s\n' "$CLONE_LOG"
}

assert_summary() {
  local output="$1"
  local expected="📊 Repositories by subgroup:
  (root): 1
  backend: 2
  frontend: 1
Total: 4"
  case "$output" in
    *"$expected"*) return 0 ;;
    *)
      echo "missing subgroup summary in:"
      printf '%s\n' "$output"
      return 1
      ;;
  esac
}

# Declining must show counts for every page and must not clone.
test_decline_shows_counts_and_does_not_clone() {
  local name="declining prints subgroup counts and does not clone"
  local result status output clone_log
  result="$(run_script "$ROOT/tests/fixtures/grouped-projects" "n")"
  status="$(printf '%s\n' "$result" | head -n 1)"
  clone_log="$(printf '%s\n' "$result" | tail -n 1)"
  output="$(printf '%s\n' "$result" | sed '1d;$d')"

  if [ "$status" -ne 0 ]; then
    fail "$name (exit $status)"
    printf '%s\n' "$output"
    return
  fi
  if ! assert_summary "$output"; then
    fail "$name (summary)"
    return
  fi
  case "$output" in
    *"Aborted."*) ;;
    *)
      fail "$name (missing Aborted)"
      return
      ;;
  esac
  if [ -s "$clone_log" ]; then
    fail "$name (cloned anyway)"
    cat "$clone_log"
    return
  fi
  pass "$name"
}

assert_layout_prompt() {
  local output="$1"
  local expected="Clone these repositories?
  1) Keep subgroup folder structure
  2) Flat"
  case "$output" in
    *"$expected"*) return 0 ;;
    *)
      echo "missing layout prompt in:"
      printf '%s\n' "$output"
      return 1
      ;;
  esac
}

# Choosing flat clones every repo in the current directory, in API order.
test_flat_clones_all_pages() {
  local name="flat clones every repository into the current directory"
  local result status output clone_log
  local expected="git@gitlab.example.com:eco/unified/backend/api.git
git@gitlab.example.com:eco/unified/backend/worker.git
git@gitlab.example.com:eco/unified/frontend/web.git
git@gitlab.example.com:eco/unified/docs.git"
  result="$(run_script "$ROOT/tests/fixtures/grouped-projects" "2")"
  status="$(printf '%s\n' "$result" | head -n 1)"
  clone_log="$(printf '%s\n' "$result" | tail -n 1)"
  output="$(printf '%s\n' "$result" | sed '1d;$d')"

  if [ "$status" -ne 0 ]; then
    fail "$name (exit $status)"
    printf '%s\n' "$output"
    return
  fi
  if ! assert_summary "$output"; then
    fail "$name (summary)"
    return
  fi
  if ! assert_layout_prompt "$output"; then
    fail "$name (layout prompt)"
    return
  fi
  if [ "$(cat "$clone_log")" != "$expected" ]; then
    fail "$name (clone list)"
    echo "got:"
    cat "$clone_log"
    return
  fi
  pass "$name"
}

# Choosing folders clones each repo under its subgroup path.
test_folders_keeps_subgroup_structure() {
  local name="folder layout clones into subgroup directories"
  local result status output clone_log
  local expected="git@gitlab.example.com:eco/unified/backend/api.git backend/api
git@gitlab.example.com:eco/unified/backend/worker.git backend/worker
git@gitlab.example.com:eco/unified/frontend/web.git frontend/web
git@gitlab.example.com:eco/unified/docs.git docs"
  result="$(run_script "$ROOT/tests/fixtures/grouped-projects" "1")"
  status="$(printf '%s\n' "$result" | head -n 1)"
  clone_log="$(printf '%s\n' "$result" | tail -n 1)"
  output="$(printf '%s\n' "$result" | sed '1d;$d')"

  if [ "$status" -ne 0 ]; then
    fail "$name (exit $status)"
    printf '%s\n' "$output"
    return
  fi
  if ! assert_layout_prompt "$output"; then
    fail "$name (layout prompt)"
    return
  fi
  if [ "$(cat "$clone_log")" != "$expected" ]; then
    fail "$name (clone list)"
    echo "got:"
    cat "$clone_log"
    return
  fi
  pass "$name"
}

# An empty group is reported and never asks to clone.
test_empty_group_does_not_prompt() {
  local name="empty group reports zero repositories and does not clone"
  local result status output clone_log
  result="$(run_script "$ROOT/tests/fixtures/empty-group" "")"
  status="$(printf '%s\n' "$result" | head -n 1)"
  clone_log="$(printf '%s\n' "$result" | tail -n 1)"
  output="$(printf '%s\n' "$result" | sed '1d;$d')"

  if [ "$status" -ne 0 ]; then
    fail "$name (exit $status)"
    printf '%s\n' "$output"
    return
  fi
  case "$output" in
    *"No repositories found."*) ;;
    *)
      fail "$name (message)"
      printf '%s\n' "$output"
      return
      ;;
  esac
  case "$output" in
    *"Clone these repositories?"*)
      fail "$name (prompted anyway)"
      return
      ;;
  esac
  if [ -s "$clone_log" ]; then
    fail "$name (cloned anyway)"
    return
  fi
  pass "$name"
}

# A missing token must explain where to create one in the GitLab UI.
test_missing_token_explains_gitlab_settings() {
  local name="missing token explains GitLab access token settings"
  local output status
  set +e
  output="$(env -u GITLAB_PRIVATE_TOKEN "$SCRIPT" "https://gitlab.example.com/eco/unified" 2>&1)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    fail "$name (exit 0)"
    return
  fi
  case "$output" in
    *"/-/user_settings/personal_access_tokens"*) ;;
    *)
      fail "$name (settings path)"
      printf '%s\n' "$output"
      return
      ;;
  esac
  case "$output" in
    *"read_api"*) ;;
    *)
      fail "$name (scope)"
      printf '%s\n' "$output"
      return
      ;;
  esac
  pass "$name"
}

test_missing_token_explains_gitlab_settings
test_decline_shows_counts_and_does_not_clone
test_flat_clones_all_pages
test_folders_keeps_subgroup_structure
test_empty_group_does_not_prompt

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "all tests passed"
