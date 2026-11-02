# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-02

First public release.

- One shared Traefik edge on loopback ports 80/443 (configurable with `dev-edge ports`).
- Trusted certificates per project or stack through mkcert (`dev-edge cert`).
- Per-project network isolation through `dev-edge attach` / `detach`, re-attached on restart.
- `init`, `up`, `down`, `restart`, `status`, `doctor`, `logs`, `url`, `port`, `install`,
  `uninstall`, `home`, `version`.
- Demo project with parallel stacks, host-service routing example, agent prompts and an Agent Skill.

[Unreleased]: https://github.com/m4x1m1l14n/dev-edge/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/m4x1m1l14n/dev-edge/releases/tag/v0.1.0
