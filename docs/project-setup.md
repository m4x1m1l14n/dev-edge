# Put a project behind dev-edge

This guide converts a Docker Compose project so every web service is served at
`https://<service>.<stack>.<project>.localhost`. Prefer to let a coding agent do it? Use
[prompts/setup-project.md](../prompts/setup-project.md); it follows the same steps.

Throughout, the project is called `shop` and the default stack `main`.

## 1. Choose names

| | Pattern | Example |
|---|---|---|
| Project | short, lowercase, unique on your machine | `shop` |
| Stack | `main` by default, any DNS label for more copies | `main`, `feature-login` |
| Host names | `<service>.<stack>.<project>.localhost` | `app.main.shop.localhost`, `api.main.shop.localhost` |
| Certificate | one wildcard per stack | `*.main.shop.localhost` |
| Network | `<project>-<stack>` | `shop-main` |
| Router / service names | `<project>-<stack>-<service>` | `shop-main-app` |

Use readable service names in host names (`app`, `api`, `admin`, `mail`), not container names.
A project that will only ever run one copy may drop the stack: `app.shop.localhost` with a
`*.shop.localhost` certificate.

## 2. Compose file

```yaml
name: shop-${STACK:-main}

networks:
  default:
    name: shop-${STACK:-main}

services:
  app:
    build: ./app
    labels:
      - traefik.enable=true
      - traefik.http.routers.shop-${STACK:-main}-app.rule=Host(`app.${STACK:-main}.shop.localhost`)
      - traefik.http.services.shop-${STACK:-main}-app.loadbalancer.server.port=3000

  api:
    build: ./api
    labels:
      - traefik.enable=true
      - traefik.http.routers.shop-${STACK:-main}-api.rule=Host(`api.${STACK:-main}.shop.localhost`)
      - traefik.http.services.shop-${STACK:-main}-api.loadbalancer.server.port=8000

  db:
    image: postgres:17
    # no labels: not exposed through the edge
```

Rules:

- **Stable network name.** `networks.default.name` gives the edge something predictable to attach to.
- **No `ports:` on web services.** The edge reaches containers on the project network. Published
  ports are what stop two stacks from running at once.
- **Listen on 0.0.0.0** inside the container, not 127.0.0.1, or the edge gets `502 Bad Gateway`.
- **Unique router and service names**, prefixed with `<project>-<stack>-`. They are global across
  every project on the machine.
- **No entry point or TLS labels.** dev-edge routes everything over HTTPS by default.
- **One router per host name.** A container serving several host names gets several routers that
  point at the same service (`traefik.http.routers.<name>.service=<service name>`).
- **Several networks?** If a labelled container is on more than one network, tell Traefik which one
  the edge shares with it: `traefik.docker.network=shop-${STACK:-main}`.
- **Remove the old proxy.** A project-level Traefik, nginx or Caddy and its certificates are no
  longer needed.

## 3. Start and stop scripts

Order matters:

```bash
# start
dev-edge cert shop-main '*.main.shop.localhost'   # idempotent, instant after the first time
docker compose up -d
dev-edge attach shop-main                          # also starts the edge if needed

# stop
dev-edge detach shop-main                          # before down, or the network cannot be removed
docker compose down
```

[examples/demo/dev.sh](../examples/demo/dev.sh) wraps this for any stack name and is a good
starting point for a project's `dev.sh`, Makefile target or npm script. When a stack is gone for
good (a merged branch), `dev-edge cert-rm shop-<stack>` deletes its certificate.

**Never hard-code ports in URLs.** Someone else may run the edge on 8443. Build URLs with
`dev-edge url <host> [path]` in scripts, and in config read the port once:

```bash
EDGE_HTTPS_PORT=$(dev-edge port https)          # 443 by default
APP_URL=$(dev-edge url app.main.shop.localhost)  # https://app.main.shop.localhost[:port]
```

## 4. Multiple stacks

Everything above derives from `STACK`, so a second copy is one variable away:

```bash
STACK=feature-login ./dev.sh up
```

Common ways to pick the name:

```bash
# per git branch or worktree, sanitised into a DNS label
STACK=$(git branch --show-current | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/^-*//; s/-*$//')

# per worktree folder
STACK=$(basename "$(git rev-parse --show-toplevel)")
```

Keep stack names short: a DNS label is at most 63 characters, and the whole host name at most 253.

Things that must also be per stack:

- **Volumes.** Named volumes are scoped by the compose project name (`shop-<stack>_dbdata`), so
  each stack gets its own data automatically. Bind mounts to fixed host paths are shared: avoid
  them for data.
