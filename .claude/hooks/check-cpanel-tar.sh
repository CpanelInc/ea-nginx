#!/bin/bash
# PostToolUse (Write|Edit): warn when SOURCES/cpanel.tar.gz is stale after editing SOURCES/cpanel/.
set -u

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
log="$root/.claude/hook.log"
input=$(cat)

tool=$(jq -r '.tool_name // ""' <<<"$input")
file=$(jq -r '.tool_input.file_path // ""' <<<"$input")

record() { printf '%s\t%s\t%s\t%s\n' "$(date -Is)" "$tool" "$file" "$1" >>"$log"; }

case "$file" in
    "$root"/SOURCES/cpanel/*) ;;
    *) record quiet; exit 0 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if tar xzf "$root/SOURCES/cpanel.tar.gz" -C "$tmp" 2>/dev/null \
    && diff -r "$tmp/conf.d" "$root/SOURCES/cpanel/conf.d" >/dev/null \
    && diff -r "$tmp/ea-nginx" "$root/SOURCES/cpanel/ea-nginx" >/dev/null; then
    record quiet
    exit 0
fi

record fired
echo "SOURCES/cpanel.tar.gz is stale: run ./update_cpanel_tar from the repo root (it also git-adds the tarball)." >&2
exit 2
