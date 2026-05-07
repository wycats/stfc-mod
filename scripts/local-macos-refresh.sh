#!/bin/bash

# Refresh the local macOS integration branch, build the launcher app, and
# optionally install it to /Applications for personal use.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="${PROJECT_ROOT}/scripts/mac-build-test-debug.sh"

BRANCH="wycats/local-play-macos"
BASE="origin/dev"
MODE="release"
ARCH="$(uname -m)"
FETCH=true
REBASE=true
INSTALL=false
DRY_RUN=false
TARGET_APP="/Applications/STFC Community Mod.app"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Refresh and build the local macOS integration branch.

Defaults:
  branch: ${BRANCH}
  base:   ${BASE}
  mode:   ${MODE}
  arch:   native (${ARCH})

Options:
  --mode MODE       Build mode: debug, release, releasedbg, check (default: release)
  --arch ARCH       Architecture: arm64, x86_64, or universal (default: native)
  --branch BRANCH   Local integration branch to refresh
  --base REF        Upstream base ref to rebase onto
  --no-fetch        Do not fetch the base ref before rebasing
  --no-rebase       Do not rebase before building
  --install         Install the built app to /Applications
  --no-install      Build only; this is the default
  --dry-run         Print the operations without changing the branch, building, or installing
  -h, --help        Show this help message

This script never pushes. Untracked files are allowed and printed; tracked or staged
changes abort the refresh before rebase/build unless --dry-run is used.
EOF
}

quote_command() {
    local quoted=""
    local arg
    for arg in "$@"; do
        printf -v quoted '%s%q ' "$quoted" "$arg"
    done
    printf '%s' "${quoted% }"
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "+ $(quote_command "$@")"
    else
        "$@"
    fi
}

fail() {
    print_error "$1"
    exit 1
}

require_option_value() {
    local option="$1"
    local value="${2:-}"

    [[ -n "$value" ]] || fail "Missing value for ${option}."
    [[ "$value" != --* ]] || fail "Missing value for ${option}."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            require_option_value "$1" "${2:-}"
            MODE="$2"
            shift 2
            ;;
        --arch)
            require_option_value "$1" "${2:-}"
            ARCH="$2"
            shift 2
            ;;
        --branch)
            require_option_value "$1" "${2:-}"
            BRANCH="$2"
            shift 2
            ;;
        --base)
            require_option_value "$1" "${2:-}"
            BASE="$2"
            shift 2
            ;;
        --no-fetch)
            FETCH=false
            shift
            ;;
        --no-rebase)
            REBASE=false
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --no-install)
            INSTALL=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

case "$MODE" in
    debug|release|releasedbg|check)
        ;;
    *)
        fail "Invalid build mode: ${MODE}"
        ;;
esac

case "$ARCH" in
    arm64|x86_64|universal)
        ;;
    *)
        fail "Invalid architecture: ${ARCH}"
        ;;
esac

SOURCE_APP="${PROJECT_ROOT}/build/macosx/${ARCH}/${MODE}/STFC Community Mod.app"

