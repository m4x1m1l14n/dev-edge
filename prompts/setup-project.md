# Prompt: put a project behind dev-edge

Paste everything below the line into a coding agent running in the project you want to convert.
Replace `<project>` with a short lowercase name for the project (e.g. `shop`), or delete that line
and let the agent propose one.

---

Put this project behind **dev-edge**, the shared local HTTPS proxy on this machine, so every web
service is served at `https://<service>.<stack>.<project>.localhost` with a trusted certificate,
and several copies (stacks) of the project can run side by side.
The project name is `<project>`.

## Background (read first)

- The `dev-edge` CLI must be on PATH and `dev-edge doctor` must pass. If not, stop and tell me; do
  not install it yourself (installing needs my password).
- Read, completely, before changing anything: `"$(dev-edge home)/README.md"` and
  `"$(dev-edge home)/docs/project-setup.md"`. The second is the step-by-step guide this task
  follows; `"$(dev-edge home)/examples/demo/"` is a working reference (compose file and `dev.sh`).
- dev-edge is one Traefik container that owns the HTTP/HTTPS ports for the whole machine. It reads
  Docker labels, terminates TLS with mkcert certificates, and reaches containers by being attached
  to each project's own Docker network. Projects never publish web ports themselves, which is what
  lets many stacks run at once.

## What to do

1. **Inventory.** List how the project runs today: compose files, any reverse proxy of its own
   (Traefik, Caddy, nginx), published ports, TLS certificates (mkcert or self-signed files),
   hosts-file entries, fixed `container_name:` values, and every URL or host name in env files,
   app config and frontend config (API base URLs, OAuth redirect URIs, CORS origins, CSRF trusted
   origins, cookie domains, websocket/HMR URLs). Also note whether the project already supports
   several instances (per git worktree, per branch, a `COMPOSE_PROJECT_NAME` scheme). Show me this
   list, the planned host names and the planned stack mechanism **before editing anything**.

2. **Choose names** (see "Choose names" in project-setup.md):
   - Stack: a `STACK` variable defaulting to `main`. If the project already has an instance
     mechanism, reuse it and derive the stack name from it.
   - Host names: `<service>.<stack>.<project>.localhost`, with readable service names (`app`,
     `api`, `admin`, `mail`, …).
   - Certificate: one per stack, `dev-edge cert <project>-<stack> '*.<stack>.<project>.localhost'`.
   - Network: `<project>-<stack>`. Router and service names: `<project>-<stack>-<service>`.

3. **Compose changes:**
   - `name: <project>-${STACK:-main}` and `networks: { default: { name: <project>-${STACK:-main} } }`.
   - Remove the project's own reverse proxy service and its certificate files and mounts. If it
     uses Traefik file-provider rules for things labels cannot express, convert them to labels
     where possible and tell me which ones remain.
   - Remove `ports:` from every web-facing service. For non-HTTP ports used from host tools (a
     database for a desktop client), switch to a random loopback port (`"127.0.0.1::5432"`) and
     tell me about each one.
   - Remove or stack-suffix any `container_name:`; check bind-mounted data paths do not collide
     between stacks.
   - Add labels to each web-facing service:
     ```yaml
     labels:
       - traefik.enable=true
       - traefik.http.routers.<project>-${STACK:-main}-<svc>.rule=Host(`<svc>.${STACK:-main}.<project>.localhost`)
       - traefik.http.services.<project>-${STACK:-main}-<svc>.loadbalancer.server.port=<container port>
     ```
     One router per host name. Containers must listen on 0.0.0.0. A container on several networks
     also needs `traefik.docker.network=<project>-${STACK:-main}`. Do not set entry points or TLS
     options in labels.

4. **Start/stop scripts** (whatever the project uses: Makefile, npm scripts, a `dev.sh`; base a
   new one on `examples/demo/dev.sh`):
   - start: `dev-edge cert …` → `docker compose up -d` → `dev-edge attach <project>-<stack>` →
     print every URL with `dev-edge url <host>`.
   - stop: `dev-edge detach <project>-<stack>` **before** `docker compose down`.
   - The stack name must be passed through to compose (`export STACK`) and sanitised into a DNS
     label (lowercase letters, digits, hyphens).
   - Never hard-code the port in URLs: build them with `dev-edge url <host>` or
     `dev-edge port https`.

5. **Application config.** Update every URL from step 1 to the new `https://` host names, derived
   from the stack name where the config allows it. Make the app trust the proxy's
   `X-Forwarded-Proto` / `X-Forwarded-Host` headers and configure dev servers and HMR as described
   in project-setup.md ("Application config", "Dev servers and hot reload"). Third-party callbacks
   (OAuth apps, webhooks) registered with the old URLs need re-registration: list them for me
   instead of guessing.

6. **Containers calling other local URLs:** prefer the internal service name over plain HTTP on
   the project network. Only if the public URL is truly needed, follow "TLS ends at the edge" in
   `docs/how-it-works.md`.

7. **Remove leftovers:** hosts-file instructions, mkcert or self-signed certificate generation, the
   old proxy's config folder, and docs mentioning old URLs and ports.

8. **Verify** and show me the output:
   - `dev-edge status` lists the network and the certificate.
   - `curl -sS -o /dev/null -w '%{http_code}\n' "$(dev-edge url <host>)"` for every host, without `-k`.
   - Start a second stack (`STACK=verify` or the project's equivalent), check its URLs answer too
     while `main` keeps running, then stop it and remove its certificate (`dev-edge cert-rm`).
   - If a browser tool is available, open the main URL: trusted certificate, no console errors,
     API calls and websockets/HMR work.
   - Stop and start again with the project's scripts; after stopping, `dev-edge status` must no
     longer list the network.

9. **Document** in the project's README: the requirement (dev-edge installed, link to
   https://github.com/m4x1m1l14n/dev-edge), the URLs, how to start a second stack, and the
   start/stop commands.

Keep each change minimal, and at the end list anything you could not convert.
