#!/usr/bin/env bash
#
# release.sh
#
# Housekeeping + publishing helper for this repository:
#   1. Delete the most recently created Docker container.
#   2. Sync (commit + merge + push) the working changes into the release branch.
#   3. Publish a new GitHub release with a zip asset.
#
# The GitHub token is read from an untracked file (default: ./.secrets) or from
# the GITHUB_TOKEN environment variable. It is never written into the repo.
#
set -Eeuo pipefail

# --------------------------------------------------------------------- config
REPO="${REPO:-BENDER35/download-windows-iso-2026}"
BRANCH="${BRANCH:-bindows}"           # branch the release is built from / targets
SOURCE_BRANCH="${SOURCE_BRANCH:-}"    # branch with the new changes (default: current)
ASSET_NAME="${ASSET_NAME:-download-windows-iso-2026.zip}"
TOKEN_FILE="${TOKEN_FILE:-.secrets}"
VERSION="${VERSION:-}"                # explicit version, e.g. v1.4.0 (default: auto)
COMMIT_MESSAGE="${COMMIT_MESSAGE:-chore: sync changes before release}"
RELEASE_NAME="${RELEASE_NAME:-}"      # default: the version tag
RELEASE_BODY="${RELEASE_BODY:-Automated release.}"

API="https://api.github.com/repos/${REPO}"

DIRNAME="$(cd -- "$(dirname -- "$(realpath -- "$0")")" && pwd)"
cd -- "$DIRNAME"

# ------------------------------------------------------------------- helpers
log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ./release.sh [options]

Options:
  -b, --branch BRANCH      Release branch (default: ${BRANCH})
  -s, --source BRANCH      Branch holding the new changes (default: current)
  -t, --token-file FILE    File with GITHUB_TOKEN (default: ${TOKEN_FILE})
  -v, --version VERSION    Explicit version, e.g. v1.4.0 (default: auto minor bump)
      --no-container       Skip deleting the latest Docker container
  -h, --help               Show this help

Environment overrides:
  GITHUB_TOKEN, REPO, BRANCH, SOURCE_BRANCH, ASSET_NAME, TOKEN_FILE,
  VERSION, COMMIT_MESSAGE, RELEASE_NAME, RELEASE_BODY
EOF
}

need() { command -v -- "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

json_get() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d'"$1"')'; }

# --------------------------------------------------------------- arg parsing
DO_CONTAINER=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--branch)      BRANCH="$2"; shift 2 ;;
        -s|--source)      SOURCE_BRANCH="$2"; shift 2 ;;
        -t|--token-file)  TOKEN_FILE="$2"; shift 2 ;;
        -v|--version)     VERSION="$2"; shift 2 ;;
        --no-container)   DO_CONTAINER=0; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

