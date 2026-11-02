# dev-edge

[![CI](https://github.com/m4x1m1l14n/dev-edge/actions/workflows/ci.yml/badge.svg)](https://github.com/m4x1m1l14n/dev-edge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Trusted local HTTPS for every Docker project on your machine, on readable names, with as many
copies of each project running side by side as you need.**

```text
https://app.main.shop.localhost          project "shop", stack "main"
https://api.main.shop.localhost
https://app.feature-login.shop.localhost  a second copy of "shop", e.g. from a git worktree
https://app.blog.localhost                another project
https://traefik.localhost/dashboard/      the edge itself
```

No port juggling, no hosts-file entries, no certificate warnings, no per-project proxy.

## Why

Running several Docker projects on one laptop usually means one of these:

- every project fights for ports 80/443, or you remember that the API is on `:8081` this week;
- each project ships its own Traefik/nginx/Caddy plus self-signed certificates the browser rejects;
- running a second copy of a project (another branch, a review, an agent working in a worktree)
  needs a second set of ports and edited config.

dev-edge replaces all of that with one small, shared [Traefik](https://traefik.io/traefik/)
container (the *edge*) that owns ports 80 and 443 and routes by host name. Certificates come from a
local certificate authority made by [mkcert](https://github.com/FiloSottile/mkcert), so browsers,
curl and Node show a normal padlock. Real HTTPS locally means secure cookies, OAuth redirects,
service workers, HTTP/2 and `wss://` behave as they do in production.

**What you get**

- `https://<service>.<stack>.<project>.localhost` for every web service, trusted by your system.
- Any number of *stacks* (independent copies) per project, each with its own URLs and network.
- Projects stay isolated: no shared Docker network, so `db` in one project never resolves into
  another.
- Nothing reachable from your network: ports bind to 127.0.0.1 and ::1 only.
- A single Bash script and a compose file. No daemon, no DNS server, no root process of its own.

## Quick start

### 1. Install the requirements

You need Docker with Compose v2, `mkcert`, `openssl` and `python3` (see
[platform support](#platform-support)). mkcert and the Firefox trust tools come from your package
manager.

macOS:

```bash
brew install mkcert nss
```

Debian / Ubuntu:

```bash
sudo apt install mkcert libnss3-tools
```

### 2. Install dev-edge

Clone the repository. Any folder works, but keep it in place afterwards: the CLI is linked from
there.

```bash
git clone https://github.com/m4x1m1l14n/dev-edge.git ~/.local/share/dev-edge
```

Link the CLI into `~/.local/bin`, which must be on your `PATH`:

```bash
~/.local/share/dev-edge/bin/dev-edge install
```

Create the configuration and trust the local certificate authority. mkcert asks for your password
once.

```bash
dev-edge init
```

Start the edge and check that everything is in order:

```bash
dev-edge up
dev-edge doctor
```

### 3. Try the demo

The bundled demo runs two copies of the same project side by side. Start the `main` stack and a
`feature-x` stack:

```bash
cd "$(dev-edge home)/examples/demo"
./dev.sh up
STACK=feature-x ./dev.sh up
```

Each stack prints its URLs, for example `https://web.main.demo.localhost` and
`https://api.feature-x.demo.localhost`. They answer with a trusted certificate, so `curl` needs no
`-k`:

```bash
curl https://api.feature-x.demo.localhost
```

Stop both stacks:

```bash
STACK=feature-x ./dev.sh down
./dev.sh down
```

> [!NOTE]
> If ports 80/443 are already taken on your machine, run `dev-edge ports 8080 8443`. URLs then
> carry the port, and `dev-edge url <host>` always prints the right one.

## How it works

```text
browser ── https://app.main.shop.localhost ──▶ dev-edge (Traefik on 127.0.0.1:443)
                                                  │ attached to each project's own network
                                ┌─────────────────┼────────────────────┐
                                ▼                 ▼                    ▼
                       shop-main network   shop-feature-login     blog-main network
                         app, api, db        app, api, db            app, db
```

1. **Names:** `*.localhost` is reserved for the local machine (RFC 6761). Browsers, and on current
   macOS and systemd Linux the whole OS, resolve it to loopback. No DNS server, no hosts file.
2. **Trust:** `dev-edge init` runs `mkcert -install` once, adding a local CA to your trust stores.
   `dev-edge cert` signs a certificate per stack (e.g. `*.main.shop.localhost`) in milliseconds.
3. **Routing:** Traefik reads Docker labels from running containers. Only labelled containers are
   exposed; TLS is on for every route and HTTP redirects to HTTPS.
4. **Isolation:** `dev-edge attach <network>` connects the edge to a project's own network instead
   of putting projects on a shared one.
5. **TLS ends at the edge:** containers keep serving plain HTTP; apps need no certificates.

Details, edge cases and the reasoning behind each choice: [docs/how-it-works.md](docs/how-it-works.md).

## Use it in a project

Three things in `compose.yaml`: a stable network name per stack, no `ports:` on web services, and
labels with names unique across the machine.

```yaml
name: shop-${STACK:-main}

networks:
  default:
    name: shop-${STACK:-main}        # the network dev-edge attaches to

services:
  app:
    build: .
    # no `ports:` — the edge reaches the container on the project network
    labels:
      - traefik.enable=true
      - traefik.http.routers.shop-${STACK:-main}-app.rule=Host(`app.${STACK:-main}.shop.localhost`)
      - traefik.http.services.shop-${STACK:-main}-app.loadbalancer.server.port=3000
```

Then follow this order in whatever script the project uses. To start, issue the certificate,
start the containers and attach the edge to the project network:

```bash
dev-edge cert shop-main '*.main.shop.localhost'
docker compose up -d
dev-edge attach shop-main
```

The app is now at `https://app.main.shop.localhost`. `dev-edge url app.main.shop.localhost`
prints that address, including the port when the edge does not run on 443.

To stop, detach first. Docker refuses to remove a network the edge is still connected to.

```bash
dev-edge detach shop-main
docker compose down
```

[examples/demo/dev.sh](examples/demo/dev.sh) is a ready-to-copy script that does this for any
stack name. The full guide, including framework settings (Vite, Next.js, Laravel, Django, …),
databases, websockets and services running outside Docker, is in
[docs/project-setup.md](docs/project-setup.md).

### Multiple instances of one project

A *stack* is one running copy of a project. Pick its name with the `STACK` variable and everything
derives from it: the compose project, the network, the host names and the certificate.

Your everyday instance:

```bash
STACK=main ./dev.sh up
```

A colleague's branch, running at the same time:

```bash
STACK=review-142 ./dev.sh up
```

One stack per branch or git worktree:

```bash
STACK=$(git branch --show-current) ./dev.sh up
```

This is what makes dev-edge work well with coding agents running in parallel worktrees: each one
gets its own URLs without touching anyone else's ports.

## Set it up with a coding agent

Copy-paste prompts for Claude Code, Codex, Cursor or any other coding agent:

| Prompt | Use it |
|---|---|
| [prompts/install.md](prompts/install.md) | in any folder, to install dev-edge on your machine |
| [prompts/setup-project.md](prompts/setup-project.md) | inside a project, to put it behind dev-edge |

For day-to-day work, give your agent the [dev-edge skill](skills/dev-edge/SKILL.md) so it knows how
to start stacks, build URLs and debug routing in any project that uses dev-edge. For Claude Code,
link it once for all projects:

```bash
mkdir -p ~/.claude/skills && ln -s "$(dev-edge home)/skills/dev-edge" ~/.claude/skills/dev-edge
```

Other agents that support the [Agent Skills](https://agentskills.io) format load the same folder
from their own skills directory; for agents without skill support, point them at the file from the
project's `AGENTS.md`.

## Commands

| Command | What it does |
|---|---|
| `dev-edge init [http https]` | Create the config, trust the mkcert CA, optionally set ports |
| `dev-edge up` / `down` | Start / stop the edge (`up` is idempotent and cheap: call it from project scripts) |
| `dev-edge restart` | Recreate the edge (after updating dev-edge) and re-attach every network |
| `dev-edge status` | Ports, attached networks, issued certificates |
| `dev-edge doctor` | Check Docker, mkcert, CA trust, ports, `*.localhost` resolution |
| `dev-edge logs [-f]` | Show the edge's Traefik logs |
| `dev-edge ports <http> <https>` | Change ports, restart, re-attach networks |
| `dev-edge port [http\|https]` | Print a port (for scripts building URLs) |
| `dev-edge url <host> [path]` | Print the browser URL for a host, with the port when it is not 443 |
| `dev-edge cert <name> <domain>...` | Issue a certificate; re-issues only when the domain list changes |
| `dev-edge cert-rm <name>` | Delete a certificate |
| `dev-edge attach <network>` | Connect the edge to a project network (starts the edge if needed) |
| `dev-edge detach <network>` | Disconnect it; run **before** `docker compose down` |
| `dev-edge install` / `uninstall [dir]` | Add / remove the CLI symlink (default `~/.local/bin`) |
| `dev-edge home` / `version` | Print the install folder / the version |

State lives in `~/.config/dev-edge/` (or `$XDG_CONFIG_HOME/dev-edge`, or `$DEV_EDGE_STATE`):
`config.env` (ports), `certs/`, `dynamic/` (Traefik file-provider config, watched live) and
`attached` (networks to re-attach after a restart).

## Platform support

| Platform | Status |
|---|---|
| macOS with Docker Desktop | Supported, used daily |
| macOS with OrbStack or Colima | Expected to work, untested: reports welcome |
| Linux with Docker Engine | Supported; CI runs the full flow on Ubuntu. Rootless Docker cannot bind ports below 1024: use `dev-edge ports 8080 8443` |
| Windows (WSL2) | Untested. The CLI runs inside WSL2, but browsers on Windows need the CA too: run `mkcert -install` on Windows with the same `CAROOT` |

Browsers: Chrome, Edge, Safari and Firefox (Firefox needs `nss` installed **before**
`dev-edge init`; snap-packaged Firefox on Ubuntu keeps its own store, see
[troubleshooting](docs/troubleshooting.md)).

## Update and uninstall

To update, pull the latest version and recreate the edge. Attached networks are re-attached
automatically.

```bash
git -C "$(dev-edge home)" pull && dev-edge restart
```

To uninstall, stop the edge and remove the CLI link:

```bash
dev-edge uninstall
```

Delete the certificates and configuration:

```bash
rm -rf ~/.config/dev-edge
```

Optionally, stop trusting the local certificate authority. Other tools that use mkcert on this
machine share it, so skip this step if you still need them.

```bash
mkcert -uninstall
```

## Troubleshooting

`dev-edge doctor` catches most problems. The common ones:

| Symptom | Fix |
|---|---|
| Browser warns about the certificate | `dev-edge doctor`, then `dev-edge init`; restart the browser |
| `TRAEFIK DEFAULT CERT` | No certificate covers that name. A wildcard covers one label only: `*.main.shop.localhost` covers `app.main.shop.localhost`, not `x.app.main.shop.localhost` |
| `404 page not found` | No route: missing labels, container not running, or network not attached (`dev-edge status`) |
| `502` / `504` | Route found, backend unreachable: wrong `loadbalancer.server.port`, or the app listens on 127.0.0.1 instead of 0.0.0.0 |
| `network … has active endpoints` | Run `dev-edge detach <network>` before `docker compose down` |

More, including name resolution outside the browser and containers calling local HTTPS URLs:
[docs/troubleshooting.md](docs/troubleshooting.md).

## Security

dev-edge is a local development tool. Ports bind to loopback only; the edge reads the Docker socket
(read-only mount, which still exposes your container metadata), and the mkcert CA can sign any
name your machine will trust, so keep `$(mkcert -CAROOT)/rootCA-key.pem` private and never run
dev-edge on a shared or production host. See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
