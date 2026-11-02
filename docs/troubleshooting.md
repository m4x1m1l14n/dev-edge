# Troubleshooting

Start with `dev-edge doctor`; it checks Docker, mkcert, CA trust, ports, name resolution and, when
the edge is running, that it answers with a trusted certificate. `dev-edge status` shows attached
networks and issued certificates, `dev-edge logs` the Traefik logs, and the dashboard at
`https://traefik.localhost/dashboard/` every router Traefik knows about.

## Certificates

| Symptom | Cause and fix |
|---|---|
| Browser warns "not private" / `NET::ERR_CERT_AUTHORITY_INVALID` | The mkcert CA is not trusted. Run `dev-edge doctor`, then `dev-edge init`, then fully restart the browser |
| Firefox warns, other browsers don't | Firefox uses its own store. Install `nss` (macOS) or `libnss3-tools` (Linux), run `mkcert -install` again, restart Firefox |
| Snap Firefox on Ubuntu warns | Snap Firefox keeps its profile in `~/snap/firefox/`, which mkcert does not find. Import `$(mkcert -CAROOT)/rootCA.pem` under Settings → Privacy & Security → Certificates → Import, or use the deb package |
| Page shows `TRAEFIK DEFAULT CERT` | No issued certificate covers the host name. Check `dev-edge status`. A wildcard covers exactly one label: `*.main.shop.localhost` does not cover `main.shop.localhost` or `x.app.main.shop.localhost` |
| `curl` fails with `SSL certificate problem` but the browser is fine | The tool uses its own CA bundle. Node: `export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"`; Python requests: `REQUESTS_CA_BUNDLE`; others: `SSL_CERT_FILE` |
| `mkcert failed` | Run the printed mkcert command yourself to see the error; check `mkcert -CAROOT` is writable |

## Routing

| Symptom | Cause and fix |
|---|---|
| `404 page not found` | No router matches the host. The container lacks `traefik.enable=true`, is not running, has a typo in `Host(...)`, or the edge is not attached to its network (`dev-edge status`, then `dev-edge attach <network>`) |
| `502 Bad Gateway` | Router found, backend refused the connection: wrong `loadbalancer.server.port`, or the app listens on 127.0.0.1 inside the container instead of 0.0.0.0 |
| `504 Gateway Timeout` | Traefik picked a network the edge is not on. Add `traefik.docker.network=<project>-<stack>` to the container's labels |
| Two projects show each other's pages | Router or service names collide. Prefix every name with `<project>-<stack>-` |
| Route disappears after `docker compose up` recreated the network | The edge is attached to the old network. Run `dev-edge attach <network>` after every `up` (project scripts should always do this) |
| Hot reload / websockets fail | See [dev servers and hot reload](project-setup.md#dev-servers-and-hot-reload) |

## Ports and starting

| Symptom | Cause and fix |
|---|---|
| `port 443 is already in use` on `dev-edge up` | Another proxy holds the port (an old project Traefik, a local nginx or Apache, Laravel Herd/Valet). Stop it, or move the edge: `dev-edge ports 8080 8443` |
| Rootless Docker cannot bind 80/443 | Unprivileged processes cannot bind ports below 1024. Use `dev-edge ports 8080 8443`, or allow it: `sudo sysctl net.ipv4.ip_unprivileged_port_start=80` |
| `network … has active endpoints` on `docker compose down` | The edge is still attached. Run `dev-edge detach <network>` first |
| Edge config changed after `git pull`, but nothing happened | `dev-edge up` does nothing when the edge already runs. Run `dev-edge restart` |

## Name resolution

| Symptom | Cause and fix |
|---|---|
| `*.localhost` works in the browser, not in the terminal | Browsers resolve `*.localhost` themselves; some systems don't. Linux: enable systemd-resolved or `nss-myhostname` (`hosts: files myhostname dns` in `/etc/nsswitch.conf`). Older macOS: install dnsmasq with `address=/localhost/127.0.0.1` and create `/etc/resolver/localhost` with `nameserver 127.0.0.1`. Recent curl versions resolve `*.localhost` themselves |
| `*.localhost` inside a container resolves to the container | Expected: inside a container, localhost is the container. See [TLS ends at the edge](how-it-works.md#7-tls-ends-at-the-edge) |

## Services on the host

| Symptom | Cause and fix |
|---|---|
| File route to `host.docker.internal` returns 502 on Linux | The host process listens on 127.0.0.1 only; make it listen on 0.0.0.0 (e.g. `vite --host`). After updating dev-edge, run `dev-edge restart` once so the edge knows `host.docker.internal` |
| File route is ignored | Check `dev-edge logs` for YAML errors in `~/.config/dev-edge/dynamic/` |

## Still stuck?

Open an [issue](https://github.com/m4x1m1l14n/dev-edge/issues/new/choose) with the output of
`dev-edge version`, `dev-edge doctor` and `dev-edge status`, your OS and Docker flavour, and the
relevant labels from your compose file.
