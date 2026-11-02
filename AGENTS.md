# AGENTS.md

Instructions for coding agents working **on dev-edge itself**. (To use dev-edge in another
project, see `skills/dev-edge/SKILL.md` and `prompts/`.)

## Layout

- `bin/dev-edge`: the whole CLI, one Bash script. Commands are `cmd_<name>` functions dispatched by
  the `case` at the bottom; `usage` is the help text.
- `compose.yaml`: the edge (Traefik). Only ever run through the CLI, which supplies the ports and
  state paths.
- `examples/demo/`: a two-service project with parallel stacks; doubles as the smoke test.
- `docs/`: how it works, project setup guide, troubleshooting. `prompts/`: copy-paste prompts for
  users' agents. `skills/dev-edge/`: Agent Skill for agents in users' projects.
- `.github/workflows/ci.yml`: shellcheck plus the end-to-end flow on Ubuntu.

## Conventions

- Bash 3.2 compatible (macOS default): no associative arrays, `mapfile`, `${var,,}` or `|&`.
- `set -euo pipefail`; user-facing messages go to stderr through `info` / `die`, machine-readable
  output (paths, URLs, ports) to stdout so scripts can capture it.
- Commands are idempotent where possible (`up`, `cert`, `attach`), because project scripts call
  them on every start.
- No new runtime dependencies; keep the CLI a single file.
- When a command or behaviour changes, update `usage`, `README.md`, the relevant `docs/` page,
  `skills/dev-edge/SKILL.md` and `CHANGELOG.md` in the same change.

## Testing

```bash
docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:stable bin/dev-edge examples/demo/dev.sh
/bin/bash bin/dev-edge help
examples/demo/dev.sh up && curl -sS https://api.main.demo.localhost && examples/demo/dev.sh down
```

The developer's machine usually has a live edge serving their other projects. Do not run
`dev-edge down`, `restart`, `ports` or `uninstall`, or edit `~/.config/dev-edge/`, without asking
first; the demo and `cert` / `attach` / `detach` on demo names are safe. Remove demo certificates
afterwards (`dev-edge cert-rm demo-<stack>`).
