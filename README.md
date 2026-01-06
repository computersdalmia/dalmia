# Dalmia (JANU Core Ops)
This repo contains the JANU core ops skeleton, infra scripts, API helpers, DB assets, content pipeline, and docs.

## Directories
- infra/   : server + nginx + ssl + systemd + monitoring
- api/     : API helpers and endpoints
- db/      : schema, migrations, seed data
- content/ : SEO + knowledge pipeline inputs
- ops/     : operations tooling and runbooks
- docs/    : SOPs and handover docs
- scripts/ : bash utilities

## Notes
- Secrets are not stored in Git. Use /etc/janu/*.env on VPS.
