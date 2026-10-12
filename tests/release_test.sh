#!/usr/bin/env bash
#
# Smoke/unit tests for release.sh helpers.
#
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT/release.sh"

fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$*"; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

cd -- "$tmp"
git init -q
git config user.email test@example.com
git config user.name test
git commit -q --allow-empty -m init

# 1. auto minor bump
git tag v1.2.3
out="$(next_version)"
[[ "$out" == "v1.3.0" ]] || fail "next_version: expected v1.3.0, got '${out}'"
pass "auto minor bump -> ${out}"

# 2. explicit version wins
out="$(VERSION=v9.9.9 next_version)"
[[ "$out" == "v9.9.9" ]] || fail "explicit version ignored: '${out}'"
pass "explicit version -> ${out}"

# 3. malformed tag is rejected (subshell so die() doesn't kill the test)
git tag -d v1.2.3 >/dev/null
git tag vnope
if out="$(VERSION='' next_version 2>/dev/null)"; then
    fail "malformed tag was not rejected (got '${out}')"
fi
pass "malformed tag rejected"
git tag -d vnope >/dev/null

# 4. no tags -> v0.1.0
out="$(VERSION='' next_version)"
[[ "$out" == "v0.1.0" ]] || fail "no-tag case: expected v0.1.0, got '${out}'"
pass "no tags -> ${out}"

# 5. container selection (mock docker), most recent only
mkdir -p "$tmp/bin"
cat >"$tmp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
case "${1:-}" in
    ps) printf 'ccc\naaa\n' ;;
    inspect) printf '/mock_name\n' ;;
    *) exit 0 ;;
esac
MOCK
chmod +x "$tmp/bin/docker"
PATH="$tmp/bin:$PATH"

out="$(DRY_RUN=1 ALL_CONTAINERS=0 delete_containers 2>&1)"
grep -q 'ccc' <<<"$out" || fail "latest container not selected"
grep -q 'aaa' <<<"$out" && fail "only the latest container should be selected"
pass "selects only the most recent container"

# 6. --all-containers removes every one
out="$(DRY_RUN=1 ALL_CONTAINERS=1 delete_containers 2>&1)"
grep -q 'ccc' <<<"$out" || fail "all-containers missed ccc"
grep -q 'aaa' <<<"$out" || fail "all-containers missed aaa"
grep -q 'Removed 2' <<<"$out" || fail "all-containers count wrong"
pass "all-containers removes every container"

echo "all tests passed"
