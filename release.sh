#!/usr/bin/env bash
#
# release.sh
#
# Housekeeping + publishing helper for this repository:
#   1. Remove the Docker container(s) left behind by the ISO downloader
#      (download.sh -> image "<project>-bindows"). By default only the most
#      recently created one; use --all-containers to purge every one.
#   2. Sync (commit + merge + push) the working changes into the release branch.
#   3. Publish a new GitHub release with a zip asset (plus a .sha256).
#
# Authentication:
#   GITHUB_TOKEN is read from the environment, or from an untracked secrets file
#   (default: ./.secrets). The token is never put on a command line (so it does
#   not leak through `ps`) nor written into .git/config.
#
# The file can be sourced by tests: only the functions are defined unless the
# script is executed directly.
#
set -Eeuo pipefail

# --------------------------------------------------------------------- config
REPO="${REPO:-BENDER35/download-windows-iso-2026}"
BRANCH="${BRANCH:-bindows}"           # branch the release is built from / targets
SOURCE_BRANCH="${SOURCE_BRANCH:-}"    # branch with the new changes (default: current)
ASSET_NAME="${ASSET_NAME:-download-windows-iso-2026.zip}"
TOKEN_FILE="${TOKEN_FILE:-.secrets}"
VERSION="${VERSION:-}"                # explicit version, e.g. v1.4.0 (default: auto)
COMMIT_MESSAGE="${COMMIT_MESSAGE:-}"  # default message is derived if empty
RELEASE_NAME="${RELEASE_NAME:-}"      # default: the version tag
RELEASE_BODY="${RELEASE_BODY:-}"
MAX_FILE_MB="${MAX_FILE_MB:-50}"      # refuse to commit files bigger than this

DIRNAME="$(cd -- "$(dirname -- "$(realpath -- "$0")")" && pwd)"
cd -- "$DIRNAME"

# The ISO downloader (download.sh) builds a compose image and runs a throwaway
# container from it. We target those containers, not just "whatever is newest".
PROJECT="${PROJECT:-$(basename -- "$DIRNAME")}"
SERVICE="${SERVICE:-bindows}"
IMAGE="${IMAGE:-${PROJECT}-${SERVICE}}"   # e.g. download-windows-iso-2026-bindows

# ------------------------------------------------------------------- runtime
DO_CONTAINER=1
ALL_CONTAINERS="${ALL_CONTAINERS:-0}"
DRY_RUN="${DRY_RUN:-0}"

API=""
ORIG_BRANCH=""
TMPDIR_REL=""
NETRC=""
RELEASE_ID=""
VERSION_RESOLVED=""
TAG_PUSHED=0
PUBLISH_OK=0

# ------------------------------------------------------------------- helpers
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Run a mutating command, honouring --dry-run.
run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '\033[1;35m[dry-run]\033[0m %s\n' "$*" >&2
        return 0
    fi
    "$@"
}

usage() {
    cat <<EOF
Usage: ./release.sh [options]

Options:
  -b, --branch BRANCH       Release branch (default: ${BRANCH})
  -s, --source BRANCH       Branch holding the new changes (default: current)
  -t, --token-file FILE     File with GITHUB_TOKEN (default: ${TOKEN_FILE})
  -v, --version VERSION     Explicit version, e.g. v1.4.0 (default: auto minor bump)
  -m, --message MESSAGE     Commit message (default: derived from the diff)
  -a, --all-containers      Delete every container of the ISO-downloader image
      --no-container        Skip deleting the ISO-downloader container(s)
  -n, --dry-run             Show what would happen without changing anything
  -h, --help                Show this help

Environment overrides:
  GITHUB_TOKEN, REPO, BRANCH, SOURCE_BRANCH, ASSET_NAME, TOKEN_FILE,
  VERSION, COMMIT_MESSAGE, RELEASE_NAME, RELEASE_BODY, PROJECT, SERVICE, IMAGE,
  ALL_CONTAINERS, MAX_FILE_MB, DRY_RUN
EOF
}

