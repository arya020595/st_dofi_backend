# Manifest approval rules by fisherman category

Who has to approve what depends on the manifest's `fisherman_category`. It is derived server-side from
`company_profile.registration_type` in `Manifests::Create` and never accepted from the client.

| Category | Port-Out | Capture Report | Capture Report skipped (with a reason) | Port-In |
|---|---|---|---|---|
| `commercial` | Jetty Manager approves | DoFi Officer verifies independently from Port-In approval | No DoFi verification | Jetty Manager approves independently from Capture Report verification |
| `small_scale_full_time`, `small_scale_part_time`, `small_scale_company` | No approval | DoFi Officer verifies; the manifest then completes | No DoFi verification | No approval; the manifest completes on submit |

Part-Time, Full-Time and Small-Scale (Company) follow identical rules, so they share the `small_scale?` group.

## Where each rule lives

- **Port-Out / Port-In routing** — the `submit_port_out` and `submit_port_in` events in
  [`app/models/manifest.rb`](../../app/models/manifest.rb). Their guards (`commercial?`, `small_scale?`,
  `capture_report_skipped?`) are the single source of truth; a skipped report is checked before a real one.
- **Completing a small-scale manifest after verification** —
  [`app/models/capture_report.rb`](../../app/models/capture_report.rb) (`advance_manifest_after_verification!`).
- **Who is notified** — [`app/services/manifests/submit_port_in.rb`](../../app/services/manifests/submit_port_in.rb):
  capture-report verifiers when there are reports to verify, and Jetty Managers as soon as a commercial
  Port-In is submitted (they never wait for DoFi verification), nobody for a skipped small-scale manifest.
- **A report is either skipped or submitted, never both** — enforced by model validations, so no write
  path can bypass it: [`Manifest`](../../app/models/manifest.rb) refuses `capture_report_skipped` once
  reports exist, and [`CaptureReport`](../../app/models/capture_report.rb) refuses creation once skipped.

Port-In details (port, area, time) are applied with `Manifests::Update` while the manifest is at sea and its
Port-In is still a draft, for any category. Commercial Port-In approval and Capture Report verification run
in parallel: after either one succeeds, the manifest completes only when `port_in_status` is `approved` and
every Capture Report is `verified`. Until then, `manifest_status` remains `capture_report_submitted` (or
`awaiting_port_in_approval` when only Port-In approval remains). Small-scale rules remain unchanged.
