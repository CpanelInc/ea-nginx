# Apache 2.4.64: mod_ssl Changes and Reverse Proxy Implications

## Background: mod_ssl Behavior Before Apache 2.4.64

Before Apache 2.4.64, `mod_ssl` selected virtual hosts in two steps:

1. **TLS Handshake**: The server chose a certificate based on the SNI extension (if present).
2. **HTTP Routing**: After decrypting the request, it used the `Host:` header to select the actual `<VirtualHost>`.

If a client didn’t send SNI or it didn’t match a configured vhost, Apache defaulted to the first `<VirtualHost>` on the IP:port. Even with TLS 1.3 session resumption or HTTP/1.1 keep-alive, `mod_ssl` didn’t enforce that the resumed session’s SNI matched the new `Host:` header—creating a subtle access-control gap.

## CVE Fix in Apache 2.4.64

In July 2025, Apache addressed this issue with a CVE fix that introduced a strict compatibility check:

- **New Behavior**: After decrypting the HTTP request, `mod_ssl` calls `ssl_server_compatible()` to verify that the certificate selected during the handshake matches the `Host:` header.
- **Mismatch Handling**: Any mismatch—including resumed sessions without SNI—results in an immediate `421 Misdirected Request`.

This change closes the access-control gap but breaks configurations relying on the old “handshake-once then multiplex” model.

## Impact on Nginx → Apache Reverse Proxy

Our setup used:

- **HTTP/1.1 keep-alive**
- **TLS session tickets**

Nginx reuses backend connections, sending SNI only on the first request. Subsequent requests reuse the TLS session without renegotiating SNI. Under Apache 2.4.64+, if a reused connection carries a different `Host:` header, `mod_ssl` detects a stale SNI and returns a `421`.

These errors appear intermittently due to connection reuse patterns.

## Workaround: Switching to HTTP/1.0

To avoid `421` errors without sacrificing performance entirely:

- We **unset `proxy_http_version`** in Nginx.
- This forces **HTTP/1.0** on the backend, adding `Connection: close` to each request.
- Each request now triggers a fresh TCP/TLS handshake with a matching SNI and `Host:` header.

### Benefits

- Eliminates intermittent `421` errors.
- Maintains a simple, template-driven proxy setup.
- Avoids complex alternatives like per-domain pools or dual TLS termination.

### Trade-offs

- Slightly increased CPU usage and latency due to more frequent TLS handshakes.

## Broader Implications for Other Proxies

This issue isn’t unique to Nginx. Any reverse proxy or load balancer that:

- Reuses backend TLS sessions,
- Doesn’t re-send SNI on each request,
- Or multiplexes requests across virtual hosts,

may encounter similar `421` errors under Apache 2.4.64+.

### Potentially Affected Systems

- HAProxy with TLS reuse
- Envoy or Traefik using persistent backend connections
- Custom proxy layers in microservice architectures

### Mitigation Strategies

All affected setups must ensure that:

- SNI is sent consistently,
- TLS sessions are aligned with the `Host:` header,
- Or connections are terminated per request to reset handshake state.

## Future Considerations

We’re evaluating longer-term solutions (e.g. EA4-58) such as:

- Per-hostname keep-alive pools
- Full TLS offload at the edge

For now, the HTTP/1.0 fallback offers a reliable, low-risk fix compatible with Apache 2.4.64+.
