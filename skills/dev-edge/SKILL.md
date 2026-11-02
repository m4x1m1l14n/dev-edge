---
name: dev-edge
description: Run, reach and debug Docker projects served by dev-edge, the shared local HTTPS proxy, at https://<service>.<stack>.<project>.localhost. Use when a project's compose file has traefik.* labels or its scripts call dev-edge; when starting, stopping or adding a stack (a parallel copy of a project, e.g. per git worktree); when building local URLs; or when a *.localhost URL shows a certificate warning, 404, 502 or 504.
---

# dev-edge

dev-edge is one Traefik container (named `dev-edge`) that owns the HTTP/HTTPS ports for the whole
machine. It routes by host name using Docker labels, terminates TLS with a locally trusted mkcert
certificate, and reaches each project by being attached to the project's own Docker network.

Full documentation: `"$(dev-edge home)/README.md"` and `"$(dev-edge home)/docs/"`. Read
`docs/project-setup.md` there before converting a project or adding a service.

## Rules

- **Names.** Host `<service>.<stack>.<project>.localhost`; network and compose project
  `<project>-<stack>`; certificate `*.<stack>.<project>.localhost` named `<project>-<stack>`;
  router and service label names `<project>-<stack>-<service>` (they are global on the machine).
- **Stacks.** A stack is one running copy of a project, selected with `STACK` (default `main`).
  Use a separate stack instead of stopping someone else's: e.g. in a git worktree, derive the
  stack from the branch name. Never reuse another stack's name to "share" it.
- **Order.** Start: `dev-edge cert` → `docker compose up -d` → `dev-edge attach <network>`.
  Stop: `dev-edge detach <network>` → `docker compose down`. Use the project's own script when it
  has one.
- **No published web ports.** Never add `ports:` to a web service; add labels instead. Never add
  entry point or TLS labels. Containers must listen on 0.0.0.0.
- **No hard-coded ports in URLs.** Build them with `dev-edge url <host> [path]`; the edge may run
  on 8443 on another machine.
- **Never** stop, restart or reconfigure the edge itself (`dev-edge down`, `restart`, `ports`),
  edit `~/.config/dev-edge/`, or touch other projects' networks or certificates unless the user
  asks: other projects depend on it.
- Use `curl` without `-k`: a certificate error is a real problem to fix, not to bypass.

## Commands

| Command | Use |
|---|---|
| `dev-edge doctor` | Is the machine set up? Run it first when anything fails |
| `dev-edge status` | Ports, attached networks, certificates |
| `dev-edge url app.main.shop.localhost` | The URL to open, with the port when it is not 443 |
| `dev-edge cert shop-main '*.main.shop.localhost'` | Issue or refresh a stack's certificate (idempotent) |
| `dev-edge attach shop-main` | Connect the edge to a stack's network, after `docker compose up` |
| `dev-edge detach shop-main` | Disconnect it, before `docker compose down` |
| `dev-edge cert-rm shop-feature-x` | Delete a certificate once its stack is gone for good |
| `dev-edge logs --tail 50` | Traefik errors (bad labels, file-provider YAML) |

The Traefik dashboard (`dev-edge url traefik.localhost /dashboard/`) lists every router and the
network it uses.

## Debugging a URL

| Symptom | Check |
|---|---|
| Certificate warning, `TRAEFIK DEFAULT CERT` | `dev-edge status`: is there a certificate whose wildcard covers exactly this name? A wildcard covers one label only |
| `404 page not found` | Container running? Has `traefik.enable=true` and a `Host(...)` matching the name? Network listed in `dev-edge status`? If not, `dev-edge attach <network>` |
| `502 Bad Gateway` | `loadbalancer.server.port` matches the port the app listens on, and the app binds 0.0.0.0 |
| `504 Gateway Timeout` | Container on several networks: add `traefik.docker.network=<project>-<stack>` |
| `network … has active endpoints` | Run `dev-edge detach <network>` before `docker compose down` |
| `*.localhost` from inside a container | Means the container itself. Call other services by internal name over HTTP (`http://api:8000`) |

More: `"$(dev-edge home)/docs/troubleshooting.md"`.