- **`container_name:`** must not be set (or must include the stack), or the second stack collides.
- **Host ports** that remain (see below) must not be fixed numbers.

## 5. Application config

Update every URL the app knows about to the new `https://` names:

- API base URLs in frontend config and `.env` files
- CORS allow-lists and CSRF trusted origins
- OAuth / OIDC redirect URIs and webhook URLs registered with third parties (these need
  re-registration with the provider; check each one, since some accept only plain `localhost`)
- cookie domains: prefer host-only cookies (no `Domain` attribute); never set `Domain=localhost`
- absolute links in emails and generated documents

Apps behind a proxy must trust its forwarded headers to build correct absolute URLs and to know
the request was HTTPS:

| Stack | Setting |
|---|---|
| Express | `app.set('trust proxy', true)` |
| Fastify | `fastify({ trustProxy: true })` |
| Laravel | trust all proxies in `bootstrap/app.php` (`$middleware->trustProxies(at: '*')`), set `APP_URL` |
| Symfony | `framework.trusted_proxies: 'REMOTE_ADDR'` plus `trusted_headers` for the `x-forwarded-*` headers |
| Django | `ALLOWED_HOSTS = ['.localhost']`, `CSRF_TRUSTED_ORIGINS = ['https://*.main.shop.localhost']`, `SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')` |
| Rails | `.localhost` is allowed in development; if not, `config.hosts << '.localhost'` |
| Spring Boot | `server.forward-headers-strategy=framework` |
| ASP.NET Core | `UseForwardedHeaders` with `XForwardedProto` and `XForwardedHost` |

### Dev servers and hot reload

Websockets pass through the edge without extra configuration.

- **Vite (and Nuxt, SvelteKit, Astro, Remix on Vite):** listen on all interfaces (`server.host: true`
  or `--host`). Vite allows `*.localhost` host names by default. HMR normally connects back through
  the page's own origin; if the browser console shows HMR connection errors, set
  `server.hmr.clientPort` to the edge's HTTPS port (443 by default).
- **Next.js:** run `next dev -H 0.0.0.0`. If it warns about blocked cross-origin requests to dev
  resources, add the host names to `allowedDevOrigins` in `next.config`.
- **webpack-dev-server:** `host: '0.0.0.0'`, `allowedHosts: ['.localhost']`,
  `client.webSocketURL: 'auto://0.0.0.0:0/ws'`.
- **Angular CLI:** `ng serve --host 0.0.0.0 --allowed-hosts .localhost`.

## 6. Things that are not HTTP

The edge routes HTTP(S) only. For a database or cache you want to reach from a desktop client:

- publish it on loopback with a **random** host port so stacks do not collide, and look it up:
  ```yaml
  db:
    ports: ["127.0.0.1::5432"]
  ```
  ```bash
  docker compose port db 5432     # → 127.0.0.1:55021
  ```
- or skip the port entirely and use `docker compose exec db psql`.

SMTP catchers such as Mailpit: route the web UI through the edge (`mail.main.shop.localhost`) and
let the app send to `mailpit:1025` on the project network.

## 7. Services running outside Docker

A dev server on the host (for example `npm run dev` on port 5173) gets a route through a file in
`~/.config/dev-edge/dynamic/`. Copy [examples/host-service.yml](../examples/host-service.yml),
change the names and port, and issue a certificate for the host name. Traefik picks the file up
immediately. On Linux the process must listen on 0.0.0.0 so the edge container can reach it.

## 8. Containers that call other local HTTPS URLs

Prefer the internal name over plain HTTP (`http://api:8000`). If a container really needs the
public URL (Playwright or OAuth flows inside a container), see
[TLS ends at the edge](how-it-works.md#7-tls-ends-at-the-edge).

## 9. Verify

```bash
dev-edge status                                                       # network and certificate listed
curl -sS -o /dev/null -w '%{http_code}\n' "$(dev-edge url app.main.shop.localhost)"   # no -k
```

Then open the URL in a browser: a padlock with a trusted certificate, no console errors, API calls
and hot reload working. Stop and start with the project's scripts once more to make sure the
detach/attach order is right.

## 10. Document it

Add a short section to the project README so teammates know:

```markdown
## Local development

Requires [dev-edge](https://github.com/m4x1m1l14n/dev-edge) (`dev-edge doctor` must pass).

    ./dev.sh up                    # https://app.main.shop.localhost
    STACK=my-branch ./dev.sh up    # a second copy at https://app.my-branch.shop.localhost
    ./dev.sh down
```
