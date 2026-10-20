---
name: ea-nginx-version-bump
description: Upgrade the bundled nginx source in ea-nginx to a new upstream release (spec, tarball, changelog, Debian include-binaries). Use when asked to update, upgrade or bump ea-nginx to a new nginx version.
disable-model-invocation: true
argument-hint: "<EA-case> <new-version, e.g. 1.31.7>"
---

Upgrade ea-nginx to nginx `$ARGUMENTS`. Work from the repo root. The release rules live in CLAUDE.md ("Releasing a change"); this is the ordered procedure plus the checks that catch silent misses.

1. **Preflight.** `git status` must be clean and the branch must be named for the case. Read the current `main_version` from `SPECS/ea-nginx.spec`. Stop if the new version isn't newer.
2. **Fetch the tarball.** Run `./find-latest-version` if `../ea-tools` is checked out next to this repo. Otherwise download `https://github.com/nginx/nginx/archive/release-<NEW>.tar.gz` to `SOURCES/release-<NEW>.tar.gz`. Confirm it is a valid gzip (`tar tzf`).
3. **Swap tarballs.** `git rm SOURCES/release-<OLD>.tar.gz` and `git add` the new one.
4. **Edit `SPECS/ea-nginx.spec`.**
   - `%define main_version <NEW>`
   - `%define release_prefix 1`
   - New top `%changelog` entry, format `* <Day Mon DD YYYY> <name> <email> - <NEW>-1` then `- <CASE>: Update ea-nginx from v<OLD> to v<NEW>`.
5. **Debian.** `debify/debian/source/include-binaries` must list `release-<NEW>.tar.gz`. `ea4-tool-post-update` normally commits this change itself, so if you ran the tool, verify it. Otherwise edit it by hand. Leave `cpanel.tar.gz` as is.
6. **Patch check.** Confirm `0001-*.patch` still applies to the new source: `tar xzf SOURCES/release-<NEW>.tar.gz -C <tmpdir>`, then `cd` into the single top-level directory it creates and run `patch -p1 --dry-run < <repo>/SOURCES/0001-*.patch` (the spec applies it with `%patch1 -p1`). If it fails, rebase the patch. If upstream fixed the issue, drop the patch and its `%patch1` line.
7. **Leftover check.** `ls SOURCES/*.tar.gz` should show only `cpanel.tar.gz` and `release-<NEW>.tar.gz`. Report any other tarball (such as an old `nginx-*.tar.gz`) and ask before removing it.
8. **Verify.** `grep -rn '<OLD>' SPECS debify` should return only old changelog entries. Run `/usr/local/cpanel/3rdparty/bin/prove t/`.
9. **Commit.** Message: `<CASE>: Update ea-nginx from v<OLD> to v<NEW>`. Don't push or open a PR unless asked.

Do not edit `SOURCES/cpanel/` in this workflow. If you do, the PostToolUse hook will say whether `SOURCES/cpanel.tar.gz` needs `./update_cpanel_tar`.
