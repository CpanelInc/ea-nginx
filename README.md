# dev notes

## Re-create SOURCES/cpanel.tar.gz before building!

To keep things organized and revision controlled we use `SOURCES/cpanel`.

Since `SOURCES/` must be flat its cleaner to generate a tarball as a single source and untar it on installation.

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
