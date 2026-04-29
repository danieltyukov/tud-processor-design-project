#!/usr/bin/env bash
# Shared helpers — every script in this dir sources this.
# Loads credentials from the first file found in this lookup order:
#   1. $PDP_CREDS_FILE                         (explicit override)
#   2. ~/.config/pdp-project-24/credentials.txt (historical default)
#   3. <repo-root>/credentials.txt              (in-tree, .gitignored)

set -euo pipefail

SCRIPT_DIR_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_LIB="$(cd "$SCRIPT_DIR_LIB/.." && pwd)"

CREDS_CANDIDATES=(
    "${PDP_CREDS_FILE:-}"
    "$HOME/.config/pdp-project-24/credentials.txt"
    "$REPO_ROOT_LIB/credentials.txt"
)

CREDS_FILE=""
for candidate in "${CREDS_CANDIDATES[@]}"; do
    [[ -n "$candidate" && -f "$candidate" ]] || continue
    CREDS_FILE="$candidate"
    break
done

if [[ -z "$CREDS_FILE" ]]; then
    echo "error: no credentials file found. Looked in:" >&2
    for candidate in "${CREDS_CANDIDATES[@]}"; do
        [[ -n "$candidate" ]] && echo "         $candidate" >&2
    done
    echo "" >&2
    echo "       fix: copy credentials.example.txt to credentials.txt and fill it in:" >&2
    echo "         cp $REPO_ROOT_LIB/credentials.example.txt $REPO_ROOT_LIB/credentials.txt" >&2
    echo "         chmod 600 $REPO_ROOT_LIB/credentials.txt" >&2
    echo "         \$EDITOR $REPO_ROOT_LIB/credentials.txt" >&2
    exit 1
fi

# shellcheck disable=SC1090
set -a; source "$CREDS_FILE"; set +a

: "${PDP_SERVER_HOST:?credentials: PDP_SERVER_HOST not set}"
: "${PDP_SERVER_USER:?credentials: PDP_SERVER_USER not set}"
: "${PDP_SSH_KEY:?credentials: PDP_SSH_KEY not set}"
