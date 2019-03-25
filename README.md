# ea-nginx Documentation

https://go.cpanel.net/ea-nginx

# User Configuration

`/usr/local/cpanel/scripts/ea-nginx` will create/remove a configuration file for a user in `/etc/nginx/conf.d/users/<USER>.conf`. This file should not be edited manually. Instead use include files as described below.

To customize all server blocks for a user you can create include files (suitable for a server block) in `/etc/nginx/conf.d/users/<USER>/` that end in `.conf`.

To customize a specific server block you can create include files (suitable for a server block) in `/etc/nginx/conf.d/users/<USER>/<FQDN>/` that end in `.conf`.

`<FQDN>` should be:

* the main domain for the server block with the main domain and its parked domains
* the subdomain for the server blocks for non-addon subdomains
* the subdomain for the server blocks for addon domains and theri subdomains

Reusable `.conf` files should go in `/etc/nginx/conf.d/server-includes-optional/`. Dependiong on what they are for you could make those symlinks/hardlinks in `…/users/<USER>/*.conf` or `…users/<USER>/<FQDN>/` or `include` them as part files that you put there.

# Global Configuration

Should go in `/etc/nginx/conf.d/*.conf` just be sure not to over write a file the RPM controls or it will get blown away.

If your intent is to adjust every server block you can add a `.conf` file to `/etc/nginx/conf.d/server-includes/` just be sure not to over write a file the RPM controls or it will get blown away.

# dev notes

## Re-create SOURCES/cpanel.tar.gz before building!

To keep things organized and revision controlled we use `SOURCES/cpanel`.

Since `SOURCES/` must be flat it is cleaner to generate a tarball as a single source and untar it on installation.

Just run: `cd SOURCES/cpanel && rm -f ../cpanel.tar.gz && tar czf ../cpanel.tar.gz conf.d ea-nginx && cd ../..`

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