need() { command -v -- "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

json_get() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(d'"$1"')'; }

# ------------------------------------------------------------ token handling
load_token() {
    [[ -n "${GITHUB_TOKEN:-}" ]] && return 0
    [[ -f "$TOKEN_FILE" ]] || die "GITHUB_TOKEN is not set and '$TOKEN_FILE' does not exist"

    local line value
    line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?GITHUB_TOKEN=' -- "$TOKEN_FILE" | tail -n1 || true)"
    [[ -n "$line" ]] || die "no GITHUB_TOKEN assignment found in '$TOKEN_FILE'"
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"   # trim leading spaces
    value="${value%"${value##*[![:space:]]}"}"   # trim trailing spaces
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    [[ -n "$value" ]] || die "empty GITHUB_TOKEN in '$TOKEN_FILE'"
    GITHUB_TOKEN="$value"
}

check_token_file_perms() {
    [[ -f "$TOKEN_FILE" ]] || return 0
    local mode
    mode="$(stat -c '%a' -- "$TOKEN_FILE" 2>/dev/null || true)"
    [[ -z "$mode" || "$mode" == "600" ]] || warn "'$TOKEN_FILE' is mode ${mode}; run 'chmod 600 $TOKEN_FILE'"
}

setup_git_auth() {
    # Pass credentials through the environment (never argv, never .git/config).
    local basic
    basic="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0="http.https://github.com/.extraheader"
    export GIT_CONFIG_VALUE_0="Authorization: Basic ${basic}"
    export GIT_TERMINAL_PROMPT=0
}

setup_netrc() {
    NETRC="${TMPDIR_REL}/netrc"
    ( umask 077
      cat >"$NETRC" <<EOF
machine api.github.com login x-access-token password ${GITHUB_TOKEN}
machine uploads.github.com login x-access-token password ${GITHUB_TOKEN}
EOF
    )
}

curl_gh() { curl --netrc-file "$NETRC" -H 'Accept: application/vnd.github+json' "$@"; }

# Network git commands ignore the user's global config: a global
# `url.<token>@github.com.insteadOf` rewrite can otherwise inject stale
# credentials into every https://github.com URL. Auth comes from the
# GIT_CONFIG_* extraheader set in setup_git_auth.
git_net() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"; }

# --------------------------------------------------------------- cleanup/trap
cleanup() {
    local rc=$?
    trap - EXIT
    set +e

    if [[ "$rc" -ne 0 && "$TAG_PUSHED" == 1 && "$PUBLISH_OK" != 1 ]]; then
        warn "publishing failed; rolling back tag ${VERSION_RESOLVED}"
        [[ -n "$RELEASE_ID" ]] && curl_gh -fsS -X DELETE "${API}/releases/${RELEASE_ID}" >/dev/null
        git_net push origin --delete "refs/tags/${VERSION_RESOLVED}" >/dev/null 2>&1
        git tag --delete "$VERSION_RESOLVED" >/dev/null 2>&1
    fi

    [[ -n "$TMPDIR_REL" && -d "$TMPDIR_REL" ]] && rm -rf -- "$TMPDIR_REL"
    return "$rc"
}

setup_tmp() {
    TMPDIR_REL="$(mktemp -d)"
    trap cleanup EXIT
}

# -------------------------------------------------------------- git plumbing
ensure_clean_remote() {
    local url clean
    # Read the repo's own config, not `git remote get-url`, which applies
    # global insteadOf rewrites and could show an injected token.
    url="$(git config --local --get remote.origin.url 2>/dev/null || true)"
    [[ -n "$url" ]] || return 0
    case "$url" in
        https://*@github.com/*)
            clean="${url#https://}"; clean="https://${clean#*@}"
            warn "removing embedded credentials from 'origin' (a stale token was stored there)"
            run git remote set-url origin "$clean"
            ;;
    esac
}

# ---------------------------------------------------- 1. delete the container
#
# The containers left behind by download.sh carry the compose labels baked into
# the image, so we find them by project + service. The `ancestor=<image>` filter
# is unreliable here: once the image is rebuilt the old containers point at a
# dangling image id and stop matching by name.
target_container_ids() {
    local ids
    ids="$(docker ps --all --quiet \
        --filter "label=com.docker.compose.project=${PROJECT}" \
        --filter "label=com.docker.compose.service=${SERVICE}" 2>/dev/null || true)"
    if [[ -z "$ids" ]]; then
        ids="$(docker ps --all --quiet --filter "ancestor=${IMAGE}" 2>/dev/null || true)"
    fi
    printf '%s\n' "$ids"
}

delete_one_container() {
    local cid="$1" name
    name="$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null || true)"
    name="${name#/}"
    log "Removing container ${cid} (${name:-?})"
    run docker rm --force "$cid" >/dev/null
}

# Delete the most recently created container of the ISO-downloader image, or
# every one of them when --all-containers is given.
delete_containers() {
    local ids cid count
    ids="$(target_container_ids)"

    if [[ -z "$ids" ]]; then
        log "No '${IMAGE}' containers found; nothing to delete."
        return 0
    fi

    if [[ "$ALL_CONTAINERS" == 1 ]]; then
        count=0
        while IFS= read -r cid; do
            [[ -n "$cid" ]] || continue
            delete_one_container "$cid"
            count=$((count + 1))
        done <<<"$ids"
        log "Removed ${count} '${IMAGE}' container(s)."
        return 0
    fi

    cid="${ids%%$'\n'*}"                 # docker ps lists newest first
    delete_one_container "$cid"
}

# ------------------------------------------------------ 2. sync the changes
staged_too_big() {
    local dest="$1" f size
    : >"$dest"
    while IFS= read -r -d '' f; do
        [[ -f "$f" ]] || continue
        size="$(du -m -- "$f" 2>/dev/null | cut -f1)"
        [[ "$size" =~ ^[0-9]+$ ]] || continue
        if (( size >= MAX_FILE_MB )); then
            printf '%s (%sMB)\n' "$f" "$size" >>"$dest"
        fi
    done < <(git diff --cached --name-only -z)
    return 0
}

sync_changes() {
    local src big
    src="${SOURCE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
    ORIG_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    [[ "$src" != "HEAD" ]] || die "detached HEAD; checkout a branch or pass --source"

    if [[ "$DRY_RUN" == 1 ]]; then
        log "[dry-run] changes that would be committed on '${src}':"
        git status --short || true
    else
        log "Staging changes on '${src}'"
        git add --all

        big="${TMPDIR_REL}/bigfiles"
        staged_too_big "$big"
        if [[ -s "$big" ]]; then
            die "refusing to commit files >= ${MAX_FILE_MB}MB: $(paste -sd', ' -- "$big")"
        fi

        if ! git diff --cached --quiet; then
            local msg="${COMMIT_MESSAGE:-chore: sync changes before release}"
            git commit -m "$msg" >/dev/null
            log "Committed $(git log -1 --pretty='%h %s')"
        else
            log "No local changes to commit."
        fi
    fi

    log "Fetching origin"
    run git_net fetch --prune --tags origin

    if [[ "$src" != "$BRANCH" ]]; then
        log "Merging '${src}' into '${BRANCH}'"
        run git checkout "$BRANCH"
        run git_net pull --ff-only origin "$BRANCH" || warn "could not fast-forward '${BRANCH}'"
        run git merge --no-edit "$src"
    else
        run git_net pull --ff-only origin "$BRANCH" || warn "could not fast-forward '${BRANCH}'"
    fi

    log "Pushing '${BRANCH}'"
    run git_net push origin "$BRANCH"
}

# -------------------------------------------------------- 3. next version tag
next_version() {
    if [[ -n "$VERSION" ]]; then
        printf '%s\n' "$VERSION"
        return 0
    fi
    local latest
    latest="$(git tag --list 'v*' --sort=-v:refname | sed -n '1p')"
    latest="${latest:-v0.0.0}"
    if [[ ! "$latest" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        die "newest tag '${latest}' does not follow vMAJOR.MINOR.PATCH"
    fi
    printf 'v%s.%s.0\n' "${BASH_REMATCH[1]}" "$((BASH_REMATCH[2] + 1))"
}

# --------------------------------------------------------- 4. publish release
remove_named_assets() {
    local release_json="$1" aid
    while IFS= read -r aid; do
        [[ -n "$aid" ]] || continue
        log "Removing existing asset ${aid}"
        run curl_gh -fsS -X DELETE "${API}/releases/assets/${aid}" >/dev/null
    done < <(printf '%s' "$release_json" | python3 -c '
import json, sys
name = sys.argv[1]
for a in json.load(sys.stdin).get("assets", []):
    if a["name"] in (name, name + ".sha256"):
        print(a["id"])' "$ASSET_NAME")
}

publish_release() {
    local version="$1"
    local name="${RELEASE_NAME:-$version}"
    local body="${RELEASE_BODY:-Automated release.}"
    local zip="${TMPDIR_REL}/${ASSET_NAME}"
    local sha="${zip}.sha256"
    local code payload release_json upload_url

    VERSION_RESOLVED="$version"
    log "Packaging ${ASSET_NAME} from '${BRANCH}'"
    run git archive --format=zip --prefix="${ASSET_NAME%.*}/" \
        --output="$zip" "refs/heads/${BRANCH}"

    if [[ "$DRY_RUN" == 1 ]]; then
        log "[dry-run] would tag ${version} on '${BRANCH}', create the release and upload ${ASSET_NAME} (+ .sha256)"
        return 0
    fi

    ( cd -- "$TMPDIR_REL" && sha256sum -- "$ASSET_NAME" > "${ASSET_NAME}.sha256" )

    if git rev-parse --verify --quiet "refs/tags/${version}" >/dev/null; then
        log "Tag ${version} already exists locally."
    else
        git tag --annotate "$version" --message "Release ${version}"
    fi
    git_net push origin "refs/tags/${version}"
    TAG_PUSHED=1

    log "Looking up release ${version}"
    code="$(curl_gh -sS -o "${TMPDIR_REL}/rel.json" -w '%{http_code}' "${API}/releases/tags/${version}")"

    if [[ "$code" == "200" ]]; then
        log "Release ${version} already exists; reusing it."
        release_json="$(cat -- "${TMPDIR_REL}/rel.json")"
    elif [[ "$code" == "404" ]]; then
        payload="$(python3 - "$version" "$BRANCH" "$name" "$body" <<'PY'
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
        release_json="$(curl_gh -fsS -X POST "${API}/releases" \
            -H "Content-Type: application/json" --data "$payload")"
    else
        die "unexpected GitHub API response (${code}) while looking up release ${version}"
    fi

    RELEASE_ID="$(printf '%s' "$release_json" | json_get '["id"]')"
    upload_url="$(printf '%s' "$release_json" | json_get '["upload_url"]')"
    upload_url="${upload_url%\{*}"

    remove_named_assets "$release_json"

    log "Uploading ${ASSET_NAME} ($(du -h -- "$zip" | cut -f1))"
    curl_gh -fsS -X POST "${upload_url}?name=${ASSET_NAME}" \
        -H "Content-Type: application/zip" --data-binary "@${zip}" >/dev/null

    log "Uploading ${ASSET_NAME}.sha256"
    curl_gh -fsS -X POST "${upload_url}?name=${ASSET_NAME}.sha256" \
        -H "Content-Type: text/plain" --data-binary "@${sha}" >/dev/null

    PUBLISH_OK=1
    log "Release published: https://github.com/${REPO}/releases/tag/${version}"
}

# ----------------------------------------------------------------------- main
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--branch)         BRANCH="$2"; shift 2 ;;
            -s|--source)         SOURCE_BRANCH="$2"; shift 2 ;;
            -t|--token-file)     TOKEN_FILE="$2"; shift 2 ;;
            -v|--version)        VERSION="$2"; shift 2 ;;
            -m|--message)        COMMIT_MESSAGE="$2"; shift 2 ;;
            -a|--all-containers) ALL_CONTAINERS=1; shift ;;
            --no-container)      DO_CONTAINER=0; shift ;;
            -n|--dry-run)        DRY_RUN=1; shift ;;
            -h|--help)           usage; exit 0 ;;
            *) die "unknown option: $1 (try --help)" ;;
        esac
    done
}

main() {
    parse_args "$@"
    load_token
    check_token_file_perms

    need docker
    need git
    need curl
    need python3
    need sha256sum
    need base64

    setup_tmp
    setup_git_auth
    setup_netrc
    ensure_clean_remote

    API="https://api.github.com/repos/${REPO}"
    if [[ "$DRY_RUN" == 1 ]]; then
        log "dry-run: no changes will be made"
    fi

    if [[ "$DO_CONTAINER" == 1 ]]; then
        delete_containers
    fi

    sync_changes
    publish_release "$(next_version)"

    if [[ -n "$ORIG_BRANCH" && "$ORIG_BRANCH" != "$(git rev-parse --abbrev-ref HEAD)" ]]; then
        log "Returning to branch '${ORIG_BRANCH}'"
        git checkout "$ORIG_BRANCH" >/dev/null
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
