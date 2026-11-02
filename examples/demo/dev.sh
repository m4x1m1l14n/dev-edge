#!/usr/bin/env bash
# Start and stop one stack of the demo behind dev-edge. Copy it into a project as a starting point.
#
#   ./dev.sh up | down | urls     stack "main"
#   STACK=feature-x ./dev.sh up   a second, independent stack
#   STACK=$(git branch --show-current) ./dev.sh up   one stack per branch or worktree
set -euo pipefail
cd "$(dirname "$0")"

project=demo
services=(web api)

# The stack name becomes a DNS label: lowercase letters, digits and hyphens, at most 40 characters.
stack=$(printf '%s' "${STACK:-main}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/^-*//; s/-*$//')
export STACK=${stack:-main}
network=$project-$STACK

urls() {
  local s
  for s in "${services[@]}"; do dev-edge url "$s.$STACK.$project.localhost"; done
}

case "${1:-up}" in
  up)
    dev-edge cert "$network" "*.$STACK.$project.localhost" >/dev/null
    docker compose up -d
    dev-edge attach "$network"
    urls
    ;;
  down)
    # Detach first: Docker refuses to remove a network the edge is still connected to.
    dev-edge detach "$network"
    docker compose down
    ;;
  urls) urls ;;
  *) echo "usage: [STACK=name] $0 up|down|urls" >&2; exit 2 ;;
esac
