# snapcd-deployment-docker

Reference Docker Compose deployment for [Snap CD](https://snapcd.io), covering all three Snap CD components — **Server**, **Runner** and **Agent** — in one repository.

Each component is a self-contained Compose file under `components/`. The root `docker-compose.yml` is a thin shim that `include`s all three for an all-in-one deploy. Use whichever shape fits your needs:

| You want…                                                                  | What to bring up                                              |
|----------------------------------------------------------------------------|---------------------------------------------------------------|
| **A full Self-Hosted stack** (Server + Runner + Agent on one box)          | `docker compose up -d` (from the repo root)                   |
| **Just the Server** (you'll run Runners/Agents elsewhere)                  | `docker compose -f components/server/docker-compose.yml up -d` |
| **Just a Runner** (you use Snap CD Cloud at snapcd.io)                     | `docker compose -f components/runner/docker-compose.yml up -d` |
| **Just an Agent** (you use Snap CD Cloud or a remote Self-Hosted Server)   | `docker compose -f components/agent/docker-compose.yml up -d`  |

> Each component Compose file is fully self-contained. You can copy a single `components/<name>/` directory out into its own repo if you'd rather not keep the other components around.

## What lives where

```
snapcd-deployment-docker/
├── docker-compose.yml             # Root shim — includes all three components
├── components/
│   ├── server/
│   │   ├── docker-compose.yml     # SQL Server + Redis + Snap CD Server
│   │   └── config/appsettings.json
│   ├── runner/
│   │   ├── docker-compose.yml     # Snap CD Runner
│   │   └── config/
│   │       ├── appsettings.json
│   │       ├── known_hosts        # SSH known_hosts for GitHub / GitLab
│   │       ├── id_rsa             # Your private SSH key (gitignored — see below)
│   │       └── preapproved-hooks/
│   └── agent/
│       ├── docker-compose.yml     # Snap CD Agent + Claude sidecar
│       └── config/appsettings.json
├── renovate.json                   # Auto-PR new Snap CD image versions
└── .github/workflows/renovate.yaml
```

All component Compose files attach to a shared external bridge network called `snapcd-net`, so when you bring up multiple components together they reach each other by service name (`snapcd-server`, `snapcd-runner`, `snapcd-agent`, `snapcd-agent-sidecar-claude`, `sqlserver`, `redis`).

## Bringing up the full stack

```bash
docker compose up -d
docker compose logs -f snapcd-server
```

The Server's Dashboard is available at <http://localhost:8080>. The default Self-Hosted organization is pre-seeded; you sign in as:

- **Email:** `admin@preseeded.io`
- **Password:** `Admin#123`

> Change this password before you put the deployment in front of anything that matters.

The Runner registers automatically using the `default` Service Principal that the Server pre-seeds on first start. The Agent registers using the `defaultAgent` Service Principal. Neither needs any additional setup for the all-in-one deploy to work.

## Bringing up a single component

Each component's Compose file is the source of truth for that component. You can stand them up individually — the only thing you'll typically need to change is each component's `config/appsettings.json` to point at the right Server URL and supply the right credentials.

### Server (only)

```bash
docker compose -f components/server/docker-compose.yml up -d
```

Brings up SQL Server, Redis and the Snap CD Server.

Edit `components/server/config/appsettings.json` to:
- Configure your real OpenID Connect signing keys (`OpenIdConnect.TokenSigning.RsaPrivateKey` / `RsaPublicKey`) — see [docs/server settings](https://docs.snapcd.io/components/server/#settings).
- Set up an `EmailSender` so users can self-serve password resets and invitations.
- Configure `OpenIdConnect.ExternalLoginProviders` if you want SSO sign-in.
- Layer environment-specific overrides into `components/server/config/appsettings.Production.json` (gitignored) — secrets, connection strings, etc.

### Runner (only) — pointed at Snap CD Cloud

```bash
docker compose -f components/runner/docker-compose.yml up -d
```

Edit `components/runner/config/appsettings.json`:
- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's URL).
- Set `Runner.Id`, `Runner.OrganizationId` and `Runner.Credentials` to the values shown when you registered the Runner in the Dashboard.

Drop your SSH key at `components/runner/config/id_rsa` if you want the Runner to clone private Git repositories (this file is gitignored — don't commit it).

### Agent (only) — pointed at Snap CD Cloud

```bash
docker compose -f components/agent/docker-compose.yml up -d
```

Edit `components/agent/config/appsettings.json`:
- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's URL).
- Set `Agent.AgentId`, `Agent.OrganizationId` and `Agent.ClientId` / `Agent.ClientSecret` to the values shown when you registered the Agent.

The Agent ships with a Claude sidecar by default. If your organization is configured to use a different inference provider, edit `components/agent/docker-compose.yml` to swap in the matching sidecar image.

## Executing commands inside containers

Use `docker exec -it <container-name> bash` (or `sh` for Alpine-based images) to get a shell inside a running container.

```bash
# Shell into the Runner (e.g. to run az login, install tools, debug)
docker exec -it snapcd-runner bash

# Shell into the Server
docker exec -it snapcd-server bash

# Shell into the Agent
docker exec -it snapcd-agent bash

# Shell into SQL Server (e.g. to run sqlcmd)
docker exec -it sqlserver bash

# Shell into Redis (Alpine — use sh)
docker exec -it redis sh
```

This is useful for tasks like authenticating cloud CLIs on the Runner:

```bash
docker exec -it snapcd-runner bash
az login
```

## Mixing and matching

The component Compose files don't depend on each other; they only share a network name. You can:
- Spread components across multiple machines (each running its own component Compose).
- Run two Agents on the same box for different organizations — copy `components/agent/` to `components/agent-org-b/` and edit the container names / config paths.
- Run the Server on one box and Runners on many — each Runner gets its own deploy of `components/runner/`.

## Configuration

Per-component settings live next to each component:

- `components/server/config/appsettings.json` — Server settings (full schema: [docs](https://docs.snapcd.io/components/server/#settings))
- `components/runner/config/appsettings.json` — Runner settings ([docs](https://docs.snapcd.io/components/runner/#settings))
- `components/agent/config/appsettings.json` — Agent settings ([docs](https://docs.snapcd.io/components/agent/#settings))

For environment-specific overrides (production secrets, real connection strings), drop an `appsettings.Production.json` next to the base `appsettings.json`. The `.gitignore` excludes these so you can keep production credentials out of source control.

## Image versions

Image tags are pinned in each component Compose file (e.g. `ghcr.io/schrieksoft/snapcd/snapcd-server:1.3.1`). A Renovate workflow in `.github/workflows/renovate.yaml` listens for `repository_dispatch: snapcd-released` events from the upstream Snap CD release pipeline and automatically opens PRs to bump these tags in lock-step. Configure the `RENOVATE_TOKEN` repository secret to enable it.

## Licensing

Snap CD Self-Hosted is distributed under the [Snap CD Source-Available License](https://github.com/schrieksoft/snapcd/blob/main/applications/snapcd/LICENSE.md). This deployment repository is published separately under its own license — see the upstream Snap CD documentation for tier comparisons and how to obtain a license token.
