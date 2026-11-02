# Contributing

Thanks for helping improve dev-edge. Bug reports, platform reports (does it work on your OS and
Docker flavour?) and pull requests are all welcome.

## Principles

- **Small and dependency-free.** The CLI is one Bash script; the edge is one compose file. New
  dependencies beyond Docker, mkcert, openssl, python3 and standard Unix tools need a strong reason.
- **Projects own their routing.** dev-edge provides ports, certificates and network attachment.
  Per-project behaviour belongs in project labels, not in dev-edge.
- **Safe by default.** Loopback only, nothing exposed by default, no secrets in the repository.

## Development

```bash
git clone https://github.com/m4x1m1l14n/dev-edge.git
cd dev-edge
bin/dev-edge install     # points the dev-edge on your PATH at this checkout
```

Before opening a pull request:

1. `shellcheck bin/dev-edge examples/demo/dev.sh` passes
   (or `docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:stable bin/dev-edge examples/demo/dev.sh`).
2. The script still runs on Bash 3.2 (the macOS default): `/bin/bash bin/dev-edge help`.
3. The demo works end to end: `examples/demo/dev.sh up`, `curl` the URLs without `-k`,
   `examples/demo/dev.sh down`.
4. If you changed `compose.yaml`, run `dev-edge restart` and check `dev-edge doctor`.
5. Commands and behaviour changes are reflected in `README.md`, the `usage` text in `bin/dev-edge`,
   `docs/`, `skills/dev-edge/SKILL.md` and `CHANGELOG.md` (under *Unreleased*).

CI runs shellcheck and the full flow (init, up, demo with two stacks, restart, port change) on
Ubuntu for every pull request.

## Releases

1. Move the *Unreleased* entries in `CHANGELOG.md` under a new version and date.
2. Bump `version=` in `bin/dev-edge`.
3. Tag `vX.Y.Z` and create a GitHub release with the changelog section.
