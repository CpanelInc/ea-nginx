# ea-nginx Documentation

https://go.cpanel.net/ea-nginx

# User Configuration

`/usr/local/cpanel/scripts/ea-nginx` will create/remove a configuration file for a user in `/etc/nginx/conf.d/users/<USER>.conf`. This file should not be edited manually. Instead use include files as described below.

To customize all server blocks for a user you can create include files (suitable for a server block) in `/etc/nginx/conf.d/users/<USER>/` that end in `.conf`.

To customize a specific server block you can create include files (suitable for a server block) in `/etc/nginx/conf.d/users/<USER>/<FQDN>/` that end in `.conf`.

`<FQDN>` should be:

* the main domain for the server block with the main domain and its parked domains
* the subdomain for the server blocks for non-addon subdomains
* the subdomain for the server blocks for addon domains and their subdomains

Reusable `.conf` files should go in `/etc/nginx/conf.d/server-includes-optional/`. Depending on what they are for, you could make those symlinks/hardlinks in `…/users/<USER>/*.conf` or `…users/<USER>/<FQDN>/` or `include` them as part files that you put there.

# Global Configuration

Should go in `/etc/nginx/conf.d/*.conf` just be sure not to over write a file the RPM controls or it will get blown away.

If your intent is to adjust every server block you can add a `.conf` file to `/etc/nginx/conf.d/server-includes/` just be sure not to over write a file the RPM controls or it will get blown away.

To have a global configuration file regenerated have your package drop a script into `/etc/nginx/ea-nginx/config-scripts/global/`. These will be executed by `/usr/local/cpanel/scripts/ea-nginx config` with `--all` or `--global`.

## 3rdparty Vendor Proxy Configuration

If an external package needs some specific proxy configuration beyond what `cpanel-proxy.conf` provides they can drop config files in `conf.d/includes-optional/cpanel-proxy-vendors/*.conf`.

# Correcting Apache’s `REMOTE_ADDR`

As of `ea-nginx` version 1.21.6-3 (and `ea-apache24-config-runtime` version 1.0-185) it will bring in Apache’s `mod_remoteip` and configure it securely to correct `REMOTE_ADDR` for hits that are proxied from the local NGINX.

## If you use a custom `/var/cpanel/templates/apache2_4/ea4_main.local`

You **must** update it based on the latest version of `/var/cpanel/templates/apache2_4/ea4_main.default` to get the security benefits.

## If you already have Apache’s `mod_remoteip` configured

We **strongly** suggest removing your `RemoteIPHeader` and `RemoteIPInternalProxy` so that the global and **secure** `RemoteIPHeader` and `RemoteIPInternalProxy` that this package does wil be in effect.

# dev notes

## Re-create SOURCES/cpanel.tar.gz before building!

To keep things organized and revision controlled we use `SOURCES/cpanel`.

Since `SOURCES/` must be flat it is cleaner to generate a tarball as a single source and untar it on installation.

Just run: `cd SOURCES/cpanel && rm -f ../cpanel.tar.gz && tar czf ../cpanel.tar.gz conf.d ea-nginx && cd ../.. && git add SOURCES/cpanel.tar.gz`

A convenience script has been added that does the above, `./update_cpanel_tar`.

## Make sure any `proxy_pass` directives do not introduce XSS vulnerability

TL;DR: simply ensure it does not end in a `/`

NGINX as a reverse proxy does not re-URI encode the path that it sends to the back end when `proxy_pass`’s value ends with a `/`.

For example:

Given this URL `https://example.com/%3C%22your XSS goes here%22%3E/` …

```
proxy_pass https://backend/foo/;
```

… will get sent to the backend as `https://example.com/<"your XSS goes here">/`.

Remove the trailing slash …

```
proxy_pass https://backend/foo;
```

… and will get sent to the backend as `https://example.com/%3C%22your XSS goes here%22%3E/`.

## Make sure any `alias` directives do not introduce path traversal exploit

TL;DR: simply ensure the `location` it belongs to ends in a `/`

This allows traversal:

```
location /i {
    alias /data/w3/images/;
}
```

This does not:

```
location /i/ {
    alias /data/w3/images/;
}
```

For the rest of that example see [Path traversal via misconfigured NGINX alias](https://www.acunetix.com/vulnerabilities/web/path-traversal-via-misconfigured-nginx-alias/).

More in depth talk on the topic: [DEF CON 26 - Orange Tsai - Breaking Parser Logic Take Your Path Normalization Off and Pop 0Days Out](https://youtu.be/28xWcRegncw)