require_macos() {
    [[ "$(uname -s)" == "Darwin" ]] || fail "This refresh script is macOS-only."
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_tools() {
    require_command git
    require_command xmake
    require_command codesign
    require_command shasum
    require_command ditto
    require_command pgrep
    require_command ps
}

require_clean_tracked_state() {
    git update-index -q --refresh

    if ! git diff --quiet --ignore-submodules --; then
        fail "Tracked working tree changes are present. Commit, stash, or discard them before refreshing."
    fi

    if ! git diff --cached --quiet --ignore-submodules --; then
        fail "Staged changes are present. Commit, unstage, or stash them before refreshing."
    fi
}

print_untracked_files() {
    local untracked
    untracked="$(git ls-files --others --exclude-standard)"

    if [[ -n "$untracked" ]]; then
        print_warning "Untracked files are present and will be left alone:"
        echo "$untracked" | sed 's/^/  /'
    else
        print_info "No untracked files."
    fi
}

current_branch() {
    git branch --show-current
}

require_expected_branch() {
    local current
    current="$(current_branch)"
    [[ "$current" == "$BRANCH" ]] || fail "Current branch is ${current}; expected ${BRANCH}."
}

fetch_base() {
    if [[ "$FETCH" != true ]]; then
        print_info "Skipping fetch (--no-fetch)."
        return
    fi

    if [[ "$BASE" != */* ]]; then
        fail "Cannot infer a remote from base ref '${BASE}'. Use --no-fetch or pass a remote ref like origin/dev."
    fi

    local remote="${BASE%%/*}"
    local remote_ref="${BASE#*/}"

    print_info "Fetching ${remote}/${remote_ref}..."
    run git fetch "$remote" "${remote_ref}:refs/remotes/${remote}/${remote_ref}"
}

verify_base_ref() {
    if [[ "$DRY_RUN" == true ]]; then
        if git rev-parse --verify --quiet "$BASE" >/dev/null; then
            return
        fi

        print_warning "Base ref ${BASE} is not present locally yet; dry-run will continue."
        return
    fi

    git rev-parse --verify --quiet "$BASE" >/dev/null || fail "Base ref not found: ${BASE}"
}

rebase_branch() {
    if [[ "$REBASE" != true ]]; then
        print_info "Skipping rebase (--no-rebase)."
        return
    fi

    print_info "Rebasing ${BRANCH} onto ${BASE}..."
    run git rebase "$BASE"
}

print_ref_status() {
    local head_short
    local head_full
    head_short="$(git rev-parse --short HEAD)"
    head_full="$(git rev-parse HEAD)"

    print_info "Repository: ${PROJECT_ROOT}"
    print_info "Branch: $(current_branch)"
    print_info "Base: ${BASE}"
    print_info "HEAD: ${head_short} (${head_full})"

    if git rev-parse --verify --quiet "$BASE" >/dev/null; then
        print_info "${BASE}: $(git rev-parse --short "$BASE") ($(git rev-parse "$BASE"))"
    else
        print_warning "${BASE}: not present locally"
    fi
}

build_app() {
    print_info "Building ${MODE} app for ${ARCH}..."
    run "$BUILD_SCRIPT" --mode "$MODE" --arch "$ARCH" build
}

verify_app_exists() {
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would require source app at: ${SOURCE_APP}"
        return
    fi

    [[ -d "$SOURCE_APP" ]] || fail "Build did not produce app bundle: ${SOURCE_APP}"
}

verify_codesign() {
    local app_path="$1"
    print_info "Verifying code signature: ${app_path}"
    run codesign --verify --deep --strict --verbose=2 "$app_path"
}

bundle_hash() {
    local app_path="$1"

    (
        cd "$app_path"
        find . -type f -print | LC_ALL=C sort | while IFS= read -r file; do
            shasum -a 256 "$file"
        done | shasum -a 256 | awk '{print $1}'
    )
}

print_bundle_hash() {
    local label="$1"
    local app_path="$2"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "${label} bundle hash: <dry-run>"
        return
    fi

    print_info "${label} bundle hash: $(bundle_hash "$app_path")"
}

require_not_running() {
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would check that the game, launcher, and loader are not running."
        return
    fi

    local found=false
    local name

    for name in "STFC Community Mod" "macOSLauncher" "stfc-community-mod-loader" "Star Trek Fleet Command"; do
        if pgrep -x "$name" >/dev/null 2>&1; then
            print_error "Running process detected: ${name}"
            pgrep -x "$name" | while IFS= read -r pid; do
                ps -p "$pid" -o pid= -o comm=
            done
            found=true
        fi
    done

    [[ "$found" == false ]] || fail "Quit the game, launcher, and loader before installing."
}

install_app() {
    if [[ "$INSTALL" != true ]]; then
        print_info "Skipping install. Pass --install to replace ${TARGET_APP}."
        return
    fi

    print_info "Installing app to ${TARGET_APP}..."

    require_not_running

    local tmp_parent
    if [[ "$DRY_RUN" == true ]]; then
        tmp_parent="/Applications/.stfc-community-mod-install.<dry-run>"
    else
        tmp_parent="$(mktemp -d "/Applications/.stfc-community-mod-install.XXXXXX")"
    fi
    local tmp_app="${tmp_parent}/STFC Community Mod.app"
    local backup_app=""

    run ditto "$SOURCE_APP" "$tmp_app"
    verify_codesign "$tmp_app"

    if [[ -d "$TARGET_APP" ]]; then
        backup_app="${TARGET_APP}.previous.$(date +%Y%m%d%H%M%S)"
        run mv "$TARGET_APP" "$backup_app"
    fi

    if ! run mv "$tmp_app" "$TARGET_APP"; then
        if [[ -n "$backup_app" && -d "$backup_app" ]]; then
            run mv "$backup_app" "$TARGET_APP"
        fi
        run rm -rf "$tmp_parent"
        fail "Install failed; restored previous app if one existed."
    fi

    if ! verify_codesign "$TARGET_APP" || ! compare_installed_hash; then
        if [[ -n "$backup_app" && -d "$backup_app" ]]; then
            run rm -rf "$TARGET_APP"
            run mv "$backup_app" "$TARGET_APP"
        fi
        run rm -rf "$tmp_parent"
        fail "Installed app verification failed; restored previous app if one existed."
    fi

    run rm -rf "$tmp_parent"
    if [[ -n "$backup_app" ]]; then
        run rm -rf "$backup_app"
    fi
}

compare_installed_hash() {
    if [[ "$INSTALL" != true || "$DRY_RUN" == true ]]; then
        return 0
    fi

    local source_hash
    local installed_hash
    source_hash="$(bundle_hash "$SOURCE_APP")"
    installed_hash="$(bundle_hash "$TARGET_APP")"

    print_info "Source bundle hash:    ${source_hash}"
    print_info "Installed bundle hash: ${installed_hash}"

    [[ "$source_hash" == "$installed_hash" ]] || return 1
}

print_final_status() {
    print_ref_status

    if [[ "$DRY_RUN" != true && -d "$SOURCE_APP" ]]; then
        print_bundle_hash "Source" "$SOURCE_APP"
    fi

    if [[ "$DRY_RUN" != true && "$INSTALL" == true && -d "$TARGET_APP" ]]; then
        print_bundle_hash "Installed" "$TARGET_APP"
    fi

    print_info "Working tree status:"
    git status --short
}

main() {
    require_macos
    require_tools

    cd "$PROJECT_ROOT"

    print_info "STFC macOS local refresh"
    print_ref_status
    print_untracked_files

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "Dry-run: tracked/staged cleanliness is not enforced because no rebase/build/install will run."
    else
        require_clean_tracked_state
    fi

    require_expected_branch
    fetch_base
    verify_base_ref
    rebase_branch
    build_app
    verify_app_exists
    verify_codesign "$SOURCE_APP"
    print_bundle_hash "Source" "$SOURCE_APP"
    install_app
    print_final_status

    print_success "Local macOS refresh complete."
}

main
