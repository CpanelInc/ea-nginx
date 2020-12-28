# NGINX Behavior Modes

## Target Audiences

1. Maintenance and security teams
2. Training and technical support
3. Managers and other internal key stakeholders
4. Future project/feature owners/maintainers

## Detailed Summary

NGINX is the most popular feature on the feature site, specifically speeding up website by using it as a caching reverse proxy.

Some also want it to serve static content instead of proxying that also.

## Overall Intent

To deliver behaviors customers need in a way that covers most out of the box and is flexable enough to do other behaviors relatively simply.

## Maintainability

Estimate:

1. how much time and resources will be needed to maintain the feature in the future
2. how frequently maintenance will need to happen

Once in place very little of either. Anytime we add another “behavior” type it will involve determining what configuration we need, creating a package that will enable that configuration, and probably updating ea-nginx configurations to factor that in.

## Options/Decisions

Note: “standalone” is how it works in the initial experimental `ea-nginx`: serve static content and proxy everything else (to cpsrvd, Apache, FPM, etc)

| Approach | Pro | Con |
| ---------| ----| ----|
| leave it as standalone | No Effort | Not what most people want, has security issues so would be longer to get out of experimental |
| change it to reverse proxy everything to Apache and cache | This is what most people want | That leaves the rest by the wayside |
| change it to reverse proxy everything to Apache and cache by default; with a way to switch to standalone (and any other “Behavior Modes” that come up) | Everyone can get what they want, ea-nginx can go to production while standalone stays experimental (security issues), can add new modes relatively easy | None |

### Conclusion: reverse proxy to Apache w/ caching by default, “standalone” via new `ea-nginx-standalone`

Caching is done per user in `/etc/nginx/cache/<type>/<user>`. `<type>` is `proxy` for `proxy_pass`. When caching is added to standalone (ZC-8173), there will also be `fastcgi` for `fastcgi_pass`.

**Note**: The cache directories are `700` `nobody/root` which means users can not see them unless the server is already exploitable (e.g. Apache running PHP as `nobody`).

## SEE ALSO

The [README.md](README.md) contains information on how the configuration is laid out as well as other things to take into consideration.
