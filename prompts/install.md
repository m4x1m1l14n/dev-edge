# Prompt: install dev-edge on this machine

Paste everything below the line into a coding agent (Claude Code, Codex, Cursor, …) in any folder.
The agent will pause and hand you the one step that needs your password.

---

Install **dev-edge** on this machine: a shared local Traefik that gives Docker projects trusted
HTTPS on `https://<service>.<stack>.<project>.localhost`. Repository:
https://github.com/m4x1m1l14n/dev-edge. Read its README before you start.

Work through these steps in order, show me the output of each check, and stop to ask me before
anything that needs `sudo`, a password, or changes outside the folders named here.

1. **Check what is already there.** If `command -v dev-edge` succeeds, run `dev-edge doctor`,
   report the result and stop: it is installed. Otherwise check the requirements and list what is
   missing: Docker running (`docker info`), Docker Compose v2 (`docker compose version`), `mkcert`,
   `openssl`, `python3`, and `curl`.

2. **Install missing requirements** with the platform's package manager, after I confirm:
   macOS `brew install mkcert nss`; Debian/Ubuntu `sudo apt install mkcert libnss3-tools`;
   Fedora `sudo dnf install mkcert nss-tools`; Arch `sudo pacman -S mkcert nss`. Do not install
   or start Docker yourself; tell me if it is missing.

3. **Check ports 80 and 443.** If something already listens on them (`lsof -nP -iTCP:443
   -sTCP:LISTEN`, or `ss -ltnp` on Linux), tell me what it is. Do not stop it; I will choose
   between stopping it and running dev-edge on other ports (`dev-edge ports 8080 8443` later).

4. **Clone and link the CLI:**
   ```bash
   git clone https://github.com/m4x1m1l14n/dev-edge.git ~/.local/share/dev-edge
   ~/.local/share/dev-edge/bin/dev-edge install
   ```
   If `~/.local/bin` is not on PATH, show me the line to add to my shell profile and add it only
   after I agree.

5. **Trust the local CA.** `dev-edge init` runs `mkcert -install`, which asks for my password. Do
   not try to supply it: ask me to run `dev-edge init` in my own terminal (with ports, e.g.
   `dev-edge init 8080 8443`, if we chose other ports in step 3) and wait until I confirm.

6. **Start and verify:**
   ```bash
   dev-edge up
   dev-edge doctor
   ```
   Every check must say `ok`. If one fails, use `docs/troubleshooting.md` in the repository to fix
   it and explain what you changed.

7. **Smoke test** with the bundled demo, then clean up:
   ```bash
   cd "$(dev-edge home)/examples/demo"
   ./dev.sh up
   curl -sS "$(dev-edge url api.main.demo.localhost)" | head -3      # no -k
   ./dev.sh down
   dev-edge cert-rm demo-main
   ```

8. **Optional, ask me first:** link the dev-edge Agent Skill so coding agents know how to use it
   in every project. For Claude Code:
   `mkdir -p ~/.claude/skills && ln -s "$(dev-edge home)/skills/dev-edge" ~/.claude/skills/dev-edge`.

Finish with a short summary: install location, ports, `dev-edge doctor` output, and the dashboard
URL (`dev-edge url traefik.localhost /dashboard/`).
