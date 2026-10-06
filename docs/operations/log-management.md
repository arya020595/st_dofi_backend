# Log management

## Current approach

Developers inspect API and worker output with Docker Compose; see [server logging](server-logging.md).
Server administrators provide SSH access and monitor available disk space. Sentry handles error
monitoring; business audit records track business changes separately from operational logs.

Docker manages container logs using the server's existing settings. There is no new retention
policy, collector, or central store. Do not add request/response database logging for troubleshooting.

## Future centralization

When retention across deployments or searching multiple servers becomes necessary:

1. Agree on required retention, expected volume, access controls, and hosting with server administrators.
2. Evaluate Grafana with Loki and a supported collector, or the organization's existing logging platform.
3. Collect container stdout/stderr outside application code, keeping request-ID correlation and filtering.
4. Pilot collection on staging, verify searches and secret handling, and measure disk/storage costs.
5. Roll out to production with dashboards and actionable alerts after agreeing on ownership and retention.

No collector or Grafana/Loki deployment is included now.