# ---------------------------------------------------------------------- token
if [[ -f "$TOKEN_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$TOKEN_FILE"
fi
[[ -n "${GITHUB_TOKEN:-}" ]] || die "GITHUB_TOKEN is not set (create '$TOKEN_FILE' or export it)"

need docker
need git
need curl
need python3

# Authenticated push/API URL built on the fly so the token is never stored in
# .git/config and the (possibly stale) credentials baked into 'origin' are ignored.
AUTH_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git"

export GITHUB_TOKEN

# ---------------------------------------------------- 1. delete the container
delete_latest_container() {
    local cid
    cid="$(docker ps --all --quiet --latest 2>/dev/null || true)"
    if [[ -z "$cid" ]]; then
        log "No Docker containers found; nothing to delete."
        return 0
    fi

    local info name image
    info="$(docker inspect --format '{{.Name}} {{.Config.Image}}' "$cid" 2>/dev/null || true)"
    name="${info%% *}"; name="${name#/}"
    image="${info#* }"

    log "Deleting latest container: ${cid} (${name:-?}, image ${image:-?})"
    docker rm --force "$cid" >/dev/null
    log "Container ${cid} removed."
}

# ------------------------------------------------------ 2. sync the changes
sync_changes() {
    local src="${SOURCE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
    [[ "$src" != "HEAD" ]] || die "detached HEAD; checkout a branch or pass --source"

    log "Staging changes on branch '${src}'"
    git add --all
    if ! git diff --cached --quiet; then
        git commit -m "$COMMIT_MESSAGE" >/dev/null
        log "Committed local changes."
    else
        log "No local changes to commit."
    fi

    log "Fetching origin"
    git fetch --prune --tags origin

    if [[ "$src" != "$BRANCH" ]]; then
        log "Merging '${src}' into '${BRANCH}'"
        git checkout "$BRANCH"
        git pull --ff-only origin "$BRANCH" || warn "could not fast-forward '${BRANCH}'"
        git merge --no-edit "$src"
    else
        git pull --ff-only origin "$BRANCH" || warn "could not fast-forward '${BRANCH}'"
    fi

    log "Pushing '${BRANCH}'"
    git push "$AUTH_URL" "$BRANCH"
}

# -------------------------------------------------------- 3. next version tag
next_version() {
    if [[ -n "$VERSION" ]]; then
        printf '%s\n' "$VERSION"
        return 0
    fi
    local latest major minor
    latest="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
    latest="${latest:-v0.0.0}"
    IFS=. read -r major minor _ <<<"${latest#v}"
    printf 'v%s.%s.0\n' "$major" "$((minor + 1))"
}

# --------------------------------------------------------- 4. publish release
publish_release() {
    local version="$1"
    local name="${RELEASE_NAME:-$version}"
    local tmpdir zip payload release_json upload_url code

    tmpdir="$(mktemp -d)"
    trap 'rm -rf -- "$tmpdir"' RETURN
    zip="${tmpdir}/${ASSET_NAME}"

    log "Packaging ${ASSET_NAME} from '${BRANCH}'"
    git archive --format=zip --prefix="${ASSET_NAME%.zip}/" \
        --output="$zip" "refs/heads/${BRANCH}" \
        || git archive --format=zip --prefix="${ASSET_NAME%.zip}/" --output="$zip" "$BRANCH"

    if git rev-parse --verify --quiet "refs/tags/${version}" >/dev/null; then
        log "Tag ${version} already exists locally."
    else
        git tag --annotate "$version" --message "Release ${version}"
    fi
    git push "$AUTH_URL" "refs/tags/${version}"

    log "Looking up release ${version}"
    code="$(curl -s -o "$tmpdir/rel.json" -w '%{http_code}' \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "${API}/releases/tags/${version}")"

    if [[ "$code" == "200" ]]; then
        log "Release ${version} already exists; reusing it."
        release_json="$(cat -- "$tmpdir/rel.json")"
    elif [[ "$code" == "404" ]]; then
        payload="$(python3 - "$version" "$BRANCH" "$name" "$RELEASE_BODY" <<'PY'
import json, sys
version, branch, name, body = sys.argv[1:5]
print(json.dumps({
    "tag_name": version,
    "target_commitish": branch,
    "name": name,
    "body": body,
    "draft": False,
    "prerelease": False,
    "generate_release_notes": True,
}))
PY
)"
        log "Creating release ${version}"
        release_json="$(curl -fsS -X POST "${API}/releases" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "Content-Type: application/json" \
            --data "$payload")"
    else
        die "unexpected GitHub API response (${code}) while looking up release ${version}"
    fi

    upload_url="$(printf '%s' "$release_json" | json_get '["upload_url"]')"
    upload_url="${upload_url%\{*}"

    # Drop an existing asset with the same name so the upload never 409/422s.
    local asset_id
    asset_id="$(printf '%s' "$release_json" \
        | python3 -c 'import json,sys
name=sys.argv[1]
for a in json.load(sys.stdin).get("assets", []):
    if a["name"] == name:
        print(a["id"]); break' "$ASSET_NAME")"
    if [[ -n "$asset_id" ]]; then
        log "Removing existing asset ${ASSET_NAME} (${asset_id})"
        curl -fsS -X DELETE \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            "${API}/releases/assets/${asset_id}" >/dev/null
    fi

    log "Uploading ${ASSET_NAME} ($(du -h -- "$zip" | cut -f1))"
    curl -fsS -X POST "${upload_url}?name=${ASSET_NAME}" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/zip" \
        --data-binary "@${zip}" >/dev/null

    log "Release published: https://github.com/${REPO}/releases/tag/${version}"
}

# ----------------------------------------------------------------------- main
if [[ "$DO_CONTAINER" -eq 1 ]]; then
    delete_latest_container
fi
sync_changes
VERSION_RESOLVED="$(next_version)"
publish_release "$VERSION_RESOLVED"
