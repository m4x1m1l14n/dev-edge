# Security policy

dev-edge is a local development tool. It is designed to run on a single developer machine and must
never be exposed to a network or used in production.

## What dev-edge does that matters for security

- It publishes ports on 127.0.0.1 and ::1 only.
- The edge container mounts the Docker socket read-only to read container labels. A read-only
  mount still allows reading all container metadata, including environment variables.
- `dev-edge init` installs a local certificate authority (mkcert) into your trust stores. Anyone
  with its private key (`$(mkcert -CAROOT)/rootCA-key.pem`) can create certificates your machine
  trusts for any domain. Never commit, copy or share that file; `mkcert -uninstall` removes the
  trust.
- The Traefik dashboard at `https://traefik.localhost/dashboard/` is unauthenticated and reachable
  from the local machine only.

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub security advisories](https://github.com/m4x1m1l14n/dev-edge/security/advisories/new)
rather than a public issue. Include the steps to reproduce, the impact, and your platform. You
should get a response within a week.

Issues that require an attacker who already runs code as your user (and could therefore use Docker
or mkcert directly) are generally out of scope.
