# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The EasyApache 4 (cPanel & WHM) `ea-nginx` RPM: NGINX as a caching reverse proxy in front of Apache, plus Perl glue that generates per-user NGINX config from cPanel userdata. There is no local build; OBS builds it (CI in `.github/workflows/` calls reusable `ea-tools` workflows). `SPECS/ea-nginx.spec` installs from the flat `SOURCES/` directory.

## Commands

- **Tests** need a cPanel install (they load `Cpanel::*`) and cPanel's Perl, run from the repo root: `/usr/local/cpanel/3rdparty/bin/perl t/<file>.t` for one file, `/usr/local/cpanel/3rdparty/bin/prove t/` for all. `SPEC=<regex>` runs only the matching Test::Spec blocks.
- **`./update_cpanel_tar`** regenerates `SOURCES/cpanel.tar.gz` from `SOURCES/cpanel/` and `git add`s it. Run it from the repo root after any change under `SOURCES/cpanel/`.

## Architecture

- **`SOURCES/cpanel-scripts-ea-nginx`** (package `scripts::ea_nginx`) is installed as `/usr/local/cpanel/scripts/ea-nginx`, with subcommands `config`, `remove`, `cache`, `clear-cache`, `reload` and others. It renders the Template Toolkit templates (`SOURCES/cpanel/ea-nginx/*.tt`) from cPanel userdata into `/etc/nginx/conf.d/users/<USER>.conf`, writes the global config, and runs `nginx -t` before reloading.
- **`cpanel-scripts-ea-nginx-userdata`** updates per-user userdata (cache and proxy settings).
- **`NginxHooks.pm`, `NginxTasks.pm`, `Nginx.pm`** are cPanel hooks and task handlers that regenerate config on account, domain and PHP-version changes. The spec scriptlets register them with `manage_hooks`.
- **`nginx-adminbin`** lets users clear their own cache. Caches live in `/var/cache/ea-nginx/<type>/<user>`.
- **`SOURCES/cpanel/`** is shipped as the tarball. `conf.d/` holds global config and include snippets. `ea-nginx/` holds the templates, `settings.json`, `cache.json`, and `config-scripts/global/` (other packages' regeneration scripts, run by `ea-nginx config --all|--global`).
- **`debify/`** holds the Debian/Ubuntu packaging overrides.
- `README.md` documents the user-facing include layout. `DESIGN.md` explains why the default is a caching proxy to Apache, with "standalone" as an optional mode.

## Releasing a change

Every shipped change needs, in `SPECS/ea-nginx.spec`:

- `%define release_prefix` incremented.
- A new `%changelog` entry at the top (follow the existing entries).

The committed `SOURCES/cpanel.tar.gz` is what ships, and the tests read `SOURCES/cpanel/` directly, so a stale tarball won't fail them.

Upgrading nginx (commit and changelog subject `EA-NNNNN: Update ea-nginx from vOLD to vNEW`):

- `git rm` the old `SOURCES/release-X.Y.Z.tar.gz`, add the new one, set `main_version`, and reset `release_prefix` to 1.
- Check that `Patch1` (`0001-*.patch`) still applies. Rebase it, or drop it and its `%patch1` line if upstream fixed the issue.

## Security rules for templates (from README.md)

- A `proxy_pass` must not end in `/` (NGINX then doesn't re-encode the URI, which allows XSS).
- A `location` that has an `alias` must end in `/` (otherwise path traversal).
- Filter or escape every user-controlled value that goes into a template (for example the basic-auth realm and auth file paths).

## Conventions

- Commit subjects are `CASE: summary` (for example `EA4-332: ...`).
- Perl scripts are modulinos (`exit( run(@ARGV) ) if !caller;`), so tests load them and call functions directly.
